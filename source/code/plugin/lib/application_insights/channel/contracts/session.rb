require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Session
    include JsonSerializable

    attr_accessor :id, :is_first

    attribute_mapping(
      id: 'ai.session.id',
      is_first: 'ai.session.isFirst'
    )
  end
end
