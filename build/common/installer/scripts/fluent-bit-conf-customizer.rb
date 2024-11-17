#!/usr/local/bin/ruby
require_relative "ConfigParseErrorLogger"

@fluent_bit_conf_path = "/etc/opt/microsoft/docker-cimprov/fluent-bit.conf"
@fluent_bit_common_conf_path = "/etc/opt/microsoft/docker-cimprov/fluent-bit-common.conf"

@os_type = ENV["OS_TYPE"]
@isWindows = false
if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
  @isWindows = true
  @fluent_bit_conf_path = "/etc/fluent-bit/fluent-bit.conf"
  @fluent_bit_common_conf_path = "/etc/fluent-bit/fluent-bit-common.conf"
end

@using_aad_msi_auth = false
if !ENV["USING_AAD_MSI_AUTH"].nil? && !ENV["USING_AAD_MSI_AUTH"].empty? && ENV["USING_AAD_MSI_AUTH"].strip.casecmp("true") == 0
  @using_aad_msi_auth = true
end

@geneva_logs_integration = false
if !ENV["GENEVA_LOGS_INTEGRATION"].nil? && !ENV["GENEVA_LOGS_INTEGRATION"].empty? && ENV["GENEVA_LOGS_INTEGRATION"].strip.casecmp("true") == 0
  @geneva_logs_integration = true
end


@default_service_interval = "15"
@default_mem_buf_limit = "10"
@default_high_log_scale_service_interval = "1"
@default_high_log_scale_max_storage_chunks_up = "500" # Each chunk size is ~2MB
@default_high_log_scale_max_storage_type = "filesystem" # filesystem = memory + filesystem in fluent-bit
@default_high_log_scale_max_storage_total_limit_size = "10G"

def is_number?(value)
  true if Integer(value) rescue false
end

def is_high_log_scale_mode?
  isHighLogScaleMode = false
  if !ENV["IS_HIGH_LOG_SCALE_MODE"].nil? && !ENV["IS_HIGH_LOG_SCALE_MODE"].empty? && ENV["IS_HIGH_LOG_SCALE_MODE"].to_s.downcase == "true"
    isHighLogScaleMode = true
  end
  return isHighLogScaleMode
end

def substituteMultiline(multilineLogging, stacktraceLanguages, new_contents)
    if !multilineLogging.nil? && multilineLogging.to_s.downcase == "true"
      if !stacktraceLanguages.nil? && !stacktraceLanguages.empty?
        new_contents = new_contents.gsub("#${MultilineEnabled}", "")
        new_contents = new_contents.gsub("#${MultilineLanguages}", stacktraceLanguages)
      end
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

def substituteStorageTotalLimitSize(new_contents)
   if is_high_log_scale_mode?
      new_contents = new_contents.gsub("#${AZMON_STORAGE_TOTAL_LIMIT_SIZE_MB}", "storage.total_limit_size  " + @default_high_log_scale_max_storage_total_limit_size)
   else
      new_contents = new_contents.gsub("\n    #${AZMON_STORAGE_TOTAL_LIMIT_SIZE_MB}\n", "\n")
   end
   return new_contents
end

def substituteResourceOptimization(resourceOptimizationEnabled, new_contents)
  #Update the config file only in two conditions: 1. Linux and resource optimization is enabled 2. Windows and using aad msi auth and not using geneva logs integration
  if (!@isWindows && !resourceOptimizationEnabled.nil? && resourceOptimizationEnabled.to_s.downcase == "true") || (@isWindows && @using_aad_msi_auth && !@geneva_logs_integration)
    puts "config::Starting to substitute the placeholders in fluent-bit.conf file for resource optimization"
    if (@isWindows)
      new_contents = new_contents.gsub("#${ResourceOptimizationPluginFile}", "plugins_file  /etc/fluent-bit/azm-containers-input-plugins.conf")
    else
      new_contents = new_contents.gsub("#${ResourceOptimizationPluginFile}", "plugins_file  /etc/opt/microsoft/docker-cimprov/azm-containers-input-plugins.conf")
    end
    new_contents = new_contents.gsub("#${ResourceOptimizationFBConfigFile}", "@INCLUDE fluent-bit-input.conf")
  end

  return new_contents
end

