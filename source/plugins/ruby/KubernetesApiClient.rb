#!/usr/local/bin/ruby
# frozen_string_literal: true

class KubernetesApiClient
  require "json"
  require "logger"
  require "net/http"
  require "net/https"
  require "uri"
  require "time"
  require "ipaddress"
  require "jwt"

  require_relative "oms_common"
  require_relative "constants"
  require_relative "WatchStream"
  require_relative "kubernetes_container_inventory"
  require_relative "extension_utils"

  @@ApiVersion = "v1"
  @@ApiVersionApps = "v1"
  @@ApiGroupApps = "apps"
  @@ApiGroupHPA = "autoscaling"
  @@ApiVersionHPA = "v1"
  @@CaFile = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  @@ClusterName = nil
  @@ClusterId = nil
  @@IsNodeMaster = nil
  @@IsAROV3Cluster = nil
  #@@IsValidRunningNode = nil
  #@@IsLinuxCluster = nil
  @@KubeSystemNamespace = "kube-system"

  @os_type = ENV["OS_TYPE"]
  if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
    @LogPath = Constants::WINDOWS_LOG_PATH + "kubernetes_client_log.txt"
  else
    @LogPath = Constants::LINUX_LOG_PATH + "kubernetes_client_log.txt"
  end
  @Log = Logger.new(@LogPath, 2, 10 * 1048576) #keep last 2 files, max log file size = 10M
  @@TokenFileName = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  @@TokenStr = nil
  @@TokenExpiry = DateTime.now.to_time.to_i
  @@cpuLimitsTelemetryTimeTracker = DateTime.now.to_time.to_i
  @@cpuRequestsTelemetryTimeTracker = DateTime.now.to_time.to_i
  @@memoryLimitsTelemetryTimeTracker = DateTime.now.to_time.to_i
  @@memoryRequestsTelemetryTimeTracker = DateTime.now.to_time.to_i
  @@resourceLimitsTelemetryHash = {}
  @@userAgent = nil

  def initialize
  end

  class << self
    def getKubeResourceInfo(resource, api_group: nil)
      headers = {}
      response = nil
      @Log.info "Getting Kube resource: #{resource}"
      begin
        resourceUri = getResourceUri(resource, api_group)
        if !resourceUri.nil?
          uri = URI.parse(resourceUri)
          if !File.exist?(@@CaFile)
            raise "#{@@CaFile} doesnt exist"
          else
            Net::HTTP.start(uri.host, uri.port, :use_ssl => true, :ca_file => @@CaFile, :verify_mode => OpenSSL::SSL::VERIFY_PEER, :open_timeout => 20, :read_timeout => 40) do |http|
              kubeApiRequest = Net::HTTP::Get.new(uri.request_uri)
              kubeApiRequest["Authorization"] = "Bearer " + getTokenStr
              kubeApiRequest["User-Agent"] = getUserAgent()
              @Log.info "KubernetesAPIClient::getKubeResourceInfo : Making request to #{uri.request_uri} @ #{Time.now.utc.iso8601}"
              response = http.request(kubeApiRequest)
              @Log.info "KubernetesAPIClient::getKubeResourceInfo : Got response of #{response.code} for #{uri.request_uri} @ #{Time.now.utc.iso8601}"
            end
          end
        end
      rescue => error
        @Log.warn("kubernetes api request failed: #{error} for #{resource} @ #{Time.now.utc.iso8601}")
      end
      if (!response.nil?)
        if (!response.body.nil? && response.body.empty?)
          @Log.warn("KubernetesAPIClient::getKubeResourceInfo : Got empty response from Kube API for #{resource} @ #{Time.now.utc.iso8601}")
        end
      end
      return response
    end

    def getKubeResourceInfoV2(resource, api_group: nil)
      headers = {}
      response = nil
      responseCode = nil
      @Log.info "Getting Kube resource: #{resource}"
      begin
        resourceUri = getResourceUri(resource, api_group)
        if !resourceUri.nil?
          uri = URI.parse(resourceUri)
          if !File.exist?(@@CaFile)
            raise "#{@@CaFile} doesnt exist"
          else
            Net::HTTP.start(uri.host, uri.port, :use_ssl => true, :ca_file => @@CaFile, :verify_mode => OpenSSL::SSL::VERIFY_PEER, :open_timeout => 20, :read_timeout => 40) do |http|
              kubeApiRequest = Net::HTTP::Get.new(uri.request_uri)
              kubeApiRequest["Authorization"] = "Bearer " + getTokenStr
              kubeApiRequest["User-Agent"] = getUserAgent()
              @Log.info "KubernetesAPIClient::getKubeResourceInfoV2 : Making request to #{uri.request_uri} @ #{Time.now.utc.iso8601}"
              response = http.request(kubeApiRequest)
              responseCode = response.code
              @Log.info "KubernetesAPIClient::getKubeResourceInfoV2 : Got response of #{response.code} for #{uri.request_uri} @ #{Time.now.utc.iso8601}"
            end
          end
        end
      rescue => error
        @Log.warn("kubernetes api request failed: #{error} for #{resource} @ #{Time.now.utc.iso8601}")
      end
      if (!response.nil?)
        if (!response.body.nil? && response.body.empty?)
          @Log.warn("KubernetesAPIClient::getKubeResourceInfoV2 : Got empty response from Kube API for #{resource} @ #{Time.now.utc.iso8601}")
        end
      end
      return responseCode, response
    end

    def getTokenStr
      begin
        if (@@TokenStr.nil? || (@@TokenExpiry - DateTime.now.to_time.to_i).abs <= Constants::SERVICE_ACCOUNT_TOKEN_REFRESH_INTERVAL_SECONDS) # refresh token from token file if its near expiry
          if File.exist?(@@TokenFileName) && File.readable?(@@TokenFileName)
            @@TokenStr = File.read(@@TokenFileName).strip
            begin
              token_info = JWT.decode(@@TokenStr, nil, false)
              @@TokenExpiry = token_info[0]["exp"]
            rescue JWT::DecodeError => e
              @Log.warn("The token is not a JWT.")
              @@TokenExpiry = DateTime.now.to_time.to_i + Constants::LEGACY_SERVICE_ACCOUNT_TOKEN_EXPIRY_SECONDS
            end
            # By default without explicit token mount, token expiry is one year so setting expiry to 1hour to refresh token periodically
            if (@@TokenExpiry - DateTime.now.to_time.to_i).abs > Constants::LEGACY_SERVICE_ACCOUNT_TOKEN_EXPIRY_SECONDS
              @@TokenExpiry = DateTime.now.to_time.to_i + Constants::LEGACY_SERVICE_ACCOUNT_TOKEN_EXPIRY_SECONDS
            end
          else
            @Log.warn("Unable to read token string from #{@@TokenFileName}: #{error}")
            @@TokenExpiry = DateTime.now.to_time.to_i
            @@TokenStr = nil
          end
        end
      rescue => error
        @Log.warn("getTokenStr failed: #{error}")
      end
      return @@TokenStr
    end

    def getClusterRegion(env = ENV)
      if env["AKS_REGION"]
        return env["AKS_REGION"]
      else
        @Log.warn ("Kubernetes environment variable not set AKS_REGION. Unable to get cluster region.")
        return nil
      end
    end

    def getResourceUri(resource, api_group, env = ENV)
      begin
        if env["KUBERNETES_SERVICE_HOST"] && env["KUBERNETES_PORT_443_TCP_PORT"]
          if api_group.nil?
            return "https://#{env["KUBERNETES_SERVICE_HOST"]}:#{env["KUBERNETES_PORT_443_TCP_PORT"]}/api/" + @@ApiVersion + "/" + resource
          elsif api_group == @@ApiGroupApps
            return "https://#{env["KUBERNETES_SERVICE_HOST"]}:#{env["KUBERNETES_PORT_443_TCP_PORT"]}/apis/apps/" + @@ApiVersionApps + "/" + resource
          elsif api_group == @@ApiGroupHPA
            return "https://#{env["KUBERNETES_SERVICE_HOST"]}:#{env["KUBERNETES_PORT_443_TCP_PORT"]}/apis/" + @@ApiGroupHPA + "/" + @@ApiVersionHPA + "/" + resource
          end
        else
          @Log.warn ("Kubernetes environment variable not set KUBERNETES_SERVICE_HOST: #{env["KUBERNETES_SERVICE_HOST"]} KUBERNETES_PORT_443_TCP_PORT: #{env["KUBERNETES_PORT_443_TCP_PORT"]}. Unable to form resourceUri")
          return nil
        end
      end
    end

    def getClusterName(env = ENV)
      return @@ClusterName if !@@ClusterName.nil?
      @@ClusterName = "None"
      begin
        #try getting resource ID for aks
        cluster = env["AKS_RESOURCE_ID"]
        if cluster && !cluster.nil? && !cluster.empty?
          @@ClusterName = cluster.split("/").last
        else
          cluster = env["ACS_RESOURCE_NAME"]
          if cluster && !cluster.nil? && !cluster.empty?
            @@ClusterName = cluster
          else
            kubesystemResourceUri = "namespaces/" + @@KubeSystemNamespace + "/pods"
            @Log.info("KubernetesApiClient::getClusterName : Getting pods from Kube API @ #{Time.now.utc.iso8601}")
            podInfo = JSON.parse(getKubeResourceInfo(kubesystemResourceUri).body)
            @Log.info("KubernetesApiClient::getClusterName : Done getting pods from Kube API @ #{Time.now.utc.iso8601}")
            podInfo["items"].each do |items|
              if items["metadata"]["name"].include? "kube-controller-manager"
                items["spec"]["containers"][0]["command"].each do |command|
                  if command.include? "--cluster-name"
                    @@ClusterName = command.split("=")[1]
                  end
                end
              end
            end
          end
        end
      rescue => error
        @Log.warn("getClusterName failed: #{error}")
      end
      return @@ClusterName
    end

    def getClusterId(env = ENV)
      return @@ClusterId if !@@ClusterId.nil?
      #By default initialize ClusterId to ClusterName.
      #<TODO> In ACS/On-prem, we need to figure out how we can generate ClusterId
      # Dilipr: Spoof the subid by generating md5 hash of cluster name, and taking some constant parts of it.
      # e.g. md5 digest is 128 bits = 32 character in hex. Get first 16 and get a guid, and the next 16 to get resource id
      @@ClusterId = getClusterName
      begin
        cluster = env["AKS_RESOURCE_ID"]
        if cluster && !cluster.nil? && !cluster.empty?
          @@ClusterId = cluster
        end
      rescue => error
        @Log.warn("getClusterId failed: #{error}")
      end
      return @@ClusterId
    end

    def getUserAgent()
      return @@userAgent if !@@userAgent.nil?
      begin
          @@userAgent = "ama-logs/#{ENV['AGENT_VERSION'].nil? ? '0.0.0' : ENV['AGENT_VERSION']} (#{ENV['OS_TYPE'].nil? ? 'linux' : ENV['OS_TYPE']}; Ruby #{RUBY_PLATFORM})"
      rescue => error
        @Log.warn("KubernetesAPIClient::getUserAgent : getUserAgent failed: #{error}")
      end
      return @@userAgent || "ama-logs/0.0.0 ()"
    end

    def isAROV3Cluster
      return @@IsAROV3Cluster if !@@IsAROV3Cluster.nil?
      @@IsAROV3Cluster = false
      begin
        cluster = getClusterId
        if !cluster.nil? && !cluster.empty? && cluster.downcase.include?("/microsoft.containerservice/openshiftmanagedclusters")
          @@IsAROV3Cluster = true
        end
      rescue => error
        @Log.warn("KubernetesApiClient::IsAROV3Cluster : IsAROV3Cluster failed #{error}")
      end
      return @@IsAROV3Cluster
    end

    def isAROv3MasterOrInfraPod(nodeName)
      return isAROV3Cluster() && (!nodeName.nil? && (nodeName.downcase.start_with?("infra-") || nodeName.downcase.start_with?("master-")))
    end

    def isNodeMaster
      return @@IsNodeMaster if !@@IsNodeMaster.nil?
      @@IsNodeMaster = false
      begin
        @Log.info("KubernetesApiClient::isNodeMaster : Getting nodes from Kube API @ #{Time.now.utc.iso8601}")
        allNodesInfo = JSON.parse(getKubeResourceInfo("nodes").body)
        @Log.info("KubernetesApiClient::isNodeMaster : Done getting nodes from Kube API @ #{Time.now.utc.iso8601}")
        if !allNodesInfo.nil? && !allNodesInfo.empty?
          thisNodeName = OMS::Common.get_hostname
          allNodesInfo["items"].each do |item|
            if item["metadata"]["name"].casecmp(thisNodeName) == 0
              if item["metadata"]["labels"]["kubernetes.io/role"].to_s.include?("master") || item["metadata"]["labels"]["role"].to_s.include?("master")
                @@IsNodeMaster = true
              end
              break
            end
          end
        end
      rescue => error
        @Log.warn("KubernetesApiClient::isNodeMaster : node role request failed: #{error}")
      end

      return @@IsNodeMaster
    end

    def getNodesResourceUri(nodesResourceUri)
      begin
        # For ARO v3 cluster, filter out all other node roles other than compute
        if isAROV3Cluster()
          if !nodesResourceUri.nil? && !nodesResourceUri.index("?").nil?
            nodesResourceUri = nodesResourceUri + "&labelSelector=node-role.kubernetes.io%2Fcompute%3Dtrue"
          else
            nodesResourceUri = nodesResourceUri + "labelSelector=node-role.kubernetes.io%2Fcompute%3Dtrue"
          end
        end
      rescue => error
        @Log.warn("getNodesResourceUri failed: #{error}")
      end
      return nodesResourceUri
    end

    #def isValidRunningNode
    #    return @@IsValidRunningNode if !@@IsValidRunningNode.nil?
    #    @@IsValidRunningNode = false
    #    begin
    #        thisNodeName = OMS::Common.get_hostname
    #        if isLinuxCluster
    #            # Run on agent node [0]
    #            @@IsValidRunningNode = !isNodeMaster && thisNodeName.to_s.split('-').last == '0'
    #        else
    #            # Run on master node [0]
    #            @@IsValidRunningNode = isNodeMaster && thisNodeName.to_s.split('-').last == '0'
    #        end
    #    rescue => error
    #        @Log.warn("Checking Node Type failed: #{error}")
    #    end
    #    if(@@IsValidRunningNode == true)
    #        @Log.info("Electing current node to talk to k8 api")
    #    else
    #        @Log.info("Not Electing current node to talk to k8 api")
    #    end
    #    return @@IsValidRunningNode
    #end

    #def isLinuxCluster
    #    return @@IsLinuxCluster if !@@IsLinuxCluster.nil?
    #    @@IsLinuxCluster = true
    #    begin
    #        @Log.info("KubernetesApiClient::isLinuxCluster : Getting nodes from Kube API @ #{Time.now.utc.iso8601}")
    #        allNodesInfo = JSON.parse(getKubeResourceInfo('nodes').body)
    #        @Log.info("KubernetesApiClient::isLinuxCluster : Done getting nodes from Kube API @ #{Time.now.utc.iso8601}")
    #        if !allNodesInfo.nil? && !allNodesInfo.empty?
    #            allNodesInfo['items'].each do |item|
    #                if !(item['status']['nodeInfo']['operatingSystem'].casecmp('linux') == 0)
    #                    @@IsLinuxCluster = false
    #                    break
    #                end
    #            end
    #        end
    #    rescue => error
    #        @Log.warn("KubernetesApiClient::isLinuxCluster : node role request failed: #{error}")
    #    end
    #    return @@IsLinuxCluster
    #end

    # returns an arry of pods (json)
    def getPods(namespace)
      pods = []
      begin
        kubesystemResourceUri = "namespaces/" + namespace + "/pods"
        podInfo = JSON.parse(getKubeResourceInfo(kubesystemResourceUri).body)
        podInfo["items"].each do |items|
          pods.push items
        end
      rescue => error
        @Log.warn("List pods request failed: #{error}")
      end
      return pods
    end

    # returns a hash of windows node names and their internal IPs
    def getWindowsNodes
      winNodes = []
      begin
        # get only windows nodes
        resourceUri = getNodesResourceUri("nodes?labelSelector=kubernetes.io%2Fos%3Dwindows")
        nodeInventory = JSON.parse(getKubeResourceInfo(resourceUri).body)
        @Log.info "KubernetesAPIClient::getWindowsNodes : Got nodes from kube api"
        if (!nodeInventory.empty?)
          nodeInventory["items"].each do |item|
            # check for windows operating system in node metadata
            winNode = {}
            nodeStatus = item["status"]
            nodeMetadata = item["metadata"]
            if !nodeStatus.nil? && !nodeStatus["nodeInfo"].nil? && !nodeStatus["nodeInfo"]["operatingSystem"].nil?
              operatingSystem = nodeStatus["nodeInfo"]["operatingSystem"]
              if (operatingSystem.is_a?(String) && operatingSystem.casecmp("windows") == 0)
                nodeStatusAddresses = nodeStatus["addresses"]
                if !nodeStatusAddresses.nil?
                  nodeStatusAddresses.each do |address|
                    if !address["type"].nil? && address["type"].eql?("InternalIP")
                      ipAddress = address["address"]
                      # Pick Only IPv4 address in case of  dual stack
                      if IPAddress.valid_ipv4?(ipAddress)
                        winNode[address["type"]] = ipAddress
                      end
                    else
                      winNode[address["type"]] = address["address"]
                    end
                  end
                  winNodes.push(winNode)
                end
              end
            end
          end
        end
        return winNodes
      rescue => error
        @Log.warn("Error in get windows nodes: #{error}")
        return nil
      end
    end

    def getWindowsNodesArray
      winNodeArray = []
      begin
        # get only windows nodes
        resourceUri = getNodesResourceUri("nodes?labelSelector=kubernetes.io%2Fos%3Dwindows")
        nodeInventory = JSON.parse(getKubeResourceInfo(resourceUri).body)
        @Log.info "KubernetesAPIClient::getWindowsNodes : Got nodes from kube api"
        if (!nodeInventory.empty?)
          nodeInventory["items"].each do |item|
            # check for windows operating system in node metadata
            nodeStatus = item["status"]
            nodeMetadata = item["metadata"]
            if !nodeStatus.nil? && !nodeStatus["nodeInfo"].nil? && !nodeStatus["nodeInfo"]["operatingSystem"].nil?
              operatingSystem = nodeStatus["nodeInfo"]["operatingSystem"]
              if (operatingSystem.is_a?(String) && operatingSystem.casecmp("windows") == 0)
                # Adding windows nodes to winNodeArray so that it can be used in kubepodinventory to send ContainerInventory data
                # to get images and image tags for containers in windows nodes
                if !nodeMetadata.nil? && !nodeMetadata["name"].nil?
                  winNodeArray.push(nodeMetadata["name"])
                end
              end
            end
          end
        end
      rescue => error
        @Log.warn("KubernetesApiClient::getWindowsNodesArray:failed with an error: #{error}")
      end
      return winNodeArray
    end

    def getContainerIDs(namespace)
      containers = Hash.new
      begin
        kubesystemResourceUri = "namespaces/" + namespace + "/pods"
        @Log.info("KubernetesApiClient::getContainerIDs : Getting pods from Kube API @ #{Time.now.utc.iso8601}")
        podInfo = JSON.parse(getKubeResourceInfo(kubesystemResourceUri).body)
        @Log.info("KubernetesApiClient::getContainerIDs : Done getting pods from Kube API @ #{Time.now.utc.iso8601}")
        podInfo["items"].each do |item|
          if (!item["status"].nil? && !item["status"].empty? && !item["status"]["containerStatuses"].nil? && !item["status"]["containerStatuses"].empty?)
            item["status"]["containerStatuses"].each do |cntr|
              containers[cntr["containerID"]] = "kube-system"
            end
          end
        end
      rescue => error
        @Log.warn("KubernetesApiClient::getContainerIDs : List ContainerIDs request failed: #{error}")
      end
      return containers
    end

    def getContainerLogs(namespace, pod, container, showTimeStamp)
      containerLogs = ""
      begin
        kubesystemResourceUri = "namespaces/" + namespace + "/pods/" + pod + "/log" + "?container=" + container
        if showTimeStamp
          kubesystemResourceUri += "&timestamps=true"
        end
        @Log.info("KubernetesApiClient::getContainerLogs : Getting logs from Kube API @ #{Time.now.utc.iso8601}")
        containerLogs = getKubeResourceInfo(kubesystemResourceUri).body
        @Log.info("KubernetesApiClient::getContainerLogs : Done getting logs from Kube API @ #{Time.now.utc.iso8601}")
      rescue => error
        @Log.warn("Pod logs request failed: #{error}")
      end
      return containerLogs
    end

    def getContainerLogsSinceTime(namespace, pod, container, since, showTimeStamp)
      containerLogs = ""
      begin
        kubesystemResourceUri = "namespaces/" + namespace + "/pods/" + pod + "/log" + "?container=" + container + "&sinceTime=" + since
        kubesystemResourceUri = URI.escape(kubesystemResourceUri, ":.+") # HTML URL Encoding for date

        if showTimeStamp
          kubesystemResourceUri += "&timestamps=true"
        end
        @Log.info("calling #{kubesystemResourceUri}")
        @Log.info("KubernetesApiClient::getContainerLogsSinceTime : Getting logs from Kube API @ #{Time.now.utc.iso8601}")
        containerLogs = getKubeResourceInfo(kubesystemResourceUri).body
        @Log.info("KubernetesApiClient::getContainerLogsSinceTime : Done getting logs from Kube API @ #{Time.now.utc.iso8601}")
      rescue => error
        @Log.warn("Pod logs request failed: #{error}")
      end
      return containerLogs
    end

    def getPodUid(podNameSpace, podMetadata)
      podUid = nil
      begin
        if podNameSpace.eql?("kube-system") && !podMetadata.key?("ownerReferences")
          # The above case seems to be the only case where you have horizontal scaling of pods
          # but no controller, in which case cAdvisor picks up kubernetes.io/config.hash
          # instead of the actual poduid. Since this uid is not being surface into the UX
          # its ok to use this.
          # Use kubernetes.io/config.hash to be able to correlate with cadvisor data
          if podMetadata["annotations"].nil?
            return nil
          else
            podUid = podMetadata["annotations"]["kubernetes.io/config.hash"]
          end
        else
          podUid = podMetadata["uid"]
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getPodUid:Failed to get poduid: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return podUid
    end

    def getContainerResourceRequestsAndLimits(pod, metricCategory, metricNameToCollect, metricNametoReturn, nodeAllocatableRecord, metricTime = Time.now.utc.iso8601)
      metricItems = []
      begin
        clusterId = getClusterId
        podNameSpace = pod["metadata"]["namespace"]
        podUid = getPodUid(podNameSpace, pod["metadata"])
        if podUid.nil?
          return metricItems
        end
        podName = pod["metadata"]["name"]

        nodeName = ""
        #for unscheduled (non-started) pods nodeName does NOT exist
        if !pod["spec"]["nodeName"].nil?
          nodeName = pod["spec"]["nodeName"]
        end
        # For ARO, skip the pods scheduled on to master or infra nodes to ingest
        if isAROv3MasterOrInfraPod(nodeName)
          return metricItems
        end

        podContainers = []
        if !pod["spec"]["containers"].nil? && !pod["spec"]["containers"].empty?
          podContainers = podContainers + pod["spec"]["containers"]
        end
        # Adding init containers to the record list as well.
        if !pod["spec"]["initContainers"].nil? && !pod["spec"]["initContainers"].empty?
          podContainers = podContainers + pod["spec"]["initContainers"]
        end

        if (!podContainers.nil? && !podContainers.empty? && !pod["spec"]["nodeName"].nil?)
          podContainers.each do |container|
            containerName = container["name"]
            #metricTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z
            if (!container["resources"].nil? && !container["resources"].empty? && !container["resources"][metricCategory].nil? && !container["resources"][metricCategory][metricNameToCollect].nil?)
              metricValue = getMetricNumericValue(metricNameToCollect, container["resources"][metricCategory][metricNameToCollect])

              metricProps = {}
              metricProps["Timestamp"] = metricTime
              metricProps["Host"] = nodeName
              # Adding this so that it is not set by base ama-logs since it was not set earlier and being set by base ama-logs
              metricProps["Computer"] = nodeName
              metricProps["ObjectName"] = "K8SContainer"
              metricProps["InstanceName"] = clusterId + "/" + podUid + "/" + containerName

              metricCollection = {}
              metricCollection["CounterName"] = metricNametoReturn
              metricCollection["Value"] = metricValue

              metricProps["json_Collections"] = []
              metricCollections = []
              metricCollections.push(metricCollection)
              metricProps["json_Collections"] = metricCollections.to_json
              metricItems.push(metricProps)

              if isAddonResizerVPAEnabled()
                sendReplicasetAgentRequestsAndLimitsTelemetry(podName, podNameSpace, containerName, metricNametoReturn, metricValue)
              end
            else
              #No container level limit for the given metric, so default to node level limit
              if (metricCategory == "limits" && !nodeAllocatableRecord.nil? && !nodeAllocatableRecord.empty? && nodeAllocatableRecord.has_key?(metricNameToCollect))
                metricValue = getMetricNumericValue(metricNameToCollect, nodeAllocatableRecord[metricNameToCollect])
                metricProps = {}
                metricProps["Timestamp"] = metricTime
                metricProps["Host"] = nodeName
                # Adding this so that it is not set by base ama-logs since it was not set earlier and being set by base ama-logs
                metricProps["Computer"] = nodeName
                metricProps["ObjectName"] = "K8SContainer"
                metricProps["InstanceName"] = clusterId + "/" + podUid + "/" + containerName

                metricCollection = {}
                metricCollection["CounterName"] = metricNametoReturn
                metricCollection["Value"] = metricValue
                metricProps["json_Collections"] = []
                metricCollections = []
                metricCollections.push(metricCollection)
                metricProps["json_Collections"] = metricCollections.to_json
                metricItems.push(metricProps)
              end
            end
          end
        end
      rescue => error
        @Log.warn("getcontainerResourceRequestsAndLimits failed: #{error} for metric #{metricCategory} #{metricNameToCollect}")
        return metricItems
      end
      return metricItems
    end #getContainerResourceRequestAndLimits

    def getContainerResourceRequestsAndLimitsAsInsightsMetrics(pod, metricCategory, metricNameToCollect, metricNametoReturn, nodeAllocatableRecord, metricTime = Time.now.utc.iso8601)
      metricItems = []
      begin
        clusterId = getClusterId
        clusterName = getClusterName
        podNameSpace = pod["metadata"]["namespace"]
        if podNameSpace.eql?("kube-system") && !pod["metadata"].key?("ownerReferences")
          # The above case seems to be the only case where you have horizontal scaling of pods
          # but no controller, in which case cAdvisor picks up kubernetes.io/config.hash
          # instead of the actual poduid. Since this uid is not being surface into the UX
          # its ok to use this.
          # Use kubernetes.io/config.hash to be able to correlate with cadvisor data
          if pod["metadata"]["annotations"].nil?
            return metricItems
          else
            podUid = pod["metadata"]["annotations"]["kubernetes.io/config.hash"]
          end
        else
          podUid = pod["metadata"]["uid"]
        end

        podContainers = []
        if !pod["spec"]["containers"].nil? && !pod["spec"]["containers"].empty?
          podContainers = podContainers + pod["spec"]["containers"]
        end
        # Adding init containers to the record list as well.
        if !pod["spec"]["initContainers"].nil? && !pod["spec"]["initContainers"].empty?
          podContainers = podContainers + pod["spec"]["initContainers"]
        end

        if (!podContainers.nil? && !podContainers.empty?)
          if (!pod["spec"]["nodeName"].nil?)
            nodeName = pod["spec"]["nodeName"]
          else
            nodeName = "" #unscheduled pod. We still want to collect limits & requests for GPU
          end
          podContainers.each do |container|
            metricValue = nil
            containerName = container["name"]
            #metricTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z
            if (!container["resources"].nil? && !container["resources"].empty? && !container["resources"][metricCategory].nil? && !container["resources"][metricCategory][metricNameToCollect].nil?)
              metricValue = getMetricNumericValue(metricNameToCollect, container["resources"][metricCategory][metricNameToCollect])
            else
              #No container level limit for the given metric, so default to node level limit for non-gpu metrics
              if (metricNameToCollect.downcase != "nvidia.com/gpu") && (metricNameToCollect.downcase != "amd.com/gpu")
                if !nodeAllocatableRecord.nil? && !nodeAllocatableRecord.empty? && nodeAllocatableRecord.has_key?(metricNameToCollect)
                  metricValue = getMetricNumericValue(metricNameToCollect, nodeAllocatableRecord[metricNameToCollect])
                end
              end
            end
            if (!metricValue.nil?)
              metricItem = {}
              metricItem["CollectionTime"] = metricTime
              metricItem["Computer"] = nodeName
              metricItem["Name"] = metricNametoReturn
              metricItem["Value"] = metricValue
              metricItem["Origin"] = Constants::INSIGHTSMETRICS_TAGS_ORIGIN
              metricItem["Namespace"] = Constants::INSIGHTSMETRICS_TAGS_GPU_NAMESPACE

              metricTags = {}
              metricTags[Constants::INSIGHTSMETRICS_TAGS_CLUSTERID] = clusterId
              metricTags[Constants::INSIGHTSMETRICS_TAGS_CLUSTERNAME] = clusterName
              metricTags[Constants::INSIGHTSMETRICS_TAGS_CONTAINER_NAME] = podUid + "/" + containerName
              #metricTags[Constants::INSIGHTSMETRICS_TAGS_K8SNAMESPACE] = podNameSpace

              metricItem["Tags"] = metricTags

              metricItems.push(metricItem)
            end
          end
        end
      rescue => error
        @Log.warn("getcontainerResourceRequestsAndLimitsAsInsightsMetrics failed: #{error} for metric #{metricCategory} #{metricNameToCollect}")
        return metricItems
      end
      return metricItems
    end #getContainerResourceRequestAndLimitsAsInsightsMetrics

    def parseNodeLimits(metricJSON, metricCategory, metricNameToCollect, metricNametoReturn, metricTime = Time.now.utc.iso8601)
      metricItems = []
      begin
        metricInfo = metricJSON
        clusterId = getClusterId
        #Since we are getting all node data at the same time and kubernetes doesnt specify a timestamp for the capacity and allocation metrics,
        #if we are coming up with the time it should be same for all nodes
        #metricTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z
        metricInfo["items"].each do |node|
          metricItem = parseNodeLimitsFromNodeItem(node, metricCategory, metricNameToCollect, metricNametoReturn, metricTime)
          if !metricItem.nil? && !metricItem.empty?
            metricItems.push(metricItem)
          end
        end
      rescue => error
        @Log.warn("parseNodeLimits failed: #{error} for metric #{metricCategory} #{metricNameToCollect}")
      end
      return metricItems
    end #parseNodeLimits

    def parseNodeLimitsFromNodeItem(node, metricCategory, metricNameToCollect, metricNametoReturn, metricTime = Time.now.utc.iso8601)
      metricItem = {}
      begin
        clusterId = getClusterId
        #Since we are getting all node data at the same time and kubernetes doesnt specify a timestamp for the capacity and allocation metrics,
        #if we are coming up with the time it should be same for all nodes
        #metricTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z
        if (!node["status"][metricCategory].nil?) && (!node["status"][metricCategory][metricNameToCollect].nil?)
          # metricCategory can be "capacity" or "allocatable" and metricNameToCollect can be "cpu" or "memory"
          metricValue = getMetricNumericValue(metricNameToCollect, node["status"][metricCategory][metricNameToCollect])

          metricItem["Timestamp"] = metricTime
          metricItem["Host"] = node["metadata"]["name"]
          # Adding this so that it is not set by base ama-logs since it was not set earlier and being set by base ama-logs
          metricItem["Computer"] = node["metadata"]["name"]
          metricItem["ObjectName"] = "K8SNode"
          metricItem["InstanceName"] = clusterId + "/" + node["metadata"]["name"]

          metricCollection = {}
          metricCollection["CounterName"] = metricNametoReturn
          metricCollection["Value"] = metricValue
          metricCollections = []
          metricCollections.push(metricCollection)

          metricItem["json_Collections"] = []
          metricItem["json_Collections"] = metricCollections.to_json
        end
      rescue => error
        @Log.warn("parseNodeLimitsFromNodeItem failed: #{error} for metric #{metricCategory} #{metricNameToCollect}")
      end
      return metricItem
    end #parseNodeLimitsFromNodeItem

    def parseNodeLimitsAsInsightsMetrics(node, metricCategory, metricNameToCollect, metricNametoReturn, metricTime = Time.now.utc.iso8601)
      metricItem = {}
      begin
        #Since we are getting all node data at the same time and kubernetes doesnt specify a timestamp for the capacity and allocation metrics,
        #if we are coming up with the time it should be same for all nodes
        #metricTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z
        if (!node["status"][metricCategory].nil?) && (!node["status"][metricCategory][metricNameToCollect].nil?)
          clusterId = getClusterId
          clusterName = getClusterName

          # metricCategory can be "capacity" or "allocatable" and metricNameToCollect can be "cpu" or "memory" or "amd.com/gpu" or "nvidia.com/gpu"
          metricValue = getMetricNumericValue(metricNameToCollect, node["status"][metricCategory][metricNameToCollect])

          metricItem["CollectionTime"] = metricTime
          metricItem["Computer"] = node["metadata"]["name"]
          metricItem["Name"] = metricNametoReturn
          metricItem["Value"] = metricValue
          metricItem["Origin"] = Constants::INSIGHTSMETRICS_TAGS_ORIGIN
          metricItem["Namespace"] = Constants::INSIGHTSMETRICS_TAGS_GPU_NAMESPACE

          metricTags = {}
          metricTags[Constants::INSIGHTSMETRICS_TAGS_CLUSTERID] = clusterId
          metricTags[Constants::INSIGHTSMETRICS_TAGS_CLUSTERNAME] = clusterName
          metricTags[Constants::INSIGHTSMETRICS_TAGS_GPU_VENDOR] = metricNameToCollect

          metricItem["Tags"] = metricTags
        end
      rescue => error
        @Log.warn("parseNodeLimitsAsInsightsMetrics failed: #{error} for metric #{metricCategory} #{metricNameToCollect}")
      end
      return metricItem
    end

    def getMetricNumericValue(metricName, metricVal)
      metricValue = metricVal.downcase
      begin
        case metricName
        when "memory" #convert to bytes for memory
          #https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/
          if (metricValue.end_with?("ki"))
            metricValue.chomp!("ki")
            metricValue = Float(metricValue) * 1024.0 ** 1
          elsif (metricValue.end_with?("mi"))
            metricValue.chomp!("mi")
            metricValue = Float(metricValue) * 1024.0 ** 2
          elsif (metricValue.end_with?("gi"))
            metricValue.chomp!("gi")
            metricValue = Float(metricValue) * 1024.0 ** 3
          elsif (metricValue.end_with?("ti"))
            metricValue.chomp!("ti")
            metricValue = Float(metricValue) * 1024.0 ** 4
          elsif (metricValue.end_with?("pi"))
            metricValue.chomp!("pi")
            metricValue = Float(metricValue) * 1024.0 ** 5
          elsif (metricValue.end_with?("ei"))
            metricValue.chomp!("ei")
            metricValue = Float(metricValue) * 1024.0 ** 6
          elsif (metricValue.end_with?("zi"))
            metricValue.chomp!("zi")
            metricValue = Float(metricValue) * 1024.0 ** 7
          elsif (metricValue.end_with?("yi"))
            metricValue.chomp!("yi")
            metricValue = Float(metricValue) * 1024.0 ** 8
          elsif (metricValue.end_with?("k"))
            metricValue.chomp!("k")
            metricValue = Float(metricValue) * 1000.0 ** 1
          elsif (metricValue.end_with?("m"))
            #original value before downcase ending with M is megabyte and value ending with m is milli-byte
            metricValue.chomp!("m")
            if (metricVal.end_with?("M"))
              metricValue = Float(metricValue) * 1000.0 ** 2
            else
              metricValue = Float(metricValue) / 1000.0
            end
          elsif (metricValue.end_with?("g"))
            metricValue.chomp!("g")
            metricValue = Float(metricValue) * 1000.0 ** 3
          elsif (metricValue.end_with?("t"))
            metricValue.chomp!("t")
            metricValue = Float(metricValue) * 1000.0 ** 4
          elsif (metricValue.end_with?("p"))
            metricValue.chomp!("p")
            metricValue = Float(metricValue) * 1000.0 ** 5
          elsif (metricValue.end_with?("e"))
            metricValue.chomp!("e")
            metricValue = Float(metricValue) * 1000.0 ** 6
          elsif (metricValue.end_with?("z"))
            metricValue.chomp!("z")
            metricValue = Float(metricValue) * 1000.0 ** 7
          elsif (metricValue.end_with?("y"))
            metricValue.chomp!("y")
            metricValue = Float(metricValue) * 1000.0 ** 8
          else #assuming there are no units specified, it is bytes (the below conversion will fail for other unsupported 'units')
            metricValue = Float(metricValue)
          end
        when "cpu" #convert to nanocores for cpu
          #https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/
          if (metricValue.end_with?("m"))
            metricValue.chomp!("m")
            metricValue = Float(metricValue) * 1000.0 ** 2
          elsif (metricValue.end_with?("k"))
            metricValue.chomp!("k")
            metricValue = Float(metricValue) * 1000.0
          else #assuming no units specified, it is cores that we are converting to nanocores (the below conversion will fail for other unsupported 'units')
            metricValue = Float(metricValue) * 1000.0 ** 3
          end
        when "nvidia.com/gpu"
          metricValue = Float(metricValue) * 1.0
        when "amd.com/gpu"
          metricValue = Float(metricValue) * 1.0
        else
          @Log.warn("getMetricNumericValue: Unsupported metric #{metricName}. Returning 0 for metric value")
          metricValue = 0
        end #case statement
      rescue => error
        @Log.warn("getMetricNumericValue failed: #{error} for metric #{metricName} with value #{metricVal}. Returning 0 for metric value")
        return 0
      end
      return metricValue
    end # getMetricNumericValue

    def getResourcesAndContinuationTokenV2(uri, api_group: nil)
      continuationToken = nil
      resourceInventory = nil
      responseCode = nil
      begin
        @Log.info "KubernetesApiClient::getResourcesAndContinuationTokenV2 : Getting resources from Kube API using url: #{uri} @ #{Time.now.utc.iso8601}"
        responseCode, resourceInfo = getKubeResourceInfoV2(uri, api_group: api_group)
        @Log.info "KubernetesApiClient::getResourcesAndContinuationTokenV2 : Done getting resources from Kube API using url: #{uri} @ #{Time.now.utc.iso8601}"
        if !responseCode.nil? && responseCode == "200" && !resourceInfo.nil?
          @Log.info "KubernetesApiClient::getResourcesAndContinuationTokenV2:Start:Parsing data for #{uri} using JSON @ #{Time.now.utc.iso8601}"
          resourceInventory = JSON.parse(resourceInfo.body)
          @Log.info "KubernetesApiClient::getResourcesAndContinuationTokenV2:End:Parsing data for #{uri} using JSON @ #{Time.now.utc.iso8601}"
          resourceInfo = nil
        end
        if (!resourceInventory.nil? && !resourceInventory["metadata"].nil?)
          continuationToken = resourceInventory["metadata"]["continue"]
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getResourcesAndContinuationTokenV2:Failed in get resources for #{uri} and continuation token: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
        resourceInventory = nil
      end
      return continuationToken, resourceInventory, responseCode
    end #getResourcesAndContinuationTokenV2

    def getResourcesAndContinuationToken(uri, api_group: nil)
      continuationToken = nil
      resourceInventory = nil
      begin
        @Log.info "KubernetesApiClient::getResourcesAndContinuationToken : Getting resources from Kube API using url: #{uri} @ #{Time.now.utc.iso8601}"
        resourceInfo = getKubeResourceInfo(uri, api_group: api_group)
        @Log.info "KubernetesApiClient::getResourcesAndContinuationToken : Done getting resources from Kube API using url: #{uri} @ #{Time.now.utc.iso8601}"
        if !resourceInfo.nil?
          @Log.info "KubernetesApiClient::getResourcesAndContinuationToken:Start:Parsing data for #{uri} using JSON @ #{Time.now.utc.iso8601}"
          resourceInventory = JSON.parse(resourceInfo.body)
          @Log.info "KubernetesApiClient::getResourcesAndContinuationToken:End:Parsing data for #{uri} using JSON @ #{Time.now.utc.iso8601}"
          resourceInfo = nil
        end
        if (!resourceInventory.nil? && !resourceInventory["metadata"].nil?)
          continuationToken = resourceInventory["metadata"]["continue"]
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getResourcesAndContinuationToken:Failed in get resources for #{uri} and continuation token: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
        resourceInventory = nil
      end
      return continuationToken, resourceInventory
    end #getResourcesAndContinuationToken

    def getKubeAPIServerUrl(env = ENV)
      apiServerUrl = nil
      begin
        if env["KUBERNETES_SERVICE_HOST"] && env["KUBERNETES_PORT_443_TCP_PORT"]
          apiServerUrl = "https://#{env["KUBERNETES_SERVICE_HOST"]}:#{env["KUBERNETES_PORT_443_TCP_PORT"]}"
        else
          @Log.warn "Kubernetes environment variable not set KUBERNETES_SERVICE_HOST: #{env["KUBERNETES_SERVICE_HOST"]} KUBERNETES_PORT_443_TCP_PORT: #{env["KUBERNETES_PORT_443_TCP_PORT"]}. Unable to form resourceUri"
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getKubeAPIServerUrl:Failed  #{errorStr}"
      end
      return apiServerUrl
    end

    def getKubeServicesInventoryRecords(serviceList, batchTime = Time.utc.iso8601)
      kubeServiceRecords = []
      begin
        if (!serviceList.nil? && !serviceList.empty? && serviceList.key?("items") && !serviceList["items"].nil? && !serviceList["items"].empty?)
          servicesCount = serviceList["items"].length
          @Log.info("KubernetesApiClient::getKubeServicesInventoryRecords : number of services in serviceList  #{servicesCount} @ #{Time.now.utc.iso8601}")
          serviceList["items"].each do |item|
            kubeServiceRecord = {}
            kubeServiceRecord["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
            kubeServiceRecord["ServiceName"] = item["metadata"]["name"]
            kubeServiceRecord["Namespace"] = item["metadata"]["namespace"]
            kubeServiceRecord["SelectorLabels"] = [item["spec"]["selector"]]
            # added these before emit to avoid memory foot print
            # kubeServiceRecord["ClusterId"] = KubernetesApiClient.getClusterId
            # kubeServiceRecord["ClusterName"] = KubernetesApiClient.getClusterName
            kubeServiceRecord["ClusterIP"] = item["spec"]["clusterIP"]
            kubeServiceRecord["ServiceType"] = item["spec"]["type"]
            kubeServiceRecords.push(kubeServiceRecord.dup)
          end
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getKubeServicesInventoryRecords:Failed with an error : #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return kubeServiceRecords
    end

    # Accepts the following options:
    #   :namespace (string) - the namespace of the entity.
    #   :name (string) - the name of the entity to watch.
    #   :label_selector (string) - a selector to restrict the list of returned objects by labels.
    #   :field_selector (string) - a selector to restrict the list of returned objects by fields.
    #   :resource_version (string) - shows changes that occur after passed version of a resource.
    #   :allow_watch_bookmarks (bool) - flag to indicate whether to use bookmark or not.
    def watch(resource_name, options = {})
      begin
        if !File.exist?(@@CaFile)
          raise "#{@@CaFile} doesnt exist"
        end
        http_options = {
          use_ssl: true,
          open_timeout: 60,
          read_timeout: 240, # https://github.com/kubernetes-client/java/issues/1370 https://github.com/kubernetes-client/java/issues/1578
          ca_file: @@CaFile,
          verify_mode: OpenSSL::SSL::VERIFY_PEER,
        }
        http_headers = {
          Authorization: "Bearer " + getTokenStr,
          "User-Agent": getUserAgent(),
        }
        ns = ""
        if !options[:namespace].to_s.empty?
          ns = "namespaces/#{namespace}/"
        end
        path = "watch/#{ns}#{resource_name}"
        path += "/#{options[:name]}" if options[:name]
        api_endpoint = "https://#{ENV["KUBERNETES_SERVICE_HOST"]}:#{ENV["KUBERNETES_PORT_443_TCP_PORT"]}/api/" + @@ApiVersion + "/" + "#{path}"
        uri = URI.parse(api_endpoint)
        params = {}
        WATCH_ARGUMENTS.each { |k, v| params[k] = options[v] if options[v] }
        uri.query = URI.encode_www_form(params) if params.any?
        watcher = WatchStream.new(
          uri,
          http_options,
          http_headers,
          @Log
        )
        return watcher unless block_given?
        begin
          watcher.each(&block)
        ensure
          watcher.finish if watcher
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::watch:Failed with an error: #{errorStr}"
      end
    end

    def getOptimizedItem(resource, resourceItem, isWindowsItem = false)
      case resource
      when "pods"
        return getPodOptimizedItem(resourceItem, isWindowsItem)
      when "pods-perf"
        return getPodPerfOptimizedItem(resourceItem)
      when "nodes"
        return getNodeOptimizedItem(resourceItem)
      when "services"
        return getServiceOptimizedItem(resourceItem)
      when "deployments"
        return getDeploymentOptimizedItem(resourceItem)
      when "horizontalpodautoscalers"
        return getHpaOptimizedItem(resourceItem)
      else
        return resourceItem
      end
    end

    def getServiceOptimizedItem(resourceItem)
      item = {}
      begin
        item["metadata"] = {}
        if !resourceItem["metadata"].nil?
          item["metadata"]["name"] = resourceItem["metadata"]["name"]
          item["metadata"]["namespace"] = resourceItem["metadata"]["namespace"]
        end
        item["spec"] = {}
        if !resourceItem["spec"].nil?
          item["spec"]["selector"] = []
          if !resourceItem["spec"]["selector"].nil?
            item["spec"]["selector"] = resourceItem["spec"]["selector"]
          end
          item["spec"]["clusterIP"] = ""
          if !resourceItem["spec"]["clusterIP"].nil?
            item["spec"]["clusterIP"] = resourceItem["spec"]["clusterIP"]
          end
          item["spec"]["type"] = ""
          if !resourceItem["spec"]["type"].nil?
            item["spec"]["type"] = resourceItem["spec"]["type"]
          end
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getServiceOptimizedItem:Failed with an error : #{errorStr}"
      end
      return item
    end

    def isWindowsNodeItem(nodeResourceItem)
      isWindowsNodeItem = false
      begin
        nodeStatus = nodeResourceItem["status"]
        if !nodeStatus.nil? && !nodeStatus["nodeInfo"].nil? && !nodeStatus["nodeInfo"]["operatingSystem"].nil?
          operatingSystem = nodeStatus["nodeInfo"]["operatingSystem"]
          if (operatingSystem.is_a?(String) && operatingSystem.casecmp("windows") == 0)
            isWindowsNodeItem = true
          end
        end
      rescue => errorStr
        $Log.warn "KubernetesApiClient::::isWindowsNodeItem: failed with an error: #{errorStr} @ #{Time.now.utc.iso8601}"
      end
      return isWindowsNodeItem
    end

    def getPodPerfOptimizedItem(resourceItem)
      item = {}
      begin
        item["metadata"] = {}
        if !resourceItem["metadata"].nil?
          if !resourceItem["metadata"]["annotations"].nil?
            item["metadata"]["annotations"] = {}
            item["metadata"]["annotations"]["kubernetes.io/config.hash"] = resourceItem["metadata"]["annotations"]["kubernetes.io/config.hash"]
          end

          if !resourceItem["metadata"]["ownerReferences"].nil? && resourceItem["metadata"]["ownerReferences"].length > 0
            item["metadata"]["ownerReferences"] = []
            ownerReference = {}
            ownerReference["name"] = resourceItem["metadata"]["ownerReferences"][0]["name"]
            ownerReference["kind"] = resourceItem["metadata"]["ownerReferences"][0]["kind"]
            item["metadata"]["ownerReferences"].push(ownerReference)
          end
          item["metadata"]["name"] = resourceItem["metadata"]["name"]
          item["metadata"]["namespace"] = resourceItem["metadata"]["namespace"]
          item["metadata"]["uid"] = resourceItem["metadata"]["uid"]
        end

        item["spec"] = {}
        if !resourceItem["spec"].nil?
          item["spec"]["containers"] = []
          if !resourceItem["spec"]["containers"].nil?
            resourceItem["spec"]["containers"].each do |container|
              currentContainer = {}
              currentContainer["name"] = container["name"]
              currentContainer["resources"] = container["resources"]
              item["spec"]["containers"].push(currentContainer)
            end
          end
          item["spec"]["initContainers"] = []
          if !resourceItem["spec"]["initContainers"].nil?
            resourceItem["spec"]["initContainers"].each do |container|
              currentContainer = {}
              currentContainer["name"] = container["name"]
              currentContainer["resources"] = container["resources"]
              item["spec"]["initContainers"].push(currentContainer)
            end
          end
          item["spec"]["nodeName"] = ""
          if !resourceItem["spec"]["nodeName"].nil?
            item["spec"]["nodeName"] = resourceItem["spec"]["nodeName"]
          end
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getPodPerfOptimizedItem:Failed with an error : #{errorStr}"
      end
      return item
    end

    def getPodOptimizedItem(resourceItem, isWindowsPodItem)
      item = {}
      begin
        item["metadata"] = {}
        if !resourceItem["metadata"].nil?
          if !resourceItem["metadata"]["annotations"].nil?
            item["metadata"]["annotations"] = {}
            item["metadata"]["annotations"]["kubernetes.io/config.hash"] = resourceItem["metadata"]["annotations"]["kubernetes.io/config.hash"]
          end
          if !resourceItem["metadata"]["labels"].nil?
            item["metadata"]["labels"] = resourceItem["metadata"]["labels"]
          end
          if !resourceItem["metadata"]["ownerReferences"].nil? && resourceItem["metadata"]["ownerReferences"].length > 0
            item["metadata"]["ownerReferences"] = []
            ownerReference = {}
            ownerReference["name"] = resourceItem["metadata"]["ownerReferences"][0]["name"]
            ownerReference["kind"] = resourceItem["metadata"]["ownerReferences"][0]["kind"]
            item["metadata"]["ownerReferences"].push(ownerReference)
          end
          item["metadata"]["name"] = resourceItem["metadata"]["name"]
          item["metadata"]["namespace"] = resourceItem["metadata"]["namespace"]
          item["metadata"]["uid"] = resourceItem["metadata"]["uid"]
          item["metadata"]["creationTimestamp"] = resourceItem["metadata"]["creationTimestamp"]
          if !resourceItem["metadata"]["deletionTimestamp"].nil?
            item["metadata"]["deletionTimestamp"] = resourceItem["metadata"]["deletionTimestamp"]
          end
        end

        item["spec"] = {}
        if !resourceItem["spec"].nil?
          item["spec"]["containers"] = []
          item["spec"]["initContainers"] = []
          isDisableClusterCollectEnvVar = false
          clusterCollectEnvironmentVar = ENV["AZMON_CLUSTER_COLLECT_ENV_VAR"]
          if !clusterCollectEnvironmentVar.nil? && !clusterCollectEnvironmentVar.empty? && clusterCollectEnvironmentVar.casecmp("false") == 0
            isDisableClusterCollectEnvVar = true
          end

          # container spec required only for windows container inventory records
          if isWindowsPodItem
            if !resourceItem["spec"]["containers"].nil?
              resourceItem["spec"]["containers"].each do |container|
                currentContainer = {}
                currentContainer["name"] = container["name"]
                currentContainer["resources"] = container["resources"]
                # fields required for windows containers records
                if isWindowsPodItem
                  currentContainer["image"] = container["image"]
                  currentContainer["ports"] = container["ports"]
                  currentContainer["command"] = container["command"]
                  currentContainer["env"] = ""
                  if !isDisableClusterCollectEnvVar
                    currentContainer["env"] = KubernetesContainerInventory.obtainContainerEnvironmentVarsFromPodsResponse(resourceItem, container)
                  end
                end
                item["spec"]["containers"].push(currentContainer)
              end
            end
            if !resourceItem["spec"]["initContainers"].nil?
              resourceItem["spec"]["initContainers"].each do |container|
                currentContainer = {}
                currentContainer["name"] = container["name"]
                currentContainer["resources"] = container["resources"]
                # fields required for windows containers records
                if isWindowsPodItem
                  currentContainer["image"] = container["image"]
                  currentContainer["ports"] = container["ports"]
                  currentContainer["command"] = container["command"]
                  currentContainer["env"] = ""
                  if !isDisableClusterCollectEnvVar
                    currentContainer["env"] = KubernetesContainerInventory.obtainContainerEnvironmentVarsFromPodsResponse(resourceItem, container)
                  end
                end
                item["spec"]["initContainers"].push(currentContainer)
              end
            end
          end

          item["spec"]["nodeName"] = ""
          if !resourceItem["spec"]["nodeName"].nil?
            item["spec"]["nodeName"] = resourceItem["spec"]["nodeName"]
          end
        end
        item["status"] = {}

        if !resourceItem["status"].nil?
          if !resourceItem["status"]["startTime"].nil?
            item["status"]["startTime"] = resourceItem["status"]["startTime"]
          end
          if !resourceItem["status"]["reason"].nil?
            item["status"]["reason"] = resourceItem["status"]["reason"]
          end
          if !resourceItem["status"]["podIP"].nil?
            item["status"]["podIP"] = resourceItem["status"]["podIP"]
          end
          if !resourceItem["status"]["phase"].nil?
            item["status"]["phase"] = resourceItem["status"]["phase"]
          end
          if !resourceItem["status"]["conditions"].nil?
            item["status"]["conditions"] = []
            resourceItem["status"]["conditions"].each do |condition|
              currentCondition = {}
              currentCondition["type"] = condition["type"]
              currentCondition["status"] = condition["status"]
              item["status"]["conditions"].push(currentCondition)
            end
          end
          item["status"]["initContainerStatuses"] = []
          if !resourceItem["status"]["initContainerStatuses"].nil?
            resourceItem["status"]["initContainerStatuses"].each do |containerStatus|
              currentContainerStatus = {}
              currentContainerStatus["containerID"] = containerStatus["containerID"]
              currentContainerStatus["name"] = containerStatus["name"]
              currentContainerStatus["restartCount"] = containerStatus["restartCount"]
              currentContainerStatus["state"] = containerStatus["state"]
              currentContainerStatus["lastState"] = containerStatus["lastState"]
              if isWindowsPodItem
                currentContainerStatus["imageID"] = containerStatus["imageID"]
              end
              item["status"]["initContainerStatuses"].push(currentContainerStatus)
            end
          end
          item["status"]["containerStatuses"] = []
          if !resourceItem["status"]["containerStatuses"].nil?
            resourceItem["status"]["containerStatuses"].each do |containerStatus|
              currentContainerStatus = {}
              currentContainerStatus["containerID"] = containerStatus["containerID"]
              currentContainerStatus["name"] = containerStatus["name"]
              currentContainerStatus["restartCount"] = containerStatus["restartCount"]
              currentContainerStatus["state"] = containerStatus["state"]
              currentContainerStatus["lastState"] = containerStatus["lastState"]
              if isWindowsPodItem
                currentContainerStatus["imageID"] = containerStatus["imageID"]
              end
              item["status"]["containerStatuses"].push(currentContainerStatus)
            end
          end
          # this metadata used to identify the pod scheduled onto windows node
          # so that pod inventory can make decision to extract containerinventory records or not
          if isWindowsPodItem
            item["isWindows"] = "true"
          end
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getPodOptimizedItem:Failed with an error : #{errorStr}"
      end
      return item
    end

    def getNodeAllocatableValues(nodeResourceItem)
      nodeAllocatable = {}
      begin
        if !nodeResourceItem["status"].nil? &&
           !nodeResourceItem["status"]["allocatable"].nil? &&
           !nodeResourceItem["status"]["allocatable"].empty?
          nodeAllocatable["cpu"] = nodeResourceItem["status"]["allocatable"]["cpu"]
          nodeAllocatable["memory"] = nodeResourceItem["status"]["allocatable"]["memory"]
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getNodeAllocatableValues:Failed with an error : #{errorStr}"
      end
      return nodeAllocatable
    end

    def getNodeOptimizedItem(resourceItem)
      item = {}
      begin
        item["metadata"] = {}
        if !resourceItem["metadata"].nil?
          item["metadata"]["name"] = resourceItem["metadata"]["name"]
          item["metadata"]["creationTimestamp"] = resourceItem["metadata"]["creationTimestamp"]
          if !resourceItem["metadata"]["labels"].nil?
            item["metadata"]["labels"] = resourceItem["metadata"]["labels"]
          end
        end
        item["spec"] = {}
        if !resourceItem["spec"].nil?
          if !resourceItem["spec"]["providerID"].nil? && !resourceItem["spec"]["providerID"].empty?
            provider = resourceItem["spec"]["providerID"].split(":")[0]
            if !provider.nil? && !provider.empty?
              item["spec"]["providerID"] = provider
            end
          end
        end
        item["status"] = {}
        if !resourceItem["status"].nil?
          item["status"]["conditions"] = []
          if !resourceItem["status"]["conditions"].nil?
            resourceItem["status"]["conditions"].each do |condition|
              currentCondition = {}
              currentCondition["type"] = condition["type"]
              currentCondition["status"] = condition["status"]
              currentCondition["lastTransitionTime"] = condition["lastTransitionTime"]
              item["status"]["conditions"].push(currentCondition)
            end
          end

          nodeInfo = {}
          if !resourceItem["status"]["nodeInfo"].nil? && !resourceItem["status"]["nodeInfo"].empty?
            nodeInfo["kubeletVersion"] = resourceItem["status"]["nodeInfo"]["kubeletVersion"]
            nodeInfo["kubeProxyVersion"] = resourceItem["status"]["nodeInfo"]["kubeProxyVersion"]
            nodeInfo["osImage"] = resourceItem["status"]["nodeInfo"]["osImage"]
            nodeInfo["containerRuntimeVersion"] = resourceItem["status"]["nodeInfo"]["containerRuntimeVersion"]
            nodeInfo["operatingSystem"] = resourceItem["status"]["nodeInfo"]["operatingSystem"]
            nodeInfo["kernelVersion"] = resourceItem["status"]["nodeInfo"]["kernelVersion"]
            nodeInfo["architecture"] = resourceItem["status"]["nodeInfo"]["architecture"]
          end
          item["status"]["nodeInfo"] = nodeInfo

          nodeAllocatable = {}
          if !resourceItem["status"]["allocatable"].nil? && !resourceItem["status"]["allocatable"].empty?
            nodeAllocatable["cpu"] = resourceItem["status"]["allocatable"]["cpu"]
            nodeAllocatable["memory"] = resourceItem["status"]["allocatable"]["memory"]
            if !resourceItem["status"]["allocatable"]["nvidia.com/gpu"].nil?
              nodeAllocatable["nvidia.com/gpu"] = resourceItem["status"]["allocatable"]["nvidia.com/gpu"]
            end
            if !resourceItem["status"]["allocatable"]["amd.com/gpu"].nil?
              nodeAllocatable["amd.com/gpu"] = resourceItem["status"]["allocatable"]["amd.com/gpu"]
            end
          end
          item["status"]["allocatable"] = nodeAllocatable

          nodeCapacity = {}
          if !resourceItem["status"]["capacity"].nil? && !resourceItem["status"]["capacity"].empty?
            nodeCapacity["cpu"] = resourceItem["status"]["capacity"]["cpu"]
            nodeCapacity["memory"] = resourceItem["status"]["capacity"]["memory"]
            if !resourceItem["status"]["capacity"]["nvidia.com/gpu"].nil?
              nodeCapacity["nvidia.com/gpu"] = resourceItem["status"]["capacity"]["nvidia.com/gpu"]
            end
            if !resourceItem["status"]["capacity"]["amd.com/gpu"].nil?
              nodeCapacity["amd.com/gpu"] = resourceItem["status"]["capacity"]["amd.com/gpu"]
            end
          end
          item["status"]["capacity"] = nodeCapacity
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getNodeOptimizedItem:Failed with an error : #{errorStr}"
      end
      return item
    end

    def getDeploymentOptimizedItem(resourceItem)
      item = {}
      begin
        item["metadata"] = {}
        if !resourceItem["metadata"].nil?
          item["metadata"]["name"] = resourceItem["metadata"]["name"]
          item["metadata"]["creationTimestamp"] = resourceItem["metadata"]["creationTimestamp"]
        end
        item["spec"] = {}
        if !resourceItem["spec"].nil?
          item["spec"]["strategy"] = {}
          if !resourceItem["spec"]["strategy"].nil? && !resourceItem["spec"]["strategy"].empty? && !resourceItem["spec"]["strategy"]["type"].nil?
            item["spec"]["strategy"]["type"] = resourceItem["spec"]["strategy"]["type"]
          end
          if !resourceItem["spec"]["replicas"].nil?
            item["spec"]["replicas"] = resourceItem["spec"]["replicas"]
          end
        end
        item["status"] = {}
        if !resourceItem["status"].nil?
          if !resourceItem["status"]["readyReplicas"].nil?
            item["status"]["readyReplicas"] = resourceItem["status"]["readyReplicas"]
          end
          if !resourceItem["status"]["updatedReplicas"].nil?
            item["status"]["updatedReplicas"] = resourceItem["status"]["updatedReplicas"]
          end
          if !resourceItem["status"]["availableReplicas"].nil?
            item["status"]["availableReplicas"] = resourceItem["status"]["availableReplicas"]
          end
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getDeploymentOptimizedItem:Failed with an error : #{errorStr}"
      end
      return item
    end

    def getHpaOptimizedItem(resourceItem)
      item = {}
      begin
        item["metadata"] = {}
        if !resourceItem["metadata"].nil?
          item["metadata"]["name"] = resourceItem["metadata"]["name"]
          item["metadata"]["namespace"] = resourceItem["metadata"]["namespace"]
          item["metadata"]["creationTimestamp"] = resourceItem["metadata"]["creationTimestamp"]
        end
        item["spec"] = {}
        if !resourceItem["spec"].nil?
          if !resourceItem["spec"]["minReplicas"].nil?
            item["spec"]["minReplicas"] = resourceItem["spec"]["minReplicas"]
          end
          if !resourceItem["spec"]["maxReplicas"].nil?
            item["spec"]["maxReplicas"] = resourceItem["spec"]["maxReplicas"]
          end
          item["spec"]["scaleTargetRef"] = {}
          if !resourceItem["spec"]["scaleTargetRef"].nil? && !resourceItem["spec"]["scaleTargetRef"]["kind"].nil?
            item["spec"]["scaleTargetRef"]["kind"] = resourceItem["spec"]["scaleTargetRef"]["kind"]
          end
          if !resourceItem["spec"]["scaleTargetRef"].nil? && !resourceItem["spec"]["scaleTargetRef"]["name"].nil?
            item["spec"]["scaleTargetRef"]["name"] = resourceItem["spec"]["scaleTargetRef"]["name"]
          end
        end
        item["status"] = {}
        if !resourceItem["status"].nil?
          if !resourceItem["status"]["currentReplicas"].nil?
            item["status"]["currentReplicas"] = resourceItem["status"]["currentReplicas"]
          end
          if !resourceItem["status"]["desiredReplicas"].nil?
            item["status"]["desiredReplicas"] = resourceItem["status"]["desiredReplicas"]
          end
          if !resourceItem["status"]["lastScaleTime"].nil?
            item["status"]["lastScaleTime"] = resourceItem["status"]["lastScaleTime"]
          end
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getHpaOptimizedItem:Failed with an error : #{errorStr}"
      end
      return item
    end

    def getPodReadyCondition(podStatusConditions, controllerKind, podStatus)
      podReadyCondition = false
      begin
        if !podStatusConditions.nil? && !podStatusConditions.empty?
          podStatusConditions.each do |condition|
            if condition["type"] == "Ready"
              if condition["status"].downcase == "true" || isCompletedJobPod(controllerKind, podStatus)
                podReadyCondition = true
              end
              break #Exit the for loop since we found the ready condition
            end
          end
        end
      rescue => err
        @Log.warn "in_kube_podinventory::getPodReadyCondition failed with an error: #{err}"
      end
      return podReadyCondition
    end

    def isCompletedJobPod(controllerKind, podStatus)
      isCompletedPod = false
      begin
        if !controllerKind.nil? && !controllerKind.empty? &&
           !podStatus.nil? && !podStatus.empty? &&
           controllerKind.downcase == Constants::CONTROLLER_KIND_JOB && podStatus == "Succeeded"
          isCompletedPod = true
        end
      rescue => error
        @Log.warn "in_kube_podinventory::isCompletedJobPod failed with an error: #{error}"
      end
      return isCompletedPod
    end

    def isEmitCacheTelemetry
      isEmitCacheTelemtryEnabled = false
      if !ENV["EMIT_CACHE_TELEMETRY"].nil? && !ENV["EMIT_CACHE_TELEMETRY"].empty? && ENV["EMIT_CACHE_TELEMETRY"].downcase == "true"
        isEmitCacheTelemtryEnabled = true
      end
      return isEmitCacheTelemtryEnabled
    end

    def isExcludeResourceItem(resourceName, resourceNamespace, namespaceFilteringMode, namespaces)
      isExclude = false
      begin
        if !resourceName.nil? && !resourceName.empty? && !resourceNamespace.nil? && !resourceNamespace.empty?
          # data collection namespace filtering not applicable for ama-logs agent as customer needs to monitor the agent
          if resourceName.start_with?("ama-logs") && resourceNamespace.eql?("kube-system")
            isExclude = false
          elsif !namespaces.nil? && !namespaces.empty? && namespaces.length > 0 && !namespaceFilteringMode.nil? && !namespaceFilteringMode.empty?
            if namespaceFilteringMode == "exclude" && namespaces.include?(resourceNamespace)
              isExclude = true
            elsif namespaceFilteringMode == "include" && !namespaces.include?(resourceNamespace)
              isExclude = true
            end
          end
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::isExcludeResourceItem:Failed with an error : #{errorStr}"
      end
      return isExclude
    end

    def isAddonResizerVPAEnabled
      isAddonResizerVPAEnabled = false
      if !ENV["RS_ADDON-RESIZER_VPA_ENABLED"].nil? && !ENV["RS_ADDON-RESIZER_VPA_ENABLED"].empty? && ENV["RS_ADDON-RESIZER_VPA_ENABLED"].downcase == "true".downcase
        isAddonResizerVPAEnabled = true
      end
      return isAddonResizerVPAEnabled
    end

    def sendReplicasetAgentRequestsAndLimitsTelemetry(podName, podNameSpace, containerName, metricName, metricValue)
      begin
        if (!podName.nil? && podName.downcase.start_with?("ama-logs-rs-") && podNameSpace.eql?("kube-system") && containerName.eql?("ama-logs"))
          telemetryProps = {}
          telemetryProps["Pod"] = podName
          telemetryProps["ContainerName"] = containerName
          case metricName
          when "cpuLimitNanoCores"
            timeDifference = (DateTime.now.to_time.to_i - @@cpuLimitsTelemetryTimeTracker).abs
            timeDifferenceInMinutes = timeDifference / 60
            if (timeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
              @@cpuLimitsTelemetryTimeTracker = DateTime.now.to_time.to_i
              ApplicationInsightsUtility.sendMetricTelemetry(metricName, metricValue, telemetryProps)
            end
          when "memoryLimitBytes"
            timeDifference = (DateTime.now.to_time.to_i - @@memoryLimitsTelemetryTimeTracker).abs
            timeDifferenceInMinutes = timeDifference / 60
            if (timeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
              @@memoryLimitsTelemetryTimeTracker = DateTime.now.to_time.to_i
              ApplicationInsightsUtility.sendMetricTelemetry(metricName, metricValue, telemetryProps)
            end
          when "cpuRequestNanoCores"
            timeDifference = (DateTime.now.to_time.to_i - @@cpuRequestsTelemetryTimeTracker).abs
            timeDifferenceInMinutes = timeDifference / 60
            if (timeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
              @@cpuRequestsTelemetryTimeTracker = DateTime.now.to_time.to_i
              ApplicationInsightsUtility.sendMetricTelemetry(metricName, metricValue, telemetryProps)
            end
          when "memoryRequestBytes"
            timeDifference = (DateTime.now.to_time.to_i - @@memoryRequestsTelemetryTimeTracker).abs
            timeDifferenceInMinutes = timeDifference / 60
            if (timeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
              @@memoryRequestsTelemetryTimeTracker = DateTime.now.to_time.to_i
              ApplicationInsightsUtility.sendMetricTelemetry(metricName, metricValue, telemetryProps)
            end
          end
        end
      rescue => err
        @Log.warn "KubernetesApiClient::sendReplicasetAgentRequestsAndLimitsTelemetry failed with an error: #{err}"
      end
    end

    def isDCRStreamIdTag(tag)
      return (!tag.nil? && tag.start_with?(Constants::EXTENSION_OUTPUT_STREAM_ID_TAG_PREFIX))
    end

    def getOutputStreamIdAndSource(datatype, tag, agentConfigRefreshTracker)
      fromCache = true
      begin
        if (!isDCRStreamIdTag(tag) || (DateTime.now.to_time.to_i - agentConfigRefreshTracker).abs >= Constants::AGENT_CONFIG_REFRESH_INTERVAL_SECONDS)
          fromCache = false
        end
        tag = ExtensionUtils.getOutputStreamId(datatype, fromCache)
      rescue => error
        @Log.warn "KubernetesApiClient::getOutputStreamIdAndSource failed with an error: #{error}"
      end
      return tag, fromCache
    end
  end
end
