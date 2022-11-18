#!/usr/local/bin/ruby
# frozen_string_literal: true

require "fluent/plugin/input"

module Fluent::Plugin
  class Kube_PerfInventory_Input < Input
    Fluent::Plugin.register_input("kube_perfinventory", self)

    def initialize
      super
      require "yaml"
      require "json"
      require "set"
      require "time"
      require "net/http"

      require_relative "KubernetesApiClient"
      require_relative "ApplicationInsightsUtility"
      require_relative "oms_common"
      require_relative "omslog"
      require_relative "constants"
      require_relative "extension_utils"

      # refer tomlparser-agent-config for updating defaults
      # this configurable via configmap
      @PODS_CHUNK_SIZE = 0
      @PODS_EMIT_STREAM_BATCH_SIZE = 0

      @watchPodsThread = nil
      @podItemsCache = {}

      @kubeperfTag = "oneagent.containerInsights.LINUX_PERF_BLOB"
      @insightsMetricsTag = "oneagent.containerInsights.INSIGHTS_METRICS_BLOB"
    end

    config_param :run_interval, :time, :default => 60
    config_param :tag, :string, :default => "oneagent.containerInsights.LINUX_PERF_BLOB"

    def configure(conf)
      super
    end

    def start
      if @run_interval
        super
        if !ENV["PODS_CHUNK_SIZE"].nil? && !ENV["PODS_CHUNK_SIZE"].empty? && ENV["PODS_CHUNK_SIZE"].to_i > 0
          @PODS_CHUNK_SIZE = ENV["PODS_CHUNK_SIZE"].to_i
        else
          # this shouldnt happen just setting default here as safe guard
          $log.warn("in_kube_perfinventory::start: setting to default value since got PODS_CHUNK_SIZE nil or empty")
          @PODS_CHUNK_SIZE = 1000
        end
        $log.info("in_kube_perfinventory::start: PODS_CHUNK_SIZE  @ #{@PODS_CHUNK_SIZE}")

        if !ENV["PODS_EMIT_STREAM_BATCH_SIZE"].nil? && !ENV["PODS_EMIT_STREAM_BATCH_SIZE"].empty? && ENV["PODS_EMIT_STREAM_BATCH_SIZE"].to_i > 0
          @PODS_EMIT_STREAM_BATCH_SIZE = ENV["PODS_EMIT_STREAM_BATCH_SIZE"].to_i
        else
          # this shouldnt happen just setting default here as safe guard
          $log.warn("in_kube_perfinventory::start: setting to default value since got PODS_EMIT_STREAM_BATCH_SIZE nil or empty")
          @PODS_EMIT_STREAM_BATCH_SIZE = 200
        end
        $log.info("in_kube_perfinventory::start: PODS_EMIT_STREAM_BATCH_SIZE  @ #{@PODS_EMIT_STREAM_BATCH_SIZE}")

        @finished = false
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @podCacheMutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
        @watchPodsThread = Thread.new(&method(:watch_pods))
      end
    end

    def shutdown
      if @run_interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
        @watchPodsThread.join
        super # This super must be at the end of shutdown method
      end
    end

    def enumerate(podList = nil)
      begin
        podInventory = podList
        @podCount = 0
        currentTime = Time.now
        batchTime = currentTime.utc.iso8601
        if ExtensionUtils.isAADMSIAuthMode()
          $log.info("in_kube_perfinventory::enumerate: AAD AUTH MSI MODE")
          if @kubeperfTag.nil? || !@kubeperfTag.start_with?(Constants::EXTENSION_OUTPUT_STREAM_ID_TAG_PREFIX)
            @kubeperfTag = ExtensionUtils.getOutputStreamId(Constants::PERF_DATA_TYPE)
          end
          if @insightsMetricsTag.nil? || !@insightsMetricsTag.start_with?(Constants::EXTENSION_OUTPUT_STREAM_ID_TAG_PREFIX)
            @insightsMetricsTag = ExtensionUtils.getOutputStreamId(Constants::INSIGHTS_METRICS_DATA_TYPE)
          end
          $log.info("in_kube_perfinventory::enumerate: using perf tag -#{@kubeperfTag} @ #{Time.now.utc.iso8601}")
          $log.info("in_kube_perfinventory::enumerate: using insightsmetrics tag -#{@insightsMetricsTag} @ #{Time.now.utc.iso8601}")
        end

        nodeAllocatableRecords = getNodeAllocatableRecords()
        # Initializing continuation token to nil
        continuationToken = nil
        podItemsCacheSizeKB = 0
        podInventory = {}
        @podCacheMutex.synchronize {
          podInventory["items"] = @podItemsCache.values.clone
        }
        if (!podInventory.nil? && !podInventory.empty? && podInventory.key?("items") && !podInventory["items"].nil? && !podInventory["items"].empty?)
          $log.info("in_kube_perfinventory::enumerate : number of pod items :#{podInventory["items"].length}  from Kube API @ #{Time.now.utc.iso8601}")
          parse_and_emit_records(podInventory, nodeAllocatableRecords, continuationToken, batchTime)
        else
          $log.warn "in_kube_perfinventory::enumerate:Received empty podInventory"
        end
        # Setting these to nil so that we dont hold memory until GC kicks in
        podInventory = nil
        nodeAllocatableRecords = nil
      rescue => errorStr
        $log.warn "in_kube_perfinventory::enumerate:Failed in enumerate: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def parse_and_emit_records(podInventory, nodeAllocatableRecords, continuationToken, batchTime = Time.utc.iso8601)
      currentTime = Time.now
      emitTime = Fluent::Engine.now
      kubePerfEventStream = Fluent::MultiEventStream.new
      insightsMetricsEventStream = Fluent::MultiEventStream.new
      @@istestvar = ENV["ISTEST"]

      begin #begin block start
        podInventory["items"].each do |item| #podInventory block start
          nodeName = ""
          if !item["spec"]["nodeName"].nil?
            nodeName = item["spec"]["nodeName"]
          end

          nodeAllocatableRecord = {}
          if !nodeName.empty? && !nodeAllocatableRecords.nil? && !nodeAllocatableRecords.empty? && nodeAllocatableRecords.has_key?(nodeName)
            nodeAllocatableRecord = nodeAllocatableRecords[nodeName]
          end
          #container perf records
          containerMetricDataItems = []
          containerMetricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(item, "requests", "cpu", "cpuRequestNanoCores", nodeAllocatableRecord, batchTime))
          containerMetricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(item, "requests", "memory", "memoryRequestBytes", nodeAllocatableRecord, batchTime))
          containerMetricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(item, "limits", "cpu", "cpuLimitNanoCores", nodeAllocatableRecord, batchTime))
          containerMetricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(item, "limits", "memory", "memoryLimitBytes", nodeAllocatableRecord, batchTime))

          containerMetricDataItems.each do |record|
            kubePerfEventStream.add(emitTime, record) if record
          end

          if @PODS_EMIT_STREAM_BATCH_SIZE > 0 && kubePerfEventStream.count >= @PODS_EMIT_STREAM_BATCH_SIZE
            $log.info("in_kube_perfinventory::parse_and_emit_records: number of container perf records emitted #{kubePerfEventStream.count} @ #{Time.now.utc.iso8601}")
            router.emit_stream(@kubeperfTag, kubePerfEventStream) if kubePerfEventStream
            if (!@@istestvar.nil? && !@@istestvar.empty? && @@istestvar.casecmp("true") == 0)
              $log.info("kubeContainerPerfEventEmitStreamSuccess @ #{Time.now.utc.iso8601}")
            end
            kubePerfEventStream = Fluent::MultiEventStream.new
          end

          # container GPU records
          containerGPUInsightsMetricsDataItems = []
          containerGPUInsightsMetricsDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimitsAsInsightsMetrics(item, "requests", "nvidia.com/gpu", "containerGpuRequests", nodeAllocatableRecord, batchTime))
          containerGPUInsightsMetricsDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimitsAsInsightsMetrics(item, "limits", "nvidia.com/gpu", "containerGpuLimits", nodeAllocatableRecord, batchTime))
          containerGPUInsightsMetricsDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimitsAsInsightsMetrics(item, "requests", "amd.com/gpu", "containerGpuRequests", nodeAllocatableRecord, batchTime))
          containerGPUInsightsMetricsDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimitsAsInsightsMetrics(item, "limits", "amd.com/gpu", "containerGpuLimits", nodeAllocatableRecord, batchTime))
          containerGPUInsightsMetricsDataItems.each do |insightsMetricsRecord|
            insightsMetricsEventStream.add(emitTime, insightsMetricsRecord) if insightsMetricsRecord
          end

          if @PODS_EMIT_STREAM_BATCH_SIZE > 0 && insightsMetricsEventStream.count >= @PODS_EMIT_STREAM_BATCH_SIZE
            $log.info("in_kube_perfinventory::parse_and_emit_records: number of GPU insights metrics records emitted #{insightsMetricsEventStream.count} @ #{Time.now.utc.iso8601}")
            if (!@@istestvar.nil? && !@@istestvar.empty? && @@istestvar.casecmp("true") == 0)
              $log.info("kubePodInsightsMetricsEmitStreamSuccess @ #{Time.now.utc.iso8601}")
            end
            router.emit_stream(@insightsMetricsTag, insightsMetricsEventStream) if insightsMetricsEventStream
            insightsMetricsEventStream = Fluent::MultiEventStream.new
          end
        end  #podInventory block end

        if kubePerfEventStream.count > 0
          $log.info("in_kube_perfinventory::parse_and_emit_records: number of perf records emitted #{kubePerfEventStream.count} @ #{Time.now.utc.iso8601}")
          router.emit_stream(@kubeperfTag, kubePerfEventStream) if kubePerfEventStream
          kubePerfEventStream = nil
          if (!@@istestvar.nil? && !@@istestvar.empty? && @@istestvar.casecmp("true") == 0)
            $log.info("kubeContainerPerfEventEmitStreamSuccess @ #{Time.now.utc.iso8601}")
          end
        end

        if insightsMetricsEventStream.count > 0
          $log.info("in_kube_perfinventory::parse_and_emit_records: number of insights metrics records emitted #{insightsMetricsEventStream.count} @ #{Time.now.utc.iso8601}")
          router.emit_stream(@insightsMetricsTag, insightsMetricsEventStream) if insightsMetricsEventStream
          if (!@@istestvar.nil? && !@@istestvar.empty? && @@istestvar.casecmp("true") == 0)
            $log.info("kubePodInsightsMetricsEmitStreamSuccess @ #{Time.now.utc.iso8601}")
          end
          insightsMetricsEventStream = nil
        end
      rescue => errorStr
        $log.warn "Failed in parse_and_emit_record kube perf inventory: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end #begin block end
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
            $log.info("in_kube_perfinventory::run_periodic.enumerate.start #{Time.now.utc.iso8601}")
            enumerate
            $log.info("in_kube_perfinventory::run_periodic.enumerate.end #{Time.now.utc.iso8601}")
          rescue => errorStr
            $log.warn "in_kube_perfinventory::run_periodic: enumerate Failed to retrieve perf inventory: #{errorStr}"
            ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end

    def watch_pods
      $log.info("in_kube_perfinventory::watch_pods:Start @ #{Time.now.utc.iso8601}")
      podsResourceVersion = nil
      loop do
        begin
          if podsResourceVersion.nil?
            # clear cache before filling the cache with list
            @podCacheMutex.synchronize {
              @podItemsCache.clear()
            }
            continuationToken = nil
            resourceUri = "pods?limit=#{@PODS_CHUNK_SIZE}"
            $log.info("in_kube_perfinventory::watch_pods:Getting pods from Kube API: #{resourceUri}  @ #{Time.now.utc.iso8601}")
            continuationToken, podInventory, responseCode = KubernetesApiClient.getResourcesAndContinuationTokenV2(resourceUri)
            if responseCode.nil? || responseCode != "200"
              $log.warn("in_kube_perfinventory::watch_pods:Getting pods from Kube API: #{resourceUri} failed with statuscode: #{responseCode} @ #{Time.now.utc.iso8601}")
            else
              $log.info("in_kube_perfinventory::watch_pods:Done getting pods from Kube API:#{resourceUri} @ #{Time.now.utc.iso8601}")
              if (!podInventory.nil? && !podInventory.empty?)
                podsResourceVersion = podInventory["metadata"]["resourceVersion"]
                if (podInventory.key?("items") && !podInventory["items"].nil? && !podInventory["items"].empty?)
                  $log.info("in_kube_perfinventory::watch_pods:number of pod items :#{podInventory["items"].length}  from Kube API @ #{Time.now.utc.iso8601}")
                  podInventory["items"].each do |item|
                    key = item["metadata"]["uid"]
                    if !key.nil? && !key.empty?
                      podItem = KubernetesApiClient.getOptimizedItem("pods-perf", item)
                      if !podItem.nil? && !podItem.empty?
                        @podCacheMutex.synchronize {
                          @podItemsCache[key] = podItem
                        }
                      else
                        $log.warn "in_kube_perfinventory::watch_pods:Received podItem either empty or nil  @ #{Time.now.utc.iso8601}"
                      end
                    else
                      $log.warn "in_kube_perfinventory::watch_pods:Received poduid either nil or empty  @ #{Time.now.utc.iso8601}"
                    end
                  end
                end
              else
                $log.warn "in_kube_perfinventory::watch_pods:Received empty podInventory"
              end
              while (!continuationToken.nil? && !continuationToken.empty?)
                resourceUri = "pods?limit=#{@PODS_CHUNK_SIZE}&continue=#{continuationToken}"
                continuationToken, podInventory, responseCode = KubernetesApiClient.getResourcesAndContinuationTokenV2(resourceUri)
                if responseCode.nil? || responseCode != "200"
                  $log.warn("in_kube_perfinventory::watch_pods:Getting pods from Kube API: #{resourceUri} failed with statuscode: #{responseCode} @ #{Time.now.utc.iso8601}")
                  podsResourceVersion = nil
                  break  # break, if any of the pagination call failed so that full cache will rebuild with LIST again
                else
                  if (!podInventory.nil? && !podInventory.empty?)
                    podsResourceVersion = podInventory["metadata"]["resourceVersion"]
                    if (podInventory.key?("items") && !podInventory["items"].nil? && !podInventory["items"].empty?)
                      $log.info("in_kube_perfinventory::watch_pods:number of pod items :#{podInventory["items"].length} from Kube API @ #{Time.now.utc.iso8601}")
                      podInventory["items"].each do |item|
                        key = item["metadata"]["uid"]
                        if !key.nil? && !key.empty?
                          podItem = KubernetesApiClient.getOptimizedItem("pods-perf", item)
                          if !podItem.nil? && !podItem.empty?
                            @podCacheMutex.synchronize {
                              @podItemsCache[key] = podItem
                            }
                          else
                            $log.warn "in_kube_perfinventory::watch_pods:Received podItem is empty or nil  @ #{Time.now.utc.iso8601}"
                          end
                        else
                          $log.warn "in_kube_perfinventory::watch_pods:Received poduid either nil or empty  @ #{Time.now.utc.iso8601}"
                        end
                      end
                    end
                  else
                    $log.warn "in_kube_perfinventory::watch_pods:Received empty podInventory  @ #{Time.now.utc.iso8601}"
                  end
                end
              end
            end
          end
          if podsResourceVersion.nil? || podsResourceVersion.empty? || podsResourceVersion == "0"
            # https://github.com/kubernetes/kubernetes/issues/74022
            $log.warn("in_kube_perfinventory::watch_pods:received podsResourceVersion: #{podsResourceVersion} either nil or empty or 0 @ #{Time.now.utc.iso8601}")
            podsResourceVersion = nil # for the LIST to happen again
            sleep(30) # do not overwhelm the api-server if api-server broken
          else
            begin
              $log.info("in_kube_perfinventory::watch_pods:Establishing Watch connection for pods with resourceversion: #{podsResourceVersion} @ #{Time.now.utc.iso8601}")
              watcher = KubernetesApiClient.watch("pods", resource_version: podsResourceVersion, allow_watch_bookmarks: true)
              if watcher.nil?
                $log.warn("in_kube_perfinventory::watch_pods:watch API returned nil watcher for watch connection with resource version: #{podsResourceVersion} @ #{Time.now.utc.iso8601}")
              else
                watcher.each do |notice|
                  case notice["type"]
                  when "ADDED", "MODIFIED", "DELETED", "BOOKMARK"
                    item = notice["object"]
                    # extract latest resource version to use for watch reconnect
                    if !item.nil? && !item.empty? &&
                       !item["metadata"].nil? && !item["metadata"].empty? &&
                       !item["metadata"]["resourceVersion"].nil? && !item["metadata"]["resourceVersion"].empty?
                      podsResourceVersion = item["metadata"]["resourceVersion"]
                      # $log.info("in_kube_perfinventory::watch_pods:received event type: #{notice["type"]} with resource version: #{podsResourceVersion} @ #{Time.now.utc.iso8601}")
                    else
                      $log.warn("in_kube_perfinventory::watch_pods:received event type with no resourceVersion hence stopping watcher to reconnect @ #{Time.now.utc.iso8601}")
                      podsResourceVersion = nil
                      # We have to abort here because this might cause lastResourceVersion inconsistency by skipping a potential RV with valid data!
                      break
                    end
                    if ((notice["type"] == "ADDED") || (notice["type"] == "MODIFIED"))
                      key = item["metadata"]["uid"]
                      if !key.nil? && !key.empty?
                        podItem = KubernetesApiClient.getOptimizedItem("pods-perf", item)
                        if !podItem.nil? && !podItem.empty?
                          @podCacheMutex.synchronize {
                            @podItemsCache[key] = podItem
                          }
                        else
                          $log.warn "in_kube_perfinventory::watch_pods:Received podItem is empty or nil  @ #{Time.now.utc.iso8601}"
                        end
                      else
                        $log.warn "in_kube_perfinventory::watch_pods:Received poduid either nil or empty  @ #{Time.now.utc.iso8601}"
                      end
                    elsif notice["type"] == "DELETED"
                      key = item["metadata"]["uid"]
                      if !key.nil? && !key.empty?
                        @podCacheMutex.synchronize {
                          @podItemsCache.delete(key)
                        }
                      end
                    end
                  when "ERROR"
                    podsResourceVersion = nil
                    $log.warn("in_kube_perfinventory::watch_pods:ERROR event with :#{notice["object"]} @ #{Time.now.utc.iso8601}")
                    break
                  else
                    podsResourceVersion = nil
                    $log.warn("in_kube_perfinventory::watch_pods:Unsupported event type #{notice["type"]} @ #{Time.now.utc.iso8601}")
                  end
                end
                $log.warn("in_kube_perfinventory::watch_pods:Watch connection got disconnected for pods @ #{Time.now.utc.iso8601}")
              end
            rescue Net::ReadTimeout => errorStr
              ## This expected if there is no activity more than readtimeout value used in the connection
              # $log.warn("in_kube_perfinventory::watch_pods:Watch failed with an error: #{errorStr} @ #{Time.now.utc.iso8601}")
            rescue => errorStr
              $log.warn("in_kube_perfinventory::watch_pods:Watch failed with an error: #{errorStr} @ #{Time.now.utc.iso8601}")
              podsResourceVersion = nil
              sleep(5) # do not overwhelm the api-server if api-server broken
            ensure
              watcher.finish if watcher
            end
          end
        rescue => errorStr
          $log.warn("in_kube_perfinventory::watch_pods:failed with an error: #{errorStr} @ #{Time.now.utc.iso8601}")
          podsResourceVersion = nil
        end
      end
      $log.info("in_kube_perfinventory::watch_pods:End @ #{Time.now.utc.iso8601}")
    end

    def getNodeAllocatableRecords()
      maxRetryCount = 5
      initialRetryDelaySecs = 0.5
      retryAttemptCount = 1
      nodeAllocatableRecords = {}
      begin
        f = File.open(Constants::NODE_ALLOCATABLE_RECORDS_STATE_FILE, "r")
        if !f.nil?
          isAcquiredLock = f.flock(File::LOCK_EX | File::LOCK_NB)
          raise "in_kube_perfinventory:getNodeAllocatableRecords:Failed to acquire file lock @ #{Time.now.utc.iso8601}" if !isAcquiredLock
          startTime = (Time.now.to_f * 1000).to_i
          nodeAllocatableRecords = JSON.parse(f.read)
          timetakenMs = ((Time.now.to_f * 1000).to_i - startTime)
          $log.info "in_kube_perfinventory:getNodeAllocatableRecords:Number of Node Allocatable records: #{nodeAllocatableRecords.length} with time taken(ms) for read: #{timetakenMs} @ #{Time.now.utc.iso8601}"
        else
          raise "in_kube_perfinventory:getNodeAllocatableRecords:Failed to open file for read @ #{Time.now.utc.iso8601}"
        end
      rescue => err
        if retryAttemptCount < maxRetryCount
          f.flock(File::LOCK_UN) if !f.nil?
          f.close if !f.nil?
          sleep (initialRetryDelaySecs * retryAttemptCount)
          retryAttemptCount = retryAttemptCount + 1
          retry
        end
        $log.warn "in_kube_perfinventory:getNodeAllocatableRecords failed with an error: #{err} after retries: #{maxRetryCount} @  #{Time.now.utc.iso8601}"
        ApplicationInsightsUtility.sendExceptionTelemetry(err)
      ensure
        f.flock(File::LOCK_UN) if !f.nil?
        f.close if !f.nil?
      end
      return nodeAllocatableRecords
    end
  end # Kube_Pod_Input
end # module
