#!/usr/local/bin/ruby
require_relative "ConfigParseErrorLogger"

@td_agent_bit_conf_path = "/etc/opt/microsoft/docker-cimprov/td-agent-bit.conf"

@default_service_interval = "15"

def is_number?(value)
  true if Integer(value) rescue false
end

def substituteFluentBitPlaceHolders
  begin
    # Replace the fluentbit config file with custom values if present
    puts "config::Starting to substitute the placeholders in td-agent-bit.conf file for log collection"

    interval = ENV["FBIT_SERVICE_FLUSH_INTERVAL"]
    bufferChunkSize = ENV["FBIT_TAIL_BUFFER_CHUNK_SIZE"]
    bufferMaxSize = ENV["FBIT_TAIL_BUFFER_MAX_SIZE"]

    serviceInterval = (!interval.nil? && is_number?(interval)) ? interval : @default_service_interval
    serviceIntervalSetting = "Flush         " + serviceInterval

    tailBufferChunkSize = (!bufferChunkSize.nil? && is_number?(bufferChunkSize)) ? bufferChunkSize : nil

    tailBufferMaxSize = (!bufferMaxSize.nil? && is_number?(bufferMaxSize)) ? bufferMaxSize : nil

    text = File.read(@td_agent_bit_conf_path)
    new_contents = text.gsub("${SERVICE_FLUSH_INTERVAL}", serviceIntervalSetting)
    if !tailBufferChunkSize.nil?
      new_contents = new_contents.gsub("${TAIL_BUFFER_CHUNK_SIZE}", "Buffer_Chunk_Size " + tailBufferChunkSize + "m")
    else
      new_contents = new_contents.gsub("\n    ${TAIL_BUFFER_CHUNK_SIZE}\n", "\n")
    end
    if !tailBufferMaxSize.nil?
      new_contents = new_contents.gsub("${TAIL_BUFFER_MAX_SIZE}", "Buffer_Max_Size " + tailBufferMaxSize + "m")
    else
      new_contents = new_contents.gsub("\n    ${TAIL_BUFFER_MAX_SIZE}\n", "\n")
    end

    File.open(@td_agent_bit_conf_path, "w") { |file| file.puts new_contents }
    puts "config::Successfully substituted the placeholders in td-agent-bit.conf file"
  rescue => errorStr
    ConfigParseErrorLogger.logError("td-agent-bit-config-customizer: error while substituting values in td-agent-bit.conf file: #{errorStr}")
  end
end

substituteFluentBitPlaceHolders
