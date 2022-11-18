#!/usr/local/bin/ruby
# frozen_string_literal: true

class ContainerInventoryState
    require 'json'
    require_relative 'omslog'
    @@InventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"

    def initialize
    end

    class << self
       # Write the container information to disk with the data that is obtained from the current plugin execution
       def writeContainerState(container)
            containerId = container['InstanceID']
            if !containerId.nil? && !containerId.empty?
                begin
                    file = File.open(@@InventoryDirectory + containerId, "w")
                    if !file.nil?
                        file.write(container.to_json)
                        file.close
                    else
                        $log.warn("Exception while opening file with id: #{containerId}")
                    end
                rescue => errorStr
                    $log.warn("Exception in writeContainerState: #{errorStr}")
                end
            end
       end

       # Reads the container state for the deleted container
       def readContainerState(containerId)
            begin
                containerObject = nil
                filepath = @@InventoryDirectory + containerId
                file = File.open(filepath, "r")
                if !file.nil?
                    fileContents = file.read
                    containerObject = JSON.parse(fileContents)
                    file.close
                    # Delete the file since the state is update to deleted
                    File.delete(filepath) if File.exist?(filepath)
                else
                    $log.warn("Open file for container with id returned nil: #{containerId}")
                end
            rescue => errorStr
                $log.warn("Exception in readContainerState: #{errorStr}")
            end
            return containerObject
       end

       # Gets the containers that were written to the disk with the previous plugin invocation but do not exist in the current container list
       # Doing this because we need to update the container state to deleted. Else this will stay running forever.
       def getDeletedContainers(containerIds)
            deletedContainers = nil
            begin
                previousContainerList = Dir.entries(@@InventoryDirectory) - [".", ".."]
                deletedContainers = previousContainerList - containerIds
            rescue => errorStr
                $log.warn("Exception in getDeletedContainers: #{errorStr}")
            end
            return deletedContainers
       end
    end
end