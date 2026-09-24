#!/usr/local/bin/rubyinfra_namespaces

@os_type = ENV["OS_TYPE"]
require "tomlrb"
require "json"

require_relative "ConfigParseErrorLogger"

@configMapMountPath = "/etc/config/settings/integrations"
@configSchemaVersion = ""
@geneva_logs_integration = false
@multi_tenancy = false
@disable_windows = false
@disable_linux = false

GENEVA_SUPPORTED_ENVIRONMENTS = ["Test", "Stage", "DiagnosticsProd", "FirstpartyProd", "BillingProd", "ExternalProd", "CaMooncake", "CaFairfax", "CaBlackforest", "Bleu"]

# Everything under [integrations.geneva_logs] comes from the container-azm-ms-agentconfig config
# map, which is tenant writable, so it is untrusted input. On linux the generated
# geneva_config_env_var file is appended to ~/.bashrc and sourced by main.sh while the agent runs
# as root, so an unquoted value would be executed as shell. Every value is therefore validated
# against an anchored allowlist below and single quoted when written.
# The anchors must be \A and \z (not ^ and $) so that a value such as "prod\n<injected command>"
# cannot pass validation by matching only its first line.

# Geneva environment, account and namespace identifiers must start with a letter and then may
# contain letters, digits, underscores, hyphens or periods.
GENEVA_NAME_REGEX = /\A[A-Za-z][A-Za-z0-9_\-\.]{0,63}\z/
# GCS region must start with a letter and contain only letters or digits.
GENEVA_REGION_REGEX = /\A[A-Za-z][A-Za-z0-9]{0,63}\z/
# Agent xml config version, for example "1.0" or "Ver2v0".
GENEVA_CONFIG_VERSION_REGEX = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/
# MUST be <identifier>#<value>, for example client_id#<guid> or mi_res_id#<identity resource id>.
# The windows agent relies on the same shape when it splits the value on "#".
GENEVA_AUTH_ID_REGEX = /\A(?:client_id|object_id|mi_res_id)#[A-Za-z0-9._\-\/()]{1,512}\z/i
# Kubernetes namespaces are RFC 1123 labels. Keep these constants Geneva-specific because the
# unit test driver loads all common parser tests into one Ruby process.
GENEVA_KUBERNETES_NAMESPACE_REGEX = /\A[a-z0-9]([-a-z0-9]*[a-z0-9])?\z/
GENEVA_KUBERNETES_NAMESPACE_MAX_LENGTH = 63
# Infra namespaces may carry a trailing wildcard, which main.sh strips before using the value as
# part of a generated fluent-bit config file name.
GENEVA_INFRA_NAMESPACE_WILDCARD_SUFFIX = "-*"
GENEVA_DEFAULT_CONFIG_VERSION = "1.0"

# Renders a value as a single quoted shell word. Every character inside single quotes is literal
# to the shell, and an embedded single quote is emitted as '\'' so that the value cannot terminate
# its own quoting. Values are validated before they reach this point; this is the last line of
# defense that keeps config map content out of the shell parser.
# The block form of gsub is required: with a replacement string ruby would treat the \' as the
# post-match backreference instead of a literal backslash and quote.
def toShellSingleQuoted(value)
  return "'" + value.to_s.gsub("'") { "'\\''" } + "'"
end

def isValidGenevaName(value)
  return value.kind_of?(String) && !(value =~ GENEVA_NAME_REGEX).nil?
end

def isValidGenevaRegion(region)
  return region.kind_of?(String) && !(region =~ GENEVA_REGION_REGEX).nil?
end

def isValidGenevaAuthId(authid)
  return authid.kind_of?(String) && !(authid =~ GENEVA_AUTH_ID_REGEX).nil?
end

def isValidGenevaConfigVersion(configVersion)
  return configVersion.kind_of?(String) && !(configVersion =~ GENEVA_CONFIG_VERSION_REGEX).nil?
end

