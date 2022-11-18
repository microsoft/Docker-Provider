require_relative 'queue_base'

module ApplicationInsights
  module Channel
    # A synchronous queue for use in conjunction with the {SynchronousSender}.
    # The queue will call {SenderBase#send} when it reaches {#max_queue_length},
    # or when the consumer calls {#flush}.
    #
    # @example
    #   require 'application_insights'
    #   require 'thread'
    #   queue = ApplicationInsights::Channel::SynchronousQueue.new nil
    #   queue.max_queue_length = 1
    #   queue.push 1
    class SynchronousQueue < QueueBase
      # Initializes a new instance of the class.
      # @param [SenderBase] sender the sender object that will be used in
      #   conjunction with this queue.
      def initialize(sender)
        super sender
      end

      # Flushes the current queue by by calling {#sender}'s
      # {SenderBase#send} method.
      def flush
        local_sender = @sender
        return unless local_sender

        while true
          # get at most send_buffer_size items and send them
          data = []
          while data.length < local_sender.send_buffer_size
            item = pop()
            break if not item
            data.push item
          end

          break if data.length == 0

          local_sender.send(data)
        end
      end
    end
  end
end
