#!/usr/local/bin/ruby
# frozen_string_literal: true

class MdmMetricsGenerator
  require "logger"
  require "yajl/json_gem"
  require "json"
  require_relative "MdmAlertTemplates"
  require_relative "ApplicationInsightsUtility"
  require_relative "constants"

  @log_path = "/var/opt/microsoft/docker-cimprov/log/mdm_metrics_generator.log"
  @log = Logger.new(@log_path, 1, 5000000)

  @oom_killed_container_count_hash = {}
  @container_restart_count_hash = {}
  @stale_job_count_hash = {}
  @pod_ready_hash = {}
  @pod_not_ready_hash = {}
  @pod_ready_percentage_hash = {}
  @zero_fill_metrics_hash = {
    Constants::MDM_OOM_KILLED_CONTAINER_COUNT => true,
    Constants::MDM_CONTAINER_RESTART_COUNT => true,
    Constants::MDM_STALE_COMPLETED_JOB_COUNT => true,
  }

  @@node_metric_name_metric_percentage_name_hash = {
    Constants::CPU_USAGE_MILLI_CORES => Constants::MDM_NODE_CPU_USAGE_PERCENTAGE,
    Constants::MEMORY_RSS_BYTES => Constants::MDM_NODE_MEMORY_RSS_PERCENTAGE,
    Constants::MEMORY_WORKING_SET_BYTES => Constants::MDM_NODE_MEMORY_WORKING_SET_PERCENTAGE,
  }

  @@container_metric_name_metric_percentage_name_hash = {
    Constants::CPU_USAGE_MILLI_CORES => Constants::MDM_CONTAINER_CPU_UTILIZATION_METRIC,
    Constants::CPU_USAGE_NANO_CORES => Constants::MDM_CONTAINER_CPU_UTILIZATION_METRIC,
    Constants::MEMORY_RSS_BYTES => Constants::MDM_CONTAINER_MEMORY_RSS_UTILIZATION_METRIC,
    Constants::MEMORY_WORKING_SET_BYTES => Constants::MDM_CONTAINER_MEMORY_WORKING_SET_UTILIZATION_METRIC,
  }

  @@pod_metric_name_metric_percentage_name_hash = {
    Constants::PV_USED_BYTES => Constants::MDM_PV_UTILIZATION_METRIC
  }

  # Setting this to true since we need to send zero filled metrics at startup. If metrics are absent alert creation fails
  @sendZeroFilledMetrics = true

  def initialize
  end

  class << self
    def populatePodReadyPercentageHash
      begin
        @log.info "in populatePodReadyPercentageHash..."
        @pod_ready_hash.each { |dim_key, value|
          podsNotReady = @pod_not_ready_hash.key?(dim_key) ? @pod_not_ready_hash[dim_key] : 0
          totalPods = value + podsNotReady
          podsReadyPercentage = (value / totalPods) * 100
          @pod_ready_percentage_hash[dim_key] = podsReadyPercentage
          # Deleting this key value pair from not ready hash,
          # so that we can get those dimensions for which there are 100% of the pods in not ready state
          if (@pod_not_ready_hash.key?(dim_key))
            @pod_not_ready_hash.delete(dim_key)
          end
        }

        # Add 0% pod ready for these dimensions
        if @pod_not_ready_hash.length > 0
          @pod_not_ready_hash.each { |key, value|
            @pod_ready_percentage_hash[key] = 0
          }
        end

        # Cleaning up hashes after use
        @pod_ready_hash = {}
        @pod_not_ready_hash = {}
      rescue => errorStr
        @log.info "Error in populatePodReadyPercentageHash: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def appendPodMetrics(records, metricName, metricHash, batch_time, metricsTemplate)
      begin
        @log.info "in appendPodMetrics..."
        if !metricHash.empty?
          metricHash.each { |key, value|
            key_elements = key.split("~~")
            if key_elements.length != 2
              next
            end

            # get dimension values by key
            podControllerNameDimValue = key_elements[0]
            podNamespaceDimValue = key_elements[1]

            record = metricsTemplate % {
              timestamp: batch_time,
              metricName: metricName,
              controllerNameDimValue: podControllerNameDimValue,
              namespaceDimValue: podNamespaceDimValue,
              containerCountMetricValue: value,
            }
            records.push(Yajl::Parser.parse(StringIO.new(record)))
          }
        else
          @log.info "No records found in hash for metric: #{metricName}"
        end
      rescue => errorStr
        @log.info "Error appending pod metrics for metric: #{metricName} : #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      @log.info "Done appending PodMetrics for metric: #{metricName}..."
      return records
    end

    def flushPodMdmMetricTelemetry
      begin
        properties = {}
        # Getting the sum of all values in the hash to send a count to telemetry
        containerRestartHashValues = @container_restart_count_hash.values
        containerRestartMetricCount = containerRestartHashValues.inject(0) { |sum, x| sum + x }

        oomKilledContainerHashValues = @oom_killed_container_count_hash.values
        oomKilledContainerMetricCount = oomKilledContainerHashValues.inject(0) { |sum, x| sum + x }

        staleJobHashValues = @stale_job_count_hash.values
        staleJobMetricCount = staleJobHashValues.inject(0) { |sum, x| sum + x }

        properties["ContainerRestarts"] = containerRestartMetricCount
        properties["OomKilledContainers"] = oomKilledContainerMetricCount
        properties["OldCompletedJobs"] = staleJobMetricCount
        ApplicationInsightsUtility.sendCustomEvent(Constants::CONTAINER_METRICS_HEART_BEAT_EVENT, properties)
        ApplicationInsightsUtility.sendCustomEvent(Constants::POD_READY_PERCENTAGE_HEART_BEAT_EVENT, {})
      rescue => errorStr
        @log.info "Error in flushMdmMetricTelemetry: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      @log.info "Mdm pod metric telemetry successfully flushed"
    end

    def clearPodHashes
      @oom_killed_container_count_hash = {}
      @container_restart_count_hash = {}
      @stale_job_count_hash = {}
      @pod_ready_percentage_hash = {}
    end

    def zeroFillMetricRecords(records, batch_time)
      begin
        @log.info "In zero fill metric records"
        zero_fill_dim_key = [Constants::OMSAGENT_ZERO_FILL, Constants::KUBESYSTEM_NAMESPACE_ZERO_FILL].join("~~")
        @oom_killed_container_count_hash[zero_fill_dim_key] = @oom_killed_container_count_hash.key?(zero_fill_dim_key) ? @oom_killed_container_count_hash[zero_fill_dim_key] : 0
        @container_restart_count_hash[zero_fill_dim_key] = @container_restart_count_hash.key?(zero_fill_dim_key) ? @container_restart_count_hash[zero_fill_dim_key] : 0
        @stale_job_count_hash[zero_fill_dim_key] = @stale_job_count_hash.key?(zero_fill_dim_key) ? @stale_job_count_hash[zero_fill_dim_key] : 0

        metric_threshold_hash = getContainerResourceUtilizationThresholds
        container_zero_fill_dims = [Constants::OMSAGENT_ZERO_FILL, Constants::OMSAGENT_ZERO_FILL, Constants::OMSAGENT_ZERO_FILL, Constants::KUBESYSTEM_NAMESPACE_ZERO_FILL].join("~~")
        containerCpuRecord = getContainerResourceUtilMetricRecords(batch_time,
                                                                   Constants::CPU_USAGE_NANO_CORES,
                                                                   0,
                                                                   container_zero_fill_dims,
                                                                   metric_threshold_hash[Constants::CPU_USAGE_NANO_CORES])
        if !containerCpuRecord.nil? && !containerCpuRecord.empty? && !containerCpuRecord[0].nil? && !containerCpuRecord[0].empty?
          records.push(containerCpuRecord[0])
        end
        containerMemoryRssRecord = getContainerResourceUtilMetricRecords(batch_time,
                                                                         Constants::MEMORY_RSS_BYTES,
                                                                         0,
                                                                         container_zero_fill_dims,
                                                                         metric_threshold_hash[Constants::MEMORY_RSS_BYTES])
        if !containerMemoryRssRecord.nil? && !containerMemoryRssRecord.empty? && !containerMemoryRssRecord[0].nil? && !containerMemoryRssRecord[0].empty?
          records.push(containerMemoryRssRecord[0])
        end
        containerMemoryWorkingSetRecord = getContainerResourceUtilMetricRecords(batch_time,
                                                                                Constants::MEMORY_WORKING_SET_BYTES,
                                                                                0,
                                                                                container_zero_fill_dims,
                                                                                metric_threshold_hash[Constants::MEMORY_WORKING_SET_BYTES])
        if !containerMemoryWorkingSetRecord.nil? && !containerMemoryWorkingSetRecord.empty? && !containerMemoryWorkingSetRecord[0].nil? && !containerMemoryWorkingSetRecord[0].empty?
          records.push(containerMemoryWorkingSetRecord[0])
        end
      rescue => errorStr
        @log.info "Error in zeroFillMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def appendAllPodMetrics(records, batch_time)
      begin
        @log.info "in appendAllPodMetrics..."
        if @sendZeroFilledMetrics == true
          records = zeroFillMetricRecords(records, batch_time)
          # Setting it to false after startup
          @sendZeroFilledMetrics = false
        end
        records = appendPodMetrics(records,
                                   Constants::MDM_OOM_KILLED_CONTAINER_COUNT,
                                   @oom_killed_container_count_hash,
                                   batch_time,
                                   MdmAlertTemplates::Pod_metrics_template)

        records = appendPodMetrics(records,
                                   Constants::MDM_CONTAINER_RESTART_COUNT,
                                   @container_restart_count_hash,
                                   batch_time,
                                   MdmAlertTemplates::Pod_metrics_template)

        records = appendPodMetrics(records,
                                   Constants::MDM_STALE_COMPLETED_JOB_COUNT,
                                   @stale_job_count_hash,
                                   batch_time,
                                   MdmAlertTemplates::Stable_job_metrics_template)

        # Computer the percentage here, because we need to do this after all chunks have been processed.
        populatePodReadyPercentageHash
        # @log.info "@pod_ready_percentage_hash: #{@pod_ready_percentage_hash}"
        records = appendPodMetrics(records,
                                   Constants::MDM_POD_READY_PERCENTAGE,
                                   @pod_ready_percentage_hash,
                                   batch_time,
                                   MdmAlertTemplates::Pod_metrics_template)
      rescue => errorStr
        @log.info "Error in appendAllPodMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def getContainerResourceUtilMetricRecords(recordTimeStamp, metricName, percentageMetricValue, dims, thresholdPercentage)
      records = []
      begin
        if dims.nil?
          @log.info "Dimensions nil, returning empty records"
          return records
        end
        dimElements = dims.split("~~")
        if dimElements.length != 4
          return records
        end

        # get dimension values
        containerName = dimElements[0]
        podName = dimElements[1]
        controllerName = dimElements[2]
        podNamespace = dimElements[3]

        resourceUtilRecord = MdmAlertTemplates::Container_resource_utilization_template % {
          timestamp: recordTimeStamp,
          metricName: @@container_metric_name_metric_percentage_name_hash[metricName],
          containerNameDimValue: containerName,
          podNameDimValue: podName,
          controllerNameDimValue: controllerName,
          namespaceDimValue: podNamespace,
          containerResourceUtilizationPercentage: percentageMetricValue,
          thresholdPercentageDimValue: thresholdPercentage,
        }
        records.push(Yajl::Parser.parse(StringIO.new(resourceUtilRecord)))
      rescue => errorStr
        @log.info "Error in getContainerResourceUtilMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def getPVResourceUtilMetricRecords(recordTimeStamp, metricName, computer, percentageMetricValue, dims, thresholdPercentage)
      records = []
      begin
        containerName = dims[Constants::INSIGHTSMETRICS_TAGS_CONTAINER_NAME]
        pvcNamespace = dims[Constants::INSIGHTSMETRICS_TAGS_PVC_NAMESPACE]
        podName = dims[Constants::INSIGHTSMETRICS_TAGS_POD_NAME]
        podUid = dims[Constants::INSIGHTSMETRICS_TAGS_POD_UID]

        resourceUtilRecord = MdmAlertTemplates::PV_resource_utilization_template % {
          timestamp: recordTimeStamp,
          metricName: @@pod_metric_name_metric_percentage_name_hash[metricName],
          podNameDimValue: podName,
          computerNameDimValue: computer,
          namespaceDimValue: pvcNamespace,
          pvResourceUtilizationPercentage: percentageMetricValue,
          thresholdPercentageDimValue: thresholdPercentage,
        }
        records.push(Yajl::Parser.parse(StringIO.new(resourceUtilRecord)))
      rescue => errorStr
        @log.info "Error in getPVResourceUtilMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def getDiskUsageMetricRecords(record)
      records = []
      usedPercent = nil
      deviceName = nil
      hostName = nil
      begin
        if !record["fields"].nil?
          usedPercent = record["fields"]["used_percent"]
        end
        if !record["tags"].nil?
          deviceName = record["tags"]["device"]
          hostName = record["tags"]["hostName"]
        end
        timestamp = record["timestamp"]
        convertedTimestamp = Time.at(timestamp.to_i).utc.iso8601
        if !usedPercent.nil? && !deviceName.nil? && !hostName.nil?
          diskUsedPercentageRecord = MdmAlertTemplates::Disk_used_percentage_metrics_template % {
            timestamp: convertedTimestamp,
            metricName: Constants::MDM_DISK_USED_PERCENTAGE,
            hostvalue: hostName,
            devicevalue: deviceName,
            diskUsagePercentageValue: usedPercent,
          }
          records.push(Yajl::Parser.parse(StringIO.new(diskUsedPercentageRecord)))
        end
      rescue => errorStr
        @log.info "Error in getDiskUsageMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def getMetricRecords(record)
      records = []
      begin
        dimNames = String.new "" #mutable string
        dimValues = String.new ""
        noDimVal ="-"
        metricValue = 0
        if !record["tags"].nil?
            dimCount = 0
            record["tags"].each { |k, v| 
            dimCount = dimCount+1
              if (dimCount <= 10) #MDM = 10 dims
                dimNames.concat("\"#{k}\"")
                dimNames.concat(",")
                if !v.nil? && v.length >0
                  dimValues.concat("\"#{v}\"")
                else
                  dimValues.concat("\"#{noDimVal}\"")
                end
                dimValues.concat(",")
              end
          }
          if (dimNames.end_with?(","))
            dimNames.chomp!(",")
          end
          if (dimValues.end_with?(","))
            dimValues.chomp!(",")
          end
        end
        timestamp = record["timestamp"]
        convertedTimestamp = Time.at(timestamp.to_i).utc.iso8601
        if !record["fields"].nil?
          record["fields"].each { |k, v|
          if is_numeric(v)
            metricRecord = MdmAlertTemplates::Generic_metric_template % {
              timestamp: convertedTimestamp,
              metricName: k,
              namespaceSuffix: record["name"],
              dimNames: dimNames,
              dimValues: dimValues,
              metricValue: v,
            }
            records.push(Yajl::Parser.parse(StringIO.new(metricRecord)))
            #@log.info "pushed mdmgenericmetric: #{k},#{v}"
          end
            }
        end
      rescue => errorStr
        @log.info "getMetricRecords:Error: #{errorStr} for record #{record}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def is_numeric(o)
        true if Float(o) rescue false
    end

    def getContainerResourceUtilizationThresholds
      begin
        metric_threshold_hash = {}
        # Initilizing with default values
        metric_threshold_hash[Constants::CPU_USAGE_NANO_CORES] = Constants::DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD
        metric_threshold_hash[Constants::MEMORY_RSS_BYTES] = Constants::DEFAULT_MDM_MEMORY_RSS_THRESHOLD
        metric_threshold_hash[Constants::MEMORY_WORKING_SET_BYTES] = Constants::DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD
        metric_threshold_hash[Constants::PV_USED_BYTES] = Constants::DEFAULT_MDM_PV_UTILIZATION_THRESHOLD

        cpuThreshold = ENV["AZMON_ALERT_CONTAINER_CPU_THRESHOLD"]
        if !cpuThreshold.nil? && !cpuThreshold.empty?
          #Rounding this to 2 decimal places, since this value is user configurable
          cpuThresholdFloat = (cpuThreshold.to_f).round(2)
          metric_threshold_hash[Constants::CPU_USAGE_NANO_CORES] = cpuThresholdFloat
        end

        memoryRssThreshold = ENV["AZMON_ALERT_CONTAINER_MEMORY_RSS_THRESHOLD"]
        if !memoryRssThreshold.nil? && !memoryRssThreshold.empty?
          memoryRssThresholdFloat = (memoryRssThreshold.to_f).round(2)
          metric_threshold_hash[Constants::MEMORY_RSS_BYTES] = memoryRssThresholdFloat
        end

        memoryWorkingSetThreshold = ENV["AZMON_ALERT_CONTAINER_MEMORY_WORKING_SET_THRESHOLD"]
        if !memoryWorkingSetThreshold.nil? && !memoryWorkingSetThreshold.empty?
          memoryWorkingSetThresholdFloat = (memoryWorkingSetThreshold.to_f).round(2)
          metric_threshold_hash[Constants::MEMORY_WORKING_SET_BYTES] = memoryWorkingSetThresholdFloat
        end

        pvUsagePercentageThreshold = ENV["AZMON_ALERT_PV_USAGE_THRESHOLD"]
        if !pvUsagePercentageThreshold.nil? && !pvUsagePercentageThreshold.empty?
          pvUsagePercentageThresholdFloat = (pvUsagePercentageThreshold.to_f).round(2)
          metric_threshold_hash[Constants::PV_USED_BYTES] = pvUsagePercentageThresholdFloat
        end
      rescue => errorStr
        @log.info "Error in getContainerResourceUtilizationThresholds: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return metric_threshold_hash
    end

    def getNodeResourceMetricRecords(record, metric_name, metric_value, percentage_metric_value)
      records = []
      begin
        custommetricrecord = MdmAlertTemplates::Node_resource_metrics_template % {
          timestamp: record["DataItems"][0]["Timestamp"],
          metricName: metric_name,
          hostvalue: record["DataItems"][0]["Host"],
          objectnamevalue: record["DataItems"][0]["ObjectName"],
          instancenamevalue: record["DataItems"][0]["InstanceName"],
          metricminvalue: metric_value,
          metricmaxvalue: metric_value,
          metricsumvalue: metric_value,
        }
        records.push(Yajl::Parser.parse(StringIO.new(custommetricrecord)))

        if !percentage_metric_value.nil?
          additional_record = MdmAlertTemplates::Node_resource_metrics_template % {
            timestamp: record["DataItems"][0]["Timestamp"],
            metricName: @@node_metric_name_metric_percentage_name_hash[metric_name],
            hostvalue: record["DataItems"][0]["Host"],
            objectnamevalue: record["DataItems"][0]["ObjectName"],
            instancenamevalue: record["DataItems"][0]["InstanceName"],
            metricminvalue: percentage_metric_value,
            metricmaxvalue: percentage_metric_value,
            metricsumvalue: percentage_metric_value,
          }
          records.push(Yajl::Parser.parse(StringIO.new(additional_record)))
        end
      rescue => errorStr
        @log.info "Error in getNodeResourceMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def generateOOMKilledContainerMetrics(podControllerName, podNamespace)
      begin
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to oom killed container hash..."
        @oom_killed_container_count_hash[dim_key] = @oom_killed_container_count_hash.key?(dim_key) ? @oom_killed_container_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        @log.warn "Error in generateOOMKilledContainerMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def generateRestartingContainersMetrics(podControllerName, podNamespace)
      begin
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to container restart count hash..."
        @container_restart_count_hash[dim_key] = @container_restart_count_hash.key?(dim_key) ? @container_restart_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        @log.warn "Error in generateRestartingContainersMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def generatePodReadyMetrics(podControllerName, podNamespace, podReadyCondition)
      begin
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to pod ready hash..."
        if podReadyCondition == true
          @pod_ready_hash[dim_key] = @pod_ready_hash.key?(dim_key) ? @pod_ready_hash[dim_key] + 1 : 1
        else
          @pod_not_ready_hash[dim_key] = @pod_not_ready_hash.key?(dim_key) ? @pod_not_ready_hash[dim_key] + 1 : 1
        end
      rescue => errorStr
        @log.warn "Error in generatePodReadyMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def generateStaleJobCountMetrics(podControllerName, podNamespace)
      begin
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to stale job count hash..."
        @stale_job_count_hash[dim_key] = @stale_job_count_hash.key?(dim_key) ? @stale_job_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        @log.warn "Error in generateStaleJobCountMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end
end
