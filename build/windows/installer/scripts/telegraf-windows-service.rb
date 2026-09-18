require "fileutils"
require "logger"
require "thread"

class TelegrafServiceWorker
  EXECUTABLE = 'C:\opt\telegraf\telegraf.exe'.freeze
  CONFIGURATIONS = {
    "prometheus" => 'C:\etc\telegraf\telegraf.conf',
    "process-metrics" => 'C:\etc\telegraf\telegraf-ama-logs-process-metrics.conf',
  }.freeze
  STOP_TIMEOUT = 20

  class UnexpectedExit < StandardError; end

  def initialize(role, logger, console, process_api = Process)
    @configuration = CONFIGURATIONS.fetch(role)
    @logger = logger
    @console = console
    @process_api = process_api
    @mutex = Mutex.new
    @stopping = false
  end

  def run
    reader = nil
    @mutex.synchronize do
      return if @stopping
      @console.prepare
      reader, writer = IO.pipe
      begin
        @pid = @process_api.spawn(
          EXECUTABLE, "--console", "--config", @configuration,
          in: File::NULL, out: writer, err: writer, new_pgroup: true
        )
      ensure
        writer.close
      end
      begin
        @console.attach(@pid)
      rescue SystemCallError
        unless @process_api.waitpid(@pid, Process::WNOHANG)
          @process_api.kill("KILL", @pid)
          @process_api.waitpid(@pid)
        end
        raise
      end
      @waiter = @process_api.detach(@pid)
      @logger.info("Started Telegraf PID #{@pid}")
    end

    output = Thread.new do
      reader.each_line { |line| @logger.info(line.chomp) }
    end
    output.abort_on_exception = true
    status = @waiter.value
    unless output.join(5)
      raise IOError, "Telegraf output did not close after the process exited"
    end
    unless @mutex.synchronize { @stopping }
      raise UnexpectedExit, "Telegraf PID #{@pid} exited unexpectedly: #{status}"
    end
    @logger.info("Telegraf PID #{@pid} stopped: #{status}")
  ensure
    reader.close if reader && !reader.closed?
    @console.close
  end

  def stop
    pid, waiter = @mutex.synchronize do
      @stopping = true
      [@pid, @waiter]
    end
    return unless waiter && waiter.alive?

    # A private console and process group let SCM stop only this Telegraf child.
    signaled = @console.interrupt(pid)
    @logger.warn("Could not signal Telegraf PID #{pid}; terminating it") unless signaled
    if !signaled || !waiter.join(STOP_TIMEOUT)
      @logger.warn("Terminating Telegraf PID #{pid} after the shutdown deadline") if signaled
      @process_api.kill("KILL", pid) if waiter.alive?
      raise UnexpectedExit, "Telegraf PID #{pid} did not terminate" unless waiter.join(5)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  unless ARGV.length == 1 && TelegrafServiceWorker::CONFIGURATIONS.key?(ARGV[0])
    abort "Usage: telegraf-windows-service.rb prometheus|process-metrics"
  end

  # The image already uses win32-service for Fluentd. Unlike Telegraf's native
  # service detection, its dispatcher works in a container's nonzero session.
  require "win32/daemon"

  class TelegrafConsole
    module Native
      extend FFI::Library
      ffi_lib "kernel32"
      ffi_convention :stdcall
      attach_function :GetConsoleProcessList, [:pointer, :ulong], :ulong
      attach_function :AllocConsole, [], :bool
      attach_function :FreeConsole, [], :bool
      attach_function :GenerateConsoleCtrlEvent, [:ulong, :ulong], :bool
      attach_function :GetLastError, [], :ulong
      attach_function :CreateJobObjectW, [:pointer, :pointer], :pointer
      attach_function :SetInformationJobObject, [:pointer, :int, :pointer, :ulong], :bool
      attach_function :OpenProcess, [:ulong, :bool, :ulong], :pointer
      attach_function :AssignProcessToJobObject, [:pointer, :pointer], :bool
      attach_function :CloseHandle, [:pointer], :bool

      class BasicLimits < FFI::Struct
        layout :process_time, :int64, :job_time, :int64, :flags, :uint32,
               :min_working_set, :size_t, :max_working_set, :size_t,
               :active_processes, :uint32, :affinity, :size_t,
               :priority, :uint32, :scheduling, :uint32
      end

      class ExtendedLimits < FFI::Struct
        layout :basic, BasicLimits, :io_counters, [:uint64, 6],
               :process_memory, :size_t, :job_memory, :size_t,
               :peak_process_memory, :size_t, :peak_job_memory, :size_t
      end
    end

    def prepare
      buffer = FFI::MemoryPointer.new(:ulong, 1)
      if Native.GetConsoleProcessList(buffer, 1) == 0
        unless Native.AllocConsole
          raise SystemCallError.new("AllocConsole", Native.GetLastError)
        end
        @allocated = true
      end
      @job = Native.CreateJobObjectW(nil, nil)
      raise SystemCallError.new("CreateJobObject", Native.GetLastError) if @job.null?
      limits = Native::ExtendedLimits.new
      limits[:basic][:flags] = 0x2000 # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE.
      unless Native.SetInformationJobObject(@job, 9, limits.pointer, limits.size)
        raise SystemCallError.new("SetInformationJobObject", Native.GetLastError)
      end
    end

    def attach(pid)
      # The job also cleans up the child if the service host crashes or is killed.
      process = Native.OpenProcess(0x0101, false, pid) # SET_QUOTA | TERMINATE.
      raise SystemCallError.new("OpenProcess", Native.GetLastError) if process.null?
      begin
        unless Native.AssignProcessToJobObject(@job, process)
          raise SystemCallError.new("AssignProcessToJobObject", Native.GetLastError)
        end
      ensure
        unless Native.CloseHandle(process)
          raise SystemCallError.new("CloseHandle(process)", Native.GetLastError)
        end
      end
    end

    def interrupt(pid)
      Native.GenerateConsoleCtrlEvent(1, pid) # CTRL_BREAK_EVENT for this process group.
    end

    def close
      if @job && !@job.null?
        unless Native.CloseHandle(@job)
          raise SystemCallError.new("CloseHandle(job)", Native.GetLastError)
        end
        @job = nil
      end
      return unless @allocated
      unless Native.FreeConsole
        raise SystemCallError.new("FreeConsole", Native.GetLastError)
      end
      @allocated = false
    end
  end

  class TelegrafWindowsService < Win32::Daemon
    def initialize(role)
      directory = 'C:\opt\telegraf\logs'
      FileUtils.mkdir_p(directory)
      @logger = Logger.new(File.join(directory, "#{role}-service.log"), 2, 5 * 1024 * 1024)
      @worker = TelegrafServiceWorker.new(role, @logger, TelegrafConsole.new)
    end

    def service_main
      @worker.run
    rescue TelegrafServiceWorker::UnexpectedExit, SystemCallError, IOError => error
      @logger.fatal(error.message)
      exit! 1
    end

    def service_stop
      @worker.stop
    end
  end

  TelegrafWindowsService.new(ARGV[0]).mainloop
end
