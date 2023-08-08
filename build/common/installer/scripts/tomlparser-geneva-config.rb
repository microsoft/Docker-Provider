#!/usr/local/bin/rubyinfra_namespaces

@os_type = ENV["OS_TYPE"]
require "tomlrb"
require "json"

require_relative "ConfigParseErrorLogger"

@configMapMountPath = "/etc/config/settings/integrations"
@configSchemaVersion = ""
@geneva_logs_integration = false
@multi_tenancy = false

GENEVA_SUPPORTED_ENVIRONMENTS = ["Test", "Stage", "DiagnosticsProd", "FirstpartyProd", "BillingProd", "ExternalProd", "CaMooncake", "CaFairfax", "CaBlackforest"]
@geneva_account_environment = "" # Supported values Test, Stage, DiagnosticsProd, FirstpartyProd, BillingProd, ExternalProd, CaMooncake, CaFairfax, CaBlackforest
@geneva_account_name = ""
@geneva_account_namespace = ""
@geneva_account_namespace_windows = ""
@geneva_logs_config_version = "1.0"
@geneva_logs_config_version_windows = "1.0"
@geneva_gcs_region = ""
@infra_namespaces = ""
@tenant_namespaces = ""
@geneva_gcs_authid = ""
@azure_json_path = "/etc/kubernetes/host/azure.json"
@enable_fbit_threading = false

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@configMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig found, parsing values for geneva logs config"
      parsedConfig = Tomlrb.load_file(@configMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig  not mounted, using defaults"
      return nil
    end
  rescue => errorStr
    ConfigParseErrorLogger.logError("Exception while parsing config map for geneva logs config: #{errorStr}, using defaults, please check config map for errors")
    return nil
  end
end

# Use the ruby structure created after config parsing to set the right values to be used as environment variables
def populateSettingValuesFromConfigMap(parsedConfig)
  begin
    if !parsedConfig.nil? && !parsedConfig[:integrations].nil? && !parsedConfig[:integrations][:geneva_logs].nil?
      if !parsedConfig[:integrations][:geneva_logs][:enabled].nil?
        geneva_logs_integration = parsedConfig[:integrations][:geneva_logs][:enabled].to_s
        if !geneva_logs_integration.nil? && geneva_logs_integration.strip.casecmp("true") == 0
          @geneva_logs_integration = true
        else
          @geneva_logs_integration = false
        end
        if @geneva_logs_integration
          multi_tenancy = parsedConfig[:integrations][:geneva_logs][:multi_tenancy].to_s
          if !multi_tenancy.nil? && multi_tenancy.strip.casecmp("true") == 0
            @multi_tenancy = true
          end

          if @multi_tenancy
            # this is only applicable incase of multi-tenacy
            infra_namespaces = parsedConfig[:integrations][:geneva_logs][:infra_namespaces]
            puts "config::geneva_logs:infra_namespaces provided in the configmap: #{infra_namespaces}"
            if !infra_namespaces.nil? && !infra_namespaces.empty? &&
               infra_namespaces.kind_of?(Array) && infra_namespaces.length > 0 &&
               infra_namespaces[0].kind_of?(String) # Checking only for the first element to be string because toml enforces the arrays to contain elements of same type
              infra_namespaces.each do |namespace|
                if @infra_namespaces.empty?
                  # To not append , for the first element
                  @infra_namespaces.concat(namespace)
                else
                  @infra_namespaces.concat("," + namespace)
                end
              end
            end
            enable_fbit_threading = parsedConfig[:integrations][:geneva_logs][:enable_threading].to_s
            puts "config::geneva_logs:enable_threading provided in the configmap: #{enable_fbit_threading}"
            if !enable_fbit_threading.nil? && enable_fbit_threading.strip.casecmp("true") == 0
              @enable_fbit_threading = true
            end
          end

          if !@multi_tenancy || (@multi_tenancy && !@infra_namespaces.empty?)
            geneva_account_environment = parsedConfig[:integrations][:geneva_logs][:environment].to_s
            geneva_account_namespace = parsedConfig[:integrations][:geneva_logs][:namespace].to_s
            geneva_account_namespace_windows = parsedConfig[:integrations][:geneva_logs][:namespacewindows].to_s
            geneva_account_name = parsedConfig[:integrations][:geneva_logs][:account].to_s
            geneva_logs_config_version = parsedConfig[:integrations][:geneva_logs][:configversion].to_s
            geneva_logs_config_version_windows = parsedConfig[:integrations][:geneva_logs][:windowsconfigversion].to_s
            geneva_gcs_region = parsedConfig[:integrations][:geneva_logs][:region].to_s
            geneva_gcs_authid = parsedConfig[:integrations][:geneva_logs][:authid].to_s
            if geneva_gcs_authid.nil? || geneva_gcs_authid.empty?
              # extract authid from nodes config
              begin
                file = File.read(@azure_json_path)
                data_hash = JSON.parse(file)
                # Check to see if SP exists, if it does use SP. Else, use msi
                sp_client_id = data_hash["aadClientId"]
                sp_client_secret = data_hash["aadClientSecret"]
                user_assigned_client_id = data_hash["userAssignedIdentityID"]
                if (!sp_client_id.nil? &&
                    !sp_client_id.empty? &&
                    sp_client_id.downcase == "msi" &&
                    !user_assigned_client_id.nil? &&
                    !user_assigned_client_id.empty?)
                  geneva_gcs_authid = "client_id##{user_assigned_client_id}"
                  puts "using authid for geneva integration: #{geneva_gcs_authid}"
                end
              rescue => errorStr
                puts "failed to get user assigned client id with an error: #{errorStr}"
              end
            end
            if isValidGenevaConfig(geneva_account_environment, geneva_account_namespace, geneva_account_namespace_windows, geneva_account_name, geneva_gcs_authid, geneva_gcs_region)
              @geneva_account_environment = geneva_account_environment
              @geneva_account_namespace = geneva_account_namespace
              @geneva_account_namespace_windows = geneva_account_namespace_windows
              @geneva_account_name = geneva_account_name
              @geneva_gcs_region = geneva_gcs_region
              @geneva_gcs_authid = geneva_gcs_authid

              if !geneva_logs_config_version.nil? && !geneva_logs_config_version.empty?
                @geneva_logs_config_version = geneva_logs_config_version
              else
                @geneva_logs_config_version = "1.0"
                puts "Since config version not specified so using default config version : #{@geneva_logs_config_version}"
              end

              if !geneva_logs_config_version_windows.nil? && !geneva_logs_config_version_windows.empty?
                @geneva_logs_config_version_windows = geneva_logs_config_version_windows
              else
                @geneva_logs_config_version_windows = "1.0"
                puts "Since config version for windows not specified so using default config version : #{@geneva_logs_config_version_windows}"
              end
            else
              puts "config::geneva_logs::error: provided geneva logs config is not valid"
            end
          end

          if @multi_tenancy
            tenant_namespaces = parsedConfig[:integrations][:geneva_logs][:tenant_namespaces]
            puts "config::geneva_logs:tenant_namespaces provided in the configmap: #{tenant_namespaces}"
            if !tenant_namespaces.nil? && !tenant_namespaces.empty? &&
               tenant_namespaces.kind_of?(Array) && tenant_namespaces.length > 0 &&
               tenant_namespaces[0].kind_of?(String) # Checking only for the first element to be string because toml enforces the arrays to contain elements of same type
              tenant_namespaces.each do |namespace|
                if @tenant_namespaces.empty?
                  # To not append , for the first element
                  @tenant_namespaces.concat(namespace)
                else
                  @tenant_namespaces.concat("," + namespace)
                end
              end
            end
          end

          puts "Using config map value: GENEVA_LOGS_INTEGRATION=#{@geneva_logs_integration}"
          puts "Using config map value: GENEVA_LOGS_MULTI_TENANCY=#{@multi_tenancy}"
          puts "Using config map value: MONITORING_GCS_ENVIRONMENT=#{@geneva_account_environment}"
          puts "Using config map value: MONITORING_GCS_NAMESPACE=#{@geneva_account_namespace}"
          puts "Using config map value: MONITORING_GCS_ACCOUNT=#{@geneva_account_name}"
          puts "Using config map value: MONITORING_GCS_REGION=#{@geneva_gcs_region}"
          puts "Using config map value: MONITORING_GCS_AUTH_ID=#{@geneva_gcs_authid}"
          if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
            puts "Using config map value: MONITORING_CONFIG_VERSION=#{@geneva_logs_config_version_windows}"
          else
            puts "Using config map value: MONITORING_CONFIG_VERSION=#{@geneva_logs_config_version}"
          end
          puts "Using config map value: GENEVA_LOGS_INFRA_NAMESPACES=#{@infra_namespaces}"
          puts "Using config map value: GENEVA_LOGS_TENANT_NAMESPACES=#{@tenant_namespaces}"
        end
      end
    end
  rescue => errorStr
    puts "config::geneva_logs::error:Exception while reading config settings for geneva logs setting - #{errorStr}, using defaults"
    @geneva_logs_integration = false
    @multi_tenancy = false
    @geneva_account_environment = ""
    @geneva_account_name = ""
    @geneva_account_namespace = ""
    @geneva_gcs_region = ""
  end
end

def isValidGenevaConfig(environment, namespace, namespacewindows, account, authid, region)
  isValid = false
  begin
    if environment.nil? || environment.empty?
      puts "config::geneva_logs::error:geneva environment MUST be valid"
      return isValid
    end

    if namespace.nil? || namespace.empty?
      puts "config::geneva_logs::error:geneva account namespace MUST be valid"
      return isValid
    end

    if region.nil? || region.empty?
      puts "config::geneva_logs::error:geneva GCS region MUST be valid"
      return isValid
    end

    if authid.nil? || authid.empty?
      puts "config::geneva_logs::error:geneva GCS AuthID MUST be valid"
      return isValid
    end
    ## namespacewindows is optional hence we dont need this validation
    # if namespacewindows.nil? || namespacewindows.empty?
    #   puts "config::geneva_logs::error:geneva account namespace for windows MUST be valid"
    #   return isValid
    # end
    # TODO - add the validation once we figured out the environment for airgap clouds
    # GENEVA_SUPPORTED_ENVIRONMENTS.map(&:downcase).include?(environment.downcase)
    isValid = true
  rescue => errorStr
    puts "config::geneva_logs::error:Exception while validating Geneva config - #{errorStr}"
  end
  return isValid
end

def get_command_windows(env_variable_name, env_variable_value)
  return "[System.Environment]::SetEnvironmentVariable(\"#{env_variable_name}\", \"#{env_variable_value}\", \"Process\")" + "\n" + "[System.Environment]::SetEnvironmentVariable(\"#{env_variable_name}\", \"#{env_variable_value}\", \"Machine\")" + "\n"
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start Agent Integrations Config Processing********************"
if !@configSchemaVersion.nil? && !@configSchemaVersion.empty? && @configSchemaVersion.strip.casecmp("v1") == 0 #note v1 is the only supported schema version , so hardcoding it
  configMapSettings = parseConfigMap
  if !configMapSettings.nil?
    populateSettingValuesFromConfigMap(configMapSettings)
  end
else
  if (File.file?(@configMapMountPath))
    ConfigParseErrorLogger.logError("config::integrations::unsupported/missing config schema version - '#{@configSchemaVersion}' , using defaults, please use supported schema version")
  end
  @geneva_logs_integration = false
  @multi_tenancy = false
  @geneva_account_environment = ""
  @geneva_account_name = ""
  @geneva_account_namespace = ""
  @geneva_gcs_region = ""
end

# Write the settings to file, so that they can be set as environment variables
file = File.open("geneva_config_env_var", "w")

if !file.nil?
  file.write("export GENEVA_LOGS_INTEGRATION=#{@geneva_logs_integration}\n")
  file.write("export GENEVA_LOGS_MULTI_TENANCY=#{@multi_tenancy}\n")
  if @enable_fbit_threading
    file.write("export ENABLE_FBIT_THREADING=#{@enable_fbit_threading}\n")
  end

  if @geneva_logs_integration
    file.write("export MONITORING_GCS_ENVIRONMENT=#{@geneva_account_environment}\n")
    file.write("export MONITORING_GCS_NAMESPACE=#{@geneva_account_namespace}\n")
    file.write("export MONITORING_GCS_ACCOUNT=#{@geneva_account_name}\n")
    file.write("export MONITORING_GCS_REGION=#{@geneva_gcs_region}\n")
    file.write("export MONITORING_CONFIG_VERSION=#{@geneva_logs_config_version}\n")
    file.write("export MONITORING_GCS_AUTH_ID=#{@geneva_gcs_authid}\n")
    file.write("export MONITORING_GCS_AUTH_ID_TYPE=AuthMSIToken")
  end
  file.write("export GENEVA_LOGS_INFRA_NAMESPACES=#{@infra_namespaces}\n")
  file.write("export GENEVA_LOGS_TENANT_NAMESPACES=#{@tenant_namespaces}\n")

  # This required environment variable in geneva mode
  file.write("export MDSD_MSGPACK_SORT_COLUMNS=1\n")

  # Close file after writing all environment variables
  file.close
else
  puts "Exception while opening file for writing  geneva config environment variables"
  puts "****************End Config Processing********************"
end

if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
  # Write the settings to file, so that they can be set as environment variables
  file = File.open("setgenevaconfigenv.ps1", "w")

  if !file.nil?
    commands = get_command_windows("GENEVA_LOGS_INTEGRATION", @geneva_logs_integration)
    file.write(commands)
    commands = get_command_windows("GENEVA_LOGS_MULTI_TENANCY", @multi_tenancy)
    file.write(commands)
    if @enable_fbit_threading
      commands = get_command_windows("ENABLE_FBIT_THREADING", @enable_fbit_threading)
      file.write(commands)
    end

    if @geneva_logs_integration
      commands = get_command_windows("MONITORING_GCS_ENVIRONMENT", @geneva_account_environment)
      file.write(commands)
      commands = get_command_windows("MONITORING_GCS_NAMESPACE", @geneva_account_namespace_windows)
      file.write(commands)
      commands = get_command_windows("MONITORING_GCS_ACCOUNT", @geneva_account_name)
      file.write(commands)
      commands = get_command_windows("MONITORING_CONFIG_VERSION", @geneva_logs_config_version_windows)
      file.write(commands)
      commands = get_command_windows("MONITORING_GCS_REGION", @geneva_gcs_region)
      file.write(commands)
      commands = get_command_windows("MONITORING_GCS_AUTH_ID_TYPE", "AuthMSIToken")
      file.write(commands)
      #Windows AMA expects these and these are different from Linux AMA
      authIdParts = @geneva_gcs_authid.split("#", 2)
      if authIdParts.length == 2
        file.write(get_command_windows("MONITORING_MANAGED_ID_IDENTIFIER", authIdParts[0]))
        file.write(get_command_windows("MONITORING_MANAGED_ID_VALUE", authIdParts[1]))
      else
        puts "Invalid GCS Auth Id: #{@geneva_gcs_authid}"
      end
    end

    commands = get_command_windows("GENEVA_LOGS_INFRA_NAMESPACES", @infra_namespaces)
    file.write(commands)
    commands = get_command_windows("GENEVA_LOGS_TENANT_NAMESPACES", @tenant_namespaces)
    file.write(commands)
    # Close file after writing all environment variables
    file.close
    puts "****************End Config Processing********************"
  else
    puts "Exception while opening file for writing config environment variables for WINDOWS LOG"
    puts "****************End Config Processing********************"
  end
end
