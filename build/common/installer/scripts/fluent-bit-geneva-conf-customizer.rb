#!/usr/local/bin/ruby
require_relative "ConfigParseErrorLogger"

LINUX_CONFIG_PATHS = {
  "common" => "/etc/opt/microsoft/docker-cimprov/fluent-bit-geneva.conf",
  "infra" => "/etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_infra.conf",
  "tenant" => "/etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_tenant.conf",
}

WINDOWS_CONFIG_PATHS = {
  "common" => "/etc/fluent-bit/fluent-bit-geneva.conf",
  "infra" => "/etc/fluent-bit/fluent-bit-geneva-logs_infra.conf",
  "tenant" => "/etc/fluent-bit/fluent-bit-geneva-logs_tenant.conf",
}
SUPPORTED_CONFIG_TYPES = ["common", "infra", "tenant"]

@default_service_interval = "15"
@default_mem_buf_limit = "10"

def is_number?(value)
  true if Integer(value) rescue false
end

# check if it is number and greater than 0
def is_valid_number?(value)
  return !value.nil? && is_number?(value) && value.to_i > 0
end

def substituteFluentBitPlaceHolders(configFilePath)
  begin
    # Replace the fluentbit config file with custom values if present
    configFileName = File.basename(configFilePath)
    puts "config::Starting to substitute the placeholders in #{configFileName} file for geneva log collection"

    interval = ENV["FBIT_SERVICE_FLUSH_INTERVAL"]
    bufferChunkSize = ENV["FBIT_TAIL_BUFFER_CHUNK_SIZE"]
    bufferMaxSize = ENV["FBIT_TAIL_BUFFER_MAX_SIZE"]
    memBufLimit = ENV["FBIT_TAIL_MEM_BUF_LIMIT"]
    ignoreOlder = ENV["FBIT_TAIL_IGNORE_OLDER"]
    multilineLogging = ENV["AZMON_MULTILINE_ENABLED"]
    enableFluentBitThreading = ENV["ENABLE_FBIT_THREADING"]

    serviceInterval = is_valid_number?(interval) ? interval : @default_service_interval
    serviceIntervalSetting = "Flush         " + serviceInterval

    tailBufferChunkSize = is_valid_number?(bufferChunkSize) ? bufferChunkSize : nil

    tailBufferMaxSize = is_valid_number?(bufferMaxSize) ? bufferMaxSize : nil

    if ((!tailBufferChunkSize.nil? && tailBufferMaxSize.nil?) || (!tailBufferChunkSize.nil? && !tailBufferMaxSize.nil? && tailBufferChunkSize.to_i > tailBufferMaxSize.to_i))
      puts "config:warn buffer max size must be greater or equal to chunk size"
      tailBufferMaxSize = tailBufferChunkSize
    end

    tailMemBufLimit = (is_valid_number?(memBufLimit) && memBufLimit.to_i > 10) ? memBufLimit : @default_mem_buf_limit
    tailMemBufLimitSetting = "Mem_Buf_Limit " + tailMemBufLimit + "m"

    text = File.read(configFilePath)
    new_contents = text.gsub("${SERVICE_FLUSH_INTERVAL}", serviceIntervalSetting)
    new_contents = new_contents.gsub("${TAIL_MEM_BUF_LIMIT}", tailMemBufLimitSetting)
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

    if !ignoreOlder.nil? && !ignoreOlder.empty?
      new_contents = new_contents.gsub("${TAIL_IGNORE_OLDER}", "Ignore_Older " + ignoreOlder)
    else
      new_contents = new_contents.gsub("\n    ${TAIL_IGNORE_OLDER}\n", "\n")
    end

    if !enableFluentBitThreading.nil? && enableFluentBitThreading.strip.casecmp("true") == 0
      new_contents = new_contents.gsub("${TAIL_THREADED}", "threaded on")
    else
      new_contents = new_contents.gsub("\n    ${TAIL_THREADED}\n", "\n")
    end

    if !multilineLogging.nil? && multilineLogging.to_s.downcase == "true"
      new_contents = new_contents.gsub("#${MultilineEnabled}", "")
      new_contents = new_contents.gsub("azm-containers-parser.conf", "azm-containers-parser-multiline.conf")
      # replace parser with multiline version. ensure running script multiple times does not have negative impact
      if (/[^\.]Parser\s{1,}docker/).match(text)
        new_contents = new_contents.gsub(/[^\.]Parser\s{1,}docker/, " Multiline.Parser docker")
      else
        new_contents = new_contents.gsub(/[^\.]Parser\s{1,}cri/, " Multiline.Parser cri")
      end
    end

    File.open(configFilePath, "w") { |file| file.puts new_contents }
    puts "config::Successfully substituted the placeholders in #{configFileName} file"
  rescue => errorStr
    ConfigParseErrorLogger.logError("fluent-bit-geneva-conf-customizer: error while substituting values in #{configFilePath} file: #{errorStr}")
  end
end

begin
  isWindows = false
  os_type = ENV["OS_TYPE"]
  if !os_type.nil? && !os_type.empty? && os_type.strip.casecmp("windows") == 0
    isWindows = true
  end

  configType = ARGV[0] # supported config type are common or infra or tenant
  if configType.nil?
    puts "config:error: fluent-bit-geneva-conf-customizer.rb file MUST be invoked with an argument"
  elsif SUPPORTED_CONFIG_TYPES.include?(configType)
    configFilePath = LINUX_CONFIG_PATHS[configType]
    if isWindows
      configFilePath = WINDOWS_CONFIG_PATHS[configType]
    end
    substituteFluentBitPlaceHolders(configFilePath)
  else
    puts "config:error: argument passed to fluent-bit-geneva-conf-customizer.rb file MUST be either common or infra or tenant"
  end
rescue => errorStr
  ConfigParseErrorLogger.logError("error while substituting values in fluent-bit-geneva conf file: #{errorStr}")
end
