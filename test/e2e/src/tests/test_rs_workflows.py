import pytest
import constants

from kubernetes import client, config
from kubernetes_pod_utility import get_pod_list, get_log_file_content
from results_utility import append_result_output
from helper import check_kubernetes_deployment_status
from helper import check_kubernetes_daemonset_status
from helper import check_kubernetes_pods_status
from kubernetes.stream import stream

pytestmark = pytest.mark.agentests

# validation of replicaset agent workflows
def test_rs_workflows(env_dict):
    print("Starting replicaset agent workflows test.")
    append_result_output("test_rs_workflows start \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))

    print("getting pod list")
    api_instance = client.CoreV1Api()
    pod_list = get_pod_list(api_instance, constants.AGENT_RESOURCES_NAMESPACE,
                            constants.AGENT_DEPLOYMENT_PODS_LABEL_SELECTOR)
    if not pod_list:
        pytest.fail("pod_list shouldnt be null or empty")

    if len(pod_list.items) <= 0:
        pytest.fail("number of items in pod list should be greater than 0")

    rspodName = pod_list.items[0].metadata.name
    if not rspodName:
        pytest.fail("replicaset pod name should not be null or empty")
        
    logcontent = get_log_file_content(
        api_instance, constants.AGENT_RESOURCES_NAMESPACE, rspodName, constants.AGENT_OMSAGENT_LOG_PATH)
    if not logcontent:
        pytest.fail("logcontent should not be null or empty for rs pod: {}".format(rspodName))
    loglines = logcontent.split("\n")
    if len(loglines) <= 0:
        pytest.fail("number of log lines should be greater than 0")

    IsKubePodInventorySuccessful = False
    IsKubeNodeInventorySuccessful = False
    IsKubeDeploymentInventorySuccessful = False
    IsKubeContainerPerfInventorySuccessful = False
    IsKubeServicesInventorySuccessful = False
    IsContainerNodeInventorySuccessful = False
    IsKubeEventsSuccessful = False
    for line in loglines:
        if line.find(constants.KUBE_POD_INVENTORY_EMIT_STREAM) >= 0:
            IsKubePodInventorySuccessful = True
        if line.find(constants.KUBE_NODE_INVENTORY_EMIT_STREAM) >= 0:
            IsKubeNodeInventorySuccessful = True
        if line.find(constants.KUBE_DEPLOYMENT_INVENTORY_EMIT_STREAM) >= 0:
            IsKubeDeploymentInventorySuccessful = True
        if line.find(constants.KUBE_CONTAINER_PERF_EMIT_STREAM) >= 0:
            IsKubeContainerPerfInventorySuccessful = True
        if line.find(constants.KUBE_SERVICES_EMIT_STREAM) >= 0:
            IsKubeServicesInventorySuccessful = True
        if line.find(constants.KUBE_CONTAINER_NODE_INVENTORY_EMIT_STREAM) >= 0:
            IsContainerNodeInventorySuccessful = True
        if line.find(constants.KUBE_EVENTS_EMIT_STREAM) >= 0:
            IsKubeEventsSuccessful = True

    if IsKubePodInventorySuccessful == False:
       pytest.fail("KubePodInventory stream not emitted successfully from pod:" + rspodName)

    if IsKubeNodeInventorySuccessful == False:
        pytest.fail("KubeNodeInventory stream not emitted successfully from pod:" + rspodName)

    if IsKubeDeploymentInventorySuccessful == False:
        pytest.fail("KubeDeploymentInventory stream not emitted successfully from pod:" + rspodName)

    if IsKubeContainerPerfInventorySuccessful == False:
        pytest.fail("KubeContainerPerfInventory stream not emitted successfully from pod:" + rspodName)
   
    if IsKubeServicesInventorySuccessful == False:
        pytest.fail("KubeServicesInventory stream not emitted successfully from pod:" + rspodName)

    if IsContainerNodeInventorySuccessful == False:
        pytest.fail("ContainerNodeInventory stream not emitted successfully from pod:" + rspodName)

    if IsKubeEventsSuccessful == False:
        pytest.fail("KubeEventsInventory stream not emitted successfully from rs pod:" + rspodName)

    append_result_output("test_rs_workflows end \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    print("Successfully completed replicaset workflows test.")
