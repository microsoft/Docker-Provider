#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent
  class Container_Inventory_Input < Input
    Plugin.register_input("containerinventory", self)

    @@PluginName = "ContainerInventory"
    @@RunningState = "Running"
    @@FailedState = "Failed"
    @@StoppedState = "Stopped"
    @@PausedState = "Paused"

    def initialize
      super
      require "json"
      require_relative "DockerApiClient"
      require_relative "ContainerInventoryState"
      require_relative "ApplicationInsightsUtility"
      require_relative "omslog"
    end

    config_param :run_interval, :time, :default => "1m"
    config_param :tag, :string, :default => "oms.containerinsights.containerinventory"

    def configure(conf)
      super
    end

    def start
      if @run_interval
        @finished = false
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
        @@telemetryTimeTracker = DateTime.now.to_time.to_i
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

    def obtainContainerConfig(instance, container, clusterCollectEnvironmentVar)
      begin
        configValue = container["Config"]
        if !configValue.nil?
          instance["ContainerHostname"] = configValue["Hostname"]
          # Check to see if the environment variable collection is disabled at the cluster level - This disables env variable collection for all containers.
          if !clusterCollectEnvironmentVar.nil? && !clusterCollectEnvironmentVar.empty? && clusterCollectEnvironmentVar.casecmp("false") == 0
            instance["EnvironmentVar"] = ["AZMON_CLUSTER_COLLECT_ENV_VAR=FALSE"]
          else
            envValue = configValue["Env"]
            envValueString = (envValue.nil?) ? "" : envValue.to_s
            # Skip environment variable processing if it contains the flag AZMON_COLLECT_ENV=FALSE
            # Check to see if the environment variable collection is disabled for this container.
            if /AZMON_COLLECT_ENV=FALSE/i.match(envValueString)
              envValueString = ["AZMON_COLLECT_ENV=FALSE"]
              $log.warn("Environment Variable collection for container: #{container["Id"]} skipped because AZMON_COLLECT_ENV is set to false")
            end
            # Restricting the ENV string value to 200kb since the size of this string can go very high
            if envValueString.length > 200000
              envValueStringTruncated = envValueString.slice(0..200000)
              lastIndex = envValueStringTruncated.rindex("\", ")
              if !lastIndex.nil?
                envValueStringTruncated = envValueStringTruncated.slice(0..lastIndex) + "]"
              end
              instance["EnvironmentVar"] = envValueStringTruncated
            else
              instance["EnvironmentVar"] = envValueString
            end
          end

          cmdValue = configValue["Cmd"]
          cmdValueString = (cmdValue.nil?) ? "" : cmdValue.to_s
          instance["Command"] = cmdValueString

          instance["ComposeGroup"] = ""
          labelsValue = configValue["Labels"]
          if !labelsValue.nil? && !labelsValue.empty?
            instance["ComposeGroup"] = labelsValue["com.docker.compose.project"]
          end
        else
          $log.warn("Attempt in ObtainContainerConfig to get container: #{container["Id"]} config information returned null")
        end
      rescue => errorStr
        $log.warn("Exception in obtainContainerConfig: #{errorStr}")
      end
    end

    def obtainContainerState(instance, container)
      begin
        stateValue = container["State"]
        if !stateValue.nil?
          exitCodeValue = stateValue["ExitCode"]
          # Exit codes less than 0 are not supported by the engine
          if exitCodeValue < 0
            exitCodeValue = 128
            $log.info("obtainContainerState::Container: #{container["Id"]} returned negative exit code")
          end
          instance["ExitCode"] = exitCodeValue
          if exitCodeValue > 0
            instance["State"] = @@FailedState
          else
            # Set the Container status : Running/Paused/Stopped
            runningValue = stateValue["Running"]
            if runningValue
              pausedValue = stateValue["Paused"]
              # Checking for paused within running is true state because docker returns true for both Running and Paused fields when the container is paused
              if pausedValue
                instance["State"] = @@PausedState
              else
                instance["State"] = @@RunningState
              end
            else
              instance["State"] = @@StoppedState
            end
          end
          instance["StartedTime"] = stateValue["StartedAt"]
          instance["FinishedTime"] = stateValue["FinishedAt"]
        else
          $log.info("Attempt in ObtainContainerState to get container: #{container["Id"]} state information returned null")
        end
      rescue => errorStr
        $log.warn("Exception in obtainContainerState: #{errorStr}")
      end
    end

    def obtainContainerHostConfig(instance, container)
      begin
        hostConfig = container["HostConfig"]
        if !hostConfig.nil?
          links = hostConfig["Links"]
          instance["Links"] = ""
          if !links.nil?
            linksString = links.to_s
            instance["Links"] = (linksString == "null") ? "" : linksString
          end
          portBindings = hostConfig["PortBindings"]
          instance["Ports"] = ""
          if !portBindings.nil?
            portBindingsString = portBindings.to_s
            instance["Ports"] = (portBindingsString == "null") ? "" : portBindingsString
          end
        else
          $log.info("Attempt in ObtainContainerHostConfig to get container: #{container["Id"]} host config information returned null")
        end
      rescue => errorStr
        $log.warn("Exception in obtainContainerHostConfig: #{errorStr}")
      end
    end

    def inspectContainer(id, nameMap, clusterCollectEnvironmentVar)
      containerInstance = {}
      begin
        container = DockerApiClient.dockerInspectContainer(id)
        if !container.nil? && !container.empty?
          containerInstance["InstanceID"] = container["Id"]
          containerInstance["CreatedTime"] = container["Created"]
          containerName = container["Name"]
          if !containerName.nil? && !containerName.empty?
            # Remove the leading / from the name if it exists (this is an API issue)
            containerInstance["ElementName"] = (containerName[0] == "/") ? containerName[1..-1] : containerName
          end
          imageValue = container["Image"]
          if !imageValue.nil? && !imageValue.empty?
            repoImageTagArray = nameMap[imageValue]
            if nameMap.has_key? imageValue
              containerInstance["Repository"] = repoImageTagArray[0]
              containerInstance["Image"] = repoImageTagArray[1]
              containerInstance["ImageTag"] = repoImageTagArray[2]
              # Setting the image id to the id in the remote repository
              containerInstance["ImageId"] = repoImageTagArray[3]
            end
          end
          obtainContainerConfig(containerInstance, container, clusterCollectEnvironmentVar)
          obtainContainerState(containerInstance, container)
          obtainContainerHostConfig(containerInstance, container)
        end
      rescue => errorStr
        $log.warn("Exception in inspectContainer: #{errorStr} for container: #{id}")
      end
      return containerInstance
    end

    def enumerate
      currentTime = Time.now
      emitTime = currentTime.to_f
      batchTime = currentTime.utc.iso8601
      containerInventory = Array.new
      $log.info("in_container_inventory::enumerate : Begin processing @ #{Time.now.utc.iso8601}")
      hostname = DockerApiClient.getDockerHostName
      begin
        containerIds = DockerApiClient.listContainers
        if !containerIds.nil? && !containerIds.empty?
          eventStream = MultiEventStream.new
          nameMap = DockerApiClient.getImageIdMap
          clusterCollectEnvironmentVar = ENV["AZMON_CLUSTER_COLLECT_ENV_VAR"]
          if !clusterCollectEnvironmentVar.nil? && !clusterCollectEnvironmentVar.empty? && clusterCollectEnvironmentVar.casecmp("false") == 0
            $log.warn("Environment Variable collection disabled for cluster")
          end
          containerIds.each do |containerId|
            inspectedContainer = {}
            inspectedContainer = inspectContainer(containerId, nameMap, clusterCollectEnvironmentVar)
            inspectedContainer["Computer"] = hostname
            inspectedContainer["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
            containerInventory.push inspectedContainer
            ContainerInventoryState.writeContainerState(inspectedContainer)
          end
          # Update the state for deleted containers
          deletedContainers = ContainerInventoryState.getDeletedContainers(containerIds)
          if !deletedContainers.nil? && !deletedContainers.empty?
            deletedContainers.each do |deletedContainer|
              container = ContainerInventoryState.readContainerState(deletedContainer)
              if !container.nil?
                container.each { |k, v| container[k] = v }
                container["State"] = "Deleted"
                containerInventory.push container
              end
            end
          end

          containerInventory.each do |record|
            wrapper = {
              "DataType" => "CONTAINER_INVENTORY_BLOB",
              "IPName" => "ContainerInsights",
              "DataItems" => [record.each { |k, v| record[k] = v }],
            }
            eventStream.add(emitTime, wrapper) if wrapper
          end
          router.emit_stream(@tag, eventStream) if eventStream
          @@istestvar = ENV["ISTEST"]
          if (!@@istestvar.nil? && !@@istestvar.empty? && @@istestvar.casecmp("true") == 0 && eventStream.count > 0)
            $log.info("containerInventoryEmitStreamSuccess @ #{Time.now.utc.iso8601}")
          end
          $log.info("in_container_inventory::enumerate : Processing complete - emitted stream @ #{Time.now.utc.iso8601}")
        end
        timeDifference = (DateTime.now.to_time.to_i - @@telemetryTimeTracker).abs
        timeDifferenceInMinutes = timeDifference / 60
        if (timeDifferenceInMinutes >= 5)
          @@telemetryTimeTracker = DateTime.now.to_time.to_i
          telemetryProperties = {}
          telemetryProperties["Computer"] = hostname
          telemetryProperties["ContainerCount"] = containerInventory.length
          ApplicationInsightsUtility.sendTelemetry(@@PluginName, telemetryProperties)
        end
      rescue => errorStr
        $log.warn("Exception in enumerate container inventory: #{errorStr}")
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
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
            $log.info("in_container_inventory::run_periodic @ #{Time.now.utc.iso8601}")
            enumerate
          rescue => errorStr
            $log.warn "in_container_inventory::run_periodic: Failed in enumerate container inventory: #{errorStr}"
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end
  end # Container_Inventory_Input
end # module
