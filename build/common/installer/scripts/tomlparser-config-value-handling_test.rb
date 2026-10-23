require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"

# kubernetes/linux/main.sh sources the shell files these parsers generate, so an unquoted value
# is subject to shell processing instead of arriving as configured. The values are rendered as
# single-quoted literals; these tests pin that a value containing shell syntax is left intact
# and that ordinary values still arrive unchanged.
class TomlParserConfigValueHandlingTest < Minitest::Test
  REPO = File.expand_path("../../../..", __dir__)
  SHELL_SYNTAX = "true$(touch EVALUATED)"

  COMMON = {
    source: "build/common/installer/scripts/tomlparser-common-agent-config.rb",
    mount: "/etc/config/settings/agent-settings",
    output: "common_agent_config_env_var",
  }.freeze

  METRIC = {
    source: "build/linux/installer/scripts/tomlparser-metric-collection-config.rb",
    mount: "/etc/config/settings/metric_collection_settings",
    output: "config_metric_collection_env_var",
  }.freeze

  LOG = {
    source: "build/common/installer/scripts/tomlparser.rb",
    mount: "/etc/config/settings/log-data-collection-settings",
    output: "config_env_var",
  }.freeze

  # Generates the shell file, then sources it the way main.sh does. Returns whether the shell
  # processed the value and what bash ended up with. The parser's hardcoded image paths are
  # repointed at the fixture, so this needs no agent image.
  def source_generated(parser, toml, vars = [])
    Dir.mktmpdir do |dir|
      settings = File.join(dir, "settings")
      File.write(settings, toml)

      source = File.read(File.join(REPO, parser[:source]))
                   .sub(parser[:mount].inspect, settings.inspect)
                   .sub('require_relative "/etc/fluent/plugin/constants"',
                        "require_relative #{File.join(REPO, "source/plugins/ruby/constants.rb").inspect}")
      File.write(File.join(dir, "parser.rb"), source)
      FileUtils.cp(File.join(REPO, "build/common/installer/scripts/ConfigParseErrorLogger.rb"), dir)

      Open3.capture3({ "AZMON_AGENT_CFG_SCHEMA_VERSION" => "v1" },
                     RbConfig.ruby, File.join(dir, "parser.rb"), chdir: dir)

      script = ". ./#{parser[:output]}; " + vars.map { |v| "printf '%s\\n' \"$#{v}\"" }.join("; ")
      out, = Open3.capture3("bash", "-c", script, chdir: dir)
      return { evaluated: File.exist?(File.join(dir, "EVALUATED")), values: out.split("\n", -1) }
    end
  end

  def test_common_agent_shell_syntax_is_not_processed
    result = source_generated(COMMON, <<~TOML, %w[DISABLE_TELEMETRY ENABLE_HIGH_LOG_SCALE_MODE ENABLE_CUSTOM_METRICS])
      [agent_settings.telemetry_config]
      disable_telemetry = "#{SHELL_SYNTAX}"

      [agent_settings.high_log_scale]
      enabled = "#{SHELL_SYNTAX}"

      [agent_settings.custom_metrics]
      enabled = "#{SHELL_SYNTAX}"
    TOML

    refute result[:evaluated], "sourcing the generated file let the shell process the config map value"
    # The literal text survives, which is what keeps this from changing behaviour. What matters
    # is that it is inert and never equals the "true" the consumers look for.
    result[:values].first(3).each { |v| refute_equal "true", v.to_s.downcase }
  end

  def test_metric_collection_shell_syntax_is_not_processed
    result = source_generated(METRIC, <<~TOML, %w[AZMON_PV_COLLECT_KUBE_SYSTEM_METRICS])
      [metric_collection_settings.collect_kube_system_pv_metrics]
      enabled = "#{SHELL_SYNTAX}"
    TOML

    refute result[:evaluated], "sourcing the generated file let the shell process the config map value"
    refute_equal "true", result[:values].first.to_s.downcase
  end

  def test_log_collection_shell_syntax_is_not_processed
    result = source_generated(LOG, <<~TOML, %w[AZMON_COLLECT_STDOUT_LOGS])
      [log_collection_settings.stdout]
      enabled = "#{SHELL_SYNTAX}"
      exclude_namespaces = ["kube-system","#{SHELL_SYNTAX}"]
      [log_collection_settings.schema]
      containerlog_schema_version = "#{SHELL_SYNTAX}"
      [log_collection_settings.enrich_container_logs]
      enabled = "#{SHELL_SYNTAX}"
    TOML

    refute result[:evaluated], "sourcing the generated file let the shell process the config map value"
  end

  # A value containing a single quote is the case naive escaping gets wrong.
  def test_quote_in_value_cannot_break_out
    result = source_generated(LOG, <<~TOML, %w[AZMON_STDOUT_EXCLUDED_NAMESPACES])
      [log_collection_settings.stdout]
      enabled = true
      exclude_namespaces = ["it's$(touch EVALUATED)"]
    TOML

    refute result[:evaluated], "a single quote in the value broke out of the quoted literal"
    assert_equal "it's$(touch EVALUATED)", result[:values].first
  end

  def test_ordinary_values_are_unchanged
    result = source_generated(COMMON, <<~TOML, %w[DISABLE_TELEMETRY ENABLE_HIGH_LOG_SCALE_MODE])
      [agent_settings.telemetry_config]
      disable_telemetry = true

      [agent_settings.high_log_scale]
      enabled = "TRUE"
    TOML

    refute result[:evaluated]
    assert_equal "true", result[:values][0]
    assert_equal "TRUE", result[:values][1], "the value must reach bash exactly as configured"
  end

  def test_ordinary_log_collection_values_are_unchanged
    result = source_generated(LOG, <<~TOML, %w[AZMON_COLLECT_STDOUT_LOGS AZMON_STDOUT_EXCLUDED_NAMESPACES AZMON_CONTAINER_LOG_SCHEMA_VERSION])
      [log_collection_settings.stdout]
      enabled = true
      exclude_namespaces = ["kube-system","gatekeeper-system"]
      [log_collection_settings.schema]
      containerlog_schema_version = "v2"
    TOML

    assert_equal "true", result[:values][0]
    assert_equal "kube-system,gatekeeper-system", result[:values][1]
    assert_equal "v2", result[:values][2]
  end
end
