#!/usr/local/bin/ruby
# frozen_string_literal: true

require "fluent/plugin/input"

module Fluent::Plugin
  require_relative "podinventory_to_mdm"

  class Kube_PodMDMInventory_Input < Input
    Fluent::Plugin.register_input("kube_podmdminventory", self)

    @@MDMKubePodInventoryTag = "mdm.kubepodinventory"

    def initialize
      super
      require "yaml"
      require "json"
      require "set"
      require "time"
      require "net/http"
      require "fileutils"
      require_relative "ApplicationInsightsUtility"
      require_relative "oms_common"
      require_relative "omslog"
      require_relative "constants"
      require_relative "CustomMetricsUtils"
    end

    config_param :run_interval, :time, :default => 60

    def configure(conf)
      super
      @inventoryToMdmConvertor = Inventory2MdmConvertor.new()
    end

    def start
      if @run_interval
        super
        $log.info("in_kube_podmdminventory::start @ #{Time.now.utc.iso8601}")
        @isCustomMetricsAvailability = CustomMetricsUtils.check_custom_metrics_availability
        @finished = false
        @prevCollectionTime = nil
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
      end
    end

    def shutdown
      if @run_interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
        super # This super must be at the end of shutdown method
      end
    end

    def enumerate
      begin
        if !@isCustomMetricsAvailability
          $log.warn "in_kube_podmdminventory::enumerate:skipping since custom metrics not available either for this cluster type or the region"
        else
          parse_and_emit_records()
        end
      rescue => errorStr
        $log.warn "in_kube_podmdminventory::enumerate:Failed in enumerate: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def parse_and_emit_records()
      begin
        $log.info "in_kube_podmdminventory:parse_and_emit_records:Start:getMDMRecords @ #{Time.now.utc.iso8601}"
        mdmPodRecords = getMDMRecords()
        $log.info "in_kube_podmdminventory:parse_and_emit_records:End:getMDMRecords @ #{Time.now.utc.iso8601}"
        if !mdmPodRecords.nil? && !mdmPodRecords.empty? && mdmPodRecords["items"].length > 0
          batchTime = mdmPodRecords["collectionTime"] # This is same batchTime used in KubePODinventory
          mdmPodRecords["items"].each do |record|
            @inventoryToMdmConvertor.process_pod_inventory_record(record)
            @inventoryToMdmConvertor.process_record_for_pods_ready_metric(record["ControllerName"], record["Namespace"], record["PodReadyCondition"])
            containerRecords = record["containerRecords"]
            if !containerRecords.nil? && !containerRecords.empty? && containerRecords.length > 0
              containerRecords.each do |containerRecord|
                if !containerRecord["state"].nil? && !containerRecord["state"].empty?
                  @inventoryToMdmConvertor.process_record_for_terminated_job_metric(record["ControllerName"], record["Namespace"], containerRecord["state"])
                end
                begin
                  if !containerRecord["lastState"].nil? && containerRecord["lastState"].keys.length == 1
                    lastStateName = containerRecord["lastState"].keys[0]
                    lastStateObject = containerRecord["lastState"][lastStateName]
                    if !lastStateObject.is_a?(Hash)
                      raise "expected a hash object. This could signify a bug or a kubernetes API change"
                    end
                    if lastStateObject.key?("reason") && lastStateObject.key?("startedAt") && lastStateObject.key?("finishedAt")
                      lastStateReason = lastStateObject["reason"]
                      lastFinishedTime = lastStateObject["finishedAt"]
                      #Populate mdm metric for OOMKilled container count if lastStateReason is OOMKilled
                      if lastStateReason.downcase == Constants::REASON_OOM_KILLED
                        @inventoryToMdmConvertor.process_record_for_oom_killed_metric(record["ControllerName"], record["Namespace"], lastFinishedTime)
                      end
                      lastStateReason = nil
                    end
                  end
                  containerRestartCount = containerRecord["restartCount"]
                  #Populate mdm metric for container restart count if greater than 0
                  if (!containerRestartCount.nil? && (containerRestartCount.is_a? Integer) && containerRestartCount > 0)
                    @inventoryToMdmConvertor.process_record_for_container_restarts_metric(record["ControllerName"], record["Namespace"], lastFinishedTime)
                  end
                rescue => err
                  $log.warn "in_kube_podmdminventory:parse_and_emit_records: failed while processing ContainerLastStatus: #{err}"
                  $log.debug_backtrace(err.backtrace)
                  ApplicationInsightsUtility.sendExceptionTelemetry(err)
                end
              end
            end
          end
          @log.info "in_kube_podmdminventory:parse_and_emit_records:Sending pod inventory mdm records to out_mdm @ #{Time.now.utc.iso8601}"
          pod_inventory_mdm_records = @inventoryToMdmConvertor.get_pod_inventory_mdm_records(batchTime)
          @log.info "in_kube_podmdminventory:parse_and_emit_records:pod_inventory_mdm_records.size #{pod_inventory_mdm_records.size} @ #{Time.now.utc.iso8601}"
          if !pod_inventory_mdm_records.nil? && pod_inventory_mdm_records.length > 0
            startTime = (Time.now.to_f * 1000).to_i
            recordCount = pod_inventory_mdm_records.length
            while recordCount > 0
              record_array = pod_inventory_mdm_records.take(Constants::POD_MDM_EMIT_STREAM_BATCH_SIZE)
              time_array = Array.new(record_array.length) { batchTime }
              mdm_pod_inventory_es = Fluent::MultiEventStream.new(time_array, record_array)
              router.emit_stream(@@MDMKubePodInventoryTag, mdm_pod_inventory_es)
              pod_inventory_mdm_records = pod_inventory_mdm_records.drop(Constants::POD_MDM_EMIT_STREAM_BATCH_SIZE)
              recordCount = pod_inventory_mdm_records.length
              time_array = nil
            end
            flushTimeMs = (Time.now.to_f * 1000).to_i - startTime
            @log.info "in_kube_podmdminventory:parse_and_emit_records:timetaken to flush all Pod MDM records: #{flushTimeMs} @ #{Time.now.utc.iso8601}"
          end
        end
      rescue => errorStr
        $log.warn "in_kube_podmdminventory:parse_and_emit_records: failed with an error #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def run_periodic
      @mutex.lock
      done = @finished
      @nextTimeToRun = Time.now
      @waitTimeout = @run_interval
      until done
        @nextTimeToRun = @nextTimeToRun + @run_interval
        @now = Time.now
        if @nextTimeToRun <= @now
          @waitTimeout = 1
          @nextTimeToRun = @now
        else
          @waitTimeout = @nextTimeToRun - @now
        end
        @condition.wait(@mutex, @waitTimeout)
        done = @finished
        @mutex.unlock
        if !done
          begin
            $log.info("in_kube_podmdminventory::run_periodic.enumerate.start #{Time.now.utc.iso8601}")
            enumerate
            $log.info("in_kube_podmdminventory::run_periodic.enumerate.end #{Time.now.utc.iso8601}")
          rescue => errorStr
            $log.warn "in_kube_podmdminventory::run_periodic: enumerate Failed to retrieve pod inventory: #{errorStr}"
            ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end

    def getMDMRecords()
      maxRetryCount = 5
      initialRetryDelaySecs = 0.5
      retryAttemptCount = 1
      mdmRecords = {}
      begin
        f = File.open(Constants::MDM_POD_INVENTORY_STATE_FILE, "r")
        if !f.nil?
          isAcquiredLock = f.flock(File::LOCK_EX | File::LOCK_NB)
          raise "in_kube_podmdminventory:getMDMRecords:Failed to acquire file lock @ #{Time.now.utc.iso8601}" if !isAcquiredLock
          startTime = (Time.now.to_f * 1000).to_i
          mdmRecords = JSON.parse(f.read)
          timetakenMs = ((Time.now.to_f * 1000).to_i - startTime)
          if mdmRecords.nil? || mdmRecords.empty? || mdmRecords["items"].nil? || mdmRecords["collectionTime"] == @prevCollectionTime
            raise "in_kube_podmdminventory:getMDMRecords: either read mdmRecords is nil or empty or stale @ #{Time.now.utc.iso8601}"
          end
          @prevCollectionTime = mdmRecords["collectionTime"]
          $log.info "in_kube_podmdminventory:getMDMRecords:Number of MDM records: #{mdmRecords["items"].length} with time taken(ms) for read: #{timetakenMs} @ #{Time.now.utc.iso8601}"
        else
          raise "in_kube_podmdminventory:getMDMRecords:Failed to open file for read @ #{Time.now.utc.iso8601}"
        end
      rescue => err
        if retryAttemptCount <= maxRetryCount
          f.flock(File::LOCK_UN) if !f.nil?
          f.close if !f.nil?
          sleep (initialRetryDelaySecs * retryAttemptCount)
          retryAttemptCount = retryAttemptCount + 1
          retry
        end
        $log.warn "in_kube_podmdminventory:getMDMRecords failed with an error: #{err} after retries: #{maxRetryCount} @  #{Time.now.utc.iso8601}"
        ApplicationInsightsUtility.sendExceptionTelemetry(err)
      ensure
        f.flock(File::LOCK_UN) if !f.nil?
        f.close if !f.nil?
      end
      return mdmRecords
    end
  end # Kube_Pod_Input
end # module