# The environment identifiers of the airgap clouds are not known to the agent, which is why the
# allowlist below is a warning rather than a rejection. The character allowlist above is what
# makes the value safe to write into the environment file.
def isValidGenevaEnvironment(environment)
  if !isValidGenevaName(environment)
    return false
  end
  if !GENEVA_SUPPORTED_ENVIRONMENTS.map(&:downcase).include?(environment.downcase)
    puts "config::geneva_logs::warn:geneva environment is not one of the known geneva environments"
  end
  return true
end

def isValidKubernetesNamespace(namespace)
  return namespace.kind_of?(String) &&
         namespace.length <= GENEVA_KUBERNETES_NAMESPACE_MAX_LENGTH &&
         !(namespace =~ GENEVA_KUBERNETES_NAMESPACE_REGEX).nil?
end

def isValidGenevaInfraNamespace(namespace)
  if !namespace.kind_of?(String)
    return false
  end
  if namespace.end_with?(GENEVA_INFRA_NAMESPACE_WILDCARD_SUFFIX)
    return isValidKubernetesNamespace(namespace[0...-GENEVA_INFRA_NAMESPACE_WILDCARD_SUFFIX.length])
  end
  return isValidKubernetesNamespace(namespace)
end

# Joins the namespaces that are safe to use into the comma separated list the agent expects.
# main.sh splits this list again and interpolates each entry into a file name and a sed
# expression, so an entry that is not a kubernetes namespace is dropped rather than passed on.
# The rejected entry is never echoed back since it is untrusted input.
def joinValidNamespaces(namespaces, settingName, isInfra)
  validNamespaces = []
  if namespaces.nil? || !namespaces.kind_of?(Array)
    return ""
  end
  namespaces.each do |namespace|
    namespace = namespace.to_s.strip
    next if namespace.empty?
    isValid = isInfra ? isValidGenevaInfraNamespace(namespace) : isValidKubernetesNamespace(namespace)
    if !isValid
      ConfigParseErrorLogger.logError("Skipping an entry in #{settingName} because it is not a valid kubernetes namespace")
      next
    end
    validNamespaces.push(namespace)
  end
  return validNamespaces.join(",")
end

# Returns the config version to use, falling back to the default when the configured value is not
# usable. A typo in an optional setting should not take the integration down.
def resolveConfigVersion(configVersion, settingName)
  if configVersion.nil? || configVersion.empty?
    puts "Since #{settingName} not specified so using default config version : #{GENEVA_DEFAULT_CONFIG_VERSION}"
    return GENEVA_DEFAULT_CONFIG_VERSION
  end
  if isValidGenevaConfigVersion(configVersion)
    return configVersion
  end
  ConfigParseErrorLogger.logError("Invalid value specified for #{settingName}, using default config version : #{GENEVA_DEFAULT_CONFIG_VERSION}")
  return GENEVA_DEFAULT_CONFIG_VERSION
end
@geneva_account_environment = "" # Supported values Test, Stage, DiagnosticsProd, FirstpartyProd, BillingProd, ExternalProd, CaMooncake, CaFairfax, CaBlackforest, Bleu
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
# Checking to see if this is the daemonset or replicaset to parse config accordingly
@controllerType = ENV["CONTROLLER_TYPE"]
@daemonset = "daemonset"

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

