require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class RequestData
    include JsonSerializable

    attr_accessor :ver, :id, :source, :name, :duration, :response_code, :success,
      :url, :properties, :measurements

    attribute_mapping(
      ver: 'ver',
      id: 'id',
      source: 'source',
      name: 'name',
      duration: 'duration',
      response_code: 'responseCode',
      success: 'success',
      url: 'url',
      properties: 'properties',
      measurements: 'measurements'
    )

    def ver
      @ver ||= 2
    end

    def properties
      @properties ||= {}
    end

    def measurements
      @measurements ||= {}
    end
  end
end
