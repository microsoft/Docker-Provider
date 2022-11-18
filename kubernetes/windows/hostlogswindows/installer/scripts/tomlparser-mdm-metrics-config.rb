#!/usr/local/bin/ruby
# frozen_string_literal: true

#this should be require relative in Linux and require in windows, since it is a gem install on windows
@os_type = ENV["OS_TYPE"]
require "tomlrb"

require_relative "/etc/fluent/plugin/constants"
require_relative "ConfigParseErrorLogger"

@configMapMountPath = "/etc/config/settings/alertable-metrics-configuration-settings"
@configVersion = ""
@configSchemaVersion = ""
# Setting default values which will be used in case they are not set in the configmap or if configmap doesnt exist
@percentageCpuUsageThreshold = Constants::DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD
@percentageMemoryRssThreshold = Constants::DEFAULT_MDM_MEMORY_RSS_THRESHOLD
@percentageMemoryWorkingSetThreshold = Constants::DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD
@percentagePVUsageThreshold = Constants::DEFAULT_MDM_PV_UTILIZATION_THRESHOLD
@jobCompletionThresholdMinutes = Constants::DEFAULT_MDM_JOB_COMPLETED_TIME_THRESHOLD_MINUTES

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@configMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig for MDM metric settings mounted, parsing values"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for MDM metrics settings not mounted, using defaults"
      return nil
    end
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while parsing config map for MDM metric settings: #{errorStr}, using defaults, please check config map for errors")
    return nil
  end
end

# Use the ruby structure created after config parsing to set the right values to be used for MDM metric configuration settings
def populateSettingValuesFromConfigMap(parsedConfig)
  if !parsedConfig.nil? && !parsedConfig[:alertable_metrics_configuration_settings].nil?
    # Get mdm metrics config settings for container resource utilization
    begin
      resourceUtilization = parsedConfig[:alertable_metrics_configuration_settings][:container_resource_utilization_thresholds]
      if !resourceUtilization.nil?
        #Cpu
        cpuThreshold = resourceUtilization[:container_cpu_threshold_percentage]
        cpuThresholdFloat = cpuThreshold.to_f
        if cpuThresholdFloat.kind_of? Float
          @percentageCpuUsageThreshold = cpuThresholdFloat
        else
          puts "config::Non floating point value or value not convertible to float specified for Cpu threshold, using default "
          @percentageCpuUsageThreshold = Constants::DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD
        end
        #Memory Rss
        memoryRssThreshold = resourceUtilization[:container_memory_rss_threshold_percentage]
        memoryRssThresholdFloat = memoryRssThreshold.to_f
        if memoryRssThresholdFloat.kind_of? Float
          @percentageMemoryRssThreshold = memoryRssThresholdFloat
        else
          puts "config::Non floating point value or value not convertible to float specified for Memory Rss threshold, using default "
          @percentageMemoryRssThreshold = Constants::DEFAULT_MDM_MEMORY_RSS_THRESHOLD
        end
        #Memory Working Set
        memoryWorkingSetThreshold = resourceUtilization[:container_memory_working_set_threshold_percentage]
        memoryWorkingSetThresholdFloat = memoryWorkingSetThreshold.to_f
        if memoryWorkingSetThresholdFloat.kind_of? Float
          @percentageMemoryWorkingSetThreshold = memoryWorkingSetThresholdFloat
        else
          puts "config::Non floating point value or value not convertible to float specified for Memory Working Set threshold, using default "
          @percentageMemoryWorkingSetThreshold = Constants::DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD
        end
        puts "config::Using config map settings for MDM metric configuration settings for container resource utilization"
      end
    rescue => errorStr
      ConfigParseErrorLogger.logError("Exception while reading config map settings for MDM metric configuration settings for resource utilization - #{errorStr}, using defaults, please check config map for errors")
      @percentageCpuUsageThreshold = Constants::DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD
      @percentageMemoryRssThreshold = Constants::DEFAULT_MDM_MEMORY_RSS_THRESHOLD
      @percentageMemoryWorkingSetThreshold = Constants::DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD
    end

    # Get mdm metrics config settings for PV utilization
    begin
      isUsingPVThresholdConfig = false
      pvUtilizationThresholds = parsedConfig[:alertable_metrics_configuration_settings][:pv_utilization_thresholds]
      if !pvUtilizationThresholds.nil?
        pvUsageThreshold = pvUtilizationThresholds[:pv_usage_threshold_percentage]
        if !pvUsageThreshold.nil?
          pvUsageThresholdFloat = pvUsageThreshold.to_f
          if pvUsageThresholdFloat.kind_of? Float
            @percentagePVUsageThreshold = pvUsageThresholdFloat
            isUsingPVThresholdConfig = true
          end
        end
      end

      if isUsingPVThresholdConfig
        puts "config::Using config map settings for MDM metric configuration settings for PV utilization"
      else
        puts "config::Non floating point value or value not convertible to float specified for PV threshold, using default "
        @percentagePVUsageThreshold = Constants::DEFAULT_MDM_PV_UTILIZATION_THRESHOLD
      end
    rescue => errorStr
      ConfigParseErrorLogger.logError("Exception while reading config map settings for MDM metric configuration settings for PV utilization - #{errorStr}, using defaults, please check config map for errors")
      @percentagePVUsageThreshold = Constants::DEFAULT_MDM_PV_UTILIZATION_THRESHOLD
    end

    # Get mdm metrics config settings for job completion
    begin
      jobCompletion = parsedConfig[:alertable_metrics_configuration_settings][:job_completion_threshold]
      if !jobCompletion.nil?
        jobCompletionThreshold = jobCompletion[:job_completion_threshold_time_minutes]
        jobCompletionThresholdInt = jobCompletionThreshold.to_i
        if jobCompletionThresholdInt.kind_of? Integer
          @jobCompletionThresholdMinutes = jobCompletionThresholdInt
        else
          puts "config::Non interger value or value not convertible to integer specified for job completion threshold, using default "
          @jobCompletionThresholdMinutes = Constants::DEFAULT_MDM_JOB_COMPLETED_TIME_THRESHOLD_MINUTES
        end
        puts "config::Using config map settings for MDM metric configuration settings for job completion"
      end
    rescue => errorStr
      ConfigParseErrorLogger.logError("Exception while reading config map settings for MDM metric configuration settings for job completion - #{errorStr}, using defaults, please check config map for errors")
      @jobCompletionThresholdMinutes = Constants::DEFAULT_MDM_JOB_COMPLETED_TIME_THRESHOLD_MINUTES
    end
  end
