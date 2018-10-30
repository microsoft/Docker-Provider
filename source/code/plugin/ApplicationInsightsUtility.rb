#!/usr/local/bin/ruby
# frozen_string_literal: true

class ApplicationInsightsUtility
    require_relative 'application_insights'
    require_relative 'omslog'
    require_relative 'DockerApiClient'
    require 'json'

    @@HeartBeat = 'HeartBeatEvent'
    @@Exception = 'ExceptionEvent'
    @OmsAdminFilePath = '/etc/opt/microsoft/omsagent/conf/omsadmin.conf'
    @@customProperties = {}
    @@tc = ApplicationInsights::TelemetryClient.new '9435b43f-97d5-4ded-8d90-b047958e6e87'
    def initialize
        resourceInfo = ENV['AKS_RESOURCE_ID']
        if resourceInfo.nil? || resourceInfo.empty?
            @@customProperties["ACSResourceName"] = ENV['ACS_RESOURCE_NAME']
		    @@customProperties["ClusterType"] = 'ACS'
		    @@customProperties["SubscriptionID"] = ""
		    @@customProperties["ResourceGroupName"] = ""
		    @@customProperties["ClusterName"] = ""
		    @@customProperties["Region"] = ""
            @@customProperties["AKS_RESOURCE_ID"] = ""
        else
            aksResourceId = ENV['AKS_RESOURCE_ID']
            @@customProperties["AKS_RESOURCE_ID"] = aksResourceId
            begin
                splitStrings = aksResourceId.split('/')
                subscriptionId = splitStrings[2]
                resourceGroupName = splitStrings[4]
                clusterName = splitStrings[8]
            rescue => errorStr
                $log.warn("Exception in AppInsightsUtility: parsing AKS resourceId: #{aksResourceId}, error: #{errorStr}")
            end
		    @@customProperties["ClusterType"] = 'AKS'
		    @@customProperties["SubscriptionID"] = subscriptionId
		    @@customProperties["ResourceGroupName"] = resourceGroupName
		    @@customProperties["ClusterName"] = clusterName
		    @@customProperties["Region"] = ENV['AKS_REGION']
        end
        @@customProperties['ControllerType'] = 'DaemonSet'
        dockerInfo = DockerApiClient.dockerInfo
        @@customProperties['DockerVersion'] = dockerInfo['Version']
        @@customProperties['DockerApiVersion'] = dockerInfo['ApiVersion']
        @@customProperties['WorkspaceID'] = getWorkspaceId
    end

    class << self
        def sendHeartBeatEvent(pluginName, properties)
            eventName = pluginName + @@HeartBeat
            @@tc.track_event eventName , :properties => @@customProperties
            @@tc.flush
        end

        def sendCustomEvent(pluginName, properties)
            @@tc.track_metric 'LastProcessedContainerInventoryCount', properties['ContainerCount'], 
            :kind => ApplicationInsights::Channel::Contracts::DataPointType::MEASUREMENT, 
            :properties => { @@customProperties }
            @@tc.flush
        end

        def sendExceptionTelemetry(pluginName, errorStr)
            eventName = pluginName + @@Exception
            @@tc.track_exception errorStr , :properties => @@customProperties
            @@tc.flush
        end

        def sendTelemetry(pluginName, properties)
            @@customProperties['Computer'] = properties['Computer']
            sendHeartBeatEvent(properties)
            sendCustomEvent(pluginName, properties)
        end

        def getWorkspaceId()
            adminConf = {}
            confFile = File.open(@OmsAdminFilePath, "r")
            confFile.each_line do |line|
                splitStrings = line.split('=')
                adminConf[splitStrings[0]] = splitStrings[1]
            end
            workspaceId = adminConf['WORKSPACE_ID']
            return workspaceId
        end
    end
end