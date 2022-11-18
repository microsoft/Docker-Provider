require_relative "sender_base"

module ApplicationInsights
  module Channel
    # A synchronous sender that works in conjunction with the {SynchronousQueue}.
    # The queue will call {#send} on the current instance with the data to send.
    class SynchronousSender < SenderBase
      SERVICE_ENDPOINT_URI = "https://dc.services.visualstudio.com/v2/track"
      # Initializes a new instance of the class.
      # @param [String] service_endpoint_uri the address of the service to send
      # @param [Logger] instance of the logger to write the logs (optional)
      # @param [Hash] proxy server configuration to send (optional)
      # telemetry data to.
      def initialize(service_endpoint_uri = SERVICE_ENDPOINT_URI, logger = nil, proxy = {})
        # callers which requires proxy dont require to maintain service endpoint uri which potentially can change
        if service_endpoint_uri.nil? || service_endpoint_uri.empty?
          service_endpoint_uri = SERVICE_ENDPOINT_URI
        end
        super service_endpoint_uri, logger, proxy
      end
    end
  end
end