def substituteHighLogScaleConfig(enableFbitThreading, storageType, storageMaxChunksUp, new_contents)
  begin
      if is_high_log_scale_mode? || (!enableFbitThreading.nil? && !enableFbitThreading.empty? && enableFbitThreading.to_s.downcase == "true" )
        new_contents = new_contents.gsub("#${AZMON_TAIL_THREADED}", "threaded on")
        puts "using threaded on for tail plugin"
      else
        new_contents = new_contents.gsub("\n    #${AZMON_TAIL_THREADED}\n", "\n")
      end

      if is_high_log_scale_mode?
        new_contents = new_contents.gsub("#${AZMON_STORAGE_TYPE}", "storage.type " + @default_high_log_scale_max_storage_type)
        puts "using storage.type: #{@default_high_log_scale_max_storage_type} for tail plugin"
      elsif !storageType.nil? && !storageType.empty?
        new_contents = new_contents.gsub("#${AZMON_STORAGE_TYPE}", "storage.type " + storageType)
        puts "using storage.type: #{storageType} for tail plugin"
      else
        new_contents = new_contents.gsub("\n    #${AZMON_STORAGE_TYPE}\n", "\n")
      end

      if is_high_log_scale_mode?
        new_contents = new_contents.gsub("#${AZMON_MAX_STORAGE_CHUNKS_UP}", "storage.max_chunks_up " + @default_high_log_scale_max_storage_chunks_up)
        puts "using storage.max_chunks_up: #{@default_high_log_scale_max_storage_chunks_up} for tail plugin"
      elsif !storageMaxChunksUp.nil? && !storageMaxChunksUp.empty?
        new_contents = new_contents.gsub("#${AZMON_MAX_STORAGE_CHUNKS_UP}", "storage.max_chunks_up " + storageMaxChunksUp)
        puts "using storage.max_chunks_up: #{storageMaxChunksUp} for tail plugin"
      else
        new_contents = new_contents.gsub("\n    #${AZMON_MAX_STORAGE_CHUNKS_UP}\n", "\n")
      end
  rescue => err
     puts "config::substituteHighLogScaleConfig failed with an error: #{err}"
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
    stacktraceLanguages = ENV["AZMON_MULTILINE_LANGUAGES"]
    resourceOptimizationEnabled = ENV["AZMON_RESOURCE_OPTIMIZATION_ENABLED"]
    enableCustomMetrics = ENV["ENABLE_CUSTOM_METRICS"]
    windowsFluentBitEnabled = ENV["AZMON_WINDOWS_FLUENT_BIT_ENABLED"]
    kubernetesMetadataCollection = ENV["AZMON_KUBERNETES_METADATA_ENABLED"]
    annotationBasedLogFiltering = ENV["AZMON_ANNOTATION_BASED_LOG_FILTERING"]
    storageMaxChunksUp = ENV["FBIT_STORAGE_MAX_CHUNKS_UP"]
    storageType = ENV["FBIT_STORAGE_TYPE"]
    enableFbitThreading = ENV["ENABLE_FBIT_THREADING"]


    serviceInterval = @default_service_interval
    if is_high_log_scale_mode?
      serviceInterval = @default_high_log_scale_service_interval
      puts " using Flush interval: #{serviceInterval}"
    elsif (!interval.nil? && is_number?(interval) && interval.to_i > 0)
      serviceInterval = interval
    end
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

    new_contents = substituteHighLogScaleConfig(enableFbitThreading, storageType,  storageMaxChunksUp, new_contents)

    if !kubernetesMetadataCollection.nil? && kubernetesMetadataCollection.to_s.downcase == "true"
      new_contents = new_contents.gsub("#${KubernetesFilterEnabled}", "")
    end

    if !annotationBasedLogFiltering.nil? && annotationBasedLogFiltering.to_s.downcase == "true"
      # enabled kubernetes filter plugin if not already enabled
      new_contents = new_contents.gsub("#${KubernetesFilterEnabled}", "")
      new_contents = new_contents.gsub("#${AnnotationBasedLogFilteringEnabled}", "")
    end

    new_contents = substituteMultiline(multilineLogging, stacktraceLanguages, new_contents)

    # Valid resource optimization scenarios
    # if Linux and Custom Metrics not enabled
    # or if Windows and Fluent Bit is not disabled
    if (!@isWindows && (enableCustomMetrics.nil? || enableCustomMetrics.to_s.downcase == "false")) || (@isWindows && (!windowsFluentBitEnabled.nil? && windowsFluentBitEnabled.to_s.downcase == "true"))
      new_contents = substituteResourceOptimization(resourceOptimizationEnabled, new_contents)
    end
    File.open(@fluent_bit_conf_path, "w") { |file| file.puts new_contents }
    puts "config::Successfully substituted the placeholders in fluent-bit.conf file"

    puts "config::Starting to substitute the placeholders in fluent-bit-common.conf file for log collection"
    text = File.read(@fluent_bit_common_conf_path)
    text = substituteStorageTotalLimitSize(text)
    new_contents = substituteMultiline(multilineLogging, stacktraceLanguages, text)
    File.open(@fluent_bit_common_conf_path, "w") { |file| file.puts new_contents }
    puts "config::Successfully substituted the placeholders in fluent-bit-common.conf file"

  rescue => errorStr
    ConfigParseErrorLogger.logError("fluent-bit-config-customizer: error while substituting values in fluent-bit conf files: #{errorStr}")
  end
end

substituteFluentBitPlaceHolders
