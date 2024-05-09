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

return if ENV['GENEVA_LOGS_INTEGRATION']&.strip&.casecmp?('true')
return if ENV['GENEVA_LOGS_INTEGRATION_SERVICE_MODE']&.strip&.casecmp?('true')
return if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp('windows').zero?
return unless ENV['USING_AAD_MSI_AUTH']&.strip&.casecmp?('true')

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
