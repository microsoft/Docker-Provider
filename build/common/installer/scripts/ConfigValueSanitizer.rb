#!/usr/local/bin/ruby

# Helpers to safely emit configmap (untrusted) derived values into the
# environment variable files that are later sourced by the agent shell scripts.
module ConfigValueSanitizer
  # Wraps the value in single quotes so that no shell metacharacter in it is
  # interpreted when the generated file is sourced by bash.
  def self.shell_quote(value)
    "'" + value.to_s.gsub("'") { "'\\''" } + "'"
  end

  # Windows env files are parsed as KEY=VALUE lines, so only line breaks (which
  # would let a value inject additional variables) need to be neutralized.
  def self.single_line(value)
    value.to_s.gsub(/[\r\n]+/, " ")
  end

  # Returns true only when the value is a non empty string fully matching pattern.
  def self.valid?(value, pattern)
    !value.nil? && value.kind_of?(String) && !value.empty? && !(pattern.match(value)).nil?
  end
end
