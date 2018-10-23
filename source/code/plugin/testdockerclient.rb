require_relative 'DockerApiClient'

myhost = DockerApiClient.getDockerHostName
puts myhost

puts DockerApiClient.listContainers