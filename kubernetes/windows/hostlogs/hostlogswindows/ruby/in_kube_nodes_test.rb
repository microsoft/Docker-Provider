require "minitest/autorun"

require "fluent/test"
require "fluent/test/driver/input"
require "fluent/test/helpers"

require_relative "in_kube_nodes.rb"

class InKubeNodesTests < Minitest::Test
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf = {}, is_unit_test_mode = true, kubernetesApiClient = nil, applicationInsightsUtility = nil, extensionUtils = nil, env = nil, telemetry_flush_interval = nil, node_items_test_cache)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::Kube_nodeInventory_Input.new(is_unit_test_mode, kubernetesApiClient = kubernetesApiClient,
                                                                                 applicationInsightsUtility = applicationInsightsUtility,
                                                                                 extensionUtils = extensionUtils,
                                                                                 env = env,
                                                                                 telemetry_flush_interval,
                                                                                 node_items_test_cache)).configure(conf)
  end

  # Collection time of scrapped data will always be different. Overwrite it in any records returned by in_kube_ndes.rb
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

    nodes_api_response = eval(File.open("test/unit-tests/canned-api-responses/kube-nodes.txt").read)
    node_items_test_cache = nodes_api_response["items"]

    kubeApiClient.expect(:getClusterName, "/cluster-name")
    kubeApiClient.expect(:getClusterId, "/cluster-id")
    def appInsightsUtil.sendExceptionTelemetry(exception)
      if exception.to_s != "undefined method `[]' for nil:NilClass"
        raise "an unexpected exception has occured"
      end
    end

    config = "run_interval 999999999"  # only run once

    d = create_driver(config, true, kubernetesApiClient = kubeApiClient, applicationInsightsUtility = appInsightsUtil, extensionUtils = extensionUtils, env = env, node_items_test_cache)
    d.instance.start
    d.instance.enumerate
    d.run(timeout: 99999)  # Input plugins decide when to run, so we have to give it enough time to run

    expected_responses = { ["oneagent.containerInsights.KUBE_NODE_INVENTORY_BLOB", overwrite_collection_time({ "CollectionTime" => "2021-08-17T20:24:18Z", "Computer" => "aks-nodepool1-24816391-vmss000000", "ClusterName" => "/cluster-name", "ClusterId" => "/cluster-id", "CreationTimeStamp" => "2021-07-21T23:40:14Z", "Labels" => [{ "agentpool" => "nodepool1", "beta.kubernetes.io/arch" => "amd64", "beta.kubernetes.io/instance-type" => "Standard_DS2_v2", "beta.kubernetes.io/os" => "linux", "failure-domain.beta.kubernetes.io/region" => "westus2", "failure-domain.beta.kubernetes.io/zone" => "0", "kubernetes.azure.com/cluster" => "MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode" => "system", "kubernetes.azure.com/node-image-version" => "AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku" => "Ubuntu", "kubernetes.azure.com/role" => "agent", "kubernetes.io/arch" => "amd64", "kubernetes.io/hostname" => "aks-nodepool1-24816391-vmss000000", "kubernetes.io/os" => "linux", "kubernetes.io/role" => "agent", "node-role.kubernetes.io/agent" => "", "node.kubernetes.io/instance-type" => "Standard_DS2_v2", "storageprofile" => "managed", "storagetier" => "Premium_LRS", "topology.kubernetes.io/region" => "westus2", "topology.kubernetes.io/zone" => "0" }], "Status" => "Ready", "KubernetesProviderID" => "azure", "LastTransitionTimeReady" => "2021-07-21T23:40:24Z", "KubeletVersion" => "v1.19.11", "KubeProxyVersion" => "v1.19.11" })] => true,
                          ["mdm.kubenodeinventory", overwrite_collection_time({ "CollectionTime" => "2021-08-17T20:24:18Z", "Computer" => "aks-nodepool1-24816391-vmss000000", "ClusterName" => "/cluster-name", "ClusterId" => "/cluster-id", "CreationTimeStamp" => "2021-07-21T23:40:14Z", "Labels" => [{ "agentpool" => "nodepool1", "beta.kubernetes.io/arch" => "amd64", "beta.kubernetes.io/instance-type" => "Standard_DS2_v2", "beta.kubernetes.io/os" => "linux", "failure-domain.beta.kubernetes.io/region" => "westus2", "failure-domain.beta.kubernetes.io/zone" => "0", "kubernetes.azure.com/cluster" => "MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode" => "system", "kubernetes.azure.com/node-image-version" => "AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku" => "Ubuntu", "kubernetes.azure.com/role" => "agent", "kubernetes.io/arch" => "amd64", "kubernetes.io/hostname" => "aks-nodepool1-24816391-vmss000000", "kubernetes.io/os" => "linux", "kubernetes.io/role" => "agent", "node-role.kubernetes.io/agent" => "", "node.kubernetes.io/instance-type" => "Standard_DS2_v2", "storageprofile" => "managed", "storagetier" => "Premium_LRS", "topology.kubernetes.io/region" => "westus2", "topology.kubernetes.io/zone" => "0" }], "Status" => "Ready", "KubernetesProviderID" => "azure", "LastTransitionTimeReady" => "2021-07-21T23:40:24Z", "KubeletVersion" => "v1.19.11", "KubeProxyVersion" => "v1.19.11" })] => true,
                          ["oneagent.containerInsights.CONTAINER_NODE_INVENTORY_BLOB", overwrite_collection_time({ "CollectionTime" => "2021-08-17T20:24:18Z", "Computer" => "aks-nodepool1-24816391-vmss000000", "OperatingSystem" => "Ubuntu 18.04.5 LTS", "DockerVersion" => "containerd://1.4.4+azure" })] => true,
                          ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({ "Timestamp" => "2021-08-17T20:24:18Z", "Host" => "aks-nodepool1-24816391-vmss000000", "Computer" => "aks-nodepool1-24816391-vmss000000", "ObjectName" => "K8SNode", "InstanceName" => "None/aks-nodepool1-24816391-vmss000000", "json_Collections" => "[{\"CounterName\":\"cpuAllocatableNanoCores\",\"Value\":1900000000.0}]" })] => true,
                          ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({ "Timestamp" => "2021-08-17T20:24:18Z", "Host" => "aks-nodepool1-24816391-vmss000000", "Computer" => "aks-nodepool1-24816391-vmss000000", "ObjectName" => "K8SNode", "InstanceName" => "None/aks-nodepool1-24816391-vmss000000", "json_Collections" => "[{\"CounterName\":\"memoryAllocatableBytes\",\"Value\":4787511296.0}]" })] => true,
                          ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({ "Timestamp" => "2021-08-17T20:24:18Z", "Host" => "aks-nodepool1-24816391-vmss000000", "Computer" => "aks-nodepool1-24816391-vmss000000", "ObjectName" => "K8SNode", "InstanceName" => "None/aks-nodepool1-24816391-vmss000000", "json_Collections" => "[{\"CounterName\":\"cpuCapacityNanoCores\",\"Value\":2000000000.0}]" })] => true,
                          ["oneagent.containerInsights.LINUX_PERF_BLOB", overwrite_collection_time({ "Timestamp" => "2021-08-17T20:24:18Z", "Host" => "aks-nodepool1-24816391-vmss000000", "Computer" => "aks-nodepool1-24816391-vmss000000", "ObjectName" => "K8SNode", "InstanceName" => "None/aks-nodepool1-24816391-vmss000000", "json_Collections" => "[{\"CounterName\":\"memoryCapacityBytes\",\"Value\":7291510784.0}]" })] => true }

    d.events.each do |tag, time, record|
      cleaned_record = overwrite_collection_time record
      if expected_responses.key?([tag, cleaned_record])
        expected_responses[[tag, cleaned_record]] = true
      else
        assert(false, "got unexpected record: #{cleaned_record}")
      end
    end

    expected_responses.each do |key, val|
      assert(val, "expected record not emitted: #{key}")
    end

    # make sure all mocked methods were called the expected number of times
    kubeApiClient.verify
    appInsightsUtil.verify
    extensionUtils.verify
  end

  # Sometimes customer tooling creates invalid node specs in the Kube API server (its happened more than once).
  # This test makes sure that it doesn't creash the entire input plugin and other nodes are still collected
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

    # Set up the KubernetesApiClient Mock. Note: most of the functions in KubernetesApiClient are pure (access no
    # state other than their arguments), so there is no need to mock them (this test file would be far longer and
    # more brittle). Instead, in_kube_nodes bypasses the mock and directly calls these functions in KubernetesApiClient.
    # Ideally the pure functions in KubernetesApiClient would be refactored into their own file to reduce confusion.
    nodes_api_response = eval(File.open("test/unit-tests/canned-api-responses/kube-nodes-malformed.txt").read)
    node_items_test_cache = nodes_api_response["items"]

    kubeApiClient.expect(:getClusterName, "/cluster-name")
    kubeApiClient.expect(:getClusterName, "/cluster-name")
    kubeApiClient.expect(:getClusterId, "/cluster-id")
    kubeApiClient.expect(:getClusterId, "/cluster-id")

    def appInsightsUtil.sendExceptionTelemetry(exception)
      if exception.to_s != "undefined method `[]' for nil:NilClass"
        raise "an unexpected exception has occured"
      end
    end

    # This test doesn't care if metric telemetry is sent properly. Looking for an unnecessary value would make it needlessly rigid
    def appInsightsUtil.sendMetricTelemetry(a, b, c)
    end

    config = "run_interval 999999999"  # only run once

    d = create_driver(config, true, kubernetesApiClient = kubeApiClient, applicationInsightsUtility = appInsightsUtil, extensionUtils = extensionUtils, env = env, telemetry_flush_interval = 0, node_items_test_cache)
    d.instance.start

    d.instance.enumerate
    d.run(timeout: 99999)  #TODO: is this necessary?

    expected_responses = {
      ["oneagent.containerInsights.KUBE_NODE_INVENTORY_BLOB", { "CollectionTime" => "~CollectionTime~", "Computer" => "correct-node", "ClusterName" => "/cluster-name", "ClusterId" => "/cluster-id", "CreationTimeStamp" => "2021-07-21T23:40:14Z", "Labels" => [{ "agentpool" => "nodepool1", "beta.kubernetes.io/arch" => "amd64", "beta.kubernetes.io/instance-type" => "Standard_DS2_v2", "beta.kubernetes.io/os" => "linux", "failure-domain.beta.kubernetes.io/region" => "westus2", "failure-domain.beta.kubernetes.io/zone" => "0", "kubernetes.azure.com/cluster" => "MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode" => "system", "kubernetes.azure.com/node-image-version" => "AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku" => "Ubuntu", "kubernetes.azure.com/role" => "agent", "kubernetes.io/arch" => "amd64", "kubernetes.io/hostname" => "correct-node", "kubernetes.io/os" => "linux", "kubernetes.io/role" => "agent", "node-role.kubernetes.io/agent" => "", "node.kubernetes.io/instance-type" => "Standard_DS2_v2", "storageprofile" => "managed", "storagetier" => "Premium_LRS", "topology.kubernetes.io/region" => "westus2", "topology.kubernetes.io/zone" => "0" }], "Status" => "Ready", "KubernetesProviderID" => "azure", "LastTransitionTimeReady" => "2021-07-21T23:40:24Z", "KubeletVersion" => "v1.19.11", "KubeProxyVersion" => "v1.19.11" }] => false,
      ["mdm.kubenodeinventory", { "CollectionTime" => "~CollectionTime~", "Computer" => "correct-node", "ClusterName" => "/cluster-name", "ClusterId" => "/cluster-id", "CreationTimeStamp" => "2021-07-21T23:40:14Z", "Labels" => [{ "agentpool" => "nodepool1", "beta.kubernetes.io/arch" => "amd64", "beta.kubernetes.io/instance-type" => "Standard_DS2_v2", "beta.kubernetes.io/os" => "linux", "failure-domain.beta.kubernetes.io/region" => "westus2", "failure-domain.beta.kubernetes.io/zone" => "0", "kubernetes.azure.com/cluster" => "MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode" => "system", "kubernetes.azure.com/node-image-version" => "AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku" => "Ubuntu", "kubernetes.azure.com/role" => "agent", "kubernetes.io/arch" => "amd64", "kubernetes.io/hostname" => "correct-node", "kubernetes.io/os" => "linux", "kubernetes.io/role" => "agent", "node-role.kubernetes.io/agent" => "", "node.kubernetes.io/instance-type" => "Standard_DS2_v2", "storageprofile" => "managed", "storagetier" => "Premium_LRS", "topology.kubernetes.io/region" => "westus2", "topology.kubernetes.io/zone" => "0" }], "Status" => "Ready", "KubernetesProviderID" => "azure", "LastTransitionTimeReady" => "2021-07-21T23:40:24Z", "KubeletVersion" => "v1.19.11", "KubeProxyVersion" => "v1.19.11" }] => false,
      ["oneagent.containerInsights.CONTAINER_NODE_INVENTORY_BLOB", { "CollectionTime" => "~CollectionTime~", "Computer" => "correct-node", "OperatingSystem" => "Ubuntu 18.04.5 LTS", "DockerVersion" => "containerd://1.4.4+azure" }] => false,
      ["oneagent.containerInsights.LINUX_PERF_BLOB", { "Timestamp" => "~Timestamp~", "Host" => "correct-node", "Computer" => "correct-node", "ObjectName" => "K8SNode", "InstanceName" => "None/correct-node", "json_Collections" => "[{\"CounterName\":\"cpuAllocatableNanoCores\",\"Value\":1000000.0}]" }] => false,
      ["oneagent.containerInsights.LINUX_PERF_BLOB", { "Timestamp" => "~Timestamp~", "Host" => "correct-node", "Computer" => "correct-node", "ObjectName" => "K8SNode", "InstanceName" => "None/correct-node", "json_Collections" => "[{\"CounterName\":\"memoryAllocatableBytes\",\"Value\":444.0}]" }] => false,
      ["oneagent.containerInsights.LINUX_PERF_BLOB", { "Timestamp" => "~Timestamp~", "Host" => "correct-node", "Computer" => "correct-node", "ObjectName" => "K8SNode", "InstanceName" => "None/correct-node", "json_Collections" => "[{\"CounterName\":\"cpuCapacityNanoCores\",\"Value\":2000000.0}]" }] => false,
      ["oneagent.containerInsights.LINUX_PERF_BLOB", { "Timestamp" => "~Timestamp~", "Host" => "correct-node", "Computer" => "correct-node", "ObjectName" => "K8SNode", "InstanceName" => "None/correct-node", "json_Collections" => "[{\"CounterName\":\"memoryCapacityBytes\",\"Value\":555.0}]" }] => false,

      # these records are for the malformed node (it doesn't have limits or requests set so there are no PERF records)
      ["oneagent.containerInsights.KUBE_NODE_INVENTORY_BLOB", { "CollectionTime" => "~CollectionTime~", "Computer" => "malformed-node", "ClusterName" => "/cluster-name", "ClusterId" => "/cluster-id", "CreationTimeStamp" => "2021-07-21T23:40:14Z", "Labels" => [{ "agentpool" => "nodepool1", "beta.kubernetes.io/arch" => "amd64", "beta.kubernetes.io/instance-type" => "Standard_DS2_v2", "beta.kubernetes.io/os" => "linux", "failure-domain.beta.kubernetes.io/region" => "westus2", "failure-domain.beta.kubernetes.io/zone" => "0", "kubernetes.azure.com/cluster" => "MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode" => "system", "kubernetes.azure.com/node-image-version" => "AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku" => "Ubuntu", "kubernetes.azure.com/role" => "agent", "kubernetes.io/arch" => "amd64", "kubernetes.io/hostname" => "malformed-node", "kubernetes.io/os" => "linux", "kubernetes.io/role" => "agent", "node-role.kubernetes.io/agent" => "", "node.kubernetes.io/instance-type" => "Standard_DS2_v2", "storageprofile" => "managed", "storagetier" => "Premium_LRS", "topology.kubernetes.io/region" => "westus2", "topology.kubernetes.io/zone" => "0" }], "Status" => "Ready", "KubernetesProviderID" => "azure", "LastTransitionTimeReady" => "2021-07-21T23:40:24Z", "KubeletVersion" => "v1.19.11", "KubeProxyVersion" => "v1.19.11" }] => false,
      ["mdm.kubenodeinventory", { "CollectionTime" => "~CollectionTime~", "Computer" => "malformed-node", "ClusterName" => "/cluster-name", "ClusterId" => "/cluster-id", "CreationTimeStamp" => "2021-07-21T23:40:14Z", "Labels" => [{ "agentpool" => "nodepool1", "beta.kubernetes.io/arch" => "amd64", "beta.kubernetes.io/instance-type" => "Standard_DS2_v2", "beta.kubernetes.io/os" => "linux", "failure-domain.beta.kubernetes.io/region" => "westus2", "failure-domain.beta.kubernetes.io/zone" => "0", "kubernetes.azure.com/cluster" => "MC_davidaks16_davidaks16_westus2", "kubernetes.azure.com/mode" => "system", "kubernetes.azure.com/node-image-version" => "AKSUbuntu-1804gen2containerd-2021.07.03", "kubernetes.azure.com/os-sku" => "Ubuntu", "kubernetes.azure.com/role" => "agent", "kubernetes.io/arch" => "amd64", "kubernetes.io/hostname" => "malformed-node", "kubernetes.io/os" => "linux", "kubernetes.io/role" => "agent", "node-role.kubernetes.io/agent" => "", "node.kubernetes.io/instance-type" => "Standard_DS2_v2", "storageprofile" => "managed", "storagetier" => "Premium_LRS", "topology.kubernetes.io/region" => "westus2", "topology.kubernetes.io/zone" => "0" }], "Status" => "Ready", "KubernetesProviderID" => "azure", "LastTransitionTimeReady" => "2021-07-21T23:40:24Z", "KubeletVersion" => "v1.19.11", "KubeProxyVersion" => "v1.19.11" }] => false,
      ["oneagent.containerInsights.CONTAINER_NODE_INVENTORY_BLOB", { "CollectionTime" => "~CollectionTime~", "Computer" => "malformed-node", "OperatingSystem" => "Ubuntu 18.04.5 LTS", "DockerVersion" => "containerd://1.4.4+azure" }] => false,
    }

    d.events.each do |tag, time, record|
      cleaned_record = overwrite_collection_time record
      if expected_responses.key?([tag, cleaned_record])
        expected_responses[[tag, cleaned_record]] = true
      end
      # don't do anything if an unexpected record was emitted. Since the node spec is malformed, there will be some partial data.
      # we care more that the non-malformed data is still emitted
    end

    expected_responses.each do |key, val|
      assert(val, "expected record not emitted: #{key}")
    end

    kubeApiClient.verify
    appInsightsUtil.verify
    extensionUtils.verify
  end
end
