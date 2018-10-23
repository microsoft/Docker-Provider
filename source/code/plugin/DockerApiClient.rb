#!/usr/local/bin/ruby
# frozen_string_literal: true

class DockerApiClient

    require 'socket'
    require 'json'
    require_relative 'oms_common'
    require_relative 'omslog'
    require_relative 'DockerApiRestHelper'

    @@SocketPath = "/var/run/docker.sock"
    @@ChunkSize = 4096

    def initialize
    end

    class << self
        # Make docker socket call to 
        def getResponse(request, isMultiJson)
            #TODO: Add error handling and retries
            socket = UNIXSocket.new(@@SocketPath)
            dockerResponse = ""
            socket.write(request)
            # iterate through the response until the last chunk is less than the chunk size so that we can read all data in socket.
            loop do
                responseChunk = socket.recv(@@ChunkSize)
                dockerResponse += responseChunk
                break if responseChunk.length < @@ChunkSize
            end
            socket.close
            return parseResponse(dockerResponse, isMultiJson)
        end

        def parseResponse(dockerResponse, isMultiJson)
            # Doing this because the response is in the raw format and includes headers.
            # Need to do a regex match to extract the json part of the response - Anything between [{}] in response
            parsedJsonResponse = nil
            begin
                jsonResponse = isMultiJson ? dockerResponse[/\[{.+}\]/] : dockerResponse[/{.+}/]
            rescue => exception
                @Log.warn("Regex match for docker response failed: #{exception} , isMultiJson: #{isMultiJson} @ #{Time.now.utc.iso8601}")
            end
            begin
                if jsonResponse != nil
                    parsedJsonResponse = JSON.parse(jsonResponse)
                end
            rescue => exception
                @Log.warn("Json parsing for docker response failed: #{exception} , isMultiJson: #{isMultiJson} @ #{Time.now.utc.iso8601}")
            end 
            return parsedJsonResponse
        end 


        def getDockerHostName()
            dockerHostName = ""
            request = DockerApiRestHelper.restDockerInfo
            response = getResponse(request, false)
            if (response != nil)
                dockerHostName = response['Name']
            end
            return dockerHostName
        end

        def listContainers()
            ids = []
            request = DockerApiRestHelper.restDockerPs
            containers = getResponse(request, true)
            if !containers.nil? && !containers.empty?
                containers.each do |container|
                    ids.push(container['Id'])
                end
            end
            return ids
        end

        def getImageRepositoryImageTag(tagValue)
            result = ["" "", ""]
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
            return result
        end

        def generateImageNameMap()
            result = nil
            request = DockerApiRestHelper.restDockerImages
            images = getResponse(request, true)
            if !images.nil? && !images.empty?
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
            return result
        end
    end
end

        