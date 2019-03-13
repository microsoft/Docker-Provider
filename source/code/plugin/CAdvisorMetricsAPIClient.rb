#!/usr/local/bin/ruby
# frozen_string_literal: true

class CAdvisorMetricsAPIClient
  require "json"
  require "logger"
  require "net/http"
  require "net/https"
  require "uri"
  require "date"

  require_relative "oms_common"
  require_relative "KubernetesApiClient"
  require_relative "ApplicationInsightsUtility"

  @LogPath = "/var/opt/microsoft/docker-cimprov/log/kubernetes_perf_log.txt"
  @Log = Logger.new(@LogPath, 2, 10 * 1048576) #keep last 2 files, max log file size = 10M
  #   @@rxBytesLast = nil
  #   @@rxBytesTimeLast = nil
  #   @@txBytesLast = nil
  #   @@txBytesTimeLast = nil
  @@nodeCpuUsageNanoSecondsLast = nil
  @@nodeCpuUsageNanoSecondsTimeLast = nil
  @@winNodeCpuUsageNanoSecondsLast = {}
  @@winNodeCpuUsageNanoSecondsTimeLast = {}
  @@winContainerCpuUsageNanoSecondsLast = {}
  @@winContainerCpuUsageNanoSecondsTimeLast = {}
  @@telemetryCpuMetricTimeTracker = DateTime.now.to_time.to_i
  @@telemetryMemoryMetricTimeTracker = DateTime.now.to_time.to_i

  def initialize
  end

  class << self
    def getSummaryStatsFromCAdvisor(winNode)
      headers = {}
      response = nil
      @Log.info "Getting CAdvisor Uri"
      begin
        cAdvisorUri = getCAdvisorUri(winNode)
        if !cAdvisorUri.nil?
          uri = URI.parse(cAdvisorUri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = false

          cAdvisorApiRequest = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(cAdvisorApiRequest)
          @Log.info "Got response code #{response.code} from #{uri.request_uri}"
        end
      rescue => error
        @Log.warn("CAdvisor api request failed: #{error}")
      end
      return response
    end

    def getCAdvisorUri(winNode)
      begin
        defaultHost = "http://localhost:10255"
        relativeUri = "/stats/summary"
        if !winNode.nil?
          nodeIP = winNode["InternalIP"]
        else
          nodeIP = ENV["NODE_IP"]
        end
        if !nodeIP.nil?
          @Log.info("Using #{nodeIP + relativeUri} for CAdvisor Uri")
          return "http://#{nodeIP}:10255" + relativeUri
        else
          @Log.warn ("NODE_IP environment variable not set. Using default as : #{defaultHost + relativeUri} ")
          if !winNode.nil?
            return nil
          else
            return defaultHost + relativeUri
          end
        end
      end
    end

    def getMetrics(winNode = nil)
      metricDataItems = []
      begin
        if !winNode.nil?
          hostName = winNode["Hostname"]
          operatingSystem = "Windows"
        else
          hostName = (OMS::Common.get_hostname)
          operatingSystem = "Linux"
        end
        metricInfo = JSON.parse(getSummaryStatsFromCAdvisor(winNode).body)
        #@Log.info "metric info: #{metricInfo}"
        if !metricInfo.nil?
          metricDataItems.concat(getContainerMemoryMetricItems(metricInfo, hostName, "workingSetBytes", "memoryWorkingSetBytes"))
          metricDataItems.concat(getContainerMemoryMetricItems(metricInfo, hostName, "rssBytes", "memoryRssBytes"))
          metricDataItems.concat(getContainerStartTimeMetricItems(metricInfo, hostName, "restartTimeEpoch"))

          if operatingSystem == "Linux"
            metricDataItems.concat(getContainerCpuMetricItems(metricInfo, hostName, "usageNanoCores", "cpuUsageNanoCores"))
          elsif operatingSystem == "Windows"
            containerCpuUsageNanoSecondsRate = getContainerCpuMetricItemRate(metricInfo, hostName, "usageCoreNanoSeconds", "cpuUsageNanoCores")
            if containerCpuUsageNanoSecondsRate && !containerCpuUsageNanoSecondsRate.empty? && !containerCpuUsageNanoSecondsRate.nil?
              metricDataItems.push(containerCpuUsageNanoSecondsRate)
            end
          end

          cpuUsageNanoSecondsRate = getNodeMetricItemRate(metricInfo, hostName, "cpu", "usageCoreNanoSeconds", "cpuUsageNanoCores", operatingSystem)
          if cpuUsageNanoSecondsRate && !cpuUsageNanoSecondsRate.empty? && !cpuUsageNanoSecondsRate.nil?
            metricDataItems.push(cpuUsageNanoSecondsRate)
          end
          metricDataItems.push(getNodeMetricItem(metricInfo, hostName, "memory", "workingSetBytes", "memoryWorkingSetBytes"))
          metricDataItems.push(getNodeMetricItem(metricInfo, hostName, "memory", "rssBytes", "memoryRssBytes"))

          metricDataItems.push(getNodeLastRebootTimeMetric(metricInfo, hostName, "restartTimeEpoch"))

          # Disabling networkRxRate and networkTxRate since we dont use it as of now.
          #metricDataItems.push(getNodeMetricItem(metricInfo, hostName, "network", "rxBytes", "networkRxBytes"))
          #metricDataItems.push(getNodeMetricItem(metricInfo, hostName, "network", "txBytes", "networkTxBytes"))
          #   networkRxRate = getNodeMetricItemRate(metricInfo, hostName, "network", "rxBytes", "networkRxBytesPerSec")
          #   if networkRxRate && !networkRxRate.empty? && !networkRxRate.nil?
          #     metricDataItems.push(networkRxRate)
          #   end
          #   networkTxRate = getNodeMetricItemRate(metricInfo, hostName, "network", "txBytes", "networkTxBytesPerSec")
          #   if networkTxRate && !networkTxRate.empty? && !networkTxRate.nil?
          #     metricDataItems.push(networkTxRate)
          #   end
        else
          @Log.warn("Couldn't get metric information for host: #{hostName}")
        end
      rescue => error
        @Log.warn("getContainerMetrics failed: #{error}")
        return metricDataItems
      end
      return metricDataItems
    end

    def getContainerCpuMetricItems(metricJSON, hostName, cpuMetricNameToCollect, metricNametoReturn)
      metricItems = []
      clusterId = KubernetesApiClient.getClusterId
      timeDifference = (DateTime.now.to_time.to_i - @@telemetryCpuMetricTimeTracker).abs
      timeDifferenceInMinutes = timeDifference / 60
      begin
        metricInfo = metricJSON
        metricInfo["pods"].each do |pod|
          podUid = pod["podRef"]["uid"]
          podName = pod["podRef"]["name"]
          podNamespace = pod["podRef"]["namespace"]

          if (!pod["containers"].nil?)
            pod["containers"].each do |container|
              #cpu metric
              containerName = container["name"]
              metricValue = container["cpu"][cpuMetricNameToCollect]
              metricTime = container["cpu"]["time"]
              metricItem = {}
              metricItem["DataItems"] = []

              metricProps = {}
              metricProps["Timestamp"] = metricTime
              metricProps["Host"] = hostName
              metricProps["ObjectName"] = "K8SContainer"
              metricProps["InstanceName"] = clusterId + "/" + podUid + "/" + containerName

              metricProps["Collections"] = []
              metricCollections = {}
              metricCollections["CounterName"] = metricNametoReturn
              metricCollections["Value"] = metricValue

              metricProps["Collections"].push(metricCollections)
              metricItem["DataItems"].push(metricProps)
              metricItems.push(metricItem)
              #Telemetry about agent performance
              begin
                # we can only do this much now. Ideally would like to use the docker image repository to find our pods/containers
                # cadvisor does not have pod/container metadata. so would need more work to cache as pv & use
                if (podName.downcase.start_with?("omsagent-") && podNamespace.eql?("kube-system") && containerName.downcase.start_with?("omsagent") && metricNametoReturn.eql?("cpuUsageNanoCores"))
                  if (timeDifferenceInMinutes >= 10)
                    telemetryProps = {}
                    telemetryProps["PodName"] = podName
                    telemetryProps["ContainerName"] = containerName
                    ApplicationInsightsUtility.sendMetricTelemetry(metricNametoReturn, metricValue, telemetryProps)
                  end
                end
              rescue => errorStr
                $log.warn("Exception while generating Telemetry from getcontainerCpuMetricItems failed: #{errorStr} for metric #{cpuMetricNameToCollect}")
              end
            end
          end
        end
        # reset time outside pod iterator as we use one timer per metric for 2 pods (ds & rs)
        if (timeDifferenceInMinutes >= 10 && metricNametoReturn.eql?("cpuUsageNanoCores"))
          @@telemetryCpuMetricTimeTracker = DateTime.now.to_time.to_i
        end
      rescue => error
        @Log.warn("getcontainerCpuMetricItems failed: #{error} for metric #{cpuMetricNameToCollect}")
        return metricItems
      end
      return metricItems
    end

    # usageNanoCores doesnt exist for windows nodes. Hence need to compute this from usageCoreNanoSeconds
    def getContainerCpuMetricItemRate(metricJSON, hostName, cpuMetricNameToCollect, metricNametoReturn)
      metricItems = []
      clusterId = KubernetesApiClient.getClusterId
      timeDifference = (DateTime.now.to_time.to_i - @@telemetryCpuMetricTimeTracker).abs
      timeDifferenceInMinutes = timeDifference / 60
      begin
        metricInfo = metricJSON
        metricInfo["pods"].each do |pod|
          podUid = pod["podRef"]["uid"]
          podName = pod["podRef"]["name"]
          podNamespace = pod["podRef"]["namespace"]

          if (!pod["containers"].nil?)
            pod["containers"].each do |container|
              #cpu metric
              containerName = container["name"]
              metricValue = container["cpu"][cpuMetricNameToCollect]
              metricTime = container["cpu"]["time"]
              metricItem = {}
              metricItem["DataItems"] = []

              metricProps = {}
              metricProps["Timestamp"] = metricTime
              metricProps["Host"] = hostName
              metricProps["ObjectName"] = "K8SContainer"
              metricProps["InstanceName"] = clusterId + "/" + podUid + "/" + containerName

              metricProps["Collections"] = []
              metricCollections = {}
              metricCollections["CounterName"] = metricNametoReturn

              containerId = podUid + "/" + containerName
              if @@winContainerCpuUsageNanoSecondsLast[containerId].nil? || @@winContainerCpuUsageNanoSecondsTimeLast[containerId].nil? || @@winContainerCpuUsageNanoSecondsLast[containerId] > metricValue #when kubelet is restarted the last condition will be true
                @@winContainerCpuUsageNanoSecondsLast[containerId] = metricValue
                @@winContainerCpuUsageNanoSecondsTimeLast[containerId] = metricTime
                @Log.info "In condition 1"
                @Log.info "metricValue :#{metricValue}"
                @Log.info "metricTime :#{metricTime}"
                return nil
              else
                metricRateValue = ((metricValue - @@winContainerCpuUsageNanoSecondsLast[containerId]) * 1.0) / (DateTime.parse(metricTime).to_time - DateTime.parse(@@winContainerCpuUsageNanoSecondsTimeLast[containerId]).to_time)
                @Log.info "In condition 2"
                @Log.info "metricValue :#{metricValue}"
                @Log.info "@@winContainerCpuUsageNanoSecondsLast[#{containerId}]: #{@@winContainerCpuUsageNanoSecondsLast[containerId]}"
                @Log.info "metricTime :#{metricTime}"
                @Log.info "DateTime.parse(metricTime).to_time: #{DateTime.parse(metricTime).to_time}"
                @Log.info "@@winContainerCpuUsageNanoSecondsTimeLast[#{containerId}]: #{@@winContainerCpuUsageNanoSecondsTimeLast[containerId]}"
                @Log.info "DateTime.parse(@@winContainerCpuUsageNanoSecondsTimeLast[#{containerId}].to_time: #{DateTime.parse(@@winContainerCpuUsageNanoSecondsTimeLast[containerId]).to_time}"
                @Log.info "metricRateValue: #{metricRateValue}"
                @@winContainerCpuUsageNanoSecondsLast[containerId] = metricValue
                @@winContainerCpuUsageNanoSecondsTimeLast[containerId] = metricTime
                metricValue = metricRateValue
              end

              metricCollections["Value"] = metricValue

              metricProps["Collections"].push(metricCollections)
              metricItem["DataItems"].push(metricProps)
              metricItems.push(metricItem)
              #Telemetry about agent performance
              begin
                # we can only do this much now. Ideally would like to use the docker image repository to find our pods/containers
                # cadvisor does not have pod/container metadata. so would need more work to cache as pv & use
                if (podName.downcase.start_with?("omsagent-") && podNamespace.eql?("kube-system") && containerName.downcase.start_with?("omsagent") && metricNametoReturn.eql?("cpuUsageNanoCores"))
                  if (timeDifferenceInMinutes >= 10)
                    telemetryProps = {}
                    telemetryProps["PodName"] = podName
                    telemetryProps["ContainerName"] = containerName
                    ApplicationInsightsUtility.sendMetricTelemetry(metricNametoReturn, metricValue, telemetryProps)
                  end
                end
              rescue => errorStr
                $log.warn("Exception while generating Telemetry from getcontainerCpuMetricItems failed: #{errorStr} for metric #{cpuMetricNameToCollect}")
              end
            end
          end
        end
        # reset time outside pod iterator as we use one timer per metric for 2 pods (ds & rs)
        if (timeDifferenceInMinutes >= 10 && metricNametoReturn.eql?("cpuUsageNanoCores"))
          @@telemetryCpuMetricTimeTracker = DateTime.now.to_time.to_i
        end
      rescue => error
        @Log.warn("getcontainerCpuMetricItemRate failed: #{error} for metric #{cpuMetricNameToCollect}")
        return metricItems
      end
      return metricItems
    end

    def getContainerMemoryMetricItems(metricJSON, hostName, memoryMetricNameToCollect, metricNametoReturn)
      metricItems = []
      clusterId = KubernetesApiClient.getClusterId
      timeDifference = (DateTime.now.to_time.to_i - @@telemetryMemoryMetricTimeTracker).abs
      timeDifferenceInMinutes = timeDifference / 60
      begin
        metricInfo = metricJSON
        metricInfo["pods"].each do |pod|
          podUid = pod["podRef"]["uid"]
          podName = pod["podRef"]["name"]
          podNamespace = pod["podRef"]["namespace"]
          if (!pod["containers"].nil?)
            pod["containers"].each do |container|
              containerName = container["name"]
              metricValue = container["memory"][memoryMetricNameToCollect]
              metricTime = container["memory"]["time"]

              metricItem = {}
              metricItem["DataItems"] = []

              metricProps = {}
              metricProps["Timestamp"] = metricTime
              metricProps["Host"] = hostName
              metricProps["ObjectName"] = "K8SContainer"
              metricProps["InstanceName"] = clusterId + "/" + podUid + "/" + containerName

              metricProps["Collections"] = []
              metricCollections = {}
              metricCollections["CounterName"] = metricNametoReturn
              metricCollections["Value"] = metricValue

              metricProps["Collections"].push(metricCollections)
              metricItem["DataItems"].push(metricProps)
              metricItems.push(metricItem)
              #Telemetry about agent performance
              begin
                # we can only do this much now. Ideally would like to use the docker image repository to find our pods/containers
                # cadvisor does not have pod/container metadata. so would need more work to cache as pv & use
                if (podName.downcase.start_with?("omsagent-") && podNamespace.eql?("kube-system") && containerName.downcase.start_with?("omsagent") && metricNametoReturn.eql?("memoryRssBytes"))
                  if (timeDifferenceInMinutes >= 10)
                    telemetryProps = {}
                    telemetryProps["PodName"] = podName
                    telemetryProps["ContainerName"] = containerName
                    ApplicationInsightsUtility.sendMetricTelemetry(metricNametoReturn, metricValue, telemetryProps)
                  end
                end
              rescue => errorStr
                $log.warn("Exception while generating Telemetry from getcontainerMemoryMetricItems failed: #{errorStr} for metric #{memoryMetricNameToCollect}")
              end
            end
          end
        end
        # reset time outside pod iterator as we use one timer per metric for 2 pods (ds & rs)
        if (timeDifferenceInMinutes >= 10 && metricNametoReturn.eql?("memoryRssBytes"))
          @@telemetryMemoryMetricTimeTracker = DateTime.now.to_time.to_i
        end
      rescue => error
        @Log.warn("getcontainerMemoryMetricItems failed: #{error} for metric #{memoryMetricNameToCollect}")
        @Log.warn metricJSON
        return metricItems
      end
      return metricItems
    end

    def getNodeMetricItem(metricJSON, hostName, metricCategory, metricNameToCollect, metricNametoReturn)
      metricItem = {}
      clusterId = KubernetesApiClient.getClusterId
      begin
        metricInfo = metricJSON
        node = metricInfo["node"]
        nodeName = node["nodeName"]

        if !node[metricCategory].nil?
          metricValue = node[metricCategory][metricNameToCollect]
          metricTime = node[metricCategory]["time"]

          metricItem["DataItems"] = []

          metricProps = {}
          metricProps["Timestamp"] = metricTime
          metricProps["Host"] = hostName
          metricProps["ObjectName"] = "K8SNode"
          metricProps["InstanceName"] = clusterId + "/" + nodeName

          metricProps["Collections"] = []
          metricCollections = {}
          metricCollections["CounterName"] = metricNametoReturn
          metricCollections["Value"] = metricValue

          metricProps["Collections"].push(metricCollections)
          metricItem["DataItems"].push(metricProps)
        end
      rescue => error
        @Log.warn("getNodeMetricItem failed: #{error} for metric #{metricNameToCollect}")
        @Log.warn metricJSON
        return metricItem
      end
      return metricItem
    end

    def getNodeMetricItemRate(metricJSON, hostName, metricCategory, metricNameToCollect, metricNametoReturn, operatingSystem)
      metricItem = {}
      clusterId = KubernetesApiClient.getClusterId
      begin
        metricInfo = metricJSON
        node = metricInfo["node"]
        nodeName = node["nodeName"]

        if !node[metricCategory].nil?
          metricValue = node[metricCategory][metricNameToCollect]
          metricTime = node[metricCategory]["time"]

          #   if !(metricNameToCollect == "rxBytes" || metricNameToCollect == "txBytes" || metricNameToCollect == "usageCoreNanoSeconds")
          #     @Log.warn("getNodeMetricItemRate : rateMetric is supported only for rxBytes, txBytes & usageCoreNanoSeconds and not for #{metricNameToCollect}")
          if !(metricNameToCollect == "usageCoreNanoSeconds")
            @Log.warn("getNodeMetricItemRate : rateMetric is supported only for usageCoreNanoSeconds and not for #{metricNameToCollect}")
            return nil
            #   elsif metricNameToCollect == "rxBytes"
            #     if @@rxBytesLast.nil? || @@rxBytesTimeLast.nil? || @@rxBytesLast > metricValue #when kubelet is restarted the last condition will be true
            #       @@rxBytesLast = metricValue
            #       @@rxBytesTimeLast = metricTime
            #       return nil
            #     else
            #       metricRateValue = ((metricValue - @@rxBytesLast) * 1.0) / (DateTime.parse(metricTime).to_time - DateTime.parse(@@rxBytesTimeLast).to_time)
            #       @@rxBytesLast = metricValue
            #       @@rxBytesTimeLast = metricTime
            #       metricValue = metricRateValue
            #     end
            #   elsif metricNameToCollect == "txBytes"
            #     if @@txBytesLast.nil? || @@txBytesTimeLast.nil? || @@txBytesLast > metricValue #when kubelet is restarted the last condition will be true
            #       @@txBytesLast = metricValue
            #       @@txBytesTimeLast = metricTime
            #       return nil
            #     else
            #       metricRateValue = ((metricValue - @@txBytesLast) * 1.0) / (DateTime.parse(metricTime).to_time - DateTime.parse(@@txBytesTimeLast).to_time)
            #       @@txBytesLast = metricValue
            #       @@txBytesTimeLast = metricTime
            #       metricValue = metricRateValue
            #     end
          else
            if operatingSystem == "Linux"
              if @@nodeCpuUsageNanoSecondsLast.nil? || @@nodeCpuUsageNanoSecondsTimeLast.nil? || @@nodeCpuUsageNanoSecondsLast > metricValue #when kubelet is restarted the last condition will be true
                @@nodeCpuUsageNanoSecondsLast = metricValue
                @@nodeCpuUsageNanoSecondsTimeLast = metricTime
                return nil
              else
                metricRateValue = ((metricValue - @@nodeCpuUsageNanoSecondsLast) * 1.0) / (DateTime.parse(metricTime).to_time - DateTime.parse(@@nodeCpuUsageNanoSecondsTimeLast).to_time)
                @@nodeCpuUsageNanoSecondsLast = metricValue
                @@nodeCpuUsageNanoSecondsTimeLast = metricTime
                metricValue = metricRateValue
              end
            elsif operatingSystem == "Windows"
              # Using the hash for windows nodes since this is running in replica set and there can be multiple nodes
              if @@winNodeCpuUsageNanoSecondsLast[hostName].nil? || @@winNodeCpuUsageNanoSecondsTimeLast[hostName].nil? || @@winNodeCpuUsageNanoSecondsLast[hostName] > metricValue #when kubelet is restarted the last condition will be true
                @@winNodeCpuUsageNanoSecondsLast[hostName] = metricValue
                @@winNodeCpuUsageNanoSecondsTimeLast[hostName] = metricTime
                # @Log.info "@@winNodeCpuUsageNanoSecondsLast[#{hostName}]: #{@@winNodeCpuUsageNanoSecondsLast[hostName]}"
                # @Log.info "@@winNodeCpuUsageNanoSecondsLast[#{hostName}]: #{@@winNodeCpuUsageNanoSecondsLast[hostName]}"
                # @Log.info "In condition 1"
                # @Log.info "metricValue :#{metricValue}"
                # @Log.info "metricTime :#{metricTime}"
                return nil
              else
                metricRateValue = ((metricValue - @@winNodeCpuUsageNanoSecondsLast[hostName]) * 1.0) / (DateTime.parse(metricTime).to_time - DateTime.parse(@@winNodeCpuUsageNanoSecondsTimeLast[hostName]).to_time)
                # @Log.info "In condition 2"
                # @Log.info "metricValue :#{metricValue}"
                # @Log.info "@@winNodeCpuUsageNanoSecondsLast[#{hostName}]: #{@@winNodeCpuUsageNanoSecondsLast[hostName]}"
                # @Log.info "metricTime :#{metricTime}"
                # @Log.info "DateTime.parse(metricTime).to_time: #{DateTime.parse(metricTime).to_time}"
                # @Log.info "@@winNodeCpuUsageNanoSecondsTimeLast[#{hostName}]: #{@@winNodeCpuUsageNanoSecondsTimeLast[hostName]}"
                # @Log.info "DateTime.parse(@@winNodeCpuUsageNanoSecondsTimeLast[#{hostName}].to_time: #{DateTime.parse(@@winNodeCpuUsageNanoSecondsTimeLast[hostName]).to_time}"
                # @Log.info "metricRateValue: #{metricRateValue}"
                @@winNodeCpuUsageNanoSecondsLast[hostName] = metricValue
                @@winNodeCpuUsageNanoSecondsTimeLast[hostName] = metricTime
                metricValue = metricRateValue
              end
            end
          end
          metricItem["DataItems"] = []

          metricProps = {}
          metricProps["Timestamp"] = metricTime
          metricProps["Host"] = hostName
          metricProps["ObjectName"] = "K8SNode"
          metricProps["InstanceName"] = clusterId + "/" + nodeName

          metricProps["Collections"] = []
          metricCollections = {}
          metricCollections["CounterName"] = metricNametoReturn
          metricCollections["Value"] = metricValue

          metricProps["Collections"].push(metricCollections)
          metricItem["DataItems"].push(metricProps)
        end
      rescue => error
        @Log.warn("getNodeMetricItemRate failed: #{error} for metric #{metricNameToCollect}")
        @Log.warn metricJSON
        return nil
      end
      return metricItem
    end

    def getNodeLastRebootTimeMetric(metricJSON, hostName, metricNametoReturn)
      metricItem = {}
      clusterId = KubernetesApiClient.getClusterId

      begin
        metricInfo = metricJSON
        node = metricInfo["node"]
        nodeName = node["nodeName"]

        metricValue = node["startTime"]
        metricTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z

        metricItem["DataItems"] = []

        metricProps = {}
        metricProps["Timestamp"] = metricTime
        metricProps["Host"] = hostName
        metricProps["ObjectName"] = "K8SNode"
        metricProps["InstanceName"] = clusterId + "/" + nodeName

        metricProps["Collections"] = []
        metricCollections = {}
        metricCollections["CounterName"] = metricNametoReturn
        #Read it from /proc/uptime
        metricCollections["Value"] = DateTime.parse(metricTime).to_time.to_i - IO.read("/proc/uptime").split[0].to_f

        metricProps["Collections"].push(metricCollections)
        metricItem["DataItems"].push(metricProps)
      rescue => error
        @Log.warn("getNodeLastRebootTimeMetric failed: #{error} ")
        @Log.warn metricJSON
        return metricItem
      end
      return metricItem
    end

    def getContainerStartTimeMetricItems(metricJSON, hostName, metricNametoReturn)
      metricItems = []
      clusterId = KubernetesApiClient.getClusterId
      currentTime = Time.now.utc.iso8601 #2018-01-30T19:36:14Z
      begin
        metricInfo = metricJSON
        metricInfo["pods"].each do |pod|
          podUid = pod["podRef"]["uid"]
          if (!pod["containers"].nil?)
            pod["containers"].each do |container|
              containerName = container["name"]
              metricValue = container["startTime"]
              metricTime = currentTime

              metricItem = {}
              metricItem["DataItems"] = []

              metricProps = {}
              metricProps["Timestamp"] = metricTime
              metricProps["Host"] = hostName
              metricProps["ObjectName"] = "K8SContainer"
              metricProps["InstanceName"] = clusterId + "/" + podUid + "/" + containerName

              metricProps["Collections"] = []
              metricCollections = {}
              metricCollections["CounterName"] = metricNametoReturn
              metricCollections["Value"] = DateTime.parse(metricValue).to_time.to_i

              metricProps["Collections"].push(metricCollections)
              metricItem["DataItems"].push(metricProps)
              metricItems.push(metricItem)
            end
          end
        end
      rescue => error
        @Log.warn("getContainerStartTimeMetric failed: #{error} for metric #{metricNametoReturn}")
        @Log.warn metricJSON
        return metricItems
      end
      return metricItems
    end
  end
end
