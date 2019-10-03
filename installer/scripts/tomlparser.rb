#!/usr/local/bin/ruby

require_relative "tomlrb"
require_relative "ConfigParseErrorLogger"
require "json"

@log_settings_config_map_mount_path = "/etc/config/settings/log-data-collection-settings"
@agent_settings_config_map_mount_path = "/etc/config/settings/agent-settings"
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
@excludePath = "*.csv2" #some invalid path
@enable_health_model = false

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap(path)
  begin
    # Check to see if config map is created
    if (File.file?(path))
      puts "config::configmap container-azm-ms-agentconfig for settings mounted, parsing values from #{path}"
      parsedConfig = Tomlrb.load_file(path, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map from #{path}"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for settings not mounted, using defaults for #{path}"
      @excludePath = "*_kube-system_*.log"
      return nil
    end
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while parsing config map for log collection/env variable settings: #{errorStr}, using defaults, please check config map for errors")
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
      ConfigParseErrorLogger.logError("Exception while reading config map settings for stdout log collection - #{errorStr}, using defaults, please check config map for errors")
    end

    #Get stderr log config settings
    begin
      if !parsedConfig[:log_collection_settings][:stderr].nil? && !parsedConfig[:log_collection_settings][:stderr][:enabled].nil?
        @collectStderrLogs = parsedConfig[:log_collection_settings][:stderr][:enabled]
        puts "config::Using config map setting for stderr log collection"
        stderrNamespaces = parsedConfig[:log_collection_settings][:stderr][:exclude_namespaces]
        stdoutNamespaces = Array.new
        #Clearing it, so that it can be overridden with the config map settings
        @stderrExcludeNamespaces.clear
        if @collectStderrLogs && !stderrNamespaces.nil?
          if stderrNamespaces.kind_of?(Array)
            if !@stdoutExcludeNamespaces.nil? && !@stdoutExcludeNamespaces.empty?
              stdoutNamespaces = @stdoutExcludeNamespaces.split(",")
            end
            # Checking only for the first element to be string because toml enforces the arrays to contain elements of same type
            if stderrNamespaces.length > 0 && stderrNamespaces[0].kind_of?(String)
              stderrNamespaces.each do |namespace|
                if @stderrExcludeNamespaces.empty?
                  # To not append , for the first element
                  @stderrExcludeNamespaces.concat(namespace)
                else
                  @stderrExcludeNamespaces.concat("," + namespace)
                end
                # Add this namespace to excludepath if both stdout & stderr are excluded for this namespace, to ensure are optimized and dont tail these files at all
                if stdoutNamespaces.include? namespace
                  @excludePath.concat("," + "*_" + namespace + "_*.log")
                end
              end
              puts "config::Using config map setting for stderr log collection to exclude namespace"
            end
          end
        end
      end
    rescue => errorStr
      ConfigParseErrorLogger.logError("Exception while reading config map settings for stderr log collection - #{errorStr}, using defaults, please check config map for errors")
    end

    #Get environment variables log config settings
    begin
      if !parsedConfig[:log_collection_settings][:env_var].nil? && !parsedConfig[:log_collection_settings][:env_var][:enabled].nil?
        @collectClusterEnvVariables = parsedConfig[:log_collection_settings][:env_var][:enabled]
        puts "config::Using config map setting for cluster level environment variable collection"
      end
    rescue => errorStr
      ConfigParseErrorLogger.logError("Exception while reading config map settings for cluster level environment variable collection - #{errorStr}, using defaults, please check config map for errors")
    end
  end

  begin
    if !parsedConfig.nil? && !parsedConfig[:agent_settings].nil? && !parsedConfig[:agent_settings][:health_model].nil? && !parsedConfig[:agent_settings][:health_model][:enabled].nil?
      @enable_health_model = parsedConfig[:agent_settings][:health_model][:enabled]
    else
      @enable_health_model = false
    end
    puts "enable_health_model = #{@enable_health_model}"
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while reading config map settings for health_model enabled setting - #{errorStr}, using defaults, please check config map for errors")
    @enable_health_model = false
  end
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start Config Processing********************"

if !@configSchemaVersion.nil? && !@configSchemaVersion.empty? && @configSchemaVersion.strip.casecmp("v1") == 0 #note v1 is the only supported schema version , so hardcoding it
  configMapSettings = {}

  #iterate over every *settings file and build a hash of settings
  Dir["/etc/config/settings/*settings"].each { |file|
    puts "Parsing File #{file}"
    settings = parseConfigMap(file)
    if !settings.nil?
      configMapSettings = configMapSettings.merge(settings)
    end
  }

  if !configMapSettings.nil?
    populateSettingValuesFromConfigMap(configMapSettings)
  end
else
  ConfigParseErrorLogger.logError("config::unsupported/missing config schema version - '#{@configSchemaVersion}' , using defaults, please use supported schema version")
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
  #health_model settings
  file.write("export AZMON_CLUSTER_ENABLE_HEALTH_MODEL=#{@enable_health_model}\n")
  # Close file after writing all environment variables
  file.close
  puts "Both stdout & stderr log collection are turned off for namespaces: '#{@excludePath}' "
  puts "****************End Config Processing********************"
else
  puts "Exception while opening file for writing config environment variables"
  puts "****************End Config Processing********************"
end
