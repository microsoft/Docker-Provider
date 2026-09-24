require "minitest/autorun"
require "rbconfig"
require "tmpdir"

if Gem.win_platform?
  require_relative "telegraf-windows-console"

  module TelegrafProcessObserver
    extend FFI::Library
    ffi_lib "kernel32"
    ffi_convention :stdcall
    attach_function :OpenProcess, [:ulong, :bool, :ulong], :pointer
    attach_function :WaitForSingleObject, [:pointer, :ulong], :ulong
    attach_function :TerminateProcess, [:pointer, :uint32], :bool
    attach_function :CloseHandle, [:pointer], :bool
  end
end

class TelegrafConsoleTest < Minitest::Test
  # Pause inside spawn, before the worker can perform any post-spawn action.
  # Only a sleeping Ruby fixture is launched; no Telegraf, service or network.
  HOST_SCRIPT = <<~'RUBY'.freeze
    require ARGV.shift
    require ARGV.shift
    require "rbconfig"

    class StartupBoundary
      def initialize(console, marker, close_console)
        @console, @marker, @close_console = console, marker, close_console
      end

      def spawn(*command, **options)
        pid = Process.spawn(RbConfig.ruby, "-e", "sleep 60", **options)
        @console.close if @close_console
        File.write(@marker, pid.to_s)
        $stdin.gets
        exit 0
      end
    end

    marker, close_console = ARGV
    console = TelegrafConsole.new
    processes = StartupBoundary.new(console, marker, close_console == "true")
    TelegrafServiceWorker.new("prometheus", Logger.new(File::NULL), console, processes).run
  RUBY

  def setup
    skip "Native job containment requires Windows" unless Gem.win_platform?
  end

  def with_startup_boundary(close_console: false)
    Dir.mktmpdir("telegraf-job-test") do |directory|
      marker = File.join(directory, "child.pid")
      log_path = File.join(directory, "host.log")
      input, command = IO.pipe
      waiter = nil
      child = nil
      begin
        File.open(log_path, "w") do |log|
          host_pid = Process.spawn(
            RbConfig.ruby, "-e", HOST_SCRIPT,
            File.join(__dir__, "telegraf-windows-service.rb"),
            File.join(__dir__, "telegraf-windows-console.rb"),
            marker, close_console.to_s, in: input, out: log, err: log
          )
          waiter = Process.detach(host_pid)
        end
        input.close
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
        until File.exist?(marker) && !File.zero?(marker)
          break unless waiter.alive? && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
          sleep 0.02
        end
        assert File.exist?(marker) && !File.zero?(marker), "Host did not reach the startup boundary: #{File.read(log_path)}"
        child_pid = Integer(File.read(marker))
        child = TelegrafProcessObserver.OpenProcess(0x00100001, false, child_pid) # SYNCHRONIZE | TERMINATE.
        refute child.null?, "Cannot observe the owned fixture child"
        assert waiter.alive?, "Host exited before the startup boundary"
        assert_equal 258, TelegrafProcessObserver.WaitForSingleObject(child, 0), "Child should initially be alive"
        yield waiter, command
        assert waiter.join(5), "Host did not exit"
        assert_equal 0, TelegrafProcessObserver.WaitForSingleObject(child, 5000), "Child survived its host"
      ensure
        command.close unless command.closed?
        input.close unless input.closed?
        if waiter && waiter.alive?
          Process.kill("KILL", waiter.pid)
          waiter.join(5)
        end
        if child && !child.null?
          if TelegrafProcessObserver.WaitForSingleObject(child, 0) == 258
            TelegrafProcessObserver.TerminateProcess(child, 1)
            TelegrafProcessObserver.WaitForSingleObject(child, 5000)
          end
          TelegrafProcessObserver.CloseHandle(child)
        end
      end
    end
  end

  def test_host_killed_before_spawn_returns_cannot_orphan_child
    with_startup_boundary do |host, _|
      Process.kill("KILL", host.pid)
    end
  end

  def test_normal_host_exit_at_startup_boundary_cleans_up_child
    with_startup_boundary do |host, command|
      command.puts("exit")
      assert host.join(5), "Host did not exit normally"
      assert host.value.success?, "Normal host exit should complete its cleanup"
    end
  end

  def test_console_cleanup_keeps_job_alive_until_host_exit
    with_startup_boundary(close_console: true) do |host, command|
      command.puts("exit")
      assert host.join(5), "Host did not exit after console cleanup"
      assert host.value.success?, "Console cleanup must not kill the host"
    end
  end
end
