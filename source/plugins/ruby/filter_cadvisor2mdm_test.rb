# require 'minitest/autorun'
# require 'fluent/test'
# require 'fluent/test/driver/filter'
# require 'fluent/test/helpers'
# require_relative 'filter_cadvisor2mdm.rb'
# require_relative 'KubernetesApiClient'
# require 'byebug'


# # This is one way to stub a class. It's longer than the method demonstrated in in_kube_nodes_test.rb but gives more control
# # over how the stub behaves
# class Ai_utility_stub
#   class << self
#     def sendCustomEvent(a, b)
#     end

#     def sendExceptionTelemetry (errorstr)
#       # this shouldn't happen, why was there an exception?
#       byebug
#     end
#   end
# end

# class KubernetesApiClientMock < KubernetesApiClient
#   class GetNodesResponse
#     def body
#       return File.open("test/unit-tests/canned-api-responses/get_nodes_response_2.json").read
#     end
#   end
#   class << self
#     def getKubeResourceInfo(resource, api_group: nil)
#       if resource == "nodes?fieldSelector=metadata.name%3DWIN-T14B9CT7KMS"
#         return GetNodesResponse.new()
#       end
#       # this means that a saved input is missing
#       byebug
#     end
#   end
# end



# class FilterCadvisor2MdmTests < Minitest::Test
#     include Fluent::Test::Helpers

#     def setup
#       Fluent::Test.setup
#     end
  
#     def create_driver(conf = "")
#       Fluent::Test::Driver::Filter.new(Fluent::Plugin::CAdvisor2MdmFilter).configure(conf)
#     end
  
#     # A relatively simple test for a helper method
#     def test_build_metrics_hash
#       instance = create_driver.instance

#       expected = {"constants::cpu_usage_nano_cores" => true, "constants::memory_working_set_bytes" => true, "constants::memory_rss_bytes"=> true, "constants::pv_used_bytes"=> true}
#       actual = instance.build_metrics_hash "Constants::CPU_USAGE_NANO_CORES,Constants::MEMORY_WORKING_SET_BYTES,Constants::MEMORY_RSS_BYTES,Constants::PV_USED_BYTES"
#       assert_equal(expected, actual)

#       assert_equal({}, instance.build_metrics_hash(""))

#       assert_equal({"test_input:.<>" => true}, instance.build_metrics_hash("test_input:.<>"))
#     end


#     # a much more complicated test for the filter method of filter_cadvisor2mdm (this is an allup test)
#     def test_filter


#       env = {"CONTROLLER_TYPE" => "ReplicaSet",
#                                     "OS_TYPE" => "linux",
#                                     "AZMON_ALERT_CONTAINER_CPU_THRESHOLD" => Constants::DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD.to_s,
#                                     "AZMON_ALERT_CONTAINER_MEMORY_RSS_THRESHOLD" => Constants::DEFAULT_MDM_MEMORY_RSS_THRESHOLD.to_s,
#                                     "AZMON_ALERT_CONTAINER_MEMORY_WORKING_SET_THRESHOLD" => Constants::DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD.to_s,
#                                     "AZMON_ALERT_PV_USAGE_THRESHOLD" => Constants::DEFAULT_MDM_PV_UTILIZATION_THRESHOLD.to_s,
#                                     "AZMON_ALERT_JOB_COMPLETION_TIME_THRESHOLD" => Constants::DEFAULT_MDM_JOB_COMPLETED_TIME_THRESHOLD_MINUTES.to_s,
#                                     "AKS_REGION" => "westus2",
#                                     "AKS_RESOURCE_ID" => "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx/resourceGroups/rg/providers/Microsoft.ContainerService/managedClusters/clustername",
#                                     "CLOUD_ENVIRONMENT" => "azurepubliccloud"}  # TODO: this is actually set to public in running containers. Figure out how @process_incoming_stream resolves to true
#       applicationInsightsUtility = Ai_utility_stub.new()
#       kubernetesApiClient = KubernetesApiClientMock

#       oms_common = Minitest::Mock.new
#       oms_common.expect(:get_hostname, "aks-nodepool1-24816391-vmss000000")

#       config = %[
#                   metrics_to_collect cpuUsageNanoCores,memoryWorkingSetBytes,pvUsedBytes
#                   @log_level info
#                 ]

#       data = [
#         {"tag" => "mdm.cadvisorperf", "time" => 1629337471, "data" => {"Timestamp"=>"2021-08-19T01:44:31Z", "Host"=>"aks-nodepool1-24031368-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"/subscriptions/9b96ebbd-c57a-42d1-bbe9-b69296e4c7fb/resourceGroups/davidbuild1/providers/Microsoft.ContainerService/managedClusters/davidbuild1/aks-nodepool1-24031368-vmss000000", "json_Collections"=>"[{\"CounterName\":\"memoryRssBytes\",\"Value\":511778816}]"}}
#       ]

#       expected_output = [
#         {"time"=>"2021-08-19T01:44:31Z", "data"=>{"baseData"=>{"metric"=>"memoryRssBytes", "namespace"=>"Insights.Container/nodes", "dimNames"=>["host"], "series"=>[{"dimValues"=>["aks-nodepool1-24031368-vmss000000"], "min"=>511778816, "max"=>511778816, "sum"=>511778816, "count"=>1}]}}},
#         {"time"=>"2021-08-19T01:44:31Z", "data"=>{"baseData"=>{"metric"=>"memoryRssPercentage", "namespace"=>"Insights.Container/nodes", "dimNames"=>["host"], "series"=>[{"dimValues"=>["aks-nodepool1-24031368-vmss000000"], "min"=>7.018830955074673, "max"=>7.018830955074673, "sum"=>7.018830955074673, "count"=>1}]}}}
#       ]

#       d = create_driver(config)
#       # TODO: why doesn't the fluentd test harness call start automatically?
#       d.instance.start(env=env, applicationInsightsUtility=applicationInsightsUtility, kubernetesApiClient=kubernetesApiClient, oms_common=oms_common)
#       time = event_time

#       # byebug
#       d.run do
#         d.feed(data[0]["tag"], time, data[0]["data"])
#       end

#       puts d.filtered_records.size
#       puts d.filtered_records

#       assert_equal(0, d.filtered_records.size)
#       # assert_equal("expected response", d.filtered_records)
#     end
# end
