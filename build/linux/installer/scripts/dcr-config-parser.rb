#!/usr/local/bin/ruby

require "fileutils"
require "json"
require_relative "ConfigParseErrorLogger"

@os_type = ENV["OS_TYPE"]
@controllerType = ENV["CONTROLLER_TYPE"]
@containerType = ENV["CONTAINER_TYPE"]
@logs_and_events_streams = {
  "CONTAINER_LOG_BLOB" => true,
  "CONTAINERINSIGHTS_CONTAINERLOGV2" => true,
  "KUBE_EVENTS_BLOB" => true,
  "KUBE_POD_INVENTORY_BLOB" => true,
}
@logs_and_events_only = false

# Return early without checking DCRs in these cases:
# 1. Geneva Logs integration is enabled and multi-tenancy is disabled. The container runs in Geneva mode, which does not use DCRs.
# 2. Geneva Logs integration and multi-tenancy are enabled, and Geneva Logs infra namespaces are configured. The container runs in Geneva mode, which does not use DCRs.
# 3. Geneva Logs service mode is enabled. The container runs in Geneva mode, which does not use DCRs.
# 4. Azure Monitor service mode is enabled - Though it uses DCRs but it doesnt use the Container Insights extension DCR
# 5. The OS is Windows. DCRs are at cluster level and checking at Linux Daemonset  level is enough and dont need windows daemonset to check DCRs
# 6. AAD MSI authentication is not enabled. DCRs are not used in this configuration.

def env_flag?(name, expected)
  ENV[name]&.strip&.casecmp?(expected) == true
end

geneva_logs_integration = env_flag?("GENEVA_LOGS_INTEGRATION", "true")
geneva_logs_infra_namespaces_set = !ENV.fetch("GENEVA_LOGS_INFRA_NAMESPACES", "").empty?

# Scenarios 1 and 2 match isGenevaMode in kubernetes/linux/main.sh for the multi-tenancy values written by
# the geneva config parser, so a tenant-only node (no infra namespaces) still runs mdsd with DCRs.
return if geneva_logs_integration && env_flag?("GENEVA_LOGS_MULTI_TENANCY", "false")
return if geneva_logs_integration && env_flag?("GENEVA_LOGS_MULTI_TENANCY", "true") && geneva_logs_infra_namespaces_set
return if env_flag?("GENEVA_LOGS_INTEGRATION_SERVICE_MODE", "true") 
return if env_flag?("AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE", "true")
return if @os_type&.strip&.casecmp?("windows")
return unless env_flag?("USING_AAD_MSI_AUTH", "true")

if !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp("daemonset").zero? \
  && @containerType.nil?
  begin
    file_path = nil
    if Dir.exist?("/etc/mdsd.d/config-cache/configchunks")
      Dir.glob("/etc/mdsd.d/config-cache/configchunks/*.json").each do |file|
        if File.foreach(file).grep(/ContainerInsightsExtension/).any?
          file_path = file
          break # Exit the loop once a matching file is found
        end
      end
    end

    # Raise an error if no JSON file is found
    raise 'No JSON file found in the specified directory. Check if mdsd is running in MSI mode' unless file_path

    file_contents = File.read(file_path)
    data = JSON.parse(file_contents)

    raise 'Invalid JSON structure: Missing required key: dataSources. Check if DCR is valid' unless data.is_a?(Hash) && data.key?('dataSources')

    # Extract the stream values
    # If the DCR has GIG and ODS streams,then id will be either in the format ContainerInsightsExtension:ods-* or ContainerInsightsExtension:gigl-dce-*
    streams = data["dataSources"].select { |ds| ds["id"].start_with?("ContainerInsightsExtension") }
                                 .flat_map { |ds| ds["streams"] if ds.key?("streams") }
                                 .compact
                                 .map { |stream| stream["stream"] if stream.key?("stream") }
                                 .compact

    # Check if there is a stream which is not part of the logs and events streams
    extra_stream = streams.any? { |stream| !@logs_and_events_streams.include?(stream) }
    unless extra_stream
      # Write the settings to file, so that they can be set as environment variables
      puts "DCR config matches Log and Events only profile. Setting LOGS_AND_EVENTS_ONLY to true"
      @logs_and_events_only = true
    end
    file = File.open("/opt/dcr_env_var", "w")
    file.write("LOGS_AND_EVENTS_ONLY=#{@logs_and_events_only}\n")
    file.close
  rescue Exception => e
    ConfigParseErrorLogger.logError("Exception while parsing dcr : #{e}. DCR Json data: #{data}")
  end
end
