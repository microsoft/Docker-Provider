require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"

class FluentBitConfCustomizerTest < Minitest::Test
  SCRIPTS_DIR = File.expand_path(__dir__)
  REPO_ROOT = File.expand_path("../../../..", SCRIPTS_DIR)
  MULTILINE_PARSERS_CONF = File.join(REPO_ROOT, "build/common/installer/conf/azm-containers-parser-multiline.conf")
  CONF_DIRS = {
    "linux" => ["/etc/opt/microsoft/docker-cimprov", "build/linux/installer/conf"],
    "windows" => ["/etc/fluent-bit", "build/windows/installer/conf"],
  }.freeze
  CUSTOMIZERS = [
    ["fluent-bit-conf-customizer.rb", "fluent-bit.conf", []],
    ["fluent-bit-geneva-conf-customizer.rb", "fluent-bit-geneva.conf", ["common"]],
  ].freeze

  # Runs a customizer against the shipped conf files in a sandbox and returns the rendered conf_name.
  def render(script_name, conf_name, os_type: "linux", enabled: "true", languages: "go,java,python", args: [])
    Dir.mktmpdir("fluent-bit-conf-customizer-test") do |sandbox|
      FileUtils.cp(File.join(SCRIPTS_DIR, "ConfigParseErrorLogger.rb"), sandbox)
      script = File.join(sandbox, script_name)
      File.write(script, File.read(File.join(SCRIPTS_DIR, script_name)).gsub('"/etc/', "\"#{sandbox}/etc/"))
      target_dir, source_dir = CONF_DIRS.fetch(os_type)
      conf_dir = File.join(sandbox, target_dir)
      FileUtils.mkdir_p(conf_dir)
      ["fluent-bit.conf", "fluent-bit-common.conf", "fluent-bit-geneva.conf"].each do |name|
        FileUtils.cp(File.join(REPO_ROOT, source_dir, name), conf_dir)
      end
      env = { "OS_TYPE" => os_type, "AZMON_MULTILINE_ENABLED" => enabled, "AZMON_MULTILINE_LANGUAGES" => languages }
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, script, *args, chdir: sandbox)
      assert status.success?, "#{script_name} failed: #{stdout}\n#{stderr}"
      refute_includes stderr, "config::error", "#{script_name} logged an error"
      File.read(File.join(conf_dir, conf_name))
    end
  end

  def multiline_parser_setting(conf)
    conf.lines.map(&:strip).find { |line| line.start_with?("multiline.parser") }
  end

  def test_java_renders_as_azmon_java
    CUSTOMIZERS.product(CONF_DIRS.keys).each do |(script, conf_name, args), os_type|
      conf = render(script, conf_name, os_type: os_type, args: args)
      assert_equal "multiline.parser go,azmon_java,python", multiline_parser_setting(conf), "#{script} on #{os_type}"
      assert_includes conf, "azm-containers-parser-multiline.conf", "#{script} on #{os_type}"
    end
  end

  def test_languages_without_java_are_unchanged
    CUSTOMIZERS.each do |script, conf_name, args|
      conf = render(script, conf_name, languages: "go,python", args: args)
      assert_equal "multiline.parser go,python", multiline_parser_setting(conf), script
    end
  end

  def test_disabled_multiline_keeps_placeholders
    CUSTOMIZERS.each do |script, conf_name, args|
      conf = render(script, conf_name, enabled: "false", args: args)
      assert_includes conf, '#${MultilineLanguages}', script
      refute_includes conf, "azmon_java", script
    end
  end

  # fluent-bit evaluates multiline rules with Onigmo, the same regex engine as Ruby.
  def test_azmon_java_start_rule_matches_headers_without_trailing_newline
    section = File.read(MULTILINE_PARSERS_CONF).split("[MULTILINE_PARSER]").find { |s| s.match?(/^\s*name\s+azmon_java\s*$/) }
    refute_nil section, "azmon_java is not defined in azm-containers-parser-multiline.conf"
    start_rule = section[/^\s*rule\s+"start_state[^"]*"\s+"\/(.+)\/"\s+"\w+"\s*$/, 1]
    refute_nil start_rule, "azmon_java has no start_state rule"
    start = Regexp.new(start_rule)

    # containerd (CRI) log lines have no trailing newline; Docker json-file lines do.
    [
      "java.lang.NullPointerException",
      "Exception in thread \"main\" java.lang.IllegalStateException",
      "java.lang.OutOfMemoryError",
      "java.lang.IllegalStateException: boom",
      "java.lang.IllegalStateException: boom\n",
      "System.InvalidOperationException",
    ].each { |header| assert_match start, header }
    ["\tat com.example.Foo.bar(Foo.java:42)", "INFO request completed"].each { |line| refute_match start, line }
  end
end
