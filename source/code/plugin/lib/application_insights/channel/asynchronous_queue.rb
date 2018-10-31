require_relative 'event'
require_relative 'queue_base'

module ApplicationInsights
  module Channel
    # An asynchronous queue for use in conjunction with the {AsynchronousSender}.
    # The queue will notify the sender that it needs to pick up items when it
    # reaches {#max_queue_length}, or when the consumer calls {#flush} via the
    # {#flush_notification} event.
    #
    # @example
    #   require 'application_insights'
    #   require 'thread'
    #   queue = ApplicationInsights::Channel::AsynchronousQueue.new nil
    #   Thread.new do
    #     sleep 1
    #     queue.push 1
    #     queue.flush
    #   end
    #   queue.flush_notification.wait
    #   queue.flush_notification.clear
    #   result = queue.pop
    class AsynchronousQueue < QueueBase
      # Initializes a new instance of the class.
      # @param [SenderBase] sender the sender object that will be used in
      #   conjunction with this queue. In addition to the sender object must
      #   support a {AsynchronousSender#start} method which is invoked each time
      #   an item is pushed to the queue as well as use the {#flush_notification}
      #   event.
      def initialize(sender)
        @flush_notification = Event.new
        super sender
      end

      # The flush notification {ApplicationInsights::Channel::Event} that the {#sender}
      # will use to get notified that a flush is needed.
      # @return [Event] object that the {#sender} can wait on.
      attr_reader :flush_notification

      # Adds the passed in item object to the queue and notifies the {#sender}
      # to start an asynchronous send operation
      # by calling {AsynchronousSender#start}.
      # @param [Contracts::Envelope] item the telemetry envelope object to send
      #   to the service.
      def push(item)
        super item
        @sender.start if @sender
      end

      # Flushes the current queue by notifying the {#sender} via the
      # {#flush_notification} event.
      def flush
        @flush_notification.set
        @sender.start if @sender
      end
    end
  end
end
