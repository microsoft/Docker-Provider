#!/usr/local/bin/ruby
# frozen_string_literal: true

class ApplicationInsightsUtility
    require_relative 'lib/application_insights'
    require_relative 'omslog'
    require_relative 'DockerApiClient'
    require 'json'
    require 'base64'

    @@HeartBeat = 'HeartBeatEvent'
    @@Exception = 'ExceptionEvent'
    @@AcsClusterType = 'ACS'
    @@AksClusterType = 'AKS'
    @@DaemonsetControllerType = 'DaemonSet'
    @OmsAdminFilePath = '/etc/opt/microsoft/omsagent/conf/omsadmin.conf'
    @@EnvAcsResourceName = 'ACS_RESOURCE_NAME'
    @@EnvAksRegion = 'AKS_REGION'
    @@EnvAgentVersion = 'AGENT_VERSION'
    @@EnvApplicationInsightsKey = 'APPLICATIONINSIGHTS_AUTH'
    @@CustomProperties = {}
    @@Tc = nil

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
                @@CustomProperties['ControllerType'] = @@DaemonsetControllerType
                dockerInfo = DockerApiClient.dockerInfo
                @@CustomProperties['DockerVersion'] = dockerInfo['Version']
                @@CustomProperties['DockerApiVersion'] = dockerInfo['ApiVersion']
                @@CustomProperties['WorkspaceID'] = getWorkspaceId
                @@CustomProperties['AgentVersion'] = ENV[@@EnvAgentVersion]
                encodedAppInsightsKey = ENV[@@EnvApplicationInsightsKey]
                if !encodedAppInsightsKey.nil?
                    decodedAppInsightsKey = Base64.decode64(encodedAppInsightsKey)
                    @@Tc = ApplicationInsights::TelemetryClient.new decodedAppInsightsKey
                end
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: initilizeUtility - error: #{errorStr}")
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

        def sendCustomEvent(pluginName, properties)
            begin
                if !(@@Tc.nil?)
                    @@Tc.track_metric 'LastProcessedContainerInventoryCount', properties['ContainerCount'], 
                    :kind => ApplicationInsights::Channel::Contracts::DataPointType::MEASUREMENT, 
                    :properties => @@CustomProperties
                    @@Tc.flush
                    $log.info("AppInsights Container Count Telemetry sent successfully")
                end
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: sendCustomEvent - error: #{errorStr}")
            end
        end

        def sendExceptionTelemetry(errorStr)
            begin
                if @@CustomProperties.empty? || @@CustomProperties.nil?
                    initializeUtility
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
                    initializeUtility
                end
                @@CustomProperties['Computer'] = properties['Computer']
                sendHeartBeatEvent(pluginName)
                sendCustomEvent(pluginName, properties)
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: sendTelemetry - error: #{errorStr}")
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