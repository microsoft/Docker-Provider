#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent

  class Container_Inventory_Input < Input
    Plugin.register_input('containerinventory', self)

    def initialize
      super
      require 'json'
      require_relative 'DockerApiClient'
      require_relative 'omslog'
    end

    config_param :run_interval, :time, :default => '1m'
    config_param :tag, :string, :default => "oms.containerinsights.ContainerInventory"
  
    def configure (conf)
      super
    end

    def start
      if @run_interval
        @finished = false
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
      end
    end

    def obtainContainerConfig(instance, container)
      begin
        configValue = container['Config']
        if !configValue.nil?
          instance['ContainerHostname'] = configValue['Hostname']

          envValue = configValue['Env']
          envValueString = (envValue.nil?) ? "" : envValue.to_s
          instance['EnvironmentVar'] = envValueString

          cmdValue = configValue['Cmd']
          cmdValueString = (cmdValue.nil?) ? "" : cmdValue.to_s
          instance['Command'] = cmdValueString

          instance['ComposeGroup'] = ""
          labelsValue = configValue['Labels']
          if !labelsValue.nil? && !labelsValue.empty?
            instance['ComposeGroup'] = labelsValue['com.docker.compose.project']
          end
        else
          $log.warn("Attempt in ObtainContainerConfig to get container #{container['Id']} config information returned null")
        end
        rescue => errorStr
          $log.warn("Exception in obtainContainerConfig: #{errorStr}")
        end
    end

    def obtainContainerState(instance, container)
      begin
        stateValue = container['State']
        if !stateValue.nil?
          exitCodeValue  = stateValue['ExitCode']
          # Exit codes less than 0 are not supported by the engine
          if exitCodeValue < 0
            exitCodeValue =  128
            $log.info("obtainContainerState::Container #{container['Id']} returned negative exit code")
          end
          instance['ExitCode'] = exitCodeValue
          if exitCodeValue > 0
            instance['State'] = "Failed"
          else
            # Set the Container status : Running/Paused/Stopped
            runningValue = stateValue['Running']
            if runningValue
              pausedValue = stateValue['Paused']
              # Checking for paused within running is true state because docker returns true for both Running and Paused fields when the container is paused
              if pausedValue
                instance['State'] = "Paused"
              else
                instance['State'] = "Running"
              end
            else
              instance['State'] = "Stopped"
            end
          end
          instance['StartedTime'] = stateValue['StartedAt']
          instance['FinishedTime'] = stateValue['FinishedAt']
        else
          $log.info("Attempt in ObtainContainerState to get container: #{container['Id']} state information returned null")
        end
        rescue => errorStr
          $log.warn("Exception in obtainContainerState: #{errorStr}")
      end
    end

    def obtainContainerHostConfig(instance, container)
      begin
        hostConfig = container['HostConfig']
        if !hostConfig.nil?
          links = hostConfig['Links']
          instance['Links'] = ""
          if !links.nil?
            linksString = links.to_s
            instance['Links'] = (linksString == "null")? "" : linksString
          end
          portBindings = hostConfig['PortBindings']
          instance['Ports'] = ""
          if !portBindings.nil?
            portBindingsString = portBindings.to_s
            instance['Ports'] = (portBindingsString == "null")? "" : portBindingsString
          end
        else
          $log.info("Attempt in ObtainContainerHostConfig to get container: #{container['Id']} host config information returned null")
        end
        rescue => errorStr
          $log.warn("Exception in obtainContainerHostConfig: #{errorStr}")
        end
    end

    def inspectContainer(id, nameMap)
      containerInstance = {}
      begin
        container = DockerApiClient.dockerInspectContainer(id)
        if !container.nil? && !container.empty?
          containerInstance['InstanceID'] = "rashmi" + container['Id']
          containerInstance['CreatedTime'] = container['Created']
          containerName = container['Name']
          if !containerName.nil? && !containerName.empty?
            # Remove the leading / from the name if it exists (this is an API issue)
            containerInstance['ElementName'] = (containerName[0] == '/') ? containerName[1..-1] : containerName
          end
          imageValue = container['Image']
          if !imageValue.nil? && !imageValue.empty?
            containerInstance['ImageId'] = imageValue
            repoImageTagArray = nameMap[imageValue]
            if nameMap.has_key? imageValue
              containerInstance['Repository'] = repoImageTagArray[0]
              containerInstance['Image'] = repoImageTagArray[1]
              containerInstance['ImageTag'] = repoImageTagArray[2]
            end
          end
          obtainContainerConfig(containerInstance, container);
          obtainContainerState(containerInstance, container);
          obtainContainerHostConfig(containerInstance, container);
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
      $log.info("Done getting host name @ #{Time.now.utc.iso8601}")
      begin
        containerIds = DockerApiClient.listContainers
        $log.info("Done getting containers @ #{Time.now.utc.iso8601}")
        if !containerIds.empty?
          $log.info("in container ids not empty @ #{Time.now.utc.iso8601}")
          eventStream = MultiEventStream.new
          $log.info("Done creating eventstream @ #{Time.now.utc.iso8601}")
          nameMap = DockerApiClient.getImageIdMap
          $log.info("Done getting namemap @ #{Time.now.utc.iso8601}")
          containerIds.each do |containerId|
            inspectedContainer = {}
            inspectedContainer = inspectContainer(containerId, nameMap)
            inspectedContainer['Computer'] = hostname
            containerInventory.push inspectedContainer
          end
          #TODO: Get deleted container state and update it
          containerInventory.each do |record|
            wrapper = {
              "DataType"=>"CONTAINER_INVENTORY_BLOB",
              "IPName"=>"ContainerInsights",
              "DataItems"=>[record.each{|k,v| record[k]=v}]
            }
            eventStream.add(emitTime, wrapper) if wrapper
          end
          router.emit_stream(@tag, eventStream) if eventStream
        end
      rescue => errorStr
        $log.warn("Exception in enumerate container inventory: #{errorStr}")
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