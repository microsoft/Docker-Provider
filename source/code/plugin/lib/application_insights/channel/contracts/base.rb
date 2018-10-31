require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Base
    include JsonSerializable

    attr_accessor :base_type

    attribute_mapping(
      base_type: 'baseType'
    )
  end
end
