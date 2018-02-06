#!/usr/local/bin/ruby

module Fluent

  class Kube_PodInventory_Input < Input
    Plugin.register_input('kubepodinventory', self)

    def initialize
      super
      require 'yaml'
      require 'json'

      require_relative 'KubernetesApiClient'
      require_relative 'oms_common'
      require_relative 'omslog'
    end

    config_param :run_interval, :time, :default => '10m'
    config_param :tag, :string, :default => "oms.api.KubePodInventory"

    def configure (conf)
      super
    end

    def start
      if KubernetesApiClient.isValidRunningNode && @run_interval
        @finished = false
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
      else
        enumerate
      end
    end

    def shutdown
      if KubernetesApiClient.isValidRunningNode && @run_interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end

    def enumerate(podList = nil)
      time = Time.now.to_f
      if KubernetesApiClient.isValidRunningNode
        if podList.nil?
          podInventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo('pods').body)
          
        else
          podInventory = podList
        end
        begin
          if(!podInventory.empty?) 

            #get resource requests & resource limits per container as perf data
            metricDataItems = []
            hostName = (OMS::Common.get_hostname)
            metricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(podInventory, "requests", hostName, "cpu","cpuRequestNanoCores"))
            metricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(podInventory, "requests", hostName, "memory","memoryRequestBytes"))
            metricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(podInventory, "limits", hostName, "cpu","cpuLimitNanoCores"))
            metricDataItems.concat(KubernetesApiClient.getContainerResourceRequestsAndLimits(podInventory, "limits", hostName, "memory","memoryLimitBytes"))

            metricDataItems.each do |record|
              record['DataType'] = "LINUX_PERF_BLOB"
              record['IPName'] = "LogManagement"
              router.emit("oms.api.KubePerf", time, record) if record  
            end  

            #get pod inventory
            podInventory['items'].each do |items|
              records = []
              record = {}
              record['Name'] = items['metadata']['name']
              podUid = items['metadata']['uid']
              record['PodUid'] = podUid
              record['PodLabel'] = [items['metadata']['labels']]
              record['Namespace'] = items['metadata']['namespace']
              record['PodCreationTimeStamp'] = items['metadata']['creationTimestamp']
              record['PodStartTime'] = items['status']['startTime']
              record['PodStatus'] = items['status']['phase']
              record['PodIp'] =items['status']['podIP']
              record['Computer'] = items['spec']['nodeName']
              record['ClusterName'] = KubernetesApiClient.getClusterName
              record['ServiceName'] = getServiceNameFromLabels(items['metadata']['namespace'], items['metadata']['labels'])
              if !items['metadata']['ownerReferences'].nil?
                record['ControllerKind'] = items['metadata']['ownerReferences'][0]['kind']
                record['ControllerName'] = items['metadata']['ownerReferences'][0]['name']
              end  
              podRestartCount = 0
              record['PodRestartCount'] = 0		    
              items['status']['containerStatuses'].each do |container|		
                containerRestartCount = 0		
                #container Id is of the form 		
                #docker://dfd9da983f1fd27432fb2c1fe3049c0a1d25b1c697b2dc1a530c986e58b16527	
                if !container['containerID'].nil?	
                  record['ContainerID'] = container['containerID'].split("//")[1]		
                else 
                  record['ContainerID'] = "00000000-0000-0000-0000-000000000000"  
                end 
                #keeping this as <PodUid/container_name> which is same as InstanceName in perf table		
                record['ContainerName'] = podUid + "/" +container['name']		
                #Pod restart count is a sumtotal of restart counts of individual containers		
                #within the pod. The restart count of a container is maintained by kubernetes		
                #itself in the form of a container label.		
                containerRestartCount = container['restartCount']		
                record['ContainerRestartCount'] = containerRestartCount
                containerStatus = container['state']
                # state is of the following form , so just picking up the first key name
                # "state": {
                #   "waiting": {
                #     "reason": "CrashLoopBackOff",
                #      "message": "Back-off 5m0s restarting failed container=metrics-server pod=metrics-server-2011498749-3g453_kube-system(5953be5f-fcae-11e7-a356-000d3ae0e432)"
                #   }
                # },
                record['ContainerStatus'] = containerStatus.keys[0]
                if containerStatus == "running"
                  record['ContainerCreationTimeStamp'] = container['running']['startedAt']
                end
                podRestartCount += containerRestartCount	
                records.push(record)		
              end
              records.each do |record|
                if !record.nil? 		
                  record['PodRestartCount'] = podRestartCount		
                  $log.info record
                  router.emit(@tag, time, record) 
                end    		
              end       
            end
          end  
        rescue  => errorStr
          $log.warn "Failed to retrieve pod inventory: #{errorStr}"
          $log.debug_backtrace(errorStr.backtrace)
        end
      else
        record = {}
        record['Name'] = ""
        record['PodUid'] = ""
        record['PodLabel'] = ""
        record['Namespace'] = ""
        record['PodCreationTimeStamp'] = ""
        record['PodStatus'] = ""
        record['PodIp'] = ""
        record['Computer'] = ""
        record['ClusterName'] = ""
        record['ServiceName'] = ""
        record['ContainerID'] = ""		
        record['InstanceName'] = ""		
        record['ContainerRestartCount'] = ""		
        record['PodRestartCount'] = "0"		
        record['PodStartTime'] = ""
        record['ContainerStartTime'] = ""        
        router.emit(@tag, time, record)
      end
    end

    def run_periodic
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, @run_interval)
        done = @finished
        @mutex.unlock
        if !done
          enumerate
        end
        @mutex.lock
      end
      @mutex.unlock
    end

    def getServiceNameFromLabels(namespace, labels)
      serviceName = ""
      begin
        if KubernetesApiClient.isValidRunningNode && !labels.nil? && !labels.empty?
          serviceList = JSON.parse(KubernetesApiClient.getKubeResourceInfo('services').body)
          if(!serviceList.empty?)
            serviceList['items'].each do |item|
              found = 0
              if !item['spec'].nil? && !item['spec']['selector'].nil? && item['metadata']['namespace'] == namespace
                
                selectorLabels = item['spec']['selector']
                selectorLabels.each do |key,value|
                  if !(labels.select {|k,v| k==key && v==value}.length > 0)
                    break
                  end
                  found = found + 1
                end
                if found == selectorLabels.length
                  return item['metadata']['name']
                end
              end  
            end
          end  
        end
      rescue  => errorStr
        $log.warn "Failed to retrieve service name from labels: #{errorStr}"
        $log.debug_backtrace(errorStr.backtrace)
      end
      return serviceName
    end

  end # Kube_Pod_Input

end # module