def populateGenevaIntegrationSettings(parsedConfig)
  begin
    if !parsedConfig.nil? && !parsedConfig[:integrations].nil? && !parsedConfig[:integrations][:geneva_logs].nil?
      if !parsedConfig[:integrations][:geneva_logs][:enabled].nil?
        geneva_logs_integration = parsedConfig[:integrations][:geneva_logs][:enabled].to_s
        if !geneva_logs_integration.nil? && geneva_logs_integration.strip.casecmp("true") == 0
          @geneva_logs_integration = true
        else
          @geneva_logs_integration = false
        end
      end
      puts "Using config map value: GENEVA_LOGS_INTEGRATION=#{@geneva_logs_integration}"
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

        disable_windows = parsedConfig[:integrations][:geneva_logs][:disable_windows].to_s
        if !disable_windows.nil? && disable_windows.strip.casecmp("true") == 0
          @disable_windows = true
        end

        disable_linux = parsedConfig[:integrations][:geneva_logs][:disable_linux].to_s
        if !disable_linux.nil? && disable_linux.strip.casecmp("true") == 0
          @disable_linux = true
        end

        if @disable_windows && @disable_linux
          @geneva_logs_integration = false # if both are disabled then disable the integration
          puts "config::geneva_logs:geneva logs integration disabled since both linux and windows disabled"
        end

        if @geneva_logs_integration
          multi_tenancy = parsedConfig[:integrations][:geneva_logs][:multi_tenancy].to_s
          if !multi_tenancy.nil? && multi_tenancy.strip.casecmp("true") == 0
            @multi_tenancy = true
          end

          if @multi_tenancy
            # this is only applicable incase of multi-tenacy
            infra_namespaces = parsedConfig[:integrations][:geneva_logs][:infra_namespaces]
            if !infra_namespaces.nil? && !infra_namespaces.empty? &&
               infra_namespaces.kind_of?(Array) && infra_namespaces.length > 0 &&
               infra_namespaces[0].kind_of?(String) # Checking only for the first element to be string because toml enforces the arrays to contain elements of same type
              @infra_namespaces = joinValidNamespaces(infra_namespaces, "infra_namespaces", true)
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
                @geneva_logs_config_version = resolveConfigVersion(geneva_logs_config_version, "configversion")
              else
                @geneva_logs_config_version = GENEVA_DEFAULT_CONFIG_VERSION
                puts "Since config version not specified so using default config version : #{@geneva_logs_config_version}"
              end

              if !geneva_logs_config_version_windows.nil? && !geneva_logs_config_version_windows.empty?
                @geneva_logs_config_version_windows = resolveConfigVersion(geneva_logs_config_version_windows, "windowsconfigversion")
              else
                @geneva_logs_config_version_windows = GENEVA_DEFAULT_CONFIG_VERSION
                puts "Since config version for windows not specified so using default config version : #{@geneva_logs_config_version_windows}"
              end
            else
              puts "config::geneva_logs::error: provided geneva logs config is not valid"
            end
          end

          if @multi_tenancy
            tenant_namespaces = parsedConfig[:integrations][:geneva_logs][:tenant_namespaces]
            if !tenant_namespaces.nil? && !tenant_namespaces.empty? &&
               tenant_namespaces.kind_of?(Array) && tenant_namespaces.length > 0 &&
               tenant_namespaces[0].kind_of?(String) # Checking only for the first element to be string because toml enforces the arrays to contain elements of same type
              @tenant_namespaces = joinValidNamespaces(tenant_namespaces, "tenant_namespaces", false)
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
    # The rejected values are never echoed back into the logs since they are untrusted input.
    if environment.nil? || environment.empty? || !isValidGenevaEnvironment(environment)
      puts "config::geneva_logs::error:geneva environment MUST be valid"
      return isValid
    end

    if namespace.nil? || namespace.empty? || !isValidGenevaName(namespace)
      puts "config::geneva_logs::error:geneva account namespace MUST be valid"
      return isValid
    end

    if region.nil? || region.empty? || !isValidGenevaRegion(region)
      puts "config::geneva_logs::error:geneva GCS region MUST be valid"
      return isValid
    end

    if authid.nil? || authid.empty? || !isValidGenevaAuthId(authid)
      puts "config::geneva_logs::error:geneva GCS AuthID MUST be valid"
      return isValid
    end

    ## account and namespacewindows are optional hence only the format is validated when provided
    if !account.nil? && !account.empty? && !isValidGenevaName(account)
      puts "config::geneva_logs::error:geneva account MUST be valid"
      return isValid
    end

    if !namespacewindows.nil? && !namespacewindows.empty? && !isValidGenevaName(namespacewindows)
      puts "config::geneva_logs::error:geneva account namespace for windows MUST be valid"
      return isValid
    end
    isValid = true
  rescue => errorStr
    puts "config::geneva_logs::error:Exception while validating Geneva config - #{errorStr}"
  end
  return isValid
end

def get_command_windows(env_variable_name, env_variable_value)
  return "#{env_variable_name}=#{env_variable_value}\n"
