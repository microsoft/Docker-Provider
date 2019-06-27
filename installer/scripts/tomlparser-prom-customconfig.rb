#!/usr/local/bin/ruby

require_relative "tomlrb"

@promConfigMapMountPath = "/etc/config/settings/prometheus-data-collection-settings"
@replicaset = "replicaset"
@daemonset = "daemonset"
# @cnfigVersion = ""
@configSchemaVersion = ""
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

          # Check for the right datattypes to enforce right setting values
          if checkForType(interval, String) &&
             checkForTypeArray(fieldPass, String) &&
             checkForTypeArray(fieldDrop, String) &&
             checkForTypeArray(kubernetesServices, String) &&
             checkForTypeArray(urls, String) &&
             checkForType(monitorKubernetesPods, Boolean)
            puts "config::Successfully passed typecheck for config settings for replicaset"
            # Write the settings to file, so that they can be set as environment variables
            file = File.open("prom_config_env_var", "w")
            if !file.nil?
              file.write("export AZMON_RS_PROM_INTERVAL=#{interval}\n")
              file.write("export AZMON_RS_PROM_FIELDPASS=\"#{fieldPass}\"\n")
              #Setting array lengths as environment variables for telemetry purposes
              file.write("export TELEMETRY_RS_PROM_FIELDPASS_LENGTH=\"#{fieldPass.length}\"\n")
              file.write("export AZMON_RS_PROM_FIELDDROP=#{fieldDrop}\n")
              file.write("export TELEMETRY_RS_PROM_FIELDDROP_LENGTH=\"#{fieldDrop.length}\"\n")
              file.write("export AZMON_RS_PROM_K8S_SERVICES=#{kubernetesServices}\n")
              file.write("export TELEMETRY_RS_PROM_K8S_SERVICES_LENGTH=#{kubernetesServices.length}\n")
              file.write("export AZMON_RS_PROM_URLS=#{urls}\n")
              file.write("export TELEMETRY_RS_PROM_URLS_LENGTH=#{urls.length}\n")
              file.write("export AZMON_RS_PROM_MONITOR_PODS=#{monitorKubernetesPods}\n")
              # Close file after writing all environment variables
              file.close
              puts "config::Successfully created custom config environment variable file for replicaset"

              #Also substitute these values in the test config file for telegraf
              file_name = "telegraf-test-rs.conf"
              text = File.read(file_name)
              new_contents = text.gsub("$AZMON_RS_PROM_INTERVAL", interval)
              new_contents = text.gsub("$AZMON_RS_PROM_FIELDPASS", fieldPass)
              new_contents = text.gsub("$AZMON_RS_PROM_FIELDDROP", fieldDrop)
              new_contents = text.gsub("$AZMON_RS_PROM_URLS", urls)
              new_contents = text.gsub("$AZMON_RS_PROM_K8S_SERVICES", kubernetesServices)
              new_contents = text.gsub("$AZMON_RS_PROM_MONITOR_PODS", monitorKubernetesPods)

              File.open(file_name, "w") { |file| file.puts new_contents }
              puts "config::Successfully replaced the settings in test telegraf config file for replicaset"
            else
              puts "config::error::Exception while opening file for writing prometheus replicaset config environment variables"
              puts "****************End Prometheus Config Processing********************"
            end
          end # end of type check condition
        rescue => errorStr
          puts "config::error::Exception while reading config file for prometheus config for replicaset: #{errorStr}, using defaults"
          puts "****************End Prometheus Config Processing********************"
        end
      elsif controller.casecmp(@daemonset) == 0 && !parsedConfig[:prometheus_data_collection_settings][:node].nil?
        #Get prometheus daemonset custom config settings
        begin
          interval = parsedConfig[:prometheus_data_collection_settings][:node][:interval]
          fieldPass = parsedConfig[:prometheus_data_collection_settings][:node][:fieldpass]
          fieldDrop = parsedConfig[:prometheus_data_collection_settings][:node][:fielddrop]
          urls = parsedConfig[:prometheus_data_collection_settings][:node][:urls]

          # Check for the right datattypes to enforce right setting values
          if checkForType(interval, String) &&
             checkForTypeArray(fieldPass, String) &&
             checkForTypeArray(fieldDrop, String) &&
             checkForTypeArray(urls, String)
            puts "config::Successfully passed typecheck for config settings for daemonset"
            # Write the settings to file, so that they can be set as environment variables
            file = File.open("prom_config_env_var", "w")
            if !file.nil?
              file.write("export AZMON_DS_PROM_INTERVAL=#{interval}\n")
              file.write("export AZMON_DS_PROM_FIELDPASS=\"#{fieldPass}\"\n")
              #Setting array lengths as environment variables for telemetry purposes
              file.write("export TELEMETRY_DS_PROM_FIELDPASS_LENGTH=\"#{fieldPass.length}\"\n")
              file.write("export AZMON_DS_PROM_FIELDDROP=#{fieldDrop}\n")
              file.write("export TELEMETRY_DS_PROM_FIELDDROP_LENGTH=\"#{fieldDrop.length}\"\n")
              file.write("export AZMON_DS_PROM_URLS=#{urls}\n")
              file.write("export TELEMETRY_DS_PROM_URLS_LENGTH=#{urls.length}\n")
              # Close file after writing all environment variables
              file.close
              puts "config::Successfully created custom config environment variable file for daemonset"

              #Also substitute these values in the test config file for telegraf
              file_name = "telegraf-test.conf"
              text = File.read(file_name)
              new_contents = text.gsub("$AZMON_DS_PROM_INTERVAL", interval)
              new_contents = text.gsub("$AZMON_DS_PROM_FIELDPASS", fieldPass)
              new_contents = text.gsub("$AZMON_DS_PROM_FIELDDROP", fieldDrop)
              new_contents = text.gsub("$AZMON_DS_PROM_URLS", urls)
              # To write changes to the file, use:
              File.open(file_name, "w") { |file| file.puts new_contents }
              puts "config::Successfully replaced the settings in test telegraf config file for daemonset"
            else
              puts "config::error::Exception while opening file for writing prometheus daemonset config environment variables"
              puts "****************End Prometheus Config Processing********************"
            end
          end # end of type check condition
        rescue => errorStr
          puts "config::error::Exception while reading config file for prometheus config for daemonset: #{errorStr}, using defaults"
          puts "****************End Prometheus Config Processing********************"
        end
      end # end of controller type check
    end
  else
    puts "config::error:: Controller undefined while processing prometheus config, using defaults"
  end
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start Prometheus Config Processing********************"
if !@configSchemaVersion.nil? && !@configSchemaVersion.empty? && @configSchemaVersion.strip.casecmp("v1") == 0 #note v1 is the only supported schema version , so hardcoding it
  configMapSettings = parseConfigMap
  if !configMapSettings.nil?
    populateSettingValuesFromConfigMap(configMapSettings)
  end
else
  if (File.file?(@promConfigMapMountPath))
    puts "config::unsupported/missing config schema version - '#{@configSchemaVersion}' , using defaults"
  end
end
puts "****************End Prometheus Config Processing********************"
