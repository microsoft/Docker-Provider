require_relative 'json_serializable'
require_relative 'data_point_type'

module ApplicationInsights::Channel::Contracts
  class DataPoint
    include JsonSerializable

    attr_accessor :ns, :name, :kind, :value, :count, :min, :max, :std_dev

    attribute_mapping(
      ns: 'ns',
      name: 'name',
      kind: 'kind',
      value: 'value',
      count: 'count',
      min: 'min',
      max: 'max',
      std_dev: 'stdDev'
    )

    def kind
      @kind ||= DataPointType::MEASUREMENT
    end
  end
end
