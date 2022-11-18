# Copyright (c) Microsoft Corporation.  All rights reserved.

# frozen_string_literal: true

require 'fluent/plugin/filter'

module Fluent::Plugin
  require "logger"
  require "json"
  require_relative "oms_common"
  require_relative "kubelet_utils"
  require_relative "MdmMetricsGenerator"
  require_relative "constants"

  class Telegraf2MdmFilter < Filter
    Fluent::Plugin.register_filter("telegraf2mdm", self)

    config_param :enable_log, :integer, :default => 0
    config_param :log_path, :string, :default => "/var/opt/microsoft/docker-cimprov/log/filter_telegraf2mdm.log"

    @process_incoming_stream = true

    def initialize
      super
    end

    def configure(conf)
      super
      @log = nil

      if @enable_log
        @log = Logger.new(@log_path, 1, 5000000)
        @log.debug { "Starting filter_telegraf2mdm plugin" }
      end
    end

    def start
      super
      begin
        @process_incoming_stream = CustomMetricsUtils.check_custom_metrics_availability
        @log.debug "After check_custom_metrics_availability process_incoming_stream #{@process_incoming_stream}"
      rescue => errorStr
        @log.info "Error initializing plugin #{errorStr}"
      end
    end

    def shutdown
      super
    end

    def filter(tag, time, record)
      if @process_incoming_stream
        begin
          if !record.nil? && !record["name"].nil? && record["name"].downcase == Constants::TELEGRAF_DISK_METRICS
            return MdmMetricsGenerator.getDiskUsageMetricRecords(record)
          else
            return MdmMetricsGenerator.getMetricRecords(record)
          end
          return []
        rescue Exception => errorStr
          @log.info "Error processing telegraf record Exception: #{errorStr}"
          ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
          return [] #return empty array if we ran into any errors
        end
      end
    end

    def filter_stream(tag, es)
      new_es = Fluent::MultiEventStream.new
      begin
        es.each { |time, record|
          filtered_records = filter(tag, time, record)
          filtered_records.each { |filtered_record|
            new_es.add(time, filtered_record) if filtered_record
          } if filtered_records
        }
      rescue => e
        @log.info "Error in filter_stream #{e.message}"
      end
      new_es
    end
  end
end
