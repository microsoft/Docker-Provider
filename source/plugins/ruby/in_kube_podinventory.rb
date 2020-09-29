#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent
  require_relative "podinventory_to_mdm"      

  class Kube_PodInventory_Input < Input
    Plugin.register_input("kubepodinventory", self)

    @@MDMKubePodInventoryTag = "mdm.kubepodinventory"
    @@hostName = (OMS::Common.get_hostname)
    @@kubeperfTag = "oms.api.KubePerf"
    @@kubeservicesTag = "oms.containerinsights.KubeServices"

    def initialize
      super
      require "yaml"
      require "yajl/json_gem"
      require "yajl"
      require "set"
      require "time"
      
      require_relative "kubernetes_container_inventory"
      require_relative "KubernetesApiClient"
      require_relative "ApplicationInsightsUtility"
      require_relative "oms_common"
      require_relative "omslog"
      require_relative "constants"

      @PODS_CHUNK_SIZE = "1500"
      @podCount = 0
      @controllerSet = Set.new []
      @winContainerCount = 0
      @controllerData = {}
    end

    config_param :run_interval, :time, :default => 60
    config_param :tag, :string, :default => "oms.containerinsights.KubePodInventory"
    config_param :custom_metrics_azure_regions, :string

    def configure(conf)
      super
      @inventoryToMdmConvertor = Inventory2MdmConvertor.new(@custom_metrics_azure_regions)
    end

    def start
      if @run_interval
        @finished = false
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
        @@podTelemetryTimeTracker = DateTime.now.to_time.to_i
      end
    end

    def shutdown
      if @run_interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end

    def enumerate(podList = nil)
      begin
        podInventory = podList
        telemetryFlush = false
        @podCount = 0
        @controllerSet = Set.new []
        @winContainerCount = 0
        @controllerData = {}
        currentTime = Time.now
        batchTime = currentTime.utc.iso8601

        # Get services first so that we dont need to make a call for very chunk
        $log.info("in_kube_podinventory::enumerate : Getting services from Kube API @ #{Time.now.utc.iso8601}")
        serviceInfo = KubernetesApiClient.getKubeResourceInfo("services")
        # serviceList = JSON.parse(KubernetesApiClient.getKubeResourceInfo("services").body)
        $log.info("in_kube_podinventory::enumerate : Done getting services from Kube API @ #{Time.now.utc.iso8601}")

        if !serviceInfo.nil?
          $log.info("in_kube_podinventory::enumerate:Start:Parsing services data using yajl @ #{Time.now.utc.iso8601}")
          serviceList = Yajl::Parser.parse(StringIO.new(serviceInfo.body))
          $log.info("in_kube_podinventory::enumerate:End:Parsing services data using yajl @ #{Time.now.utc.iso8601}")
          serviceInfo = nil
        end

        # Initializing continuation token to nil
        continuationToken = nil
        $log.info("in_kube_podinventory::enumerate : Getting pods from Kube API @ #{Time.now.utc.iso8601}")
        continuationToken, podInventory = KubernetesApiClient.getResourcesAndContinuationToken("pods?limit=#{@PODS_CHUNK_SIZE}")
        $log.info("in_kube_podinventory::enumerate : Done getting pods from Kube API @ #{Time.now.utc.iso8601}")
        if (!podInventory.nil? && !podInventory.empty? && podInventory.key?("items") && !podInventory["items"].nil? && !podInventory["items"].empty?)
          parse_and_emit_records(podInventory, serviceList, continuationToken, batchTime)
        else
          $log.warn "in_kube_podinventory::enumerate:Received empty podInventory"
        end

        #If we receive a continuation token, make calls, process and flush data until we have processed all data
        while (!continuationToken.nil? && !continuationToken.empty?)
          continuationToken, podInventory = KubernetesApiClient.getResourcesAndContinuationToken("pods?limit=#{@PODS_CHUNK_SIZE}&continue=#{continuationToken}")
          if (!podInventory.nil? && !podInventory.empty? && podInventory.key?("items") && !podInventory["items"].nil? && !podInventory["items"].empty?)
            parse_and_emit_records(podInventory, serviceList, continuationToken, batchTime)
          else
            $log.warn "in_kube_podinventory::enumerate:Received empty podInventory"
          end
        end

        # Setting these to nil so that we dont hold memory until GC kicks in
        podInventory = nil
        serviceList = nil

        # Adding telemetry to send pod telemetry every 5 minutes
        timeDifference = (DateTime.now.to_time.to_i - @@podTelemetryTimeTracker).abs
        timeDifferenceInMinutes = timeDifference / 60
        if (timeDifferenceInMinutes >= 5)
          telemetryFlush = true
        end

        # Flush AppInsights telemetry once all the processing is done
        if telemetryFlush == true
          telemetryProperties = {}
          telemetryProperties["Computer"] = @@hostName
          ApplicationInsightsUtility.sendCustomEvent("KubePodInventoryHeartBeatEvent", telemetryProperties)
          ApplicationInsightsUtility.sendMetricTelemetry("PodCount", @podCount, {})
          telemetryProperties["ControllerData"] = @controllerData.to_json
          ApplicationInsightsUtility.sendMetricTelemetry("ControllerCount", @controllerSet.length, telemetryProperties)
          if @winContainerCount > 0
            telemetryProperties["ClusterWideWindowsContainersCount"] = @winContainerCount
            ApplicationInsightsUtility.sendCustomEvent("WindowsContainerInventoryEvent", telemetryProperties)
          end
          @@podTelemetryTimeTracker = DateTime.now.to_time.to_i
        end
      rescue => errorStr
        $log.warn "in_kube_podinventory::enumerate:Failed in enumerate: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end    

    def parse_and_emit_records(podInventory, serviceList, continuationToken, batchTime = Time.utc.iso8601)
      currentTime = Time.now
      emitTime = currentTime.to_f
      #batchTime = currentTime.utc.iso8601
      eventStream = MultiEventStream.new
      @@istestvar = ENV["ISTEST"]

      begin #begin block start
        # Getting windows nodes from kubeapi
        winNodes = KubernetesApiClient.getWindowsNodesArray

        podInventory["items"].each do |items| #podInventory block start          
          containerInventoryRecords = []
          records = []
          record = {}
          record["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
          record["Name"] = items["metadata"]["name"]
          podNameSpace = items["metadata"]["namespace"]

          # For ARO v3 cluster, skip the pods scheduled on to master or infra nodes
          if KubernetesApiClient.isAROV3Cluster && !items["spec"].nil? && !items["spec"]["nodeName"].nil? &&
             (items["spec"]["nodeName"].downcase.start_with?("infra-") ||
              items["spec"]["nodeName"].downcase.start_with?("master-"))
            next
          end

          podUid = KubernetesApiClient.getPodUid(podNameSpace, items["metadata"])
          if podUid.nil?
            next
          end
          record["PodUid"] = podUid
          record["PodLabel"] = [items["metadata"]["labels"]]
          record["Namespace"] = podNameSpace
          record["PodCreationTimeStamp"] = items["metadata"]["creationTimestamp"]
          #for unscheduled (non-started) pods startTime does NOT exist
          if !items["status"]["startTime"].nil?
            record["PodStartTime"] = items["status"]["startTime"]
          else
            record["PodStartTime"] = ""
          end
          #podStatus
          # the below is for accounting 'NodeLost' scenario, where-in the pod(s) in the lost node is still being reported as running
          podReadyCondition = true
          if !items["status"]["reason"].nil? && items["status"]["reason"] == "NodeLost" && !items["status"]["conditions"].nil?
            items["status"]["conditions"].each do |condition|
              if condition["type"] == "Ready" && condition["status"] == "False"
                podReadyCondition = false
                break
              end
            end
          end

          if podReadyCondition == false
            record["PodStatus"] = "Unknown"
          # ICM - https://portal.microsofticm.com/imp/v3/incidents/details/187091803/home
          elsif !items["metadata"]["deletionTimestamp"].nil? && !items["metadata"]["deletionTimestamp"].empty?
            record["PodStatus"] = Constants::POD_STATUS_TERMINATING
          else
            record["PodStatus"] = items["status"]["phase"]
          end
          #for unscheduled (non-started) pods podIP does NOT exist
          if !items["status"]["podIP"].nil?
            record["PodIp"] = items["status"]["podIP"]
          else
            record["PodIp"] = ""
          end
          #for unscheduled (non-started) pods nodeName does NOT exist
          if !items["spec"]["nodeName"].nil?
            record["Computer"] = items["spec"]["nodeName"]
          else
            record["Computer"] = ""
          end

          # Setting this flag to true so that we can send ContainerInventory records for containers
          # on windows nodes and parse environment variables for these containers
          if winNodes.length > 0
            if (!record["Computer"].empty? && (winNodes.include? record["Computer"]))
              clusterCollectEnvironmentVar = ENV["AZMON_CLUSTER_COLLECT_ENV_VAR"]
              #Generate ContainerInventory records for windows nodes so that we can get image and image tag in property panel
              containerInventoryRecordsInPodItem = KubernetesContainerInventory.getContainerInventoryRecords(items, batchTime, clusterCollectEnvironmentVar, true)  
              containerInventoryRecordsInPodItem.each do |containerRecord|
                containerInventoryRecords.push(containerRecord)          
              end              
            end
          end

          record["ClusterId"] = KubernetesApiClient.getClusterId
          record["ClusterName"] = KubernetesApiClient.getClusterName
          record["ServiceName"] = getServiceNameFromLabels(items["metadata"]["namespace"], items["metadata"]["labels"], serviceList)

          if !items["metadata"]["ownerReferences"].nil?
            record["ControllerKind"] = items["metadata"]["ownerReferences"][0]["kind"]
            record["ControllerName"] = items["metadata"]["ownerReferences"][0]["name"]
            @controllerSet.add(record["ControllerKind"] + record["ControllerName"])
            #Adding controller kind to telemetry ro information about customer workload
            if (@controllerData[record["ControllerKind"]].nil?)
              @controllerData[record["ControllerKind"]] = 1
            else
              controllerValue = @controllerData[record["ControllerKind"]]
              @controllerData[record["ControllerKind"]] += 1
            end
          end
          podRestartCount = 0
          record["PodRestartCount"] = 0

          #Invoke the helper method to compute ready/not ready mdm metric
          @inventoryToMdmConvertor.process_record_for_pods_ready_metric(record["ControllerName"], record["Namespace"], items["status"]["conditions"])

          podContainers = []
          if items["status"].key?("containerStatuses") && !items["status"]["containerStatuses"].empty?
            podContainers = podContainers + items["status"]["containerStatuses"]
          end
          # Adding init containers to the record list as well.
          if items["status"].key?("initContainerStatuses") && !items["status"]["initContainerStatuses"].empty?
            podContainers = podContainers + items["status"]["initContainerStatuses"]
          end

          # if items["status"].key?("containerStatuses") && !items["status"]["containerStatuses"].empty? #container status block start
          if !podContainers.empty? #container status block start
            podContainers.each do |container|
              containerRestartCount = 0
              lastFinishedTime = nil
              # Need this flag to determine if we need to process container data for mdm metrics like oomkilled and container restart
              #container Id is of the form
              #docker://dfd9da983f1fd27432fb2c1fe3049c0a1d25b1c697b2dc1a530c986e58b16527
              if !container["containerID"].nil?
                record["ContainerID"] = container["containerID"].split("//")[1]
              else
                # for containers that have image issues (like invalid image/tag etc..) this will be empty. do not make it all 0
                record["ContainerID"] = ""
              end
              #keeping this as <PodUid/container_name> which is same as InstanceName in perf table
              if podUid.nil? || container["name"].nil?
                next
              else
                record["ContainerName"] = podUid + "/" + container["name"]
              end
              #Pod restart count is a sumtotal of restart counts of individual containers
              #within the pod. The restart count of a container is maintained by kubernetes
              #itself in the form of a container label.
              containerRestartCount = container["restartCount"]
              record["ContainerRestartCount"] = containerRestartCount

              containerStatus = container["state"]
              record["ContainerStatusReason"] = ""
              # state is of the following form , so just picking up the first key name
              # "state": {
              #   "waiting": {
              #     "reason": "CrashLoopBackOff",
              #      "message": "Back-off 5m0s restarting failed container=metrics-server pod=metrics-server-2011498749-3g453_kube-system(5953be5f-fcae-11e7-a356-000d3ae0e432)"
              #   }
              # },
              # the below is for accounting 'NodeLost' scenario, where-in the containers in the lost node/pod(s) is still being reported as running
              if podReadyCondition == false
                record["ContainerStatus"] = "Unknown"
              else
                record["ContainerStatus"] = containerStatus.keys[0]
              end
              #TODO : Remove ContainerCreationTimeStamp from here since we are sending it as a metric
              #Picking up both container and node start time from cAdvisor to be consistent
              if containerStatus.keys[0] == "running"
                record["ContainerCreationTimeStamp"] = container["state"]["running"]["startedAt"]
              else
                if !containerStatus[containerStatus.keys[0]]["reason"].nil? && !containerStatus[containerStatus.keys[0]]["reason"].empty?
                  record["ContainerStatusReason"] = containerStatus[containerStatus.keys[0]]["reason"]
                end
                # Process the record to see if job was completed 6 hours ago. If so, send metric to mdm
                if !record["ControllerKind"].nil? && record["ControllerKind"].downcase == Constants::CONTROLLER_KIND_JOB
                  @inventoryToMdmConvertor.process_record_for_terminated_job_metric(record["ControllerName"], record["Namespace"], containerStatus)
                end
              end

              # Record the last state of the container. This may have information on why a container was killed.
              begin
                if !container["lastState"].nil? && container["lastState"].keys.length == 1
                  lastStateName = container["lastState"].keys[0]
                  lastStateObject = container["lastState"][lastStateName]
                  if !lastStateObject.is_a?(Hash)
                    raise "expected a hash object. This could signify a bug or a kubernetes API change"
                  end

                  if lastStateObject.key?("reason") && lastStateObject.key?("startedAt") && lastStateObject.key?("finishedAt")
                    newRecord = Hash.new
                    newRecord["lastState"] = lastStateName  # get the name of the last state (ex: terminated)
                    lastStateReason = lastStateObject["reason"]
                    # newRecord["reason"] = lastStateObject["reason"]  # (ex: OOMKilled)
                    newRecord["reason"] = lastStateReason  # (ex: OOMKilled)
                    newRecord["startedAt"] = lastStateObject["startedAt"]  # (ex: 2019-07-02T14:58:51Z)
                    lastFinishedTime = lastStateObject["finishedAt"]
                    newRecord["finishedAt"] = lastFinishedTime  # (ex: 2019-07-02T14:58:52Z)

                    # only write to the output field if everything previously ran without error
                    record["ContainerLastStatus"] = newRecord

                    #Populate mdm metric for OOMKilled container count if lastStateReason is OOMKilled
                    if lastStateReason.downcase == Constants::REASON_OOM_KILLED
                      @inventoryToMdmConvertor.process_record_for_oom_killed_metric(record["ControllerName"], record["Namespace"], lastFinishedTime)
                    end
                    lastStateReason = nil
                  else
                    record["ContainerLastStatus"] = Hash.new
                  end
                else
                  record["ContainerLastStatus"] = Hash.new
                end

                #Populate mdm metric for container restart count if greater than 0
                if (!containerRestartCount.nil? && (containerRestartCount.is_a? Integer) && containerRestartCount > 0)
                  @inventoryToMdmConvertor.process_record_for_container_restarts_metric(record["ControllerName"], record["Namespace"], lastFinishedTime)
                end
              rescue => errorStr
                $log.warn "Failed in parse_and_emit_record pod inventory while processing ContainerLastStatus: #{errorStr}"
                $log.debug_backtrace(errorStr.backtrace)
                ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
                record["ContainerLastStatus"] = Hash.new
              end

              podRestartCount += containerRestartCount
              records.push(record.dup)            
            end
          else # for unscheduled pods there are no status.containerStatuses, in this case we still want the pod
            records.push(record)
          end  #container status block end
          records.each do |record|
            if !record.nil?
              record["PodRestartCount"] = podRestartCount
              wrapper = {
                          "DataType" => "KUBE_POD_INVENTORY_BLOB",
                          "IPName" => "ContainerInsights",
                          "DataItems" => [record.each { |k, v| record[k] = v }],
                        }
              eventStream.add(emitTime, wrapper) if wrapper
              @inventoryToMdmConvertor.process_pod_inventory_record(wrapper)
            end
          end
          # Send container inventory records for containers on windows nodes
          @winContainerCount += containerInventoryRecords.length
          containerInventoryRecords.each do |cirecord|
            if !cirecord.nil?
              ciwrapper = {
                "DataType" => "CONTAINER_INVENTORY_BLOB",
                "IPName" => "ContainerInsights",
                "DataItems" => [cirecord.each { |k, v| cirecord[k] = v }],
              }
              eventStream.add(emitTime, ciwrapper) if ciwrapper
            end
          end
        end  #podInventory block end

        router.emit_stream(@tag, eventStream) if eventStream

        if continuationToken.nil? #no more chunks in this batch to be sent, get all pod inventory records to send
          @log.info "Sending pod inventory mdm records to out_mdm"
          pod_inventory_mdm_records = @inventoryToMdmConvertor.get_pod_inventory_mdm_records(batchTime)
          @log.info "pod_inventory_mdm_records.size #{pod_inventory_mdm_records.size}"
          mdm_pod_inventory_es = MultiEventStream.new
          pod_inventory_mdm_records.each { |pod_inventory_mdm_record|
            mdm_pod_inventory_es.add(batchTime, pod_inventory_mdm_record) if pod_inventory_mdm_record
          } if pod_inventory_mdm_records
          router.emit_stream(@@MDMKubePodInventoryTag, mdm_pod_inventory_es) if mdm_pod_inventory_es
        end

        #:optimize:kubeperf merge
        begin
          #if(!podInventory.empty?)
          containerMetricDataItems = []
          #hostName = (OMS::Common.get_hostname)
          containerMetricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(podInventory, "requests", "cpu", "cpuRequestNanoCores", batchTime))
          containerMetricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(podInventory, "requests", "memory", "memoryRequestBytes", batchTime))
          containerMetricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(podInventory, "limits", "cpu", "cpuLimitNanoCores", batchTime))
          containerMetricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(podInventory, "limits", "memory", "memoryLimitBytes", batchTime))

          kubePerfEventStream = MultiEventStream.new
          insightsMetricsEventStream = MultiEventStream.new

          containerMetricDataItems.each do |record|
            record["DataType"] = "LINUX_PERF_BLOB"
            record["IPName"] = "LogManagement"
            kubePerfEventStream.add(emitTime, record) if record
          end
          #end
          router.emit_stream(@@kubeperfTag, kubePerfEventStream) if kubePerfEventStream

          begin
            #start GPU InsightsMetrics items

            containerGPUInsightsMetricsDataItems = []
            containerGPUInsightsMetricsDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimitsAsInsightsMetrics(podInventory, "requests", "nvidia.com/gpu", "containerGpuRequests", batchTime))
            containerGPUInsightsMetricsDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimitsAsInsightsMetrics(podInventory, "limits", "nvidia.com/gpu", "containerGpuLimits", batchTime))

            containerGPUInsightsMetricsDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimitsAsInsightsMetrics(podInventory, "requests", "amd.com/gpu", "containerGpuRequests", batchTime))
            containerGPUInsightsMetricsDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimitsAsInsightsMetrics(podInventory, "limits", "amd.com/gpu", "containerGpuLimits", batchTime))

            containerGPUInsightsMetricsDataItems.each do |insightsMetricsRecord|
              wrapper = {
                "DataType" => "INSIGHTS_METRICS_BLOB",
                "IPName" => "ContainerInsights",
                "DataItems" => [insightsMetricsRecord.each { |k, v| insightsMetricsRecord[k] = v }],
              }
              insightsMetricsEventStream.add(emitTime, wrapper) if wrapper

              if (!@@istestvar.nil? && !@@istestvar.empty? && @@istestvar.casecmp("true") == 0 && insightsMetricsEventStream.count > 0)
                $log.info("kubePodInsightsMetricsEmitStreamSuccess @ #{Time.now.utc.iso8601}")
              end
            end

            router.emit_stream(Constants::INSIGHTSMETRICS_FLUENT_TAG, insightsMetricsEventStream) if insightsMetricsEventStream
            #end GPU InsightsMetrics items
          rescue => errorStr
            $log.warn "Failed when processing GPU metrics in_kube_podinventory : #{errorStr}"
            $log.debug_backtrace(errorStr.backtrace)
            ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
          end
        rescue => errorStr
          $log.warn "Failed in parse_and_emit_record for KubePerf from in_kube_podinventory : #{errorStr}"
          $log.debug_backtrace(errorStr.backtrace)
          ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
        end
        #:optimize:end kubeperf merge

        #:optimize:start kubeservices merge
        begin
          if (!serviceList.nil? && !serviceList.empty?)
            kubeServicesEventStream = MultiEventStream.new
            serviceList["items"].each do |items|
              kubeServiceRecord = {}
              kubeServiceRecord["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
              kubeServiceRecord["ServiceName"] = items["metadata"]["name"]
              kubeServiceRecord["Namespace"] = items["metadata"]["namespace"]
              kubeServiceRecord["SelectorLabels"] = [items["spec"]["selector"]]
              kubeServiceRecord["ClusterId"] = KubernetesApiClient.getClusterId
              kubeServiceRecord["ClusterName"] = KubernetesApiClient.getClusterName
              kubeServiceRecord["ClusterIP"] = items["spec"]["clusterIP"]
              kubeServiceRecord["ServiceType"] = items["spec"]["type"]
              #<TODO> : Add ports and status fields
              kubeServicewrapper = {
                "DataType" => "KUBE_SERVICES_BLOB",
                "IPName" => "ContainerInsights",
                "DataItems" => [kubeServiceRecord.each { |k, v| kubeServiceRecord[k] = v }],
              }
              kubeServicesEventStream.add(emitTime, kubeServicewrapper) if kubeServicewrapper
            end
            router.emit_stream(@@kubeservicesTag, kubeServicesEventStream) if kubeServicesEventStream
          end
        rescue => errorStr
          $log.warn "Failed in parse_and_emit_record for KubeServices from in_kube_podinventory : #{errorStr}"
          $log.debug_backtrace(errorStr.backtrace)
          ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
        end
        #:optimize:end kubeservices merge

        #Updating value for AppInsights telemetry
        @podCount += podInventory["items"].length

        if (!@@istestvar.nil? && !@@istestvar.empty? && @@istestvar.casecmp("true") == 0 && eventStream.count > 0)
          $log.info("kubePodInventoryEmitStreamSuccess @ #{Time.now.utc.iso8601}")
        end
      rescue => errorStr
        $log.warn "Failed in parse_and_emit_record pod inventory: #{errorStr}"
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
            $log.info("in_kube_podinventory::run_periodic.enumerate.start #{Time.now.utc.iso8601}")
            enumerate
            $log.info("in_kube_podinventory::run_periodic.enumerate.end #{Time.now.utc.iso8601}")
          rescue => errorStr
            $log.warn "in_kube_podinventory::run_periodic: enumerate Failed to retrieve pod inventory: #{errorStr}"
            ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end

    def getServiceNameFromLabels(namespace, labels, serviceList)
      serviceName = ""
      begin
        if !labels.nil? && !labels.empty?
          if (!serviceList.nil? && !serviceList.empty? && serviceList.key?("items") && !serviceList["items"].empty?)
            serviceList["items"].each do |item|
              found = 0
              if !item["spec"].nil? && !item["spec"]["selector"].nil? && item["metadata"]["namespace"] == namespace
                selectorLabels = item["spec"]["selector"]
                if !selectorLabels.empty?
                  selectorLabels.each do |key, value|
                    if !(labels.select { |k, v| k == key && v == value }.length > 0)
                      break
                    end
                    found = found + 1
                  end
                end
                if found == selectorLabels.length
                  return item["metadata"]["name"]
                end
              end
            end
          end
        end
      rescue => errorStr
        $log.warn "Failed to retrieve service name from labels: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return serviceName
    end
  end # Kube_Pod_Input
end # module
