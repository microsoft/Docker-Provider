#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent
  class Kube_Event_Input < Input
    Plugin.register_input("kubeevents", self)

    @@KubeEventsStateFile = "/var/opt/microsoft/docker-cimprov/state/KubeEventQueryState.yaml"

    def initialize
      super
      require "json"

      require_relative "KubernetesApiClient"
      require_relative "oms_common"
      require_relative "omslog"
      require_relative "ApplicationInsightsUtility"
    end

    config_param :run_interval, :time, :default => "1m"
    config_param :tag, :string, :default => "oms.containerinsights.KubeEvents"

    def configure(conf)
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

    def enumerate(eventList = nil)
      currentTime = Time.now
      emitTime = currentTime.to_f
      batchTime = currentTime.utc.iso8601
      if eventList.nil?
        $log.info("in_kube_events::enumerate : Getting events from Kube API @ #{Time.now.utc.iso8601}")
        events = JSON.parse(KubernetesApiClient.getKubeResourceInfo("events").body)
        $log.info("in_kube_events::enumerate : Done getting events from Kube API @ #{Time.now.utc.iso8601}")
      else
        events = eventList
      end
      eventQueryState = getEventQueryState
      newEventQueryState = []
      begin
        if (!events.empty? && !events["items"].nil?)
          eventStream = MultiEventStream.new
          events["items"].each do |items|
            record = {}
            #<BUGBUG> - Not sure if ingestion has the below mapping for this custom type. Fix it as part of fixed type conversion
            record["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
            eventId = items["metadata"]["uid"] + "/" + items["count"].to_s
            newEventQueryState.push(eventId)
            if !eventQueryState.empty? && eventQueryState.include?(eventId)
              next
            end
            record["ObjectKind"] = items["involvedObject"]["kind"]
            record["Namespace"] = items["involvedObject"]["namespace"]
            record["Name"] = items["involvedObject"]["name"]
            record["Reason"] = items["reason"]
            record["Message"] = items["message"]
            record["Type"] = items["type"]
            record["TimeGenerated"] = items["metadata"]["creationTimestamp"]
            record["SourceComponent"] = items["source"]["component"]
            record["FirstSeen"] = items["firstTimestamp"]
            record["LastSeen"] = items["lastTimestamp"]
            record["Count"] = items["count"]
            if items["source"].key?("host")
              record["Computer"] = items["source"]["host"]
            else
              record["Computer"] = (OMS::Common.get_hostname)
            end
            record["ClusterName"] = KubernetesApiClient.getClusterName
            record["ClusterId"] = KubernetesApiClient.getClusterId
            wrapper = {
              "DataType" => "KUBE_EVENTS_BLOB",
              "IPName" => "ContainerInsights",
              "DataItems" => [record.each { |k, v| record[k] = v }],
            }
            eventStream.add(emitTime, wrapper) if wrapper
          end
          router.emit_stream(@tag, eventStream) if eventStream
        end
        writeEventQueryState(newEventQueryState)
      rescue => errorStr
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
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
            ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
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
          # Do not read the entire file in one shot as it spikes memory (50+MB) for ~5k events
          File.foreach(@@KubeEventsStateFile) do |line|
            eventQueryState.push(line.chomp) #puts will append newline which needs to be removed
          end
        end
      rescue => errorStr
        $log.warn $log.warn line.dump, error: errorStr.to_s
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return eventQueryState
    end

    def writeEventQueryState(eventQueryState)
      begin
        if (!eventQueryState.nil? && !eventQueryState.empty?)
          # No need to close file handle (f) due to block scope
          File.open(@@KubeEventsStateFile, "w") do |f|
            f.puts(eventQueryState)
          end
        end
      rescue => errorStr
        $log.warn $log.warn line.dump, error: errorStr.to_s
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end # Kube_Event_Input
end # module
