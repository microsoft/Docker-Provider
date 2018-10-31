require_relative 'telemetry_client'
require_relative 'channel/telemetry_channel'
require_relative 'channel/synchronous_queue'
require_relative 'channel/synchronous_sender'

include ApplicationInsights

module ApplicationInsights
  module UnhandledException
    @sender = nil

    # Auto collects unhandled exception and send to the Application Insights service.
    # @param (string) instrumentation_key used to identify which Application
    #   Insights application this data is for.
    # @example
    #   require 'application_insights'
    #   ApplicationInsights::UnhandledException.collect('<YOUR INSTRUMENTATION KEY GOES HERE>')
    #   raise Exception, 'Boom!'
    def self.collect(instrumentation_key)
      at_exit do
        # Avoid sending exception more than once if this method got invoked multiple times
        send(instrumentation_key) unless @sender
      end
    end

    # @api private
    # Send the last raised exception to the Application Insights service if
    # telemetry_sender is not customized.
    # @param (string) instrumentation_key used to identify which Application
    #   Insights application this data is for.
    # @param (SenderBase) telemetry_sender used to send the last raised exception.
    def self.send(instrumentation_key, telemetry_sender = nil)
      if $! && !$!.is_a?(SystemExit) && !$!.is_a?(SignalException)
        if telemetry_sender
          @sender = telemetry_sender
        elsif !@sender
          # Use a synchronized sender to guarantee the data would be sent out once flush
          @sender = Channel::SynchronousSender.new
        end

        queue = Channel::SynchronousQueue.new @sender
        channel = Channel::TelemetryChannel.new nil, queue
        client = TelemetryClient.new instrumentation_key, channel
        client.track_exception($!, handled_at: 'Unhandled')
        client.flush
      end
    end
  end
end
