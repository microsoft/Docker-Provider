#!/usr/local/bin/ruby

#this should be require relative in Linux and require in windows, since it is a gem install on windows
@os_type = ENV["OS_TYPE"]
require "tomlrb"

require_relative "ConfigParseErrorLogger"
require "fileutils"

@promConfigMapMountPath = "/etc/config/settings/prometheus-data-collection-settings"
@replicaset = "replicaset"
@daemonset = "daemonset"
@promSideCar = "prometheussidecar"
@windows = "windows"
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
# @defaultRsMonitorPods = false
@defaultCustomPrometheusInterval = "1m"
@defaultCustomPrometheusFieldPass = []
@defaultCustomPrometheusFieldDrop = []
@defaultCustomPrometheusMonitorPods = false
@defaultCustomPrometheusLabelSelectors = ""
@defaultCustomPrometheusFieldSelectors = ""

#Configurations to be used for the auto-generated input prometheus plugins for namespace filtering
@metricVersion = 2
@monitorKubernetesPodsVersion = 2
@urlTag = "scrapeUrl"
@bearerToken = "/var/run/secrets/kubernetes.io/serviceaccount/token"
@responseTimeout = "15s"
@tlsCa = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
@insecureSkipVerify = true

# Checking to see if this is the daemonset or replicaset to parse config accordingly
@controller = ENV["CONTROLLER_TYPE"]
@containerType = ENV["CONTAINER_TYPE"]
@sidecarScrapingEnabled = ENV["SIDECAR_SCRAPING_ENABLED"]

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
    ConfigParseErrorLogger.logError("Exception while parsing config map for prometheus config: #{errorStr}, using defaults, please check config map for errors")
    return nil
  end
end

def checkForTypeArray(arrayValue, arrayType)
  if (arrayValue.nil? || (arrayValue.kind_of?(Array) && ((arrayValue.length == 0) || (arrayValue.length > 0 && arrayValue[0].kind_of?(arrayType)))))
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

def replaceDefaultMonitorPodSettings(new_contents, monitorKubernetesPods, kubernetesLabelSelectors, kubernetesFieldSelectors)
  begin
    puts "config::Starting to substitute the placeholders in telegraf conf copy file with no namespace filters"
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS", ("monitor_kubernetes_pods = #{monitorKubernetesPods}"))
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_SCRAPE_SCOPE", ("pod_scrape_scope = \"#{(@controller.casecmp(@replicaset) == 0) ? "cluster" : "node"}\""))
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_PLUGINS_WITH_NAMESPACE_FILTER", "")
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_LABEL_SELECTOR", ("kubernetes_label_selector = \"#{kubernetesLabelSelectors}\""))
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_FIELD_SELECTOR", ("kubernetes_field_selector = \"#{kubernetesFieldSelectors}\""))
  rescue => errorStr
    puts "Exception while replacing default pod monitor settings for custom prometheus scraping: #{errorStr}"
  end
  return new_contents
end

def createPrometheusPluginsWithNamespaceSetting(monitorKubernetesPods, monitorKubernetesPodsNamespaces, new_contents, interval, fieldPassSetting, fieldDropSetting, kubernetesLabelSelectors, kubernetesFieldSelectors)
  begin
    puts "config::Starting to substitute the placeholders in telegraf conf copy file with namespace filters"

    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS", "# Commenting this out since new plugins will be created per namespace\n  # $AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS")
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_LABEL_SELECTOR", "# Commenting this out since new plugins will be created per namespace\n  # $AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_LABEL_SELECTOR")
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_FIELD_SELECTOR", "# Commenting this out since new plugins will be created per namespace\n  # $AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_FIELD_SELECTOR")
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_SCRAPE_SCOPE", "# Commenting this out since new plugins will be created per namespace\n  # $AZMON_TELEGRAF_CUSTOM_PROM_SCRAPE_SCOPE")

    pluginConfigsWithNamespaces = ""
    monitorKubernetesPodsNamespaces.each do |namespace|
      if !namespace.nil?
        #Stripping namespaces to remove leading and trailing whitespaces
        namespace.strip!
        if namespace.length > 0
          pluginConfigsWithNamespaces += "\n[[inputs.prometheus]]
  interval = \"#{interval}\"
  monitor_kubernetes_pods = true
  pod_scrape_scope = \"#{(@controller.casecmp(@replicaset) == 0) ? "cluster" : "node"}\"
  monitor_kubernetes_pods_namespace = \"#{namespace}\"
  kubernetes_label_selector = \"#{kubernetesLabelSelectors}\"
  kubernetes_field_selector = \"#{kubernetesFieldSelectors}\"
  fieldpass = #{fieldPassSetting}
  fielddrop = #{fieldDropSetting}
  metric_version = #{@metricVersion}
  url_tag = \"#{@urlTag}\"
  bearer_token = \"#{@bearerToken}\"
  response_timeout = \"#{@responseTimeout}\"
  tls_ca = \"#{@tlsCa}\"
  insecure_skip_verify = #{@insecureSkipVerify}\n"
        end
      end
    end
    new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_PLUGINS_WITH_NAMESPACE_FILTER", pluginConfigsWithNamespaces)
    return new_contents
  rescue => errorStr
    puts "Exception while creating prometheus input plugins to filter namespaces for custom prometheus: #{errorStr}, using defaults"
    replaceDefaultMonitorPodSettings(new_contents, monitorKubernetesPods, kubernetesLabelSelectors, kubernetesFieldSelectors)
  end
