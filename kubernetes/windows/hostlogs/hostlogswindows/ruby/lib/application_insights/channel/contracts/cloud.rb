require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Cloud
    include JsonSerializable

    attr_accessor :role, :role_instance

    attribute_mapping(
      role: 'ai.cloud.role',
      role_instance: 'ai.cloud.roleInstance'
    )
  end
end
