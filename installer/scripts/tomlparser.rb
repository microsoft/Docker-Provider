#!/usr/local/bin/ruby

require_relative "tomlrb"

@configMapMountPath = "/etc/config/settings/log-data-collection-settings"
@configVersion = ""
@configSchemaVersion = ""
# Setting default values which will be used in case they are not set in the configmap or if configmap doesnt exist
@collectStdoutLogs = true
@stdoutExcludeNamespaces = "kube-system"
@collectStderrLogs = true
@stderrExcludeNamespaces = "kube-system"
@collectClusterEnvVariables = true
@logTailPath = "/var/log/containers/*.log"
@logExclusionRegexPattern = "(^((?!stdout|stderr).)*$)"
@excludePath = "*.csv2"

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@configMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig for settings mounted, parsing values"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for settings not mounted, using defaults"
      @excludePath = "*_kube-system_*.log"
      return nil
    end
  rescue => errorStr
    puts "config::error::Exception while parsing toml config file: #{errorStr}, using defaults"
    @excludePath = "*_kube-system_*.log"
    return nil
  end
end

# Use the ruby structure created after config parsing to set the right values to be used as environment variables
def populateSettingValuesFromConfigMap(parsedConfig)
  if !parsedConfig.nil? && !parsedConfig[:log_collection_settings].nil?
    #Get stdout log config settings
    begin
      if !parsedConfig[:log_collection_settings][:stdout].nil? && !parsedConfig[:log_collection_settings][:stdout][:enabled].nil?
        @collectStdoutLogs = parsedConfig[:log_collection_settings][:stdout][:enabled]
        puts "config::Using config map setting for stdout log collection"
        stdoutNamespaces = parsedConfig[:log_collection_settings][:stdout][:exclude_namespaces]

        #Clearing it, so that it can be overridden with the config map settings
        @stdoutExcludeNamespaces.clear
        if @collectStdoutLogs && !stdoutNamespaces.nil?
          if stdoutNamespaces.kind_of?(Array)
            # Checking only for the first element to be string because toml enforces the arrays to contain elements of same type
            if stdoutNamespaces.length > 0 && stdoutNamespaces[0].kind_of?(String)
              #Empty the array to use the values from configmap
              stdoutNamespaces.each do |namespace|
                if @stdoutExcludeNamespaces.empty?
                  # To not append , for the first element
                  @stdoutExcludeNamespaces.concat(namespace)
                else
                  @stdoutExcludeNamespaces.concat("," + namespace)
                end
              end
              puts "config::Using config map setting for stdout log collection to exclude namespace"
            end
          end
        end
      end
    rescue => errorStr
      puts "config::error::Exception while reading config settings for stdout log collection - #{errorStr}, using defaults"
    end

    #Get stderr log config settings
    begin
      if !parsedConfig[:log_collection_settings][:stderr].nil? && !parsedConfig[:log_collection_settings][:stderr][:enabled].nil?
        @collectStderrLogs = parsedConfig[:log_collection_settings][:stderr][:enabled]
        puts "config::Using config map setting for stderr log collection"
        stderrNamespaces = parsedConfig[:log_collection_settings][:stderr][:exclude_namespaces]

        #Clearing it, so that it can be overridden with the config map settings
        @stderrExcludeNamespaces.clear
        if @collectStderrLogs && !stderrNamespaces.nil?
          if stderrNamespaces.kind_of?(Array)
            # Checking only for the first element to be string because toml enforces the arrays to contain elements of same type
            if stderrNamespaces.length > 0 && stderrNamespaces[0].kind_of?(String)
              stderrNamespaces.each do |namespace|
                if @stderrExcludeNamespaces.empty?
                  # To not append , for the first element
                  @stderrExcludeNamespaces.concat(namespace)
                else
                  @stderrExcludeNamespaces.concat("," + namespace)
                end
              end
              puts "config::Using config map setting for stderr log collection to exclude namespace"
            end
          end
        end
      end
    rescue => errorStr
      puts "config::error:Exception while reading config settings for stderr log collection - #{errorStr}, using defaults"
    end

    #Get environment variables log config settings
    begin
      if !parsedConfig[:log_collection_settings][:env_var].nil? && !parsedConfig[:log_collection_settings][:env_var][:enabled].nil?
        @collectClusterEnvVariables = parsedConfig[:log_collection_settings][:env_var][:enabled]
        puts "config::Using config map setting for cluster level environment variable collection"
      end
    rescue => errorStr
      puts "config::error::Exception while reading config settings for cluster level environment variable collection - #{errorStr}, using defaults"
    end
  end
end

  @configSchemaVersion = ENV['AZMON_AGENT_CFG_SCHEMA_VERSION']
  if !@configSchemaVersion.nil? && !@configSchemaVersion.empty? && @@configSchemaVersion.strip.casecmp('v1') == 0 #note v1 is the only supported schema version , so hardcoding it
    configMapSettings = parseConfigMap
    if !configMapSettings.nil?
      populateSettingValuesFromConfigMap(configMapSettings)
    end
  else
    puts "config::unsupported config schema version - #{@configSchemaVersion}, using defaults"
    @excludePath = "*_kube-system_*.log"
  end

  # Write the settings to file, so that they can be set as environment variables
  file = File.open("config_env_var", "w")

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
  else
    puts "config::error::Exception while opening file for writing config environment variables"
  end
