#!/usr/local/bin/ruby

module Fluent

  class Kube_Event_Input < Input
    Plugin.register_input('kubeevents', self)

    @@KubeEventsStateFile = "/var/opt/microsoft/docker-cimprov/state/KubeEventQueryState.yaml"

    def initialize
      super
      require 'yaml'
      require 'json'

      require_relative 'KubernetesApiClient'
      require_relative 'oms_common'
      require_relative 'omslog'
    end

    config_param :run_interval, :time, :default => '10m'
    config_param :tag, :string, :default => "oms.api.KubeEvents"

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

    def enumerate(eventList = nil)
        time = Time.now.to_f
        if KubernetesApiClient.isValidRunningNode
          if eventList.nil?
            events = JSON.parse(KubernetesApiClient.getKubeResourceInfo('events').body)
          else
            events = eventList
          end
          eventQueryState = getEventQueryState
          newEventQueryState = []
          begin
            if(!events.empty?)
              events['items'].each do |items|
                record = {}
                eventId = items['metadata']['uid'] + "/" + items['count'].to_s  
                newEventQueryState.push(eventId)
                if !eventQueryState.empty? && eventQueryState.include?(eventId)
                  next
                end  
                record['ObjectKind']= items['involvedObject']['kind']
                record['Namespace'] = items['involvedObject']['namespace']
                record['Name'] = items['involvedObject']['name']
                record['Reason'] = items['reason']
                record['Message'] = items['message']
                record['Type'] = items['type']
                record['TimeGenerated'] = items['metadata']['creationTimestamp']
                record['SourceComponent'] = items['source']['component']
                record['FirstSeen'] = items['firstTimestamp']
                record['LastSeen'] = items['lastTimestamp']
                record['Count'] = items['count']
                if items['source'].key?('host')
                        record['Computer'] = items['source']['host']
                else
                        record['Computer'] = (OMS::Common.get_hostname)
                end
                record['ClusterName'] = KubernetesApiClient.getClusterName
                router.emit(@tag, time, record) if record   
              end
            end  
            writeEventQueryState(newEventQueryState)
          rescue  => errorStr
            $log.warn line.dump, error: errorStr.to_s
            $log.debug_backtrace(errorStr.backtrace)
          end   
        else
          record = {}
          record['ObjectKind']= ""
          record['Namespace'] = ""
          record['Name'] = ""
          record['Reason'] = ""
          record['Message'] = ""
          record['Type'] = ""
          record['TimeGenerated'] = ""
          record['SourceComponent'] = ""
          record['FirstSeen'] = ""
          record['LastSeen'] = ""
          record['Count'] = "0"
          record['Computer'] = ""
          record['ClusterName'] = ""
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
          begin
            $log.info("in_kube_events::run_periodic @ #{Time.now.utc.iso8601}")
            enumerate
          rescue => errorStr
            $log.warn "in_kube_events::run_periodic: enumerate Failed to retrieve kube events: #{errorStr}"
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end

    def getEventQueryState
      eventQueryState = []
      begin
        if File.file?(@@KubeEventsStateFile)
          eventQueryState = YAML.load_file(@@KubeEventsStateFile, [])
        end
      rescue  => errorStr
        $log.warn $log.warn line.dump, error: errorStr.to_s
        $log.debug_backtrace(errorStr.backtrace)
      end
      return eventQueryState
    end

    def writeEventQueryState(eventQueryState)
      begin
        File.write(@@KubeEventsStateFile, eventQueryState.to_yaml)
      rescue  => errorStr
        $log.warn $log.warn line.dump, error: errorStr.to_s
        $log.debug_backtrace(errorStr.backtrace)
      end
    end

  end # Kube_Event_Input

end # module

