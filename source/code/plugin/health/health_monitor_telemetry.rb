require_relative 'health_model_constants'
require 'socket'
if Socket.gethostname.start_with?('omsagent-rs')
    require_relative '../ApplicationInsightsUtility'
end


module HealthModel
    class HealthMonitorTelemetry

        attr_reader :monitor_records, :last_sent_time
        @@TELEMETRY_SEND_INTERVAL = 60

        def initialize
            @last_sent_time = Time.now
        end

        def send
            if Time.now > @last_sent_time + @@TELEMETRY_SEND_INTERVAL * 60
                log = HealthMonitorHelpers.get_log_handle
                log.info "Sending #{@monitor_records.size} state change events"
                if @monitor_records.size > 0
                    hash_to_send = {}
                    @monitor_records.each{|k,v|
                        v.each{|k1,v1|
                            hash_to_send["#{k}-#{k1}"] = v1
                        }
                    }
                    ApplicationInsightsUtility.sendCustomEvent("HealthMonitorStateChangeEvent", hash_to_send)
                end
                @monitor_records = {}
                @last_sent_time = Time.now
            end
        end

        def add_monitor_to_telemetry(monitor_id, old_state, new_state)
            if @monitor_records.nil? || @monitor_records.empty?
                @monitor_records = {}
            end
            if @monitor_records.key?(monitor_id)
                monitor_hash = @monitor_records[monitor_id]
                if monitor_hash.key?("#{old_state}-#{new_state}")
                    count = monitor_hash["#{old_state}-#{new_state}"]
                    count = count + 1
                    monitor_hash["#{old_state}-#{new_state}"] = count
                else
                    monitor_hash["#{old_state}-#{new_state}"] = 1
                end
                @monitor_records[monitor_id] = monitor_hash
            else
                monitor_hash = {}
                monitor_hash["#{old_state}-#{new_state}"] = 1
                @monitor_records[monitor_id] = monitor_hash
            end
        end
    end
end