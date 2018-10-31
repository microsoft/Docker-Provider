require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class RemoteDependencyData
    include JsonSerializable

    attr_accessor :ver, :name, :id, :result_code, :duration, :success, :data,
      :target, :type, :properties, :measurements

    attribute_mapping(
      ver: 'ver',
      name: 'name',
      id: 'id',
      result_code: 'resultCode',
      duration: 'duration',
      success: 'success',
      data: 'data',
      target: 'target',
      type: 'type',
      properties: 'properties',
      measurements: 'measurements'
    )

    def ver
      @ver ||= 2
    end

    def success
      @success.nil? ? true : @success
    end

    def properties
      @properties ||= {}
    end

    def measurements
      @measurements ||= {}
    end
  end
end
