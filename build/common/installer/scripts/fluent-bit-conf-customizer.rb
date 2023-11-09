#!/usr/local/bin/ruby
require_relative "ConfigParseErrorLogger"

@fluent_bit_conf_path = "/etc/opt/microsoft/docker-cimprov/fluent-bit.conf"
@fluent_bit_common_conf_path = "/etc/opt/microsoft/docker-cimprov/fluent-bit-common.conf"

@os_type = ENV["OS_TYPE"]
if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
  @fluent_bit_conf_path = "/etc/fluent-bit/fluent-bit.conf"
  @fluent_bit_common_conf_path = "/etc/fluent-bit/fluent-bit-common.conf"
end

@default_service_interval = "15"
@default_mem_buf_limit = "10"

def is_number?(value)
  true if Integer(value) rescue false
end

def substituteMultiline(multilineLogging, new_contents)
    if !multilineLogging.nil? && multilineLogging.to_s.downcase == "true"
      new_contents = new_contents.gsub("#${MultilineEnabled}", "")
      new_contents = new_contents.gsub("azm-containers-parser.conf", "azm-containers-parser-multiline.conf")
      # replace parser with multiline version. ensure running script multiple times does not have negative impact
      if (/[^\.]Parser\s{1,}docker/).match(new_contents)
        new_contents = new_contents.gsub(/[^\.]Parser\s{1,}docker/, " Multiline.Parser docker")
      else
        new_contents = new_contents.gsub(/[^\.]Parser\s{1,}cri/, " Multiline.Parser cri")
      end
    end

    return new_contents
end

def substituteFluentBitPlaceHolders
  begin
    # Replace the fluentbit config file with custom values if present
    puts "config::Starting to substitute the placeholders in fluent-bit.conf file for log collection"

    interval = ENV["FBIT_SERVICE_FLUSH_INTERVAL"]
    bufferChunkSize = ENV["FBIT_TAIL_BUFFER_CHUNK_SIZE"]
    bufferMaxSize = ENV["FBIT_TAIL_BUFFER_MAX_SIZE"]
    memBufLimit = ENV["FBIT_TAIL_MEM_BUF_LIMIT"]
    ignoreOlder = ENV["FBIT_TAIL_IGNORE_OLDER"]
    multilineLogging = ENV["AZMON_MULTILINE_ENABLED"]
    kubernetesMetadataCollection = env["AZMON_KUBERNETES_METADATA_ENABLED"]

    serviceInterval = (!interval.nil? && is_number?(interval) && interval.to_i > 0) ? interval : @default_service_interval
    serviceIntervalSetting = "Flush         " + serviceInterval

    tailBufferChunkSize = (!bufferChunkSize.nil? && is_number?(bufferChunkSize) && bufferChunkSize.to_i > 0) ? bufferChunkSize : nil

    tailBufferMaxSize = (!bufferMaxSize.nil? && is_number?(bufferMaxSize) && bufferMaxSize.to_i > 0) ? bufferMaxSize : nil

    if ((!tailBufferChunkSize.nil? && tailBufferMaxSize.nil?) || (!tailBufferChunkSize.nil? && !tailBufferMaxSize.nil? && tailBufferChunkSize.to_i > tailBufferMaxSize.to_i))
      puts "config:warn buffer max size must be greater or equal to chunk size"
      tailBufferMaxSize = tailBufferChunkSize
    end

    tailMemBufLimit = (!memBufLimit.nil? && is_number?(memBufLimit) && memBufLimit.to_i > 10) ? memBufLimit : @default_mem_buf_limit
    tailMemBufLimitSetting = "Mem_Buf_Limit " + tailMemBufLimit + "m"

    text = File.read(@fluent_bit_conf_path)
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

    if !kubernetesMetadataCollection.nil? && kubernetesMetadataCollection.to_s.downcase == "true"
      new_contents = new_contents.gsub("#${KubernetesMetadataCollection}", "")
    end

    new_contents = substituteMultiline(multilineLogging, new_contents)
    File.open(@fluent_bit_conf_path, "w") { |file| file.puts new_contents }
    puts "config::Successfully substituted the placeholders in fluent-bit.conf file"

    puts "config::Starting to substitute the placeholders in fluent-bit-common.conf file for log collection"
    text = File.read(@fluent_bit_common_conf_path)
    new_contents = substituteMultiline(multilineLogging, text)
    File.open(@fluent_bit_common_conf_path, "w") { |file| file.puts new_contents }
    puts "config::Successfully substituted the placeholders in fluent-bit-common.conf file"

  rescue => errorStr
    ConfigParseErrorLogger.logError("fluent-bit-config-customizer: error while substituting values in fluent-bit conf files: #{errorStr}")
  end
end

substituteFluentBitPlaceHolders
