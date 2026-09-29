require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "open3"

class LivenessProbeTest < Minitest::Test
  SCRIPTS_DIR = File.expand_path(__dir__)
  PROBE_PATH = File.join(SCRIPTS_DIR, "livenessprobe.sh")
  WINDOWS_BASH = "C:/Program Files/Git/bin/bash.exe"

  def setup
    @sandbox = Dir.mktmpdir("livenessprobe-test")
    @bin_dir = File.join(@sandbox, "bin")
    @opt_dir = File.join(@sandbox, "opt")
    @dev_dir = File.join(@sandbox, "dev")
    @tmp_dir = File.join(@sandbox, "tmp")
    @state_dir = File.join(@sandbox, "state")
    @config_chunks = File.join(@sandbox, "configchunks")
    @mdsd_run_dir = File.join(@sandbox, "mdsd-ci")
    [@bin_dir, @opt_dir, @dev_dir, @tmp_dir, @state_dir, @config_chunks].each do |dir|
      FileUtils.mkdir_p(dir)
    end

    @parser_sentinel = File.join(@sandbox, "parser-invoked")
    @env_file = File.join(@opt_dir, "env_vars")
    @termination_log = File.join(@dev_dir, "termination-log")

    write_executable(
      File.join(@bin_dir, "ruby"),
      <<~SH
        #!/bin/bash
        touch "$PARSER_SENTINEL"
        if [ "${PARSER_STATUS}" != "0" ]; then
          exit "${PARSER_STATUS}"
        fi
        if [ "$#" -lt 2 ]; then
          exit 97
        fi
        output="${!#}"
        if "${APPEND_NEWLINE:-false}"; then
          newline=$'\\n'
        else
          newline=""
        fi
        printf '%s%s' "${PARSER_VALUE}" "${newline}" > "$output"
      SH
    )
    write_executable(
      File.join(@bin_dir, "ps"),
      <<~SH
        #!/bin/bash
        echo "root 10 1 0 mdsd"
        echo "root 11 1 0 fluent-bit"
      SH
    )

    script = File.read(PROBE_PATH)
                 .sub("#!/bin/bash", "#!/bin/bash\nPATH=\"#{msys_path(@bin_dir)}:$PATH\"")
                 .gsub("/opt/env_vars", shell_path(@env_file))
                 .gsub("/opt/dcr-config-parser.rb", shell_path(File.join(@opt_dir, "dcr-config-parser.rb")))
                 .gsub("/dev/write-to-traces", shell_path(File.join(@dev_dir, "write-to-traces")))
                 .gsub("/dev/termination-log", shell_path(@termination_log))
                 .gsub("/var/opt/microsoft/docker-cimprov/state", shell_path(@state_dir))
                 .gsub("/etc/mdsd.d/config-cache/configchunks", shell_path(@config_chunks))
                 .gsub("/var/run/mdsd-ci", shell_path(@mdsd_run_dir))
    @probe = File.join(@sandbox, "livenessprobe.sh")
    File.write(@probe, script)
    FileUtils.chmod(0o755, @probe)
  end

  def teardown
    FileUtils.remove_entry(@sandbox) if @sandbox && File.exist?(@sandbox)
  end

  def shell_path(path)
    path.tr("\\", "/")
  end

  def msys_path(path)
    normalized = shell_path(path)
    return normalized unless normalized.match?(/\A[A-Za-z]:\//)

    "/#{normalized[0].downcase}#{normalized[2..]}"
  end

  def bash_path
    return "/bin/bash" if File.exist?("/bin/bash")
    return WINDOWS_BASH if File.exist?(WINDOWS_BASH)

    raise "bash is required to run liveness probe tests"
  end

  def write_executable(path, contents)
    File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o755) do |file|
      file.write(contents)
    end
  end

  def write_environment(dcr_required:, initial_value:)
    File.write(
      @env_file,
      <<~SH
        export CONTROLLER_TYPE="DaemonSet"
        export CONTAINER_TYPE=""
        export DCR_REQUIRED="#{dcr_required}"
        export LOGS_AND_EVENTS_ONLY="#{initial_value}"
        export AZMON_RESOURCE_OPTIMIZATION_ENABLED="true"
      SH
    )
  end

  def run_probe(parser_status: 0, parser_value: "true", append_newline: true)
    Open3.capture3(
      {
        "TMPDIR" => shell_path(@tmp_dir),
        "PARSER_SENTINEL" => shell_path(@parser_sentinel),
        "PARSER_STATUS" => parser_status.to_s,
        "PARSER_VALUE" => parser_value,
        "APPEND_NEWLINE" => append_newline.to_s,
      },
      bash_path,
      shell_path(@probe),
      chdir: @sandbox
    )
  end

  def success_diagnostics(stdout, stderr, status)
    termination = File.exist?(@termination_log) ? File.read(@termination_log) : "<none>"
    "status=#{status.exitstatus}\nstdout=#{stdout}\nstderr=#{stderr}\ntermination=#{termination}"
  end

  def test_skips_parser_when_dcr_is_not_required
    write_environment(dcr_required: "false", initial_value: "true")

    stdout, stderr, status = run_probe(parser_status: 23)

    assert status.success?, success_diagnostics(stdout, stderr, status)
    refute File.exist?(@parser_sentinel)
  end

  def test_fails_when_stored_initial_value_is_missing
    write_environment(dcr_required: "true", initial_value: "")

    _, _, status = run_probe(parser_value: "true")

    refute status.success?
    refute File.exist?(@parser_sentinel)
  end

  def test_fails_when_stored_initial_value_is_invalid
    write_environment(dcr_required: "true", initial_value: "stored-invalid-value")

    _, _, status = run_probe(parser_value: "true")

    refute status.success?
    assert_includes File.read(@termination_log), "stored-invalid-value"
  end

  def test_fails_when_parser_fails
    write_environment(dcr_required: "true", initial_value: "true")

    _, _, status = run_probe(parser_status: 23)

    refute status.success?
    assert_empty Dir.glob(File.join(@tmp_dir, "dcr_env_var.*"))
  end

  def test_fails_when_current_value_differs_from_initial_value
    write_environment(dcr_required: "true", initial_value: "true")

    _, _, status = run_probe(parser_value: "false")

    refute status.success?
  end

  def test_fails_when_parser_output_contains_trailing_content
    write_environment(dcr_required: "true", initial_value: "true")

    _, _, status = run_probe(parser_value: "true trailing-value")

    refute status.success?
    assert_includes File.read(@termination_log), "trailing-value"
  end

  def test_fails_when_parser_output_omits_trailing_newline
    write_environment(dcr_required: "true", initial_value: "true")

    _, _, status = run_probe(append_newline: false)

    refute status.success?
    assert_includes File.read(@termination_log), "Failed to read"
  end

  def test_fails_when_false_parser_output_omits_trailing_newline
    write_environment(dcr_required: "true", initial_value: "false")

    _, _, status = run_probe(parser_value: "false", append_newline: false)

    refute status.success?
  end

  def test_succeeds_when_false_value_matches_initial_value
    write_environment(dcr_required: "true", initial_value: "false")

    stdout, stderr, status = run_probe(parser_value: "false")

    assert status.success?, success_diagnostics(stdout, stderr, status)
  end

  def test_succeeds_when_current_value_matches_initial_value
    write_environment(dcr_required: "true", initial_value: "true")

    stdout, stderr, status = run_probe(parser_value: "true")

    assert status.success?, success_diagnostics(stdout, stderr, status)
    assert File.exist?(@parser_sentinel)
    assert_empty Dir.glob(File.join(@tmp_dir, "dcr_env_var.*"))
  end

  def test_fails_when_dcr_requirement_is_missing
    write_environment(dcr_required: "", initial_value: "true")

    _, _, status = run_probe(parser_value: "true")

    refute status.success?
    refute File.exist?(@parser_sentinel)
  end

  def test_fails_when_dcr_requirement_is_invalid
    write_environment(dcr_required: "required-invalid-value", initial_value: "true")

    _, _, status = run_probe(parser_value: "true")

    refute status.success?
    assert_includes File.read(@termination_log), "required-invalid-value"
  end

  def test_fails_when_current_value_is_invalid
    write_environment(dcr_required: "true", initial_value: "true")

    _, _, status = run_probe(parser_value: "current-invalid-value")

    refute status.success?
    assert_includes File.read(@termination_log), "current-invalid-value"
  end

  def test_uses_one_private_parser_output_file_per_probe
    source = File.read(PROBE_PATH)

    assert_operator source.index("umask 077"), :<, source.index("mktemp")
    assert_equal 1, source.scan(/mktemp .*dcr_env_var/).length
    assert_operator source.index("mktemp"), :<, source.index('case "${DCR_REQUIRED}"')
  end
end
