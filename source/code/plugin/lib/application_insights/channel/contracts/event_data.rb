require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class EventData
    include JsonSerializable

    attr_accessor :ver, :name, :properties, :measurements

    attribute_mapping(
      ver: 'ver',
      name: 'name',
      properties: 'properties',
      measurements: 'measurements'
    )

    def ver
      @ver ||= 2
    end

    def properties
      @properties ||= {}
    end

    def measurements
      @measurements ||= {}
    end
  end
end
