#!/usr/local/bin/ruby

require_relative "tomlrb"

@promConfigMapMountPath = "/etc/config/settings/prometheus-data-collection-settings"
@replicaset = "replicaset"
@daemonset = "daemonset"
# @cnfigVersion = ""
@promConfigSchemaVersion = ""
# Setting default values which will be used in case they are not set in the configmap or if configmap doesnt exist
# @collectStdoutLogs = true
# @stdoutExcludeNamespaces = "kube-system"
# @collectStderrLogs = true
# @stderrExcludeNamespaces = "kube-system"
# @collectClusterEnvVariables = true
# @logTailPath = "/var/log/containers/*.log"
# @logExclusionRegexPattern = "(^((?!stdout|stderr).)*$)"
# @excludePath = "*.csv2" #some invalid path

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@promConfigMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig for settings mounted, parsing values for prometheus config map"
      parsedConfig = Tomlrb.load_file(@promConfigMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted prometheus config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for settings not mounted, using defaults for prometheus scraping"
      # @excludePath = "*_kube-system_*.log"
      return nil
    end
  rescue => errorStr
    puts "config::error::Exception while parsing toml config file for prometheus config: #{errorStr}, using defaults"
    # @excludePath = "*_kube-system_*.log"
    return nil
  end
end

def checkForTypeArray(arrayValue, arrayType)
  if !arrayValue.nil? && arrayValue.kind_of?(Array) && arrayValue.length > 0 && arrayValue[0].kind_of?(arrayType)
    return true
  else
    return false
  end
end

def checkForType(variable, varType)
  if !variable.nil? && variable.kind_of?(varType)
    return true
  else
    return false
  end
end

# Use the ruby structure created after config parsing to set the right values to be used as environment variables
def populateSettingValuesFromConfigMap(parsedConfig)
puts "****************Start Prometheus Config Processing********************"
  # Checking to see if this is the daemonset or replicaset to parse config accordingly
  controller = ENV["CONTROLLER_TYPE"]
  if !controller.nil?
      if !parsedConfig.nil? && !parsedConfig[:prometheus_data_collection_settings].nil? 
        if controller.casecmp(@replicaset) == 0 && !parsedConfig[:prometheus_data_collection_settings][:cluster].nil?
        #Get prometheus replicaset custom config settings
        begin
          interval = parsedConfig[:prometheus_data_collection_settings][:cluster][:interval]
          fieldPass = parsedConfig[:prometheus_data_collection_settings][:cluster][:fieldpass]
          fieldDrop = parsedConfig[:prometheus_data_collection_settings][:cluster][:fielddrop]
          urls = parsedConfig[:prometheus_data_collection_settings][:cluster][:urls]
          kubernetesServices = parsedConfig[:prometheus_data_collection_settings][:cluster][:kubernetes_services]
          monitorKubernetesPods = parsedConfig[:prometheus_data_collection_settings][:cluster][:monitor_kubernetes_pods]

          if checkForType(interval, String) 
            && checkForTypeArray(fieldPass, String)
            && checkForTypeArray(fieldDrop, String)
            && checkForTypeArray(kubernetesServices, String)
            && checkForTypeArray(urls, String)
            && checkForType(monitorKubernetesPods, Boolean)

            # Write the settings to file, so that they can be set as environment variables
file = File.open("prom_config_env_var", "w")

if !file.nil?
  file.write("export AZMON_RS_PROM_INTERVAL=#{interval}\n")
  file.write("export AZMON_RS_PROM_FIELDPASS=\"#{fieldPass}\"\n")
  file.write("export AZMON_RS_PROM_FIELDDROP=#{fieldDrop}\n")
  file.write("export AZMON_RS_PROM_K8S_SERVICES=#{kubernetesServices}\n")
  file.write("export AZMON_RS_PROM_URLS=#{urls}\n")
  file.write("export AZMON_RS_PROM_MONITOR_PODS=#{monitorKubernetesPods}\n")
  # Close file after writing all environment variables
  file.close
  puts "****************End Prometheus Config Processing********************"
else
  puts "config::error::Exception while opening file for writing prometheus  replicaset config environment variables"
  puts "****************End Prometheus Config Processing********************"
end

          end
        rescue => errorStr
          # error handling code
        end
    elsif controller.casecmp(@daemonset) == 0 && !parsedConfig[:prometheus_data_collection_settings][:node].nil?
        #Get prometheus daemonset custom config settings
        begin
          interval = parsedConfig[:prometheus_data_collection_settings][:node][:interval]
          fieldPass = parsedConfig[:prometheus_data_collection_settings][:node][:fieldpass]
          fieldDrop = parsedConfig[:prometheus_data_collection_settings][:node][:fielddrop]
          urls = parsedConfig[:prometheus_data_collection_settings][:node][:urls]

          if checkForType(interval, String) 
            && checkForTypeArray(fieldPass, String)
            && checkForTypeArray(fieldDrop, String)
            && checkForTypeArray(urls, String)

            # Write the settings to file, so that they can be set as environment variables
file = File.open("prom_config_env_var", "w")

if !file.nil?
  file.write("export AZMON_DS_PROM_INTERVAL=#{interval}\n")
  file.write("export AZMON_DS_PROM_FIELDPASS=\"#{fieldPass}\"\n")
  file.write("export AZMON_DS_PROM_FIELDDROP=#{fieldDrop}\n")
  file.write("export AZMON_DS_PROM_URLS=#{urls}\n")
  # Close file after writing all environment variables
  file.close
  puts "****************End Prometheus Config Processing********************"
else
  puts "config::error::Exception while opening file for writing prometheus daemonset config environment variables"
  puts "****************End Prometheus Config Processing********************"
end

          end
        rescue => errorStr
          # error handling code
        end
          end
        end
      end

    end
  end

@promConfigSchemaVersion = ENV["AZMON_AGENT_PROM_CFG_SCHEMA_VERSION"]
puts "****************Start Prometheus Config Processing********************"
if !@promConfigSchemaVersion.nil? && !@promConfigSchemaVersion.empty? && @promConfigSchemaVersion.strip.casecmp("v1") == 0 #note v1 is the only supported schema version , so hardcoding it
  promConfigMapSettings = parseConfigMap
  if !promConfigMapSettings.nil?
    populateSettingValuesFromConfigMap(promConfigMapSettings)
  end
else
  if (File.file?(@promConfigMapMountPath))
    puts "config::unsupported/missing config schema version for prometheus config - '#{@promConfigSchemaVersion}' , using defaults"
  end
  # @excludePath = "*_kube-system_*.log"
end

# Write the settings to file, so that they can be set as environment variables
file = File.open("prom_config_env_var", "w")

if !file.nil?
  # This will be used in td-agent-bit.conf file to filter out logs
  if (!@collectStdoutLogs && !@collectStderrLogs)
    #Stop log tailing completely
    @logTailPath = "/opt/nolog*.log"
    @logExclusionRegexPattern = "stdout|stderr"
  elsif !@collectStdoutLogs
    @logExclusionRegexPattern = "stdout"
  elsif !@collectStderrLogs
    @logExclusionRegexPattern = "stderr"
  end
  file.write("export AZMON_COLLECT_STDOUT_LOGS=#{@collectStdoutLogs}\n")
  file.write("export AZMON_LOG_TAIL_PATH=#{@logTailPath}\n")
  file.write("export AZMON_LOG_EXCLUSION_REGEX_PATTERN=\"#{@logExclusionRegexPattern}\"\n")
  file.write("export AZMON_STDOUT_EXCLUDED_NAMESPACES=#{@stdoutExcludeNamespaces}\n")
  file.write("export AZMON_COLLECT_STDERR_LOGS=#{@collectStderrLogs}\n")
  file.write("export AZMON_STDERR_EXCLUDED_NAMESPACES=#{@stderrExcludeNamespaces}\n")
  file.write("export AZMON_CLUSTER_COLLECT_ENV_VAR=#{@collectClusterEnvVariables}\n")
  file.write("export AZMON_CLUSTER_LOG_TAIL_EXCLUDE_PATH=#{@excludePath}\n")
  # Close file after writing all environment variables
  file.close
  puts "Both stdout & stderr log collection are turned off for namespaces: '#{@excludePath}' "
  puts "****************End Config Processing********************"
else
  puts "config::error::Exception while opening file for writing prometheus config environment variables"
  puts "****************End Prometheus Config Processing********************"
end
