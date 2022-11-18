require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Operation
    include JsonSerializable

    attr_accessor :id, :name, :parent_id, :synthetic_source, :correlation_vector

    attribute_mapping(
      id: 'ai.operation.id',
      name: 'ai.operation.name',
      parent_id: 'ai.operation.parentId',
      synthetic_source: 'ai.operation.syntheticSource',
      correlation_vector: 'ai.operation.correlationVector'
    )
  end
end
