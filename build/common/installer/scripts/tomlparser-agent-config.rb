#!/usr/local/bin/ruby

@os_type = ENV["OS_TYPE"]
require "tomlrb"

require_relative "ConfigParseErrorLogger"

@configMapMountPath = "/etc/config/settings/agent-settings"
@configSchemaVersion = ""

# Checking to see if this is the daemonset or replicaset to parse config accordingly
@controllerType = ENV["CONTROLLER_TYPE"]
@daemonset = "daemonset"
# Checking to see if container is not prometheus sidecar.
# CONTAINER_TYPE is populated only for prometheus sidecar container.
@containerType = ENV["CONTAINER_TYPE"]

# 250 Node items (15KB per node) account to approximately 4MB
@nodesChunkSize = 250
# 1000 pods (10KB per pod) account to approximately 10MB
@podsChunkSize = 1000
# 4000 events (1KB per event) account to approximately 4MB
@eventsChunkSize = 4000
# roughly each deployment is 8k
# 500 deployments account to approximately 4MB
@deploymentsChunkSize = 500
# roughly each HPA is 3k
# 2000 HPAs account to approximately 6-7MB
@hpaChunkSize = 2000
# stream batch sizes to avoid large file writes
# too low will consume higher disk iops
@podsEmitStreamBatchSize = 200
@nodesEmitStreamBatchSize = 100

# higher the chunk size rs pod memory consumption higher and lower api latency
# similarly lower the value, helps on the memory consumption but incurrs additional round trip latency
# these needs to be tuned be based on the workload
# nodes
@nodesChunkSizeMin = 100
@nodesChunkSizeMax = 400
# pods
@podsChunkSizeMin = 10
@podsChunkSizeMax = 1500
# events
@eventsChunkSizeMin = 2000
@eventsChunkSizeMax = 10000
# deployments
@deploymentsChunkSizeMin = 500
@deploymentsChunkSizeMax = 1000
# hpa
@hpaChunkSizeMin = 500
@hpaChunkSizeMax = 2000

# emit stream sizes to prevent lower values which costs disk i/o
# max will be upto the chunk size
@podsEmitStreamBatchSizeMin = 50
@nodesEmitStreamBatchSizeMin = 50

# configmap settings related fbit config
@enableFbitInternalMetrics = false
@fbitFlushIntervalSecs = 0
@fbitTailBufferChunkSizeMBs = 0
@fbitTailBufferMaxSizeMBs = 0
@fbitTailMemBufLimitMBs = 0
@fbitTailIgnoreOlder = ""
@storageTotalLimitSizeMB = 200
@outputForwardWorkers = 10
@outputForwardRetryLimit = 10
@requireAckResponse = "false"
@fbitStorageMaxChunksUp = 0
@fbitStorageType = ""
@enableFluentBitThreading = false

# configmap settings related to mdsd
@mdsdMonitoringMaxEventRate = 0
@mdsdUploadMaxSizeInMB = 0
@mdsdUploadFrequencyInSeconds = 0
@mdsdBackPressureThresholdInMB = 0
@mdsdCompressionLevel = -1

# Checking to see if this is the daemonset or replicaset to parse config accordingly
@controllerType = ENV["CONTROLLER_TYPE"]
@daemonset = "daemonset"
# Checking to see if container is not prometheus sidecar.
# CONTAINER_TYPE is populated only for prometheus sidecar container.
@containerType = ENV["CONTAINER_TYPE"]
@containerMemoryLimitInBytes = ENV["CONTAINER_MEMORY_LIMIT_IN_BYTES"]

@promFbitChunkSize = 0
@promFbitBufferSize = 0
@promFbitMemBufLimit = 0

@promFbitChunkSizeDefault = "32k" #kb
@promFbitBufferSizeDefault = "64k" #kb
@promFbitMemBufLimitDefault = "10m" #mb

@ignoreProxySettings = false

@multiline_enabled = "false"
@resource_optimization_enabled = false
@windows_fluent_bit_disabled = true

@waittime_port_25226 = 45
@waittime_port_25228 = 120
@waittime_port_25229 = 45
@waittime_port_13000 = 45 # default waittime for AMACA data port
@waittime_port_12563 = 45 # default waittime for AMACA config port

def is_number?(value)
  true if Integer(value) rescue false
end

# check if it is number and greater than 0
def is_valid_number?(value)
  return !value.nil? && is_number?(value) && value.to_i > 0
end

