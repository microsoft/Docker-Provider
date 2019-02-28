# Copyright (c) Microsoft Corporation.  All rights reserved.

# frozen_string_literal: true

module Fluent
  require "logger"
  require "json"
  require_relative "omslog"

  class CPUMemoryHealthFilter < Filter
    Fluent::Plugin.register_filter("filter_health_cpu_memory", self)

    config_param :enable_log, :integer, :default => 0
    config_param :log_path, :string, :default => "/var/opt/microsoft/omsagent/log/filter_health_cpu_memory.log"
    config_param :metrics_to_collect, :string, :default => "cpuUsageNanoCores,memoryWorkingSetBytes,memoryRssBytes"

    @@HealthConfigFile = "/var/opt/microsoft/docker-cimprov/healthConfig/config"
    @@PluginName = "filter_health_cpu_memory"

    # Setting the memory and cpu pass and fail percentages to default values
    @@memoryPassPercentage = 80.0
    @@memoryFailPercentage = 90.0
    @@cpuPassPercentage = 80.0
    @@cpuFailPercentage = 90.0
    @@cpuMonitorTimeOut = 50
    @@memoryRssMonitorTimeOut = 50

    @@previousCpuHealthDetails = {}
    @@previousPreviousCpuHealthDetails = {}
    @@previousCpuHealthStateSent = ""
    @@nodeCpuHealthDataTimeTracker = DateTime.now.to_time.to_i
    @@nodeMemoryRssDataTimeTracker = DateTime.now.to_time.to_i

    @@previousMemoryRssHealthDetails = {}
    @@previousPreviousMemoryRssHealthDetails = {}
    @@previousMemoryRssHealthStateSent = ""
    @@clusterName = KubernetesApiClient.getClusterName
    @@clusterId = KubernetesApiClient.getClusterId
    @@clusterRegion = KubernetesApiClient.getClusterRegion
    @@cpu_usage_nano_cores = "cpuusagenanocores"
    @@memory_rss_bytes = "memoryrssbytes"
    @@object_name_k8s_node = "K8SNode"

    @metrics_to_collect_hash = {}

    def initialize
      super
    end

    def configure(conf)
      super
      @log = nil

      if @enable_log
        @log = Logger.new(@log_path, "weekly")
        @log.debug { "Starting filter_health_cpu_memory plugin" }
      end
    end

    def start
      super
      @metrics_to_collect_hash = build_metrics_hash
      @@clusterName = KubernetesApiClient.getClusterName
      @@clusterId = KubernetesApiClient.getClusterId
      @@clusterRegion = KubernetesApiClient.getClusterRegion
      @@cpu_limit = 0.0
      @@memory_limit = 0.0
      begin
        nodeInventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo("nodes").body)
      rescue Exception => e
        @log.info "Error when getting nodeInventory from kube API. Exception: #{e.class} Message: #{e.message} "
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
      end
      if !nodeInventory.nil?
        cpu_limit_json = KubernetesApiClient.parseNodeLimits(nodeInventory, "capacity", "cpu", "cpuCapacityNanoCores")
        if !cpu_limit_json.nil?
          @@cpu_limit = cpu_limit_json[0]["DataItems"][0]["Collections"][0]["Value"]
          @log.info "CPU Limit #{@@cpu_limit}"
        else
          @log.info "Error getting cpu_limit"
        end
        memory_limit_json = KubernetesApiClient.parseNodeLimits(nodeInventory, "capacity", "memory", "memoryCapacityBytes")
        if !memory_limit_json.nil?
          @@memory_limit = memory_limit_json[0]["DataItems"][0]["Collections"][0]["Value"]
          @log.info "Memory Limit #{@@memory_limit}"
        else
          @log.info "Error getting memory_limit"
        end
      end
      # Read config information for cpu and memory limits.
      begin
        healthConfigObject = nil
        file = File.open(@@HealthConfigFile, "r")
        if !file.nil?
          fileContents = file.read
          healthConfigObject = JSON.parse(fileContents)
          file.close
          if !healthConfigObject.nil?
            # memPassPercent = healthConfigObject["memoryPassPercentage"]
            # memFailPercent = healthConfigObject["memoryFailPercentage"]
            # cpuPassPercent = healthConfigObject["cpuPassPercentage"]
            # cpuFailPercent = healthConfigObject["cpuFailPercentage"]
            cpuPassPercent = healthConfigObject["NodeCpuMonitor"]["PassPercentage"]
            cpuFailPercent = healthConfigObject["NodeCpuMonitor"]["FailPercentage"]
            memPassPercent = healthConfigObject["NodeMemoryRssMonitor"]["PassPercentage"]
            memFailPercent = healthConfigObject["NodeMemoryRssMonitor"]["FailPercentage"]
            @@cpuMonitorTimeOut = healthConfigObject["NodeCpuMonitor"]["MonitorTimeOut"]
            @@memoryRssMonitorTimeOut = healthConfigObject["NodeMemoryRssMonitor"]["MonitorTimeOut"]

            if !memPassPercent.nil? && memPassPercent.is_a?(Numeric)
              @@memoryPassPercentage = memPassPercent
            end
            if !memFailPercent.nil? && memFailPercent.is_a?(Numeric)
              @@memoryFailPercentage = memFailPercent
            end
            if !cpuPassPercent.nil? && cpuPassPercent.is_a?(Numeric)
              @@cpuPassPercentage = cpuPassPercent
            end
            if !cpuFailPercent.nil? && cpuFailPercent.is_a?(Numeric)
              @@cpuFailPercentage = cpuFailPercent
            end
            @log.info "Successfully read config values from file, using values for cpu and memory health."
          end
        else
          @log.warn "Failed to open file at location #{@@HealthConfigFile} to read health config, using defaults"
        end
      rescue => errorStr
        @log.debug "Exception occured while reading config file at location #{@@HealthConfigFile}, error: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def shutdown
      super
    end

    def build_metrics_hash
      @log.debug "Building Hash of Metrics to Collect"
      metrics_to_collect_arr = @metrics_to_collect.split(",").map(&:strip)
      metrics_hash = metrics_to_collect_arr.map { |x| [x.downcase, true] }.to_h
      @log.info "Metrics Collected : #{metrics_hash}"
      return metrics_hash
    end

    def processCpuMetrics(cpuMetricValue, cpuMetricPercentValue, host, timeStamp)
      begin
        @log.debug "cpuMetricValue: #{cpuMetricValue}"
        @log.debug "cpuMetricPercentValue: #{cpuMetricPercentValue}"
        # Get node CPU usage health
        updateCpuHealthState = false
        cpuHealthRecord = {}
        currentCpuHealthDetails = {}
        labels = {}
        labels["ClusterName"] = @@clusterName
        labels["ClusterId"] = @@clusterId
        labels["ClusterRegion"] = @@clusterRegion
        labels["NodeName"] = host
        cpuHealthRecord["Labels"] = labels.to_json
        cpuHealthRecord["MonitorId"] = "NodeCpuMonitor"
        cpuHealthState = ""
        if cpuMetricPercentValue.to_f < @@cpuPassPercentage
          cpuHealthState = "Pass"
        elsif cpuMetricPercentValue.to_f > @@cpuFailPercentage
          cpuHealthState = "Fail"
        else
          cpuHealthState = "Warning"
        end
        currentCpuHealthDetails["State"] = cpuHealthState
        currentCpuHealthDetails["Time"] = timeStamp
        currentCpuHealthDetails["CPUUsagePercentage"] = cpuMetricPercentValue
        currentCpuHealthDetails["CPUUsageMillicores"] = cpuMetricValue

        currentTime = DateTime.now.to_time.to_i
        timeDifference = (currentTime - @@nodeCpuHealthDataTimeTracker).abs
        timeDifferenceInMinutes = timeDifference / 60

        @log.debug "processing cpu metrics"
        if ((cpuHealthState != @@previousCpuHealthStateSent &&
             ((cpuHealthState == @@previousCpuHealthDetails["State"]) && (cpuHealthState == @@previousPreviousCpuHealthDetails["State"]))) ||
            timeDifferenceInMinutes > @@cpuMonitorTimeOut)
          @log.debug "cpu conditions met."
          cpuHealthRecord["NewState"] = cpuHealthState
          cpuHealthRecord["OldState"] = @@previousCpuHealthStateSent

          details = {}
          details["NodeCpuUsagePercentage"] = cpuMetricPercentValue
          details["NodeCpuUsageMilliCores"] = cpuMetricValue
          details["PrevNodeCpuUsageDetails"] = {"Percent": @@previousCpuHealthDetails["CPUUsagePercentage"], "TimeStamp": @@previousCpuHealthDetails["Time"], "Millicores": @@previousCpuHealthDetails["CPUUsageMillicores"]}
          details["PrevPrevNodeCpuUsageDetails"] = {"Percent": @@previousPreviousCpuHealthDetails["CPUUsagePercentage"], "TimeStamp": @@previousPreviousCpuHealthDetails["Time"], "Millicores": @@previousPreviousCpuHealthDetails["CPUUsageMillicores"]}
          cpuHealthRecord["Details"] = details.to_json

          monitorConfigDetails = {}
          monitorConfigDetails["PassPercentage"] = @@cpuPassPercentage
          monitorConfigDetails["FailPercentage"] = @@cpuFailPercentage
          monitorConfigDetails["MonitorTimeOut"] = @@cpuMonitorTimeOut
          cpuHealthRecord["MonitorConfigDetails"] = monitorConfigDetails.to_json

          #Sendind this data as collection time because this is overridden in custom log type. This will be mapped to TimeGenerated with fixed type.
          cpuHealthRecord["CollectionTime"] = @@previousPreviousCpuHealthDetails["Time"]
          updateCpuHealthState = true
          @@previousCpuHealthStateSent = cpuHealthState
        end
        @@previousPreviousCpuHealthDetails = @@previousCpuHealthDetails.clone
        @@previousCpuHealthDetails = currentCpuHealthDetails.clone
        if updateCpuHealthState
          @@nodeCpuHealthDataTimeTracker = currentTime
          cpuHealthRecord["TimeObserved"] = Time.now.utc.iso8601
          telemetryProperties = {}
          telemetryProperties["Computer"] = host
          telemetryProperties["NodeCpuHealthState"] = cpuHealthState
          ApplicationInsightsUtility.sendTelemetry(@@PluginName, telemetryProperties)
          @log.debug "cpu record sent"
          return cpuHealthRecord
        else
          return nil
        end
      rescue => errorStr
        @log.debug "In processCpuMetrics: exception: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def processMemoryRssHealthMetrics(memoryRssMetricValue, memoryRssMetricPercentValue, host, timeStamp)
      begin
        @log.debug "memoryRssMetricValue: #{memoryRssMetricValue}"
        @log.debug "memoryRssMetricPercentValue: #{memoryRssMetricPercentValue}"

        # Get node memory RSS health
        memRssHealthRecord = {}
        currentMemoryRssHealthDetails = {}

        labels = {}
        labels["ClusterName"] = @@clusterName
        labels["ClusterId"] = @@clusterId
        labels["ClusterRegion"] = @@clusterRegion
        labels["NodeName"] = host
        memRssHealthRecord["Labels"] = labels.to_json
        memRssHealthRecord["MonitorId"] = "NodeMemoryRssMonitor"

        memoryRssHealthState = ""
        if memoryRssMetricPercentValue.to_f < @@memoryPassPercentage
          memoryRssHealthState = "Pass"
        elsif memoryRssMetricPercentValue.to_f > @@memoryFailPercentage
          memoryRssHealthState = "Fail"
        else
          memoryRssHealthState = "Warning"
        end
        currentMemoryRssHealthDetails["State"] = memoryRssHealthState
        currentMemoryRssHealthDetails["Time"] = timeStamp
        currentMemoryRssHealthDetails["memoryRssPercentage"] = memoryRssMetricPercentValue
        currentMemoryRssHealthDetails["memoryRssBytes"] = memoryRssMetricValue
        updateMemoryRssHealthState = false

        currentTime = DateTime.now.to_time.to_i
        timeDifference = (currentTime - @@nodeMemoryRssDataTimeTracker).abs
        timeDifferenceInMinutes = timeDifference / 60
        @log.debug "processing memory metrics"

        if ((memoryRssHealthState != @@previousMemoryRssHealthStateSent &&
             ((memoryRssHealthState == @@previousMemoryRssHealthDetails["State"]) && (memoryRssHealthState == @@previousPreviousMemoryRssHealthDetails["State"]))) ||
            timeDifferenceInMinutes > @@memoryRssMonitorTimeOut)
          @log.debug "memory conditions met"
          memRssHealthRecord["NewState"] = memoryRssHealthState
          memRssHealthRecord["OldState"] = @@previousMemoryRssHealthStateSent
          details = {}
          details["NodeMemoryRssPercentage"] = memoryRssMetricPercentValue
          details["NodeMemoryRssBytes"] = memoryRssMetricValue
          details["PrevNodeMemoryRssDetails"] = {"Percent": @@previousMemoryRssHealthDetails["memoryRssPercentage"], "TimeStamp": @@previousMemoryRssHealthDetails["Time"], "Bytes": @@previousMemoryRssHealthDetails["memoryRssBytes"]}
          details["PrevPrevNodeMemoryRssDetails"] = {"Percent": @@previousPreviousMemoryRssHealthDetails["memoryRssPercentage"], "TimeStamp": @@previousPreviousMemoryRssHealthDetails["Time"], "Bytes": @@previousPreviousMemoryRssHealthDetails["memoryRssBytes"]}
          memRssHealthRecord["Details"] = details.to_json

          monitorConfigDetails = {}
          monitorConfigDetails["PassPercentage"] = @@memoryPassPercentage
          monitorConfigDetails["FailPercentage"] = @@memoryFailPercentage
          monitorConfigDetails["MonitorTimeOut"] = @@memoryRssMonitorTimeOut
          memRssHealthRecord["MonitorConfigDetails"] = monitorConfigDetails.to_json

          #Sending this data as collection time because this is overridden in custom log type. This will be mapped to TimeGenerated with fixed type.
          memRssHealthRecord["CollectionTime"] = @@previousPreviousMemoryRssHealthDetails["Time"]
          updateMemoryRssHealthState = true
          @@previousMemoryRssHealthStateSent = memoryRssHealthState
        end
        @@previousPreviousMemoryRssHealthDetails = @@previousMemoryRssHealthDetails.clone
        @@previousMemoryRssHealthDetails = currentMemoryRssHealthDetails.clone
        if updateMemoryRssHealthState
          @@nodeMemoryRssDataTimeTracker = currentTime
          memRssHealthRecord["TimeObserved"] = Time.now.utc.iso8601
          telemetryProperties = {}
          telemetryProperties["Computer"] = host
          telemetryProperties["NodeMemoryRssHealthState"] = memoryRssHealthState
          ApplicationInsightsUtility.sendTelemetry(@@PluginName, telemetryProperties)
          @log.debug "memory record sent"
          return memRssHealthRecord
        else
          return nil
        end
      rescue => errorStr
        @log.debug "In processMemoryRssMetrics: exception: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def filter(tag, time, record)
      object_name = record["DataItems"][0]["ObjectName"]
      counter_name = record["DataItems"][0]["Collections"][0]["CounterName"]
      host = record["DataItems"][0]["Host"]
      timeStamp = record["DataItems"][0]["Timestamp"]
      if object_name == @@object_name_k8s_node && @metrics_to_collect_hash.key?(counter_name.downcase)
        percentage_metric_value = 0.0

        # Compute and send % CPU and Memory
        begin
          metric_value = record["DataItems"][0]["Collections"][0]["Value"]
          if counter_name.downcase == @@cpu_usage_nano_cores
            metric_value = metric_value / 1000000
            if @@cpu_limit != 0.0
              percentage_metric_value = (metric_value * 1000000) * 100 / @@cpu_limit
            end
            return processCpuMetrics(metric_value, percentage_metric_value, host, timeStamp)
          end

          if counter_name.downcase == @@memory_rss_bytes
            if @@memory_limit != 0.0
              percentage_metric_value = metric_value * 100 / @@memory_limit
            end
            return processMemoryRssHealthMetrics(metric_value, percentage_metric_value, host, timeStamp)
          end
        rescue Exception => e
          @log.info "Error parsing cadvisor record Exception: #{e.class} Message: #{e.message}"
          ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
          return nil
        end
      else
        return nil
      end
    end

    def filter_stream(tag, es)
      new_es = MultiEventStream.new
      es.each { |time, record|
        begin
          filtered_record = filter(tag, time, record)
          new_es.add(time, filtered_record) if filtered_record
        rescue => e
          router.emit_error_event(tag, time, record, e)
          ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
        end
      }
      new_es
    end
  end
end
