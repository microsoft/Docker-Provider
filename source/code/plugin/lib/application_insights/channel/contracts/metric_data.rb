require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class MetricData
    include JsonSerializable

    attr_accessor :ver, :metrics, :properties

    attribute_mapping(
      ver: 'ver',
      metrics: 'metrics',
      properties: 'properties'
    )

    def ver
      @ver ||= 2
    end

    def metrics
      @metrics ||= []
    end

    def properties
      @properties ||= {}
    end
  end
end
