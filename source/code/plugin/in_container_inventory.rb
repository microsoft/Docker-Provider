#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent

  class Container_Inventory_Input < Input
    Plugin.register_input('containerinventory', self)

    def initialize
      super
      require 'json'
      require_relative 'DockerApiClient'
    end

    config_param :run_interval, :time, :default => '1m'
    config_param :tag, :string, :default => "oms.containerinsights.ContainerInventory"
  
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

    def enumerate
      currentTime = Time.now
      emitTime = currentTime.to_f
      batchTime = currentTime.utc.iso8601
      myhost = DockerApiClient.getDockerHostName
      begin
        eventStream = MultiEventStream.new
        record = {}
        record['myhost'] = myhost
        eventStream.add(emitTime, record) if record
        router.emit_stream(@tag, eventStream) if eventStream
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
            $log.info("in_container_inventory::run_periodic @ #{Time.now.utc.iso8601}")
            enumerate
          rescue => errorStr
            $log.warn "in_container_inventory::run_periodic: enumerate Failed to retrieve docker container inventory: #{errorStr}"
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end

  end # Container_Inventory_Input

end # module