# check if it is a valid waittime
def is_valid_waittime?(value, default)
  return !value.nil? && is_number?(value) && value.to_i >= default / 2 && value.to_i <= 3 * default
end

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@configMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig for agent settings mounted, parsing values"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for agent settings not mounted, using defaults"
      return nil
    end
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while parsing config map for agent settings : #{errorStr}, using defaults, please check config map for errors")
    return nil
  end
end

# Use the ruby structure created after config parsing to set the right values to be used as environment variables
def populateSettingValuesFromConfigMap(parsedConfig)
  begin
    if !parsedConfig.nil? && !parsedConfig[:agent_settings].nil?
      chunk_config = parsedConfig[:agent_settings][:chunk_config]
      if !chunk_config.nil?
        nodesChunkSize = chunk_config[:NODES_CHUNK_SIZE]
        if !nodesChunkSize.nil? && is_number?(nodesChunkSize) && (@nodesChunkSizeMin..@nodesChunkSizeMax) === nodesChunkSize.to_i
          @nodesChunkSize = nodesChunkSize.to_i
          puts "Using config map value: NODES_CHUNK_SIZE = #{@nodesChunkSize}"
        end

        podsChunkSize = chunk_config[:PODS_CHUNK_SIZE]
        if !podsChunkSize.nil? && is_number?(podsChunkSize) && (@podsChunkSizeMin..@podsChunkSizeMax) === podsChunkSize.to_i
          @podsChunkSize = podsChunkSize.to_i
          puts "Using config map value: PODS_CHUNK_SIZE = #{@podsChunkSize}"
        end

        eventsChunkSize = chunk_config[:EVENTS_CHUNK_SIZE]
        if !eventsChunkSize.nil? && is_number?(eventsChunkSize) && (@eventsChunkSizeMin..@eventsChunkSizeMax) === eventsChunkSize.to_i
          @eventsChunkSize = eventsChunkSize.to_i
          puts "Using config map value: EVENTS_CHUNK_SIZE = #{@eventsChunkSize}"
        end

        deploymentsChunkSize = chunk_config[:DEPLOYMENTS_CHUNK_SIZE]
        if !deploymentsChunkSize.nil? && is_number?(deploymentsChunkSize) && (@deploymentsChunkSizeMin..@deploymentsChunkSizeMax) === deploymentsChunkSize.to_i
          @deploymentsChunkSize = deploymentsChunkSize.to_i
          puts "Using config map value: DEPLOYMENTS_CHUNK_SIZE = #{@deploymentsChunkSize}"
        end

        hpaChunkSize = chunk_config[:HPA_CHUNK_SIZE]
        if !hpaChunkSize.nil? && is_number?(hpaChunkSize) && (@hpaChunkSizeMin..@hpaChunkSizeMax) === hpaChunkSize.to_i
          @hpaChunkSize = hpaChunkSize.to_i
          puts "Using config map value: HPA_CHUNK_SIZE = #{@hpaChunkSize}"
        end

        podsEmitStreamBatchSize = chunk_config[:PODS_EMIT_STREAM_BATCH_SIZE]
        if !podsEmitStreamBatchSize.nil? && is_number?(podsEmitStreamBatchSize) &&
           podsEmitStreamBatchSize.to_i <= @podsChunkSize && podsEmitStreamBatchSize.to_i >= @podsEmitStreamBatchSizeMin
          @podsEmitStreamBatchSize = podsEmitStreamBatchSize.to_i
          puts "Using config map value: PODS_EMIT_STREAM_BATCH_SIZE = #{@podsEmitStreamBatchSize}"
        end
        nodesEmitStreamBatchSize = chunk_config[:NODES_EMIT_STREAM_BATCH_SIZE]
        if !nodesEmitStreamBatchSize.nil? && is_number?(nodesEmitStreamBatchSize) &&
           nodesEmitStreamBatchSize.to_i <= @nodesChunkSize && nodesEmitStreamBatchSize.to_i >= @nodesEmitStreamBatchSizeMin
          @nodesEmitStreamBatchSize = nodesEmitStreamBatchSize.to_i
          puts "Using config map value: NODES_EMIT_STREAM_BATCH_SIZE = #{@nodesEmitStreamBatchSize}"
        end
      end
      # fbit config settings
      fbit_config = parsedConfig[:agent_settings][:fbit_config]
      if !fbit_config.nil?
        fbitFlushIntervalSecs = fbit_config[:log_flush_interval_secs]
        if is_valid_number?(fbitFlushIntervalSecs)
          @fbitFlushIntervalSecs = fbitFlushIntervalSecs.to_i
          puts "Using config map value: log_flush_interval_secs = #{@fbitFlushIntervalSecs}"
        end

        fbitTailBufferChunkSizeMBs = fbit_config[:tail_buf_chunksize_megabytes]
        if is_valid_number?(fbitTailBufferChunkSizeMBs)
          @fbitTailBufferChunkSizeMBs = fbitTailBufferChunkSizeMBs.to_i
          puts "Using config map value: tail_buf_chunksize_megabytes  = #{@fbitTailBufferChunkSizeMBs}"
        end

        fbitTailBufferMaxSizeMBs = fbit_config[:tail_buf_maxsize_megabytes]
        if is_valid_number?(fbitTailBufferMaxSizeMBs)
          if fbitTailBufferMaxSizeMBs.to_i >= @fbitTailBufferChunkSizeMBs
            @fbitTailBufferMaxSizeMBs = fbitTailBufferMaxSizeMBs.to_i
            puts "Using config map value: tail_buf_maxsize_megabytes = #{@fbitTailBufferMaxSizeMBs}"
          else
            # tail_buf_maxsize_megabytes has to be greater or equal to tail_buf_chunksize_megabytes
            @fbitTailBufferMaxSizeMBs = @fbitTailBufferChunkSizeMBs
            puts "config::warn: tail_buf_maxsize_megabytes must be greater or equal to value of tail_buf_chunksize_megabytes. Using tail_buf_maxsize_megabytes = #{@fbitTailBufferMaxSizeMBs} since provided config value not valid"
          end
        end
        # in scenario - tail_buf_chunksize_megabytes provided but not tail_buf_maxsize_megabytes to prevent fbit crash
        if @fbitTailBufferChunkSizeMBs > 0 && @fbitTailBufferMaxSizeMBs == 0
          @fbitTailBufferMaxSizeMBs = @fbitTailBufferChunkSizeMBs
          puts "config::warn: since tail_buf_maxsize_megabytes not provided hence using tail_buf_maxsize_megabytes=#{@fbitTailBufferMaxSizeMBs} which is same as the value of tail_buf_chunksize_megabytes"
        end

        fbitTailMemBufLimitMBs = fbit_config[:tail_mem_buf_limit_megabytes]
        if is_valid_number?(fbitTailMemBufLimitMBs)
          @fbitTailMemBufLimitMBs = fbitTailMemBufLimitMBs.to_i
          puts "Using config map value: tail_mem_buf_limit_megabytes  = #{@fbitTailMemBufLimitMBs}"
        end

        fbitTailIgnoreOlder = fbit_config[:tail_ignore_older]
        re = /^[0-9]+[mhd]$/
        if !fbitTailIgnoreOlder.nil? && !fbitTailIgnoreOlder.empty?
          if !re.match(fbitTailIgnoreOlder).nil?
            @fbitTailIgnoreOlder = fbitTailIgnoreOlder
            puts "Using config map value: tail_ignore_older  = #{@fbitTailIgnoreOlder}"
          else
            puts "config:warn: provided tail_ignore_older value is not valid hence using default value"
          end
        end

        enableFbitInternalMetrics = fbit_config[:enable_internal_metrics]
        if !enableFbitInternalMetrics.nil? && enableFbitInternalMetrics.downcase == "true"
          @enableFbitInternalMetrics = true
          puts "Using config map value: enable_internal_metrics = #{@enableFbitInternalMetrics}"
        end

        fbitStorageMaxChunksUp = fbit_config[:storage_max_chunks_up]
        if is_valid_number?(fbitStorageMaxChunksUp)
            @fbitStorageMaxChunksUp = fbitStorageMaxChunksUp.to_i
            puts "Using config map value: fbitStorageMaxChunksUp  = #{@fbitStorageMaxChunksUp}"
        end
        fbitStorageType = fbit_config[:storage_type]
        if !fbitStorageType.nil? && !fbitStorageType.empty? && ["memory", "filesystem"].include?(fbitStorageType)
            @fbitStorageType = fbitStorageType
            puts "Using config map value: fbitStorageType  = #{@fbitStorageType}"
        end

        enableFluentBitThreading = fbit_config[:enable_threading]
        if !enableFluentBitThreading.nil? && enableFluentBitThreading.strip.casecmp("true") == 0
          @enableFluentBitThreading = enableFluentBitThreading
          puts "Using config map value: enableFluentBitThreading  = #{@enableFluentBitThreading}"
        end
      end

      # fbit forward plugins geneva settings per tenant
      fbit_config = parsedConfig[:agent_settings][:geneva_tenant_fbit_settings]
      if !fbit_config.nil?
        storageTotalLimitSizeMB = fbit_config[:storage_total_limit_size_mb]
        if is_valid_number?(storageTotalLimitSizeMB)
          @storageTotalLimitSizeMB = storageTotalLimitSizeMB.to_i
          puts "Using config map value: storage_total_limit_size_mb = #{@storageTotalLimitSizeMB}"
        end
        outputForwardWorkers = fbit_config[:output_forward_workers]
        if is_valid_number?(outputForwardWorkers)
          @outputForwardWorkers = outputForwardWorkers.to_i
          puts "Using config map value: output_forward_workers = #{@outputForwardWorkers}"
        end
        #Ref https://docs.fluentbit.io/manual/administration/scheduling-and-retries
        outputForwardRetryLimit = fbit_config[:output_forward_retry_limit]
        if !outputForwardRetryLimit.nil?
          if is_number?(outputForwardRetryLimit) && outputForwardRetryLimit.to_i > 0
            @outputForwardRetryLimit = outputForwardRetryLimit.to_i
            puts "Using config map value: output_forward_retry_limit = #{@outputForwardRetryLimit}"
          elsif ["False", "no_limits", "no_retries"].include?(outputForwardRetryLimit)
            @outputForwardRetryLimit = outputForwardRetryLimit
            puts "Using config map value: output_forward_retry_limit = #{@outputForwardRetryLimit}"
          end
        end
        requireAckResponse = fbit_config[:require_ack_response]
        if !requireAckResponse.nil? && requireAckResponse.downcase == "true"
          @requireAckResponse = requireAckResponse
          puts "Using config map value: require_ack_response = #{@requireAckResponse}"
        end
      end

      # mdsd settings
      mdsd_config = parsedConfig[:agent_settings][:mdsd_config]
      if !mdsd_config.nil?
        # ama-logs daemonset only settings
        if !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp(@daemonset) == 0 && @containerType.nil?
          mdsdMonitoringMaxEventRate = mdsd_config[:monitoring_max_event_rate]
          if is_valid_number?(mdsdMonitoringMaxEventRate)
            @mdsdMonitoringMaxEventRate = mdsdMonitoringMaxEventRate.to_i
            puts "Using config map value: monitoring_max_event_rate  = #{@mdsdMonitoringMaxEventRate}"
          end
          mdsdUploadMaxSizeInMB = mdsd_config[:upload_max_size_in_mb]
          if is_valid_number?(mdsdUploadMaxSizeInMB)
            @mdsdUploadMaxSizeInMB = mdsdUploadMaxSizeInMB.to_i
            puts "Using config map value: upload_max_size_in_mb  = #{@mdsdUploadMaxSizeInMB}"
          end
          mdsdUploadFrequencyInSeconds = mdsd_config[:upload_frequency_seconds]
          if is_valid_number?(mdsdUploadFrequencyInSeconds)
            @mdsdUploadFrequencyInSeconds = mdsdUploadFrequencyInSeconds.to_i
            puts "Using config map value: upload_frequency_seconds  = #{@mdsdUploadFrequencyInSeconds}"
          end
          mdsdCompressionLevel = mdsd_config[:compression_level]
          if is_number?(mdsdCompressionLevel) && mdsdCompressionLevel.to_i >= 0 && mdsdCompressionLevel.to_i < 10 # supported levels from 0 to 9
            @mdsdCompressionLevel = mdsdCompressionLevel.to_i
            puts "Using config map value: mdsdCompressionLevel = #{@mdsdCompressionLevel}"
          else
            puts "Ignoring mdsd compression_level level since its not supported level. Check input values for correctness."
          end
        end

        mdsdBackPressureThresholdInMB = mdsd_config[:backpressure_memory_threshold_in_mb]
        if is_valid_number?(mdsdBackPressureThresholdInMB) && is_valid_number?(@containerMemoryLimitInBytes) && mdsdBackPressureThresholdInMB.to_i < (@containerMemoryLimitInBytes.to_i / 1048576) && mdsdBackPressureThresholdInMB.to_i > 100
          @mdsdBackPressureThresholdInMB = mdsdBackPressureThresholdInMB.to_i
          puts "Using config map value: backpressure_memory_threshold_in_mb  = #{@mdsdBackPressureThresholdInMB}"
        else
          puts "Ignoring mdsd backpressure limit. Check input values for correctness. Configmap value in mb: #{mdsdBackPressureThresholdInMB}, container limit in bytes: #{@containerMemoryLimitInBytes}"
        end
      end

      prom_fbit_config = nil
      if !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp(@daemonset) == 0 && @containerType.nil?
        prom_fbit_config = parsedConfig[:agent_settings][:node_prometheus_fbit_settings]
      elsif !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp(@daemonset) != 0
        prom_fbit_config = parsedConfig[:agent_settings][:cluster_prometheus_fbit_settings]
      end

      if !prom_fbit_config.nil?
        chunk_size = prom_fbit_config[:tcp_listener_chunk_size]
        if is_valid_number?(chunk_size)
          @promFbitChunkSize = chunk_size.to_i
          puts "Using config map value: AZMON_FBIT_CHUNK_SIZE = #{@promFbitChunkSize.to_s + "m"}"
        end
        buffer_size = prom_fbit_config[:tcp_listener_buffer_size]
        if is_valid_number?(buffer_size)
          @promFbitBufferSize = buffer_size.to_i
          puts "Using config map value: AZMON_FBIT_BUFFER_SIZE = #{@promFbitBufferSize.to_s + "m"}"
          if @promFbitBufferSize < @promFbitChunkSize
            @promFbitBufferSize = @promFbitChunkSize
            puts "Setting Fbit buffer size equal to chunk size since it is set to less than chunk size - AZMON_FBIT_BUFFER_SIZE = #{@promFbitBufferSize.to_s + "m"}"
          end
        end
        mem_buf_limit = prom_fbit_config[:tcp_listener_mem_buf_limit]
        if is_valid_number?(mem_buf_limit)
          @promFbitMemBufLimit = mem_buf_limit.to_i
          puts "Using config map value: AZMON_FBIT_MEM_BUF_LIMIT = #{@promFbitMemBufLimit.to_s + "m"}"
        end
      end
      proxy_config = parsedConfig[:agent_settings][:proxy_config]
      if !proxy_config.nil?
        ignoreProxySettings = proxy_config[:ignore_proxy_settings]
        if !ignoreProxySettings.nil? && ignoreProxySettings.downcase == "true"
          @ignoreProxySettings = true
          puts "Using config map value: ignoreProxySettings = #{@ignoreProxySettings}"
        end
      end

      multiline_config = parsedConfig[:agent_settings][:multiline]
      if !multiline_config.nil?
        @multiline_enabled = multiline_config[:enabled]
        puts "Using config map value: AZMON_MULTILINE_ENABLED = #{@multiline_enabled}"
      end

      if !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp(@daemonset) == 0 && @containerType.nil?
        resource_optimization_config = parsedConfig[:agent_settings][:resource_optimization]
        if !resource_optimization_config.nil?
          resource_optimization_enabled = resource_optimization_config[:enabled]
          if !resource_optimization_enabled.nil? && (!!resource_optimization_enabled == resource_optimization_enabled) #Checking for Boolean type, since 'Boolean' is not defined as a type in ruby
            @resource_optimization_enabled = resource_optimization_enabled
          end
          puts "Using config map value: AZMON_RESOURCE_OPTIMIZATION_ENABLED = #{@resource_optimization_enabled}"
        end
      end

      windows_fluent_bit_config = parsedConfig[:agent_settings][:windows_fluent_bit]
      if !windows_fluent_bit_config.nil?
        windows_fluent_bit_disabled = windows_fluent_bit_config[:disabled]
        if !windows_fluent_bit_disabled.nil? && windows_fluent_bit_disabled.downcase == "false"
          @windows_fluent_bit_disabled = false
        end
        puts "Using config map value: AZMON_WINDOWS_FLUENT_BIT_DISABLED = #{@windows_fluent_bit_disabled}"
      end

      network_listener_waittime_config = parsedConfig[:agent_settings][:network_listener_waittime]
      if !network_listener_waittime_config.nil?
        waittime = network_listener_waittime_config[:tcp_port_25226]
        if is_valid_waittime?(waittime, @waittime_port_25226)
          @waittime_port_25226 = waittime.to_i
          puts "Using config map value: WAITTIME_PORT_25226 = #{@waittime_port_25226}"
        end

        waittime = network_listener_waittime_config[:tcp_port_25228]
        if is_valid_waittime?(waittime, @waittime_port_25228)
          @waittime_port_25228 = waittime.to_i
          puts "Using config map value: WAITTIME_PORT_25228 = #{@waittime_port_25228}"
        end

        waittime = network_listener_waittime_config[:tcp_port_25229]
        if is_valid_waittime?(waittime, @waittime_port_25229)
          @waittime_port_25229 = waittime.to_i
          puts "Using config map value: WAITTIME_PORT_25229 = #{@waittime_port_25229}"
        end
        waittime = network_listener_waittime_config[:tcp_port_13000]
        if is_valid_waittime?(waittime, @waittime_port_13000)
          @waittime_port_13000 = waittime.to_i
          puts "Using config map value: WAITTIME_PORT_13000 = #{@waittime_port_13000}"
        end
        waittime = network_listener_waittime_config[:tcp_port_12563]
        if is_valid_waittime?(waittime, @waittime_port_12563)
          @waittime_port_12563 = waittime.to_i
          puts "Using config map value: WAITTIME_PORT_12563 = #{@waittime_port_12563}"
        end
      end
    end
  rescue => errorStr
    puts "config::error:Exception while reading config settings for agent configuration setting - #{errorStr}, using defaults"
  end
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start Config Processing********************"
if !@configSchemaVersion.nil? && !@configSchemaVersion.empty? && @configSchemaVersion.strip.casecmp("v1") == 0 #note v1 is the only supported schema version , so hardcoding it
  configMapSettings = parseConfigMap
  if !configMapSettings.nil?
    populateSettingValuesFromConfigMap(configMapSettings)
  end
