require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class ExceptionDetails
    include JsonSerializable

    attr_accessor :id, :outer_id, :type_name, :message, :has_full_stack, :stack,
      :parsed_stack

    attribute_mapping(
      id: 'id',
      outer_id: 'outerId',
      type_name: 'typeName',
      message: 'message',
      has_full_stack: 'hasFullStack',
      stack: 'stack',
      parsed_stack: 'parsedStack'
    )

    def has_full_stack
      @has_full_stack.nil? ? true : @has_full_stack
    end

    def parsed_stack
      @parsed_stack ||= []
    end
  end
end
