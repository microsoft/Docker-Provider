require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class MessageData
    include JsonSerializable

    attr_accessor :ver, :message, :severity_level, :properties

    attribute_mapping(
      ver: 'ver',
      message: 'message',
      severity_level: 'severityLevel',
      properties: 'properties'
    )

    def ver
      @ver ||= 2
    end

    def properties
      @properties ||= {}
    end
  end
end
