import pytest
import constants

from kubernetes import client, config
from results_utility import append_result_output
from helper import check_kubernetes_deployment_status
from helper import check_kubernetes_daemonset_status
from helper import check_kubernetes_pods_status

pytestmark = pytest.mark.agentests

# validate all the critical resources such as ds, rs, ds pods and rs pod etc. are up and running
def test_resource_status(env_dict):
    print("Starting resource status check.")
    append_result_output("test_resource_status start \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
        #config.load_kube_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))
   
    # checking the deployment status
    check_kubernetes_deployment_status(
        constants.AGENT_RESOURCES_NAMESPACE, constants.AGENT_DEPLOYMENT_NAME, env_dict['TEST_AGENT_LOG_FILE'])

    # checking the daemonset status
    check_kubernetes_daemonset_status(
        constants.AGENT_RESOURCES_NAMESPACE, constants.AGENT_DAEMONSET_NAME, env_dict['TEST_AGENT_LOG_FILE'])

    expectedPodRestartCount = env_dict['AGENT_POD_EXPECTED_RESTART_COUNT'] 
    # checking deployment pod status
    check_kubernetes_pods_status(constants.AGENT_RESOURCES_NAMESPACE,
                                 constants.AGENT_DEPLOYMENT_PODS_LABEL_SELECTOR, expectedPodRestartCount, env_dict['TEST_AGENT_LOG_FILE'])

    # checking daemonset pod status
    check_kubernetes_pods_status(constants.AGENT_RESOURCES_NAMESPACE,
                                 constants.AGENT_DAEMON_SET_PODS_LABEL_SELECTOR, expectedPodRestartCount, env_dict['TEST_AGENT_LOG_FILE'])

    append_result_output("test_resource_status end \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    print("Successfully checked resource status check.")
