module HealthModel
    class AggregateMonitorInstanceIdLabels
        @@id_labels_mapping = {
            MonitorId::SYSTEM_WORKLOAD => [HealthMonitorLabels::NAMESPACE, HealthMonitorLabels::WORKLOAD_NAME],
            MonitorId::USER_WORKLOAD => [HealthMonitorLabels::NAMESPACE, HealthMonitorLabels::WORKLOAD_NAME],
            MonitorId::NODE => [HealthMonitorLabels::AGENTPOOL, HealthMonitorLabels::ROLE, HealthMonitorLabels::HOSTNAME],
            MonitorId::NAMESPACE => [HealthMonitorLabels::NAMESPACE],
            MonitorId::AGENT_NODE_POOL => [HealthMonitorLabels::AGENTPOOL],
            MonitorId::CONTAINER => [HealthMonitorLabels::NAMESPACE, HealthMonitorLabels::WORKLOAD_NAME, HealthMonitorLabels::CONTAINER],
            MonitorId::CONTAINER_CPU_MONITOR_ID => [HealthMonitorLabels::NAMESPACE, HealthMonitorLabels::WORKLOAD_NAME],
            MonitorId::CONTAINER_MEMORY_MONITOR_ID => [HealthMonitorLabels::NAMESPACE, HealthMonitorLabels::WORKLOAD_NAME],
        }

        def self.get_labels_for(monitor_id)
            if @@id_labels_mapping.key?(monitor_id)
                return @@id_labels_mapping[monitor_id]
            else
                return []
            end

        end
    end
end