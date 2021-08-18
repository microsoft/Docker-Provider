# TODO: can we get rid of this global flag
$in_unit_test = true

# TODO: get rid of require test-unit if we switch to minitest
# require "test-unit"
require 'minitest/autorun'
#
require 'fluent/test'
require 'fluent/test/driver/filter'
require 'fluent/test/helpers'
require_relative 'filter_cadvisor2mdm.rb'
require_relative 'KubernetesApiClient'
require 'byebug'


class Ai_utility_stub
  class << self
    def sendCustomEvent(a, b)
    end

    def sendExceptionTelemetry (errorstr)
      # this shouldn't happen, why was there an exception?
      byebug
    end
  end
end

class KubernetesApiClientMock < KubernetesApiClient
      class GetNodesResponse
        def body
          return "{\"kind\":\"NodeList\",\"apiVersion\":\"v1\",\"metadata\":{\"selfLink\":\"/api/v1/nodes\",\"resourceVersion\":\"4597672\"},\"items\":[{\"metadata\":{\"name\":\"aks-nodepool1-24816391-vmss000000\",\"selfLink\":\"/api/v1/nodes/aks-nodepool1-24816391-vmss000000\",\"uid\":\"fe073f0a-e6bf-4d68-b4e5-ffaa42b91528\",\"resourceVersion\":\"4597521\",\"creationTimestamp\":\"2021-07-21T23:40:14Z\",\"labels\":{\"agentpool\":\"nodepool1\",\"beta.kubernetes.io/arch\":\"amd64\",\"beta.kubernetes.io/instance-type\":\"Standard_DS2_v2\",\"beta.kubernetes.io/os\":\"linux\",\"failure-domain.beta.kubernetes.io/region\":\"westus2\",\"failure-domain.beta.kubernetes.io/zone\":\"0\",\"kubernetes.azure.com/cluster\":\"MC_davidaks16_davidaks16_westus2\",\"kubernetes.azure.com/mode\":\"system\",\"kubernetes.azure.com/node-image-version\":\"AKSUbuntu-1804gen2containerd-2021.07.03\",\"kubernetes.azure.com/os-sku\":\"Ubuntu\",\"kubernetes.azure.com/role\":\"agent\",\"kubernetes.io/arch\":\"amd64\",\"kubernetes.io/hostname\":\"aks-nodepool1-24816391-vmss000000\",\"kubernetes.io/os\":\"linux\",\"kubernetes.io/role\":\"agent\",\"node-role.kubernetes.io/agent\":\"\",\"node.kubernetes.io/instance-type\":\"Standard_DS2_v2\",\"storageprofile\":\"managed\",\"storagetier\":\"Premium_LRS\",\"topology.kubernetes.io/region\":\"westus2\",\"topology.kubernetes.io/zone\":\"0\"},\"annotations\":{\"node.alpha.kubernetes.io/ttl\":\"0\",\"volumes.kubernetes.io/controller-managed-attach-detach\":\"true\"},\"managedFields\":[{\"manager\":\"kube-controller-manager\",\"operation\":\"Update\",\"apiVersion\":\"v1\",\"time\":\"2021-07-21T23:40:20Z\",\"fieldsType\":\"FieldsV1\",\"fieldsV1\":{\"f:metadata\":{\"f:annotations\":{\"f:node.alpha.kubernetes.io/ttl\":{}}}}},{\"manager\":\"kubelet\",\"operation\":\"Update\",\"apiVersion\":\"v1\",\"time\":\"2021-07-21T23:40:24Z\",\"fieldsType\":\"FieldsV1\",\"fieldsV1\":{\"f:metadata\":{\"f:annotations\":{\".\":{},\"f:volumes.kubernetes.io/controller-managed-attach-detach\":{}},\"f:labels\":{\".\":{},\"f:agentpool\":{},\"f:beta.kubernetes.io/arch\":{},\"f:beta.kubernetes.io/instance-type\":{},\"f:beta.kubernetes.io/os\":{},\"f:failure-domain.beta.kubernetes.io/region\":{},\"f:failure-domain.beta.kubernetes.io/zone\":{},\"f:kubernetes.azure.com/cluster\":{},\"f:kubernetes.azure.com/mode\":{},\"f:kubernetes.azure.com/node-image-version\":{},\"f:kubernetes.azure.com/os-sku\":{},\"f:kubernetes.azure.com/role\":{},\"f:kubernetes.io/arch\":{},\"f:kubernetes.io/hostname\":{},\"f:kubernetes.io/os\":{},\"f:node.kubernetes.io/instance-type\":{},\"f:storageprofile\":{},\"f:storagetier\":{},\"f:topology.kubernetes.io/region\":{},\"f:topology.kubernetes.io/zone\":{}}},\"f:spec\":{\"f:providerID\":{}},\"f:status\":{\"f:addresses\":{\".\":{},\"k:{\\\"type\\\":\\\"Hostname\\\"}\":{\".\":{},\"f:address\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"InternalIP\\\"}\":{\".\":{},\"f:address\":{},\"f:type\":{}}},\"f:allocatable\":{\".\":{},\"f:attachable-volumes-azure-disk\":{},\"f:cpu\":{},\"f:ephemeral-storage\":{},\"f:hugepages-1Gi\":{},\"f:hugepages-2Mi\":{},\"f:memory\":{},\"f:pods\":{}},\"f:capacity\":{\".\":{},\"f:attachable-volumes-azure-disk\":{},\"f:cpu\":{},\"f:ephemeral-storage\":{},\"f:hugepages-1Gi\":{},\"f:hugepages-2Mi\":{},\"f:memory\":{},\"f:pods\":{}},\"f:conditions\":{\".\":{},\"k:{\\\"type\\\":\\\"DiskPressure\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"MemoryPressure\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"PIDPressure\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"Ready\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}}},\"f:config\":{},\"f:daemonEndpoints\":{\"f:kubeletEndpoint\":{\"f:Port\":{}}},\"f:images\":{},\"f:nodeInfo\":{\"f:architecture\":{},\"f:bootID\":{},\"f:containerRuntimeVersion\":{},\"f:kernelVersion\":{},\"f:kubeProxyVersion\":{},\"f:kubeletVersion\":{},\"f:machineID\":{},\"f:operatingSystem\":{},\"f:osImage\":{},\"f:systemUUID\":{}}}}},{\"manager\":\"kubectl-label\",\"operation\":\"Update\",\"apiVersion\":\"v1\",\"time\":\"2021-07-21T23:40:53Z\",\"fieldsType\":\"FieldsV1\",\"fieldsV1\":{\"f:metadata\":{\"f:labels\":{\"f:kubernetes.io/role\":{},\"f:node-role.kubernetes.io/agent\":{}}}}},{\"manager\":\"node-problem-detector\",\"operation\":\"Update\",\"apiVersion\":\"v1\",\"time\":\"2021-08-10T18:10:02Z\",\"fieldsType\":\"FieldsV1\",\"fieldsV1\":{\"f:status\":{\"f:conditions\":{\"k:{\\\"type\\\":\\\"ContainerRuntimeProblem\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"FilesystemCorruptionProblem\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"FreezeScheduled\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"FrequentContainerdRestart\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"FrequentDockerRestart\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"FrequentKubeletRestart\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"FrequentUnregisterNetDevice\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"KernelDeadlock\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"KubeletProblem\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"PreemptScheduled\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"ReadonlyFilesystem\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"RebootScheduled\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"RedeployScheduled\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}},\"k:{\\\"type\\\":\\\"TerminateScheduled\\\"}\":{\".\":{},\"f:lastHeartbeatTime\":{},\"f:lastTransitionTime\":{},\"f:message\":{},\"f:reason\":{},\"f:status\":{},\"f:type\":{}}}}}}]},\"spec\":{\"providerID\":\"azure:///subscriptions/3b875bf3-0eec-4d8c-bdee-25c7ccc1f130/resourceGroups/mc_davidaks16_davidaks16_westus2/providers/Microsoft.Compute/virtualMachineScaleSets/aks-nodepool1-24816391-vmss/virtualMachines/0\"},\"status\":{\"capacity\":{\"attachable-volumes-azure-disk\":\"8\",\"cpu\":\"2\",\"ephemeral-storage\":\"129900528Ki\",\"hugepages-1Gi\":\"0\",\"hugepages-2Mi\":\"0\",\"memory\":\"7120616Ki\",\"pods\":\"30\"},\"allocatable\":{\"attachable-volumes-azure-disk\":\"8\",\"cpu\":\"1900m\",\"ephemeral-storage\":\"119716326407\",\"hugepages-1Gi\":\"0\",\"hugepages-2Mi\":\"0\",\"memory\":\"4675304Ki\",\"pods\":\"30\"},\"conditions\":[{\"type\":\"FrequentContainerdRestart\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"NoFrequentContainerdRestart\",\"message\":\"containerd is functioning properly\"},{\"type\":\"FreezeScheduled\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"NoFreezeScheduled\",\"message\":\"VM has no scheduled Freeze event\"},{\"type\":\"FrequentDockerRestart\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"NoFrequentDockerRestart\",\"message\":\"docker is functioning properly\"},{\"type\":\"FilesystemCorruptionProblem\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"FilesystemIsOK\",\"message\":\"Filesystem is healthy\"},{\"type\":\"KernelDeadlock\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"KernelHasNoDeadlock\",\"message\":\"kernel has no deadlock\"},{\"type\":\"TerminateScheduled\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"NoTerminateScheduled\",\"message\":\"VM has no scheduled Terminate event\"},{\"type\":\"ReadonlyFilesystem\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"FilesystemIsNotReadOnly\",\"message\":\"Filesystem is not read-only\"},{\"type\":\"FrequentUnregisterNetDevice\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"NoFrequentUnregisterNetDevice\",\"message\":\"node is functioning properly\"},{\"type\":\"KubeletProblem\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"KubeletIsUp\",\"message\":\"kubelet service is up\"},{\"type\":\"PreemptScheduled\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:11:11Z\",\"reason\":\"NoPreemptScheduled\",\"message\":\"VM has no scheduled Preempt event\"},{\"type\":\"RedeployScheduled\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"NoRedeployScheduled\",\"message\":\"VM has no scheduled Redeploy event\"},{\"type\":\"ContainerRuntimeProblem\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"ContainerRuntimeIsUp\",\"message\":\"container runtime service is up\"},{\"type\":\"FrequentKubeletRestart\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"NoFrequentKubeletRestart\",\"message\":\"kubelet is functioning properly\"},{\"type\":\"RebootScheduled\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:57:20Z\",\"lastTransitionTime\":\"2021-08-10T18:10:01Z\",\"reason\":\"NoRebootScheduled\",\"message\":\"VM has no scheduled Reboot event\"},{\"type\":\"MemoryPressure\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:58:37Z\",\"lastTransitionTime\":\"2021-07-21T23:40:14Z\",\"reason\":\"KubeletHasSufficientMemory\",\"message\":\"kubelet has sufficient memory available\"},{\"type\":\"DiskPressure\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:58:37Z\",\"lastTransitionTime\":\"2021-07-21T23:40:14Z\",\"reason\":\"KubeletHasNoDiskPressure\",\"message\":\"kubelet has no disk pressure\"},{\"type\":\"PIDPressure\",\"status\":\"False\",\"lastHeartbeatTime\":\"2021-08-11T02:58:37Z\",\"lastTransitionTime\":\"2021-07-21T23:40:14Z\",\"reason\":\"KubeletHasSufficientPID\",\"message\":\"kubelet has sufficient PID available\"},{\"type\":\"Ready\",\"status\":\"True\",\"lastHeartbeatTime\":\"2021-08-11T02:58:37Z\",\"lastTransitionTime\":\"2021-07-21T23:40:24Z\",\"reason\":\"KubeletReady\",\"message\":\"kubelet is posting ready status. AppArmor enabled\"}],\"addresses\":[{\"type\":\"Hostname\",\"address\":\"aks-nodepool1-24816391-vmss000000\"},{\"type\":\"InternalIP\",\"address\":\"10.240.0.4\"}],\"daemonEndpoints\":{\"kubeletEndpoint\":{\"Port\":10250}},\"nodeInfo\":{\"machineID\":\"17a654260e2c4a9bb3a3eb4b4188e4b4\",\"systemUUID\":\"7ff599e4-909e-4950-a044-ff8613af3af9\",\"bootID\":\"02bb865b-a469-43cd-8b0b-5ceb4ecd80b0\",\"kernelVersion\":\"5.4.0-1051-azure\",\"osImage\":\"Ubuntu 18.04.5 LTS\",\"containerRuntimeVersion\":\"containerd://1.4.4+azure\",\"kubeletVersion\":\"v1.19.11\",\"kubeProxyVersion\":\"v1.19.11\",\"operatingSystem\":\"linux\",\"architecture\":\"amd64\"},\"images\":[{\"names\":[\"mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06112021-1\"],\"sizeBytes\":331689060},{\"names\":[\"mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06112021\"],\"sizeBytes\":330099815},{\"names\":[\"mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod05202021-hotfix\"],\"sizeBytes\":271471426},{\"names\":[\"mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod05202021\"],\"sizeBytes\":269703297},{\"names\":[\"mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod03262021\"],\"sizeBytes\":264732875},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/ingress/nginx-ingress-controller:0.19.0\"],\"sizeBytes\":166352383},{\"names\":[\"mcr.microsoft.com/aks/hcp/hcp-tunnel-front:master.210623.2\"],\"sizeBytes\":147750148},{\"names\":[\"mcr.microsoft.com/aks/hcp/hcp-tunnel-front:master.210524.1\"],\"sizeBytes\":146446618},{\"names\":[\"mcr.microsoft.com/aks/hcp/hcp-tunnel-front:master.210427.1\"],\"sizeBytes\":136242776},{\"names\":[\"mcr.microsoft.com/oss/calico/node:v3.8.9.5\"],\"sizeBytes\":101794833},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/ingress/nginx-ingress-controller:0.47.0\"],\"sizeBytes\":101445696},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/autoscaler/cluster-proportional-autoscaler:1.3.0_v0.0.5\"],\"sizeBytes\":101194562},{\"names\":[\"mcr.microsoft.com/aks/hcp/tunnel-openvpn:master.210623.2\"],\"sizeBytes\":96125176},{\"names\":[\"mcr.microsoft.com/aks/hcp/tunnel-openvpn:master.210524.1\"],\"sizeBytes\":95879501},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/exechealthz:1.2_v0.0.5\"],\"sizeBytes\":94348102},{\"names\":[\"mcr.microsoft.com/oss/calico/node:v3.8.9.2\"],\"sizeBytes\":93537927},{\"names\":[\"mcr.microsoft.com/aks/acc/sgx-attestation:2.0\"],\"sizeBytes\":91841669},{\"names\":[\"mcr.microsoft.com/oss/kubernetes-csi/azurefile-csi:v1.4.0\"],\"sizeBytes\":91324193},{\"names\":[\"mcr.microsoft.com/oss/kubernetes-csi/azurefile-csi:v1.2.0\"],\"sizeBytes\":89103171},{\"names\":[\"mcr.microsoft.com/azure-application-gateway/kubernetes-ingress:1.0.1-rc3\"],\"sizeBytes\":86839805},{\"names\":[\"mcr.microsoft.com/azure-application-gateway/kubernetes-ingress:1.2.0\"],\"sizeBytes\":86488586},{\"names\":[\"mcr.microsoft.com/aks/hcp/tunnel-openvpn:master.210427.1\"],\"sizeBytes\":86120048},{\"names\":[\"mcr.microsoft.com/azure-application-gateway/kubernetes-ingress:1.3.0\"],\"sizeBytes\":81252495},{\"names\":[\"mcr.microsoft.com/azure-application-gateway/kubernetes-ingress:1.4.0\"],\"sizeBytes\":79586703},{\"names\":[\"mcr.microsoft.com/oss/kubernetes-csi/azuredisk-csi:v1.4.0\"],\"sizeBytes\":78795016},{\"names\":[\"mcr.microsoft.com/oss/kubernetes-csi/azuredisk-csi:v1.2.0\"],\"sizeBytes\":76527179},{\"names\":[\"mcr.microsoft.com/containernetworking/azure-npm:v1.1.8\"],\"sizeBytes\":75025803},{\"names\":[\"mcr.microsoft.com/containernetworking/azure-npm:v1.2.2_hotfix\"],\"sizeBytes\":73533889},{\"names\":[\"mcr.microsoft.com/containernetworking/azure-npm:v1.3.1\"],\"sizeBytes\":72242894},{\"names\":[\"mcr.microsoft.com/containernetworking/azure-npm:v1.2.8\"],\"sizeBytes\":70622822},{\"names\":[\"mcr.microsoft.com/oss/nvidia/k8s-device-plugin:v0.9.0\"],\"sizeBytes\":67291599},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/dashboard:v2.0.1\"],\"sizeBytes\":66415836},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/dashboard:v2.0.0-rc7\"],\"sizeBytes\":65965658},{\"names\":[\"mcr.microsoft.com/containernetworking/azure-npm:v1.2.1\"],\"sizeBytes\":64123775},{\"names\":[\"mcr.microsoft.com/oss/calico/cni:v3.8.9.3\"],\"sizeBytes\":63581323},{\"names\":[\"mcr.microsoft.com/containernetworking/networkmonitor:v1.1.8\"],\"sizeBytes\":63154716},{\"names\":[\"mcr.microsoft.com/oss/calico/cni:v3.8.9.2\"],\"sizeBytes\":61626312},{\"names\":[\"mcr.microsoft.com/oss/calico/node:v3.18.1\"],\"sizeBytes\":60500885},{\"names\":[\"mcr.microsoft.com/oss/calico/node:v3.17.2\"],\"sizeBytes\":58419768},{\"names\":[\"mcr.microsoft.com/containernetworking/networkmonitor:v1.1.8_hotfix\",\"mcr.microsoft.com/containernetworking/networkmonitor:v1.1.8post2\"],\"sizeBytes\":56368756},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/kube-proxy@sha256:282543237a1aa3f407656290f454b7068a92e1abe2156082c750d5abfbcad90c\",\"mcr.microsoft.com/oss/kubernetes/kube-proxy:v1.19.11-hotfix.20210526.2\"],\"sizeBytes\":56310724},{\"names\":[\"mcr.microsoft.com/oss/calico/node:v3.19.0\"],\"sizeBytes\":55228749},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/kube-proxy:v1.19.11-hotfix.20210526.1\"],\"sizeBytes\":54692048},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/dashboard:v2.0.0-rc3\"],\"sizeBytes\":50803639},{\"names\":[\"mcr.microsoft.com/oss/kubernetes-csi/secrets-store/driver:v0.0.19\"],\"sizeBytes\":49759361},{\"names\":[\"mcr.microsoft.com/oss/azure/aad-pod-identity/nmi:v1.7.5\"],\"sizeBytes\":49704644},{\"names\":[\"mcr.microsoft.com/oss/kubernetes-csi/secrets-store/driver:v0.0.21\"],\"sizeBytes\":49372390},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/kube-proxy@sha256:a64d3538b72905b07356881314755b02db3675ff47ee2bcc49dd7be856e285d5\",\"mcr.microsoft.com/oss/kubernetes/kube-proxy:v1.19.11-hotfix.20210526\"],\"sizeBytes\":49322942},{\"names\":[\"mcr.microsoft.com/oss/azure/aad-pod-identity/nmi:v1.7.4\"],\"sizeBytes\":48108311},{\"names\":[\"mcr.microsoft.com/oss/kubernetes/kubernetes-dashboard:v1.10.1\"],\"sizeBytes\":44907744}],\"config\":{}}}]}\n"
        end
      end
  class << self
    def getKubeResourceInfo(resource, api_group: nil)
      if resource == "nodes?fieldSelector=metadata.name%3DWIN-T14B9CT7KMS"
        return GetNodesResponse.new()
      end
      # this means that a saved input is missing
      byebug
    end
  end
