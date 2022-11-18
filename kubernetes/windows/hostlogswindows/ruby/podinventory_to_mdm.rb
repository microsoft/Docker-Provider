# Copyright (c) Microsoft Corporation.  All rights reserved.

# frozen_string_literal: true

require "logger"
require "json"
require "time"
require_relative "oms_common"
require_relative "CustomMetricsUtils"
require_relative "MdmMetricsGenerator"
# require_relative "mdmMetrics"
require_relative "constants"

class Inventory2MdmConvertor
  @@node_count_metric_name = "nodesCount"
  @@pod_count_metric_name = "podCount"
  @@pod_inventory_tag = "mdm.kubepodinventory"
  @@node_inventory_tag = "mdm.kubenodeinventory"
  @@node_status_ready = "Ready"
  @@node_status_not_ready = "NotReady"
  @@oom_killed = "oomkilled"
  @@metricTelemetryTimeTracker = DateTime.now.to_time.to_i

  @@node_inventory_custom_metrics_template = '
        {
            "time": "%{timestamp}",
            "data": {
                "baseData": {
                    "metric": "%{metricName}",
                    "namespace": "insights.container/nodes",
                    "dimNames": [
                    "status"
                    ],
                    "series": [
                    {
                        "dimValues": [
                        "%{statusValue}"
                        ],
                        "min": %{node_status_count},
                        "max": %{node_status_count},
                        "sum": %{node_status_count},
                        "count": 1
                    }
                    ]
                }
            }
        }'

  @@pod_inventory_custom_metrics_template = '
        {
            "time": "%{timestamp}",
            "data": {
                "baseData": {
                    "metric": "%{metricName}",
                    "namespace": "insights.container/pods",
                    "dimNames": [
                    "phase",
                    "Kubernetes namespace",
                    "node",
                    "controllerName"
                    ],
                    "series": [
                    {
                        "dimValues": [
                        "%{phaseDimValue}",
                        "%{namespaceDimValue}",
                        "%{nodeDimValue}",
                        "%{controllerNameDimValue}"
                        ],
                        "min": %{podCountMetricValue},
                        "max": %{podCountMetricValue},
                        "sum": %{podCountMetricValue},
                        "count": 1
                    }
                    ]
                }
            }
        }'

  @@pod_phase_values = ["Running", "Pending", "Succeeded", "Failed", "Unknown"]
  @process_incoming_stream = false

  def initialize()
    @log_path = "/var/opt/microsoft/docker-cimprov/log/mdm_metrics_generator.log"
    @log = Logger.new(@log_path, 1, 5000000)
    @pod_count_hash = {}
    @no_phase_dim_values_hash = {}
    @pod_count_by_phase = {}
    @pod_uids = {}
    @process_incoming_stream = CustomMetricsUtils.check_custom_metrics_availability
    @metric_threshold_hash = MdmMetricsGenerator.getContainerResourceUtilizationThresholds
    @log.debug "After check_custom_metrics_availability process_incoming_stream #{@process_incoming_stream}"
    @log.debug { "Starting podinventory_to_mdm plugin" }
  end

  def get_pod_inventory_mdm_records(batch_time)
    records = []
    begin
      if @process_incoming_stream
        # generate all possible values of non_phase_dim_values X pod Phases and zero-fill the ones that are not already present
        @no_phase_dim_values_hash.each { |key, value|
          @@pod_phase_values.each { |phase|
            pod_key = [key, phase].join("~~")
            if !@pod_count_hash.key?(pod_key)
              @pod_count_hash[pod_key] = 0
            else
              next
            end
          }
        }
        @pod_count_hash.each { |key, value|
          key_elements = key.split("~~")
          if key_elements.length != 4
            next
          end

          # get dimension values by key
          podNodeDimValue = key_elements[0]
          podNamespaceDimValue = key_elements[1]
          podControllerNameDimValue = key_elements[2]
          podPhaseDimValue = key_elements[3]

          record = @@pod_inventory_custom_metrics_template % {
            timestamp: batch_time,
            metricName: @@pod_count_metric_name,
            phaseDimValue: podPhaseDimValue,
            namespaceDimValue: podNamespaceDimValue,
            nodeDimValue: podNodeDimValue,
            controllerNameDimValue: podControllerNameDimValue,
            podCountMetricValue: value,
          }
          records.push(JSON.parse(record))
        }

        #Add pod metric records
        records = MdmMetricsGenerator.appendAllPodMetrics(records, batch_time)

        #Send telemetry for pod metrics
        timeDifference = (DateTime.now.to_time.to_i - @@metricTelemetryTimeTracker).abs
        timeDifferenceInMinutes = timeDifference / 60
        if (timeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
          MdmMetricsGenerator.flushPodMdmMetricTelemetry
          @@metricTelemetryTimeTracker = DateTime.now.to_time.to_i
        end

        # Clearing out all hashes after telemetry is flushed
        MdmMetricsGenerator.clearPodHashes
      end
    rescue Exception => e
      @log.info "Error processing pod inventory record Exception: #{e.class} Message: #{e.message}"
      ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
      return []
    end
    if @process_incoming_stream
      @log.info "Pod Count To Phase #{@pod_count_by_phase} "
      @log.info "resetting convertor state "
      @pod_count_hash = {}
      @no_phase_dim_values_hash = {}
      @pod_count_by_phase = {}
      @pod_uids = {}
    end
    return records
  end

  # Check if container was terminated in the last 5 minutes
  def is_container_terminated_recently(finishedTime)
    begin
      if !finishedTime.nil? && !finishedTime.empty?
        finishedTimeParsed = Time.parse(finishedTime)
        if ((Time.now - finishedTimeParsed) / 60) < Constants::CONTAINER_TERMINATED_RECENTLY_IN_MINUTES
          return true
        end
      end
    rescue => errorStr
      @log.warn("Exception in check_if_terminated_recently: #{errorStr}")
      ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
    end
    return false
  end

  def process_record_for_oom_killed_metric(podControllerNameDimValue, podNamespaceDimValue, finishedTime)
    if @process_incoming_stream
      begin
        @log.info "in process_record_for_oom_killed_metric..."

        # Send OOM Killed state for container only if it terminated in the last 5 minutes, we dont want to keep sending this count forever
        if is_container_terminated_recently(finishedTime)
          if podControllerNameDimValue.nil? || podControllerNameDimValue.empty?
            podControllerNameDimValue = "No Controller"
          end
          MdmMetricsGenerator.generateOOMKilledContainerMetrics(podControllerNameDimValue,
                                                                podNamespaceDimValue)
        end
      rescue => errorStr
        @log.warn("Exception in process_record_for_oom_killed_metric: #{errorStr}")
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end

  def process_record_for_container_restarts_metric(podControllerNameDimValue, podNamespaceDimValue, finishedTime)
    if @process_incoming_stream
      begin
        @log.info "in process_record_for_container_restarts_metric..."

        # Send OOM Killed state for container only if it terminated in the last 5 minutes, we dont want to keep sending this count forever
        if is_container_terminated_recently(finishedTime)
          if podControllerNameDimValue.nil? || podControllerNameDimValue.empty?
            podControllerNameDimValue = "No Controller"
          end
          MdmMetricsGenerator.generateRestartingContainersMetrics(podControllerNameDimValue,
                                                                  podNamespaceDimValue)
        end
      rescue => errorStr
        @log.warn("Exception in process_record_for_container_restarts_metric: #{errorStr}")
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end

  def process_record_for_pods_ready_metric(podControllerNameDimValue, podNamespaceDimValue, podReadyCondition)
    if @process_incoming_stream
      begin
        @log.info "in process_record_for_pods_ready_metric..."
        if podControllerNameDimValue.nil? || podControllerNameDimValue.empty?
          podControllerNameDimValue = "No Controller"
        end
        MdmMetricsGenerator.generatePodReadyMetrics(podControllerNameDimValue,
                                                    podNamespaceDimValue, podReadyCondition)
      rescue => errorStr
        @log.warn("Exception in process_record_for_pods_ready_metric: #{errorStr}")
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end

  # Process the record to see if job was completed 6 hours ago. If so, send metric to mdm
  def process_record_for_terminated_job_metric(podControllerNameDimValue, podNamespaceDimValue, containerStatus)
    if @process_incoming_stream
      begin
        @log.info "in process_record_for_terminated_job_metric..."
        if podControllerNameDimValue.nil? || podControllerNameDimValue.empty?
          podControllerNameDimValue = "No Controller"
        end
        if !containerStatus.keys[0].nil? && containerStatus.keys[0].downcase == Constants::CONTAINER_STATE_TERMINATED
          containerTerminatedReason = containerStatus["terminated"]["reason"]
          if !containerTerminatedReason.nil? && containerTerminatedReason.downcase == Constants::CONTAINER_TERMINATION_REASON_COMPLETED
            containerFinishedTime = containerStatus["terminated"]["finishedAt"]
            if !containerFinishedTime.nil? && !containerFinishedTime.empty?
              finishedTimeParsed = Time.parse(containerFinishedTime)
              # Check to see if job was completed 6 hours ago/STALE_JOB_TIME_IN_MINUTES
              if ((Time.now - finishedTimeParsed) / 60) > @metric_threshold_hash[Constants::JOB_COMPLETION_TIME]
                MdmMetricsGenerator.generateStaleJobCountMetrics(podControllerNameDimValue,
                                                                 podNamespaceDimValue)
              end
            end
          end
        end
      rescue => errorStr
        @log.warn("Exception in process_record_for_terminated_job: #{errorStr}")
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end

  def process_pod_inventory_record(record)
    if @process_incoming_stream
      begin
        records = []

        podUid = record["PodUid"]
        if @pod_uids.key?(podUid)
          return
        end

        @pod_uids[podUid] = true
        podPhaseDimValue = record["PodStatus"]
        podNamespaceDimValue = record["Namespace"]
        podControllerNameDimValue = record["ControllerName"]
        podNodeDimValue = record["Computer"]

        if podControllerNameDimValue.nil? || podControllerNameDimValue.empty?
          podControllerNameDimValue = "No Controller"
        end

        if podNodeDimValue.empty? && podPhaseDimValue.downcase == "pending"
          podNodeDimValue = "unscheduled"
        elsif podNodeDimValue.empty?
          podNodeDimValue = "unknown"
        end

        # group by distinct dimension values
        pod_key = [podNodeDimValue, podNamespaceDimValue, podControllerNameDimValue, podPhaseDimValue].join("~~")

        @pod_count_by_phase[podPhaseDimValue] = @pod_count_by_phase.key?(podPhaseDimValue) ? @pod_count_by_phase[podPhaseDimValue] + 1 : 1
        @pod_count_hash[pod_key] = @pod_count_hash.key?(pod_key) ? @pod_count_hash[pod_key] + 1 : 1

        # Collect all possible combinations of dimension values other than pod phase
        key_without_phase_dim_value = [podNodeDimValue, podNamespaceDimValue, podControllerNameDimValue].join("~~")
        if @no_phase_dim_values_hash.key?(key_without_phase_dim_value)
          return
        else
          @no_phase_dim_values_hash[key_without_phase_dim_value] = true
        end
      rescue Exception => e
        @log.info "Error processing pod inventory record Exception: #{e.class} Message: #{e.message}"
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
      end
    end
  end
end
