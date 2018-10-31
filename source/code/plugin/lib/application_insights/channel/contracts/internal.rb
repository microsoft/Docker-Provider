require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Internal
    include JsonSerializable

    attr_accessor :sdk_version, :agent_version, :node_name

    attribute_mapping(
      sdk_version: 'ai.internal.sdkVersion',
      agent_version: 'ai.internal.agentVersion',
      node_name: 'ai.internal.nodeName'
    )
  end
end
