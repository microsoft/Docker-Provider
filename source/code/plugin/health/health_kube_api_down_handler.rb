require_relative 'health_model_constants'
module HealthModel
    class HealthKubeApiDownHandler
        def initialize
            @@monitors_to_change = [MonitorId::WORKLOAD_CPU_OVERSUBSCRIBED_MONITOR_ID,
                                    MonitorId::WORKLOAD_MEMORY_OVERSUBSCRIBED_MONITOR_ID,
                                    MonitorId::NODE_CONDITION_MONITOR_ID,
                                    MonitorId::USER_WORKLOAD_PODS_READY_MONITOR_ID,
                                    MonitorId::SYSTEM_WORKLOAD_PODS_READY_MONITOR_ID]
        end

        # update kube-api dependent monitors to be 'unknown' if kube-api is down or monitor is unavailable
        def handle_kube_api_down(health_monitor_records)
            health_monitor_records_map = {}

            health_monitor_records.map{|record| health_monitor_records_map[record.monitor_instance_id] = record}
            if !health_monitor_records_map.key?(MonitorId::KUBE_API_STATUS) || (health_monitor_records_map.key?(MonitorId::KUBE_API_STATUS) && health_monitor_records_map[MonitorId::KUBE_API_STATUS].state != 'pass')
                #iterate over the map and set the state to unknown for related monitors
                health_monitor_records.each{|health_monitor_record|
                    if @@monitors_to_change.include?(health_monitor_record.monitor_id)
                        health_monitor_record.state = HealthMonitorStates::UNKNOWN
                    end
                }
            end
            return health_monitor_records
        end
    end
end