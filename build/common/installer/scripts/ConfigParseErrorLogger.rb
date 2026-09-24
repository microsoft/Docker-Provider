#!/usr/local/bin/ruby
# frozen_string_literal: true

class ConfigParseErrorLogger
  require "json"

  def initialize
  end

  class << self
    def logError(message)
      begin
        errorMessage = "config::error::" + message
        jsonMessage = errorMessage.to_json
        STDERR.puts "\e[31m" + jsonMessage + "\e[0m" #Using red color for error messages
      rescue => errorStr
        puts "Error in ConfigParserErrorLogger::logError: #{errorStr}"
      end
    end
  end
end

# Values read from the config map are interpolated into shell files that the agent entry point
# sources, so they are rendered as single-quoted literals. Quoting rather than rewriting the
# value keeps the resulting variable byte-identical to what was configured.
module ConfigValue
  class << self
    # POSIX single-quoting: end the quoted run, emit an escaped quote, reopen.
    def to_shell_single_quoted(value)
      "'" + value.to_s.gsub("'") { "'\\''" } + "'"
    end
  end
end
