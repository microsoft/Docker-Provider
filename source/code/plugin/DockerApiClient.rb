#!/usr/local/bin/ruby
# frozen_string_literal: true

class DockerApiClient

    require 'socket'
    require 'json'
    require 'timeout'
    require_relative 'omslog'
    require_relative 'DockerApiRestHelper'
    require_relative 'ApplicationInsightsUtility'

    @@SocketPath = "/var/run/host/docker.sock"
    @@ChunkSize = 4096
    @@TimeoutInSeconds = 5
    @@PluginName = 'ContainerInventory'
    def initialize
    end

    class << self
        # Make docker socket call for requests
        def getResponse(request, isMultiJson, isVersion)
            begin
                socket = UNIXSocket.new(@@SocketPath)
                dockerResponse = ""
                isTimeOut = false
                socket.write(request)
                # iterate through the response until the last chunk is less than the chunk size so that we can read all data in socket.
                loop do
                    begin
                        responseChunk = ""
                        timeout(@@TimeoutInSeconds) do
                            responseChunk = socket.recv(@@ChunkSize)
                        end
                        dockerResponse += responseChunk
                    rescue Timeout::Error
                        $log.warn("Socket read timedout for request: #{request} @ #{Time.now.utc.iso8601}")
                        isTimeOut = true
                        break
                    end
                    break if (isVersion)? (responseChunk.length < @@ChunkSize) : (responseChunk.end_with? "0\r\n\r\n")
                end
                socket.close
                return (isTimeOut)? nil : parseResponse(dockerResponse, isMultiJson)
            rescue => errorStr
                $log.warn("Socket call failed for request: #{request} error: #{errorStr} , isMultiJson: #{isMultiJson} @ #{Time.now.utc.iso8601}")
                ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
            end
        end

        def parseResponse(dockerResponse, isMultiJson)
            # Doing this because the response is in the raw format and includes headers.
            # Need to do a regex match to extract the json part of the response - Anything between [{}] in response
            parsedJsonResponse = nil
            begin
                jsonResponse = isMultiJson ? dockerResponse[/\[{.+}\]/] : dockerResponse[/{.+}/]
            rescue => errorStr
                $log.warn("Regex match for docker response failed: #{errorStr} , isMultiJson: #{isMultiJson} @ #{Time.now.utc.iso8601}")
            end
            begin
                if jsonResponse != nil
                    parsedJsonResponse = JSON.parse(jsonResponse)
                end
            rescue => errorStr
                $log.warn("Json parsing for docker response failed: #{errorStr} , isMultiJson: #{isMultiJson} @ #{Time.now.utc.iso8601}")
                ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
            end 
            return parsedJsonResponse
        end 


        def getDockerHostName()
            dockerHostName = ""
            request = DockerApiRestHelper.restDockerInfo
            response = getResponse(request, false, false)
            if (response != nil)
                dockerHostName = response['Name']
            end
            return dockerHostName
        end

        def listContainers()
            ids = []
            request = DockerApiRestHelper.restDockerPs
            containers = getResponse(request, true, false)
            if !containers.nil? && !containers.empty?
                containers.each do |container|
                    ids.push(container['Id'])
                end
            end
            return ids
        end

        # This method splits the tag value into an array - repository, image and tag
        def getImageRepositoryImageTag(tagValue)
            result = ["", "", ""]
            begin
                if !tagValue.empty?
                    # Find delimiters in the string of format repository/image:imagetag
                    slashLocation = tagValue.index('/')
                    colonLocation = tagValue.index(':')
                    if !colonLocation.nil?
                        if slashLocation.nil?
                            # image:imagetag
                            result[1] = tagValue[0..(colonLocation-1)]
                        else
                            # repository/image:imagetag
                            result[0] = tagValue[0..(slashLocation-1)]
                            result[1] = tagValue[(slashLocation + 1)..(colonLocation - 1)]
                        end
                        result[2] = tagValue[(colonLocation + 1)..-1]
                    end
                end
            rescue => errorStr
                $log.warn("Exception at getImageRepositoryImageTag: #{errorStr} @ #{Time.now.utc.iso8601}")
            end
            return result
        end

        # Image is in the format repository/image:imagetag - This method creates a hash of image id and repository, image and tag
        def getImageIdMap()
            result = nil
            begin
                request = DockerApiRestHelper.restDockerImages
                images = getResponse(request, true, false)
                if !images.nil? && !images.empty?
                    result = {}
                    images.each do |image|
                        tagValue = ""
                        tags = image['RepoTags']
                        if !tags.nil? && tags.kind_of?(Array) && tags.length > 0
                            tagValue = tags[0]
                        end
                        idValue = image['Id']
                        if !idValue.nil?
                            result[idValue] = getImageRepositoryImageTag(tagValue)
                        end
                    end
                end
            rescue => errorStr
                $log.warn("Exception at getImageIdMap: #{errorStr} @ #{Time.now.utc.iso8601}")
            end
            return result
        end

        def dockerInspectContainer(id)
            request = DockerApiRestHelper.restDockerInspect(id)
            return getResponse(request, false, false)
        end

        # This method returns docker version and docker api version for telemetry
        def dockerInfo()
            request = DockerApiRestHelper.restDockerVersion
            response = getResponse(request, false, true)
            dockerInfo = {}
            if (response != nil)
                dockerInfo['Version'] = response['Version']
                dockerInfo['ApiVersion'] = response['ApiVersion']
            end
            return dockerInfo
        end
    end
end
