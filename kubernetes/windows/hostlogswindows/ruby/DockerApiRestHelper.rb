#!/usr/local/bin/ruby
# frozen_string_literal: true

class DockerApiRestHelper
  def initialize
  end

  class << self
    # Create the REST request to list images
    # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#list-images
    # returns Request in string format
    def restDockerImages()
      begin
        return "GET /images/json?all=0 HTTP/1.1\r\nHost: localhost\r\n\r\n"
      end
    end

    # Create the REST request to list containers
    # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#list-containers
    # returns Request in string format
    def restDockerPs()
      begin
        return "GET /containers/json?all=1 HTTP/1.1\r\nHost: localhost\r\n\r\n"
      end
    end

    # Create the REST request to inspect a container
    # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#inspect-a-container
    # parameter - ID of the container to be inspected
    # returns Request in string format
    def restDockerInspect(id)
      begin
        return "GET /containers/" + id + "/json HTTP/1.1\r\nHost: localhost\r\n\r\n"
      end
    end

    # Create the REST request to get docker info
    # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#get-container-stats-based-on-resource-usage
    # returns Request in string format
    def restDockerInfo()
      begin
        return "GET /info HTTP/1.1\r\nHost: localhost\r\n\r\n"
      end
    end

    # Create the REST request to get docker info
    # https://docs.docker.com/engine/api/v1.21/#21-containers
    # returns Request in string format
    def restDockerVersion()
      begin
        return "GET /version HTTP/1.1\r\nHost: localhost\r\n\r\n"
      end
    end
  end
end
