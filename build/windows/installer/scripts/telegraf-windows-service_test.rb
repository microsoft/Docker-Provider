require "minitest/autorun"
require_relative "telegraf-windows-service"

class TelegrafServiceWorkerTest < Minitest::Test
  class Waiter
    attr_reader :waits

    def initialize
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @finished = false
      @waits = []
    end

    def finish
      @mutex.synchronize do
        @finished = true
        @condition.broadcast
      end
    end

    def alive?
      @mutex.synchronize { !@finished }
    end

    def join(timeout)
      @waits << timeout
      alive? ? nil : self
    end

    def value
      @mutex.synchronize { @condition.wait(@mutex) until @finished }
      "exit 0"
    end
  end

  class Processes
    attr_reader :started, :waiter, :kills, :command, :options

    def initialize
      @started = Queue.new
      @waiter = Waiter.new
      @kills = []
    end

    def spawn(*command, **options)
      @command, @options = command, options
      options[:out].puts("fixture log")
      @started << true
      123
    end

    def detach(pid)
      raise "wrong PID" unless pid == 123
      @waiter
    end

    def kill(signal, pid)
      @kills << [signal, pid]
      @waiter.finish
    end

    def waitpid(pid, flags = nil)
      return nil if flags && @waiter.alive?
      @waiter.value
      pid
    end
  end

  class Console
    attr_accessor :signal_result, :complete_on_interrupt, :fail_attach
    attr_reader :prepared, :closed, :attached, :interrupted

    def initialize(processes)
      @processes = processes
      @signal_result = true
      @complete_on_interrupt = true
    end

    def prepare
      @prepared = true
    end

    def attach(pid)
      raise Errno::EACCES, "job fixture" if @fail_attach
      @attached = pid
    end

    def interrupt(pid)
      @interrupted = pid
      @processes.waiter.finish if @complete_on_interrupt
      @signal_result
    end

    def close
      @closed = true
    end
  end

  def setup
    @processes = Processes.new
    @console = Console.new(@processes)
    @logger = Logger.new(File::NULL)
    @worker = TelegrafServiceWorker.new("prometheus", @logger, @console, @processes)
  end

  def teardown
    @processes.waiter.finish
    @thread.join(1) if @thread && @thread.alive?
    @logger.close
  end

  def start_worker
    @thread = Thread.new { @worker.run }
    @thread.report_on_exception = false
    @processes.started.pop
  end

  def test_graceful_stop_keeps_stock_binary_and_configuration
    start_worker
    @worker.stop
    @thread.value
    assert_equal [TelegrafServiceWorker::EXECUTABLE, "--console", "--config", 'C:\etc\telegraf\telegraf.conf'], @processes.command
    assert @processes.options[:new_pgroup]
    assert @console.prepared
    assert_equal 123, @console.attached
    assert_equal 123, @console.interrupted
    assert_empty @processes.kills
    assert @console.closed
  end

  def test_stop_deadline_kills_only_owned_child
    @console.complete_on_interrupt = false
    start_worker
    @worker.stop
    @thread.value
    assert_equal [20, 5], @processes.waiter.waits
    assert_equal [["KILL", 123]], @processes.kills
  end

  def test_failed_signal_kills_only_owned_child
    @console.signal_result = false
    @console.complete_on_interrupt = false
    start_worker
    @worker.stop
    @thread.value
    assert_equal [["KILL", 123]], @processes.kills
    assert_equal [5], @processes.waiter.waits
  end

  def test_unexpected_clean_child_exit_is_a_service_failure
    start_worker
    @processes.waiter.finish
    assert_raises(TelegrafServiceWorker::UnexpectedExit) { @thread.value }
    assert @console.closed
  end

  def test_job_assignment_failure_does_not_leave_an_unmanaged_process
    @console.fail_attach = true
    assert_raises(Errno::EACCES) { @worker.run }
    assert_equal [["KILL", 123]], @processes.kills
    assert @console.closed
  end

  def test_stop_before_start_does_not_launch_a_child
    @worker.stop
    @worker.run
    assert_nil @processes.command
  end

  def test_process_metrics_role_uses_its_existing_configuration
    @worker = TelegrafServiceWorker.new("process-metrics", @logger, @console, @processes)
    start_worker
    @worker.stop
    @thread.value
    assert_equal 'C:\etc\telegraf\telegraf-ama-logs-process-metrics.conf', @processes.command.last
  end

  def test_unknown_role_is_rejected
    assert_raises(KeyError) { TelegrafServiceWorker.new("unexpected", @logger, @console) }
  end
end
