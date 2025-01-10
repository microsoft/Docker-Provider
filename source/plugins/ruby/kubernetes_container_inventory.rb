#!/usr/local/bin/ruby
# frozen_string_literal: true

class KubernetesContainerInventory
  require "json"
  require "time"
  require_relative "omslog"
  require_relative "ApplicationInsightsUtility"

  # cache the container and cgroup parent process
  @@containerCGroupCache = Hash.new

  def initialize
  end

  class << self
    def getContainerInventoryRecords(podItem, batchTime, clusterCollectEnvironmentVar, isWindows = false)
      containerInventoryRecords = Array.new
      isKataRuntimePod = false
      begin
        containersInfoMap = getContainersInfoMap(podItem, isWindows)
        podContainersStatuses = []
        if !podItem["status"]["containerStatuses"].nil? && !podItem["status"]["containerStatuses"].empty?
          podContainersStatuses = podItem["status"]["containerStatuses"]
        end
        if !podItem["status"]["initContainerStatuses"].nil? && !podItem["status"]["initContainerStatuses"].empty?
          podContainersStatuses = podContainersStatuses + podItem["status"]["initContainerStatuses"]
        end
        isKataRuntimePod = isSandboxingPod(podItem)
        if !podContainersStatuses.empty?
          podContainersStatuses.each do |containerStatus|
            containerInventoryRecord = {}
            containerInventoryRecord["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
            containerName = containerStatus["name"]
            # containeId format is <containerRuntime>://<containerId>
            containerRuntime = ""
            containerId = ""
            if !containerStatus["containerID"].nil?
              containerRuntime = containerStatus["containerID"].split(":")[0]
              containerId = containerStatus["containerID"].split("//")[1]
              containerInventoryRecord["InstanceID"] = containerId
            else
              # for containers that have image issues (like invalid image/tag etc..) this will be empty. do not make it all 0
              containerInventoryRecord["InstanceID"] = containerId
            end
            # imagedId is of the format - repo@sha256:imageid
            imageIdValue = containerStatus["imageID"]
            if !imageIdValue.nil? && !imageIdValue.empty?
              atLocation = imageIdValue.index("@")
              if !atLocation.nil?
                containerInventoryRecord["ImageId"] = imageIdValue[(atLocation + 1)..-1]
              end
            end
            containerInventoryRecord["ExitCode"] = 0
            isContainerTerminated = false
            isContainerWaiting = false
            if !containerStatus["state"].nil? && !containerStatus["state"].empty?
              containerState = containerStatus["state"]
              if containerState.key?("running")
                containerInventoryRecord["State"] = "Running"
                containerInventoryRecord["StartedTime"] = containerState["running"]["startedAt"]
              elsif containerState.key?("terminated")
                containerInventoryRecord["State"] = "Terminated"
                containerInventoryRecord["StartedTime"] = containerState["terminated"]["startedAt"]
                containerInventoryRecord["FinishedTime"] = containerState["terminated"]["finishedAt"]
                exitCodeValue = containerState["terminated"]["exitCode"]
                if exitCodeValue < 0
                  exitCodeValue = 128
                end
                containerInventoryRecord["ExitCode"] = exitCodeValue
                if exitCodeValue > 0
                  containerInventoryRecord["State"] = "Failed"
                end
                isContainerTerminated = true
              elsif containerState.key?("waiting")
                containerInventoryRecord["State"] = "Waiting"
                isContainerWaiting = true
              end
            end

            restartCount = 0
            if !containerStatus["restartCount"].nil?
              restartCount = containerStatus["restartCount"]
            end

            containerInfoMap = containersInfoMap[containerName]
            # image can be in any one of below format in spec
            # repository/image[:imagetag | @digest], repository/image:imagetag@digest, repo/image, image:imagetag, image@digest, image
            imageValue = containerInfoMap["image"]
            if !imageValue.nil? && !imageValue.empty?
              # Find delimiters in image format
              atLocation = imageValue.index("@")
              isDigestSpecified = false
              if !atLocation.nil?
                # repository/image@digest or repository/image:imagetag@digest, image@digest
                imageValue = imageValue[0..(atLocation - 1)]
                # Use Digest from the spec's image in case when the status doesnt get populated i.e. container in pending or image pull back etc.
                if containerInventoryRecord["ImageId"].nil? || containerInventoryRecord["ImageId"].empty?
                  containerInventoryRecord["ImageId"] = imageValue[(atLocation + 1)..-1]
                end
                isDigestSpecified = true
              end
              slashLocation = imageValue.index("/")
              colonLocation = imageValue.index(":")
              if !colonLocation.nil?
                if slashLocation.nil?
                  # image:imagetag
                  containerInventoryRecord["Image"] = imageValue[0..(colonLocation - 1)]
                else
                  # repository/image:imagetag
                  containerInventoryRecord["Repository"] = imageValue[0..(slashLocation - 1)]
                  containerInventoryRecord["Image"] = imageValue[(slashLocation + 1)..(colonLocation - 1)]
                end
                containerInventoryRecord["ImageTag"] = imageValue[(colonLocation + 1)..-1]
              else
                if slashLocation.nil?
                  # image
                  containerInventoryRecord["Image"] = imageValue
                else
                  # repo/image
                  containerInventoryRecord["Repository"] = imageValue[0..(slashLocation - 1)]
                  containerInventoryRecord["Image"] = imageValue[(slashLocation + 1)..-1]
                end
                # if no tag specified, k8s assumes latest as imagetag and this is same behavior from docker API and from status.
                # Ref - https://kubernetes.io/docs/concepts/containers/images/#image-names
                if isDigestSpecified == false
                  containerInventoryRecord["ImageTag"] = "latest"
                end
              end
            end

            podName = containerInfoMap["PodName"]
            namespace = containerInfoMap["Namespace"]
            # containername in the format what docker sees
            containerNameInDockerFormat = "k8s_#{containerName}_#{podName}_#{namespace}_#{containerId}_#{restartCount}"
            containerInventoryRecord["ElementName"] = containerNameInDockerFormat
            containerInventoryRecord["Computer"] = containerInfoMap["Computer"]
            containerInventoryRecord["ContainerHostname"] = podName
            containerInventoryRecord["CreatedTime"] = containerInfoMap["CreatedTime"]
            containerInventoryRecord["EnvironmentVar"] = containerInfoMap["EnvironmentVar"]
            containerInventoryRecord["Ports"] = containerInfoMap["Ports"]
            containerInventoryRecord["Command"] = containerInfoMap["Command"]
            if !clusterCollectEnvironmentVar.nil? && !clusterCollectEnvironmentVar.empty? && clusterCollectEnvironmentVar.casecmp("false") == 0
              containerInventoryRecord["EnvironmentVar"] = ["AZMON_CLUSTER_COLLECT_ENV_VAR=FALSE"]
            elsif isWindows || isContainerTerminated || isContainerWaiting || isKataRuntimePod
              # for terminated and waiting containers, since the cproc doesnt exist we lost the env and we can only get this
              # for kata runtime pod(s) runs inside light weight VM, cant access host cproc
              containerInventoryRecord["EnvironmentVar"] = containerInfoMap["EnvironmentVar"]
            else
              if containerId.nil? || containerId.empty? || containerRuntime.nil? || containerRuntime.empty?
                containerInventoryRecord["EnvironmentVar"] = ""
              else
                if containerRuntime.casecmp("cri-o") == 0
                  # crio containers have conmon as parent process and we only to need get container main process envvars
                  containerInventoryRecord["EnvironmentVar"] = obtainContainerEnvironmentVars("crio-#{containerId}")
                else
                  containerInventoryRecord["EnvironmentVar"] = obtainContainerEnvironmentVars(containerId)
                end
              end
            end
            containerInventoryRecords.push containerInventoryRecord
          end
        end
      rescue => error
        $log.warn("KubernetesContainerInventory::getContainerInventoryRecords : Get Container Inventory Records failed: #{error}")
        $log.debug_backtrace(error.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(error)
      end
      return containerInventoryRecords
    end

    def getContainersInfoMap(podItem, isWindows)
      containersInfoMap = {}
      begin
        nodeName = (!podItem["spec"]["nodeName"].nil?) ? podItem["spec"]["nodeName"] : ""
        createdTime = podItem["metadata"]["creationTimestamp"]
        podName = podItem["metadata"]["name"]
        namespace = podItem["metadata"]["namespace"]
        if !podItem.nil? && !podItem.empty? && podItem.key?("spec") && !podItem["spec"].nil? && !podItem["spec"].empty?
          podContainers = []
          if !podItem["spec"]["containers"].nil? && !podItem["spec"]["containers"].empty?
            podContainers = podItem["spec"]["containers"]
          end
          if !podItem["spec"]["initContainers"].nil? && !podItem["spec"]["initContainers"].empty?
            podContainers = podContainers + podItem["spec"]["initContainers"]
          end
          if !podContainers.empty?
            podContainers.each do |container|
              containerInfoMap = {}
              containerName = container["name"]
              containerInfoMap["image"] = container["image"]
              containerInfoMap["ElementName"] = containerName
              containerInfoMap["Computer"] = nodeName
              containerInfoMap["PodName"] = podName
              containerInfoMap["Namespace"] = namespace
              containerInfoMap["CreatedTime"] = createdTime
              portsValue = container["ports"]
              portsValueString = (portsValue.nil?) ? "" : portsValue.to_s
              containerInfoMap["Ports"] = portsValueString
              cmdValue = container["command"]
              cmdValueString = (cmdValue.nil?) ? "" : cmdValue.to_s
              containerInfoMap["Command"] = cmdValueString
              if isWindows
                # For windows container inventory, we dont need to get envvars from pods response since its already taken care in KPI as part of pod optimized item
                containerInfoMap["EnvironmentVar"] = container["env"]
              else
                containerInfoMap["EnvironmentVar"] = obtainContainerEnvironmentVarsFromPodsResponse(podItem, container)
              end
              containersInfoMap[containerName] = containerInfoMap
            end
          end
        end
      rescue => error
        $log.warn("KubernetesContainerInventory::getContainersInfoMap : Get Container Info Maps failed: #{error}")
        $log.debug_backtrace(error.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(error)
      end
      return containersInfoMap
    end

    def obtainContainerEnvironmentVars(containerId)
      envValueString = ""
      begin
        isCGroupPidFetchRequired = false
        if !@@containerCGroupCache.has_key?(containerId)
          isCGroupPidFetchRequired = true
        else
          cGroupPid = @@containerCGroupCache[containerId]
          if cGroupPid.nil? || cGroupPid.empty?
            isCGroupPidFetchRequired = true
            @@containerCGroupCache.delete(containerId)
          elsif !File.exist?("/hostfs/proc/#{cGroupPid}/environ")
            isCGroupPidFetchRequired = true
            @@containerCGroupCache.delete(containerId)
          end
        end

        if isCGroupPidFetchRequired
          Dir["/hostfs/proc/*/cgroup"].each do |filename|
            begin
              if File.file?(filename) && File.exist?(filename) && File.foreach(filename).grep(/#{containerId}/).any?
                # file full path is /hostfs/proc/<cGroupPid>/cgroup
                cGroupPid = filename.split("/")[3]
                if is_number?(cGroupPid)
                  if @@containerCGroupCache.has_key?(containerId)
                    tempCGroupPid = @@containerCGroupCache[containerId]
                    if tempCGroupPid.to_i > cGroupPid.to_i
                      @@containerCGroupCache[containerId] = cGroupPid
                    end
                  else
                    @@containerCGroupCache[containerId] = cGroupPid
                  end
                end
              end
            rescue SystemCallError # ignore Error::ENOENT,Errno::ESRCH which is expected if any of the container gone while we read
            end
          end
        end
        cGroupPid = @@containerCGroupCache[containerId]
        if !cGroupPid.nil? && !cGroupPid.empty?
          environFilePath = "/hostfs/proc/#{cGroupPid}/environ"
          if File.exist?(environFilePath)
            # Skip environment variable processing if it contains the flag AZMON_COLLECT_ENV=FALSE
            # Check to see if the environment variable collection is disabled for this container.
            if File.foreach(environFilePath).grep(/AZMON_COLLECT_ENV=FALSE/i).any?
              envValueString = ["AZMON_COLLECT_ENV=FALSE"]
              $log.warn("Environment Variable collection for container: #{containerId} skipped because AZMON_COLLECT_ENV is set to false")
            else
              # Restricting the ENV string value to 200kb since the size of this string can go very high
              envVars = File.read(environFilePath, 200000)
              if !envVars.nil? && !envVars.empty?
                envVars = envVars.split("\0")
                envValueString = envVars.to_json
                envValueStringLength = envValueString.length
                if envValueStringLength >= 200000
                  lastIndex = envValueString.rindex("\",")
                  if !lastIndex.nil?
                    envValueStringTruncated = envValueString.slice(0..lastIndex) + "]"
                    envValueString = envValueStringTruncated
                  end
                end
              end
            end
          end
        else
          $log.warn("KubernetesContainerInventory::obtainContainerEnvironmentVars: cGroupPid is NIL or empty for containerId: #{containerId}")
        end
      rescue => error
        $log.warn("KubernetesContainerInventory::obtainContainerEnvironmentVars: obtain Container Environment vars failed: #{error} for containerId: #{containerId}")
        $log.debug_backtrace(error.backtrace)
      end
      return envValueString
    end

    def obtainContainerEnvironmentVarsFromPodsResponse(pod, container)
      envValueString = ""
      begin
        envVars = []
        envVarsJSON = container["env"]
        if !pod.nil? && !pod.empty? && !envVarsJSON.nil? && !envVarsJSON.empty?
          envVarsJSON.each do |envVar|
            key = envVar["name"]
            value = ""
            if !envVar["value"].nil?
              value = envVar["value"]
            elsif !envVar["valueFrom"].nil?
              valueFrom = envVar["valueFrom"]
              # https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/#use-pod-fields-as-values-for-environment-variables
              if valueFrom.key?("fieldRef") && !valueFrom["fieldRef"]["fieldPath"].nil? && !valueFrom["fieldRef"]["fieldPath"].empty?
                fieldPath = valueFrom["fieldRef"]["fieldPath"]
                fields = fieldPath.split(".")
                if fields.length() == 2
                  if !fields[1].nil? && !fields[1].empty? && fields[1].end_with?("]")
                    indexFields = fields[1].split("[")
                    hashMapValue = pod[fields[0]][indexFields[0]]
                    if !hashMapValue.nil? && !hashMapValue.empty?
                      subField = indexFields[1].chomp("]").delete("\\'")
                      value = hashMapValue[subField]
                    end
                  else
                    value = pod[fields[0]][fields[1]]
                  end
                end
                # https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/#use-container-fields-as-values-for-environment-variables
              elsif valueFrom.key?("resourceFieldRef") && !valueFrom["resourceFieldRef"]["resource"].nil? && !valueFrom["resourceFieldRef"]["resource"].empty?
                resource = valueFrom["resourceFieldRef"]["resource"]
                resourceFields = resource.split(".")
                containerResources = container["resources"]
                if !containerResources.nil? && !containerResources.empty? && resourceFields.length() == 2
                   if containerResources.key?(resourceFields[0]) && containerResources[resourceFields[0]].key?(resourceFields[1])
                     value = containerResources[resourceFields[0]][resourceFields[1]]
                   end
                end
                # https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-environment-variables
              elsif valueFrom.key?("secretKeyRef")
                secretName = valueFrom["secretKeyRef"]["name"]
                secretKey = valueFrom["secretKeyRef"]["key"]
                # This is still secret not the plaintext. Flatten value so that CI Ux can show that
                if !secretName.nil? && !secretName.empty? && !secretKey.nil? && !secretKey.empty?
                  value = "secretKeyRef_#{secretName}_#{secretKey}"
                end
              else
                value = envVar["valueFrom"].to_s
              end
            end
            envVars.push("#{key}=#{value}")
          end
          envValueString = envVars.to_json
          containerName = container["name"]
          # Skip environment variable processing if it contains the flag AZMON_COLLECT_ENV=FALSE
          # Check to see if the environment variable collection is disabled for this container.
          if /AZMON_COLLECT_ENV=FALSE/i.match(envValueString)
            envValueString = ["AZMON_COLLECT_ENV=FALSE"]
            $log.warn("Environment Variable collection for container: #{containerName} skipped because AZMON_COLLECT_ENV is set to false")
          else
            # Restricting the ENV string value to 200kb since the size of this string can go very high
            if envValueString.length > 200000
              envValueStringTruncated = envValueString.slice(0..200000)
              lastIndex = envValueStringTruncated.rindex("\",")
              if !lastIndex.nil?
                envValueString = envValueStringTruncated.slice(0..lastIndex) + "]"
              else
                envValueString = envValueStringTruncated
              end
            end
          end
        end
      rescue => error
        $log.warn("KubernetesContainerInventory::obtainContainerEnvironmentVarsFromPodsResponse: parsing of EnvVars failed: #{error}")
        $log.debug_backtrace(error.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(error)
      end
      return envValueString
    end

    def deleteCGroupCacheEntryForDeletedContainer(containerId)
      begin
        if !containerId.nil? && !containerId.empty? && !@@containerCGroupCache.nil? && @@containerCGroupCache.length > 0 && @@containerCGroupCache.key?(containerId)
          @@containerCGroupCache.delete(containerId)
        end
      rescue => error
        $log.warn("KubernetesContainerInventory::deleteCGroupCacheEntryForDeletedContainer: deleting of cache entry failed: #{error}")
        $log.debug_backtrace(error.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(error)
      end
    end

    def is_number?(value)
      true if Integer(value) rescue false
    end

    # https://learn.microsoft.com/en-us/azure/aks/use-pod-sandboxing
    def isSandboxingPod(podItem)
      isKataRuntimePod = false
      begin
        if !podItem.nil? && !podItem.empty? &&
           podItem.key?("spec") && !podItem["spec"].nil? && !podItem["spec"].empty? &&
           !podItem["spec"]["runtimeClassName"].nil? && !podItem["spec"]["runtimeClassName"].empty? &&
           podItem["spec"]["runtimeClassName"].eql?("kata-mshv-vm-isolation")
          isKataRuntimePod = true
        end
      rescue => error
        $log.warn("KubernetesContainerInventory::isSandboxingPod: failed with an error: #{error}")
      end
      return isKataRuntimePod
    end
  end
end
