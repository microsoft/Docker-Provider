require_relative 'sender_base'

module ApplicationInsights
  module Channel
    # A synchronous sender that works in conjunction with the {SynchronousQueue}.
    # The queue will call {#send} on the current instance with the data to send.
    class SynchronousSender < SenderBase
      SERVICE_ENDPOINT_URI = 'https://dc.services.visualstudio.com/v2/track'
      # Initializes a new instance of the class.
      # @param [String] service_endpoint_uri the address of the service to send
      # telemetry data to.
      def initialize(service_endpoint_uri = SERVICE_ENDPOINT_URI)
        super service_endpoint_uri
      end
    end
  end
end
