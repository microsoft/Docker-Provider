#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent
    require 'logger'
    require 'json'
    require_relative 'oms_common'
    require_relative "ApplicationInsightsUtility"
    require_relative "KubernetesApiClient"
    Dir[File.join(__dir__, './health', '*.rb')].each { |file| require file }

    class CAdvisor2NodeHealthFilter < Filter
        include HealthModel
        Fluent::Plugin.register_filter('filter_cadvisor_health_node', self)

        attr_accessor :provider, :resources

        config_param :metrics_to_collect, :string, :default => 'cpuUsageNanoCores,memoryRssBytes'
        config_param :container_resource_refresh_interval_minutes, :integer, :default => 5
        config_param :health_monitor_config_path, :default => '/etc/opt/microsoft/docker-cimprov/health/healthmonitorconfig.json'

        @@object_name_k8s_node = 'K8SNode'
        @@object_name_k8s_container = 'K8SContainer'

        @@counter_name_cpu = 'cpuusagenanocores'
        @@counter_name_memory_rss = 'memoryrssbytes'

        @@hm_log = HealthMonitorUtils.get_log_handle
        @@hostName = (OMS::Common.get_hostname)
        @@clusterName = KubernetesApiClient.getClusterName
        @@clusterId = KubernetesApiClient.getClusterId
        @@clusterRegion = KubernetesApiClient.getClusterRegion

        def initialize
            begin
                super
                @last_resource_refresh = DateTime.now.to_time.to_i
                @metrics_to_collect_hash = {}
                @resources = HealthKubernetesResources.instance # this doesnt require node and pod inventory. So no need to populate them
                @provider = HealthMonitorProvider.new(@@clusterId, HealthMonitorUtils.get_cluster_labels, @resources, @health_monitor_config_path)
            rescue => e
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
            end
        end

        def configure(conf)
            begin
                super
                @log = HealthMonitorUtils.get_log_handle
                @log.debug {'Starting filter_cadvisor2health plugin'}
            rescue => e
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
            end
        end

        def start
            begin
                super
                @cpu_capacity = 1.0 #avoid divide by zero error in case of network issues accessing kube-api
                @memory_capacity = 1.0
                @metrics_to_collect_hash = HealthMonitorUtils.build_metrics_hash(@metrics_to_collect)
                @log.debug "Calling ensure_cpu_memory_capacity_set cpu_capacity #{@cpu_capacity} memory_capacity #{@memory_capacity}"
                node_capacity = HealthMonitorUtils.ensure_cpu_memory_capacity_set(@@hm_log, @cpu_capacity, @memory_capacity, @@hostName)
                @cpu_capacity = node_capacity[0]
                @memory_capacity = node_capacity[1]
                @log.info "CPU Capacity #{@cpu_capacity} Memory Capacity #{@memory_capacity}"
                #HealthMonitorUtils.refresh_kubernetes_api_data(@log, @@hostName)
                ApplicationInsightsUtility.sendCustomEvent("filter_cadvisor_health Plugin Start", {})
            rescue => e
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
            end
        end

        def filter_stream(tag, es)
            begin
                node_capacity = HealthMonitorUtils.ensure_cpu_memory_capacity_set(@@hm_log, @cpu_capacity, @memory_capacity, @@hostName)
                @cpu_capacity = node_capacity[0]
                @memory_capacity = node_capacity[1]
                new_es = MultiEventStream.new
                records_count = 0
                es.each { |time, record|
                filtered_record = filter(tag, time, record)
                if !filtered_record.nil?
                    new_es.add(time, filtered_record)
                    records_count += 1
                end
                }
                @log.debug "Filter Records Count #{records_count}"
                return new_es
            rescue => e
                @log.info "Error in filter_cadvisor_health_node filter_stream #{e.backtrace}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
                return MultiEventStream.new
            end
        end

        def filter(tag, time, record)
            begin
                if record.key?("MonitorLabels")
                    return record
                end

                object_name = record['DataItems'][0]['ObjectName']
                counter_name = record['DataItems'][0]['Collections'][0]['CounterName'].downcase
                if @metrics_to_collect_hash.key?(counter_name.downcase)
                    metric_value = record['DataItems'][0]['Collections'][0]['Value']
                    case object_name
                    when @@object_name_k8s_node
                        case counter_name.downcase
                        when @@counter_name_cpu
                            process_node_cpu_record(record, metric_value)
                        when @@counter_name_memory_rss
                            process_node_memory_record(record, metric_value)
                        end
                    end
                end
            rescue => e
                @log.debug "Error in filter #{e}"
                @log.debug "record #{record}"
                @log.debug "backtrace #{e.backtrace}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e)
                return nil
            end
        end

        def process_node_cpu_record(record, metric_value)
            monitor_id = MonitorId::NODE_CPU_MONITOR_ID
            #@log.debug "processing node cpu record"
            if record.nil?
                return nil
            else
                instance_name = record['DataItems'][0]['InstanceName']
                #@log.info "CPU capacity #{@cpu_capacity}"

                percent = (metric_value.to_f/@cpu_capacity*100).round(2)
                #@log.debug "Percentage of CPU limit: #{percent}"
                state = HealthMonitorUtils.compute_percentage_state(percent, @provider.get_config(MonitorId::NODE_CPU_MONITOR_ID))
                #@log.debug "Computed State : #{state}"
                timestamp = record['DataItems'][0]['Timestamp']
                health_monitor_record = {"timestamp" => timestamp, "state" => state, "details" => {"cpuUsageMillicores" => metric_value/1000000.to_f, "cpuUtilizationPercentage" => percent}}

                monitor_instance_id = HealthMonitorUtils.get_monitor_instance_id(monitor_id, [@@clusterId, @@hostName])
                # temp = record.nil? ? "Nil" : record["MonitorInstanceId"]
                health_record = {}
                time_now = Time.now.utc.iso8601
                health_record[HealthMonitorRecordFields::MONITOR_ID] = monitor_id
                health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
                health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
                health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
                health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
                health_record[HealthMonitorRecordFields::NODE_NAME] =  @@hostName
                @log.info "Processed Node CPU"
                return health_record
            end
            return nil
        end

        def process_node_memory_record(record, metric_value)
            monitor_id = MonitorId::NODE_MEMORY_MONITOR_ID
            #@log.debug "processing node memory record"
            if record.nil?
                return nil
            else
                instance_name = record['DataItems'][0]['InstanceName']
                #@log.info "Memory capacity #{@memory_capacity}"

                percent = (metric_value.to_f/@memory_capacity*100).round(2)
                #@log.debug "Percentage of Memory limit: #{percent}"
                state = HealthMonitorUtils.compute_percentage_state(percent, @provider.get_config(MonitorId::NODE_MEMORY_MONITOR_ID))
                #@log.debug "Computed State : #{state}"
                timestamp = record['DataItems'][0]['Timestamp']
                health_monitor_record = {"timestamp" => timestamp, "state" => state, "details" => {"memoryRssBytes" => metric_value.to_f, "memoryUtilizationPercentage" => percent}}
                #@log.info health_monitor_record

                monitor_instance_id = HealthMonitorUtils.get_monitor_instance_id(monitor_id, [@@clusterId, @@hostName])
                health_record = {}
                time_now = Time.now.utc.iso8601
                health_record[HealthMonitorRecordFields::MONITOR_ID] = monitor_id
                health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
                health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
                health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
                health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
                health_record[HealthMonitorRecordFields::NODE_NAME] =  @@hostName
                @log.info "Processed Node Memory"
                return health_record
            end
            return nil
        end
    end
end
