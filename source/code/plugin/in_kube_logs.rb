#!/usr/local/bin/ruby

module Fluent
    
    class Kube_Logs_Input < Input
        Plugin.register_input('kubelogs', self)
    
        @@KubeLogsStateFile = "/var/opt/microsoft/docker-cimprov/state/KubeLogQueryState.yaml"
    
        def initialize
            super
            require 'yaml'
            require 'date'
            require 'time'

            require_relative 'KubernetesApiClient'
            require_relative 'oms_common'
            require_relative 'omslog'  
        end
    
        config_param :run_interval, :time, :default => '1m'
        config_param :tag, :string, :default => "oms.api.KubeLogs"
        config_param :namespace, :string, :default => "default"

        def configure (conf)
            super
        end
    
        def start
            if KubernetesApiClient.isNodeMaster && @run_interval
                @finished = false
                @condition = ConditionVariable.new
                @mutex = Mutex.new
                @thread = Thread.new(&method(:run_periodic))
            else
                enumerate
            end
        end
    
        def shutdown
            if KubernetesApiClient.isNodeMaster && @run_interval
                @mutex.synchronize {
                    @finished = true
                    @condition.signal
                }
                @thread.join
            end  
        end
    
        def enumerate(podList = nil)
            time = Time.now.to_f
            if KubernetesApiClient.isNodeMaster

                if podList.nil?
                    pods = KubernetesApiClient.getPods(@namespace)
                else
                    pods = podList
                end   
                logQueryState = getLogQueryState
                newLogQueryState = {}

                pods.each do |pod|
                    record = {}
                    begin
                        pod['status']['containerStatuses'].each do |container|
        
                            # if container['state']['running']
                            #     puts container['name'] + ' is running'
                            # end

                            timeStamp = DateTime.now

                            containerId = pod['metadata']['namespace'] + "_" + pod['metadata']['name'] + "_" + container['name']
                            if !logQueryState.empty? && logQueryState[containerId]
                                timeStamp = DateTime.parse(logQueryState[containerId])
                            end  
                            #puts timeStamp.rfc3339(9)

                            logs = KubernetesApiClient.getContainerLogsSinceTime(pod['metadata']['namespace'], pod['metadata']['name'], container['name'], timeStamp.rfc3339(9), true)
                            
                            if logs && logs.empty?
                                newLogQueryState[containerId] = DateTime.now.rfc3339(9)
                            else
                                lines = logs.split("\n")
                                index = -1
            
                                # ignore duplicates
                                for i in 0...lines.count
                                    dateTime = DateTime.parse(lines[i].split(" ").first)               
                                    if (dateTime.to_time - timeStamp.to_time) > 0.0
                                        index = i
                                        break
                                    end
                                end
            
                                if index >= 0
                                    for i in index...lines.count
                                        record['Namespace'] = pod['metadata']['namespace']
                                        record['Pod'] = pod['metadata']['name']
                                        record['Container'] = container['name']
                                        record['Message'] = lines[i][(lines[i].index(' ') + 1)..(lines[i].length - 1)]
                                        record['Type'] = 'Containerlog'
                                        record['TimeGenerated'] = lines[i].split(" ").first
                                        router.emit(@tag, time, record) if record
                                    end
                                    newLogQueryState[containerId] = lines.last.split(" ").first
                                else
                                    newLogQueryState[containerId] = DateTime.now.rfc3339(9)
                                end
                            end
                        end    
                    rescue  => errorStr
                        $log.warn line.dump, error: errorStr.to_s
                        $log.debug_backtrace(e.backtrace)
                    end
                end
                writeLogQueryState(newLogQueryState)
            else
                record = {}
                record['Namespace'] = ""
                record['Pod'] = ""
                record['Container'] = ""
                record['Message'] = ""
                record['Type'] = ""
                record['TimeGenerated'] = ""
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
    
        def getLogQueryState
            logQueryState = []
            begin
                if File.file?(@@KubeLogsStateFile)
                    logQueryState = YAML.load_file(@@KubeLogsStateFile)
                end
            rescue  => errorStr
                $log.warn $log.warn line.dump, error: errorStr.to_s
                $log.debug_backtrace(e.backtrace)
            end
            return logQueryState
        end
    
        def writeLogQueryState(logQueryState)
            begin     
                File.write(@@KubeLogsStateFile, logQueryState.to_yaml)       
            rescue  => errorStr
                $log.warn $log.warn line.dump, error: errorStr.to_s
                $log.debug_backtrace(e.backtrace)
            end
        end
    
    end # Kube_Log_Input
    
end # module
    
    
    