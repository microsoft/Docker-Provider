#!/usr/local/bin/ruby

require 'fileutils'
require 'json'
require_relative 'ConfigParseErrorLogger'

@os_type = ENV['OS_TYPE']
@controllerType = ENV['CONTROLLER_TYPE']
@containerType = ENV['CONTAINER_TYPE']
@dcrConfigFilePattern = '/etc/mdsd.d/config-cache/configchunks/*.json'
@logs_and_events_streams = %w[
  CONTAINER_LOG_BLOB
  CONTAINERINSIGHTS_CONTAINERLOGV2
  KUBE_EVENTS_BLOB
  KUBE_POD_INVENTORY_BLOB
]
@logs_and_events_only = false

return if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp('windows').zero?
return unless ENV['USING_AAD_MSI_AUTH'].strip.casecmp('true').zero?

if !@controllerType.nil? && !@controllerType.empty? && @controllerType.strip.casecmp('daemonset').zero? \
  && @containerType.nil?
  begin
    file_path = Dir.glob(@dcrConfigFilePattern).first
    # Raise an error if no JSON file is found
    raise 'No JSON file found in the specified directory' unless file_path

    file_contents = File.read(file_path)
    data = JSON.parse(file_contents)

    raise 'Invalid JSON structure: Missing required keys' unless data.is_a?(Hash) && data.key?('dataSources')

    # Extract the stream values
    streams = data['dataSources'].select { |ds| ds['id'] == 'ContainerInsightsExtension' }
                                 .flat_map { |ds| ds['streams'] if ds.key?('streams') }
                                 .compact
                                 .map { |stream| stream['stream'] if stream.key?('stream') }
                                 .compact
    streams -= @logs_and_events_streams
    if streams.empty?
      # Write the settings to file, so that they can be set as environment variables
      puts 'DCR config matches Log and Events only profile. Setting LOGS_AND_EVENTS_ONLY to true'
      @logs_and_events_only = true
      file = File.open('dcr_env_var', 'w')
      file.write("LOGS_AND_EVENTS_ONLY=#{@logs_and_events_only}\n")
      file.close
    end
  rescue StandardError => e
    ConfigParseErrorLogger.logError("Exception while parsing dcr : #{e}. DCR Json data: #{data}")
  end
end
