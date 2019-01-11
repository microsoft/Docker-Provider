#!/usr/local/bin/ruby
# frozen_string_literal: true

class ApplicationInsightsUtility
    require_relative 'lib/application_insights'
    require_relative 'omslog'
    require_relative 'DockerApiClient'
    require_relative 'oms_common'
    require 'json'
    require 'base64'

    @@HeartBeat = 'HeartBeatEvent'
    @@Exception = 'ExceptionEvent'
    @@AcsClusterType = 'ACS'
    @@AksClusterType = 'AKS'
    @OmsAdminFilePath = '/etc/opt/microsoft/omsagent/conf/omsadmin.conf'
    @@EnvAcsResourceName = 'ACS_RESOURCE_NAME'
    @@EnvAksRegion = 'AKS_REGION'
    @@EnvAgentVersion = 'AGENT_VERSION'
    @@EnvApplicationInsightsKey = 'APPLICATIONINSIGHTS_AUTH'
    @@EnvControllerType = 'CONTROLLER_TYPE'

    @@CustomProperties = {}
    @@Tc = nil
    @@hostName = (OMS::Common.get_hostname)

    def initialize
    end

    class << self
        #Set default properties for telemetry event
        def initializeUtility()
            begin
                resourceInfo = ENV['AKS_RESOURCE_ID']
                if resourceInfo.nil? || resourceInfo.empty?
                    @@CustomProperties["ACSResourceName"] = ENV[@@EnvAcsResourceName]
		            @@CustomProperties["ClusterType"] = @@AcsClusterType
		            @@CustomProperties["SubscriptionID"] = ""
		            @@CustomProperties["ResourceGroupName"] = ""
		            @@CustomProperties["ClusterName"] = ""
		            @@CustomProperties["Region"] = ""
                else
                    @@CustomProperties["AKS_RESOURCE_ID"] = resourceInfo
                    begin
                        splitStrings = resourceInfo.split('/')
                        subscriptionId = splitStrings[2]
                        resourceGroupName = splitStrings[4]
                        clusterName = splitStrings[8]
                    rescue => errorStr
                        $log.warn("Exception in AppInsightsUtility: parsing AKS resourceId: #{resourceInfo}, error: #{errorStr}")
                    end
		            @@CustomProperties["ClusterType"] = @@AksClusterType
		            @@CustomProperties["SubscriptionID"] = subscriptionId
		            @@CustomProperties["ResourceGroupName"] = resourceGroupName
		            @@CustomProperties["ClusterName"] = clusterName
		            @@CustomProperties["Region"] = ENV[@@EnvAksRegion]
                end

                getDockerInfo()
                @@CustomProperties['WorkspaceID'] = getWorkspaceId
                @@CustomProperties['AgentVersion'] = ENV[@@EnvAgentVersion]
                @@CustomProperties['ControllerType'] = ENV[@@EnvControllerType]
                encodedAppInsightsKey = ENV[@@EnvApplicationInsightsKey]
                if !encodedAppInsightsKey.nil?
                    decodedAppInsightsKey = Base64.decode64(encodedAppInsightsKey)
                    @@Tc = ApplicationInsights::TelemetryClient.new decodedAppInsightsKey
                end
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: initilizeUtility - error: #{errorStr}")
            end
        end

        def getDockerInfo() 
            dockerInfo = DockerApiClient.dockerInfo
            if (!dockerInfo.nil? && !dockerInfo.empty?)
                @@CustomProperties['DockerVersion'] = dockerInfo['Version']
                @@CustomProperties['DockerApiVersion'] = dockerInfo['ApiVersion']
            end
        end

        def sendHeartBeatEvent(pluginName)
            begin
                eventName = pluginName + @@HeartBeat
                if !(@@Tc.nil?)
                    @@Tc.track_event eventName , :properties => @@CustomProperties
                    @@Tc.flush
                    $log.info("AppInsights Heartbeat Telemetry sent successfully")
                end
            rescue =>errorStr
                $log.warn("Exception in AppInsightsUtility: sendHeartBeatEvent - error: #{errorStr}")
            end
        end

        def sendCustomMetric(pluginName, properties)
            begin
                if !(@@Tc.nil?)
                    @@Tc.track_metric 'LastProcessedContainerInventoryCount', properties['ContainerCount'], 
                    :kind => ApplicationInsights::Channel::Contracts::DataPointType::MEASUREMENT, 
                    :properties => @@CustomProperties
                    @@Tc.flush
                    $log.info("AppInsights Container Count Telemetry sent successfully")
                end
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: sendCustomMetric - error: #{errorStr}")
            end
        end

        def sendExceptionTelemetry(errorStr)
            begin
                if @@CustomProperties.empty? || @@CustomProperties.nil?
                    initializeUtility()
                elsif @@CustomProperties['DockerVersion'].nil?
                    getDockerInfo()
                end
                if !(@@Tc.nil?)
                    @@Tc.track_exception errorStr , :properties => @@CustomProperties
                    @@Tc.flush
                    $log.info("AppInsights Exception Telemetry sent successfully")
                end
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: sendExceptionTelemetry - error: #{errorStr}")
            end
        end

        #Method to send heartbeat and container inventory count
        def sendTelemetry(pluginName, properties)
            begin
                if @@CustomProperties.empty? || @@CustomProperties.nil?
                    initializeUtility()
                elsif @@CustomProperties['DockerVersion'].nil?
                    getDockerInfo()
                end
                @@CustomProperties['Computer'] = properties['Computer']
                sendHeartBeatEvent(pluginName)
                sendCustomMetric(pluginName, properties)
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: sendTelemetry - error: #{errorStr}")
            end
        end

        #Method to send metric. It will merge passed-in properties with common custom properties
        def sendMetricTelemetry(metricName, metricValue, properties)
            begin
                if (metricName.empty? || metricName.nil?)
                    $log.warn("SendMetricTelemetry: metricName is missing")
                    return
                end
                if @@CustomProperties.empty? || @@CustomProperties.nil?
                    initializeUtility()
                elsif @@CustomProperties['DockerVersion'].nil?
                    getDockerInfo()
                end
                telemetryProps = {}
                telemetryProps["Computer"] = @@hostName
                # add common dimensions
                @@CustomProperties.each{ |k,v| telemetryProps[k]=v}
                # add passed-in dimensions if any
                if (!properties.nil? && !properties.empty?)
                    properties.each{ |k,v| telemetryProps[k]=v}
                end
                if !(@@Tc.nil?)
                    @@Tc.track_metric metricName, metricValue, 
                    :kind => ApplicationInsights::Channel::Contracts::DataPointType::MEASUREMENT, 
                    :properties => telemetryProps
                    @@Tc.flush
                    $log.info("AppInsights metric Telemetry #{metricName} sent successfully")
                end
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: sendMetricTelemetry - error: #{errorStr}")
            end
        end

        def getWorkspaceId()
            begin
                adminConf = {}
                confFile = File.open(@OmsAdminFilePath, "r")
                confFile.each_line do |line|
                    splitStrings = line.split('=')
                    adminConf[splitStrings[0]] = splitStrings[1]
                end
                workspaceId = adminConf['WORKSPACE_ID']
                return workspaceId
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: getWorkspaceId - error: #{errorStr}")
            end
        end
    end
end