require "minitest/autorun"
require "tmpdir"

require_relative "parser_test_helper"

# Verifies that log collection settings coming from the container-azm-ms-agentconfig configmap cannot
# inject shell commands into config_env_var, which main.sh appends to ~/.bashrc and sources as root.
class TomlParserLogCollectionTests < Minitest::Test
  PARSER_SCRIPT = "tomlparser.rb"
  CONFIGMAP_MOUNT_PATH = "/etc/config/settings/log-data-collection-settings"
  ENV_VAR_FILE = "config_env_var"

  def run_log_collection_parser(tomlContent, workdir)
    return ParserTestHelper.run_parser(PARSER_SCRIPT, CONFIGMAP_MOUNT_PATH, ENV_VAR_FILE, tomlContent, workdir)
  end

  def test_excluded_namespaces_are_written_quoted
    Dir.mktmpdir do |workdir|
      _output, envVarFileContents = run_log_collection_parser(<<~TOML, workdir)
        [log_collection_settings.stdout]
        enabled = true
        exclude_namespaces = ["kube-system", "gatekeeper-system"]
      TOML

      assert_includes envVarFileContents, "export AZMON_STDOUT_EXCLUDED_NAMESPACES='kube-system,gatekeeper-system'\n"

      sourced = ParserTestHelper.source_env_file(File.join(workdir, ENV_VAR_FILE), ["AZMON_STDOUT_EXCLUDED_NAMESPACES", "AZMON_LOG_TAIL_PATH"])
      assert_equal "kube-system,gatekeeper-system", sourced["AZMON_STDOUT_EXCLUDED_NAMESPACES"]
      # the glob must survive sourcing unexpanded since fluent-bit uses it as a tail pattern
      assert_equal "/var/log/containers/*.log", sourced["AZMON_LOG_TAIL_PATH"]
    end
  end

  def test_excluded_namespace_with_shell_metacharacters_does_not_execute
    Dir.mktmpdir do |workdir|
      marker = File.join(workdir, "pwned")
      _output, _envVarFileContents = run_log_collection_parser(<<~TOML, workdir)
        [log_collection_settings.stdout]
        enabled = true
        exclude_namespaces = ["kube-system; touch #{marker} #"]

        [log_collection_settings.stderr]
        enabled = true
        exclude_namespaces = ["gatekeeper-system$(touch #{marker})"]
      TOML

      sourced = ParserTestHelper.source_env_file(File.join(workdir, ENV_VAR_FILE), ["AZMON_STDOUT_EXCLUDED_NAMESPACES", "AZMON_STDERR_EXCLUDED_NAMESPACES"])
      assert_equal "kube-system; touch #{marker} #", sourced["AZMON_STDOUT_EXCLUDED_NAMESPACES"]
      assert_equal "gatekeeper-system$(touch #{marker})", sourced["AZMON_STDERR_EXCLUDED_NAMESPACES"]
      refute File.exist?(marker), "configmap value was executed as a shell command"
    end
  end

  def test_container_log_settings_with_shell_metacharacters_do_not_execute
    Dir.mktmpdir do |workdir|
      marker = File.join(workdir, "pwned")
      _output, _envVarFileContents = run_log_collection_parser(<<~TOML, workdir)
        [log_collection_settings.schema]
        containerlog_schema_version = "v2`touch #{marker}`"

        [log_collection_settings.route_container_logs]
        version = "v2; touch #{marker} #"
      TOML

      sourced = ParserTestHelper.source_env_file(File.join(workdir, ENV_VAR_FILE), ["AZMON_CONTAINER_LOG_SCHEMA_VERSION", "AZMON_CONTAINER_LOGS_ROUTE"])
      assert_equal "v2`touch #{marker}`", sourced["AZMON_CONTAINER_LOG_SCHEMA_VERSION"]
      assert_equal "v2; touch #{marker} #", sourced["AZMON_CONTAINER_LOGS_ROUTE"]
      refute File.exist?(marker), "configmap value was executed as a shell command"
    end
  end
end
