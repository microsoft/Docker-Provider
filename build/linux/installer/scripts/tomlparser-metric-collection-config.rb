#!/usr/local/bin/ruby
# frozen_string_literal: true

require_relative "tomlrb"
require_relative "ConfigParseErrorLogger"
require_relative "microsoft/omsagent/plugin/constants"

@configMapMountPath = "/etc/config/settings/metric_collection_settings"
@configVersion = ""
@configSchemaVersion = ""

# Setting default values which will be used in case they are not set in the configmap or if configmap doesnt exist
@collectPVKubeSystemMetrics = false

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@configMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig for metric collection settings mounted, parsing values"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for metric collection settings not mounted, using defaults"
      return nil
    end
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while parsing config map for metric collection settings: #{errorStr}, using defaults, please check config map for errors")
    return nil
  end
end

# Use the ruby structure created after config parsing to set the right values to be used for metric collection settings
def populateSettingValuesFromConfigMap(parsedConfig)
  # Get metric collection settings for including or excluding kube-system namespace in PV metrics
  begin
    if !parsedConfig.nil? && !parsedConfig[:metric_collection_settings][:collect_kube_system_pv_metrics].nil? && !parsedConfig[:metric_collection_settings][:collect_kube_system_pv_metrics][:enabled].nil?
      @collectPVKubeSystemMetrics = parsedConfig[:metric_collection_settings][:collect_kube_system_pv_metrics][:enabled]
      puts "config::Using config map setting for PV kube-system collection"
    end
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while reading config map settings for PV kube-system collection - #{errorStr}, using defaults, please check config map for errors")
  end
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start Metric Collection Settings Processing********************"
if !@configSchemaVersion.nil? && !@configSchemaVersion.empty? && @configSchemaVersion.strip.casecmp("v1") == 0 #note v1 is the only supported schema version, so hardcoding it
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
file = File.open("config_metric_collection_env_var", "w")

if !file.nil?
  file.write("export AZMON_PV_COLLECT_KUBE_SYSTEM_METRICS=#{@collectPVKubeSystemMetrics}\n")
  # Close file after writing all metric collection setting environment variables
  file.close
  puts "****************End Metric Collection Settings Processing********************"
else
  puts "Exception while opening file for writing MDM metric config environment variables"
  puts "****************End Metric Collection Settings Processing********************"
end
