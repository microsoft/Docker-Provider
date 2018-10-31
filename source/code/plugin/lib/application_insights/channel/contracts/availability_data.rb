require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class AvailabilityData
    include JsonSerializable

    attr_accessor :ver, :id, :name, :duration, :success, :run_location, :message,
      :properties, :measurements

    attribute_mapping(
      ver: 'ver',
      id: 'id',
      name: 'name',
      duration: 'duration',
      success: 'success',
      run_location: 'runLocation',
      message: 'message',
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