end

def get_command_windows(env_variable_name, env_variable_value)
  return "[System.Environment]::SetEnvironmentVariable(\"#{env_variable_name}\", \"#{env_variable_value}\", \"Process\")" + "\n" + "[System.Environment]::SetEnvironmentVariable(\"#{env_variable_name}\", \"#{env_variable_value}\", \"Machine\")" + "\n"
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start MDM Metrics Config Processing********************"
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

if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
  # Write the settings to file, so that they can be set as environment variables in windows container
  file = File.open("setmdmenv.ps1", "w")

  if !file.nil?
    commands = get_command_windows("AZMON_ALERT_CONTAINER_CPU_THRESHOLD", @percentageCpuUsageThreshold)
    file.write(commands)
    commands = get_command_windows("AZMON_ALERT_CONTAINER_MEMORY_WORKING_SET_THRESHOLD", @percentageMemoryWorkingSetThreshold)
    file.write(commands)
    # Close file after writing all environment variables
    file.close
    puts "****************End MDM Metrics Config Processing********************"
  else
    puts "Exception while opening file for writing MDM metric config environment variables"
    puts "****************End MDM Metrics Config Processing********************"
  end
else
  # Write the settings to file, so that they can be set as environment variables in linux container
  file = File.open("config_mdm_metrics_env_var", "w")

  if !file.nil?
    file.write("export AZMON_ALERT_CONTAINER_CPU_THRESHOLD=#{@percentageCpuUsageThreshold}\n")
    file.write("export AZMON_ALERT_CONTAINER_MEMORY_RSS_THRESHOLD=#{@percentageMemoryRssThreshold}\n")
    file.write("export AZMON_ALERT_CONTAINER_MEMORY_WORKING_SET_THRESHOLD=\"#{@percentageMemoryWorkingSetThreshold}\"\n")
    file.write("export AZMON_ALERT_PV_USAGE_THRESHOLD=#{@percentagePVUsageThreshold}\n")
    file.write("export AZMON_ALERT_JOB_COMPLETION_TIME_THRESHOLD=#{@jobCompletionThresholdMinutes}\n")
    # Close file after writing all MDM setting environment variables
    file.close
    puts "****************End MDM Metrics Config Processing********************"
  else
    puts "Exception while opening file for writing MDM metric config environment variables"
    puts "****************End MDM Metrics Config Processing********************"
  end
end
