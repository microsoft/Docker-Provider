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
  require_relative "telegraf-windows-console"

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
