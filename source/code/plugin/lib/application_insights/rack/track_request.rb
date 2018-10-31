require 'rack'
require 'securerandom'
require_relative '../channel/contracts/request_data'
require_relative '../telemetry_client'

module ApplicationInsights
  module Rack
    # Track every request and sends the request data to Application Insights.
    class TrackRequest
      # Initializes a new instance of the class.
      # @param [Object] app the inner rack application.
      # @param [String] instrumentation_key to identify which Application Insights
      #   application this data is for.
      # @param [Fixnum] buffer_size the buffer size and the buffered requests would
      #   send to Application Insights when buffer is full.
      # @param [Fixnum] send_interval the frequency (in seconds) to check buffer
      #   and send buffered requests to Application Insights if any.
      def initialize(app, instrumentation_key, buffer_size = 500, send_interval = 60)
        @app = app
        @instrumentation_key = instrumentation_key
        @buffer_size = buffer_size
        @send_interval = send_interval

        @sender = Channel::AsynchronousSender.new
        @sender.send_interval = @send_interval
        queue = Channel::AsynchronousQueue.new @sender
        queue.max_queue_length = @buffer_size
        @channel = Channel::TelemetryChannel.new nil, queue

        @client = TelemetryClient.new @instrumentation_key, @channel
      end

      # Track requests and send data to Application Insights asynchronously.
      # @param [Hash] env the rack environment.
      def call(env)
        # Build a request ID, incorporating one from our request if one exists.
        request_id = request_id_header(env['HTTP_REQUEST_ID'])
        env['ApplicationInsights.request.id'] = request_id

        start = Time.now
        begin
          status, headers, response = @app.call(env)
        rescue Exception => ex
          status = 500
          exception = ex
        end
        stop = Time.now

        start_time = start.iso8601(7)
        duration = format_request_duration(stop - start)
        success = status.to_i < 400

        request = ::Rack::Request.new env
        options = options_hash(request)

        data = request_data(request_id, start_time, duration, status, success, options)
        context = telemetry_context(request_id, env['HTTP_REQUEST_ID'])

        @client.channel.write data, context, start_time

        if exception
          @client.track_exception exception, handled_at: 'Unhandled'
          raise exception
        end

        [status, headers, response]
      end

      private

      def sender=(sender)
        if sender.is_a? Channel::AsynchronousSender
          @sender = sender
          @client.channel.queue.sender = @sender
        end
      end

      def client
        @client
      end

      def format_request_duration(duration_seconds)
        if duration_seconds >= 86400
          # just return 1 day when it takes more than 1 day which should not happen for requests.
          return "%02d.%02d:%02d:%02d.%07d" % [1, 0, 0, 0, 0]
        end

        Time.at(duration_seconds).gmtime.strftime("00.%H:%M:%S.%7N")
      end

      def request_id_header(request_id)
        valid_request_id_header = valid_request_id(request_id)

        length = valid_request_id_header ? 5 : 10
        id = SecureRandom.base64(length)

        if valid_request_id_header
          request_id_has_end = %w[. _].include?(request_id[-1])
          request_id << '.' unless request_id_has_end

          return "#{request_id}#{id}_"
        end

        "|#{id}."
      end

      def valid_request_id(request_id)
        request_id && request_id[0] == '|'
      end

      def operation_id(id)
        # Returns the root ID from the '|' to the first '.' if any.
        root_start = id[0] == '|' ? 1 : 0

        root_end = id.index('.')
        root_end = root_end ? root_end - 1 : id.length - root_start

        id[root_start..root_end]
      end

      def options_hash(request)
        {
            name: "#{request.request_method} #{request.path}",
            http_method: request.request_method,
            url: request.url
        }
      end

      def request_data(request_id, start_time, duration, status, success, options)
        Channel::Contracts::RequestData.new(
            :id => request_id || 'Null',
            :duration => duration || '0:00:00:00.0000000',
            :response_code => status || 200,
            :success => success == nil ? true : success,
            :name => options[:name],
            :url => options[:url],
            :properties => options[:properties] || {},
            :measurements => options[:measurements] || {},
            # Must initialize http_method after properties because it's actually stored in properties
            :http_method => options[:http_method]
        )
      end

      def telemetry_context(request_id, request_id_header)
        context = Channel::TelemetryContext.new
        context.instrumentation_key = @instrumentation_key
        context.operation.id = operation_id(request_id)
        context.operation.parent_id = request_id_header

        context
      end
    end
  end
end
