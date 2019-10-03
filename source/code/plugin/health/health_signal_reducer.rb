require_relative 'health_model_constants'

module HealthModel
    # this class
    # 1. dedupes daemonset signals and takes only the latest
    # 2. removes signals for objects that are no longer in the inventory e.g. node might have sent signal before being scaled down
    class HealthSignalReducer
        def initialize

        end

        def reduce_signals(health_monitor_records, health_k8s_inventory)
            nodes = health_k8s_inventory.get_nodes
            workload_names = health_k8s_inventory.get_workload_names
            reduced_signals_map = {}
            reduced_signals = []
            health_monitor_records.each{|health_monitor_record|
                monitor_instance_id = health_monitor_record.monitor_instance_id
                monitor_id = health_monitor_record.monitor_id
                if reduced_signals_map.key?(monitor_instance_id)
                    record = reduced_signals_map[monitor_instance_id]
                    if health_monitor_record.transition_date_time > record.transition_date_time # always take the latest record for a monitor instance id
                        reduced_signals_map[monitor_instance_id] = health_monitor_record
                    end
                elsif HealthMonitorHelpers.is_node_monitor(monitor_id)
                    node_name = health_monitor_record.labels['kubernetes.io/hostname']
                    if (node_name.nil? || !nodes.include?(node_name)) # only add daemon set records if node is present in the inventory
                        next
                    end
                    reduced_signals_map[monitor_instance_id] = health_monitor_record
                elsif HealthMonitorHelpers.is_pods_ready_monitor(monitor_id)
                    workload_name = health_monitor_record.labels[HealthMonitorLabels::WORKLOAD_NAME]
                    namespace = health_monitor_record.labels[HealthMonitorLabels::NAMESPACE]
                    lookup = "#{namespace}~~#{workload_name}"
                    if (workload_name.nil? || !workload_names.include?(lookup)) #only add pod record if present in the inventory
                        next
                    end
                    reduced_signals_map[monitor_instance_id] = health_monitor_record
                else
                    reduced_signals_map[monitor_instance_id] = health_monitor_record
                end
            }

            reduced_signals_map.each{|k,v|
                reduced_signals.push(v)
            }

            return reduced_signals
        end

    end
end