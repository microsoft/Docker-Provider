require_relative 'health_model_constants'

module HealthModel
    class HealthMonitorProvider

        attr_accessor :cluster_labels, :health_kubernetes_resources, :monitor_configuration_path, :cluster_id
        attr_reader :monitor_configuration

        def initialize(cluster_id, cluster_labels, health_kubernetes_resources, monitor_configuration_path)
            @cluster_labels = Hash.new
            cluster_labels.each{|k,v| @cluster_labels[k] = v}
            @cluster_id = cluster_id
            @health_kubernetes_resources = health_kubernetes_resources
            @monitor_configuration_path = monitor_configuration_path
            begin
                @monitor_configuration = {}
                file = File.open(@monitor_configuration_path, "r")
                if !file.nil?
                    fileContents = file.read
                    @monitor_configuration = JSON.parse(fileContents)
                    file.close
                end
            rescue => e
                @log.info "Error when opening health config file #{e}"
            end
        end

        def get_record(health_monitor_record, health_monitor_state)

            labels = Hash.new
            @cluster_labels.each{|k,v| labels[k] = v}
            monitor_id = health_monitor_record.monitor_id
            monitor_instance_id = health_monitor_record.monitor_instance_id
            health_monitor_instance_state = health_monitor_state.get_state(monitor_instance_id)


            monitor_labels = health_monitor_record.labels
            if !monitor_labels.empty?
                monitor_labels.keys.each do |key|
                    labels[key] = monitor_labels[key]
                end
            end

            prev_records = health_monitor_instance_state.prev_records
            time_first_observed = health_monitor_instance_state.state_change_time # the oldest collection time
            new_state = health_monitor_instance_state.new_state # this is updated before formatRecord is called
            old_state = health_monitor_instance_state.old_state

            config = get_config(monitor_id)

            if prev_records.size == 1
                details = prev_records[0]
            else
                details = prev_records
            end

            time_observed = Time.now.utc.iso8601

            monitor_record = {}

            monitor_record[HealthMonitorRecordFields::CLUSTER_ID] = @cluster_id
            monitor_record[HealthMonitorRecordFields::MONITOR_LABELS] = labels.to_json
            monitor_record[HealthMonitorRecordFields::MONITOR_ID] = monitor_id
            monitor_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
            monitor_record[HealthMonitorRecordFields::NEW_STATE] = new_state
            monitor_record[HealthMonitorRecordFields::OLD_STATE] = old_state
            monitor_record[HealthMonitorRecordFields::DETAILS] = details.to_json
            monitor_record[HealthMonitorRecordFields::MONITOR_CONFIG] = config.to_json
            monitor_record[HealthMonitorRecordFields::TIME_GENERATED] = Time.now.utc.iso8601
            monitor_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] = time_first_observed
            monitor_record[HealthMonitorRecordFields::PARENT_MONITOR_INSTANCE_ID] = ''

            return monitor_record
        end

        def get_config(monitor_id)
            if @monitor_configuration.key?(monitor_id)
                return @monitor_configuration[monitor_id]
            else
                return {}
            end
        end

        def get_labels(health_monitor_record)
            monitor_labels = Hash.new
            @cluster_labels.keys.each{|key|
                monitor_labels[key] = @cluster_labels[key]
            }
            monitor_id = health_monitor_record[HealthMonitorRecordFields::MONITOR_ID]
            case monitor_id
            when MonitorId::CONTAINER_CPU_MONITOR_ID, MonitorId::CONTAINER_MEMORY_MONITOR_ID, MonitorId::USER_WORKLOAD_PODS_READY_MONITOR_ID, MonitorId::SYSTEM_WORKLOAD_PODS_READY_MONITOR_ID

                namespace = health_monitor_record[HealthMonitorRecordFields::DETAILS]['details']['namespace']
                workload_name = health_monitor_record[HealthMonitorRecordFields::DETAILS]['details']['workload_name']
                workload_kind = health_monitor_record[HealthMonitorRecordFields::DETAILS]['details']['workload_kind']

                monitor_labels[HealthMonitorLabels::WORKLOAD_NAME] = workload_name.split('~~')[1]
                monitor_labels[HealthMonitorLabels::WORKLOAD_KIND] = workload_kind
                monitor_labels[HealthMonitorLabels::NAMESPACE] = namespace

                # add the container name for container memory/cpu
                if monitor_id == MonitorId::CONTAINER_CPU_MONITOR_ID || monitor_id == MonitorId::CONTAINER_MEMORY_MONITOR_ID
                    container = health_monitor_record[HealthMonitorRecordFields::DETAILS]['details']['container']
                    monitor_labels[HealthMonitorLabels::CONTAINER] = container
                end

                #TODO: This doesn't belong here. Move this elsewhere
                health_monitor_record[HealthMonitorRecordFields::DETAILS]['details'].delete('namespace')
                health_monitor_record[HealthMonitorRecordFields::DETAILS]['details'].delete('workload_name')
                health_monitor_record[HealthMonitorRecordFields::DETAILS]['details'].delete('workload_kind')

            when MonitorId::NODE_CPU_MONITOR_ID, MonitorId::NODE_MEMORY_MONITOR_ID, MonitorId::NODE_CONDITION_MONITOR_ID
                node_name = health_monitor_record[HealthMonitorRecordFields::NODE_NAME]
                @health_kubernetes_resources.get_node_inventory['items'].each do |node|
                    if !node_name.nil? && !node['metadata']['name'].nil? && node_name == node['metadata']['name']
                        if !node["metadata"].nil? && !node["metadata"]["labels"].nil?
                            monitor_labels = monitor_labels.merge(node["metadata"]["labels"])
                        end
                    end
                end
            end
            return monitor_labels
        end

        def get_node_labels(node_name)
            monitor_labels = {}
            @health_kubernetes_resources.get_node_inventory['items'].each do |node|
                if !node_name.nil? && !node['metadata']['name'].nil? && node_name == node['metadata']['name']
                    if !node["metadata"].nil? && !node["metadata"]["labels"].nil?
                        monitor_labels = node["metadata"]["labels"]
                    end
                end
            end
            return monitor_labels
        end
    end
end