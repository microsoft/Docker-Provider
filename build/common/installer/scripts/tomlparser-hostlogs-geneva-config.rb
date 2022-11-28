#!/usr/local/bin/ruby

require "tomlrb"
require "json"

require_relative "ConfigParseErrorLogger"

@configMapMountPath = "./etc/config/settings/hostlogs-settings"
@configSchemaVersion = ""

# configmap settings related to geneva logs config
@geneva_account_environment = ""
@geneva_account_name = ""
@geneva_account_namespace = ""
@geneva_logs_config_version = ""
@geneva_gcs_authid = ""
@azure_json_path = "C:\\k\\azure.json"

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
        geneva_account_environment = geneva_logs_config[:environment]
        geneva_account_name = geneva_logs_config[:account]
        geneva_account_namespace = geneva_logs_config[:namespace]
        geneva_logs_config_version = geneva_logs_config[:configversion]
        if !geneva_account_environment.nil? && !geneva_account_name.nil? && !geneva_account_namespace.nil? && !geneva_logs_config_version.nil?
          @geneva_account_environment = geneva_account_environment
          @geneva_account_name = geneva_account_name
          @geneva_account_namespace = geneva_account_namespace
          @geneva_logs_config_version = geneva_logs_config_version
        else
          puts "config::error:invalid geneva logs config"
        end
        geneva_gcs_authid = geneva_logs_config[:authid]
        if geneva_gcs_authid.nil? || geneva_gcs_authid.empty?
          # extract authid from nodes config
          begin
            file = File.read(@azure_json_path)
            data_hash = JSON.parse(file)
            sp_client_id = data_hash["aadClientId"]
            user_assigned_client_id = data_hash["userAssignedIdentityID"]
            if (!sp_client_id.nil? &&
                !sp_client_id.empty? &&
                sp_client_id.downcase == "msi" &&
                !user_assigned_client_id.nil? &&
                !user_assigned_client_id.empty?)
              geneva_gcs_authid = "client_id##{user_assigned_client_id}"
              puts "using authid for geneva integration: #{geneva_gcs_authid}"
              @geneva_gcs_authid = geneva_gcs_authid
            end
          rescue => errorStr
            puts "failed to get user assigned client id with an error: #{errorStr}"
          end
        elsif !geneva_gcs_authid.start_with?("client_id#") && !geneva_gcs_authid.start_with?("object_id#") && !geneva_gcs_authid.start_with?("mi_res_id#")
            puts "config::error:auth id must be in one of the suppported formats: object_id#<guid> or client_id#<guid> or mi_res_id#<identity resource id>"
        else
          @geneva_gcs_authid = geneva_gcs_authid
        end
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

    if !@geneva_account_environment.empty? && !@geneva_account_name.empty? && !@geneva_account_namespace.empty? && !@geneva_logs_config_version.empty? && !@geneva_gcs_authid.empty?
      file.write(get_command_windows("MONITORING_GCS_ENVIRONMENT", @geneva_account_environment))
      file.write(get_command_windows("MONITORING_GCS_ACCOUNT", @geneva_account_name))
      file.write(get_command_windows("MONITORING_GCS_NAMESPACE", @geneva_account_namespace))
      file.write(get_command_windows("MONITORING_CONFIG_VERSION", @geneva_logs_config_version))
      
      authIdParts =  @geneva_gcs_authid.split('#', 2)
      file.write(get_command_windows("MONITORING_MANAGED_ID_IDENTIFIER", authIdParts[0]))
      file.write(get_command_windows("MONITORING_MANAGED_ID_VALUE", authIdParts[1]))

      puts "Using config map value: MONITORING_GCS_ENVIRONMENT = #{@geneva_account_environment}"
      puts "Using config map value: MONITORING_GCS_ACCOUNT = #{@geneva_account_name}"
      puts "Using config map value: MONITORING_GCS_NAMESPACE = #{@geneva_account_namespace}"
      puts "Using config map value: MONITORING_CONFIG_VERSION = #{@geneva_logs_config_version}"
      puts "Using config map value: MONITORING_MANAGED_ID_IDENTIFIER = #{authIdParts[0]}"
      puts "Using config map value: MONITORING_MANAGED_ID_VALUE= #{authIdParts[1]}"

      puts "config::info:successfully parsed geneva_logs_config settings"
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