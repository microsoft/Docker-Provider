#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent
  class Kube_PodInventory_Input < Input
    Plugin.register_input("kubepodinventory", self)

    @@MDMKubePodInventoryTag = "mdm.kubepodinventory"
    @@hostName = (OMS::Common.get_hostname)

    def initialize
      super
      require "yaml"
      require "json"
      require "set"

      require_relative "KubernetesApiClient"
      require_relative "ApplicationInsightsUtility"
      require_relative "oms_common"
      require_relative "omslog"
    end

    config_param :run_interval, :time, :default => "1m"
    config_param :tag, :string, :default => "oms.containerinsights.KubePodInventory"

    def configure(conf)
      super
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
      podInventory = podList
      $log.info("in_kube_podinventory::enumerate : Getting pods from Kube API @ #{Time.now.utc.iso8601}")
      podInfo = KubernetesApiClient.getKubeResourceInfo("pods")
      $log.info("in_kube_podinventory::enumerate : Done getting pods from Kube API @ #{Time.now.utc.iso8601}")

      if !podInfo.nil?
        podInventory = JSON.parse(podInfo.body)
      end

      begin
        if (!podInventory.nil? && !podInventory.empty? && podInventory.key?("items") && !podInventory["items"].empty?)
          #get pod inventory & services
          $log.info("in_kube_podinventory::enumerate : Getting services from Kube API @ #{Time.now.utc.iso8601}")
          serviceList = nil
          serviceInfo = KubernetesApiClient.getKubeResourceInfo("services")

          if !serviceInfo.nil?
            serviceList = JSON.parse(serviceInfo.body)
          end
          
          $log.info("in_kube_podinventory::enumerate : Done getting services from Kube API @ #{Time.now.utc.iso8601}")
          parse_and_emit_records(podInventory, serviceList)
        else
          $log.warn "Received empty podInventory"
        end
      rescue => errorStr
        $log.warn "Failed in enumerate pod inventory: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def populateWindowsContainerInventoryRecord(container, record, containerEnvVariableHash, batchTime)
      begin
        containerInventoryRecord = {}
        containerName = container["name"]
        containerInventoryRecord["InstanceID"] = record["ContainerID"]
        containerInventoryRecord["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
        containerInventoryRecord["Computer"] = record["Computer"]
        containerInventoryRecord["ContainerHostname"] = record["Computer"]
        containerInventoryRecord["ElementName"] = containerName
        image = container["image"]
        repoInfo = image.split("/")
        if !repoInfo.nil?
          containerInventoryRecord["Repository"] = repoInfo[0]
          if !repoInfo[1].nil?
            imageInfo = repoInfo[1].split(":")
            if !imageInfo.nil?
              containerInventoryRecord["Image"] = imageInfo[0]
              containerInventoryRecord["ImageTag"] = imageInfo[1]
            end
          end
        end
        imageIdInfo = container["imageID"]
        imageIdSplitInfo = imageIdInfo.split("@")
        if !imageIdSplitInfo.nil?
          containerInventoryRecord["ImageId"] = imageIdSplitInfo[1]
        end
        # Get container state
        containerStatus = container["state"]
        if containerStatus.keys[0] == "running"
          containerInventoryRecord["State"] = "Running"
          containerInventoryRecord["StartedTime"] = container["state"]["running"]["startedAt"]
        elsif containerStatus.keys[0] == "terminated"
          containerExitCode = container["state"]["terminated"]["exitCode"]
          containerStartTime = container["state"]["terminated"]["startedAt"]
          containerFinishTime = container["state"]["terminated"]["finishedAt"]
          if containerExitCode < 0
            # Exit codes less than 0 are not supported by the engine
            containerExitCode = 128
          end
          if containerExitCode > 0
            containerInventoryRecord["State"] = "Failed"
          else
            containerInventoryRecord["State"] = "Stopped"
          end
          containerInventoryRecord["ExitCode"] = containerExitCode
          containerInventoryRecord["StartedTime"] = containerStartTime
          containerInventoryRecord["FinishedTime"] = containerFinishTime
        elsif containerStatus.keys[0] == "waiting"
          containerInventoryRecord["State"] = "Waiting"
        end
        if !containerEnvVariableHash.nil? && !containerEnvVariableHash.empty?
          containerInventoryRecord["EnvironmentVar"] = containerEnvVariableHash[containerName]
        end
        return containerInventoryRecord
      rescue => errorStr
        $log.warn "Failed in populateWindowsContainerInventoryRecord: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def getContainerEnvironmentVariables(pod, clusterCollectEnvironmentVar)
      begin
        podSpec = pod["spec"]
        containerEnvHash = {}
        podContainersEnv = []
        if !podSpec["containers"].nil? && !podSpec["containers"].empty?
          podContainersEnv = podContainersEnv + podSpec["containers"]
        end
        # Adding init containers to the record list as well.
        if !podSpec["initContainers"].nil? && !podSpec["initContainers"].empty?
          podContainersEnv = podContainersEnv + podSpec["initContainers"]
        end
        if !podContainersEnv.nil? && !podContainersEnv.empty?
          podContainersEnv.each do |container|
            if !clusterCollectEnvironmentVar.nil? && !clusterCollectEnvironmentVar.empty? && clusterCollectEnvironmentVar.casecmp("false") == 0
              containerEnvHash[container["name"]] = ["AZMON_CLUSTER_COLLECT_ENV_VAR=FALSE"]
            else
              envVarsArray = []
              containerEnvArray = container["env"]
              # Parsing the environment variable array of hashes to a string value
              # since that is format being sent by container inventory workflow in daemonset
              # Keeping it in the same format because the workflow expects it in this format
              # and the UX expects an array of string for environment variables
              if !containerEnvArray.nil? && !containerEnvArray.empty?
                containerEnvArray.each do |envVarHash|
                  envName = envVarHash["name"]
                  envValue = envVarHash["value"]
                  if !envName.nil? && !envValue.nil?
                    envArrayElement = envName + "=" + envValue
                    envVarsArray.push(envArrayElement)
                  end
                end
              end
              # Skip environment variable processing if it contains the flag AZMON_COLLECT_ENV=FALSE
              envValueString = envVarsArray.to_s
              if /AZMON_COLLECT_ENV=FALSE/i.match(envValueString)
                envValueString = ["AZMON_COLLECT_ENV=FALSE"]
                $log.warn("Environment Variable collection for container: #{container["name"]} skipped because AZMON_COLLECT_ENV is set to false")
              end
              containerEnvHash[container["name"]] = envValueString
            end
          end
        end
        return containerEnvHash
      rescue => errorStr
        $log.warn "Failed in getContainerEnvironmentVariables: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def parse_and_emit_records(podInventory, serviceList)
      currentTime = Time.now
      emitTime = currentTime.to_f
      batchTime = currentTime.utc.iso8601
      eventStream = MultiEventStream.new
      controllerSet = Set.new []
      controllerData = {}
      telemetryFlush = false
      winContainerCount = 0
      begin #begin block start
        # Getting windows nodes from kubeapi
        winNodes = KubernetesApiClient.getWindowsNodesArray

        podInventory["items"].each do |items| #podInventory block start
          sendWindowsContainerInventoryRecord = false
          containerInventoryRecords = []
          records = []
          record = {}
          record["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
          record["Name"] = items["metadata"]["name"]
          podNameSpace = items["metadata"]["namespace"]

          if podNameSpace.eql?("kube-system") && !items["metadata"].key?("ownerReferences")
            # The above case seems to be the only case where you have horizontal scaling of pods
            # but no controller, in which case cAdvisor picks up kubernetes.io/config.hash
            # instead of the actual poduid. Since this uid is not being surface into the UX
            # its ok to use this.
            # Use kubernetes.io/config.hash to be able to correlate with cadvisor data
            if items["metadata"]["annotations"].nil?
              next
            else
              podUid = items["metadata"]["annotations"]["kubernetes.io/config.hash"]
            end
          else
            podUid = items["metadata"]["uid"]
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
              if !clusterCollectEnvironmentVar.nil? && !clusterCollectEnvironmentVar.empty? && clusterCollectEnvironmentVar.casecmp("false") == 0
                $log.warn("WindowsContainerInventory: Environment Variable collection disabled for cluster")
              end
              sendWindowsContainerInventoryRecord = true
              containerEnvVariableHash = getContainerEnvironmentVariables(items, clusterCollectEnvironmentVar)
            end
          end

          record["ClusterId"] = KubernetesApiClient.getClusterId
          record["ClusterName"] = KubernetesApiClient.getClusterName
          record["ServiceName"] = getServiceNameFromLabels(items["metadata"]["namespace"], items["metadata"]["labels"], serviceList)
          # Adding telemetry to send pod telemetry every 5 minutes
          timeDifference = (DateTime.now.to_time.to_i - @@podTelemetryTimeTracker).abs
          timeDifferenceInMinutes = timeDifference / 60
          if (timeDifferenceInMinutes >= 5)
            telemetryFlush = true
          end
          if !items["metadata"]["ownerReferences"].nil?
            record["ControllerKind"] = items["metadata"]["ownerReferences"][0]["kind"]
            record["ControllerName"] = items["metadata"]["ownerReferences"][0]["name"]
            if telemetryFlush == true
              controllerSet.add(record["ControllerKind"] + record["ControllerName"])
              #Adding controller kind to telemetry ro information about customer workload
              if (controllerData[record["ControllerKind"]].nil?)
                controllerData[record["ControllerKind"]] = 1
              else
                controllerValue = controllerData[record["ControllerKind"]]
                controllerData[record["ControllerKind"]] += 1
              end
            end
          end
          podRestartCount = 0
          record["PodRestartCount"] = 0

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
                    newRecord["reason"] = lastStateObject["reason"]  # (ex: OOMKilled)
                    newRecord["startedAt"] = lastStateObject["startedAt"]  # (ex: 2019-07-02T14:58:51Z)
                    newRecord["finishedAt"] = lastStateObject["finishedAt"]  # (ex: 2019-07-02T14:58:52Z)

                    # only write to the output field if everything previously ran without error
                    record["ContainerLastStatus"] = newRecord
                  else
                    record["ContainerLastStatus"] = Hash.new
                  end
                else
                  record["ContainerLastStatus"] = Hash.new
                end
              rescue => errorStr
                $log.warn "Failed in parse_and_emit_record pod inventory while processing ContainerLastStatus: #{errorStr}"
                $log.debug_backtrace(errorStr.backtrace)
                ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
                record["ContainerLastStatus"] = Hash.new
              end

              podRestartCount += containerRestartCount
              records.push(record.dup)

              #Generate ContainerInventory records for windows nodes so that we can get image and image tag in property panel
              if sendWindowsContainerInventoryRecord == true
                containerInventoryRecord = populateWindowsContainerInventoryRecord(container, record, containerEnvVariableHash, batchTime)
                containerInventoryRecords.push(containerInventoryRecord)
              end
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
            end
          end
          # Send container inventory records for containers on windows nodes
          winContainerCount += containerInventoryRecords.length
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
        router.emit_stream(@@MDMKubePodInventoryTag, eventStream) if eventStream
        if telemetryFlush == true
          telemetryProperties = {}
          telemetryProperties["Computer"] = @@hostName
          ApplicationInsightsUtility.sendCustomEvent("KubePodInventoryHeartBeatEvent", telemetryProperties)
          ApplicationInsightsUtility.sendMetricTelemetry("PodCount", podInventory["items"].length, {})
          telemetryProperties["ControllerData"] = controllerData.to_json
          ApplicationInsightsUtility.sendMetricTelemetry("ControllerCount", controllerSet.length, telemetryProperties)
          if winContainerCount > 0
            telemetryProperties["ClusterWideWindowsContainersCount"] = winContainerCount
            ApplicationInsightsUtility.sendCustomEvent("WindowsContainerInventoryEvent", telemetryProperties)
          end
          @@podTelemetryTimeTracker = DateTime.now.to_time.to_i
        end
        @@istestvar = ENV["ISTEST"]
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
      until done
        @condition.wait(@mutex, @run_interval)
        done = @finished
        @mutex.unlock
        if !done
          begin
            $log.info("in_kube_podinventory::run_periodic @ #{Time.now.utc.iso8601}")
            enumerate
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
