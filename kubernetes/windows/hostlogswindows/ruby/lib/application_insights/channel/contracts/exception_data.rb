require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class ExceptionData
    include JsonSerializable

    attr_accessor :ver, :exceptions, :severity_level, :problem_id, :properties,
      :measurements

    attribute_mapping(
      ver: 'ver',
      exceptions: 'exceptions',
      severity_level: 'severityLevel',
      problem_id: 'problemId',
      properties: 'properties',
      measurements: 'measurements'
    )

    def ver
      @ver ||= 2
    end

    def exceptions
      @exceptions ||= []
    end

    def properties
      @properties ||= {}
    end

    def measurements
      @measurements ||= {}
    end
  end
end
