require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class PageViewPerfData
    include JsonSerializable

    attr_accessor :ver, :url, :perf_total, :name, :duration, :network_connect,
      :sent_request, :received_response, :id, :dom_processing, :referrer_uri,
      :properties, :measurements

    attribute_mapping(
      ver: 'ver',
      url: 'url',
      perf_total: 'perfTotal',
      name: 'name',
      duration: 'duration',
      network_connect: 'networkConnect',
      sent_request: 'sentRequest',
      received_response: 'receivedResponse',
      id: 'id',
      dom_processing: 'domProcessing',
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
