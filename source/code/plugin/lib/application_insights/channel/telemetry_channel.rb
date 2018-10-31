require 'time'
require_relative 'asynchronous_queue'
require_relative 'asynchronous_sender'
require_relative 'telemetry_context'
require_relative 'synchronous_queue'
require_relative 'synchronous_sender'
require_relative 'contracts/envelope'
require_relative 'contracts/data'
require_relative 'contracts/internal'
require_relative '../../application_insights/version'

module ApplicationInsights
  module Channel
    # The telemetry channel is responsible for constructing a
    # {Contracts::Envelope} object from the passed in data and specified
    # telemetry context.
    #
    # @example
    #   require 'application_insights'
    #   channel = ApplicationInsights::Channel::TelemetryChannel.new
    #   event = ApplicationInsights::Channel::Contracts::EventData.new name: 'My event'
    #   channel.write event
    class TelemetryChannel
      # Initializes a new instance of the class.
      # @param [TelemetryContext] context the telemetry context to use when
      #   sending telemetry data.
      # @param [QueueBase] queue the queue to enqueue the resulting
      #   {Contracts::Envelope} to.
      def initialize(context=nil, queue=nil)
        @context = context || TelemetryContext.new
        @queue = queue || SynchronousQueue.new(SynchronousSender.new)
      end

      # The context associated with this channel. All {Contracts::Envelope}
      # objects created by this channel will use this value if it's present or if
      # none is specified as part of the {#write} call.
      # @return [TelemetryContext] the context instance
      #   (defaults to: TelemetryContext.new)
      attr_reader :context

      # The queue associated with this channel. All {Contracts::Envelope} objects
      # created by this channel will be pushed to this queue.
      # @return [QueueBase] the queue instance (defaults to: SynchronousQueue.new)
      attr_reader :queue

      # The sender associated with this channel. This instance will be used to
      # transmit telemetry to the service.
      # @return [SenderBase] the sender instance (defaults to: SynchronousSender.new)
      def sender
        @queue.sender
      end

      # Flushes the enqueued data by calling {QueueBase#flush}.
      def flush
        @queue.flush
      end

      # Enqueues the passed in data to the {#queue}. If the caller specifies a
      # context as well, it will take precedence over the instance in {#context}.
      # @param [Object] data the telemetry data to send. This will be wrapped in
      #   an {Contracts::Envelope} before being enqueued to the {#queue}.
      # @param [TelemetryContext] context the override context to use when
      #   constructing the {Contracts::Envelope}.
      # @param [Time|String] time the timestamp of the telemetry used to construct the
      #   {Contracts::Envelope}.
      def write(data, context=nil, time=nil)
        local_context = context || @context
        raise ArgumentError, 'Context was required but not provided' unless local_context

        if time && time.is_a?(String)
          local_time = time
        elsif time && time.is_a?(Time)
          local_time = time.iso8601(7)
        else
          local_time = Time.now.iso8601(7)
        end

        data_type = data.class.name.gsub(/^.*::/, '')
        set_properties data, local_context
        data_attributes = {
            :base_type => data_type,
            :base_data => data
        }
        envelope_attributes = {
          :name => 'Microsoft.ApplicationInsights.' + data_type[0..-5],
          :time => local_time,
          :i_key => local_context.instrumentation_key,
          :tags => get_tags(local_context),
          :data => Contracts::Data.new(data_attributes)
        }
        envelope = Contracts::Envelope.new envelope_attributes
        @queue.push(envelope)
      end

      private

      def get_tags(context)
        hash = {}
        internal_context_attributes = {
          :sdk_version => 'rb:' + ApplicationInsights::VERSION
        }
        internal_context = Contracts::Internal.new internal_context_attributes

        [internal_context,
          context.application,
          context.cloud,
          context.device,
          context.user,
          context.session,
          context.location,
          context.operation].each { |c|  hash.merge!(c.to_h) if c }

        hash.delete_if { |k, v| v.nil? }

        hash
      end

      def set_properties(data, context)
        if context.properties
          properties = data.properties || {}
          context.properties.each do |key, value|
            unless properties.key?(key)
              properties[key] = value
            end
          end
          data.properties = properties
        end
      end
    end
  end
end
