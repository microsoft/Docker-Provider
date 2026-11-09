require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"
require "json"
require "tomlrb"

# kubernetes/linux/main.sh sources the shell files these parsers generate, so an unquoted value
# is subject to shell processing instead of arriving as configured. The values are rendered as
# single-quoted literals; these tests pin that a value containing shell syntax is left intact
# and that ordinary values still arrive unchanged.
class TomlParserConfigValueHandlingTest < Minitest::Test
  REPO = File.expand_path("../../../..", __dir__)
  SHELL_SYNTAX = "true$(touch EVALUATED)"
  SHELL_BREAKOUT = "true'; touch EVALUATED; #"

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

  AGENT = COMMON.merge(source: "build/common/installer/scripts/tomlparser-agent-config.rb",
                       output: "agent_config_env_var").freeze

  OSM = {
    source: "build/linux/installer/scripts/tomlparser-osm-config.rb",
    mount: "/etc/config/osm-settings/osm-metric-collection-configuration",
    output: "integration_osm_config_env_var",
  }.freeze

  # Generates the shell file, then sources it the way main.sh does. Returns whether the shell
  # processed the value and what bash ended up with. The parser's hardcoded image paths are
  # repointed at the fixture, so this needs no agent image.
  def source_generated(parser, toml, vars = [], persist_to_bashrc: false)
    Dir.mktmpdir do |dir|
      settings = File.join(dir, "settings")
      File.write(settings, toml)

      source = File.read(File.join(REPO, parser[:source]))
                   .sub(parser[:mount].inspect, settings.inspect)
                   .sub('require_relative "/etc/fluent/plugin/constants"',
                        "require_relative #{File.join(REPO, "source/plugins/ruby/constants.rb").inspect}")
      tenant_dir = File.join(dir, "tenant")
      FileUtils.mkdir_p(tenant_dir)
      template = "fluent-bit-azmon-logs_tenant.conf"
      FileUtils.cp(File.join(REPO, "build/linux/installer/conf", template), tenant_dir)
      source = source.gsub("/etc/opt/microsoft/docker-cimprov/", "#{tenant_dir}/")
                     .gsub('"/opt/', "\"#{dir}/")
      File.write(File.join(dir, "telegraf-test-rs.conf"), "$AZMON_TELEGRAF_OSM_PROM_PLUGINS")
      File.write(File.join(dir, "parser.rb"), source)
      FileUtils.cp(File.join(REPO, "build/common/installer/scripts/ConfigParseErrorLogger.rb"), dir)

      output, parser_error, status = Open3.capture3({
        "AZMON_AGENT_CFG_SCHEMA_VERSION" => "v1", "AZMON_OSM_CFG_SCHEMA_VERSION" => "v1",
        "OS_TYPE" => "linux", "CONTROLLER_TYPE" => "replicaset",
        "CONTAINER_TYPE" => nil, "SIDECAR_SCRAPING_ENABLED" => "false",
      }, RbConfig.ruby, File.join(dir, "parser.rb"), chdir: dir)
      assert status.success?, "parser failed: #{output}\n#{parser_error}"

      commands = if persist_to_bashrc
                   main = File.read(File.join(REPO, "kubernetes/linux/main.sh"))
                   file = Regexp.escape(parser[:output])
                   copy_loop = main[/cat #{file} \| while[^\n]*\n[^\n]*\n\s*done|while[^\n]*\n[^\n]*\n\s*done < #{file}/]
                   raise "could not find the #{parser[:output]} copy loop in main.sh" unless copy_loop

                   "#{copy_loop}; . \"$HOME/.bashrc\""
                 else
                   ". ./#{parser[:output]}"
                 end
      script = commands + "; " + vars.map { |v| "printf '%s\\n' \"$#{v}\"" }.join("; ")
      out, error, status = Open3.capture3({ "HOME" => dir, "BASH_ENV" => nil }, "bash", "-c",
                                        "set -e\n#{script}", chdir: dir)
      assert status.success?, "sourcing settings failed: #{error}"
      return {
        evaluated: %w[EVALUATED evaluated].any? { |name| File.exist?(File.join(dir, name)) }, values: out.split("\n", -1),
        tenants: Dir.glob(File.join(tenant_dir, "*_tenant_*.conf")).to_h { |p| [File.basename(p), File.read(p)] },
        telegraf: File.read(File.join(dir, "telegraf-test-rs.conf")),
        output: output + parser_error,
      }
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

  def test_quote_survives_copy_to_bashrc
    result = source_generated(COMMON, <<~TOML, %w[ENABLE_CUSTOM_METRICS], persist_to_bashrc: true)
      [agent_settings.custom_metrics]
      enabled = "#{SHELL_BREAKOUT}"
    TOML

    refute result[:evaluated], "copying the generated file to .bashrc let the shell process the value"
    assert_equal SHELL_BREAKOUT, result[:values].first
  end

  def test_metric_quote_survives_copy_to_bashrc
    result = source_generated(METRIC, <<~TOML, %w[AZMON_PV_COLLECT_KUBE_SYSTEM_METRICS], persist_to_bashrc: true)
      [metric_collection_settings.collect_kube_system_pv_metrics]
      enabled = "#{SHELL_BREAKOUT}"
    TOML

    refute result[:evaluated], "copying the generated file to .bashrc let the shell process the value"
    assert_equal SHELL_BREAKOUT, result[:values].first
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

  def test_agent_duration_values_cannot_smuggle_new_lines
    valid = source_generated(AGENT, <<~TOML, %w[NETWORKFLOW_LOGS_THROTTLE_INTERVAL FBIT_TAIL_IGNORE_OLDER])
      [agent_settings.networkflow_logs_config]
      throttle_interval = "1.5m"
      [agent_settings.fbit_config]
      tail_ignore_older = "5m"
    TOML
    assert_equal ["1.5m", "5m"], valid[:values].first(2)

    result = source_generated(AGENT, <<~TOML, %w[NETWORKFLOW_LOGS_THROTTLE_INTERVAL FBIT_TAIL_IGNORE_OLDER])
      [agent_settings.networkflow_logs_config]
      throttle_interval = "5s\\ntouch EVALUATED\\n#"
      [agent_settings.fbit_config]
      tail_ignore_older = "1m\\ntouch EVALUATED\\n#"
    TOML
    refute result[:evaluated], "sourcing settings executed an embedded-newline duration"
    assert_equal ["1s", ""], result[:values].first(2)
  end

  def test_version_files_are_literal_after_startup_and_later_source
    main = File.read(File.join(REPO, "kubernetes/linux/main.sh"))
    helper = main[/^setGlobalEnvVar\(\) \{.*?^\}/m]
    block = main[/^#set agent config schema version.*?(?=^# common agent config)/m]
    refute_nil helper
    refute_nil block
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "settings"))
      FileUtils.mkdir_p(File.join(dir, "osm-settings"))
      value = "$(>PWNED)"
      %w[settings/schema-version settings/config-version osm-settings/schema-version].each do |file|
        File.write(File.join(dir, file), value)
      end
      File.write(File.join(dir, ".bashrc"), "source ./env_vars\n")
      File.write(File.join(dir, "env_vars"), "")
      script = (helper + "\n" + block).gsub("/opt/env_vars", "./env_vars").gsub("/etc/config/", "./")
      script += "\nsource \"$HOME/.bashrc\"\nprintf '%s\\n' \"$AZMON_AGENT_CFG_SCHEMA_VERSION\" \"$AZMON_AGENT_CFG_FILE_VERSION\" \"$AZMON_OSM_CFG_SCHEMA_VERSION\""
      out, error, status = Open3.capture3({
        "HOME" => dir, "BASH_ENV" => nil, "CONTAINER_TYPE" => "PrometheusSidecar",
      }, "bash", "-c", "set -e\n#{script}", chdir: dir)
      assert status.success?, error
      refute File.exist?(File.join(dir, "PWNED")), "version metadata was executed"
      assert_equal [value] * 3, out.lines.last(3).map(&:strip)
    end
  end

  def test_tenant_settings_cannot_add_fluent_bit_sections
    payload = "2G\n[INPUT]\n Name dummy"
    namespace_payload = "tenant-c\ntouch EVALUATED\n#"
    result = source_generated(LOG, <<~TOML, %w[AZMON_MULTI_TENANCY_SVC_BUFFER_CHUNK_SIZE AZMON_MULTI_TENANCY_SVC_BUFFER_MAX_SIZE AZMON_MULTI_TENANCY_NAMESPACES])
      [log_collection_settings.multi_tenancy]
      enabled = true
      advanced_mode_enabled = true
      namespaces = [" Tenant-A ", "tenant-b", #{JSON.generate(namespace_payload)}]
      storage_type = "Filesystem"
      mem_buf_limit = #{JSON.generate(payload)}
      namespace_settings = [#{JSON.generate("tenant-a:mem_buf_limit=\\';buffer_max_size=#{payload};throttle_interval=1d")}, #{JSON.generate("#{namespace_payload}:mem_buf_limit=1M")}]
      service_buffer_chunk_size = #{JSON.generate(payload)}
      service_buffer_max_size = "30m\\r[OUTPUT]"
    TOML
    assert_equal "tenant-a,tenant-b", result[:values][2]
    refute result[:evaluated], "sourcing settings executed a multiline tenant namespace"
    assert_includes result[:output], "Invalid multi-tenancy namespace, skipping entry"
    assert_includes result[:output], "Invalid multi-tenancy namespace_settings entry, skipping entry"
    assert_equal %w[fluent-bit-azmon-logs_tenant_tenant-a.conf fluent-bit-azmon-logs_tenant_tenant-b.conf], result[:tenants].keys.sort
    result[:tenants].each_value do |conf|
      assert_equal 1, conf.scan(/^\[INPUT\]/).length
      assert_equal 1, conf.scan(/^\[OUTPUT\]/).length
      refute_includes conf, payload
      assert_includes conf, "Filesystem"
    end
    assert_includes result[:tenants].values.first, "\\'"
    assert_includes result[:tenants].values.first, "1d"
    assert_equal ["10m", "30m"], result[:values].first(2)
    assert_includes result[:output], "Invalid"
  end

  def test_osm_namespace_cannot_add_telegraf_plugins
    payload = "bad\"\n[[inputs.exec]]\ncommands = [\"unused\"]\n#"
    result = source_generated(OSM, <<~TOML)
      [osm_metric_collection_configuration.settings]
      monitor_namespaces = [" kube-system ", #{JSON.generate(payload)}]
    TOML
    conf = Tomlrb.parse(result[:telegraf])
    assert_equal ["prometheus"], conf.fetch("inputs").keys
    assert_equal ["kube-system"], conf["inputs"]["prometheus"].map { |p| p["monitor_kubernetes_pods_namespace"] }
  end
end
