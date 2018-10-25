#!/usr/local/bin/ruby
# frozen_string_literal: true

class ContainerInventoryState
    require_relative 'oms_common'
    require_relative 'omslog'
    @@InventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"

    def initialize
    end

    class << self
       def WriteContainerState(container)
            containerId = container['InstanceID']
            if !containerId.nil? && !containerId.empty?
                begin
                    file = File.open(@@InventoryDirectory + containerId, "w")
                    if !file.nil?
                        file.write(container.to_json)
                        file.close
                    else
                        $log.warn("Exception top open file with id: #{containerId}")
                    end
                rescue => errorStr
                    $log.warn("Exception in WriteContainerState: #{errorStr}")
                end
            end
       end

       def ReadContainerState(containerId)

       end
    end
end

        