require_relative '../test_helpers'
Dir[File.join(File.expand_path(File.dirname(__FILE__)), "../../../../source/code/plugin/health/*.rb")].reject{|f| f.include?('health_monitor_utils')}.each { |file| require file }
include HealthModel

describe 'HealthContainerCpuMemoryAggregator spec' do

    it 'dedupes and drops older records' do
        formatted_records = JSON.parse'[{
            "InstanceName": "/subscriptions/72c8e8ca-dc16-47dc-b65c-6b5875eb600a/resourcegroups/dilipr-health-test/providers/Microsoft.ContainerService/managedClusters/dilipr-health-test/952488f3-a1f2-11e9-8b08-d602e29755d5/sidecar",
            "CounterName": "memoryRssBytes",
            "CounterValue": 14061568,
            "Timestamp": "2019-08-23T23:13:39Z"
        },
        {
            "InstanceName": "/subscriptions/72c8e8ca-dc16-47dc-b65c-6b5875eb600a/resourcegroups/dilipr-health-test/providers/Microsoft.ContainerService/managedClusters/dilipr-health-test/952488f3-a1f2-11e9-8b08-d602e29755d5/sidecar",
            "CounterName": "memoryRssBytes",
            "CounterValue": 14061568,
            "Timestamp": "2019-08-23T22:13:39Z"
        }]'

        resources = HealthKubernetesResources.instance
        nodes = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'nodes.json')))
        pods = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'pods.json')))
        deployments = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'deployments.json')))

        resources.pod_inventory = pods
        resources.node_inventory = nodes
        resources.set_deployment_inventory(deployments)
        resources.build_pod_uid_lookup #call this in in_kube_health every min

        cluster_labels = {
            'container.azm.ms/cluster-region' => 'eastus',
            'container.azm.ms/cluster-subscription-id' => '72c8e8ca-dc16-47dc-b65c-6b5875eb600a',
            'container.azm.ms/cluster-resource-group' => 'dilipr-health-test',
            'container.azm.ms/cluster-name' => 'dilipr-health-test'
        }
        cluster_id = 'fake_cluster_id'
        provider = HealthMonitorProvider.new(cluster_id, cluster_labels, resources, File.join(__dir__, "../../../../installer/conf/healthmonitorconfig.json"))
        aggregator = HealthContainerCpuMemoryAggregator.new(resources, provider)
        deduped_records = aggregator.dedupe_records(formatted_records)
        deduped_records.size.must_equal 1
        deduped_records[0]["Timestamp"].must_equal "2019-08-23T23:13:39Z"
    end

    it 'aggregates based on container name' do
        file = File.read(File.join(File.expand_path(File.dirname(__FILE__)),'cadvisor_perf.json'))
        records = JSON.parse(file)
        records = records.select{|record| record['DataItems'][0]['ObjectName'] == 'K8SContainer'}
        formatted_records = []
        formatter = HealthContainerCpuMemoryRecordFormatter.new
        records.each{|record|
            formatted_record = formatter.get_record_from_cadvisor_record(record)
            formatted_records.push(formatted_record)
        }

        resources = HealthKubernetesResources.instance
        nodes = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'nodes.json')))
        pods = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'pods.json')))
        deployments = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'deployments.json')))

        resources.pod_inventory = pods
        resources.node_inventory = nodes
        resources.set_deployment_inventory(deployments)
        resources.build_pod_uid_lookup #call this in in_kube_health every min

        cluster_labels = {
            'container.azm.ms/cluster-region' => 'eastus',
            'container.azm.ms/cluster-subscription-id' => '72c8e8ca-dc16-47dc-b65c-6b5875eb600a',
            'container.azm.ms/cluster-resource-group' => 'dilipr-health-test',
            'container.azm.ms/cluster-name' => 'dilipr-health-test'
        }

        cluster_id = 'fake_cluster_id'

        provider = HealthMonitorProvider.new(cluster_id, cluster_labels, resources, File.join(__dir__, "../../../../installer/conf/healthmonitorconfig.json"))

        aggregator = HealthContainerCpuMemoryAggregator.new(resources, provider)
        deduped_records = aggregator.dedupe_records(formatted_records)
        aggregator.aggregate(deduped_records)
        aggregator.compute_state
        records = aggregator.get_records
        records.size.must_equal 30
        #records have all the required details
        records.each{|record|
            record["Details"]["details"]["container"].wont_be_nil
            record["Details"]["details"]["workload_name"].wont_be_nil
            record["Details"]["details"]["workload_kind"].wont_be_nil
            record["Details"]["details"]["namespace"].wont_be_nil
            record["Details"]["timestamp"].wont_be_nil
            record["Details"]["state"].wont_be_nil
            record["MonitorTypeId"].wont_be_nil
            record["MonitorInstanceId"].wont_be_nil
            record["TimeFirstObserved"].wont_be_nil
            record["TimeGenerated"].wont_be_nil
        }
    end

    it "calculates the state correctly" do
        file = File.read(File.join(File.expand_path(File.dirname(__FILE__)),'cadvisor_perf.json'))
        records = JSON.parse(file)
        records = records.select{|record| record['DataItems'][0]['ObjectName'] == 'K8SContainer'}
        formatted_records = []
        formatter = HealthContainerCpuMemoryRecordFormatter.new
        records.each{|record|
            formatted_record = formatter.get_record_from_cadvisor_record(record)
            formatted_records.push(formatted_record)
        }

        resources = HealthKubernetesResources.instance
        nodes = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'nodes.json')))
        pods = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'pods.json')))
        deployments = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'deployments.json')))

        resources.pod_inventory = pods
        resources.node_inventory = nodes
        resources.set_deployment_inventory(deployments)
        resources.build_pod_uid_lookup #call this in in_kube_health every min

        cluster_labels = {
            'container.azm.ms/cluster-region' => 'eastus',
            'container.azm.ms/cluster-subscription-id' => '72c8e8ca-dc16-47dc-b65c-6b5875eb600a',
            'container.azm.ms/cluster-resource-group' => 'dilipr-health-test',
            'container.azm.ms/cluster-name' => 'dilipr-health-test'
        }

        cluster_id = 'fake_cluster_id'

        provider = HealthMonitorProvider.new(cluster_id, cluster_labels, resources, File.join(__dir__, "../../../../installer/conf/healthmonitorconfig.json"))

        aggregator = HealthContainerCpuMemoryAggregator.new(resources, provider)
        deduped_records = aggregator.dedupe_records(formatted_records)
        aggregator.aggregate(deduped_records)
        aggregator.compute_state
        records = aggregator.get_records

        #omsagent has limit set. So its state should be set to pass.
        #sidecar has no limit set. its state should be set to warning
        omsagent_record = records.select{|r| r["MonitorTypeId"] == MonitorId::CONTAINER_CPU_MONITOR_ID && r["Details"]["details"]["container"] == "omsagent"}[0]
        sidecar_record = records.select{|r| r["MonitorTypeId"] == MonitorId::CONTAINER_CPU_MONITOR_ID && r["Details"]["details"]["container"] == "sidecar"}[0]
        omsagent_record['Details']['state'].must_equal HealthMonitorStates::PASS #limit is set
        sidecar_record['Details']['state'].must_equal HealthMonitorStates::PASS
    end


    it "calculates the state as unknown when signals are missing" do
        file = File.read(File.join(File.expand_path(File.dirname(__FILE__)),'cadvisor_perf.json'))
        records = JSON.parse(file)
        records = records.select{|record| record['DataItems'][0]['ObjectName'] == 'K8SContainer'}
        formatted_records = []
        formatter = HealthContainerCpuMemoryRecordFormatter.new
        records.each{|record|
            formatted_record = formatter.get_record_from_cadvisor_record(record)
            formatted_records.push(formatted_record)
        }

        formatted_records = formatted_records.reject{|r| r["InstanceName"] == "/subscriptions/72c8e8ca-dc16-47dc-b65c-6b5875eb600a/resourcegroups/dilipr-health-test/providers/Microsoft.ContainerService/managedClusters/dilipr-health-test/69e68b21-c5df-11e9-8736-86290fd7dd1f/omsagent" && r["CounterName"] == "cpuUsageNanoCores"}
        formatted_records = formatted_records.reject{|r| r["InstanceName"] == "/subscriptions/72c8e8ca-dc16-47dc-b65c-6b5875eb600a/resourcegroups/dilipr-health-test/providers/Microsoft.ContainerService/managedClusters/dilipr-health-test/b1e04e1c-c5df-11e9-8736-86290fd7dd1f/omsagent" && r["CounterName"] == "cpuUsageNanoCores"}

        resources = HealthKubernetesResources.instance
        nodes = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'nodes.json')))
        pods = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'pods.json')))
        deployments = JSON.parse(File.read(File.join(File.expand_path(File.dirname(__FILE__)),'deployments.json')))

        resources.pod_inventory = pods
        resources.node_inventory = nodes
        resources.set_deployment_inventory(deployments)
        resources.build_pod_uid_lookup #call this in in_kube_health every min

        cluster_labels = {
            'container.azm.ms/cluster-region' => 'eastus',
            'container.azm.ms/cluster-subscription-id' => '72c8e8ca-dc16-47dc-b65c-6b5875eb600a',
            'container.azm.ms/cluster-resource-group' => 'dilipr-health-test',
            'container.azm.ms/cluster-name' => 'dilipr-health-test'
        }

        cluster_id = 'fake_cluster_id'

        provider = HealthMonitorProvider.new(cluster_id, cluster_labels, resources, File.join(__dir__, "../../../../installer/conf/healthmonitorconfig.json"))

        aggregator = HealthContainerCpuMemoryAggregator.new(resources, provider)
        deduped_records = aggregator.dedupe_records(formatted_records)
        aggregator.aggregate(deduped_records)
        aggregator.compute_state
        records = aggregator.get_records

        #removed(missed) omsagent records should result in state being unknown
        omsagent_record = records.select{|r| r["MonitorTypeId"] == MonitorId::CONTAINER_CPU_MONITOR_ID && r["Details"]["details"]["container"] == "omsagent" && !r["Details"]["details"]["workload_name"].include?("omsagent-rs") }[0]
        omsagent_record['Details']['state'].must_equal HealthMonitorStates::UNKNOWN #limit is set
    end
end