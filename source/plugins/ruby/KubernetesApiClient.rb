#!/usr/local/bin/ruby
# frozen_string_literal: true

class KubernetesApiClient
  require "yajl/json_gem"
  require "logger"
  require "net/http"
  require "net/https"
  require "uri"
  require "time"

  require_relative "oms_common"
  require_relative "constants"

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
  @LogPath = "/var/opt/microsoft/docker-cimprov/log/kubernetes_client_log.txt"
  @Log = Logger.new(@LogPath, 2, 10 * 1048576) #keep last 2 files, max log file size = 10M
  @@TokenFileName = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  @@TokenStr = nil
  @@NodeMetrics = Hash.new
  @@WinNodeArray = []

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

    def getTokenStr
      return @@TokenStr if !@@TokenStr.nil?
      begin
        if File.exist?(@@TokenFileName) && File.readable?(@@TokenFileName)
          @@TokenStr = File.read(@@TokenFileName).strip
          return @@TokenStr
        else
          @Log.warn("Unable to read token string from #{@@TokenFileName}: #{error}")
          return nil
        end
      end
    end

    def getClusterRegion
      if ENV["AKS_REGION"]
        return ENV["AKS_REGION"]
      else
        @Log.warn ("Kubernetes environment variable not set AKS_REGION. Unable to get cluster region.")
        return nil
      end
    end

    def getResourceUri(resource, api_group)
      begin
        if ENV["KUBERNETES_SERVICE_HOST"] && ENV["KUBERNETES_PORT_443_TCP_PORT"]
          if api_group.nil?
            return "https://#{ENV["KUBERNETES_SERVICE_HOST"]}:#{ENV["KUBERNETES_PORT_443_TCP_PORT"]}/api/" + @@ApiVersion + "/" + resource
          elsif api_group == @@ApiGroupApps
            return "https://#{ENV["KUBERNETES_SERVICE_HOST"]}:#{ENV["KUBERNETES_PORT_443_TCP_PORT"]}/apis/apps/" + @@ApiVersionApps + "/" + resource
          elsif api_group == @@ApiGroupHPA
            return "https://#{ENV["KUBERNETES_SERVICE_HOST"]}:#{ENV["KUBERNETES_PORT_443_TCP_PORT"]}/apis/" + @@ApiGroupHPA + "/" + @@ApiVersionHPA + "/" + resource
          end
        else
          @Log.warn ("Kubernetes environment variable not set KUBERNETES_SERVICE_HOST: #{ENV["KUBERNETES_SERVICE_HOST"]} KUBERNETES_PORT_443_TCP_PORT: #{ENV["KUBERNETES_PORT_443_TCP_PORT"]}. Unable to form resourceUri")
          return nil
        end
      end
    end

    def getClusterName
      return @@ClusterName if !@@ClusterName.nil?
      @@ClusterName = "None"
      begin
        #try getting resource ID for aks
        cluster = ENV["AKS_RESOURCE_ID"]
        if cluster && !cluster.nil? && !cluster.empty?
          @@ClusterName = cluster.split("/").last
        else
          cluster = ENV["ACS_RESOURCE_NAME"]
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

    def getClusterId
      return @@ClusterId if !@@ClusterId.nil?
      #By default initialize ClusterId to ClusterName.
      #<TODO> In ACS/On-prem, we need to figure out how we can generate ClusterId
      # Dilipr: Spoof the subid by generating md5 hash of cluster name, and taking some constant parts of it.
      # e.g. md5 digest is 128 bits = 32 character in hex. Get first 16 and get a guid, and the next 16 to get resource id
      @@ClusterId = getClusterName
      begin
        cluster = ENV["AKS_RESOURCE_ID"]
        if cluster && !cluster.nil? && !cluster.empty?
          @@ClusterId = cluster
        end
      rescue => error
        @Log.warn("getClusterId failed: #{error}")
      end
      return @@ClusterId
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
        resourceUri = getNodesResourceUri("nodes")
        nodeInventory = JSON.parse(getKubeResourceInfo(resourceUri).body)
        @Log.info "KubernetesAPIClient::getWindowsNodes : Got nodes from kube api"
        # Resetting the windows node cache
        @@WinNodeArray.clear
        if (!nodeInventory.empty?)
          nodeInventory["items"].each do |item|
            # check for windows operating system in node metadata
            winNode = {}
            nodeStatus = item["status"]
            nodeMetadata = item["metadata"]
            if !nodeStatus.nil? && !nodeStatus["nodeInfo"].nil? && !nodeStatus["nodeInfo"]["operatingSystem"].nil?
              operatingSystem = nodeStatus["nodeInfo"]["operatingSystem"]
              if (operatingSystem.is_a?(String) && operatingSystem.casecmp("windows") == 0)
                # Adding windows nodes to winNodeArray so that it can be used in kubepodinventory to send ContainerInventory data
                # to get images and image tags for containers in windows nodes
                if !nodeMetadata.nil? && !nodeMetadata["name"].nil?
                  @@WinNodeArray.push(nodeMetadata["name"])
                end
                nodeStatusAddresses = nodeStatus["addresses"]
                if !nodeStatusAddresses.nil?
                  nodeStatusAddresses.each do |address|
                    winNode[address["type"]] = address["address"]
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
      return @@WinNodeArray
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

    def getContainerResourceRequestsAndLimits(metricJSON, metricCategory, metricNameToCollect, metricNametoReturn, metricTime = Time.now.utc.iso8601)
      metricItems = []
      begin
        clusterId = getClusterId
        metricInfo = metricJSON
        metricInfo["items"].each do |pod|
          podNameSpace = pod["metadata"]["namespace"]
          podUid = getPodUid(podNameSpace, pod["metadata"])
          if podUid.nil?
            next
          end

          # For ARO, skip the pods scheduled on to master or infra nodes to ingest
          if isAROV3Cluster() && !pod["spec"].nil? && !pod["spec"]["nodeName"].nil? &&
             (pod["spec"]["nodeName"].downcase.start_with?("infra-") ||
              pod["spec"]["nodeName"].downcase.start_with?("master-"))
            next
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
            nodeName = pod["spec"]["nodeName"]
            podContainers.each do |container|
              containerName = container["name"]
              #metricTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z
              if (!container["resources"].nil? && !container["resources"].empty? && !container["resources"][metricCategory].nil? && !container["resources"][metricCategory][metricNameToCollect].nil?)
                metricValue = getMetricNumericValue(metricNameToCollect, container["resources"][metricCategory][metricNameToCollect])

                metricItem = {}
                metricItem["DataItems"] = []

                metricProps = {}
                metricProps["Timestamp"] = metricTime
                metricProps["Host"] = nodeName
                # Adding this so that it is not set by base omsagent since it was not set earlier and being set by base omsagent
                metricProps["Computer"] = nodeName
                metricProps["ObjectName"] = "K8SContainer"
                metricProps["InstanceName"] = clusterId + "/" + podUid + "/" + containerName

                metricProps["Collections"] = []
                metricCollections = {}
                metricCollections["CounterName"] = metricNametoReturn
                metricCollections["Value"] = metricValue

                metricProps["Collections"].push(metricCollections)
                metricItem["DataItems"].push(metricProps)
                metricItems.push(metricItem)
                #No container level limit for the given metric, so default to node level limit
              else
                nodeMetricsHashKey = clusterId + "/" + nodeName + "_" + "allocatable" + "_" + metricNameToCollect
                if (metricCategory == "limits" && @@NodeMetrics.has_key?(nodeMetricsHashKey))
                  metricValue = @@NodeMetrics[nodeMetricsHashKey]
                  #@Log.info("Limits not set for container #{clusterId + "/" + podUid + "/" + containerName} using node level limits: #{nodeMetricsHashKey}=#{metricValue} ")
                  metricItem = {}
                  metricItem["DataItems"] = []

                  metricProps = {}
                  metricProps["Timestamp"] = metricTime
                  metricProps["Host"] = nodeName
                  # Adding this so that it is not set by base omsagent since it was not set earlier and being set by base omsagent
                  metricProps["Computer"] = nodeName
                  metricProps["ObjectName"] = "K8SContainer"
                  metricProps["InstanceName"] = clusterId + "/" + podUid + "/" + containerName

                  metricProps["Collections"] = []
                  metricCollections = {}
                  metricCollections["CounterName"] = metricNametoReturn
                  metricCollections["Value"] = metricValue

                  metricProps["Collections"].push(metricCollections)
                  metricItem["DataItems"].push(metricProps)
                  metricItems.push(metricItem)
                end
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

    def getContainerResourceRequestsAndLimitsAsInsightsMetrics(metricJSON, metricCategory, metricNameToCollect, metricNametoReturn, metricTime = Time.now.utc.iso8601)
      metricItems = []
      begin
        clusterId = getClusterId
        clusterName = getClusterName

        metricInfo = metricJSON
        metricInfo["items"].each do |pod|
          podNameSpace = pod["metadata"]["namespace"]
          if podNameSpace.eql?("kube-system") && !pod["metadata"].key?("ownerReferences")
            # The above case seems to be the only case where you have horizontal scaling of pods
            # but no controller, in which case cAdvisor picks up kubernetes.io/config.hash
            # instead of the actual poduid. Since this uid is not being surface into the UX
            # its ok to use this.
            # Use kubernetes.io/config.hash to be able to correlate with cadvisor data
            if pod["metadata"]["annotations"].nil?
              next
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
                  nodeMetricsHashKey = clusterId + "/" + nodeName + "_" + "allocatable" + "_" + metricNameToCollect
                  metricValue = @@NodeMetrics[nodeMetricsHashKey]
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
          if (!node["status"][metricCategory].nil?)

            # metricCategory can be "capacity" or "allocatable" and metricNameToCollect can be "cpu" or "memory"
            metricValue = getMetricNumericValue(metricNameToCollect, node["status"][metricCategory][metricNameToCollect])

            metricItem = {}
            metricItem["DataItems"] = []
            metricProps = {}
            metricProps["Timestamp"] = metricTime
            metricProps["Host"] = node["metadata"]["name"]
            # Adding this so that it is not set by base omsagent since it was not set earlier and being set by base omsagent
            metricProps["Computer"] = node["metadata"]["name"]
            metricProps["ObjectName"] = "K8SNode"
            metricProps["InstanceName"] = clusterId + "/" + node["metadata"]["name"]
            metricProps["Collections"] = []
            metricCollections = {}
            metricCollections["CounterName"] = metricNametoReturn
            metricCollections["Value"] = metricValue

            metricProps["Collections"].push(metricCollections)
            metricItem["DataItems"].push(metricProps)
            metricItems.push(metricItem)
            #push node level metrics to a inmem hash so that we can use it looking up at container level.
            #Currently if container level cpu & memory limits are not defined we default to node level limits
            @@NodeMetrics[clusterId + "/" + node["metadata"]["name"] + "_" + metricCategory + "_" + metricNameToCollect] = metricValue
            #@Log.info ("Node metric hash: #{@@NodeMetrics}")
          end
        end
      rescue => error
        @Log.warn("parseNodeLimits failed: #{error} for metric #{metricCategory} #{metricNameToCollect}")
      end
      return metricItems
    end #parseNodeLimits

    def parseNodeLimitsAsInsightsMetrics(metricJSON, metricCategory, metricNameToCollect, metricNametoReturn, metricTime = Time.now.utc.iso8601)
      metricItems = []
      begin
        metricInfo = metricJSON
        clusterId = getClusterId
        clusterName = getClusterName
        #Since we are getting all node data at the same time and kubernetes doesnt specify a timestamp for the capacity and allocation metrics,
        #if we are coming up with the time it should be same for all nodes
        #metricTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z
        metricInfo["items"].each do |node|
          if (!node["status"][metricCategory].nil?) && (!node["status"][metricCategory][metricNameToCollect].nil?)

            # metricCategory can be "capacity" or "allocatable" and metricNameToCollect can be "cpu" or "memory" or "amd.com/gpu" or "nvidia.com/gpu"
            metricValue = getMetricNumericValue(metricNameToCollect, node["status"][metricCategory][metricNameToCollect])

            metricItem = {}
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

            metricItems.push(metricItem)
            #push node level metrics (except gpu ones) to a inmem hash so that we can use it looking up at container level.
            #Currently if container level cpu & memory limits are not defined we default to node level limits
            if (metricNameToCollect.downcase != "nvidia.com/gpu") && (metricNameToCollect.downcase != "amd.com/gpu")
              @@NodeMetrics[clusterId + "/" + node["metadata"]["name"] + "_" + metricCategory + "_" + metricNameToCollect] = metricValue
              #@Log.info ("Node metric hash: #{@@NodeMetrics}")
            end
          end
        end
      rescue => error
        @Log.warn("parseNodeLimitsAsInsightsMetrics failed: #{error} for metric #{metricCategory} #{metricNameToCollect}")
      end
      return metricItems
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
            metricValue.chomp!("m")
            metricValue = Float(metricValue) * 1000.0 ** 2
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

    def getResourcesAndContinuationToken(uri, api_group: nil)
      continuationToken = nil
      resourceInventory = nil
      begin
        @Log.info "KubernetesApiClient::getResourcesAndContinuationToken : Getting resources from Kube API using url: #{uri} @ #{Time.now.utc.iso8601}"
        resourceInfo = getKubeResourceInfo(uri, api_group: api_group)
        @Log.info "KubernetesApiClient::getResourcesAndContinuationToken : Done getting resources from Kube API using url: #{uri} @ #{Time.now.utc.iso8601}"
        if !resourceInfo.nil?
          @Log.info "KubernetesApiClient::getResourcesAndContinuationToken:Start:Parsing data for #{uri} using yajl @ #{Time.now.utc.iso8601}"
          resourceInventory = Yajl::Parser.parse(StringIO.new(resourceInfo.body))
          @Log.info "KubernetesApiClient::getResourcesAndContinuationToken:End:Parsing data for #{uri} using yajl @ #{Time.now.utc.iso8601}"
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

    def getKubeAPIServerUrl
      apiServerUrl = nil
      begin
        if ENV["KUBERNETES_SERVICE_HOST"] && ENV["KUBERNETES_PORT_443_TCP_PORT"]
          apiServerUrl = "https://#{ENV["KUBERNETES_SERVICE_HOST"]}:#{ENV["KUBERNETES_PORT_443_TCP_PORT"]}"
        else
          @Log.warn "Kubernetes environment variable not set KUBERNETES_SERVICE_HOST: #{ENV["KUBERNETES_SERVICE_HOST"]} KUBERNETES_PORT_443_TCP_PORT: #{ENV["KUBERNETES_PORT_443_TCP_PORT"]}. Unable to form resourceUri"
        end
      rescue => errorStr
        @Log.warn "KubernetesApiClient::getKubeAPIServerUrl:Failed  #{errorStr}"
      end
      return apiServerUrl
    end
  end
end
