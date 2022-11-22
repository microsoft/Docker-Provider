#!/usr/local/bin/ruby

require "tomlrb"

require_relative "ConfigParseErrorLogger"

@configMapMountPath = "./etc/config/settings/hostlogs-settings"
@configSchemaVersion = ""

# configmap settings related to geneva logs config
@genevaEnvironment = ""
@genevaAccount = ""
@genevaNamespace = ""
@genevaConfigVersion = ""
@genevaAuthId = ""
GENEVA_SUPPORTED_ENVIRONMENTS = ["Test", "Stage", "DiagnosticsProd", "FirstpartyProd", "BillingProd", "ExternalProd", "CaMooncake", "CaFairfax", "CaBlackforest"]

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@configMapMountPath))
      puts "config::configmap container-azm-ms-hostlogsconfig for agent settings mounted, parsing values"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-hostlogsconfig for agent settings not mounted, using defaults"
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
    if !parsedConfig.nil? && !parsedConfig[:hostlogs_settings].nil?
      
      geneva_logs_config = parsedConfig[:hostlogs_settings][:geneva_logs_config]
      if !geneva_logs_config.nil?
        puts "config: parsing geneva_logs_config settings"
        genevaEnvironment = geneva_logs_config[:environment]
        genevaAccount = geneva_logs_config[:account]
        genevaNamespace = geneva_logs_config[:namespace]
        genevaConfigVersion = geneva_logs_config[:configversion]
        if !genevaEnvironment.nil? && !genevaAccount.nil? && !genevaNamespace.nil? && !genevaConfigVersion.nil?
          if GENEVA_SUPPORTED_ENVIRONMENTS.include?(genevaEnvironment)
            @genevaEnvironment = genevaEnvironment
            @genevaAccount = genevaAccount
            @genevaNamespace = genevaNamespace
            @genevaConfigVersion = genevaConfigVersion
          else
            puts "config::error:unsupported geneva config environment"
          end
        else
          puts "config::error:invalid geneva logs config"
        end
        genevaAuthId = geneva_logs_config[:authid]
        if !genevaAuthId.nil?
          if genevaAuthId.start_with?("client_id#") || genevaAuthId.start_with?("object_id#") || genevaAuthId.start_with?("mi_res_id#")
            @genevaAuthId = genevaAuthId
          else
            puts "config:error: auth id must be in one of the suppported formats: object_id#<guid> or client_id#<guid> or mi_res_id#<identity resource id>"
          end
        end
        puts "config::info:successfully parsed geneva_logs_config settings"
      end
    end
  rescue => errorStr
    puts "config::error:Exception while reading config settings for agent configuration setting - #{errorStr}, using defaults"
  end
end

# Write the settings to file, so that they can be set as environment variables
def writeEnvScript(filepath)
  file = File.open(filepath, "w")

  if !file.nil?

    if !@genevaEnvironment.empty? && !@genevaAccount.empty? && !@genevaNamespace.empty? && !@genevaConfigVersion.empty? && !@genevaAuthId.empty?
      file.write(get_command_windows("MONITORING_GCS_ENVIRONMENT", @genevaEnvironment))
      file.write(get_command_windows("MONITORING_GCS_ACCOUNT", @genevaAccount))
      file.write(get_command_windows("MONITORING_GCS_NAMESPACE", @genevaNamespace))
      file.write(get_command_windows("MONITORING_CONFIG_VERSION", @genevaConfigVersion))

      authIdParts =  @genevaAuthId.split('#', 2)
      file.write(get_command_windows("MONITORING_MANAGED_ID_IDENTIFIER", authIdParts[0]))
      file.write(get_command_windows("MONITORING_MANAGED_ID_VALUE", authIdParts[1]))

      puts "Using config map value: MONITORING_GCS_ENVIRONMENT = #{@genevaEnvironment}"
      puts "Using config map value: MONITORING_GCS_ACCOUNT = #{@genevaAccount}"
      puts "Using config map value: MONITORING_GCS_NAMESPACE = #{@genevaNamespace}"
      puts "Using config map value: MONITORING_CONFIG_VERSION = #{@genevaConfigVersion}"
      puts "Using config map value: MONITORING_MANAGED_ID_IDENTIFIER = #{authIdParts[0]}"
      puts "Using config map value: MONITORING_MANAGED_ID_VALUE= #{authIdParts[1]}"

    end

    # Close file after writing all environment variables
    file.close
  else
    puts "Exception while opening file for writing config environment variables"
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
  return "[System.Environment]::SetEnvironmentVariable(\"#{env_variable_name}\", \"#{env_variable_value}\", \"Process\")" + "\n" + "[System.Environment]::SetEnvironmentVariable(\"#{env_variable_name}\", \"#{env_variable_value}\", \"Machine\")" + "\n"
end

writeEnvScript("setagentenv.ps1")
puts "****************End Config Processing********************"



