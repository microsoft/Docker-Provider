module HealthModel
    class HealthContainerCpuMemoryRecordFormatter

        @@health_container_cpu_memory_record_template = '{
                "InstanceName": "%{instance_name}",
                "CounterName" : "%{counter_name}",
                "CounterValue" : %{metric_value},
                "Timestamp" : "%{timestamp}"
            }'
        def initialize
            @log = HealthMonitorHelpers.get_log_handle
        end

        def get_record_from_cadvisor_record(cadvisor_record)
            begin
                instance_name = cadvisor_record['DataItems'][0]['InstanceName']
                counter_name = cadvisor_record['DataItems'][0]['Collections'][0]['CounterName']
                metric_value = cadvisor_record['DataItems'][0]['Collections'][0]['Value']
                timestamp = cadvisor_record['DataItems'][0]['Timestamp']

                health_container_cpu_memory_record = @@health_container_cpu_memory_record_template % {
                    instance_name: instance_name,
                    counter_name: counter_name,
                    metric_value: metric_value,
                    timestamp: timestamp
                }
                return JSON.parse(health_container_cpu_memory_record)
            rescue => e
                @log.info "Error in get_record_from_cadvisor_record #{e.message} #{e.backtrace}"
                return nil
            end
        end
    end
end