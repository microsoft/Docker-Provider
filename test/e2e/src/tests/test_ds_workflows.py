import pytest
import constants
import time

from kubernetes import client, config
from kubernetes_pod_utility import get_pod_list, get_log_file_content
from results_utility import append_result_output
from helper import check_kubernetes_deployment_status
from helper import check_kubernetes_daemonset_status
from helper import check_kubernetes_pods_status
from kubernetes.stream import stream

pytestmark = pytest.mark.agentests

# validation of ds agent workflows
def test_ds_workflows(env_dict):
    print("Starting daemonset agent workflows test.")
    append_result_output("test_ds_workflows start \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))

    print("getting daemonset pod list")
    api_instance = client.CoreV1Api()

    daemonsetPodLabelSelector = constants.AGENT_DAEMON_SET_PODS_LABEL_SELECTOR
    isNonArcK8Environment = env_dict.get('IS_NON_ARC_K8S_TEST_ENVIRONMENT')
    if isNonArcK8Environment:
        daemonsetPodLabelSelector = constants.AGENT_DAEMON_SET_PODS_LABEL_SELECTOR_NON_ARC

    pod_list = get_pod_list(api_instance, constants.AGENT_RESOURCES_NAMESPACE, daemonsetPodLabelSelector)
    if not pod_list:
        pytest.fail("daemonset pod_list shouldnt be null or empty")

    if len(pod_list.items) <= 0:
        pytest.fail("number of items in daemonset pod list should be greater than 0")

    waitTimeSeconds = env_dict['AGENT_WAIT_TIME_SECS']
    print("start: waiting for seconds: {} for agent workflows to get emitted".format(waitTimeSeconds))
    time.sleep(int(waitTimeSeconds))
    print("complete: waiting for seconds: {} for agent workflows to get emitted".format(waitTimeSeconds))

    isOMSBaseAgent = env_dict.get('USING_OMSAGENT_BASE_AGENT')
    agentLogPath = constants.AGENT_FLUENTD_LOG_PATH
    if isOMSBaseAgent:
         agentLogPath = constants.AGENT_OMSAGENT_LOG_PATH

    for podItem in pod_list.items:
        podName = podItem.metadata.name
        logcontent = get_log_file_content(
            api_instance, constants.AGENT_RESOURCES_NAMESPACE, podName, agentLogPath)
        if not logcontent:
            pytest.fail("logcontent should not be null or empty for pod: " + podName)
        loglines = logcontent.split("\n")
        if len(loglines) <= 0:
            pytest.fail("number of log lines should be greater than 0 for pod :" + podName)

        IsContainerPerfEmitStream = False
        IsContainerInventoryStream = False
        for line in loglines:
            if line.find(constants.CONTAINER_PERF_EMIT_STREAM) >= 0:
                IsContainerPerfEmitStream = True
            if line.find(constants.CONTAINER_INVENTORY_EMIT_STREAM) >= 0:
                IsContainerInventoryStream = True

        if IsContainerPerfEmitStream == False:
            pytest.fail("ContainerPerf stream not emitted successfully from pod:" + podName)
        if IsContainerInventoryStream == False:
            pytest.fail("ContainerInventory stream not emitted successfully from pod:" + podName)

    append_result_output("test_ds_workflows end \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    print("Successfully completed daemonset workflows test.")