end

# Use the ruby structure created after config parsing to set the right values to be used as environment variables
def populateSettingValuesFromConfigMap(parsedConfig)
  if !@controller.nil?
    if !parsedConfig.nil? && !parsedConfig[:prometheus_data_collection_settings].nil?
      if @controller.casecmp(@replicaset) == 0 && !parsedConfig[:prometheus_data_collection_settings][:cluster].nil?
        #Get prometheus replicaset custom config settings
        begin
          interval = parsedConfig[:prometheus_data_collection_settings][:cluster][:interval]
          fieldPass = parsedConfig[:prometheus_data_collection_settings][:cluster][:fieldpass]
          fieldDrop = parsedConfig[:prometheus_data_collection_settings][:cluster][:fielddrop]
          urls = parsedConfig[:prometheus_data_collection_settings][:cluster][:urls]
          kubernetesServices = parsedConfig[:prometheus_data_collection_settings][:cluster][:kubernetes_services]

          # Remove below 4 lines after phased rollout
          monitorKubernetesPods = parsedConfig[:prometheus_data_collection_settings][:cluster][:monitor_kubernetes_pods]
          monitorKubernetesPodsNamespaces = parsedConfig[:prometheus_data_collection_settings][:cluster][:monitor_kubernetes_pods_namespaces]
          kubernetesLabelSelectors = parsedConfig[:prometheus_data_collection_settings][:cluster][:kubernetes_label_selector]
          kubernetesFieldSelectors = parsedConfig[:prometheus_data_collection_settings][:cluster][:kubernetes_field_selector]

          # Check for the right datatypes to enforce right setting values
          if checkForType(interval, String) &&
             checkForTypeArray(fieldPass, String) &&
             checkForTypeArray(fieldDrop, String) &&
             checkForTypeArray(kubernetesServices, String) &&
             checkForTypeArray(urls, String) &&
             # Remove below check after phased rollout
             checkForType(kubernetesLabelSelectors, String) &&
             checkForType(kubernetesFieldSelectors, String) &&
             (monitorKubernetesPods.nil? || (!monitorKubernetesPods.nil? && (!!monitorKubernetesPods == monitorKubernetesPods))) # Checking for Boolean type, since 'Boolean' is not defined as a type in ruby
            puts "config::Successfully passed typecheck for config settings for replicaset"
            #if setting is nil assign default values
            interval = (interval.nil?) ? @defaultRsInterval : interval
            fieldPass = (fieldPass.nil?) ? @defaultRsFieldPass : fieldPass
            fieldDrop = (fieldDrop.nil?) ? @defaultRsFieldDrop : fieldDrop
            kubernetesServices = (kubernetesServices.nil?) ? @defaultRsK8sServices : kubernetesServices
            urls = (urls.nil?) ? @defaultRsPromUrls : urls
            # Remove below lines after phased rollout
            monitorKubernetesPods = (monitorKubernetesPods.nil?) ? @defaultRsMonitorPods : monitorKubernetesPods
            kubernetesLabelSelectors = (kubernetesLabelSelectors.nil?) ? @defaultCustomPrometheusLabelSelectors : kubernetesLabelSelectors
            kubernetesFieldSelectors = (kubernetesFieldSelectors.nil?) ? @defaultCustomPrometheusFieldSelectors : kubernetesFieldSelectors

            file_name = "/opt/telegraf-test-rs.conf"
            # Copy the telegraf config file to a temp file to run telegraf in test mode with this config
            FileUtils.cp("/etc/opt/microsoft/docker-cimprov/telegraf-rs.conf", file_name)

            puts "config::Starting to substitute the placeholders in telegraf conf copy file for replicaset"
            #Replace the placeholder config values with values from custom config
            text = File.read(file_name)
            new_contents = text.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_INTERVAL", interval)
            fieldPassSetting = (fieldPass.length > 0) ? ("[\"" + fieldPass.join("\",\"") + "\"]") : "[]"
            new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_FIELDPASS", fieldPassSetting)
            fieldDropSetting = (fieldDrop.length > 0) ? ("[\"" + fieldDrop.join("\",\"") + "\"]") : "[]"
            new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_FIELDDROP", fieldDropSetting)
            new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_URLS", ((urls.length > 0) ? ("[\"" + urls.join("\",\"") + "\"]") : "[]"))
            new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_K8S_SERVICES", ((kubernetesServices.length > 0) ? ("[\"" + kubernetesServices.join("\",\"") + "\"]") : "[]"))

            # Check to see if monitor_kubernetes_pods is set to true with a valid setting for monitor_kubernetes_namespaces to enable scraping for specific namespaces
            # Adding nil check here as well since checkForTypeArray returns true even if setting is nil to accomodate for other settings to be able -
            # - to use defaults in case of nil settings
            # Remove below block after phased rollout
            if (@sidecarScrapingEnabled.nil? || (!@sidecarScrapingEnabled.nil? && (@sidecarScrapingEnabled.casecmp("false") == 0)))
              monitorKubernetesPodsNSConfig = []
              if monitorKubernetesPods && !monitorKubernetesPodsNamespaces.nil? && checkForTypeArray(monitorKubernetesPodsNamespaces, String)
                # Adding a check to see if an empty array is passed for kubernetes namespaces
                if (monitorKubernetesPodsNamespaces.length > 0)
                  new_contents = createPrometheusPluginsWithNamespaceSetting(monitorKubernetesPods, monitorKubernetesPodsNamespaces, new_contents, interval, fieldPassSetting, fieldDropSetting, kubernetesLabelSelectors, kubernetesFieldSelectors)
                  monitorKubernetesPodsNamespacesLength = monitorKubernetesPodsNamespaces.length
                  monitorKubernetesPodsNSConfig = monitorKubernetesPodsNamespaces
                else
                  new_contents = replaceDefaultMonitorPodSettings(new_contents, monitorKubernetesPods, kubernetesLabelSelectors, kubernetesFieldSelectors)
                  monitorKubernetesPodsNamespacesLength = 0
                end
              else
                new_contents = replaceDefaultMonitorPodSettings(new_contents, monitorKubernetesPods, kubernetesLabelSelectors, kubernetesFieldSelectors)
                monitorKubernetesPodsNamespacesLength = 0
              end
              # Label and field selectors are passed as strings. For field selectors, split by commas to get the number of key-value pairs.
              # Label selectors can be formatted as "app in (app1, app2, app3)", so split by commas only outside parentheses to get the number of key-value pairs.
              kubernetesLabelSelectorsLength = kubernetesLabelSelectors.split(/,\s*(?=[^()]*(?:\(|$))/).length
              kubernetesFieldSelectorsLength = kubernetesFieldSelectors.split(",").length
            end

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
              # Remove below block after phased rollout
              if (@sidecarScrapingEnabled.nil? || (!@sidecarScrapingEnabled.nil? && (@sidecarScrapingEnabled.casecmp("false") == 0)))
                file.write("export TELEMETRY_RS_PROM_MONITOR_PODS=\"#{monitorKubernetesPods}\"\n")
                file.write("export TELEMETRY_RS_PROM_MONITOR_PODS_NS_LENGTH=\"#{monitorKubernetesPodsNamespacesLength}\"\n")
                file.write("export TELEMETRY_RS_PROM_LABEL_SELECTOR_LENGTH=\"#{kubernetesLabelSelectorsLength}\"\n")
                file.write("export TELEMETRY_RS_PROM_FIELD_SELECTOR_LENGTH=\"#{kubernetesFieldSelectorsLength}\"\n")
              end

              # Close file after writing all environment variables
              file.close
              puts "config::Successfully created telemetry file for replicaset"
            end
          else
            ConfigParseErrorLogger.logError("Typecheck failed for prometheus config settings for replicaset, using defaults, please use right types for all settings")
          end # end of type check condition
        rescue => errorStr
          ConfigParseErrorLogger.logError("Exception while parsing config file for prometheus config for replicaset: #{errorStr}, using defaults")
          setRsPromDefaults
          puts "****************End Prometheus Config Processing********************"
        end
      elsif @controller.casecmp(@daemonset) == 0 &&
            ((!@containerType.nil? && @containerType.casecmp(@promSideCar) == 0) ||
             (!@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0) && @sidecarScrapingEnabled.strip.casecmp("true") == 0) &&
            !parsedConfig[:prometheus_data_collection_settings][:cluster].nil?
        #Get prometheus custom config settings for monitor kubernetes pods
        begin
          interval = parsedConfig[:prometheus_data_collection_settings][:cluster][:interval]
          fieldPass = parsedConfig[:prometheus_data_collection_settings][:cluster][:fieldpass]
          fieldDrop = parsedConfig[:prometheus_data_collection_settings][:cluster][:fielddrop]
          monitorKubernetesPods = parsedConfig[:prometheus_data_collection_settings][:cluster][:monitor_kubernetes_pods]
          monitorKubernetesPodsNamespaces = parsedConfig[:prometheus_data_collection_settings][:cluster][:monitor_kubernetes_pods_namespaces]
          kubernetesLabelSelectors = parsedConfig[:prometheus_data_collection_settings][:cluster][:kubernetes_label_selector]
          kubernetesFieldSelectors = parsedConfig[:prometheus_data_collection_settings][:cluster][:kubernetes_field_selector]

          # Check for the right datattypes to enforce right setting values
          if checkForType(interval, String) &&
             checkForType(kubernetesLabelSelectors, String) &&
             checkForType(kubernetesFieldSelectors, String) &&
             checkForTypeArray(fieldPass, String) &&
             checkForTypeArray(fieldDrop, String) &&
             (monitorKubernetesPods.nil? || (!monitorKubernetesPods.nil? && (!!monitorKubernetesPods == monitorKubernetesPods))) #Checking for Boolean type, since 'Boolean' is not defined as a type in ruby
            puts "config::Successfully passed typecheck for config settings for custom prometheus scraping"
            #if setting is nil assign default values
            interval = (interval.nil?) ? @defaultCustomPrometheusInterval : interval
            fieldPass = (fieldPass.nil?) ? @defaultCustomPrometheusFieldPass : fieldPass
            fieldDrop = (fieldDrop.nil?) ? @defaultCustomPrometheusFieldDrop : fieldDrop
            monitorKubernetesPods = (monitorKubernetesPods.nil?) ? @defaultCustomPrometheusMonitorPods : monitorKubernetesPods
            kubernetesLabelSelectors = (kubernetesLabelSelectors.nil?) ? @defaultCustomPrometheusLabelSelectors : kubernetesLabelSelectors
            kubernetesFieldSelectors = (kubernetesFieldSelectors.nil?) ? @defaultCustomPrometheusFieldSelectors : kubernetesFieldSelectors

            if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
              file_name = "/etc/telegraf/telegraf.conf"
            else
              file_name = "/opt/telegraf-test-prom-side-car.conf"
              # Copy the telegraf config file to a temp file to run telegraf in test mode with this config
              FileUtils.cp("/etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf", file_name)
            end
            puts "config::Starting to substitute the placeholders in telegraf conf copy file for linux or conf file for windows for custom prometheus scraping"
            #Replace the placeholder config values with values from custom config
            text = File.read(file_name)
            new_contents = text.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_INTERVAL", interval)
            fieldPassSetting = (fieldPass.length > 0) ? ("[\"" + fieldPass.join("\",\"") + "\"]") : "[]"
            new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_FIELDPASS", fieldPassSetting)
            fieldDropSetting = (fieldDrop.length > 0) ? ("[\"" + fieldDrop.join("\",\"") + "\"]") : "[]"
            new_contents = new_contents.gsub("$AZMON_TELEGRAF_CUSTOM_PROM_FIELDDROP", fieldDropSetting)

            # Check to see if monitor_kubernetes_pods is set to true with a valid setting for monitor_kubernetes_namespaces to enable scraping for specific namespaces
            # Adding nil check here as well since checkForTypeArray returns true even if setting is nil to accomodate for other settings to be able -
            # - to use defaults in case of nil settings
            monitorKubernetesPodsNSConfig = []
            if monitorKubernetesPods && !monitorKubernetesPodsNamespaces.nil? && checkForTypeArray(monitorKubernetesPodsNamespaces, String)
              # Adding a check to see if an empty array is passed for kubernetes namespaces
              if (monitorKubernetesPodsNamespaces.length > 0)
                new_contents = createPrometheusPluginsWithNamespaceSetting(monitorKubernetesPods, monitorKubernetesPodsNamespaces, new_contents, interval, fieldPassSetting, fieldDropSetting, kubernetesLabelSelectors, kubernetesFieldSelectors)
                monitorKubernetesPodsNamespacesLength = monitorKubernetesPodsNamespaces.length
                monitorKubernetesPodsNSConfig = monitorKubernetesPodsNamespaces
              else
                new_contents = replaceDefaultMonitorPodSettings(new_contents, monitorKubernetesPods, kubernetesLabelSelectors, kubernetesFieldSelectors)
                monitorKubernetesPodsNamespacesLength = 0
              end
            else
              new_contents = replaceDefaultMonitorPodSettings(new_contents, monitorKubernetesPods, kubernetesLabelSelectors, kubernetesFieldSelectors)
              monitorKubernetesPodsNamespacesLength = 0
            end

            # Label and field selectors are passed as strings. For field selectors, split by commas to get the number of key-value pairs.
            # Label selectors can be formatted as "app in (app1, app2, app3)", so split by commas only outside parentheses to get the number of key-value pairs.
            kubernetesLabelSelectorsLength = kubernetesLabelSelectors.split(/,\s*(?=[^()]*(?:\(|$))/).length
            kubernetesFieldSelectorsLength = kubernetesFieldSelectors.split(",").length

            File.open(file_name, "w") { |file| file.puts new_contents }
            puts "config::Successfully substituted the placeholders in telegraf conf file for custom prometheus scraping"
            #Set environment variables for configuration and telemetry in the sidecar container
            if (!@containerType.nil? && @containerType.casecmp(@promSideCar) == 0)
              file = File.open("telemetry_prom_config_env_var", "w")
              if !file.nil?
                #Setting array lengths as environment variables for telemetry purposes
                file.write("export TELEMETRY_CUSTOM_PROM_MONITOR_PODS=\"#{monitorKubernetesPods}\"\n")
                file.write("export TELEMETRY_CUSTOM_PROM_MONITOR_PODS_NS_LENGTH=\"#{monitorKubernetesPodsNamespacesLength}\"\n")
                file.write("export TELEMETRY_CUSTOM_PROM_LABEL_SELECTOR_LENGTH=\"#{kubernetesLabelSelectorsLength}\"\n")
                file.write("export TELEMETRY_CUSTOM_PROM_FIELD_SELECTOR_LENGTH=\"#{kubernetesFieldSelectorsLength}\"\n")

                # Close file after writing all environment variables
                file.close
                puts "config::Successfully created telemetry file for prometheus sidecar"
              end
            end
          else
            ConfigParseErrorLogger.logError("Typecheck failed for prometheus config settings for prometheus side car, using defaults, please use right types for all settings")
          end # end of type check condition
        rescue => errorStr
          ConfigParseErrorLogger.logError("Exception while parsing config file for prometheus config for promethues side car: #{errorStr}, using defaults")
          puts "****************End Prometheus Config Processing********************"
        end
      elsif @controller.casecmp(@daemonset) == 0 && !parsedConfig[:prometheus_data_collection_settings][:node].nil?
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
            ConfigParseErrorLogger.logError("Typecheck failed for prometheus config settings for daemonset, using defaults, please use right types for all settings")
          end # end of type check condition
        rescue => errorStr
          ConfigParseErrorLogger.logError("Exception while parsing config file for prometheus config for daemonset: #{errorStr}, using defaults, please check correctness of configmap")
          puts "****************End Prometheus Config Processing********************"
        end
      end # end of controller type check
    end
  else
    ConfigParseErrorLogger.logError("Controller undefined while processing prometheus config, using defaults")
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
    ConfigParseErrorLogger.logError("config::unsupported/missing config schema version - '#{@configSchemaVersion}' , using defaults, please use supported version")
  else
    puts "config::No configmap mounted for prometheus custom config, using defaults"
  end
end
puts "****************End Prometheus Config Processing********************"
