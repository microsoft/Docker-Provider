#!/usr/local/bin/ruby

@os_type = ENV["OS_TYPE"]
require "tomlrb"

require_relative "ConfigParseErrorLogger"

@configMapMountPath = "/etc/config/settings/agent-settings"
@configSchemaVersion = ""

@disableTelemetry = false
@logEnableKubernetesMetadataCacheTTLSeconds = 60
@enableHighLogScaleMode = false

def is_windows?
  return !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
end

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
      puts "config::configmap container-azm-ms-agentconfig for common agent settings mounted, parsing values"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for common agent settings not mounted, using defaults"
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
      telemetry_config = parsedConfig[:agent_settings][:telemetry_config]
      if !telemetry_config.nil? && !telemetry_config[:disable_telemetry].nil?
        @disableTelemetry = telemetry_config[:disable_telemetry]
        puts "Using config map value: disable_telemetry = #{@disableTelemetry}"
      end
    end

    # agent config for kube_meta_cache_ttl_secs which used in containerlogv2 kubernetes metadata and annotation based filtering
    if !parsedConfig.nil? && !parsedConfig[:agent_settings].nil?
      k8s_metadata_config = parsedConfig[:agent_settings][:k8s_metadata_config]
      if !k8s_metadata_config.nil? && !k8s_metadata_config[:kube_meta_cache_ttl_secs].nil?
        ttl_value = k8s_metadata_config[:kube_meta_cache_ttl_secs]
        if ttl_value.is_a?(Integer) && ttl_value >= 0
          @logEnableKubernetesMetadataCacheTTLSeconds = ttl_value
          puts "config::INFO: Using config map value: kube_meta_cache_ttl_secs = #{@logEnableKubernetesMetadataCacheTTLSeconds}"
        else
          puts "config::WARN: Using the default value for kube_meta_cache_ttl_secs since provided config value is invalid"
        end
      end
    end
    if !parsedConfig.nil? && !parsedConfig[:agent_settings].nil?
      high_log_scale = parsedConfig[:agent_settings][:high_log_scale]
      if !high_log_scale.nil? && !high_log_scale[:enabled].nil?
        @enableHighLogScaleMode = high_log_scale[:enabled]
        puts "Using config map value: enabled = #{@enableHighLogScaleMode} for high log scale config"
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

def get_command_windows(env_variable_name, env_variable_value)
  return "#{env_variable_name}=#{env_variable_value}\n"
end

if is_windows?
  # Write the settings to file, so that they can be set as environment variables
  file = File.open("setcommonagentenv.txt", "w")
  if !file.nil?
    if @disableTelemetry
      commands = get_command_windows("DISABLE_TELEMETRY", @disableTelemetry)
      file.write(commands)
    end

    if @enableHighLogScaleMode
      commands = get_command_windows("ENABLE_HIGH_LOG_SCALE_MODE", @enableHighLogScaleMode)
      file.write(commands)
    end

    commands = get_command_windows("AZMON_KUBERNETES_METADATA_CACHE_TTL_SECONDS", @logEnableKubernetesMetadataCacheTTLSeconds)
    file.write(commands)
    # Close file after writing all environment variables
    file.close
    puts "****************End Config Processing********************"
  else
    puts "Exception while opening file for writing config environment variables for WINDOWS LOG"
    puts "****************End Config Processing********************"
  end
else
  # Write the settings to file, so that they can be set as environment variables
  file = File.open("common_agent_config_env_var", "w")
  if !file.nil?
    if @disableTelemetry
      file.write("export DISABLE_TELEMETRY=#{@disableTelemetry}\n")
    end
    if @enableHighLogScaleMode
      file.write("export ENABLE_HIGH_LOG_SCALE_MODE=#{@enableHighLogScaleMode}\n")
    end
    file.write("export AZMON_KUBERNETES_METADATA_CACHE_TTL_SECONDS=#{@logEnableKubernetesMetadataCacheTTLSeconds}\n")
    # Close file after writing all environment variables
    file.close
  else
    puts "Exception while opening file for writing config environment variables"
    puts "****************End Config Processing********************"
  end
end
