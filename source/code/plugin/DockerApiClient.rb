#!/usr/local/bin/ruby
# frozen_string_literal: true

class DockerApiClient

    require 'socket'
    require 'json'
    require_relative 'oms_common'
    require_relative 'DockerApiRestHelper'

    @@SocketPath = "/var/run/docker.sock"
    @@ChunkSize = 4096

    def initialize
    end

    # Make docker socket call to 
    def getResponse(request, isMultiJson)
        #TODO: Add error handling and retries
        socket = UnixSocket.New(@@SocketPath)
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
        begin
            jsonResponse = isMultiJson ? dockerResponse[/\[{.+}\]/] : dockerResponse[/{.+}/]
        rescue => exception
            @Log.warn("Regex match for docker response failed: #{exception} , isMultiJson: #{isMultiJson} @ #{Time.now.utc.iso8601}")
        end
        begin
            parsedJsonResponse = JSON.parse(jsonResponse)
        rescue => exception
            @Log.warn("Json parsing for docker response failed: #{exception} , isMultiJson: #{isMultiJson} @ #{Time.now.utc.iso8601}")
        end 
        return parsedJsonResponse
    end 


    def getDockerHostName()
        dockerHostName = ""
        request = DockerApiRestHelper.restDockerInfo()
        response = getResponse(request, false)
        if (response != nil)
            dockerHostName = reponse['Name']
        end
        return dockerHostName
    end

end

        