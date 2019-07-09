#!/usr/local/bin/ruby

require_relative "tomlrb"
require "fileutils"

@promConfigMapMountPath = "/etc/config/settings/prometheus-data-collection-settings"
@replicaset = "replicaset"
@daemonset = "daemonset"
@configSchemaVersion = ""
@defaultDsInterval = "1m"
@defaultDsPromUrls = []
@defaultDsFieldPass = []
@defaultDsFieldDrop = []
@defaultRsInterval = "1m"
@defaultRsPromUrls = []
@defaultRsFieldPass = []
@defaultRsFieldDrop = []
@defaultRsK8sServices = []
@defaultRsMonitorPods = false

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
      return nil
    end
  rescue => errorStr
    puts "config::error::Exception while parsing toml config file for prometheus config: #{errorStr}, using defaults"
    return nil
  end
end

def checkForTypeArray(arrayValue, arrayType)
  if (arrayValue.nil? || (arrayValue.kind_of?(Array) && arrayValue.length > 0 && arrayValue[0].kind_of?(arrayType)))
    return true
  else
    return false
  end
end

def checkForType(variable, varType)
  if variable.nil? || variable.kind_of?(varType)
    return true
  else
    return false
  end
end

# Use the ruby structure created after config parsing to set the right values to be used as environment variables
def populateSettingValuesFromConfigMap(parsedConfig)
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
             !monitorKubernetesPods.nil? && (!!monitorKubernetesPods == monitorKubernetesPods) #Checking for Boolean type, since 'Boolean' is not defined as a type in ruby
            puts "config::Successfully passed typecheck for config settings for replicaset"
            #if setting is nil assign default values
            interval = (interval.nil?) ? @defaultRsInterval : interval
            fieldPass = (fieldPass.nil?) ? @defaultRsFieldPass : fieldPass
            fieldDrop = (fieldDrop.nil?) ? @defaultRsFieldDrop : fieldDrop
            kubernetesServices = (kubernetesServices.nil?) ? @defaultRsK8sServices : kubernetesServices
            urls = (urls.nil?) ? @defaultRsPromUrls : urls
            monitorKubernetesPods = (kubernetesServices.nil?) ? @defaultRsMonitorPods : monitorKubernetesPods

            file_name = "/opt/telegraf-test-rs.conf"
            # Copy the telegraf config file to a temp file to run telegraf in test mode with this config
            FileUtils.cp("/etc/opt/microsoft/docker-cimprov/telegraf-rs.conf", file_name)

            puts "config::Starting to substitute the placeholders in telegraf conf copy file for replicaset"
            #Replace the placeholder config values with values from custom config
            text = File.read(file_name)
            new_contents = text.gsub("$AZMON_RS_PROM_INTERVAL", interval)
            new_contents = new_contents.gsub("$AZMON_RS_PROM_FIELDPASS", ((fieldPass.length > 0) ? ("[\"" + fieldPass.join("\",\"") + "\"]") : "[]"))
            new_contents = new_contents.gsub("$AZMON_RS_PROM_FIELDDROP", ((fieldDrop.length > 0) ? ("[\"" + fieldDrop.join("\",\"") + "\"]") : "[]"))
            new_contents = new_contents.gsub("$AZMON_RS_PROM_URLS", ((urls.length > 0) ? ("[\"" + urls.join("\",\"") + "\"]") : "[]"))
            new_contents = new_contents.gsub("$AZMON_RS_PROM_K8S_SERVICES", ((kubernetesServices.length > 0) ? ("[\"" + kubernetesServices.join("\",\"") + "\"]") : "[]"))
            new_contents = new_contents.gsub("$AZMON_RS_PROM_MONITOR_PODS", (monitorKubernetesPods ? "true" : "false"))
            File.open(file_name, "w") { |file| file.puts new_contents }
            puts "config::Successfully substituted the placeholders in telegraf conf file for replicaset"
            #Set environment variables for telemetry
            file = File.open("telemetry_prom_config_env_var", "w")
            if !file.nil?
              file.write("export TELEMETRY_RS_PROM_INTERVAL=\"#{interval}\"\n")
              #Setting array lengths as environment variables for telemetry purposes
              file.write("export TELEMETRY_RS_PROM_FIELDPASS_LENGTH=\"#{fieldPass.length}\"\n")
              file.write("export TELEMETRY_RS_PROM_FIELDDROP_LENGTH=\"#{fieldDrop.length}\"\n")
              file.write("export TELEMETRY_RS_PROM_K8S_SERVICES_LENGTH=#{kubernetesServices.length}\n")
              file.write("export TELEMETRY_RS_PROM_URLS_LENGTH=#{urls.length}\n")
              file.write("export TELEMETRY_RS_PROM_MONITOR_PODS=\"#{monitorKubernetesPods}\"\n")
              # Close file after writing all environment variables
              file.close
              puts "config::Successfully created telemetry file for replicaset"
            end
          else
            puts "config::Typecheck failed for prometheus config settings for replicaset, using defaults"
          end # end of type check condition
        rescue => errorStr
          puts "config::error::Exception while parsing config file for prometheus config for replicaset: #{errorStr}, using defaults"
          setRsPromDefaults
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

            #if setting is nil assign default values
            interval = (interval.nil?) ? @defaultDsInterval : interval
            fieldPass = (fieldPass.nil?) ? @defaultDsFieldPass : fieldPass
            fieldDrop = (fieldDrop.nil?) ? @defaultDsFieldDrop : fieldDrop
            urls = (urls.nil?) ? @defaultDsPromUrls : urls

            file_name = "/opt/telegraf-test.conf"
            # Copy the telegraf config file to a temp file to run telegraf in test mode with this config
            FileUtils.cp("/etc/opt/microsoft/docker-cimprov/telegraf.conf", file_name)

            puts "config::Starting to substitute the placeholders in telegraf conf copy file for daemonset"
            #Replace the placeholder config values with values from custom config
            text = File.read(file_name)
            new_contents = text.gsub("$AZMON_DS_PROM_INTERVAL", interval)
            new_contents = new_contents.gsub("$AZMON_DS_PROM_FIELDPASS", ((fieldPass.length > 0) ? ("[\"" + fieldPass.join("\",\"") + "\"]") : "[]"))
            new_contents = new_contents.gsub("$AZMON_DS_PROM_FIELDDROP", ((fieldDrop.length > 0) ? ("[\"" + fieldDrop.join("\",\"") + "\"]") : "[]"))
            new_contents = new_contents.gsub("$AZMON_DS_PROM_URLS", ((urls.length > 0) ? ("[\"" + urls.join("\",\"") + "\"]") : "[]"))
            File.open(file_name, "w") { |file| file.puts new_contents }
            puts "config::Successfully substituted the placeholders in telegraf conf file for daemonset"

            #Set environment variables for telemetry
            file = File.open("telemetry_prom_config_env_var", "w")
            if !file.nil?
              file.write("export TELEMETRY_DS_PROM_INTERVAL=\"#{interval}\"\n")
              #Setting array lengths as environment variables for telemetry purposes
              file.write("export TELEMETRY_DS_PROM_FIELDPASS_LENGTH=\"#{fieldPass.length}\"\n")
              file.write("export TELEMETRY_DS_PROM_FIELDDROP_LENGTH=\"#{fieldDrop.length}\"\n")
              file.write("export TELEMETRY_DS_PROM_URLS_LENGTH=#{urls.length}\n")
              # Close file after writing all environment variables
              file.close
              puts "config::Successfully created telemetry file for daemonset"
            end
          else
            puts "config::Typecheck failed for prometheus config settings for daemonset, using defaults"
          end # end of type check condition
        rescue => errorStr
          puts "config::error::Exception while parsing config file for prometheus config for daemonset: #{errorStr}, using defaults"
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
  else
    puts "config::No configmap mounted for prometheus custom config, using defaults"
  end
end
puts "****************End Prometheus Config Processing********************"
