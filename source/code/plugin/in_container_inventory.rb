#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent

  class Container_Inventory_Input < Input
    Plugin.register_input('containerinventory', self)

    def initialize
      super
      require 'yaml'
      require 'json'

      require_relative 'DockerApiClient'
      #require_relative 'oms_common'
      #require_relative 'omslog'
    end

    config_param :run_interval, :time, :default => '1m'
    config_param :tag, :string, :default => "oms.ContainerInventory.CollectionTime"

    def configure (conf)
      super
    end

    def start
      if @run_interval
        @finished = false
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
      end
    end

    def shutdown
      if @run_interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end
=begin
    def enumerate(eventList = nil)
        currentTime = Time.now
        emitTime = currentTime.to_f
        batchTime = currentTime.utc.iso8601
          if eventList.nil?
            $log.info("in_kube_events::enumerate : Getting events from Kube API @ #{Time.now.utc.iso8601}")
            events = JSON.parse(KubernetesApiClient.getKubeResourceInfo('events').body)
            $log.info("in_kube_events::enumerate : Done getting events from Kube API @ #{Time.now.utc.iso8601}")
          else
            events = eventList
          end
          eventQueryState = getEventQueryState
          newEventQueryState = []
          begin
            if(!events.empty?)
              eventStream = MultiEventStream.new
              events['items'].each do |items|
                record = {}
                record['CollectionTime'] = batchTime #This is the time that is mapped to become TimeGenerated
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
                record['ClusterId'] = KubernetesApiClient.getClusterId
                eventStream.add(emitTime, record) if record    
              end
              router.emit_stream(@tag, eventStream) if eventStream
            end  
            writeEventQueryState(newEventQueryState)
          rescue  => errorStr
            $log.warn line.dump, error: errorStr.to_s
            $log.debug_backtrace(errorStr.backtrace)
          end   
    end
=end
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
            myhost = DockerApiClient.getDockerHostName()
            router.emit_stream(@tag, myhost) if myhost
          rescue => errorStr
            $log.warn "in_kube_events::run_periodic: enumerate Failed to retrieve kube events: #{errorStr}"
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end

  end # Kube_Event_Input

end # module

