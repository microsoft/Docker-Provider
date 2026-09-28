require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "open3"

class MainStartupTest < Minitest::Test
  MAIN_PATH = File.expand_path("main.sh", __dir__)
  WINDOWS_BASH = "C:/Program Files/Git/bin/bash.exe"

  def setup
    @sandbox = Dir.mktmpdir("main-startup-test")
    @mdsd_log = File.join(@sandbox, "mdsd")
    FileUtils.mkdir_p(@mdsd_log)
  end

  def teardown
    FileUtils.remove_entry(@sandbox) if @sandbox && File.exist?(@sandbox)
  end

  def bash_path
    return "/bin/bash" if File.exist?("/bin/bash")
    return WINDOWS_BASH if File.exist?(WINDOWS_BASH)

    raise "bash is required to run main.sh tests"
  end

  def shell_path(path)
    path.tr("\\", "/")
  end

  def function_source(name)
    lines = File.readlines(MAIN_PATH)
    start = lines.index { |line| line.start_with?("#{name}()") }
    raise "function #{name} not found" unless start

    finish = ((start + 1)...lines.length).find { |index| lines[index] == "}\n" }
    raise "end of function #{name} not found" unless finish

    lines[start..finish].join
  end

  def run_onboarding(info: nil, error: nil, live_process: true)
    File.write(File.join(@mdsd_log, "mdsd.info"), info.to_s)
    File.write(File.join(@mdsd_log, "mdsd.err"), error.to_s)
    script = <<~SH
      #{function_source("checkAgentOnboardingStatus")}
      isGenevaMode() { false; }
      MDSD_LOG="#{shell_path(@mdsd_log)}"
      if #{live_process ? "sleep 30 & MDSD_PID=$!" : "MDSD_PID=99999999"}; then
        checkAgentOnboardingStatus true
        status=$?
      fi
      #{live_process ? "kill \"$MDSD_PID\" 2>/dev/null || true" : ""}
      exit "$status"
    SH
    Open3.capture3(bash_path, "-c", script, chdir: @sandbox)
  end

  def run_dcr_parser(parser_status: 0, parser_value: "true", write_output: true)
    bin_dir = File.join(@sandbox, "bin")
    tmp_dir = File.join(@sandbox, "tmp")
    FileUtils.mkdir_p([bin_dir, tmp_dir])
    parser = File.join(bin_dir, "ruby")
    File.write(
      parser,
      <<~SH
        #!/bin/bash
        output="${!#}"
        if [ "${WRITE_OUTPUT}" == "true" ]; then
          printf '%s\\n' "${PARSER_VALUE}" > "$output"
        fi
        exit "${PARSER_STATUS}"
      SH
    )
    FileUtils.chmod(0o755, parser)
    script = <<~SH
      #{function_source("cleanupDcrOutput")}
      #{function_source("parseDcrConfig")}
      DCR_OUTPUT_FILE=""
      DCR_VALUE=""
      parseDcrConfig
      status=$?
      printf '%s\\n' "$DCR_VALUE"
      printf '%s\\n' "$DCR_OUTPUT_FILE"
      exit "$status"
    SH
    Open3.capture3(
      {
        "PATH" => "#{shell_path(bin_dir)}:#{ENV.fetch("PATH")}",
        "TMPDIR" => shell_path(tmp_dir),
        "PARSER_STATUS" => parser_status.to_s,
        "PARSER_VALUE" => parser_value,
        "WRITE_OUTPUT" => write_output.to_s,
      },
      bash_path,
      "-c",
      script,
      chdir: @sandbox
    ).then { |stdout, stderr, status| [stdout.lines.map(&:chomp), stderr, status, tmp_dir] }
  end

  def run_set_global_env_var(env_path)
    function = function_source("setGlobalEnvVar").gsub("/opt/env_vars", shell_path(env_path))
    Open3.capture3(
      bash_path,
      "-c",
      "#{function}\nsetGlobalEnvVar TEST_VALUE expected",
      chdir: @sandbox
    )
  end

  def dcr_required?(overrides)
    defaults = {
      "CONTROLLER_TYPE" => "DaemonSet",
      "CONTAINER_TYPE" => "",
      "AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE" => "false",
      "GENEVA_LOGS_INTEGRATION_SERVICE_MODE" => "false",
      "GENEVA_LOGS_INTEGRATION" => "false",
      "USING_AAD_MSI_AUTH" => "false",
      "AZMON_MULTI_TENANCY_LOG_COLLECTION" => "false",
    }
    assignments = defaults.merge(overrides).map do |name, value|
      "#{name}=#{value.to_s.inspect}"
    end.join("\n")
    script = <<~SH
      #{function_source("isDcrRequired")}
      #{assignments}
      isDcrRequired
    SH
    _, _, status = Open3.capture3(bash_path, "-c", script, chdir: @sandbox)
    status.success?
  end

  def test_dcr_requirement_matches_configuration_modes
    refute dcr_required?("AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE" => "true")
    assert dcr_required?("USING_AAD_MSI_AUTH" => "true")
    refute dcr_required?({})
    assert dcr_required?(
      "GENEVA_LOGS_INTEGRATION" => "true",
      "AZMON_MULTI_TENANCY_LOG_COLLECTION" => "true"
    )
    assert dcr_required?(
      "GENEVA_LOGS_INTEGRATION" => "true",
      "AZMON_MULTI_TENANCY_LOG_COLLECTION" => "true",
      "USING_AAD_MSI_AUTH" => "true"
    )
    refute dcr_required?("GENEVA_LOGS_INTEGRATION" => "true")
    refute dcr_required?(
      "USING_AAD_MSI_AUTH" => "true",
      "GENEVA_LOGS_INTEGRATION_SERVICE_MODE" => "true"
    )
    refute dcr_required?(
      "USING_AAD_MSI_AUTH" => "true",
      "CONTROLLER_TYPE" => "ReplicaSet"
    )
    refute dcr_required?(
      "USING_AAD_MSI_AUTH" => "true",
      "CONTAINER_TYPE" => "PrometheusSidecar"
    )
  end

  def test_onboarding_succeeds_after_authoritative_success
    _, stderr, status = run_onboarding(info: "Loaded data sources\n")

    assert status.success?, stderr
  end

  def test_onboarding_fails_after_authoritative_failure
    _, _, status = run_onboarding(error: "Failed to load data sources into config\n")

    refute status.success?
  end

  def test_onboarding_failure_takes_precedence_over_success
    _, _, status = run_onboarding(
      info: "Loaded data sources\n",
      error: "Failed to load data sources into config\n"
    )

    refute status.success?
  end

  def test_onboarding_fails_when_mdsd_terminates_before_reporting_success
    stdout, _, status = run_onboarding(live_process: false)

    refute status.success?
    assert_includes stdout, "mdsd terminated before onboarding completed"
  end

  def test_main_exits_when_onboarding_fails
    source = File.read(MAIN_PATH)

    refute_match(/checkAgentOnboardingStatus\s+\$AAD_MSI_AUTH_MODE\s+30/, source)
    assert_match(
      /if \[ "\$\{CONTROLLER_TYPE\}" == "DaemonSet" \] && \[ -z "\$\{CONTAINER_TYPE\}" \]; then\s+if ! checkAgentOnboardingStatus "\$\{AAD_MSI_AUTH_MODE\}"; then\s+exit 1\s+fi/,
      source
    )
    assert_match(
      /elif \[ "\$\{MUTE_PROM_SIDECAR\}" != "true" \]; then\s+checkAgentOnboardingStatus "\$\{AAD_MSI_AUTH_MODE\}" 30/,
      source
    )
  end

  def test_parse_dcr_config_returns_valid_value_and_removes_temporary_output
    output, stderr, status, tmp_dir = run_dcr_parser

    assert status.success?, stderr
    assert_equal ["true", ""], output
    assert_empty Dir.glob(File.join(tmp_dir, "dcr_env_var.*"))
  end

  def test_parse_dcr_config_rejects_invalid_output_and_removes_temporary_output
    output, _, status, tmp_dir = run_dcr_parser(parser_value: "invalid")

    refute status.success?
    assert_equal ["invalid", ""], output
    assert_empty Dir.glob(File.join(tmp_dir, "dcr_env_var.*"))
  end

  def test_parse_dcr_config_rejects_trailing_output_content
    _, _, status, tmp_dir = run_dcr_parser(parser_value: "true\ninvalid")

    refute status.success?
    assert_empty Dir.glob(File.join(tmp_dir, "dcr_env_var.*"))
  end

  def test_parse_dcr_config_rejects_empty_output
    _, _, status, tmp_dir = run_dcr_parser(write_output: false)

    refute status.success?
    assert_empty Dir.glob(File.join(tmp_dir, "dcr_env_var.*"))
  end

  def test_parse_dcr_config_propagates_parser_failure_and_removes_temporary_output
    _, _, status, tmp_dir = run_dcr_parser(parser_status: 23)

    refute status.success?
    assert_empty Dir.glob(File.join(tmp_dir, "dcr_env_var.*"))
  end

  def test_set_global_env_var_fails_when_state_cannot_be_written
    _, _, status = run_set_global_env_var(File.join(@sandbox, "missing", "env_vars"))

    refute status.success?
  end

  def test_shutdown_trap_is_installed_before_mdsd_starts
    source = File.read(MAIN_PATH)

    assert_operator source.index("trap shutdown SIGTERM"), :<, source.index("\n      mdsd ")
  end

  def test_environment_state_file_is_hardened_in_population_order
    source = File.read(MAIN_PATH)
    umask = source.index("umask 077")
    creation = source.index(": > /opt/env_vars")
    read_only = source.index("chmod 400 /opt/env_vars")
    last_population = source.rindex("setGlobalEnvVar AZMON_RETINA_FLOW_LOGS_ENABLED")

    assert_operator umask, :<, creation
    assert_operator creation, :<, last_population
    assert_operator last_population, :<, read_only
  end

  def test_main_does_not_use_persistent_dcr_parser_output
    refute_includes File.read(MAIN_PATH), "/opt/dcr_env_var"
  end
end
