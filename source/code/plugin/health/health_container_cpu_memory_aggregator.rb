require_relative 'health_model_constants'
=begin
    @cpu_records/@memory_records
        [
            {
            "namespace_workload_container_name" : {
                "limit" : limit, #number
                "limit_set" : limit_set, #bool
                "record_count" : record_count, #number
                "workload_name": workload_name,
                "workload_kind": workload_kind,
                "namespace" : namespace,
                "container": container,
                records:[
                    {
                        "counter_value": counter_value,
                        "pod_name": pod_name,
                        "container": container,
                        "state" : state
                    },
                    {
                        "counter_value": counter_value,
                        "pod_name": pod_name,
                        "container": container,
                        "state" : state
                    }
                ]
            }
        }
    ]
=end
module HealthModel
    # this class aggregates the records at the container level
    class HealthContainerCpuMemoryAggregator

        attr_reader :pod_uid_lookup, :workload_container_count, :cpu_records, :memory_records, :provider

        @@memory_counter_name = 'memoryRssBytes'
        @@cpu_counter_name = 'cpuUsageNanoCores'
        def initialize(resources, provider)
            @pod_uid_lookup = resources.get_pod_uid_lookup
            @workload_container_count = resources.get_workload_container_count
            @cpu_records = {}
            @memory_records = {}
            @log = HealthMonitorHelpers.get_log_handle
            @provider = provider
        end

        def dedupe_records(container_records)
            cpu_deduped_instances = {}
            memory_deduped_instances = {}
            container_records = container_records.select{|record| record['CounterName'] == @@memory_counter_name || record['CounterName'] == @@cpu_counter_name}

            container_records.each do |record|
                begin
                    instance_name = record["InstanceName"]
                    counter_name = record["CounterName"]
                    case counter_name
                    when @@memory_counter_name
                        resource_instances = memory_deduped_instances
                    when @@cpu_counter_name
                        resource_instances = cpu_deduped_instances
                    else
                        @log.info "Unexpected Counter Name #{counter_name}"
                        next
                    end
                    if !resource_instances.key?(instance_name)
                        resource_instances[instance_name] = record
                    else
                        r = resource_instances[instance_name]
                        if record["Timestamp"] > r["Timestamp"]
                            @log.info "Dropping older record"
                            resource_instances[instance_name] = record
                        end
                    end
                rescue => e
                    @log.info "Exception when deduping record #{record}"
                end
            end
            return cpu_deduped_instances.values.concat(memory_deduped_instances.values)
        end

        def aggregate(container_records)
            #filter and select only cpuUsageNanoCores and memoryRssBytes
            container_records = container_records.select{|record| record['CounterName'] == @@memory_counter_name || record['CounterName'] == @@cpu_counter_name}
            # poduid lookup has poduid/cname --> workload_name, namespace, cpu_limit, memory limit mapping
            # from the container records, extract the poduid/cname, get the values from poduid_lookup, and aggregate based on namespace_workload_cname
            container_records.each do |record|
                begin
                    instance_name = record["InstanceName"]
                    lookup_key = instance_name.split('/').last(2).join('/')
                    if !@pod_uid_lookup.key?(lookup_key)
                        next
                    end
                    namespace = @pod_uid_lookup[lookup_key]['namespace']
                    workload_name = @pod_uid_lookup[lookup_key]['workload_name']
                    cname = lookup_key.split('/')[1]
                    counter_name = record["CounterName"]
                    case counter_name
                    when @@memory_counter_name
                        resource_hash = @memory_records
                        resource_type = 'memory'
                    when @@cpu_counter_name
                        resource_hash = @cpu_records
                        resource_type = 'cpu'
                    else
                        @log.info "Unexpected Counter Name #{counter_name}"
                        next
                    end

                    # this is used as a look up from the pod_uid_lookup in kubernetes_health_resources object
                    resource_hash_key = "#{namespace}_#{workload_name.split('~~')[1]}_#{cname}"

                    # if the resource map doesnt contain the key, add limit, count and records
                    if !resource_hash.key?(resource_hash_key)
                        resource_hash[resource_hash_key] = {}
                        resource_hash[resource_hash_key]["limit"] = @pod_uid_lookup[lookup_key]["#{resource_type}_limit"]
                        resource_hash[resource_hash_key]["limit_set"] = @pod_uid_lookup[lookup_key]["#{resource_type}_limit_set"]
                        resource_hash[resource_hash_key]["record_count"] = @workload_container_count[resource_hash_key]
                        resource_hash[resource_hash_key]["workload_name"] = @pod_uid_lookup[lookup_key]["workload_name"]
                        resource_hash[resource_hash_key]["workload_kind"] = @pod_uid_lookup[lookup_key]["workload_kind"]
                        resource_hash[resource_hash_key]["namespace"] = @pod_uid_lookup[lookup_key]["namespace"]
                        resource_hash[resource_hash_key]["container"] = @pod_uid_lookup[lookup_key]["container"]
                        resource_hash[resource_hash_key]["records"] = []
                    end

                    container_instance_record = {}

                    pod_name = @pod_uid_lookup[lookup_key]["pod_name"]
                    #append the record to the hash
                    # append only if the record is not a duplicate record
                    container_instance_record["pod_name"] = pod_name
                    container_instance_record["counter_value"] = record["CounterValue"]
                    container_instance_record["container"] = @pod_uid_lookup[lookup_key]["container"]
                    container_instance_record["state"] = calculate_container_instance_state(
                        container_instance_record["counter_value"],
                        resource_hash[resource_hash_key]["limit"],
                        @provider.get_config(MonitorId::CONTAINER_MEMORY_MONITOR_ID))
                    resource_hash[resource_hash_key]["records"].push(container_instance_record)
                rescue => e
                    @log.info "Error in HealthContainerCpuMemoryAggregator aggregate #{e.backtrace} #{e.message} #{record}"
                end
            end
        end

        def compute_state()
            # if missing records, set state to unknown
            # if limits not set, set state to warning
            # if all records present, sort in descending order of metric, compute index based on StateThresholdPercentage, get the state (pass/fail/warn) based on monitor state (Using [Fail/Warn]ThresholdPercentage, and set the state)
            @memory_records.each{|k,v|
                calculate_monitor_state(v, @provider.get_config(MonitorId::CONTAINER_MEMORY_MONITOR_ID))
            }

            @cpu_records.each{|k,v|
                calculate_monitor_state(v, @provider.get_config(MonitorId::CONTAINER_CPU_MONITOR_ID))
            }

            @log.info "Finished computing state"
        end

        def get_records
            time_now = Time.now.utc.iso8601
            container_cpu_memory_records = []

            @cpu_records.each{|resource_key, record|
                health_monitor_record = {
                    "timestamp" => time_now,
                    "state" => record["state"],
                    "details" => {
                        "cpu_limit_millicores" => record["limit"]/1000000.to_f,
                        "cpu_usage_instances" => record["records"].map{|r| r.each {|k,v|
                            k == "counter_value" ? r[k] = r[k] / 1000000.to_f : r[k]
                        }},
                        "workload_name" => record["workload_name"],
                        "workload_kind" => record["workload_kind"],
                        "namespace" => record["namespace"],
                        "container" => record["container"],
                        "limit_set" => record["limit_set"]
                        }
                    }

                monitor_instance_id = HealthMonitorHelpers.get_monitor_instance_id(MonitorId::CONTAINER_CPU_MONITOR_ID, resource_key.split('_')) #container_cpu_utilization-namespace-workload-container

                health_record = {}
                health_record[HealthMonitorRecordFields::MONITOR_ID] = MonitorId::CONTAINER_CPU_MONITOR_ID
                health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
                health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
                health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
                health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
                container_cpu_memory_records.push(health_record)
            }

            @memory_records.each{|resource_key, record|
                health_monitor_record = {
                    "timestamp" => time_now,
                    "state" => record["state"],
                    "details" => {
                        "memory_limit_bytes" => record["limit"],
                        "memory_usage_instances" => record["records"],
                        "workload_name" => record["workload_name"],
                        "workload_kind" => record["workload_kind"],
                        "namespace" => record["namespace"],
                        "container" => record["container"]
                        }
                    }

                monitor_instance_id = HealthMonitorHelpers.get_monitor_instance_id(MonitorId::CONTAINER_MEMORY_MONITOR_ID, resource_key.split('_')) #container_cpu_utilization-namespace-workload-container

                health_record = {}
                health_record[HealthMonitorRecordFields::MONITOR_ID] = MonitorId::CONTAINER_MEMORY_MONITOR_ID
                health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
                health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
                health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
                health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
                container_cpu_memory_records.push(health_record)
            }
            return container_cpu_memory_records
        end

        private
        def calculate_monitor_state(v, config)
            if !v['limit_set'] && v['namespace'] != 'kube-system'
                v["state"] = HealthMonitorStates::WARNING
            else
                # sort records by descending order of metric
                v["records"] = v["records"].sort_by{|record| record["counter_value"]}.reverse
                size = v["records"].size
                if size < v["record_count"]
                    unknown_count = v["record_count"] - size
                    for i in unknown_count.downto(1)
                        # it requires a lot of computation to figure out which actual pod is not sending the signal
                        v["records"].insert(0, {"counter_value" => -1, "container" => v["container"], "pod_name" =>  "???", "state" => HealthMonitorStates::UNKNOWN }) #insert -1 for unknown records
                    end
                end

                if size == 1
                    state_index = 0
                else
                    state_threshold = config['StateThresholdPercentage'].to_f
                    count = ((state_threshold*size)/100).ceil
                    state_index = size - count
                end
                v["state"] = v["records"][state_index]["state"]
            end
        end

        def calculate_container_instance_state(counter_value, limit, config)
            percent_value = counter_value * 100  / limit
            if percent_value > config['FailThresholdPercentage']
                return HealthMonitorStates::FAIL
            elsif percent_value > config['WarnThresholdPercentage']
                return HealthMonitorStates::WARN
            else
                return HealthMonitorStates::PASS
            end
        end
    end
end