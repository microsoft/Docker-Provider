require_relative '../test_helpers'
Dir[File.join(File.expand_path(File.dirname(__FILE__)), "../../../../source/code/plugin/health/*.rb")].reject{|f| f.include?('health_monitor_utils')}.each { |file| require file }
include HealthModel
include Minitest

describe "HealthContainerCpuMemoryRecordFormatter spec" do
    it 'returns the record in expected format when cadvisor record is well formed' do
        formatter = HealthContainerCpuMemoryRecordFormatter.new
        cadvisor_record = JSON.parse('{
            "DataItems": [
              {
                "Timestamp": "2019-08-01T23:19:19Z",
                "Host": "aks-nodepool1-19574989-2",
                "ObjectName": "K8SContainer",
                "InstanceName": "/subscriptions/72c8e8ca-dc16-47dc-b65c-6b5875eb600a/resourceGroups/dilipr-health-test/providers/Microsoft.ContainerService/managedClusters/dilipr-health-test/6708e4ac-b49a-11e9-8a49-52a94e80d897/omsagent",
                "Collections": [
                  {
                    "CounterName": "memoryWorkingSetBytes",
                    "Value": 85143552
                  }
                ]
              }
            ],
            "DataType": "LINUX_PERF_BLOB",
            "IPName": "LogManagement"
          }')
        record = formatter.get_record_from_cadvisor_record(cadvisor_record)
        record.wont_equal nil
        record["InstanceName"].must_equal "/subscriptions/72c8e8ca-dc16-47dc-b65c-6b5875eb600a/resourceGroups/dilipr-health-test/providers/Microsoft.ContainerService/managedClusters/dilipr-health-test/6708e4ac-b49a-11e9-8a49-52a94e80d897/omsagent"
        record["CounterName"].must_equal "memoryWorkingSetBytes"
        record["CounterValue"].must_equal 85143552
        record["Timestamp"].must_equal "2019-08-01T23:19:19Z"
    end

    it 'returns nil for invalid cadvisor record' do
        formatter = HealthContainerCpuMemoryRecordFormatter.new
        cadvisor_record = JSON.parse('{
            "DataItms": [
              {
                "Timestamp": "2019-08-01T23:19:19Z",
                "Host": "aks-nodepool1-19574989-2",
                "ObjectName": "K8SContainer",
                "InstanceName": "/subscriptions/72c8e8ca-dc16-47dc-b65c-6b5875eb600a/resourceGroups/dilipr-health-test/providers/Microsoft.ContainerService/managedClusters/dilipr-health-test/6708e4ac-b49a-11e9-8a49-52a94e80d897/omsagent",
                "Collections": [
                  {
                    "CounterName": "memoryWorkingSetBytes",
                    "Value": 85143552
                  }
                ]
              }
            ],
            "DataType": "LINUX_PERF_BLOB",
            "IPName": "LogManagement"
          }')
        record = formatter.get_record_from_cadvisor_record(cadvisor_record)
        record.must_be_nil
    end
end