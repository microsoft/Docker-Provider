require "minitest/autorun"
require "open3"
require "tmpdir"

require_relative "../../../build/common/installer/scripts/ConfigValueSanitizer"
require_relative "parser_test_helper"

class ConfigValueSanitizerTests < Minitest::Test
  def test_shell_quote_wraps_value_in_single_quotes
    assert_equal "'kube-system'", ConfigValueSanitizer.shell_quote("kube-system")
  end

  def test_shell_quote_handles_empty_and_nil_values
    assert_equal "''", ConfigValueSanitizer.shell_quote("")
    assert_equal "''", ConfigValueSanitizer.shell_quote(nil)
  end

  def test_shell_quote_escapes_embedded_single_quote
    assert_equal "'a'\\''b'", ConfigValueSanitizer.shell_quote("a'b")
  end

  def test_single_line_replaces_line_breaks
    assert_equal "prod INJECTED=1", ConfigValueSanitizer.single_line("prod\nINJECTED=1")
    assert_equal "prod INJECTED=1", ConfigValueSanitizer.single_line("prod\r\nINJECTED=1")
  end

  def test_valid_accepts_only_full_matches_of_non_empty_strings
    pattern = /\A[A-Za-z0-9_\-\.]{1,64}\z/
    assert ConfigValueSanitizer.valid?("DiagnosticsProd", pattern)
    refute ConfigValueSanitizer.valid?("", pattern)
    refute ConfigValueSanitizer.valid?(nil, pattern)
    refute ConfigValueSanitizer.valid?("prod; id", pattern)
    # \A and \z (not ^ and $) so that a payload on a second line cannot pass validation
    refute ConfigValueSanitizer.valid?("prod\nid", pattern)
  end

  def test_sourcing_quoted_values_does_not_execute_injected_commands
    Dir.mktmpdir do |workdir|
      marker = File.join(workdir, "pwned")
      values = [
        "prod; touch #{marker} #",
        "prod$(touch #{marker})",
        "prod`touch #{marker}`",
        "prod'; touch #{marker}; '",
        "prod\nexport INJECTED=pwned",
        "/var/log/containers/*.log",
        "kube-system,gatekeeper-system",
        "",
      ]

      envVarFile = File.join(workdir, "env_var")
      File.open(envVarFile, "w") do |file|
        values.each_with_index do |value, index|
          file.write("export TEST_VALUE_#{index}=#{ConfigValueSanitizer.shell_quote(value)}\n")
        end
      end

      variableNames = values.each_index.map { |index| "TEST_VALUE_#{index}" } + ["INJECTED"]
      sourced = ParserTestHelper.source_env_file(envVarFile, variableNames)

      values.each_with_index do |value, index|
        assert_equal value, sourced["TEST_VALUE_#{index}"], "value #{index} was altered by the shell"
      end
      assert_equal "", sourced["INJECTED"]
      refute File.exist?(marker), "injected command was executed while sourcing the env var file"
    end
  end
end
