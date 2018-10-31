require_relative 'contracts/application'
require_relative 'contracts/cloud'
require_relative 'contracts/device'
require_relative 'contracts/user'
require_relative 'contracts/session'
require_relative 'contracts/operation'
require_relative 'contracts/location'

module ApplicationInsights
  module Channel
    # Represents the context for sending telemetry to the
    # Application Insights service.
    #
    # @example
    #   require 'application_insights'
    #   context = ApplicationInsights::Channel::TelemetryContext.new
    #   context.instrumentation_key = '<YOUR INSTRUMENTATION KEY GOES HERE>'
    #   context.application.id = 'My application'
    #   context.application.ver = '1.2.3'
    #   context.device.id = 'My current device'
    #   context.device.oem_name = 'Asus'
    #   context.device.model = 'X31A'
    #   context.device.type = "Other"
    #   context.user.id = 'santa@northpole.net'
    class TelemetryContext
      # Initializes a new instance of the class.
      def initialize
        @instrumentation_key = nil
        @application = Contracts::Application.new
        @cloud = Contracts::Cloud.new
        @device = Contracts::Device.new
        @user = Contracts::User.new
        @session = Contracts::Session.new
        @operation = Contracts::Operation.new
        @location = Contracts::Location.new
        @properties = {}
      end

      # The instrumentation key that is used to identify which
      # Application Insights application this data is for.
      # @return [String] the instrumentation key.
      attr_accessor :instrumentation_key

      # The application context. This contains properties of the
      # application you are running.
      # @return [Contracts::Application] the context object.
      attr_accessor :application

      # The cloud context. This contains properties of the
      # cloud role you are generating telemetry for.
      # @return [Contracts::Cloud] the context object.
      attr_accessor :cloud

      # The device context. This contains properties of the
      # device you are running on.
      # @return [Contracts::Device] the context object.
      attr_accessor :device

      # The user context. This contains properties of the
      # user you are generating telemetry for.
      # @return [Contracts::User] the context object.
      attr_accessor :user

      # The session context. This contains properties of the
      # session you are generating telemetry for.
      # @return [Contracts::Session] the context object.
      attr_accessor :session

      # The operation context. This contains properties of the
      # operation you are generating telemetry for.
      # @return [Contracts::Operation] the context object.
      attr_accessor :operation

      # The location context. This contains properties of the
      # location you are generating telemetry from.
      # @return [Contracts::Location] the context object.
      attr_accessor :location

      # The property context. This contains free-form properties
      # that you can add to your telemetry.
      # @return [Hash<String, String>] the context object.
      attr_accessor :properties
    end
  end
end
