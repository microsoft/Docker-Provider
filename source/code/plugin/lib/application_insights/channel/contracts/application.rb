require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Application
    include JsonSerializable

    attr_accessor :ver

    attribute_mapping(
      ver: 'ai.application.ver'
    )
  end
end
