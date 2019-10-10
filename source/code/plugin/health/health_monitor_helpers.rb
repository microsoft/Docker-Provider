require 'logger'
require 'digest'
require_relative 'health_model_constants'

module HealthModel
    # static class that provides a bunch of utility methods
    class HealthMonitorHelpers

        @log_path = "/var/opt/microsoft/docker-cimprov/log/health_monitors.log"

        if Gem.win_platform? #unit testing on windows dev machine
            @log_path = "C:\Temp\health_monitors.log"
        end

        @log = Logger.new(@log_path, 2, 10 * 1048576) #keep last 2 files, max log file size = 10M

        class << self
            def is_node_monitor(monitor_id)
                return (monitor_id == MonitorId::NODE_CPU_MONITOR_ID || monitor_id == MonitorId::NODE_MEMORY_MONITOR_ID || monitor_id == MonitorId::NODE_CONDITION_MONITOR_ID)
            end

            def is_pods_ready_monitor(monitor_id)
                return (monitor_id == MonitorId::USER_WORKLOAD_PODS_READY_MONITOR_ID || monitor_id == MonitorId::SYSTEM_WORKLOAD_PODS_READY_MONITOR_ID)
            end

            def get_log_handle
                return @log
            end

            def get_monitor_instance_id(monitor_id, args = [])
                string_to_hash = args.join("/")
                return "#{monitor_id}-#{Digest::MD5.hexdigest(string_to_hash)}"
            end

            def add_agentpool_node_label_if_not_present(records)
                records.each{|record|
                    # continue if it is not a node monitor
                    if !is_node_monitor(record.monitor_id)
                        #@log.info "#{record.monitor_id} is not a NODE MONITOR"
                        next
                    end
                    labels_keys = record.labels.keys

                    if labels_keys.include?(HealthMonitorLabels::AGENTPOOL)
                        @log.info "#{record.monitor_id} includes agentpool label. Value = #{record.labels[HealthMonitorLabels::AGENTPOOL]}"
                        next
                    else
                        #@log.info "#{record} does not include agentpool label."
                        role_name = 'unknown'
                        if record.labels.include?(HealthMonitorLabels::ROLE)
                            role_name = record.labels[HealthMonitorLabels::ROLE]
                        elsif record.labels.include?(HealthMonitorLabels::MASTERROLE)
                            if !record.labels[HealthMonitorLabels::MASTERROLE].empty?
                                role_name = 'master'
                            end
                        elsif record.labels.include?(HealthMonitorLabels::COMPUTEROLE)
                            if !record.labels[HealthMonitorLabels::COMPUTEROLE].empty?
                                role_name = 'compute'
                            end
                        elsif record.labels.include?(HealthMonitorLabels::INFRAROLE)
                            if !record.labels[HealthMonitorLabels::INFRAROLE].empty?
                                role_name = 'infra'
                            end
                        end
                        @log.info "Adding agentpool label #{role_name}_node_pool for #{record.monitor_id}"
                        record.labels[HealthMonitorLabels::AGENTPOOL] = "#{role_name}_node_pool"
                    end
                }
            end
        end

    end
end
