require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Device
    include JsonSerializable

    attr_accessor :id, :locale, :model, :oem_name, :os_version, :type

    attribute_mapping(
      id: 'ai.device.id',
      locale: 'ai.device.locale',
      model: 'ai.device.model',
      oem_name: 'ai.device.oemName',
      os_version: 'ai.device.osVersion',
      type: 'ai.device.type'
    )
  end
end
