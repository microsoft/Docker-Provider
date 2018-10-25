#!/usr/local/bin/ruby
# frozen_string_literal: true

class ContainerInventoryState
    require 'json'
    require_relative 'oms_common'
    require_relative 'omslog'
    @@InventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"

    def initialize
    end

    class << self
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
                    $log.warn("Exception in WriteContainerState: #{errorStr}")
                end
            end
       end

       def readContainerState(containerId)
            begin
                containerObject = nil
                file = File.open(@@InventoryDirectory + containerId, "r")
                if !file.nil?
                    fileContents = file.read
                    containerObject = JSON.parse(fileContents)
                    file.close
                else
                    $log.warn("Exception while opening file with id: #{containerId}")
                end
            rescue => errorStr
                $log.warn("Exception in ReadContainerState: #{errorStr}")
            end
            return containerObject
       end

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