end



class FilterCadvisor2MdmTests < Minitest::Test
    include Fluent::Test::Helpers

    def setup
      Fluent::Test.setup
    end
  
    def create_driver(conf = "")
      Fluent::Test::Driver::Filter.new(Fluent::Plugin::CAdvisor2MdmFilter).configure(conf)
    end
  
    # A relatively simple test for a helper method
    def test_build_metrics_hash
      instance = create_driver.instance

      expected = {"constants::cpu_usage_nano_cores" => true, "constants::memory_working_set_bytes" => true, "constants::memory_rss_bytes"=> true, "constants::pv_used_bytes"=> true}
      actual = instance.build_metrics_hash "Constants::CPU_USAGE_NANO_CORES,Constants::MEMORY_WORKING_SET_BYTES,Constants::MEMORY_RSS_BYTES,Constants::PV_USED_BYTES"
      assert_equal(expected, actual)

      assert_equal({}, instance.build_metrics_hash(""))

      assert_equal({"test_input:.<>" => true}, instance.build_metrics_hash("test_input:.<>"))

    end


    # a much more complicated test for the filter method of filter_cadvisor2mdm (this is an allup test)
    def test_filter


      env = {"CONTROLLER_TYPE" => "ReplicaSet",
                                    "OS_TYPE" => "linux",
                                    "AZMON_ALERT_CONTAINER_CPU_THRESHOLD" => Constants::DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD.to_s,
                                    "AZMON_ALERT_CONTAINER_MEMORY_RSS_THRESHOLD" => Constants::DEFAULT_MDM_MEMORY_RSS_THRESHOLD.to_s,
                                    "AZMON_ALERT_CONTAINER_MEMORY_WORKING_SET_THRESHOLD" => Constants::DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD.to_s,
                                    "AZMON_ALERT_PV_USAGE_THRESHOLD" => Constants::DEFAULT_MDM_PV_UTILIZATION_THRESHOLD.to_s,
                                    "AZMON_ALERT_JOB_COMPLETION_TIME_THRESHOLD" => Constants::DEFAULT_MDM_JOB_COMPLETED_TIME_THRESHOLD_MINUTES.to_s,
                                    "AKS_REGION" => "westus2",
                                    "AKS_RESOURCE_ID" => "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx/resourceGroups/rg/providers/Microsoft.ContainerService/managedClusters/clustername",
                                    "CLOUD_ENVIRONMENT" => "azurepubliccloud"}  # TODO: this is actually set to public in running containers. Figure out how @process_incoming_stream resolves to true
      applicationInsightsUtility = Ai_utility_stub.new()
      kubernetesApiClient = KubernetesApiClientMock

      config = %[
                  metrics_to_collect cpuUsageNanoCores,memoryWorkingSetBytes,pvUsedBytes
                  @log_level info
                ]

      data = [
        {"tag" => "mdm.cadvisorperf", "time" => 1628198199.2757478, "data" => {"DataItems"=>[{"Timestamp"=>"2021-08-05T21:16:39Z", "Host"=>"akswin00000c", "ObjectName"=>"K8SContainer", "InstanceName"=>"/subscriptions/3b875bf3-0eec-4d8c-bdee-25c7ccc1f130/resourceGroups/davidwin6/providers/Microsoft.ContainerService/managedClusters/davidwin6/9bb73e59-9034-474a-92ab-5e028f18dbe9/omsagent-win", "Collections"=>[{"CounterName"=>"memoryWorkingSetBytes", "Value"=>272093184}]}], "DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement"}}
      ]

      expected_output = [
        {"tag" => "mdm.cadvisorperf", "time" => 1628198199.2757478, "data" => {"DataItems"=>[{"Timestamp"=>"2021-08-05T21:16:39Z", "Host"=>"akswin00000c", "ObjectName"=>"K8SContainer", "InstanceName"=>"/subscriptions/3b875bf3-0eec-4d8c-bdee-25c7ccc1f130/resourceGroups/davidwin6/providers/Microsoft.ContainerService/managedClusters/davidwin6/9bb73e59-9034-474a-92ab-5e028f18dbe9/omsagent-win", "Collections"=>[{"CounterName"=>"memoryWorkingSetBytes", "Value"=>272093184}]}], "DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement"}}
      ]

      d = create_driver(config)
      d.instance.set_hostname("aks-nodepool1-24816391-vmss000000")
      d.instance.start(env=env, applicationInsightsUtility=applicationInsightsUtility, kubernetesApiClient=kubernetesApiClient)  # TODO: why doesn't the fluentd test harness do this automatically?
      time = event_time

      d.run do
        d.feed(data[0]["tag"], time, data[0]["data"])
      end

      puts d.filtered_records.size
      puts d.filtered_records

      assert_equal(0, d.filtered_records.size)
      # assert_equal("expected response", d.filtered_records)
    end

end