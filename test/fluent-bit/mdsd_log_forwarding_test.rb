require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"
require "json"

class MdsdLogForwardingTest < Minitest::Test
  REPO_ROOT = File.expand_path("../..", __dir__)
  CONF_DIR = File.join(REPO_ROOT, "build/linux/installer/conf")

  def setup
    @sandbox = Dir.mktmpdir("mdsd-diagnostics")
    @log_dir = File.join(@sandbox, "log")
    @state_dir = File.join(@sandbox, "state")
    FileUtils.mkdir_p([@log_dir, @state_dir])
    @pids = []
    @run = 0
    config = File.read(File.join(CONF_DIR, "fluent-bit-mdsd-diagnostics.conf"))
                 .gsub("/var/opt/microsoft/linuxmonagent/log", @log_dir)
                 .gsub("/var/opt/microsoft/docker-cimprov/state", @state_dir)
    File.write(File.join(@sandbox, "diagnostics.conf"), config)
    File.write(File.join(@sandbox, "fluent-bit.conf"), <<~CONF)
      [SERVICE]
          Flush 0.1
          Grace 1
      @INCLUDE diagnostics.conf
    CONF
  end

  def teardown
    @pids.each do |pid|
      begin
        Process.kill("KILL", pid)
      rescue Errno::ESRCH
        # A failed child may already have exited.
      end
      Process.wait(pid)
    end
    FileUtils.remove_entry(@sandbox)
  end

  def start_fluent_bit
    @run += 1
    @stdout = File.join(@sandbox, "stdout-#{@run}")
    @stderr = File.join(@sandbox, "stderr-#{@run}")
    pid = Process.spawn("fluent-bit", "-c", File.join(@sandbox, "fluent-bit.conf"),
                        out: @stdout, err: @stderr, chdir: @sandbox)
    @pids << pid
    pid
  end

  def stop(pid, signal = "TERM")
    Process.kill(signal, pid)
    _, status = Process.wait2(pid)
    @pids.delete(pid)
    assert status.success?, status.inspect if signal == "TERM"
  end

  def append(file, message)
    File.open(File.join(@log_dir, file), "a") { |output| output.puts(message) }
  end

  def records
    File.readlines(@stdout).filter_map do |line|
      JSON.parse(line).fetch("log") if line.end_with?("\n")
    end
  end

  def await_record(message)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    until records.include?(message)
      flunk "Missing #{message.inspect}: #{File.read(@stderr)}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
    assert_includes records, message
  end

  def test_only_errors_and_warnings_are_forwarded_including_late_files_and_rotation
    append("mdsd.err", "startup error")
    append("mdsd.info", "excluded info")
    append("mdsd.qos", "excluded qos")
    pid = start_fluent_bit
    await_record("startup error")
    append("mdsd.warn", "late warning")
    await_record("late warning")
    append("mdsd.err", "ongoing error")
    await_record("ongoing error")

    FileUtils.cp(File.join(@log_dir, "mdsd.err"), File.join(@log_dir, "mdsd.err.1"))
    File.truncate(File.join(@log_dir, "mdsd.err"), 0)
    sleep 2
    append("mdsd.err", "error after copytruncate")
    await_record("error after copytruncate")

    File.rename(File.join(@log_dir, "mdsd.warn"), File.join(@log_dir, "mdsd.warn.1"))
    append("mdsd.warn", "warning after replacement")
    await_record("warning after replacement")
    stop(pid)
    assert_equal ["startup error", "late warning", "ongoing error", "error after copytruncate", "warning after replacement"].sort, records.sort
    assert_equal "error after copytruncate\n", File.read(File.join(@log_dir, "mdsd.err"))
  end

  def test_position_database_resumes_after_process_exit_without_full_replay
    append("mdsd.err", "already forwarded error")
    append("mdsd.warn", "already forwarded warning")
    pid = start_fluent_bit
    await_record("already forwarded error")
    await_record("already forwarded warning")
    stop(pid, "KILL")
    append("mdsd.err", "error during downtime")
    append("mdsd.warn", "warning during downtime")
    pid = start_fluent_bit
    await_record("error during downtime")
    await_record("warning during downtime")
    stop(pid)
    assert_equal ["error during downtime", "warning during downtime"].sort, records.sort
  end

  def test_diagnostics_do_not_use_existing_telemetry_filters_or_output
    append("mdsd.err", "OtlpTokenFetcher AMACoreAgent tenant not started")
    existing = File.read(File.join(CONF_DIR, "fluent-bit-common.conf"))
                   .split(/(?=^\[(?:INPUT|FILTER|OUTPUT)\])/)
                   .select { |section| section.start_with?("[FILTER]") }
                   .join
    File.open(File.join(@sandbox, "fluent-bit.conf"), "a") do |file|
      file.puts(existing)
      file.puts <<~CONF
        [INPUT]
            Name dummy
            Tag oms.container.test
            Dummy {"log":"telemetry sentinel"}
            Samples 1
        [OUTPUT]
            Name file
            Match oms.container.*
            Path #{@sandbox}
            File telemetry
            Format plain
      CONF
    end
    pid = start_fluent_bit
    await_record("OtlpTokenFetcher AMACoreAgent tenant not started")
    telemetry_path = File.join(@sandbox, "telemetry")
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    until File.exist?(telemetry_path) && File.read(telemetry_path).include?("telemetry sentinel")
      flunk "Telemetry fixture did not flush: #{File.read(@stderr)}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
    stop(pid)
    telemetry = File.read(telemetry_path)
    assert_includes telemetry, "telemetry sentinel"
    refute_includes telemetry, "AMACoreAgent", "diagnostics must not be sent directly to the telemetry output"
  end

  def test_full_role_configurations_load_with_forwarding_disabled_or_enabled
    scripts = File.join(REPO_ROOT, "build/common/installer/scripts")
    conf_dir = File.join(@sandbox, "conf")
    customizer = File.join(@sandbox, "customizer.rb")
    File.write(customizer, File.read(File.join(scripts, "fluent-bit-conf-customizer.rb"))
                              .gsub("/etc/opt/microsoft/docker-cimprov", conf_dir))
    FileUtils.cp(File.join(scripts, "ConfigParseErrorLogger.rb"), @sandbox)
    configure = File.read(File.join(REPO_ROOT, "kubernetes/linux/main.sh"))
                    .match(/^configureMdsdLogForwarding\(\) \{$.*?^\}/m)[0]
                    .gsub("/etc/opt/microsoft/docker-cimprov", conf_dir)
    env = {
      "OS_TYPE" => "linux", "AZMON_LOG_TAIL_PATH" => "#{@log_dir}/*.log",
      "AZMON_LOG_EXCLUSION_REGEX_PATTERN" => "excluded-stream",
      "FBIT_SERVICE_GRACE_INTERVAL_SECONDS" => "1",
      "GENEVA_TELEMETRY_SERVICE_POD_NAMESPACE" => "test",
    }
    %w[AZMON_FBIT_CHUNK_SIZE AZMON_FBIT_BUFFER_SIZE AZMON_FBIT_MEM_BUF_LIMIT
       AZMON_SIDECAR_FBIT_CHUNK_SIZE AZMON_SIDECAR_FBIT_BUFFER_SIZE AZMON_SIDECAR_FBIT_MEM_BUF_LIMIT
       FBIT_INPUT_FORWARD_BUFFER_CHUNK_SIZE FBIT_INPUT_FORWARD_BUFFER_CHUNK_MAX_SIZE
       AZMON_MULTI_TENANCY_SVC_BUFFER_CHUNK_SIZE AZMON_MULTI_TENANCY_SVC_BUFFER_MAX_SIZE].each { |key| env[key] = "1m" }
    [nil, "true"].each do |enabled|
      FileUtils.mkdir_p(conf_dir)
      FileUtils.cp(Dir[File.join(CONF_DIR, "*.conf")], conf_dir)
      _, error, status = Open3.capture3({ "AZMON_MDSD_LOG_FORWARDING_ENABLED" => enabled },
                                       "bash", "-c", "#{configure}\nconfigureMdsdLogForwarding")
      assert status.success?, error
      _, error, status = Open3.capture3(env, RbConfig.ruby, customizer)
      assert status.success?, error
      %w[fluent-bit fluent-bit-prom-side-car fluent-bit-rs fluent-bit-geneva-telemetry-svc fluent-bit-azmon-logs-svc].each do |role|
        output, error, status = Open3.capture3(env, "fluent-bit", "--dry-run", "-c",
                                              File.join(conf_dir, "#{role}.conf"), "-e", "/opt/fluent-bit/bin/out_oms.so")
        assert status.success?, "#{role}, forwarding=#{enabled.inspect}: #{output}\n#{error}"
      end
    end
  end

  def named_process(name)
    pid = Process.spawn(RbConfig.ruby, "-e", 'Signal.trap("TERM") { exit }; Process.setproctitle(ARGV.fetch(0)); sleep 300', name,
                        out: File::NULL, err: File::NULL)
    @pids << pid
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    until Open3.capture2("pgrep", "-x", name).first.lines.map(&:to_i).include?(pid)
      flunk "Process #{name} did not start" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.01
    end
    pid
  end

  def probe(role, controller: "DaemonSet", muted: false)
    env_file = File.join(@sandbox, "env_vars")
    File.write(env_file, "")
    dcr = File.join(@sandbox, "dcr-config-parser.rb")
    File.write(dcr, "")
    File.write(File.join(@sandbox, "dcr_env_var"), "")
    source = File.read(File.join(REPO_ROOT, "build/linux/installer/scripts/livenessprobe.sh"))
                 .gsub("/opt/env_vars", env_file)
                 .gsub("/opt/dcr-config-parser.rb", dcr)
                 .gsub("/opt/dcr_env_var", File.join(@sandbox, "dcr_env_var"))
                 .gsub("/dev/termination-log", File.join(@sandbox, "termination-log"))
                 .gsub("/dev/write-to-traces", File.join(@sandbox, "write-to-traces"))
    path = File.join(@sandbox, "probe.sh")
    File.write(path, source)
    env = {
      "CONTROLLER_TYPE" => controller, "CONTAINER_TYPE" => role, "MUTE_PROM_SIDECAR" => muted.to_s,
      "LOGS_AND_EVENTS_ONLY" => "true", "AZMON_RESOURCE_OPTIMIZATION_ENABLED" => "true",
      "GENEVA_LOGS_INTEGRATION_SERVICE_MODE" => "true", "AZMON_MDSD_LOG_FORWARDING_ENABLED" => "true",
    }
    _, _, status = Open3.capture3(env, "bash", path, chdir: @sandbox)
    status
  end

  def test_liveness_checks_daemon_identity_while_diagnostics_and_a_misleading_tail_run
    pid = start_fluent_bit
    append("mdsd.err", "forwarding active")
    await_record("forwarding active")
    tail = Process.spawn("tail", "-f", File.join(@log_dir, "mdsd.err"), out: File::NULL, err: File::NULL)
    @pids << tail
    mdsd = named_process("mdsd")
    roles = [["main", "DaemonSet"], ["PrometheusSidecar", "DaemonSet"], ["main", "ReplicaSet"]]
    roles.each { |role, controller| assert probe(role, controller: controller).success?, role }
    stop(mdsd)
    roles.each do |role, controller|
      refute probe(role, controller: controller).success?, role
      assert_equal "mdsd is not running\n", File.read(File.join(@sandbox, "termination-log"))
    end
    assert probe("PrometheusSidecar", muted: true).success?
    append("mdsd.warn", "forwarding still active")
    await_record("forwarding still active")
    stop(pid)
  end
end
