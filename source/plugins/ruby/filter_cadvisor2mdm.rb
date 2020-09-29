# Copyright (c) Microsoft Corporation.  All rights reserved.

# frozen_string_literal: true

module Fluent
  require "logger"
  require "yajl/json_gem"
  require_relative "oms_common"
  require_relative "CustomMetricsUtils"
  require_relative "kubelet_utils"
  require_relative "MdmMetricsGenerator"

  class CAdvisor2MdmFilter < Filter
    Fluent::Plugin.register_filter("filter_cadvisor2mdm", self)

    config_param :enable_log, :integer, :default => 0
    config_param :log_path, :string, :default => "/var/opt/microsoft/docker-cimprov/log/filter_cadvisor2mdm.log"
    config_param :custom_metrics_azure_regions, :string
    config_param :metrics_to_collect, :string, :default => "Constants::CPU_USAGE_NANO_CORES,Constants::MEMORY_WORKING_SET_BYTES,Constants::MEMORY_RSS_BYTES,Constants::PV_USED_BYTES"

    @@hostName = (OMS::Common.get_hostname)

    @process_incoming_stream = true
    @metrics_to_collect_hash = {}

    @@metric_threshold_hash = {}

    def initialize
      super
    end

    def configure(conf)
      super
      @log = nil

      if @enable_log
        @log = Logger.new(@log_path, 1, 5000000)
        @log.debug { "Starting filter_cadvisor2mdm plugin" }
      end
    end

    def start
      super
      begin
        @process_incoming_stream = CustomMetricsUtils.check_custom_metrics_availability(@custom_metrics_azure_regions)
        @metrics_to_collect_hash = build_metrics_hash
        @log.debug "After check_custom_metrics_availability process_incoming_stream #{@process_incoming_stream}"
        @@containerResourceUtilTelemetryTimeTracker = DateTime.now.to_time.to_i
        @@pvUsageTelemetryTimeTracker = DateTime.now.to_time.to_i

        # These variables keep track if any resource utilization threshold exceeded in the last 10 minutes
        @containersExceededCpuThreshold = false
        @containersExceededMemRssThreshold = false
        @containersExceededMemWorkingSetThreshold = false
        @pvExceededUsageThreshold = false

        # initialize cpu and memory limit
        if @process_incoming_stream
          @cpu_capacity = 0.0
          @memory_capacity = 0.0
          ensure_cpu_memory_capacity_set
          @containerCpuLimitHash = {}
          @containerMemoryLimitHash = {}
          @containerResourceDimensionHash = {}
          @pvUsageHash = {}
          @@metric_threshold_hash = MdmMetricsGenerator.getContainerResourceUtilizationThresholds
        end
      rescue => e
        @log.info "Error initializing plugin #{e}"
      end
    end

    def build_metrics_hash
      @log.debug "Building Hash of Metrics to Collect"
      metrics_to_collect_arr = @metrics_to_collect.split(",").map(&:strip)
      metrics_hash = metrics_to_collect_arr.map { |x| [x.downcase, true] }.to_h
      @log.info "Metrics Collected : #{metrics_hash}"
      return metrics_hash
    end

    def shutdown
      super
    end

    def setThresholdExceededTelemetry(metricName)
      begin
        if metricName == Constants::CPU_USAGE_NANO_CORES
          @containersExceededCpuThreshold = true
        elsif metricName == Constants::MEMORY_RSS_BYTES
          @containersExceededMemRssThreshold = true
        elsif metricName == Constants::MEMORY_WORKING_SET_BYTES
          @containersExceededMemWorkingSetThreshold = true
        elsif metricName == Constants::PV_USED_BYTES
          @pvExceededUsageThreshold = true
        end
      rescue => errorStr
        @log.info "Error in setThresholdExceededTelemetry: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def flushMetricTelemetry
      begin
        #Send heartbeat telemetry with threshold percentage as dimensions
        timeDifference = (DateTime.now.to_time.to_i - @@containerResourceUtilTelemetryTimeTracker).abs
        timeDifferenceInMinutes = timeDifference / 60
        if (timeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
          properties = {}
          properties["CpuThresholdPercentage"] = @@metric_threshold_hash[Constants::CPU_USAGE_NANO_CORES]
          properties["MemoryRssThresholdPercentage"] = @@metric_threshold_hash[Constants::MEMORY_RSS_BYTES]
          properties["MemoryWorkingSetThresholdPercentage"] = @@metric_threshold_hash[Constants::MEMORY_WORKING_SET_BYTES]
          # Keeping track of any containers that have exceeded threshold in the last flush interval
          properties["CpuThresholdExceededInLastFlushInterval"] = @containersExceededCpuThreshold
          properties["MemRssThresholdExceededInLastFlushInterval"] = @containersExceededMemRssThreshold
          properties["MemWSetThresholdExceededInLastFlushInterval"] = @containersExceededMemWorkingSetThreshold
          ApplicationInsightsUtility.sendCustomEvent(Constants::CONTAINER_RESOURCE_UTIL_HEART_BEAT_EVENT, properties)
          @containersExceededCpuThreshold = false
          @containersExceededMemRssThreshold = false
          @containersExceededMemWorkingSetThreshold = false
          @@containerResourceUtilTelemetryTimeTracker = DateTime.now.to_time.to_i
        end
      rescue => errorStr
        @log.info "Error in flushMetricTelemetry: #{errorStr} for container resource util telemetry"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end

      # Also send for PV usage metrics
      begin
        pvTimeDifference = (DateTime.now.to_time.to_i - @@pvUsageTelemetryTimeTracker).abs
        pvTimeDifferenceInMinutes = pvTimeDifference / 60
        if (pvTimeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
          pvProperties = {}
          pvProperties["PVUsageThresholdPercentage"] = @@metric_threshold_hash[Constants::PV_USED_BYTES]
          pvProperties["PVUsageThresholdExceededInLastFlushInterval"] = @pvExceededUsageThreshold
          ApplicationInsightsUtility.sendCustomEvent(Constants::PV_USAGE_HEART_BEAT_EVENT, pvProperties)
          @pvExceededUsageThreshold = false
          @@pvUsageTelemetryTimeTracker = DateTime.now.to_time.to_i
        end
      rescue => errorStr
        @log.info "Error in flushMetricTelemetry: #{errorStr} for PV usage telemetry"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def filter(tag, time, record)
      begin
        if @process_incoming_stream

          # Check if insights metrics for PV metrics
          data_type = record["DataType"]
          if data_type == "INSIGHTS_METRICS_BLOB"
            return filterPVInsightsMetrics(record)
          end

          object_name = record["DataItems"][0]["ObjectName"]
          counter_name = record["DataItems"][0]["Collections"][0]["CounterName"]
          percentage_metric_value = 0.0
          metric_value = record["DataItems"][0]["Collections"][0]["Value"]

          if object_name == Constants::OBJECT_NAME_K8S_NODE && @metrics_to_collect_hash.key?(counter_name.downcase)
            # Compute and send % CPU and Memory
            if counter_name == Constants::CPU_USAGE_NANO_CORES
              metric_name = Constants::CPU_USAGE_MILLI_CORES
              metric_value /= 1000000 #cadvisor record is in nanocores. Convert to mc
              @log.info "Metric_value: #{metric_value} CPU Capacity #{@cpu_capacity}"
              if @cpu_capacity != 0.0
                percentage_metric_value = (metric_value) * 100 / @cpu_capacity
              end
            end

            if counter_name.start_with?("memory")
              metric_name = counter_name
              if @memory_capacity != 0.0
                percentage_metric_value = metric_value * 100 / @memory_capacity
              end
            end
            # return get_metric_records(record, metric_name, metric_value, percentage_metric_value)
            return MdmMetricsGenerator.getNodeResourceMetricRecords(record, metric_name, metric_value, percentage_metric_value)
          elsif object_name == Constants::OBJECT_NAME_K8S_CONTAINER && @metrics_to_collect_hash.key?(counter_name.downcase)
            instanceName = record["DataItems"][0]["InstanceName"]
            metricName = counter_name
            # Using node cpu capacity in the absence of container cpu capacity since the container will end up using the
            # node's capacity in this case. Converting this to nanocores for computation purposes, since this is in millicores
            containerCpuLimit = @cpu_capacity * 1000000
            containerMemoryLimit = @memory_capacity

            if counter_name == Constants::CPU_USAGE_NANO_CORES
              if !instanceName.nil? && !@containerCpuLimitHash[instanceName].nil?
                containerCpuLimit = @containerCpuLimitHash[instanceName]
              end

              # Checking if KubernetesApiClient ran into error while getting the numeric value or if we failed to get the limit
              if containerCpuLimit != 0
                percentage_metric_value = (metric_value) * 100 / containerCpuLimit
              end
            elsif counter_name.start_with?("memory")
              if !instanceName.nil? && !@containerMemoryLimitHash[instanceName].nil?
                containerMemoryLimit = @containerMemoryLimitHash[instanceName]
              end
              # Checking if KubernetesApiClient ran into error while getting the numeric value or if we failed to get the limit
              if containerMemoryLimit != 0
                percentage_metric_value = (metric_value) * 100 / containerMemoryLimit
              end
            end

            # Send this metric only if resource utilization is greater than configured threshold
            @log.info "percentage_metric_value for metric: #{metricName} for instance: #{instanceName} percentage: #{percentage_metric_value}"
            @log.info "@@metric_threshold_hash for #{metricName}: #{@@metric_threshold_hash[metricName]}"
            thresholdPercentage = @@metric_threshold_hash[metricName]

            # Flushing telemetry here since, we return as soon as we generate the metric
            flushMetricTelemetry
            if percentage_metric_value >= thresholdPercentage
              setThresholdExceededTelemetry(metricName)
              return MdmMetricsGenerator.getContainerResourceUtilMetricRecords(record["DataItems"][0]["Timestamp"],
                                                                               metricName,
                                                                               percentage_metric_value,
                                                                               @containerResourceDimensionHash[instanceName],
                                                                               thresholdPercentage)
            else
              return []
            end #end if block for percentage metric > configured threshold % check
          else
            return [] #end if block for object type check
          end
        else
          return []
        end #end if block for process incoming stream check
      rescue Exception => e
        @log.info "Error processing cadvisor record Exception: #{e.class} Message: #{e.message}"
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
        return [] #return empty array if we ran into any errors
      end
    end

    def filterPVInsightsMetrics(record)
      begin
        mdmMetrics = []
        record["DataItems"].each do |dataItem|

          if dataItem["Name"] == Constants::PV_USED_BYTES && @metrics_to_collect_hash.key?(dataItem["Name"].downcase)
            metricName = dataItem["Name"]
            usage = dataItem["Value"]
            capacity = dataItem["Tags"][Constants::INSIGHTSMETRICS_TAGS_PV_CAPACITY_BYTES]
            if capacity != 0
              percentage_metric_value = (usage * 100.0) / capacity
            end
            @log.info "percentage_metric_value for metric: #{metricName} percentage: #{percentage_metric_value}"
            @log.info "@@metric_threshold_hash for #{metricName}: #{@@metric_threshold_hash[metricName]}"

            computer = dataItem["Computer"]
            resourceDimensions = dataItem["Tags"]
            thresholdPercentage = @@metric_threshold_hash[metricName]

            flushMetricTelemetry
            if percentage_metric_value >= thresholdPercentage
              setThresholdExceededTelemetry(metricName)
              return MdmMetricsGenerator.getPVResourceUtilMetricRecords(dataItem["CollectionTime"],
                                                                       metricName,
                                                                       computer,
                                                                       percentage_metric_value,
                                                                       resourceDimensions,
                                                                       thresholdPercentage)
            else
              return []
            end # end if block for percentage metric > configured threshold % check
          end # end if block for dataItem name check
        end # end for block of looping through data items
        return []
      rescue Exception => e
        @log.info "Error processing cadvisor insights metrics record Exception: #{e.class} Message: #{e.message}"
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
        return [] #return empty array if we ran into any errors
      end
    end

    def ensure_cpu_memory_capacity_set
      if @cpu_capacity != 0.0 && @memory_capacity != 0.0
        @log.info "CPU And Memory Capacity are already set"
        return
      end

      controller_type = ENV["CONTROLLER_TYPE"]
      if controller_type.downcase == "replicaset"
        @log.info "ensure_cpu_memory_capacity_set @cpu_capacity #{@cpu_capacity} @memory_capacity #{@memory_capacity}"

        begin
          resourceUri = KubernetesApiClient.getNodesResourceUri("nodes?fieldSelector=metadata.name%3D#{@@hostName}")
          nodeInventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo(resourceUri).body)
        rescue Exception => e
          @log.info "Error when getting nodeInventory from kube API. Exception: #{e.class} Message: #{e.message} "
          ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
        end
        if !nodeInventory.nil?
          cpu_capacity_json = KubernetesApiClient.parseNodeLimits(nodeInventory, "capacity", "cpu", "cpuCapacityNanoCores")
          if !cpu_capacity_json.nil? && !cpu_capacity_json[0]["DataItems"][0]["Collections"][0]["Value"].to_s.nil?
            @cpu_capacity = cpu_capacity_json[0]["DataItems"][0]["Collections"][0]["Value"]
            @log.info "CPU Limit #{@cpu_capacity}"
          else
            @log.info "Error getting cpu_capacity"
          end
          memory_capacity_json = KubernetesApiClient.parseNodeLimits(nodeInventory, "capacity", "memory", "memoryCapacityBytes")
          if !memory_capacity_json.nil? && !memory_capacity_json[0]["DataItems"][0]["Collections"][0]["Value"].to_s.nil?
            @memory_capacity = memory_capacity_json[0]["DataItems"][0]["Collections"][0]["Value"]
            @log.info "Memory Limit #{@memory_capacity}"
          else
            @log.info "Error getting memory_capacity"
          end
        end
      elsif controller_type.downcase == "daemonset"
        capacity_from_kubelet = KubeletUtils.get_node_capacity
        @cpu_capacity = capacity_from_kubelet[0]
        @memory_capacity = capacity_from_kubelet[1]
      end
    end

    def filter_stream(tag, es)
      new_es = MultiEventStream.new
      begin
        ensure_cpu_memory_capacity_set
        # Getting container limits hash
        if @process_incoming_stream
          @containerCpuLimitHash, @containerMemoryLimitHash, @containerResourceDimensionHash = KubeletUtils.get_all_container_limits
        end

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
