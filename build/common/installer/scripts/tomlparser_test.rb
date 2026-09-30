require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"
require "json"
require "yaml"

class TomlParserTest < Minitest::Test
  SCRIPTS_DIR = File.expand_path(__dir__)
  PARSER_PATH = File.join(SCRIPTS_DIR, "tomlparser.rb")
  REPO_ROOT = File.expand_path("../../../..", SCRIPTS_DIR)
  INVALID_VERSIONS = [
    "v2$(touch injection_marker)",
    "v2`touch injection_marker`",
    "v2; touch injection_marker; #",
    "v2'\"; touch injection_marker; #",
    "v2\ntouch injection_marker\n#",
    "v2\r\ntouch injection_marker\r\n#",
    "v2\\\ntouch injection_marker",
    "v2\u0000$(touch injection_marker)",
    "v3",
    "",
    " v2",
    "v2 ",
    true,
    2,
    [],
    {},
  ].freeze

  def source_environment(sandbox, env, commands)
    dump_environment = %q{"$TEST_RUBY_BIN" -rjson -e 'puts JSON.generate(ENV.select { |name, _value| name.start_with?("AZMON_") })'}
    stdout, stderr, status = Open3.capture3(env, "bash", "--noprofile", "--norc", "-c",
                                          "set -e\n#{commands}\n#{dump_environment}", chdir: sandbox)
    assert status.success?, "Sourcing generated settings failed: #{stderr}"
    refute File.exist?(File.join(sandbox, "injection_marker")), "ConfigMap content was executed by the shell"
    JSON.parse(stdout)
  end

  def run_parser(configmap, os_type = "linux", schema_version: "v1", parser_source: File.read(PARSER_PATH))
    Dir.mktmpdir("tomlparser-test") do |sandbox|
      config_dir = File.join(sandbox, "etc/config/settings")
      FileUtils.mkdir_p(config_dir)
      File.write(File.join(config_dir, "log-data-collection-settings"), configmap) unless configmap.nil?
      FileUtils.cp(File.join(SCRIPTS_DIR, "ConfigParseErrorLogger.rb"), sandbox)

      source = parser_source.gsub('"/etc/', "\"#{sandbox}/etc/")
      parser = File.join(sandbox, "parser.rb")
      File.write(parser, source)
      env = {
        "AZMON_AGENT_CFG_SCHEMA_VERSION" => schema_version,
        "AZMON_CLUSTER_COLLECT_ALL_KUBE_EVENTS" => nil,
        "AZMON_KUBERNETES_METADATA_ENABLED" => nil,
        "OS_TYPE" => os_type,
        "CONTROLLER_TYPE" => "daemonset",
        "HOME" => sandbox,
        "BASH_ENV" => nil,
        "TEST_RUBY_BIN" => RbConfig.ruby,
      }
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, parser, chdir: sandbox)
      assert status.success?, "Parser failed: #{stdout}\n#{stderr}"

      startup = File.read(File.join(REPO_ROOT, "kubernetes/linux/main.sh"))
      copy_block = startup.match(/ruby tomlparser\.rb\n(.*?)\n[ \t]*source config_env_var/m)
      refute_nil copy_block, "Cannot find the settings append/source block in main.sh"
      initial = source_environment(sandbox, env, "#{copy_block[1]}\nsource config_env_var")
      assert_equal File.binread(File.join(sandbox, "config_env_var")), File.binread(File.join(sandbox, ".bashrc"))
      persisted = source_environment(sandbox, env, 'source "$HOME/.bashrc"')
      assert_equal initial, persisted

      windows_path = File.join(sandbox, "setenv.txt")
      {
        env: initial,
        exports: File.read(File.join(sandbox, "config_env_var")),
        windows: File.exist?(windows_path) ? File.read(windows_path) : nil,
        output: stdout,
      }
    end
  end

  def version_config(schema, route)
    "[log_collection_settings.schema]\ncontainerlog_schema_version = #{JSON.generate(schema)}\n" \
      "[log_collection_settings.route_container_logs]\nversion = #{JSON.generate(route)}\n"
  end

  def compatibility_configurations
    configurations = {
      "missing config" => { config: nil, expected: {} },
      "defaults" => { config: "[log_collection_settings]\n", expected: {} },
      "shipped config" => {
        config: YAML.safe_load_file(File.join(REPO_ROOT, "kubernetes/container-azm-ms-agentconfig.yaml")).fetch("data").fetch("log-data-collection-settings"),
        expected: { "AZMON_CONTAINER_LOG_SCHEMA_VERSION" => "v2" },
      },
      "namespaces and system pods" => {
        config: <<~TOML,
          [log_collection_settings.stdout]
          enabled = true
          exclude_namespaces = ["default", "gatekeeper-system"]
          collect_system_pod_logs = ["kube-system:coredns", "calico-system:calico-node"]
          [log_collection_settings.stderr]
          enabled = true
          exclude_namespaces = ["default", "gatekeeper-system"]
          collect_system_pod_logs = ["kube-system:coredns"]
        TOML
        expected: {
          "AZMON_STDOUT_EXCLUDED_NAMESPACES" => "default,gatekeeper-system",
          "AZMON_STDERR_EXCLUDED_NAMESPACES" => "default,gatekeeper-system",
          "AZMON_STDOUT_INCLUDED_SYSTEM_PODS" => "kube-system:coredns,calico-system:calico-node",
          "AZMON_STDERR_INCLUDED_SYSTEM_PODS" => "kube-system:coredns",
          "AZMON_CLUSTER_LOG_TAIL_EXCLUDE_PATH" => "*.csv2,*_default_*.log,*_gatekeeper-system_*.log",
        },
      },
      "multiline and enrichment" => {
        config: <<~TOML,
          [log_collection_settings.env_var]
          enabled = false
          [log_collection_settings.enrich_container_logs]
          enabled = true
          [log_collection_settings.collect_all_kube_events]
          enabled = true
          [log_collection_settings.enable_multiline_logs]
          enabled = true
          stacktrace_languages = ["go", "python", "dotnet"]
          [log_collection_settings.metadata_collection]
          enabled = true
          include_fields = ["podLabels", "podUid", "imageID"]
          [log_collection_settings.filter_using_annotations]
          enabled = true
        TOML
        expected: {
          "AZMON_CLUSTER_COLLECT_ENV_VAR" => "false",
          "AZMON_CLUSTER_CONTAINER_LOG_ENRICH" => "true",
          "AZMON_CLUSTER_COLLECT_ALL_KUBE_EVENTS" => "true",
          "AZMON_MULTILINE_ENABLED" => "true",
          "AZMON_MULTILINE_LANGUAGES" => "go,python,java",
          "AZMON_KUBERNETES_METADATA_ENABLED" => "true",
          "AZMON_KUBERNETES_METADATA_INCLUDES_FIELDS" => "podlabels,poduid,imageid",
          "AZMON_ANNOTATION_BASED_LOG_FILTERING" => "true",
        },
      },
      "multi-tenancy" => {
        config: <<~TOML,
          [log_collection_settings.multi_tenancy]
          enabled = true
          disable_fallback_ingestion = true
          advanced_mode_enabled = true
          namespaces = [" Tenant-A ", "tenant-b", "tenant-a"]
          storage_max_chunks_up = 750
          service_buffer_chunk_size = "12m"
          service_buffer_max_size = "36m"
        TOML
        expected: {
          "AZMON_MULTI_TENANCY_LOG_COLLECTION" => "true",
          "AZMON_MULTI_TENANCY_FALLBACK_INGESTION_DISABLED" => "true",
          "AZMON_MULTI_TENANCY_LOG_COLLECTION_ADVANCED_MODE" => "true",
          "AZMON_MULTI_TENANCY_NAMESPACES" => "tenant-a,tenant-b",
          "AZMON_MULTI_TENANCY_STORAGE_MAX_CHUNKS_UP" => "750",
          "AZMON_MULTI_TENANCY_SVC_BUFFER_CHUNK_SIZE" => "12m",
          "AZMON_MULTI_TENANCY_SVC_BUFFER_MAX_SIZE" => "36m",
        },
      },
    }
    [true, false].product([true, false]).each do |stdout_enabled, stderr_enabled|
      configurations["stdout=#{stdout_enabled}, stderr=#{stderr_enabled}"] = {
        config: "[log_collection_settings.stdout]\nenabled = #{stdout_enabled}\n" \
          "[log_collection_settings.stderr]\nenabled = #{stderr_enabled}\n",
        expected: {
          "AZMON_COLLECT_STDOUT_LOGS" => stdout_enabled.to_s,
          "AZMON_COLLECT_STDERR_LOGS" => stderr_enabled.to_s,
          "AZMON_STDOUT_EXCLUDED_NAMESPACES" => "",
          "AZMON_STDERR_EXCLUDED_NAMESPACES" => "",
        },
      }
    end
    ["v1", "v2"].product(["v1", "v2"]).each do |schema, route|
      configurations["schema=#{schema}, route=#{route}"] = {
        config: version_config(schema, route),
        expected: { "AZMON_CONTAINER_LOG_SCHEMA_VERSION" => schema, "AZMON_CONTAINER_LOGS_ROUTE" => route },
      }
    end
    configurations
  end

  def test_supported_configuration_modes_preserve_values
    ["linux", "windows"].each do |os_type|
      compatibility_configurations.each do |name, scenario|
        result = run_parser(scenario[:config], os_type)

        scenario[:expected].each do |variable, expected|
          assert_equal expected, result[:env][variable], "#{os_type}: #{name}: #{variable}"
          assert_includes result[:windows], "#{variable}=#{expected}\n" if os_type == "windows" && !variable.include?("SVC_BUFFER")
        end
        refute_includes result[:output], "Exception", "#{os_type}: #{name}"
        result[:exports].each_line { |line| assert_match(/\Aexport [A-Z0-9_]+='/, line) }
      end
    end
  end

  def test_defaults_and_literal_shell_values_are_preserved
    result = run_parser("[log_collection_settings]\n")

    assert_equal "v2", result[:env]["AZMON_CONTAINER_LOGS_ROUTE"]
    assert_equal "", result[:env]["AZMON_CONTAINER_LOG_SCHEMA_VERSION"]
    assert_equal "true", result[:env]["AZMON_COLLECT_STDOUT_LOGS"]
    assert_equal "true", result[:env]["AZMON_COLLECT_STDERR_LOGS"]
    assert_equal "/var/log/containers/*.log", result[:env]["AZMON_LOG_TAIL_PATH"]
    assert_equal "(^((?!stdout|stderr).)*$)", result[:env]["AZMON_LOG_EXCLUSION_REGEX_PATTERN"]
    result[:exports].each_line do |line|
      assert_match(/\Aexport [A-Z0-9_]+='/, line)
    end
  end

  def test_supported_versions_and_case_variants_are_accepted
    ["linux", "windows"].each do |os_type|
      ["v1", "v2", "V1", "V2"].each do |version|
        result = run_parser(version_config(version, version), os_type)

        assert_equal version.downcase, result[:env]["AZMON_CONTAINER_LOG_SCHEMA_VERSION"]
        assert_equal version.downcase, result[:env]["AZMON_CONTAINER_LOGS_ROUTE"]
        if os_type == "windows"
          assert_includes result[:windows], "AZMON_CONTAINER_LOG_SCHEMA_VERSION=#{version.downcase}\n"
          assert_includes result[:windows], "AZMON_CONTAINER_LOGS_ROUTE=#{version.downcase}\n"
        end
      end
    end
  end

  def test_invalid_schema_version_cannot_execute_or_override_valid_route
    ["linux", "windows"].each do |os_type|
      INVALID_VERSIONS.each do |version|
        result = run_parser(version_config(version, "v1"), os_type)

        assert_includes result[:output], "config::Successfully parsed mounted config map"
        assert_equal "", result[:env]["AZMON_CONTAINER_LOG_SCHEMA_VERSION"], version.inspect
        assert_equal "v1", result[:env]["AZMON_CONTAINER_LOGS_ROUTE"], version.inspect
        refute_includes result[:exports], "injection_marker"
        if os_type == "windows"
          assert_includes result[:windows], "AZMON_CONTAINER_LOG_SCHEMA_VERSION=\n"
          assert_includes result[:windows], "AZMON_CONTAINER_LOGS_ROUTE=v1\n"
          refute_includes result[:windows], "injection_marker"
        end
      end
    end
  end

  def test_invalid_route_version_cannot_execute_or_override_valid_schema
    ["linux", "windows"].each do |os_type|
      INVALID_VERSIONS.each do |version|
        result = run_parser(version_config("v2", version), os_type)
        expected_route = os_type == "windows" ? "v1" : "v2"

        assert_includes result[:output], "config::Successfully parsed mounted config map"
        assert_equal "v2", result[:env]["AZMON_CONTAINER_LOG_SCHEMA_VERSION"], version.inspect
        assert_equal expected_route, result[:env]["AZMON_CONTAINER_LOGS_ROUTE"], version.inspect
        refute_includes result[:exports], "injection_marker"
        if os_type == "windows"
          assert_includes result[:windows], "AZMON_CONTAINER_LOG_SCHEMA_VERSION=v2\n"
          assert_includes result[:windows], "AZMON_CONTAINER_LOGS_ROUTE=#{expected_route}\n"
          refute_includes result[:windows], "injection_marker"
        end
      end
    end
  end

  def test_both_reported_inputs_are_rejected_together
    result = run_parser(version_config("v2$(touch injection_marker)", "v2$(touch injection_marker)"))

    assert_equal "", result[:env]["AZMON_CONTAINER_LOG_SCHEMA_VERSION"]
    assert_equal "v2", result[:env]["AZMON_CONTAINER_LOGS_ROUTE"]
    refute_includes result[:exports], "injection_marker"
  end

  def test_missing_or_invalid_config_preserves_defaults
    ["linux", "windows"].each do |os_type|
      [nil, "not valid TOML =", "[log_collection_settings]\n"].each do |config|
        result = run_parser(config, os_type)

        assert_equal "", result[:env]["AZMON_CONTAINER_LOG_SCHEMA_VERSION"]
        assert_equal(os_type == "windows" ? "v1" : "v2", result[:env]["AZMON_CONTAINER_LOGS_ROUTE"])
        assert_equal "true", result[:env]["AZMON_COLLECT_STDOUT_LOGS"]
        assert_equal "true", result[:env]["AZMON_COLLECT_STDERR_LOGS"]
      end
      [nil, "v0", ""].each do |schema|
        result = run_parser(version_config("v1", "v2"), os_type, schema_version: schema)

        assert_equal "", result[:env]["AZMON_CONTAINER_LOG_SCHEMA_VERSION"]
        assert_equal(os_type == "windows" ? "v1" : "v2", result[:env]["AZMON_CONTAINER_LOGS_ROUTE"])
        assert_equal "*_kube-system_*.log", result[:env]["AZMON_CLUSTER_LOG_TAIL_EXCLUDE_PATH"]
      end
    end
  end

  def test_other_exported_settings_are_literal_in_startup_and_bashrc
    values = [
      "$(touch injection_marker)",
      "`touch injection_marker`",
      "value; touch injection_marker; #",
      "value'; touch injection_marker; #",
      "value\"; touch injection_marker; #",
      "first line\n$(touch injection_marker)\nlast line",
      " spaces\t* ? [glob] \\ $HOME '",
    ]
    values.each do |value|
      result = run_parser("[log_collection_settings.env_var]\nenabled = #{JSON.generate(value)}\n")

      assert_equal value, result[:env]["AZMON_CLUSTER_COLLECT_ENV_VAR"]
    end
  end

  def test_list_and_multi_tenancy_values_cannot_escape_shell_assignments
    value = "tenant'$(touch injection_marker);\\\nnext"
    encoded = JSON.generate(value)
    config = <<~TOML
      [log_collection_settings.stdout]
      enabled = true
      exclude_namespaces = [#{encoded}]
      collect_system_pod_logs = [#{JSON.generate("kube-system:#{value}")}]
      [log_collection_settings.stderr]
      enabled = true
      exclude_namespaces = [#{encoded}]
      collect_system_pod_logs = [#{JSON.generate("kube-system:#{value}")}]
      [log_collection_settings.metadata_collection]
      enabled = true
      include_fields = ["podlabels", #{encoded}]
      [log_collection_settings.multi_tenancy]
      enabled = true
      advanced_mode_enabled = true
      namespaces = [#{encoded}]
      service_buffer_chunk_size = #{encoded}
      service_buffer_max_size = #{encoded}
    TOML
    result = run_parser(config)

    ["AZMON_STDOUT_EXCLUDED_NAMESPACES", "AZMON_STDERR_EXCLUDED_NAMESPACES",
     "AZMON_MULTI_TENANCY_NAMESPACES", "AZMON_MULTI_TENANCY_SVC_BUFFER_CHUNK_SIZE",
     "AZMON_MULTI_TENANCY_SVC_BUFFER_MAX_SIZE"].each do |variable|
      assert_equal value, result[:env][variable], variable
    end
    assert_equal "kube-system:#{value}", result[:env]["AZMON_STDOUT_INCLUDED_SYSTEM_PODS"]
    assert_equal "kube-system:#{value}", result[:env]["AZMON_STDERR_INCLUDED_SYSTEM_PODS"]
    assert_equal "*.csv2,*_#{value}_*.log", result[:env]["AZMON_CLUSTER_LOG_TAIL_EXCLUDE_PATH"]
    assert_equal "podlabels,#{value}", result[:env]["AZMON_KUBERNETES_METADATA_INCLUDES_FIELDS"]
  end
end