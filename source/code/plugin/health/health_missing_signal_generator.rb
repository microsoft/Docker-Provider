require_relative 'health_model_constants'
require_relative 'health_monitor_record'

module HealthModel
    class HealthMissingSignalGenerator
        attr_accessor :last_received_records, :current_received_records
        attr_reader :missing_signals, :unknown_signals_hash

        def initialize()
            @last_received_records = {}
            @unknown_signals_hash = {}
        end

        def get_missing_signals(cluster_id, health_monitor_records, health_k8s_inventory, provider)
            missing_monitor_ids = []
            nodes = health_k8s_inventory.get_nodes
            workload_names = health_k8s_inventory.get_workload_names
            missing_signals_map = {}
            missing_signals = []
            health_monitor_records_map = {}
            health_monitor_records.map{
                |monitor| health_monitor_records_map[monitor.monitor_instance_id] = monitor
            }

            node_signals_hash = {}
            nodes.each{|node|
                node_signals_hash[node] = [MonitorId::NODE_MEMORY_MONITOR_ID, MonitorId::NODE_CPU_MONITOR_ID, MonitorId::NODE_CONDITION_MONITOR_ID]
            }
            log = HealthMonitorHelpers.get_log_handle
            log.info "last_received_records #{@last_received_records.size} nodes #{nodes}"
            @last_received_records.each{|monitor_instance_id, monitor|
                if !health_monitor_records_map.key?(monitor_instance_id)
                    if HealthMonitorHelpers.is_node_monitor(monitor.monitor_id)
                        node_name = monitor.labels[HealthMonitorLabels::HOSTNAME]
                        new_monitor = HealthMonitorRecord.new(
                            monitor.monitor_id,
                            monitor.monitor_instance_id,
                            Time.now.utc.iso8601,
                            monitor.state,
                            monitor.labels,
                            monitor.config,
                            {"timestamp" => Time.now.utc.iso8601, "state" => HealthMonitorStates::UNKNOWN, "details" => ""}
                        )
                        if !node_name.nil? && nodes.include?(node_name)
                            new_monitor.state = HealthMonitorStates::UNKNOWN
                            new_monitor.details["state"] = HealthMonitorStates::UNKNOWN
                            new_monitor.details["details"] = "Node present in inventory but no signal for #{monitor.monitor_id} from node #{node_name}"
                            @unknown_signals_hash[monitor_instance_id] = new_monitor
                        elsif !node_name.nil? && !nodes.include?(node_name)
                            new_monitor.state = HealthMonitorStates::NONE
                            new_monitor.details["state"] = HealthMonitorStates::NONE
                            new_monitor.details["details"] = "Node NOT present in inventory.  node:  #{node_name}"
                        end
                        missing_signals_map[monitor_instance_id] = new_monitor
                        log.info "Added missing signal #{new_monitor.monitor_instance_id} #{new_monitor.state}"
                    elsif HealthMonitorHelpers.is_pods_ready_monitor(monitor.monitor_id)
                        lookup = "#{monitor.labels[HealthMonitorLabels::NAMESPACE]}~~#{monitor.labels[HealthMonitorLabels::WORKLOAD_NAME]}"
                        new_monitor = HealthMonitorRecord.new(
                            monitor.monitor_id,
                            monitor.monitor_instance_id,
                            Time.now.utc.iso8601,
                            monitor.state,
                            monitor.labels,
                            monitor.config,
                            {"timestamp" => Time.now.utc.iso8601, "state" => HealthMonitorStates::UNKNOWN, "details" => ""}
                        )
                        if !lookup.nil? && workload_names.include?(lookup)
                            new_monitor.state = HealthMonitorStates::UNKNOWN
                            new_monitor.details["state"] = HealthMonitorStates::UNKNOWN
                            new_monitor.details["details"] = "Workload present in inventory. But no signal for #{lookup}"
                            @unknown_signals_hash[monitor_instance_id] = new_monitor
                        elsif !lookup.nil? && !workload_names.include?(lookup)
                            new_monitor.state = HealthMonitorStates::NONE
                            new_monitor.details["state"] = HealthMonitorStates::NONE
                            new_monitor.details["details"] = "Workload #{lookup} NOT present in inventory"
                        end
                        missing_signals_map[monitor_instance_id] = new_monitor
                    end
                end
            }


            health_monitor_records.each{|health_monitor_record|
                # remove signals from the list of expected signals if we see them in the list of current signals
                if HealthMonitorHelpers.is_node_monitor(health_monitor_record.monitor_id)
                    node_name = health_monitor_record.labels[HealthMonitorLabels::HOSTNAME]
                    if node_signals_hash.key?(node_name)
                        signals = node_signals_hash[node_name]
                        signals.delete(health_monitor_record.monitor_id)
                        if signals.size == 0
                            node_signals_hash.delete(node_name)
                        end
                    end
                end
            }

            # if the hash is not empty, means we have missing signals
            if node_signals_hash.size > 0
                # these signals were not sent previously
                # these signals need to be assigned an unknown state
                node_signals_hash.each{|node, monitor_ids|
                    monitor_ids.each{|monitor_id|
                        monitor_instance_id = HealthMonitorHelpers.get_monitor_instance_id(monitor_id, [cluster_id, node])
                        new_monitor = HealthMonitorRecord.new(
                            monitor_id,
                            monitor_instance_id,
                            Time.now.utc.iso8601,
                            HealthMonitorStates::UNKNOWN,
                            provider.get_node_labels(node),
                            {},
                            {"timestamp" => Time.now.utc.iso8601, "state" => HealthMonitorStates::UNKNOWN, "details" => "no signal received from node #{node}"}
                        )
                        missing_signals_map[monitor_instance_id] = new_monitor
                        log.info "Added missing signal when node_signals_hash was not empty #{new_monitor.monitor_instance_id} #{new_monitor.state} #{new_monitor.labels.keys}"
                    }
                }
            end

            missing_signals_map.each{|k,v|
                    missing_signals.push(v)
            }

            # if an unknown signal is present neither in missing signals or the incoming signals, change its state to none, and remove from unknown_signals
            # in update_state of HealthMonitorState, send if latest_record_state is none
            @unknown_signals_hash.each{|k,v|
                if !missing_signals_map.key?(k) && !health_monitor_records_map.key?(k)
                    monitor_record = @unknown_signals_hash[k]
                    monitor_record.details["state"] = HealthMonitorStates::NONE # used for calculating the old and new states in update_state
                    monitor_record.state = HealthMonitorStates::NONE #used for calculating the aggregate monitor state
                    missing_signals.push(monitor_record)
                    @unknown_signals_hash.delete(k)
                    log.info "Updating state from unknown to none for #{k}"
                end
            }
            return missing_signals
        end

        def update_last_received_records(last_received_records)
            last_received_records_map = {}
            last_received_records.map {|record| last_received_records_map[record.monitor_instance_id] = record }
            @last_received_records = last_received_records_map
        end
    end

end