else
  if (File.file?(@configMapMountPath))
    ConfigParseErrorLogger.logError("config::unsupported/missing config schema version - '#{@configSchemaVersion}' , using defaults, please use supported schema version")
  end
end

# Write the settings to file, so that they can be set as environment variables
file = File.open("agent_config_env_var", "w")

if !file.nil?
  file.write("export NODES_CHUNK_SIZE=#{@nodesChunkSize}\n")
  file.write("export PODS_CHUNK_SIZE=#{@podsChunkSize}\n")
  file.write("export EVENTS_CHUNK_SIZE=#{@eventsChunkSize}\n")
  file.write("export DEPLOYMENTS_CHUNK_SIZE=#{@deploymentsChunkSize}\n")
  file.write("export HPA_CHUNK_SIZE=#{@hpaChunkSize}\n")
  file.write("export PODS_EMIT_STREAM_BATCH_SIZE=#{@podsEmitStreamBatchSize}\n")
  file.write("export NODES_EMIT_STREAM_BATCH_SIZE=#{@nodesEmitStreamBatchSize}\n")
  # fbit settings
  file.write("export ENABLE_FBIT_INTERNAL_METRICS=#{@enableFbitInternalMetrics}\n")
  if @fbitFlushIntervalSecs > 0
    file.write("export FBIT_SERVICE_FLUSH_INTERVAL=#{@fbitFlushIntervalSecs}\n")
  end
  if @fbitTailBufferChunkSizeMBs > 0
    file.write("export FBIT_TAIL_BUFFER_CHUNK_SIZE=#{@fbitTailBufferChunkSizeMBs}\n")
  end
  if @fbitTailBufferMaxSizeMBs > 0
    file.write("export FBIT_TAIL_BUFFER_MAX_SIZE=#{@fbitTailBufferMaxSizeMBs}\n")
  end
  if @fbitTailMemBufLimitMBs > 0
    file.write("export FBIT_TAIL_MEM_BUF_LIMIT=#{@fbitTailMemBufLimitMBs}\n")
  end
  if !@fbitTailIgnoreOlder.nil? && !@fbitTailIgnoreOlder.empty?
    file.write("export FBIT_TAIL_IGNORE_OLDER=#{@fbitTailIgnoreOlder}\n")
  end

  if @fbitStorageMaxChunksUp > 0
    file.write("export FBIT_STORAGE_MAX_CHUNKS_UP=#{@fbitStorageMaxChunksUp}\n")
  end

  if !@fbitStorageType.nil? && !@fbitStorageType.empty?
    file.write("export FBIT_STORAGE_TYPE=#{@fbitStorageType}\n")
  end

  if @enableFluentBitThreading
    file.write("export ENABLE_FBIT_THREADING=#{@enableFluentBitThreading}\n")
  end

  if @storageTotalLimitSizeMB > 0
    file.write("export STORAGE_TOTAL_LIMIT_SIZE_MB=#{@storageTotalLimitSizeMB.to_s + "M"}\n")
  end

  if @outputForwardWorkers > 0
    file.write("export OUTPUT_FORWARD_WORKERS_COUNT=#{@outputForwardWorkers}\n")
  end

  file.write("export OUTPUT_FORWARD_RETRY_LIMIT=#{@outputForwardRetryLimit}\n")
  file.write("export REQUIRE_ACK_RESPONSE=#{@requireAckResponse}\n")

  #mdsd settings
  if @mdsdMonitoringMaxEventRate > 0
    file.write("export MONITORING_MAX_EVENT_RATE=#{@mdsdMonitoringMaxEventRate}\n")
  end

  if @mdsdUploadMaxSizeInMB > 0
    file.write("export MDSD_ODS_UPLOAD_CHUNKING_SIZE_IN_MB=#{@mdsdUploadMaxSizeInMB}\n")
  end

  if @mdsdUploadFrequencyInSeconds > 0
    file.write("export AMA_MAX_PUBLISH_LATENCY=#{@mdsdUploadFrequencyInSeconds}\n")
    # MDSD requires this needs to be true for overriding the default 60s upload frequency
    file.write("export AMA_LOAD_TEST_LATENCY=true\n")
  end

  if @mdsdBackPressureThresholdInMB > 0
    file.write("export BACKPRESSURE_THRESHOLD_IN_MB=#{@mdsdBackPressureThresholdInMB}\n")
  end

  if @mdsdCompressionLevel >= 0
    file.write("export MDSD_ODS_COMPRESSION_LEVEL=#{@mdsdCompressionLevel}\n")
  end

  if @promFbitChunkSize > 0
    file.write("export AZMON_FBIT_CHUNK_SIZE=#{@promFbitChunkSize.to_s + "m"}\n")
  else
    file.write("export AZMON_FBIT_CHUNK_SIZE=#{@promFbitChunkSizeDefault}\n")
  end

  if @promFbitBufferSize > 0
    file.write("export AZMON_FBIT_BUFFER_SIZE=#{@promFbitBufferSize.to_s + "m"}\n")
  else
    file.write("export AZMON_FBIT_BUFFER_SIZE=#{@promFbitBufferSizeDefault}\n")
  end

  if @promFbitMemBufLimit > 0
    file.write("export AZMON_FBIT_MEM_BUF_LIMIT=#{@promFbitMemBufLimit.to_s + "m"}\n")
  else
    file.write("export AZMON_FBIT_MEM_BUF_LIMIT=#{@promFbitMemBufLimitDefault}\n")
  end

  if @ignoreProxySettings
    file.write("export IGNORE_PROXY_SETTINGS=#{@ignoreProxySettings}\n")
  end

  if @multiline_enabled.strip.casecmp("true") == 0
    file.write("export AZMON_MULTILINE_ENABLED=#{@multiline_enabled}\n")
  end

  file.write("export AZMON_RESOURCE_OPTIMIZATION_ENABLED=#{@resource_optimization_enabled}\n")

  if !@windows_fluent_bit_disabled
    file.write("export AZMON_WINDOWS_FLUENT_BIT_DISABLED=#{@windows_fluent_bit_disabled}\n")
  end

  file.write("export WAITTIME_PORT_25226=#{@waittime_port_25226}\n")
  file.write("export WAITTIME_PORT_25228=#{@waittime_port_25228}\n")
  file.write("export WAITTIME_PORT_25229=#{@waittime_port_25229}\n")
  file.write("export WAITTIME_PORT_13000=#{@waittime_port_13000}\n")
  file.write("export WAITTIME_PORT_12563=#{@waittime_port_12563}\n")

  # Close file after writing all environment variables
  file.close
