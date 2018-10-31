require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class Envelope
    include JsonSerializable

    attr_accessor :ver, :name, :time, :sample_rate, :seq, :i_key, :tags, :data

    attribute_mapping(
      ver: 'ver',
      name: 'name',
      time: 'time',
      sample_rate: 'sampleRate',
      seq: 'seq',
      i_key: 'iKey',
      tags: 'tags',
      data: 'data'
    )

    def ver
      @ver ||= 1
    end

    def sample_rate
      @sample_rate ||= 100.0
    end

    def tags
      @tags ||= {}
    end
  end
end
