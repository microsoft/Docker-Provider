#!/usr/local/bin/ruby

#this should be require relative in Linux and require in windows, since it is a gem install on windows
@os_type = ENV["OS_TYPE"]
require "tomlrb"

require_relative "ConfigParseErrorLogger"

@configMapMountPath = "/etc/config/settings/agent-settings"
@configSchemaVersion = ""

@promFbitChunkSize = 10
@promFbitBufferSize = 10
@promFbitMemBufLimit = 200

@waittime_port_25226 = 45
@waittime_port_25228 = 120
@waittime_port_25229 = 45
@containerMemoryLimitInBytes = ENV["CONTAINER_MEMORY_LIMIT_IN_BYTES"]
@mdsdBackPressureThresholdInMB = 0

def is_number?(value)
  true if Integer(value) rescue false
end

# check if it is number and greater than 0
def is_valid_number?(value)
  return !value.nil? && is_number?(value) && value.to_i > 0
end

# check if it is a valid waittime
def is_valid_waittime?(value, default)
  return !value.nil? && is_number?(value) && value.to_i >= default/2 && value.to_i <= 3*default
end

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@configMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig for sidecar agent settings mounted, parsing values"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for sidecar agent settings not mounted, using defaults"
      return nil
    end
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while parsing config map for sidecar agent settings : #{errorStr}, using defaults, please check config map for errors")
    return nil
  end
end

# Use the ruby structure created after config parsing to set the right values to be used as environment variables
def populateSettingValuesFromConfigMap(parsedConfig)
  begin
    if !parsedConfig.nil? && !parsedConfig[:agent_settings].nil?
      # fbit config settings
      prom_fbit_config = parsedConfig[:agent_settings][:prometheus_fbit_settings]
      if !prom_fbit_config.nil?
        chunk_size = prom_fbit_config[:tcp_listener_chunk_size]
        if !chunk_size.nil? && is_number?(chunk_size) && chunk_size.to_i > 0
          @promFbitChunkSize = chunk_size.to_i
          puts "Using config map value: AZMON_SIDECAR_FBIT_CHUNK_SIZE = #{@promFbitChunkSize.to_s + "m"}"
        end
        buffer_size = prom_fbit_config[:tcp_listener_buffer_size]
        if !buffer_size.nil? && is_number?(buffer_size) && buffer_size.to_i > 0
          @promFbitBufferSize = buffer_size.to_i
          puts "Using config map value: AZMON_SIDECAR_FBIT_BUFFER_SIZE = #{@promFbitBufferSize.to_s + "m"}"
          if @promFbitBufferSize < @promFbitChunkSize
            @promFbitBufferSize = @promFbitChunkSize
            puts "Setting Fbit buffer size equal to chunk size since it is set to less than chunk size - AZMON_SIDECAR_FBIT_BUFFER_SIZE = #{@promFbitBufferSize.to_s + "m"}"
          end
        end
        mem_buf_limit = prom_fbit_config[:tcp_listener_mem_buf_limit]
        if !mem_buf_limit.nil? && is_number?(mem_buf_limit) && mem_buf_limit.to_i > 0
          @promFbitMemBufLimit = mem_buf_limit.to_i
          puts "Using config map value: AZMON_SIDECAR_FBIT_MEM_BUF_LIMIT = #{@promFbitMemBufLimit.to_s + "m"}"
        end
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
      end

      # mdsd settings
      mdsd_config = parsedConfig[:agent_settings][:mdsd_config]
      if !mdsd_config.nil?
        mdsdBackPressureThresholdInMB = mdsd_config[:backpressure_memory_threshold_in_mb]
        if is_valid_number?(mdsdBackPressureThresholdInMB) && is_valid_number?(@containerMemoryLimitInBytes) && mdsdBackPressureThresholdInMB.to_i < (@containerMemoryLimitInBytes.to_i / 1048576) && mdsdBackPressureThresholdInMB.to_i > 100
          @mdsdBackPressureThresholdInMB = mdsdBackPressureThresholdInMB.to_i
          puts "Using config map value: backpressure_memory_threshold_in_mb  = #{@mdsdBackPressureThresholdInMB}"
        else
          puts "Ignoring mdsd backpressure limit. Check input values for correctness. Configmap value in mb: #{mdsdBackPressureThresholdInMB}, container limit in bytes: #{@containerMemoryLimitInBytes}"
        end
      end

    end
  rescue => errorStr
    puts "config::error:Exception while reading config settings for sidecar agent configuration setting - #{errorStr}, using defaults"
  end
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start Sidecar Agent Config Processing********************"
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
file = File.open("side_car_fbit_config_env_var", "w")

if !file.nil?
  file.write("export AZMON_SIDECAR_FBIT_CHUNK_SIZE=#{@promFbitChunkSize.to_s + "m"}\n")
  file.write("export AZMON_SIDECAR_FBIT_BUFFER_SIZE=#{@promFbitBufferSize.to_s + "m"}\n")
  file.write("export AZMON_SIDECAR_FBIT_MEM_BUF_LIMIT=#{@promFbitMemBufLimit.to_s + "m"}\n")
  
  file.write("export WAITTIME_PORT_25226=#{@waittime_port_25226}\n")
  file.write("export WAITTIME_PORT_25228=#{@waittime_port_25228}\n")
  file.write("export WAITTIME_PORT_25229=#{@waittime_port_25229}\n")
  
  if @mdsdBackPressureThresholdInMB > 0
    file.write("export BACKPRESSURE_THRESHOLD_IN_MB=#{@mdsdBackPressureThresholdInMB}\n")
  end

  # Close file after writing all environment variables
  file.close
else
  puts "Exception while opening file for writing config environment variables"
  puts "****************End Sidecar Agent Config Processing********************"
end
