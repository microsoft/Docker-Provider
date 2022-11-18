require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class PageViewData
    include JsonSerializable

    attr_accessor :ver, :url, :name, :duration, :id, :referrer_uri, :properties,
      :measurements

    attribute_mapping(
      ver: 'ver',
      url: 'url',
      name: 'name',
      duration: 'duration',
      id: 'id',
      referrer_uri: 'referrerUri',
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
