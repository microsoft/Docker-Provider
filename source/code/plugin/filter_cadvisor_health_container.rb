#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent
    require 'logger'
    require 'json'
    require_relative 'oms_common'
    require_relative "ApplicationInsightsUtility"
    Dir[File.join(__dir__, './health', '*.rb')].each { |file| require file }


    class CAdvisor2ContainerHealthFilter < Filter
        include HealthModel
        Fluent::Plugin.register_filter('filter_cadvisor_health_container', self)

        config_param :log_path, :string, :default => '/var/opt/microsoft/docker-cimprov/log/health_monitors.log'
        config_param :metrics_to_collect, :string, :default => 'cpuUsageNanoCores,memoryRssBytes'
        config_param :container_resource_refresh_interval_minutes, :integer, :default => 5

        @@object_name_k8s_container = 'K8SContainer'
        @@counter_name_cpu = 'cpuusagenanocores'
        @@counter_name_memory_rss = 'memoryrssbytes'

        def initialize
            begin
                super
                @metrics_to_collect_hash = {}
                @formatter = HealthContainerCpuMemoryRecordFormatter.new
            rescue => e
                @log.info "Error in filter_cadvisor_health_container initialize #{e.backtrace}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
            end
        end

        def configure(conf)
            begin
                super
                @log = HealthMonitorUtils.get_log_handle
                @log.debug {'Starting filter_cadvisor2health plugin'}
            rescue => e
                @log.info "Error in filter_cadvisor_health_container configure #{e.backtrace}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
            end
        end

        def start
            begin
                super
                @metrics_to_collect_hash = HealthMonitorUtils.build_metrics_hash(@metrics_to_collect)
                ApplicationInsightsUtility.sendCustomEvent("filter_cadvisor_health_container Plugin Start", {})
            rescue => e
                @log.info "Error in filter_cadvisor_health_container start #{e.backtrace}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
            end
        end

        def filter_stream(tag, es)
            new_es = MultiEventStream.new
            records_count = 0
            es.each { |time, record|
              begin
                filtered_record = filter(tag, time, record)
                if !filtered_record.nil?
                    new_es.add(time, filtered_record)
                    records_count += 1
                end
              rescue => e
                @log.info "Error in filter_cadvisor_health_container filter_stream #{e.backtrace}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
              end
            }
            @log.debug "filter_cadvisor_health_container Records Count #{records_count}"
            new_es
        end

        def filter(tag, time, record)
            begin
                if record.key?("MonitorLabels")
                    return record
                end
                object_name = record['DataItems'][0]['ObjectName']
                counter_name = record['DataItems'][0]['Collections'][0]['CounterName'].downcase
                if @metrics_to_collect_hash.key?(counter_name)
                    if object_name == @@object_name_k8s_container
                        return @formatter.get_record_from_cadvisor_record(record)
                    end
                end
                return nil
            rescue => e
                @log.debug "Error in filter #{e}"
                @log.debug "record #{record}"
                @log.debug "backtrace #{e.backtrace}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
                return nil
            end
        end
    end
end