end

def is_configure_geneva_env_vars()
  is_configure = false
  if (@geneva_logs_integration && (!@multi_tenancy || !@infra_namespaces.empty?))
    is_configure = true
  end
  return is_configure
end

@configSchemaVersion = ENV["AZMON_AGENT_CFG_SCHEMA_VERSION"]
puts "****************Start Agent Integrations Config Processing********************"
if !@configSchemaVersion.nil? && !@configSchemaVersion.empty? && @configSchemaVersion.strip.casecmp("v1") == 0 #note v1 is the only supported schema version , so hardcoding it
  configMapSettings = parseConfigMap
  if !configMapSettings.nil?
    if !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp(@daemonset) == 0
      populateSettingValuesFromConfigMap(configMapSettings)
    else
      populateGenevaIntegrationSettings(configMapSettings)
    end
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
  if @disable_linux
    puts "config::geneva_logs::info:geneva logs integration disabled for linux"
  else
    if !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp(@daemonset) == 0
      file.write("export GENEVA_LOGS_INTEGRATION=#{@geneva_logs_integration}\n")
      file.write("export GENEVA_LOGS_MULTI_TENANCY=#{@multi_tenancy}\n")
      if @enable_fbit_threading
        file.write("export ENABLE_FBIT_THREADING=#{@enable_fbit_threading}\n")
      end

      if is_configure_geneva_env_vars()
        # Config map derived values are single quoted so that the shell that sources this file
        # treats them as literal data and never as commands.
        file.write("export MONITORING_GCS_ENVIRONMENT=#{toShellSingleQuoted(@geneva_account_environment)}\n")
        file.write("export MONITORING_GCS_NAMESPACE=#{toShellSingleQuoted(@geneva_account_namespace)}\n")
        file.write("export MONITORING_GCS_ACCOUNT=#{toShellSingleQuoted(@geneva_account_name)}\n")
        file.write("export MONITORING_GCS_REGION=#{toShellSingleQuoted(@geneva_gcs_region)}\n")
        file.write("export MONITORING_CONFIG_VERSION=#{toShellSingleQuoted(@geneva_logs_config_version)}\n")
        file.write("export MONITORING_GCS_AUTH_ID=#{toShellSingleQuoted(@geneva_gcs_authid)}\n")
        file.write("export MONITORING_GCS_AUTH_ID_TYPE=AuthMSIToken\n")
      end
      file.write("export GENEVA_LOGS_INFRA_NAMESPACES=#{toShellSingleQuoted(@infra_namespaces)}\n")
      file.write("export GENEVA_LOGS_TENANT_NAMESPACES=#{toShellSingleQuoted(@tenant_namespaces)}\n")

      # This required environment variable in geneva mode
      file.write("export MDSD_MSGPACK_SORT_COLUMNS=1\n")
    else
      file.write("export RS_GENEVA_LOGS_INTEGRATION=#{@geneva_logs_integration}\n")
    end
  end
  # Close file after writing all environment variables
  file.close
else
  puts "Exception while opening file for writing  geneva config environment variables"
  puts "****************End Config Processing********************"
end

if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
  # Write the settings to file, so that they can be set as environment variables
  file = File.open("setgenevaconfigenv.txt", "w")

  if !file.nil?
    if @disable_windows
      puts "config::geneva_logs::info:geneva logs integration disabled for windows"
    else
      commands = get_command_windows("GENEVA_LOGS_INTEGRATION", @geneva_logs_integration)
      file.write(commands)
      commands = get_command_windows("GENEVA_LOGS_MULTI_TENANCY", @multi_tenancy)
      file.write(commands)
      if @enable_fbit_threading
        commands = get_command_windows("ENABLE_FBIT_THREADING", @enable_fbit_threading)
        file.write(commands)
      end

      if is_configure_geneva_env_vars()
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
    end
    # Close file after writing all environment variables
    file.close
    puts "****************End Config Processing********************"
  else
    puts "Exception while opening file for writing config environment variables for WINDOWS LOG"
    puts "****************End Config Processing********************"
  end
end
