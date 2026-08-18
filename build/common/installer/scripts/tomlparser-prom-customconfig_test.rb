require "minitest/autorun"
require "tomlrb"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"

# Regression tests for the container-azm-ms-agentconfig -> telegraf configuration generation.
#
# Values in that config map are attacker supplied whenever someone has write access to it. They
# must never be able to change the *structure* of the generated telegraf configuration, because
# telegraf plugins such as [[inputs.exec]] run shell commands inside a privileged agent.
#
# The payloads below deliberately try to break out of a quoted TOML assignment and declare an
# extra plugin. Nothing here runs telegraf; the tests only assert on generated text.

class PromCustomConfigTest < Minitest::Test
  SCRIPTS_DIR = File.expand_path(__dir__)
  PARSER_PATH = File.join(SCRIPTS_DIR, "tomlparser-prom-customconfig.rb")
  REPO_ROOT = File.expand_path("../../../..", SCRIPTS_DIR)

  # Loading the parser gives direct access to its helpers. The top level code is a no-op unless
  # a config map is mounted at the hard coded agent path, which is not the case on a test machine.
  load PARSER_PATH

  # Terminates the quoted assignment it lands in, adds a plugin, then comments out the trailing
  # quote so that the result would still be valid TOML.
  BREAKOUT = "1m\"\n[[inputs.exec]]\n  commands = [\"/bin/sh -c 'touch /tmp/ci-injection-sentinel'\"]\n#"

  SCENARIOS = {
    replicaset: {
      env: { "CONTROLLER_TYPE" => "replicaset", "SIDECAR_SCRAPING_ENABLED" => "false" },
      template: "build/linux/installer/conf/telegraf-rs.conf",
      template_dest: "etc/opt/microsoft/docker-cimprov/telegraf-rs.conf",
      generated: "opt/telegraf-test-rs.conf",
      section: "cluster",
      # The replica set has no default for this setting, so it is always set explicitly here to
      # keep the generated file complete.
      base_body: "monitor_kubernetes_pods = false",
    },
    sidecar: {
      env: { "CONTROLLER_TYPE" => "daemonset", "CONTAINER_TYPE" => "PrometheusSidecar" },
      template: "build/linux/installer/conf/telegraf-prom-side-car.conf",
      template_dest: "etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf",
      generated: "opt/telegraf-test-prom-side-car.conf",
      section: "cluster",
    },
    daemonset: {
      env: { "CONTROLLER_TYPE" => "daemonset" },
      template: "build/linux/installer/conf/telegraf.conf",
      template_dest: "etc/opt/microsoft/docker-cimprov/telegraf.conf",
      generated: "opt/telegraf-test.conf",
      section: "node",
    },
    windows: {
      env: { "CONTROLLER_TYPE" => "daemonset", "OS_TYPE" => "windows", "SIDECAR_SCRAPING_ENABLED" => "true" },
      template: "build/windows/installer/conf/telegraf.conf",
      template_dest: "etc/telegraf/telegraf.conf",
      generated: "etc/telegraf/telegraf.conf",
      section: "cluster",
    },
  }.freeze

  @@baselines = {}

  # Runs the real parser against a config map in a sandbox. The parser reads and writes absolute
  # agent paths, so those prefixes are rewritten to point inside the sandbox.
  def run_parser(scenario, configmap)
    spec = SCENARIOS.fetch(scenario)
    result = nil

    Dir.mktmpdir("prom-customconfig-test") do |sandbox|
      ["etc/config/settings", "opt", "etc/opt/microsoft/docker-cimprov", "etc/telegraf"].each do |dir|
        FileUtils.mkdir_p(File.join(sandbox, dir))
      end

      File.write(File.join(sandbox, "etc/config/settings/prometheus-data-collection-settings"), configmap)
      FileUtils.cp(File.join(REPO_ROOT, spec[:template]), File.join(sandbox, spec[:template_dest]))
      FileUtils.cp(File.join(SCRIPTS_DIR, "ConfigParseErrorLogger.rb"), File.join(sandbox, "ConfigParseErrorLogger.rb"))

      parser = File.join(sandbox, "parser.rb")
      source = File.read(PARSER_PATH)
      source = source.gsub('"/etc/', "\"#{sandbox}/etc/").gsub('"/opt/', "\"#{sandbox}/opt/")
      File.write(parser, source)

      env = {
        "AZMON_AGENT_CFG_SCHEMA_VERSION" => "v1",
        "CONTROLLER_TYPE" => nil,
        "CONTAINER_TYPE" => nil,
        "OS_TYPE" => nil,
        "SIDECAR_SCRAPING_ENABLED" => nil,
      }.merge(spec[:env])

      stdout, stderr, = Open3.capture3(env, RbConfig.ruby, parser, chdir: sandbox)

      telemetry_path = File.join(sandbox, "telemetry_prom_config_env_var")
      result = {
        conf: File.read(File.join(sandbox, spec[:generated])),
        telemetry: File.exist?(telemetry_path) ? File.read(telemetry_path) : nil,
        stdout: stdout,
        stderr: stderr,
      }
    end

    result
  end

  def configmap_for(scenario, body)
    spec = SCENARIOS.fetch(scenario)
    lines = []
    base = spec[:base_body]
    lines << base if base && !body.include?("monitor_kubernetes_pods")
    lines << body
    "[prometheus_data_collection_settings.#{spec[:section]}]\n#{lines.join("\n")}\n"
  end

  # After this parser runs the file still contains placeholders owned by other config parsers
  # (osm, npm, subnet usage), and telegraf resolves its own $ENV references at load time.
  # Neutralize what is left so the generated file can be parsed as TOML.
  def parse_generated_toml(conf)
    normalized = conf.gsub(/^(\s*[\w.]+\s*=\s*)\$[A-Z0-9_]+[ \t]*$/) { "#{Regexp.last_match(1)}[]" }
    normalized = normalized.gsub(/^[ \t]*\$[A-Z0-9_]+[ \t]*$/, "")
    # tomlrb 2.0.1, the version the agent ships, cannot parse inline tables that use quoted
    # keys (the templates contain `tags = {"interface" = ["lo"]}`). Collapse inline table
    # values so the rest of the file parses on every 2.x release. Injected plugins declare
    # their own `[[inputs.x]]` table headers, which this leaves untouched.
    normalized = normalized.gsub(/^(\s*[\w.]+\s*=\s*)\{[^{}\n]*\}[ \t]*$/) { "#{Regexp.last_match(1)}{}" }
    Tomlrb.parse(normalized)
  end

  # The names of every telegraf input plugin declared in a generated configuration.
  def input_plugins(conf)
    (parse_generated_toml(conf)["inputs"] || {}).keys.sort
  end

  def baseline_plugins(scenario)
    @@baselines[scenario] ||= input_plugins(run_parser(scenario, configmap_for(scenario, "interval = \"1m\""))[:conf])
  end

  # The core security property: untrusted config map content cannot add telegraf plugins.
  # Values themselves may still appear in the output, but only escaped inside a single string.
  def assert_no_injected_plugins(scenario, conf, context)
    plugins = input_plugins(conf)
    refute_includes plugins, "exec", "an [[inputs.exec]] plugin was injected via #{context}"
    assert_equal baseline_plugins(scenario), plugins,
                 "the set of telegraf input plugins changed via #{context}"
    refute_match(/^\s*\[\[inputs\./, conf.lines.grep(/ci-injection-sentinel/).join,
                 "the payload produced a plugin table via #{context}")
  end

  # --- interval validation ------------------------------------------------------------------

  def test_valid_telegraf_durations_are_accepted
    # Units documented in kubernetes/container-azm-ms-agentconfig.yaml, plus the fractional and
    # compound forms that go's time.ParseDuration (and therefore telegraf) accepts.
    ["1m", "30s", "60s", "1h", "5ms", "100us", "250ns", "1.5s", "0.5m", ".5s", "1h30m", "2h45m30s",
     "1\u00B5s", "1\u03BCs"].each do |value|
      assert isValidTelegrafInterval(value), "expected #{value.inspect} to be a valid interval"
    end
  end

  def test_invalid_telegraf_durations_are_rejected
    [
      BREAKOUT,                 # the reported injection payload
      "1m\n[[inputs.exec]]",    # newline breakout
      "1m\"",                   # closes the surrounding quote
      "1m ",                    # trailing whitespace
      " 1m",                    # leading whitespace
      "1m\\",                   # trailing escape
      "1m;id",                  # shell metacharacters
      "$(id)",
      "`id`",
      "1d",                     # rejected: the telegraf shipped on windows does not support days
      "1",                      # missing unit
      "m",                      # missing number
      "",
      "0s",                     # zero durations cannot scrape
      "0h0m0s",
      "-1m",                    # negative durations cannot scrape
      "1m\t",
      "1m\u0000",
      nil,
      60,
    ].each do |value|
      refute isValidTelegrafInterval(value), "expected #{value.inspect} to be an invalid interval"
    end
  end

  # Anchoring on ^ and $ instead of \A and \z would make this pass, which is the mistake that
  # allows a payload to hide on a second line.
  def test_multiline_interval_is_rejected
    refute isValidTelegrafInterval("1m\n[[inputs.exec]]\ncommands = [\"id\"]")
  end

  def test_interval_falls_back_to_default_without_echoing_input
    assert_equal "1m", resolveInterval(nil, "1m", "test")
    assert_equal "1m", resolveInterval(BREAKOUT, "1m", "test")
    assert_equal "45s", resolveInterval("45s", "1m", "test")
  end

  # --- toml serialization -------------------------------------------------------------------

  def test_toml_basic_string_escapes_structural_characters
    assert_equal "\"1m\"", toTomlBasicString("1m")
    assert_equal "\"a\\\"b\"", toTomlBasicString("a\"b")
    assert_equal "\"a\\\\b\"", toTomlBasicString("a\\b")
    assert_equal "\"a\\nb\"", toTomlBasicString("a\nb")
    assert_equal "\"a\\tb\"", toTomlBasicString("a\tb")
    assert_equal "\"\\u0007\"", toTomlBasicString("\a")
    assert_equal "\"\"", toTomlBasicString(nil)
  end

  def test_toml_basic_string_output_is_a_single_parseable_value
    parsed = Tomlrb.parse("value = #{toTomlBasicString(BREAKOUT)}")
    assert_equal BREAKOUT, parsed["value"]
    assert_nil parsed["inputs"]
  end

  def test_toml_string_array_matches_previous_format_for_safe_values
    assert_equal "[]", toTomlStringArray([])
    assert_equal "[]", toTomlStringArray(nil)
    assert_equal "[\"a\"]", toTomlStringArray(["a"])
    assert_equal "[\"a\",\"b\"]", toTomlStringArray(["a", "b"])
  end

  def test_toml_string_array_escapes_structural_characters
    parsed = Tomlrb.parse("urls = #{toTomlStringArray(["http://ok", BREAKOUT])}")
    assert_equal ["http://ok", BREAKOUT], parsed["urls"]
    assert_nil parsed["inputs"]
  end

  def test_kubernetes_namespace_validation
    ["default", "kube-system", "a", "a1-b2"].each do |value|
      assert isValidKubernetesNamespace(value), "expected #{value.inspect} to be a valid namespace"
    end
    ["", "-bad", "bad-", "Bad", "a b", "a\"b", "a\nb", "a" * 64, nil].each do |value|
      refute isValidKubernetesNamespace(value), "expected #{value.inspect} to be an invalid namespace"
    end
  end

  # --- end to end generation ----------------------------------------------------------------

  SCENARIOS.each_key do |scenario|
    define_method("test_interval_breakout_is_neutralized_#{scenario}") do
      result = run_parser(scenario, configmap_for(scenario, "interval = '''#{BREAKOUT}'''"))
      assert_no_injected_plugins(scenario, result[:conf], "the #{scenario} interval")
      # An invalid interval is dropped entirely, so the payload must not appear at all.
      refute_includes result[:conf], "ci-injection-sentinel"
      # The rejected value falls back to the default instead of being partially applied.
      assert_includes result[:conf], "interval = \"1m\""
    end

    define_method("test_fieldpass_breakout_is_neutralized_#{scenario}") do
      result = run_parser(scenario, configmap_for(scenario, "fieldpass = ['''#{BREAKOUT}''']"))
      assert_no_injected_plugins(scenario, result[:conf], "the #{scenario} fieldpass array")
      # The value survives, but only as a single escaped string.
      assert_includes collect_values(result[:conf], "fieldpass"), BREAKOUT
    end

    define_method("test_fielddrop_breakout_is_neutralized_#{scenario}") do
      result = run_parser(scenario, configmap_for(scenario, "fielddrop = ['''#{BREAKOUT}''']"))
      assert_no_injected_plugins(scenario, result[:conf], "the #{scenario} fielddrop array")
      assert_includes collect_values(result[:conf], "fielddrop"), BREAKOUT
    end

    define_method("test_valid_settings_are_preserved_#{scenario}") do
      result = run_parser(scenario, configmap_for(scenario, "interval = \"45s\"\nfieldpass = [\"a\",\"b\"]"))
      assert_includes result[:conf], "interval = \"45s\"", "a valid interval must be preserved"
      assert_includes result[:conf], "fieldpass = [\"a\",\"b\"]", "array formatting must be unchanged"
      assert_no_injected_plugins(scenario, result[:conf], "a benign #{scenario} configuration")
    end
  end

  def test_urls_breakout_is_neutralized
    result = run_parser(:daemonset, configmap_for(:daemonset, "urls = ['''#{BREAKOUT}''']"))
    assert_no_injected_plugins(:daemonset, result[:conf], "the node urls array")
  end

  def test_kubernetes_services_breakout_is_neutralized
    result = run_parser(:replicaset, configmap_for(:replicaset, "kubernetes_services = ['''#{BREAKOUT}''']"))
    assert_no_injected_plugins(:replicaset, result[:conf], "the cluster kubernetes_services array")
  end

  def test_label_and_field_selector_breakout_is_neutralized
    body = "monitor_kubernetes_pods = false\n" \
           "kubernetes_label_selector = '''#{BREAKOUT}'''\n" \
           "kubernetes_field_selector = '''#{BREAKOUT}'''"
    result = run_parser(:replicaset, configmap_for(:replicaset, body))
    assert_no_injected_plugins(:replicaset, result[:conf], "the cluster label and field selectors")
  end

  def test_namespace_breakout_is_neutralized
    body = "monitor_kubernetes_pods = true\n" \
           "monitor_kubernetes_pods_namespaces = [\"default\", '''#{BREAKOUT}''']"
    result = run_parser(:replicaset, configmap_for(:replicaset, body))
    assert_no_injected_plugins(:replicaset, result[:conf], "the monitored namespaces")
    # The valid namespace is still configured; the invalid one is dropped.
    namespaces = monitored_namespaces(result[:conf])
    assert_equal ["default"], namespaces
  end

  def test_namespace_plugins_are_generated_for_valid_namespaces
    body = "monitor_kubernetes_pods = true\n" \
           "monitor_kubernetes_pods_namespaces = [\"default\", \"kube-system\"]"
    result = run_parser(:replicaset, configmap_for(:replicaset, body))
    assert_equal ["default", "kube-system"], monitored_namespaces(result[:conf])
    assert_no_injected_plugins(:replicaset, result[:conf], "a benign namespace configuration")
  end

  def test_selectors_are_escaped_in_generated_namespace_plugins
    body = "monitor_kubernetes_pods = true\n" \
           "monitor_kubernetes_pods_namespaces = [\"default\"]\n" \
           "kubernetes_label_selector = '''#{BREAKOUT}'''"
    result = run_parser(:replicaset, configmap_for(:replicaset, body))
    assert_no_injected_plugins(:replicaset, result[:conf], "a selector inside a namespace plugin")
    plugin = parse_generated_toml(result[:conf])["inputs"]["prometheus"]
             .find { |entry| entry["monitor_kubernetes_pods_namespace"] == "default" }
    assert_equal BREAKOUT, plugin["kubernetes_label_selector"]
  end

  def monitored_namespaces(conf)
    parse_generated_toml(conf)["inputs"]["prometheus"]
      .map { |plugin| plugin["monitor_kubernetes_pods_namespace"] }
      .compact
  end

  # Every value configured for the given key across all generated prometheus plugins.
  def collect_values(conf, key)
    parse_generated_toml(conf)["inputs"]["prometheus"].flat_map { |plugin| plugin[key] || [] }
  end

  # --- telemetry file is sourced by main.sh, so it must never carry shell syntax -------------

  def test_telemetry_file_cannot_inject_shell_commands
    [:replicaset, :daemonset].each do |scenario|
      result = run_parser(scenario, configmap_for(scenario, "interval = '''#{BREAKOUT}'''"))
      telemetry = result[:telemetry]
      refute_nil telemetry, "expected a telemetry file for #{scenario}"

      telemetry.each_line do |line|
        next if line.strip.empty?
        assert_match(/\Aexport [A-Z0-9_]+="?[A-Za-z0-9_.]*"?\n?\z/, line,
                     "telemetry line for #{scenario} is not an inert assignment: #{line.inspect}")
      end

      # Sourcing the file must not run anything.
      Dir.mktmpdir("telemetry-source-test") do |dir|
        File.write(File.join(dir, "telemetry"), telemetry)
        sentinel = File.join(dir, "sentinel")
        _, _, status = Open3.capture3(
          "bash", "-c", "source ./telemetry >/dev/null 2>&1; exit 0", chdir: dir
        )
        assert_equal 0, status.exitstatus, "sourcing the #{scenario} telemetry file failed"
        refute File.exist?(sentinel), "sourcing the #{scenario} telemetry file executed a command"
      end
    end
  end
end
