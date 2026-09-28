#!/usr/local/bin/ruby

require "json"
require_relative "ConfigParseErrorLogger"

logs_and_events_streams = {
  "CONTAINER_LOG_BLOB" => true,
  "CONTAINERINSIGHTS_CONTAINERLOGV2" => true,
  "KUBE_EVENTS_BLOB" => true,
  "KUBE_POD_INVENTORY_BLOB" => true,
}
output_path = ARGV[0]

begin
  raise "Output file path is required" if output_path.nil? || output_path.empty?

  applicable_sources = nil
  Dir.glob("/etc/mdsd.d/config-cache/configchunks/*.json").each do |file|
    begin
      candidate = JSON.parse(File.read(file))
    rescue JSON::ParserError
      next
    end

    next unless candidate.is_a?(Hash) && candidate["dataSources"].is_a?(Array)

    sources = candidate["dataSources"].select do |source|
      source.is_a?(Hash) && source["id"].is_a?(String) &&
        source["id"].start_with?("ContainerInsightsExtension")
    end
    next if sources.empty?

    valid_streams = sources.all? do |source|
      source["streams"].is_a?(Array) && !source["streams"].empty? &&
        source["streams"].all? do |stream|
          stream.is_a?(Hash) && stream["stream"].is_a?(String) && !stream["stream"].empty?
        end
    end
    next unless valid_streams

    applicable_sources = sources
    break
  end

  raise "No applicable Container Insights DCR configuration was found" unless applicable_sources

  streams = applicable_sources.flat_map { |source| source["streams"] }
                              .map { |stream| stream["stream"] }

  logs_and_events_only = streams.none? { |stream| !logs_and_events_streams.include?(stream) }
  File.write(output_path, "#{logs_and_events_only}\n")
rescue StandardError => e
  ConfigParseErrorLogger.logError("Exception while parsing dcr: #{e}")
  exit 1
end
