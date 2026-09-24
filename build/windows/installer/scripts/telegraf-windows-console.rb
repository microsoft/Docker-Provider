require "ffi"

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
    attach_function :GetCurrentProcess, [], :pointer
    attach_function :CreateJobObjectW, [:pointer, :pointer], :pointer
    attach_function :SetInformationJobObject, [:pointer, :int, :pointer, :ulong], :bool
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

    # Enroll the host before spawning: children inherit membership atomically.
    # The non-inheritable job handle remains owned only by this host.
    unless Native.AssignProcessToJobObject(@job, Native.GetCurrentProcess)
      raise SystemCallError.new("AssignProcessToJobObject(host)", Native.GetLastError)
    end
    @host_assigned = true
  end

  def interrupt(pid)
    Native.GenerateConsoleCtrlEvent(1, pid) # CTRL_BREAK_EVENT for this process group.
  end

  def close
    # Once enrolled, keep the handle until host exit. Closing it here would also
    # kill the host before it can finish SCM stop notification and log cleanup.
    if @job && !@job.null? && !@host_assigned
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
