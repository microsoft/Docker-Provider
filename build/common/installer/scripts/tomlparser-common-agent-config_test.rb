require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"
require "yaml"

class CommonAgentConfigTest < Minitest::Test
  SCRIPTS_DIR = File.expand_path(__dir__)
  REPO_ROOT = File.expand_path("../../../..", SCRIPTS_DIR)
  PARSER_PATH = File.join(SCRIPTS_DIR, "tomlparser-common-agent-config.rb")
  ENV_NAME = "AZMON_MDSD_LOG_FORWARDING_ENABLED"

  def run_parser(config, expected:, schema: "v1", os: "linux", extension: nil)
    Dir.mktmpdir("common-agent-config-test") do |sandbox|
      config_dir = File.join(sandbox, "etc/config/settings")
      FileUtils.mkdir_p(config_dir)
      File.write(File.join(config_dir, "agent-settings"), config) unless config.nil?
      FileUtils.cp(File.join(SCRIPTS_DIR, "ConfigParseErrorLogger.rb"), sandbox)
      parser = File.join(sandbox, "parser.rb")
      File.write(parser, File.read(PARSER_PATH).gsub('"/etc/', "\"#{sandbox}/etc/"))
      env = {
        "AZMON_AGENT_CFG_SCHEMA_VERSION" => schema,
        "OS_TYPE" => os,
        ENV_NAME => extension,
        "BASH_ENV" => nil,
      }
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, parser, chdir: sandbox)
      assert status.success?, "Parser failed: #{stdout}\n#{stderr}"
      output_file = os == "windows" ? "setcommonagentenv.txt" : "common_agent_config_env_var"
      exports = File.read(File.join(sandbox, output_file))
      if os == "windows"
        refute_includes exports, ENV_NAME
      else
        assert_includes exports, "export #{ENV_NAME}=#{expected}\n"
        function = File.read(File.join(REPO_ROOT, "kubernetes/linux/main.sh"))
                       .match(/^startMdsdLogForwarding\(\) \{$.*?^\}/m)[0]
        commands = <<~BASH
          set -euo pipefail
          source common_agent_config_env_var
          #{function}
          tail() { printf '%s\\n' "$*" > forwarded; }
          MDSD_LOG="$PWD"
          startMdsdLogForwarding
          wait
        BASH
        shell_stdout, shell_stderr, shell_status = Open3.capture3(env, "bash", "-c", commands, chdir: sandbox)
        assert shell_status.success?, "Forwarding failed: #{shell_stdout}\n#{shell_stderr}"
        %w[mdsd.err mdsd.warn forwarded].each do |file|
          assert_equal expected, File.exist?(File.join(sandbox, file)), file
        end
        if expected
          assert_equal "-q -n +1 -F #{sandbox}/mdsd.err #{sandbox}/mdsd.warn\n",
                       File.read(File.join(sandbox, "forwarded"))
        end
      end
      stderr
    end
  end

  def config(value)
    "[agent_settings.mdsd_log_forwarding]\nenabled = #{value}\n"
  end

  def test_missing_configuration_and_setting_default_to_disabled
    [nil, "[agent_settings]\n"].each { |value| run_parser(value, expected: false) }
    shipped = YAML.safe_load(File.read(File.join(REPO_ROOT, "kubernetes/container-azm-ms-agentconfig.yaml")))
    run_parser(shipped.fetch("data").fetch("agent-settings"), expected: false)
  end

  def test_explicit_boolean_enablement_and_disablement
    run_parser(config("true"), expected: true)
    run_parser(config("false"), expected: false)
  end

  def test_extension_setting_is_used_when_configmap_override_is_absent
    [nil, "[agent_settings]\n"].each do |value|
      run_parser(value, expected: true, extension: "true")
    end
    shipped = YAML.safe_load(File.read(File.join(REPO_ROOT, "kubernetes/container-azm-ms-agentconfig.yaml")))
    run_parser(shipped.fetch("data").fetch("agent-settings"), expected: true, extension: "true")
    ["false", "invalid"].each do |value|
      run_parser(nil, expected: false, extension: value)
    end
  end

  def test_configmap_boolean_overrides_extension_setting
    run_parser(config("false"), expected: false, extension: "true")
    run_parser(config("true"), expected: true, extension: "false")
  end

  def test_invalid_configmap_preserves_extension_setting
    assert_includes run_parser(config('"true"'), expected: true, extension: "true"), "ignoring invalid override"
    assert_includes run_parser("[invalid", expected: true, extension: "true"), "Exception while parsing"
    assert_includes run_parser(config("false"), expected: true, extension: "true", schema: "v2"), "unsupported/missing config schema"
  end

  def test_invalid_or_missing_enabled_values_are_reported_and_disabled
    ['"true"', "1", "[]", "{}"].each do |value|
      assert_includes run_parser(config(value), expected: false), "must be a boolean"
    end
    assert_includes run_parser("[agent_settings.mdsd_log_forwarding]\n", expected: false), "must be a boolean"
    assert_includes run_parser("[agent_settings]\nmdsd_log_forwarding = true\n", expected: false), "must be a boolean"
  end

  def test_invalid_toml_and_unsupported_schema_do_not_enable_forwarding
    assert_includes run_parser("[invalid", expected: false), "Exception while parsing"
    ["v2", nil].each do |schema|
      assert_includes run_parser(config("true"), expected: false, schema: schema), "unsupported/missing config schema"
    end
  end

  def test_windows_does_not_export_linux_only_setting
    run_parser(config("true"), expected: false, os: "windows")
  end
end
