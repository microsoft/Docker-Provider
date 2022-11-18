require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Location
    include JsonSerializable

    attr_accessor :ip

    attribute_mapping(
      ip: 'ai.location.ip'
    )
  end
end