else
  puts "Exception while opening file for writing config environment variables"
  puts "****************End Config Processing********************"
end

def get_command_windows(env_variable_name, env_variable_value)
  return "#{env_variable_name}=#{env_variable_value}\n"
end

if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
  # Write the settings to file, so that they can be set as environment variables
  file = File.open("setagentenv.txt", "w")

  if !file.nil?
    commands = get_command_windows("ENABLE_FBIT_INTERNAL_METRICS", @enableFbitInternalMetrics)
    file.write(commands)
    if @fbitFlushIntervalSecs > 0
      commands = get_command_windows("FBIT_SERVICE_FLUSH_INTERVAL", @fbitFlushIntervalSecs)
      file.write(commands)
    end
    if @fbitTailBufferChunkSizeMBs > 0
      commands = get_command_windows("FBIT_TAIL_BUFFER_CHUNK_SIZE", @fbitTailBufferChunkSizeMBs)
      file.write(commands)
    end
    if @fbitTailBufferMaxSizeMBs > 0
      commands = get_command_windows("FBIT_TAIL_BUFFER_MAX_SIZE", @fbitTailBufferMaxSizeMBs)
      file.write(commands)
    end
    if @fbitTailMemBufLimitMBs > 0
      commands = get_command_windows("FBIT_TAIL_MEM_BUF_LIMIT", @fbitTailMemBufLimitMBs)
      file.write(commands)
    end
    if !@fbitTailIgnoreOlder.nil? && !@fbitTailIgnoreOlder.empty?
      commands = get_command_windows("FBIT_TAIL_IGNORE_OLDER", @fbitTailIgnoreOlder)
      file.write(commands)
    end

    if @fbitStorageMaxChunksUp > 0
      commands = get_command_windows("FBIT_STORAGE_MAX_CHUNKS_UP", @fbitStorageMaxChunksUp)
      file.write(commands)
    end
    if !@fbitStorageType.nil? && !@fbitStorageType.empty?
      commands = get_command_windows("FBIT_STORAGE_TYPE", @fbitStorageType)
    end

    if @enableFluentBitThreading
      commands = get_command_windows("ENABLE_FBIT_THREADING", @enableFluentBitThreading)
      file.write(commands)
    end

    if @promFbitChunkSize > 0
      commands = get_command_windows("AZMON_FBIT_CHUNK_SIZE", @promFbitChunkSize.to_s + "m")
      file.write(commands)
    else
      commands = get_command_windows("AZMON_FBIT_CHUNK_SIZE", @promFbitChunkSizeDefault)
      file.write(commands)
    end
    if @promFbitBufferSize > 0
      commands = get_command_windows("AZMON_FBIT_BUFFER_SIZE", @promFbitBufferSize.to_s + "m")
      file.write(commands)
    else
      commands = get_command_windows("AZMON_FBIT_BUFFER_SIZE", @promFbitBufferSizeDefault)
      file.write(commands)
    end
    if @promFbitMemBufLimit > 0
      commands = get_command_windows("AZMON_FBIT_MEM_BUF_LIMIT", @promFbitMemBufLimit.to_s + "m")
      file.write(commands)
    else
      commands = get_command_windows("AZMON_FBIT_MEM_BUF_LIMIT", @promFbitMemBufLimitDefault)
      file.write(commands)
    end

    if @storageTotalLimitSizeMB > 0
      commands = get_command_windows("STORAGE_TOTAL_LIMIT_SIZE_MB", @storageTotalLimitSizeMB.to_s + "M")
      file.write(commands)
    end

    if @outputForwardWorkers > 0
      commands = get_command_windows("OUTPUT_FORWARD_WORKERS_COUNT", @outputForwardWorkers)
      file.write(commands)
    end

    commands = get_command_windows("OUTPUT_FORWARD_RETRY_LIMIT", @outputForwardRetryLimit)
    file.write(commands)

    commands = get_command_windows("REQUIRE_ACK_RESPONSE", @requireAckResponse)
    file.write(commands)

    if @ignoreProxySettings
      commands = get_command_windows("IGNORE_PROXY_SETTINGS", @ignoreProxySettings)
      file.write(commands)
    end
    if @multiline_enabled.strip.casecmp("true") == 0
      commands = get_command_windows("AZMON_MULTILINE_ENABLED", @multiline_enabled)
      file.write(commands)
    end
    if @resource_optimization_enabled
      commands = get_command_windows("AZMON_RESOURCE_OPTIMIZATION_ENABLED", @resource_optimization_enabled)
      file.write(commands)
    end

    if !@windows_fluent_bit_disabled
      commands = get_command_windows("AZMON_WINDOWS_FLUENT_BIT_DISABLED", @windows_fluent_bit_disabled)
      file.write(commands)
    end

    commands = get_command_windows("WAITTIME_PORT_25229", @waittime_port_25229)
    file.write(commands)

    # Close file after writing all environment variables
    file.close
    puts "****************End Config Processing********************"
  else
    puts "Exception while opening file for writing config environment variables for WINDOWS LOG"
    puts "****************End Config Processing********************"
  end
end
