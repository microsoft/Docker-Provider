import pytest
import constants
import requests
import time

from  arm_rest_utility import fetch_aad_token
from kubernetes import client, config
from kubernetes_pod_utility import get_pod_list
from results_utility import append_result_output


pytestmark = pytest.mark.agentests

# validation of workflows e2e
def test_e2e_workflows(env_dict):
    print("Starting e2e workflows test.")
    append_result_output("test_e2e_workflows start \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))

    # query time interval for LA queries
    queryTimeInterval = env_dict['DEFAULT_QUERY_TIME_INTERVAL_IN_MINUTES']
    if not queryTimeInterval:
        pytest.fail("DEFAULT_QUERY_TIME_INTERVAL_IN_MINUTES should not be null or empty")

    # get the cluster resource id from replicaset pod envvars
    api_instance = client.CoreV1Api()
    pod_list = get_pod_list(api_instance, constants.AGENT_RESOURCES_NAMESPACE,
                            constants.AGENT_DEPLOYMENT_PODS_LABEL_SELECTOR)

    if not pod_list:
        pytest.fail("pod_list shouldnt be null or empty")

    if len(pod_list.items) <= 0:
        pytest.fail("number of items in pod list should be greater than 0")

    envVars = pod_list.items[0].spec.containers[0].env
    if not envVars:
        pytest.fail("environment variables should be defined in the replicaset pod")

    clusterResourceId = ''
    for env in envVars:
        if env.name == "AKS_RESOURCE_ID":
            clusterResourceId = env.value
            print("cluster resource id: {}".format(clusterResourceId))

    if not clusterResourceId:
            pytest.fail("failed to get clusterResourceId from replicaset pod environment variables")

    # fetch AAD token for log analytics resource for the queries
    tenant_id = env_dict.get('TENANT_ID')
    authority_uri = env_dict.get('AZURE_ENDPOINTS').get('activeDirectory') + tenant_id
    client_id = env_dict.get('CLIENT_ID')
    client_secret = env_dict.get('CLIENT_SECRET')
    resource = env_dict.get('AZURE_ENDPOINTS').get('logAnalytics')
    aad_token = fetch_aad_token(client_id, client_secret, authority_uri,  resource)
    if not aad_token:
        pytest.fail("failed to fetch AAD token")

    access_token = aad_token.get('accessToken')
    if not access_token:
        pytest.fail("access_token shouldnt be null or empty")

    # validate e2e workflows by checking data in log analytics workspace through resource centric queries
    queryUrl = resource + "/v1" + clusterResourceId + "/query"
    Headers = {
        "Authorization": str("Bearer " + access_token),
        "Content-Type": "application/json"
    }

    waitTimeSeconds = env_dict['AGENT_WAIT_TIME_SECS']
    print("start: waiting for seconds: {} for agent workflows to get emitted".format(waitTimeSeconds))
    time.sleep(int(waitTimeSeconds))
    print("complete: waiting for seconds: {} for agent workflows to get emitted".format(waitTimeSeconds))

    # KubePodInventory
    query = constants.KUBE_POD_INVENTORY_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('KUBE_POD_INVENTORY'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} and workflow: {1}".format(clusterResourceId, 'KUBE_POD_INVENTORY'))

    # KubeNodeInventory
    query = constants.KUBE_NODE_INVENTORY_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('KUBE_NODE_INVENTORY'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'KUBE_NODE_INVENTORY'))

    # KubeServices
    query = constants.KUBE_SERVICES_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
         pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('KUBE_SERVICES'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'KUBE_SERVICES'))

    # KubeEvents
    query = constants.KUBE_EVENTS_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('KUBE_EVENTS'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'KUBE_EVENTS'))

    # Container Node Inventory
    query = constants.CONTAINER_NODE_INVENTORY_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_NODE_INVENTORY'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_NODE_INVENTORY'))

    # Node Perf
    # cpu capacity
    query = constants.NODE_PERF_CPU_CAPCITY_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('NODE_PERF_CPU_CAPCITY'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'NODE_PERF_CPU_CAPCITY'))

    # memory capacity
    query = constants.NODE_PERF_MEMORY_CAPCITY_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('NODE_PERF_MEMORY_CAPCITY'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'NODE_PERF_MEMORY_CAPCITY'))

    # cpu allocatable
    query = constants.NODE_PERF_CPU_ALLOCATABLE_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('NODE_PERF_CPU_ALLOCATABLE'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'NODE_PERF_CPU_ALLOCATABLE'))

    # memory allocatable
    query = constants.NODE_PERF_MEMORY_ALLOCATABLE_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('NODE_PERF_MEMORY_ALLOCATABLE'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'NODE_PERF_MEMORY_ALLOCATABLE'))

    # cpu usage
    query = constants.NODE_PERF_CPU_USAGE_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('NODE_PERF_CPU_USAGE'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'NODE_PERF_CPU_USAGE'))

    # memory rss usage
    query = constants.NODE_PERF_MEMORY_RSS_USAGE_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('NODE_PERF_MEMORY_RSS_USAGE'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'NODE_PERF_MEMORY_RSS_USAGE'))

    # memory ws usage
    query = constants.NODE_PERF_MEMORY_WS_USAGE_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('NODE_PERF_MEMORY_WS_USAGE'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'NODE_PERF_MEMORY_WS_USAGE'))

    # restartime epoch
    query = constants.NODE_PERF_RESTART_TIME_EPOCH_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('NODE_PERF_RESTART_TIME_EPOCH'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'NODE_PERF_RESTART_TIME_EPOCH'))

    # Container Perf
    # container cpu limits
    query = constants.CONTAINER_PERF_CPU_LIMITS_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_PERF_CPU_LIMITS'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_PERF_CPU_LIMITS'))

    # container memory limits
    query = constants.CONTAINER_PERF_MEMORY_LIMITS_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_PERF_MEMORY_LIMITS'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_PERF_MEMORY_LIMITS'))

    # cpu requests
    query = constants.CONTAINER_PERF_CPU_REQUESTS_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_PERF_CPU_REQUESTS'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_PERF_CPU_REQUESTS'))

    # memory requests
    query = constants.CONTAINER_PERF_MEMORY_REQUESTS_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_PERF_MEMORY_REQUESTS_QUERY'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_PERF_MEMORY_REQUESTS'))

    # cpu usage
    query = constants.CONTAINER_PERF_CPU_USAGE_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_PERF_CPU_USAGE'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_PERF_CPU_USAGE'))

    # memory rss usage
    query = constants.CONTAINER_PERF_MEMORY_RSS_USAGE_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_PERF_MEMORY_RSS_USAGE'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_PERF_MEMORY_RSS_USAGE'))

    # memory ws usage
    query = constants.CONTAINER_PERF_MEMORY_WS_USAGE_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_PERF_MEMORY_WS_USAGE'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_PERF_MEMORY_WS_USAGE'))

    # restart time epoch
    query = constants.CONTAINER_PERF_RESTART_TIME_EPOCH_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_PERF_RESTART_TIME_EPOCH'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_PERF_RESTART_TIME_EPOCH'))

    # Container log
    query = constants.CONTAINER_LOG_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('CONTAINER_LOG'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'CONTAINER_LOG'))

     # InsightsMetrics
    query = constants.INSIGHTS_METRICS_QUERY.format(queryTimeInterval)
    params = { 'query': query}
    result = requests.get(queryUrl, params=params, headers=Headers)
    if not result:
        pytest.fail("log analytics query response shouldnt be null or empty for workflow: {0}".format('INSIGHTS_METRICS'))

    rowCount = result.json()['tables'][0]['rows'][0][0]
    if not rowCount:
        pytest.fail("rowCount should be greater than for cluster: {0} for workflow: {1} ".format(clusterResourceId, 'INSIGHTS_METRICS'))

    append_result_output("test_e2e_workflows end \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    print("Successfully completed e2e workflows test.")
