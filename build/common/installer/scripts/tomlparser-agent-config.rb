#!/usr/local/bin/ruby

#this should be require relative in Linux and require in windows, since it is a gem install on windows
@os_type = ENV["OS_TYPE"]
require "tomlrb"

require_relative "ConfigParseErrorLogger"

@configMapMountPath = "/etc/config/settings/agent-settings"
@configSchemaVersion = ""

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
@podsChunkSizeMin = 250
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
@fbitFlushIntervalSecs = 0
@fbitTailBufferChunkSizeMBs = 0
@fbitTailBufferMaxSizeMBs = 0
@fbitTailMemBufLimitMBs = 0
@fbitTailIgnoreOlder = ""

# Checking to see if this is the daemonset or replicaset to parse config accordingly
@controllerType = ENV["CONTROLLER_TYPE"]
@daemonset = "daemonset"
# Checking to see if container is not prometheus sidecar.
# CONTAINER_TYPE is populated only for prometheus sidecar container.
@containerType = ENV["CONTAINER_TYPE"]

@promFbitChunkSize = 0
@promFbitBufferSize = 0
@promFbitMemBufLimit = 0

@promFbitChunkSizeDefault = "32k" #kb
@promFbitBufferSizeDefault  = "64k" #kb
@promFbitMemBufLimitDefault  = "10m" #mb

def is_number?(value)
  true if Integer(value) rescue false
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
        if !fbitFlushIntervalSecs.nil? && is_number?(fbitFlushIntervalSecs) && fbitFlushIntervalSecs.to_i > 0
          @fbitFlushIntervalSecs = fbitFlushIntervalSecs.to_i
          puts "Using config map value: log_flush_interval_secs = #{@fbitFlushIntervalSecs}"
        end

        fbitTailBufferChunkSizeMBs = fbit_config[:tail_buf_chunksize_megabytes]
        if !fbitTailBufferChunkSizeMBs.nil? && is_number?(fbitTailBufferChunkSizeMBs) && fbitTailBufferChunkSizeMBs.to_i > 0
          @fbitTailBufferChunkSizeMBs = fbitTailBufferChunkSizeMBs.to_i
          puts "Using config map value: tail_buf_chunksize_megabytes  = #{@fbitTailBufferChunkSizeMBs}"
        end

        fbitTailBufferMaxSizeMBs = fbit_config[:tail_buf_maxsize_megabytes]
        if !fbitTailBufferMaxSizeMBs.nil? && is_number?(fbitTailBufferMaxSizeMBs) && fbitTailBufferMaxSizeMBs.to_i > 0
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
        if !fbitTailMemBufLimitMBs.nil? && is_number?(fbitTailMemBufLimitMBs) && fbitTailMemBufLimitMBs.to_i > 0
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
      end
    
      prom_fbit_config = nil
      if !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp(@daemonset) == 0 && @containerType.nil?
        prom_fbit_config = parsedConfig[:agent_settings][:node_prometheus_fbit_settings]
      elsif !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp(@daemonset) != 0
        prom_fbit_config = parsedConfig[:agent_settings][:cluster_prometheus_fbit_settings]
      end

      if !prom_fbit_config.nil?
        chunk_size = prom_fbit_config[:tcp_listener_chunk_size]
        if !chunk_size.nil? && is_number?(chunk_size) && chunk_size.to_i > 0
          @promFbitChunkSize = chunk_size.to_i
          puts "Using config map value: AZMON_FBIT_CHUNK_SIZE = #{@promFbitChunkSize.to_s + "m"}"
        end
        buffer_size = prom_fbit_config[:tcp_listener_buffer_size]
        if !buffer_size.nil? && is_number?(buffer_size) && buffer_size.to_i > 0
          @promFbitBufferSize = buffer_size.to_i
          puts "Using config map value: AZMON_FBIT_BUFFER_SIZE = #{@promFbitBufferSize.to_s + "m"}"
          if @promFbitBufferSize < @promFbitChunkSize
            @promFbitBufferSize = @promFbitChunkSize
            puts "Setting Fbit buffer size equal to chunk size since it is set to less than chunk size - AZMON_FBIT_BUFFER_SIZE = #{@promFbitBufferSize.to_s + "m"}"
          end
        end
        mem_buf_limit = prom_fbit_config[:tcp_listener_mem_buf_limit]
        if !mem_buf_limit.nil? && is_number?(mem_buf_limit) && mem_buf_limit.to_i > 0
          @promFbitMemBufLimit = mem_buf_limit.to_i
          puts "Using config map value: AZMON_FBIT_MEM_BUF_LIMIT = #{@promFbitMemBufLimit.to_s + "m"}"
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

  # Close file after writing all environment variables
  file.close
else
  puts "Exception while opening file for writing config environment variables"
  puts "****************End Config Processing********************"
end

def get_command_windows(env_variable_name, env_variable_value)
  return "[System.Environment]::SetEnvironmentVariable(\"#{env_variable_name}\", \"#{env_variable_value}\", \"Process\")" + "\n" + "[System.Environment]::SetEnvironmentVariable(\"#{env_variable_name}\", \"#{env_variable_value}\", \"Machine\")" + "\n"
end

if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
  # Write the settings to file, so that they can be set as environment variables
  file = File.open("setagentenv.ps1", "w")

  if !file.nil?
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
    # Close file after writing all environment variables
    file.close
    puts "****************End Config Processing********************"
  else
    puts "Exception while opening file for writing config environment variables for WINDOWS LOG"
    puts "****************End Config Processing********************"
  end
end
