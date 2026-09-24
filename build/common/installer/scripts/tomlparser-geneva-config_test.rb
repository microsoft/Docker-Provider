require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"

# Regression tests for the container-azm-ms-agentconfig -> geneva environment file generation.
#
# Values in that config map are attacker supplied whenever someone has write access to it. On
# linux the generated geneva_config_env_var file is appended to ~/.bashrc and sourced by
# kubernetes/linux/main.sh while the agent runs as root in a privileged daemonset, so a value
# must never be able to escape its assignment and become a command.
#
# The payloads below try exactly that. Nothing here runs the agent; the tests generate the file
# with the real parser and then source it in a throwaway shell.

class GenevaConfigTest < Minitest::Test
  SCRIPTS_DIR = File.expand_path(__dir__)
  PARSER_PATH = File.join(SCRIPTS_DIR, "tomlparser-geneva-config.rb")

  # Loading the parser gives direct access to its helpers. The top level code is a no-op unless
  # a config map is mounted at the hard coded agent path, which is not the case on a test machine,
  # but it does write its (empty) output file, so it is loaded from a throwaway directory.
  Dir.mktmpdir("geneva-config-load") { |dir| Dir.chdir(dir) { load PARSER_PATH } }

  SENTINEL_NAME = "ci-geneva-injection-sentinel"

  # Terminates the assignment it lands in and runs a command, then comments out the rest of the
  # line so that the result would still be a valid shell script.
  def payloads
    [
      "Test; touch #{@sentinel} #",
      "Test\ntouch #{@sentinel}\n#",
      "Test$(touch #{@sentinel})",
      "Test`touch #{@sentinel}`",
      "Test' ; touch #{@sentinel} ; '",
      "Test\" ; touch #{@sentinel} ; \"",
      "Test\\\ntouch #{@sentinel}",
    ]
  end

  def setup
    @sandbox = Dir.mktmpdir("geneva-config-test")
    @sentinel = File.join(@sandbox, SENTINEL_NAME)
  end

  def teardown
    FileUtils.remove_entry(@sandbox) if @sandbox && File.exist?(@sandbox)
  end

  VALID_SETTINGS = {
    "enabled" => "true",
    "environment" => "Test",
    "namespace" => "TestNamespace",
    "account" => "TestAccount",
    "region" => "westus2",
    "configversion" => "1.0",
    "authid" => "client_id#11111111-2222-3333-4444-555555555555",
  }.freeze

  def configmap_for(overrides = {}, extra_lines = [])
    settings = VALID_SETTINGS.merge(overrides)
    lines = settings.map do |key, value|
      value == "true" || value == "false" ? "#{key} = #{value}" : "#{key} = #{value.inspect}"
    end
    "[integrations.geneva_logs]\n#{(lines + extra_lines).join("\n")}\n"
  end

  # Runs the real parser against a config map in a sandbox. The parser reads absolute agent paths,
  # so those prefixes are rewritten to point inside the sandbox, and writes its output files
  # relative to the working directory.
  def run_parser(configmap, env = {})
    workdir = Dir.mktmpdir("geneva-config-run", @sandbox)
    FileUtils.mkdir_p(File.join(workdir, "etc/config/settings"))
    File.write(File.join(workdir, "etc/config/settings/integrations"), configmap)
    FileUtils.cp(File.join(SCRIPTS_DIR, "ConfigParseErrorLogger.rb"), File.join(workdir, "ConfigParseErrorLogger.rb"))

    parser = File.join(workdir, "parser.rb")
    File.write(parser, File.read(PARSER_PATH).gsub('"/etc/', "\"#{workdir}/etc/"))

    parserEnv = {
      "AZMON_AGENT_CFG_SCHEMA_VERSION" => "v1",
      "CONTROLLER_TYPE" => "daemonset",
      "OS_TYPE" => nil,
    }.merge(env)

    stdout, stderr, = Open3.capture3(parserEnv, RbConfig.ruby, parser, chdir: workdir)

    windowsPath = File.join(workdir, "setgenevaconfigenv.txt")
    {
      workdir: workdir,
      env_file: File.read(File.join(workdir, "geneva_config_env_var")),
      env_file_path: File.join(workdir, "geneva_config_env_var"),
      windows_file: File.exist?(windowsPath) ? File.read(windowsPath) : nil,
      stdout: stdout,
      stderr: stderr,
    }
  end

  # Sources the generated file the same way main.sh does and reports the resulting variables.
  def source_env_file(result)
    script = "set -e\n. \"#{result[:env_file_path]}\"\n" +
             ["MONITORING_GCS_ENVIRONMENT", "MONITORING_GCS_NAMESPACE", "MONITORING_GCS_ACCOUNT",
              "MONITORING_GCS_REGION", "MONITORING_CONFIG_VERSION", "MONITORING_GCS_AUTH_ID",
              "MONITORING_GCS_AUTH_ID_TYPE", "GENEVA_LOGS_INFRA_NAMESPACES",
              "GENEVA_LOGS_TENANT_NAMESPACES"].map { |name| "printf '%s=%s\\n' #{name} \"$#{name}\"" }.join("\n")
    stdout, = Open3.capture3({}, "bash", "-c", script, chdir: result[:workdir])
    stdout.lines.map { |line| line.chomp.split("=", 2) }.to_h
  end

  # The core security property: no config map value can execute a command when the generated file
  # is sourced by a shell.
  def assert_no_command_execution(result, context)
    source_env_file(result)
    refute File.exist?(@sentinel), "config map value was executed as a command via #{context}"
    # main.sh copies the file into ~/.bashrc line by line, so a value must stay on its own line.
    result[:env_file].each_line do |line|
      next if line.strip.empty?
      assert_match(/\A(export [A-Z_]+=|#)/, line, "unexpected line in the generated env file via #{context}")
    end
  end

  # --- value validation ----------------------------------------------------------------------

  def test_known_geneva_environments_are_accepted
    GENEVA_SUPPORTED_ENVIRONMENTS.each do |environment|
      assert isValidGenevaEnvironment(environment), "expected #{environment.inspect} to be valid"
      assert isValidGenevaEnvironment(environment.downcase)
    end
  end

  # Airgap clouds use environment identifiers the agent does not know, so an unknown alphanumeric
  # value is still accepted. The character allowlist is what makes it safe.
  def test_unknown_alphanumeric_environment_is_accepted
    assert isValidGenevaEnvironment("SomeAirgapProd42")
  end

  def test_geneva_names_must_start_with_a_letter
    ["Prod_1", "Prod-1", "Prod.1", "A"].each do |value|
      assert isValidGenevaName(value), "expected #{value.inspect} to be a valid geneva name"
    end

    ["1Prod", "_Prod", "-Prod", ".Prod"].each do |value|
      refute isValidGenevaName(value), "expected #{value.inspect} to be an invalid geneva name"
    end
  end

  def test_invalid_values_are_rejected
    invalid = [
      "Test; id",
      "Test$(id)",
      "Test`id`",
      "Test|id",
      "Test id",
      "Test'",
      "Test\"",
      "Test\\",
      "Test\n",
      "Test\nid",       # \A and \z anchors, not ^ and $, keep a payload off a second line
      "Test\u0000",
      "",
      nil,
      42,
      "T" * 65,
    ]
    invalid.each do |value|
      refute isValidGenevaName(value), "expected #{value.inspect} to be an invalid geneva name"
      refute isValidGenevaEnvironment(value), "expected #{value.inspect} to be an invalid environment"
      refute isValidGenevaRegion(value), "expected #{value.inspect} to be an invalid region"
      refute isValidGenevaConfigVersion(value), "expected #{value.inspect} to be an invalid config version"
      refute isValidGenevaAuthId(value), "expected #{value.inspect} to be an invalid authid"
      refute isValidKubernetesNamespace(value), "expected #{value.inspect} to be an invalid namespace"
    end
  end

  def test_valid_regions_and_config_versions_are_accepted
    ["westus2", "chinanorth3", "A"].each { |value| assert isValidGenevaRegion(value) }
    ["1.0", "2.1", "Ver2v0", "1_0", "1-0"].each { |value| assert isValidGenevaConfigVersion(value) }
  end

  def test_geneva_region_must_start_with_a_letter_and_be_alphanumeric
    ["1westus", "east-us-2", "westus_2", "west.us2", "-westus", "westus-"].each do |value|
      refute isValidGenevaRegion(value), "expected #{value.inspect} to be an invalid region"
    end
  end

  def test_authid_must_use_a_supported_identifier
    ["client_id#11111111-2222-3333-4444-555555555555",
     "object_id#11111111-2222-3333-4444-555555555555",
     "mi_res_id#/subscriptions/sub/resourcegroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/name",
    ].each { |value| assert isValidGenevaAuthId(value), "expected #{value.inspect} to be a valid authid" }

    ["11111111-2222-3333-4444-555555555555",
     "client_id",
     "some_id#guid",
     "client_id#guid;id",
    ].each { |value| refute isValidGenevaAuthId(value), "expected #{value.inspect} to be an invalid authid" }
  end

  def test_infra_namespace_wildcard_is_supported
    assert isValidGenevaInfraNamespace("kube-system")
    assert isValidGenevaInfraNamespace("infra-*")
    refute isValidGenevaInfraNamespace("infra-*-*")
    refute isValidGenevaInfraNamespace("*")
    refute isValidKubernetesNamespace("infra-*")
    refute isValidKubernetesNamespace("a" * 64)
  end

  # --- joinValidNamespaces -------------------------------------------------------------------

  # main.sh splits this list again and interpolates each entry into a `cp` target, a file name and
  # a `sed -i "s/.../.../g"` expression, so the joined list is a sink in its own right.

  def test_join_valid_namespaces_returns_empty_for_non_array_input
    [nil, "kube-system", {}, 42].each do |value|
      assert_equal "", joinValidNamespaces(value, "infra_namespaces", true),
                   "expected #{value.inspect} to produce an empty list"
    end
    assert_equal "", joinValidNamespaces([], "tenant_namespaces", false)
  end

  def test_join_valid_namespaces_preserves_order_and_strips_whitespace
    assert_equal "zeta,alpha,mid",
                 joinValidNamespaces(["zeta", "alpha", "mid"], "tenant_namespaces", false)
    assert_equal "kube-system,default",
                 joinValidNamespaces([" kube-system ", "\tdefault\n"], "tenant_namespaces", false)
  end

  # Duplicates are the tenant's problem, not a safety issue, so they are passed through unchanged.
  def test_join_valid_namespaces_keeps_duplicates
    assert_equal "team-a,team-a", joinValidNamespaces(["team-a", "team-a"], "tenant_namespaces", false)
  end

  def test_join_valid_namespaces_skips_blank_and_invalid_entries
    assert_equal "default",
                 joinValidNamespaces(["", "   ", "default"], "tenant_namespaces", false)
    assert_equal "",
                 joinValidNamespaces(["BadNamespace", "has space", "a" * 64], "tenant_namespaces", false)
    assert_equal "kube-system,team-a",
                 joinValidNamespaces(["kube-system", "Bad_Namespace", "team-a"], "tenant_namespaces", false)
  end

  # The wildcard suffix is only meaningful for infra namespaces, which main.sh strips before it
  # builds the generated fluent-bit config file name. A tenant namespace must be an exact label.
  def test_join_valid_namespaces_applies_the_wildcard_rule_only_for_infra
    assert_equal "kube-system,infra-*",
                 joinValidNamespaces(["kube-system", "infra-*"], "infra_namespaces", true)
    assert_equal "kube-system",
                 joinValidNamespaces(["kube-system", "infra-*"], "tenant_namespaces", false)
  end

  def test_join_valid_namespaces_drops_injection_payloads
    payloads.each do |payload|
      assert_equal "kube-system",
                   joinValidNamespaces([payload, "kube-system"], "infra_namespaces", true),
                   "the payload #{payload.inspect} was not dropped from the infra list"
      assert_equal "default",
                   joinValidNamespaces(["default", payload], "tenant_namespaces", false),
                   "the payload #{payload.inspect} was not dropped from the tenant list"
    end
  end

  # Non string entries cannot reach here through toml, which enforces a single element type, but
  # the coercion is what keeps a surprising type from raising and taking the integration down.
  def test_join_valid_namespaces_coerces_non_string_entries
    assert_equal "default", joinValidNamespaces([nil, "default"], "tenant_namespaces", false)
    assert_equal "42", joinValidNamespaces([42], "tenant_namespaces", false)
  end

  def test_join_valid_namespaces_error_does_not_echo_the_rejected_entry
    payload = "evil; touch /tmp/#{SENTINEL_NAME} #"
    result = nil
    _, stderr = capture_subprocess_io do
      result = joinValidNamespaces(["kube-system", payload], "infra_namespaces", true)
    end

    assert_equal "kube-system", result
    assert_includes stderr, "infra_namespaces"
    refute_includes stderr, payload
    refute_includes stderr, SENTINEL_NAME
  end

  def test_config_version_falls_back_to_default_without_echoing_input
    assert_equal "1.0", resolveConfigVersion(nil, "configversion")
    assert_equal "1.0", resolveConfigVersion("", "configversion")
    assert_equal "1.0", resolveConfigVersion("1.0; id", "configversion")
    assert_equal "2.1", resolveConfigVersion("2.1", "configversion")
  end

  def test_single_quoting_keeps_a_value_literal
    assert_equal "'plain'", toShellSingleQuoted("plain")
    assert_equal "'it'\\''s'", toShellSingleQuoted("it's")
    assert_equal "'a; id #'", toShellSingleQuoted("a; id #")
    assert_equal "''", toShellSingleQuoted("")
  end

  # --- generated file ------------------------------------------------------------------------

  def test_valid_config_is_written_and_sourced_intact
    result = run_parser(configmap_for)
    values = source_env_file(result)

    assert_equal "Test", values["MONITORING_GCS_ENVIRONMENT"]
    assert_equal "TestNamespace", values["MONITORING_GCS_NAMESPACE"]
    assert_equal "TestAccount", values["MONITORING_GCS_ACCOUNT"]
    assert_equal "westus2", values["MONITORING_GCS_REGION"]
    assert_equal "1.0", values["MONITORING_CONFIG_VERSION"]
    assert_equal "client_id#11111111-2222-3333-4444-555555555555", values["MONITORING_GCS_AUTH_ID"]
    # This used to run together with the following export because of a missing newline.
    assert_equal "AuthMSIToken", values["MONITORING_GCS_AUTH_ID_TYPE"]
    assert_includes result[:env_file], "export MDSD_MSGPACK_SORT_COLUMNS=1\n"
  end

  def test_payload_in_any_scalar_setting_cannot_execute
    ["environment", "namespace", "account", "region", "configversion", "authid"].each do |setting|
      payloads.each do |payload|
        result = run_parser(configmap_for(setting => payload))
        assert_no_command_execution(result, "#{setting}=#{payload.inspect}")
        refute_includes result[:env_file], "touch", "the payload reached the env file via #{setting}"
      end
    end
  end

  def test_payload_in_namespace_lists_cannot_execute
    payloads.each do |payload|
      result = run_parser(configmap_for(
        { "multi_tenancy" => "true" },
        ["infra_namespaces = [#{payload.inspect}, \"kube-system\"]",
         "tenant_namespaces = [#{payload.inspect}, \"default\"]"]
      ))
      assert_no_command_execution(result, "namespace lists with #{payload.inspect}")
      refute_includes result[:env_file], "touch", "the payload reached the env file via the namespace lists"
    end
  end

  def test_invalid_scalar_setting_discards_the_geneva_config
    result = run_parser(configmap_for("environment" => "Test; touch /tmp/x #"))
    values = source_env_file(result)
    assert_equal "", values["MONITORING_GCS_ENVIRONMENT"]
    assert_equal "", values["MONITORING_GCS_ACCOUNT"]
  end

  def test_invalid_namespaces_are_skipped_and_valid_ones_kept
    result = run_parser(configmap_for(
      { "multi_tenancy" => "true" },
      ["infra_namespaces = [\"kube-system\", \"bad namespace\", \"infra-*\"]",
       "tenant_namespaces = [\"default\", \"Bad_Namespace\", \"team-a\"]"]
    ))
    values = source_env_file(result)
    assert_equal "kube-system,infra-*", values["GENEVA_LOGS_INFRA_NAMESPACES"]
    assert_equal "default,team-a", values["GENEVA_LOGS_TENANT_NAMESPACES"]
  end

  def test_invalid_config_version_falls_back_to_the_default
    result = run_parser(configmap_for("configversion" => "1.0; id"))
    assert_equal "1.0", source_env_file(result)["MONITORING_CONFIG_VERSION"]
  end

  def test_rejected_values_are_not_echoed_back_into_the_logs
    payload = "Test; touch #{@sentinel} #"
    result = run_parser(configmap_for("environment" => payload))
    refute_includes result[:stdout], payload
    refute_includes result[:stderr], payload
    refute_includes result[:stdout], SENTINEL_NAME
    refute_includes result[:stderr], SENTINEL_NAME
  end

  # --- windows -------------------------------------------------------------------------------

  # The windows agent assigns these values through the environment provider rather than a shell,
  # but a value with a newline would still forge additional assignments in the generated file.
  def test_windows_file_has_one_assignment_per_line
    payloads.each do |payload|
      result = run_parser(configmap_for("namespacewindows" => payload), "OS_TYPE" => "windows")
      refute_nil result[:windows_file]
      result[:windows_file].each_line do |line|
        next if line.strip.empty?
        assert_match(/\A[A-Z_]+=[^\n]*\n?\z/, line, "unexpected line in the windows env file via #{payload.inspect}")
      end
      refute_includes result[:windows_file], "touch"
    end
  end
end
