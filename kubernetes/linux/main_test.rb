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

  def dcr_output_setup_source
    lines = File.readlines(MAIN_PATH)
    start = lines.index { |line| line.start_with?("dcrOutputFile=$(mktemp ") }
    raise "DCR output setup not found" unless start

    finish = ((start + 1)...lines.length).find { |index| lines[index] == "}\n" }
    raise "end of DCR output setup not found" unless finish

    lines[start..finish].join
  end

  def dcr_startup_source
    lines = File.readlines(MAIN_PATH)
    start = lines.index { |line| line == "if [ \"${DCR_REQUIRED}\" == \"true\" ]; then\n" }
    raise "DCR startup block not found" unless start

    finish = ((start + 1)...lines.length).find { |index| lines[index] == "fi\n" }
    raise "end of DCR startup block not found" unless finish

    lines[start..finish].join
  end

  def run_onboarding(info: nil, error: nil, live_process: true, success_after_sleeps: nil)
    File.write(File.join(@mdsd_log, "mdsd.info"), info.to_s)
    File.write(File.join(@mdsd_log, "mdsd.err"), error.to_s)
    script = <<~SH
      #{function_source("checkAgentOnboardingStatus")}
      isGenevaMode() { false; }
      MDSD_LOG="#{shell_path(@mdsd_log)}"
      #{success_after_sleeps ? <<~SLEEP : ""}
        sleepCalls=0
        sleep() {
          sleepCalls=$((sleepCalls + 1))
          if [ "$sleepCalls" -eq #{success_after_sleeps} ]; then
            echo "Loaded data sources" > "$MDSD_LOG/mdsd.info"
          fi
        }
      SLEEP
      status=1
      if #{live_process ? "command sleep 30 & mdsdPid=$!" : "mdsdPid=99999999"}; then
        checkAgentOnboardingStatus true "$mdsdPid"
        status=$?
      fi
      #{live_process ? "kill \"$mdsdPid\" 2>/dev/null || true" : ""}
      #{success_after_sleeps ? "echo SLEEP_CALLS=$sleepCalls" : ""}
      exit "$status"
    SH
    Open3.capture3(bash_path, "-c", script, chdir: @sandbox)
  end

  def run_dcr_parser(
    parser_status: 0,
    parser_value: "true",
    parser_error: "",
    write_output: true,
    append_output: false,
    existing_output: nil,
    nul_output: false,
    append_newline: true
  )
    bin_dir = File.join(@sandbox, "bin")
    output_file = File.join(@sandbox, "dcr-output")
    FileUtils.mkdir_p(bin_dir)
    File.write(output_file, existing_output) unless existing_output.nil?
    parser = File.join(bin_dir, "ruby")
    File.write(
      parser,
      <<~SH
        #!/bin/bash
        output="${!#}"
        if [ "${NUL_OUTPUT}" == "true" ]; then
          printf 'true\\n\\0invalid\\n' > "$output"
        elif [ "${WRITE_OUTPUT}" == "true" ]; then
          if [ "${APPEND_OUTPUT}" == "true" ]; then
            printf '%s\\n' "${PARSER_VALUE}" >> "$output"
          elif [ "${APPEND_NEWLINE}" == "true" ]; then
            printf '%s\\n' "${PARSER_VALUE}" > "$output"
          else
            printf '%s' "${PARSER_VALUE}" > "$output"
          fi
        fi
        printf '%s' "${PARSER_ERROR}" >&2
        exit "${PARSER_STATUS}"
      SH
    )
    FileUtils.chmod(0o755, parser)
    script = <<~SH
      #{function_source("parseDcrConfig")}
      dcrValue=""
      parseDcrConfig "#{shell_path(output_file)}" dcrValue
      status=$?
      printf 'VALIDATED=%s' "$dcrValue"
      exit "$status"
    SH
    stdout, stderr, status = Open3.capture3(
      {
        "PATH" => "#{shell_path(bin_dir)}:#{ENV.fetch("PATH")}",
        "PARSER_STATUS" => parser_status.to_s,
        "PARSER_VALUE" => parser_value,
        "PARSER_ERROR" => parser_error,
        "WRITE_OUTPUT" => write_output.to_s,
        "APPEND_OUTPUT" => append_output.to_s,
        "NUL_OUTPUT" => nul_output.to_s,
        "APPEND_NEWLINE" => append_newline.to_s,
      },
      bash_path,
      "-c",
      script,
      chdir: @sandbox
    )
    [File.exist?(output_file) ? File.read(output_file) : nil, stdout, stderr, status]
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

  def test_parse_dcr_config_fails_when_output_cannot_be_truncated
    missing_output = File.join(@sandbox, "missing", "dcr-output")
    script = <<~SH
      #{function_source("parseDcrConfig")}
      parseDcrConfig "#{shell_path(missing_output)}" dcrValue
    SH

    stdout, _, status = Open3.capture3(bash_path, "-c", script, chdir: @sandbox)

    refute status.success?
    assert_includes stdout, "Failed to empty DCR parser output file"
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

    assert_match(
      /if \[ "\$\{MUTE_PROM_SIDECAR\}" != "true" \]; then\s+if ! checkAgentOnboardingStatus "\$\{AAD_MSI_AUTH_MODE\}" "\$\{mdsdPid\}"; then\s+exit 1\s+fi/,
      source
    )
  end

  def test_onboarding_wait_has_no_timeout_or_periodic_output
    source = function_source("checkAgentOnboardingStatus")

    refute_includes source, "waittimesecs"
    refute_includes source, "totalsleptsecs"
    refute_includes source, "Waiting for mdsd onboarding"
  end

  def test_onboarding_remains_active_beyond_former_timeout
    stdout, stderr, status = run_onboarding(success_after_sleeps: 31)

    assert status.success?, stderr
    assert_includes stdout, "SLEEP_CALLS=31"
  end

  def test_parse_dcr_config_accepts_literal_value
    output, stdout, stderr, status = run_dcr_parser

    assert status.success?, stderr
    assert_equal "true\n", output
    assert_equal "VALIDATED=true", stdout
  end

  def test_parse_dcr_config_rejects_invalid_value
    _, stdout, _, status = run_dcr_parser(parser_value: "invalid")

    refute status.success?
    assert_includes stdout, "DCR parser output is invalid"
    assert stdout.end_with?("VALIDATED=")
  end

  def test_parse_dcr_config_accepts_false_value
    output, stdout, stderr, status = run_dcr_parser(parser_value: "false")

    assert status.success?, stderr
    assert_equal "false\n", output
    assert_equal "VALIDATED=false", stdout
  end

  def test_parse_dcr_config_rejects_missing_newline
    _, _, _, status = run_dcr_parser(append_newline: false)

    refute status.success?
  end

  def test_parse_dcr_config_rejects_false_without_newline
    _, _, _, status = run_dcr_parser(parser_value: "false", append_newline: false)

    refute status.success?
  end

  def test_parse_dcr_config_rejects_trailing_content
    _, _, _, status = run_dcr_parser(parser_value: "true\ninvalid")

    refute status.success?
  end

  def test_parse_dcr_config_rejects_trailing_blank_line
    _, _, _, status = run_dcr_parser(parser_value: "true\n")

    refute status.success?
  end

  def test_parse_dcr_config_rejects_nul_delimited_suffix
    _, stdout, _, status = run_dcr_parser(nul_output: true)

    refute status.success?
    assert stdout.end_with?("VALIDATED=")
  end

  def test_parse_dcr_config_rejects_empty_output
    _, _, _, status = run_dcr_parser(write_output: false)

    refute status.success?
  end

  def test_parse_dcr_config_propagates_parser_failure
    _, _, stderr, status = run_dcr_parser(
      parser_status: 23,
      parser_error: "parser failed"
    )

    refute status.success?
    assert_includes stderr, "parser failed"
  end

  def test_parse_dcr_config_truncates_reused_output_before_parsing
    output, _, stderr, status = run_dcr_parser(
      append_output: true,
      existing_output: "stale\n"
    )

    assert status.success?, stderr
    assert_equal "true\n", output
  end

  def test_main_uses_one_script_lifetime_parser_output_and_cleanup_trap
    source = File.read(MAIN_PATH)

    assert_equal 1, source.scan(/mktemp .*dcr_env_var/).length
    assert_match(/dcrOutputFile=.*mktemp/, source)
    assert_match(/trap 'shutdown \$\?' EXIT/, source)
    assert_match(/trap 'shutdown 0' TERM INT HUP QUIT/, source)
    assert_includes function_source("shutdown"), 'rm -f -- "${dcrOutputFile}"'
    refute_match(/\bDCR_(?:OUTPUT_FILE|VALUE|ERROR)\b/, source)
  end

  def test_main_retries_then_persists_only_validated_dcr_with_diagnostics
    script = <<~SH
      parseDcrConfig() {
        attempts=$((attempts + 1))
        echo "parser stdout diagnostic"
        echo "parser stderr diagnostic" >&2
        if [ "$attempts" -eq 1 ]; then
          return 1
        fi
        printf -v "$2" '%s' false
      }
      sleep() { :; }
      setGlobalEnvVar() { printf '%s=%s\\n' "$1" "$2"; }
      attempts=0
      DCR_REQUIRED=true
      dcrOutputFile=/tmp/unused
      #{dcr_startup_source}
      printf 'ATTEMPTS=%s\\n' "$attempts"
    SH

    stdout, stderr, status = Open3.capture3(bash_path, "-c", script, chdir: @sandbox)

    assert status.success?, stderr
    assert_equal(
      "parser stdout diagnostic\nparser stdout diagnostic\nLOGS_AND_EVENTS_ONLY=false\nATTEMPTS=2\n",
      stdout
    )
    assert_equal "parser stderr diagnostic\nparser stderr diagnostic\n", stderr
  end

  def test_main_fails_when_dcr_output_file_cannot_be_created
    script = <<~SH
      mktemp() { return 1; }
      #{dcr_output_setup_source}
    SH

    stdout, _, status = Open3.capture3(bash_path, "-c", script, chdir: @sandbox)

    refute status.success?
    assert_includes stdout, "Failed to create DCR parser output file"
  end

  def test_set_global_env_var_fails_when_state_cannot_be_written
    _, _, status = run_set_global_env_var(File.join(@sandbox, "missing", "env_vars"))

    refute status.success?
  end

  def test_shutdown_trap_is_installed_before_mdsd_starts
    source = File.read(MAIN_PATH)

    assert_operator source.index("trap 'shutdown $?\' EXIT"), :<, source.index("\n      mdsd ")
    assert_operator source.index("trap 'shutdown 0' TERM INT HUP QUIT"), :<, source.index("\n      mdsd ")
  end

  def test_shutdown_traps_remove_output_and_preserve_expected_status
    trap_source = File.readlines(MAIN_PATH).grep(/^trap 'shutdown/)

    [false, true].each do |service_mode|
      {
        "exit 7" => 7,
        "(command sleep 0.1; kill -TERM $$) & wait" => 0,
      }.each do |action, expected_status|
        output_file = File.join(@sandbox, "dcr-output")
        events_file = File.join(@sandbox, "shutdown-events")
        File.write(output_file, "private")
        FileUtils.rm_f(events_file)
        script = <<~SH
          #{function_source("shutdown")}
          pkill() { echo "PKILL:$2" >> "#{shell_path(events_file)}"; }
          isHighLogScaleMode() { false; }
          gracefulShutdown() { echo "GRACEFUL" >> "#{shell_path(events_file)}"; }
          dcrOutputFile="#{shell_path(output_file)}"
          GENEVA_LOGS_INTEGRATION_SERVICE_MODE=#{service_mode}
          AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE=false
          #{trap_source.join}
          #{action}
        SH

        _, stderr, status = Open3.capture3(bash_path, "-c", script, chdir: @sandbox)

        assert_equal expected_status, status.exitstatus, stderr
        refute File.exist?(output_file)
        expected_event = service_mode ? "GRACEFUL\n" : "PKILL:mdsd\n"
        assert_equal expected_event, File.read(events_file)
      end
    end
  end

  def test_onboarding_requires_mdsd_pid
    script = <<~SH
      #{function_source("checkAgentOnboardingStatus")}
      checkAgentOnboardingStatus true ""
    SH

    stdout, _, status = Open3.capture3(bash_path, "-c", script, chdir: @sandbox)

    refute status.success?
    assert_includes stdout, "mdsd PID"
  end

  def test_onboarding_requires_authentication_mode
    script = <<~SH
      #{function_source("checkAgentOnboardingStatus")}
      checkAgentOnboardingStatus "" "123"
    SH

    stdout, _, status = Open3.capture3(bash_path, "-c", script, chdir: @sandbox)

    refute status.success?
    assert_includes stdout, "authentication mode"
  end

  def test_environment_state_file_is_hardened_in_population_order
    source = File.read(MAIN_PATH)
    umask = source.index("umask 077")
    creation = source.index(": > /opt/env_vars")
    parser_output = source.index("mktemp")
    read_only = source.index("chmod 400 /opt/env_vars")
    last_population = source.rindex("setGlobalEnvVar AZMON_RETINA_FLOW_LOGS_ENABLED")

    assert_operator umask, :<, creation
    assert_operator umask, :<, parser_output
    assert_operator creation, :<, last_population
    assert_operator last_population, :<, read_only
  end

  def test_main_does_not_use_persistent_dcr_parser_output
    refute_includes File.read(MAIN_PATH), "/opt/dcr_env_var"
  end
end
