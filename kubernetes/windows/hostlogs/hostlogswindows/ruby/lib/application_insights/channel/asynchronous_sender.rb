require_relative "sender_base"
require "thread"

module ApplicationInsights
  module Channel
    # An asynchronous sender that works in conjunction with the {AsynchronousQueue}.
    # The sender object will start a worker thread that will pull items from the
    # {#queue}. The thread will be created when the client calls {#start} and
    # will check for queue items every {#send_interval} seconds. The worker thread
    # can also be forced to check the queue by setting the
    # {AsynchronousQueue#flush_notification} event.
    #
    # - If no items are found, the thread will go back to sleep.
    # - If items are found, the worker thread will send items to the specified
    #   service in batches of {#send_buffer_size}.
    #
    # If no queue items are found for {#send_time} seconds,  the worker thread
    # will shut down (and {#start} will need  to be called again).
    class AsynchronousSender < SenderBase
      SERVICE_ENDPOINT_URI = "https://dc.services.visualstudio.com/v2/track"
      # Initializes a new instance of the class.
      # @param [String] service_endpoint_uri the address of the service to send
      # @param [Logger] instance of the logger to write the logs (optional)
      # @param [Hash] proxy server configuration to send (optional)
      #   telemetry data to.
      def initialize(service_endpoint_uri = SERVICE_ENDPOINT_URI, logger = nil, proxy = {})
        # callers which requires proxy dont require to maintain service endpoint uri which potentially can change
        if service_endpoint_uri.nil? || service_endpoint_uri.empty?
          service_endpoint_uri = SERVICE_ENDPOINT_URI
        end
        @send_interval = 1.0
        @send_remaining_time = 0
        @send_time = 3.0
        @lock_work_thread = Mutex.new
        @work_thread = nil
        @start_notification_processed = true
        super service_endpoint_uri, logger, proxy
      end

      # The time span in seconds at which the the worker thread will check the
      # {#queue} for items (defaults to: 1.0).
      # @return [Fixnum] the interval in seconds.
      attr_accessor :send_interval

      # The time span in seconds for which the worker thread will stay alive if
      # no items are found in the {#queue} (defaults to 3.0).
      # @return [Fixnum] the interval in seconds.
      attr_accessor :send_time

      # The worker thread which checks queue items and send data every
      # (#send_interval) seconds or upon flush.
      # @return [Thread] the work thread
      attr_reader :work_thread

      # Calling this method will create a worker thread that checks the {#queue}
      # every {#send_interval} seconds for a total duration of {#send_time}
      # seconds for new items. If a worker thread has already been created,
      # calling this method does nothing.
      def start
        @start_notification_processed = false
        # Maintain one working thread at one time
        unless @work_thread
          @lock_work_thread.synchronize do
            unless @work_thread
              local_send_interval = [@send_interval, 0.1].max
              @send_remaining_time = [@send_time, local_send_interval].max
              @work_thread = Thread.new { run }
              @work_thread.abort_on_exception = false
            end
          end
        end
      end

      private

      def run
        # save the queue locally
        local_queue = @queue
        if local_queue.nil?
          @work_thread = nil
          return
        end

        begin
          # fix up the send interval (can't be lower than 100ms)
          local_send_interval = [@send_interval, 0.1].max

          while true
            @start_notification_processed = true
            while true
              # get at most @send_buffer_size items from the queue
              data = []
              @send_buffer_size.downto(1) do
                item = local_queue.pop
                break if not item
                data.push item
              end

              # if we didn't get any items from the queue, we're done here
              break if data.length == 0

              # reset the send time
              @send_remaining_time = @send_time

              # finally send the data
              send data
            end

            # wait at most @send_interval ms (or until we get signalled)
            result = local_queue.flush_notification.wait local_send_interval
            if result
              local_queue.flush_notification.clear
              next
            end

            # decrement the remaining time
            @send_remaining_time -= local_send_interval
            # If remaining time <=0 and there is no start notification unprocessed,
            # then stop the working thread
            if @send_remaining_time <= 0 && @start_notification_processed
              # Note: there is still a chance some start notification could be
              # missed, e.g., the start method got triggered between the above and
              # following line. However the data is not lost as it would be
              # processed later when next start notification comes after the worker
              # thread stops. The cost to ensure no notification miss is high where
              # a lock is required each time the start method calls.
              @work_thread = nil
              break
            end
          end
        rescue Exception => e
          # Make sure work_thread sets to nil when it terminates abnormally
          @work_thread = nil
          @logger.error("application_insights") { "Asynchronous sender work thread terminated abnormally: #{e.to_s}" }
        end
      end
    end
  end
end
