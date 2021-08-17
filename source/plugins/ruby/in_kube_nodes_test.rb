# TODO: can we get rid of this global flag
$in_unit_test = true

require 'minitest/autorun'

require 'fluent/test'
require 'fluent/test/driver/input'
require 'fluent/test/helpers'

require_relative 'in_kube_nodes.rb'
require 'byebug'

class MyInputTest < Minitest::Test
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf = {}, kubernetesApiClient=nil, applicationInsightsUtility=nil, extensionUtils=nil, env=nil)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::Kube_nodeInventory_Input.new(kubernetesApiClient=kubernetesApiClient,
                                                                             applicationInsightsUtility=applicationInsightsUtility,
                                                                             extensionUtils=extensionUtils,
                                                                             env=env)).configure(conf)
  end

  def overwrite_collection_time(data) 
    if data.key?("CollectionTime")
        data["CollectionTime"] = "~CollectionTime~"
    end
    if data.key?("Timestamp")
        data["Timestamp"] = "~Timestamp~"
    end
    return data
  end

  def test_basic_single_node
    kubeApiClient = Minitest::Mock.new
    appInsightsUtil = Minitest::Mock.new
    extensionUtils = Minitest::Mock.new
    env = {}
    env["NODES_CHUNK_SIZE"] = "200"

    kubeApiClient.expect(:==, false, [nil])
    appInsightsUtil.expect(:==, false, [nil])
    extensionUtils.expect(:==, false, [nil])

    # isAADMSIAuthMode() is called multiple times and we don't really care how many time it is called. This is the same as mocking
    # but it doesn't track how many times isAADMSIAuthMode is called
    def extensionUtils.isAADMSIAuthMode
        false
    end

    nodes_api_response = eval(File.open("../../../test/unit-tests/canned-api-responses/kube-nodes.txt").read)
    kubeApiClient.expect(:getResourcesAndContinuationToken, [nil, nodes_api_response], ["nodes?limit=200"])
    kubeApiClient.expect(:getClusterName, "/cluster-name")
    kubeApiClient.expect(:getClusterId, "/cluster-id")

    config = "run_interval 999999999"  # only run once

    d = create_driver(config, kubernetesApiClient=kubeApiClient, applicationInsightsUtility=appInsightsUtil, extensionUtils=extensionUtils, env=env)
    d.instance.start
    d.instance.enumerate
    d.run(timeout: 99999)  # Input plugins decide when to run, so we have to give it enough time to run


    expected_responses = { ["oneagent.containerInsights.KUBE_NODE_INVENTORY_BLOB", overwrite_collection_time({"CollectionTime"=>"2021-08-17T20:24:18Z", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ClusterName"=>"/cluster-name", "ClusterId"=>"/cluster-id", "CreationTimeStamp"=>"2021-07-21T23:40:14Z", "Labels"=>[{"agentpool"=>"nodepool1", "beta.kubernetes.io/arch"=>"amd64", "beta.kubernetes.io/instance-type"=>"Standard_DS2_v2", "beta.kubernetes.io/os"=>"linux", "failure-domain.beta.kubernetes.io/region"=>"westus2", "failure-domain.beta.kubernetes.io/zone"=>"0", "kubernetes.azure.com/cluster"=>"MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode"=>"system", "kubernetes.azure.com/node-image-version"=>"AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku"=>"Ubuntu", "kubernetes.azure.com/role"=>"agent", "kubernetes.io/arch"=>"amd64", "kubernetes.io/hostname"=>"aks-nodepool1-24816391-vmss000000", "kubernetes.io/os"=>"linux", "kubernetes.io/role"=>"agent", "node-role.kubernetes.io/agent"=>"", "node.kubernetes.io/instance-type"=>"Standard_DS2_v2", "storageprofile"=>"managed", "storagetier"=>"Premium_LRS", "topology.kubernetes.io/region"=>"westus2", "topology.kubernetes.io/zone"=>"0"}], "Status"=>"Ready", "KubernetesProviderID"=>"azure", "LastTransitionTimeReady"=>"2021-07-21T23:40:24Z", "KubeletVersion"=>"v1.19.11", "KubeProxyVersion"=>"v1.19.11"})] => true,
    ["mdm.kubenodeinventory", overwrite_collection_time({"CollectionTime"=>"2021-08-17T20:24:18Z", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ClusterName"=>"/cluster-name", "ClusterId"=>"/cluster-id", "CreationTimeStamp"=>"2021-07-21T23:40:14Z", "Labels"=>[{"agentpool"=>"nodepool1", "beta.kubernetes.io/arch"=>"amd64", "beta.kubernetes.io/instance-type"=>"Standard_DS2_v2", "beta.kubernetes.io/os"=>"linux", "failure-domain.beta.kubernetes.io/region"=>"westus2", "failure-domain.beta.kubernetes.io/zone"=>"0", "kubernetes.azure.com/cluster"=>"MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode"=>"system", "kubernetes.azure.com/node-image-version"=>"AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku"=>"Ubuntu", "kubernetes.azure.com/role"=>"agent", "kubernetes.io/arch"=>"amd64", "kubernetes.io/hostname"=>"aks-nodepool1-24816391-vmss000000", "kubernetes.io/os"=>"linux", "kubernetes.io/role"=>"agent", "node-role.kubernetes.io/agent"=>"", "node.kubernetes.io/instance-type"=>"Standard_DS2_v2", "storageprofile"=>"managed", "storagetier"=>"Premium_LRS", "topology.kubernetes.io/region"=>"westus2", "topology.kubernetes.io/zone"=>"0"}], "Status"=>"Ready", "KubernetesProviderID"=>"azure", "LastTransitionTimeReady"=>"2021-07-21T23:40:24Z", "KubeletVersion"=>"v1.19.11", "KubeProxyVersion"=>"v1.19.11"})] => true,
    ["oneagent.containerInsights.CONTAINER_NODE_INVENTORY_BLOB", overwrite_collection_time({"CollectionTime"=>"2021-08-17T20:24:18Z", "Computer"=>"aks-nodepool1-24816391-vmss000000", "OperatingSystem"=>"Ubuntu 18.04.5 LTS", "DockerVersion"=>"containerd://1.4.4+azure"})] => true,
    ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({"Timestamp"=>"2021-08-17T20:24:18Z", "Host"=>"aks-nodepool1-24816391-vmss000000", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"None/aks-nodepool1-24816391-vmss000000", "json_Collections"=>"[{\"CounterName\":\"cpuAllocatableNanoCores\",\"Value\":1900000000.0}]"})] => true,
    ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({"Timestamp"=>"2021-08-17T20:24:18Z", "Host"=>"aks-nodepool1-24816391-vmss000000", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"None/aks-nodepool1-24816391-vmss000000", "json_Collections"=>"[{\"CounterName\":\"memoryAllocatableBytes\",\"Value\":4787511296.0}]"})] => true,
    ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({"Timestamp"=>"2021-08-17T20:24:18Z", "Host"=>"aks-nodepool1-24816391-vmss000000", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"None/aks-nodepool1-24816391-vmss000000", "json_Collections"=>"[{\"CounterName\":\"cpuCapacityNanoCores\",\"Value\":2000000000.0}]"})] => true,
    ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({"Timestamp"=>"2021-08-17T20:24:18Z", "Host"=>"aks-nodepool1-24816391-vmss000000", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"None/aks-nodepool1-24816391-vmss000000", "json_Collections"=>"[{\"CounterName\":\"memoryCapacityBytes\",\"Value\":7291510784.0}]"})] => true}

    d.events.each do |tag, time, record|
        cleaned_record = overwrite_collection_time record
        if expected_responses.key?([tag, cleaned_record])
            assert_equal(true, true)
        else
            assert_equal(true, false) 
        end
    end

    kubeApiClient.verify
    appInsightsUtil.verify
    extensionUtils.verify
  end


  def test_malformed_node_spec
    kubeApiClient = Minitest::Mock.new
    appInsightsUtil = Minitest::Mock.new
    extensionUtils = Minitest::Mock.new
    env = {}
    env["NODES_CHUNK_SIZE"] = "200"

    kubeApiClient.expect(:==, false, [nil])
    appInsightsUtil.expect(:==, false, [nil])
    extensionUtils.expect(:==, false, [nil])

    # isAADMSIAuthMode() is called multiple times and we don't really care how many time it is called. This is the same as mocking
    # but it doesn't track how many times isAADMSIAuthMode is called
    def extensionUtils.isAADMSIAuthMode
        false
    end

    nodes_api_response = eval(File.open("../../../test/unit-tests/canned-api-responses/kube-nodes-malformed.txt").read)
    kubeApiClient.expect(:getResourcesAndContinuationToken, [nil, nodes_api_response], ["nodes?limit=200"])
    kubeApiClient.expect(:getClusterName, "/cluster-name")
    kubeApiClient.expect(:getClusterId, "/cluster-id")

    config = "run_interval 999999999"  # only run once

    d = create_driver(config, kubernetesApiClient=kubeApiClient, applicationInsightsUtility=appInsightsUtil, extensionUtils=extensionUtils, env=env)
    d.instance.start
    d.instance.set_telemetry_flush_interval(0)
    
    byebug

    d.instance.enumerate
    d.run(timeout: 99999)  # Input plugins decide when to run, so we have to give it enough time to run


    expected_responses = { ["oneagent.containerInsights.KUBE_NODE_INVENTORY_BLOB", overwrite_collection_time({"CollectionTime"=>"2021-08-17T20:24:18Z", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ClusterName"=>"/cluster-name", "ClusterId"=>"/cluster-id", "CreationTimeStamp"=>"2021-07-21T23:40:14Z", "Labels"=>[{"agentpool"=>"nodepool1", "beta.kubernetes.io/arch"=>"amd64", "beta.kubernetes.io/instance-type"=>"Standard_DS2_v2", "beta.kubernetes.io/os"=>"linux", "failure-domain.beta.kubernetes.io/region"=>"westus2", "failure-domain.beta.kubernetes.io/zone"=>"0", "kubernetes.azure.com/cluster"=>"MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode"=>"system", "kubernetes.azure.com/node-image-version"=>"AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku"=>"Ubuntu", "kubernetes.azure.com/role"=>"agent", "kubernetes.io/arch"=>"amd64", "kubernetes.io/hostname"=>"aks-nodepool1-24816391-vmss000000", "kubernetes.io/os"=>"linux", "kubernetes.io/role"=>"agent", "node-role.kubernetes.io/agent"=>"", "node.kubernetes.io/instance-type"=>"Standard_DS2_v2", "storageprofile"=>"managed", "storagetier"=>"Premium_LRS", "topology.kubernetes.io/region"=>"westus2", "topology.kubernetes.io/zone"=>"0"}], "Status"=>"Ready", "KubernetesProviderID"=>"azure", "LastTransitionTimeReady"=>"2021-07-21T23:40:24Z", "KubeletVersion"=>"v1.19.11", "KubeProxyVersion"=>"v1.19.11"})] => true,
    ["mdm.kubenodeinventory", overwrite_collection_time({"CollectionTime"=>"2021-08-17T20:24:18Z", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ClusterName"=>"/cluster-name", "ClusterId"=>"/cluster-id", "CreationTimeStamp"=>"2021-07-21T23:40:14Z", "Labels"=>[{"agentpool"=>"nodepool1", "beta.kubernetes.io/arch"=>"amd64", "beta.kubernetes.io/instance-type"=>"Standard_DS2_v2", "beta.kubernetes.io/os"=>"linux", "failure-domain.beta.kubernetes.io/region"=>"westus2", "failure-domain.beta.kubernetes.io/zone"=>"0", "kubernetes.azure.com/cluster"=>"MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode"=>"system", "kubernetes.azure.com/node-image-version"=>"AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku"=>"Ubuntu", "kubernetes.azure.com/role"=>"agent", "kubernetes.io/arch"=>"amd64", "kubernetes.io/hostname"=>"aks-nodepool1-24816391-vmss000000", "kubernetes.io/os"=>"linux", "kubernetes.io/role"=>"agent", "node-role.kubernetes.io/agent"=>"", "node.kubernetes.io/instance-type"=>"Standard_DS2_v2", "storageprofile"=>"managed", "storagetier"=>"Premium_LRS", "topology.kubernetes.io/region"=>"westus2", "topology.kubernetes.io/zone"=>"0"}], "Status"=>"Ready", "KubernetesProviderID"=>"azure", "LastTransitionTimeReady"=>"2021-07-21T23:40:24Z", "KubeletVersion"=>"v1.19.11", "KubeProxyVersion"=>"v1.19.11"})] => true,
    ["oneagent.containerInsights.CONTAINER_NODE_INVENTORY_BLOB", overwrite_collection_time({"CollectionTime"=>"2021-08-17T20:24:18Z", "Computer"=>"aks-nodepool1-24816391-vmss000000", "OperatingSystem"=>"Ubuntu 18.04.5 LTS", "DockerVersion"=>"containerd://1.4.4+azure"})] => true,
    ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({"Timestamp"=>"2021-08-17T20:24:18Z", "Host"=>"aks-nodepool1-24816391-vmss000000", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"None/aks-nodepool1-24816391-vmss000000", "json_Collections"=>"[{\"CounterName\":\"cpuAllocatableNanoCores\",\"Value\":1900000000.0}]"})] => true,
    ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({"Timestamp"=>"2021-08-17T20:24:18Z", "Host"=>"aks-nodepool1-24816391-vmss000000", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"None/aks-nodepool1-24816391-vmss000000", "json_Collections"=>"[{\"CounterName\":\"memoryAllocatableBytes\",\"Value\":4787511296.0}]"})] => true,
    ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({"Timestamp"=>"2021-08-17T20:24:18Z", "Host"=>"aks-nodepool1-24816391-vmss000000", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"None/aks-nodepool1-24816391-vmss000000", "json_Collections"=>"[{\"CounterName\":\"cpuCapacityNanoCores\",\"Value\":2000000000.0}]"})] => true,
    ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({"Timestamp"=>"2021-08-17T20:24:18Z", "Host"=>"aks-nodepool1-24816391-vmss000000", "Computer"=>"aks-nodepool1-24816391-vmss000000", "ObjectName"=>"K8SNode", "InstanceName"=>"None/aks-nodepool1-24816391-vmss000000", "json_Collections"=>"[{\"CounterName\":\"memoryCapacityBytes\",\"Value\":7291510784.0}]"})] => true}

    d.events.each do |tag, time, record|
        cleaned_record = overwrite_collection_time record
        if expected_responses.key?([tag, cleaned_record])
            assert_equal(true, true)
        else
            assert_equal(true, false) 
        end
    end

    kubeApiClient.verify
    appInsightsUtil.verify
    extensionUtils.verify
  end


end
