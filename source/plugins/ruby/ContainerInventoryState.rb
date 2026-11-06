#!/usr/local/bin/ruby
# frozen_string_literal: true

class ContainerInventoryState
    require 'json'
    require_relative 'omslog'
    @@InventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"

    def initialize
    end

    class << self
       def validContainerId?(containerId)
            containerId.is_a?(String) &&
                containerId.bytesize.between?(1, 255) &&
                containerId.match?(/\A[a-zA-Z0-9_.+-]+\z/) &&
                !containerId.end_with?(".") &&
                !containerId.match?(/\A(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|\z)/i)
       end

       # Write the container information to disk with the data that is obtained from the current plugin execution
       def writeContainerState(container)
            containerId = container['InstanceID']
            return if containerId.nil? || containerId == ""
            if validContainerId?(containerId)
                begin
                    containerJson = container.to_json
                    # A validated single filename and NOFOLLOW keep writes inside the state directory.
                    File.open(File.join(@@InventoryDirectory, containerId), File::WRONLY | File::CREAT | File::TRUNC | File::NOFOLLOW) do |file|
                        file.write(containerJson)
                    end
                rescue => errorStr
                    $log.warn("Exception in writeContainerState: #{errorStr}")
                end
            else
                $log.warn("Invalid container ID in writeContainerState; skipping state write")
            end
       end

       # Reads the container state for the deleted container
       def readContainerState(containerId)
            unless validContainerId?(containerId)
                $log.warn("Invalid container ID in readContainerState; skipping state read")
                return nil
            end
            begin
                containerObject = nil
                filepath = File.join(@@InventoryDirectory, containerId)
                File.open(filepath, File::RDONLY | File::NOFOLLOW) do |file|
                    fileContents = file.read
                    containerObject = JSON.parse(fileContents)
                end
                # Delete the file since the state is update to deleted
                File.delete(filepath)
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
                previousContainerList = Dir.entries(@@InventoryDirectory).select do |containerId|
                    filepath = File.join(@@InventoryDirectory, containerId)
                    validContainerId?(containerId) && !File.symlink?(filepath) && File.file?(filepath)
                end
                deletedContainers = previousContainerList - containerIds
            rescue => errorStr
                $log.warn("Exception in getDeletedContainers: #{errorStr}")
            end
            return deletedContainers
       end
    end
end