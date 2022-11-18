require_relative 'queue_base'
require 'thread'

module ApplicationInsights
  module Channel
    # An event class that allows simple cross-thread signalling.
    #
    # An object of this type managers an internal flag that can be set to true
    # via the {#set} method and reset via the {#clear} method. Calling the
    # {#wait} method will block until the flag is set to true.
    #
    # @example
    #   require 'application_insights'
    #   require 'thread'
    #   event = ApplicationInsights::Channel::Event.new
    #   Thread.new do
    #     sleep 1
    #     event.set
    #   end
    #   puts 'Main screen turn on.'
    #   result = event.wait
    #   puts 'All your base are belong to us.'
    class Event
      # Initializes a new instance of the class.
      def initialize
        @mutex = Mutex.new
        @condition_variable = ConditionVariable.new
        @signal = false
      end

      # The signal value for this object. Note that the value of this property is
      # not synchronized with respect to {#set} and {#clear} meaning that it
      # could return false positives or negatives.
      # @return [Boolean] the signal value.
      attr_reader :signal

      # Sets the internal flag to true. Calling this method will also cause all
      # waiting threads to awaken.
      def set
        @mutex.synchronize do
          @signal = true
          @condition_variable.broadcast
        end
      end

      # Sets the internal flag to false.
      def clear
        @mutex.synchronize do
          @signal = false
        end
      end

      # Calling this method will block until the internal flag is set to true.
      # If the flag is set to true before calling this method, we will return
      # immediately. If the timeout parameter is specified, the method will
      # unblock after the specified number of seconds.
      # @param [Fixnum] timeout the timeout for the operation in seconds.
      # @return [Boolean] the value of the internal flag on exit.
      def wait(timeout=nil)
        @mutex.synchronize do
          @condition_variable.wait(@mutex, timeout) unless @signal
        end

        @signal
      end
    end
  end
end
