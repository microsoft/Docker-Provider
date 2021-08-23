import pytest
import constants
import requests
import time

from arm_rest_utility import fetch_aad_token
from kubernetes import client, config
from kubernetes_pod_utility import get_pod_list
from results_utility import append_result_output
from datetime import datetime, timedelta

pytestmark = pytest.mark.agentests

# validation of node metrics e2e workflow
def test_node_metrics_e2e_workflow(env_dict):
    print("Starting node metrics e2e workflow test.")
    append_result_output("test_node_metrics_e2e_workflow start \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))

    # query time interval for metric queries
    metricQueryIntervalInMins = env_dict['DEFAULT_METRICS_QUERY_TIME_INTERVAL_IN_MINUTES']
    if not metricQueryIntervalInMins:
        pytest.fail(
            "DEFAULT_METRICS_QUERY_TIME_INTERVAL_IN_MINUTES should not be null or empty or 0")

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
        pytest.fail(
            "environment variables should be defined in the replicaset pod")

    clusterResourceId = ''
    for env in envVars:
        if env.name == "AKS_RESOURCE_ID":
            clusterResourceId = env.value
            print("cluster resource id: {}".format(clusterResourceId))

    if not clusterResourceId:
        pytest.fail(
            "failed to get clusterResourceId from replicaset pod environment variables")

    # fetch AAD token for metric queries
    tenant_id = env_dict.get('TENANT_ID')
    authority_uri = env_dict.get('AZURE_ENDPOINTS').get(
        'activeDirectory') + tenant_id
    client_id = env_dict.get('CLIENT_ID')
    client_secret = env_dict.get('CLIENT_SECRET')
    resourceManager = env_dict.get('AZURE_ENDPOINTS').get('resourceManager')
    aad_token = fetch_aad_token(
        client_id, client_secret, authority_uri,  resourceManager)
    if not aad_token:
        pytest.fail("failed to fetch AAD token")

    access_token = aad_token.get('accessToken')
    if not access_token:
        pytest.fail("access_token shouldnt be null or empty")

    waitTimeSeconds = env_dict['AGENT_WAIT_TIME_SECS']
    print("start: waiting for seconds: {} for agent workflows to get emitted".format(waitTimeSeconds))
    time.sleep(int(waitTimeSeconds))
    print("complete: waiting for seconds: {} for agent workflows to get emitted".format(waitTimeSeconds))

    # validate metrics e2e workflow
    now = datetime.utcnow()
    endtime = now.isoformat()[:-3]+'Z'
    starttime = (now - timedelta(hours=0,
                                 minutes=constants.DEFAULT_METRICS_QUERY_TIME_INTERVAL_IN_MINUTES)).isoformat()[:-3]+'Z'
    Headers = {
        "Authorization": str("Bearer " + access_token),
        "Content-Type": "application/json",
        "content-length": "0"
    }
    params = {}
    # node metric - memoryRssBytes
    custommetricsUrl = '{0}{1}/providers/microsoft.Insights/metrics?timespan={2}/{3}&interval=FULL&metricnames={4}&aggregation={5}&metricNamespace={6}&validatedimensions=false&api-version={7}'.format(
        resourceManager.rstrip("/"),
        clusterResourceId,
        starttime,
        endtime,
        constants.NODE_MEMORY_RSS_METRIC_NAME,
        constants.NODE_METRIC_METRIC_AGGREGATION,
        constants.NODE_METRICS_NAMESPACE,
        constants.METRICS_API_VERSION)

    response = requests.get(custommetricsUrl, params=params,
                            headers=Headers)

    if not response:
        pytest.fail(
            "response of the metrics query API shouldnt be null or empty")

    if response.status_code != 200:
       pytest.fail("metrics query API failed with an error code: {}".format(
           response.status_code))

    responseJSON = response.json()
    if not responseJSON:
        pytest.fail("response JSON shouldnt be null or empty")

    namespace = responseJSON['namespace']
    if namespace != constants.NODE_METRICS_NAMESPACE:
        pytest.fail("got the namespace: {0} but expected namespace:{1} in the response".format(
            namespace, constants.NODE_METRICS_NAMESPACE))

    responseValues = responseJSON['value']
    if not responseValues:
        pytest.fail("response JSON shouldnt be null or empty")

    if len(responseValues) <= 0:
        pytest.fail("length of value array in the response should be greater than 0")

    for responseVal in responseValues:
        metricName = responseVal['name']['value']
        if metricName != constants.NODE_MEMORY_RSS_METRIC_NAME:
            pytest.fail("got the metricname: {0} but expected metricname:{1} in the response".format(metricName, constants.NODE_MEMORY_RSS_METRIC_NAME))
        timeseries = responseVal['timeseries']
        if not timeseries:
            pytest.fail("metric series shouldnt be null or empty for metric:{0} in namespace: {1}".format(
                constants.NODE_MEMORY_RSS_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))
        if len(timeseries) <= 0:
            pytest.fail("length of timeseries should be greater than for 0 for metric: {0} in namespace :{1}".format(constants.NODE_MEMORY_RSS_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))

    # node metric - memoryRssPercentage
    custommetricsUrl = '{0}{1}/providers/microsoft.Insights/metrics?timespan={2}/{3}&interval=FULL&metricnames={4}&aggregation={5}&metricNamespace={6}&validatedimensions=false&api-version={7}'.format(
        resourceManager.rstrip("/"),
        clusterResourceId,
        starttime,
        endtime,
        constants.NODE_MEMORY_RSS_PERCENTAGE_METRIC_NAME,
        constants.NODE_METRIC_METRIC_AGGREGATION,
        constants.NODE_METRICS_NAMESPACE,
        constants.METRICS_API_VERSION)

    response = requests.get(custommetricsUrl, params=params,
                            headers=Headers)

    if not response:
        pytest.fail(
            "response of the metrics query API shouldnt be null or empty")

    if response.status_code != 200:
       pytest.fail("metrics query API failed with an error code: {}".format(
           response.status_code))

    responseJSON = response.json()
    if not responseJSON:
        pytest.fail("response JSON shouldnt be null or empty")

    namespace = responseJSON['namespace']
    if namespace != constants.NODE_METRICS_NAMESPACE:
        pytest.fail("got the namespace: {0} but expected namespace:{1} in the response".format(
            namespace, constants.NODE_METRICS_NAMESPACE))

    responseValues = responseJSON['value']
    if not responseValues:
        pytest.fail("response JSON shouldnt be null or empty")

    if len(responseValues) <= 0:
        pytest.fail("length of value array in the response should be greater than 0")

    for responseVal in responseValues:
        metricName = responseVal['name']['value']
        if metricName != constants.NODE_MEMORY_RSS_PERCENTAGE_METRIC_NAME:
            pytest.fail("got the metricname: {0} but expected metricname:{1} in the response".format(metricName, constants.NODE_MEMORY_RSS_PERCENTAGE_METRIC_NAME))
        timeseries = responseVal['timeseries']
        if not timeseries:
            pytest.fail("metric series shouldnt be null or empty for metric:{0} in namespace: {1}".format(
                constants.NODE_MEMORY_RSS_PERCENTAGE_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))
        if len(timeseries) <= 0:
            pytest.fail("length of timeseries should be greater than for 0 for metric: {0} in namespace :{1}".format(constants.NODE_MEMORY_RSS_PERCENTAGE_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))

    # node metric - memoryWorkingSetBytes
    custommetricsUrl = '{0}{1}/providers/microsoft.Insights/metrics?timespan={2}/{3}&interval=FULL&metricnames={4}&aggregation={5}&metricNamespace={6}&validatedimensions=false&api-version={7}'.format(
        resourceManager.rstrip("/"),
        clusterResourceId,
        starttime,
        endtime,
        constants.NODE_MEMORY_WS_METRIC_NAME,
        constants.NODE_METRIC_METRIC_AGGREGATION,
        constants.NODE_METRICS_NAMESPACE,
        constants.METRICS_API_VERSION)

    response = requests.get(custommetricsUrl, params=params,
                            headers=Headers)

    if not response:
        pytest.fail("response of the metrics query API shouldnt be null or empty")

    if response.status_code != 200:
       pytest.fail("metrics query API failed with an error code: {}".format(
           response.status_code))

    responseJSON = response.json()
    if not responseJSON:
        pytest.fail("response JSON shouldnt be null or empty")

    namespace = responseJSON['namespace']
    if namespace != constants.NODE_METRICS_NAMESPACE:
        pytest.fail("got the namespace: {0} but expected namespace:{1} in the response".format(
            namespace, constants.NODE_METRICS_NAMESPACE))

    responseValues = responseJSON['value']
    if not responseValues:
        pytest.fail("response JSON shouldnt be null or empty")

    if len(responseValues) <= 0:
        pytest.fail("length of value array in the response should be greater than 0")

    for responseVal in responseValues:
        metricName = responseVal['name']['value']
        if metricName != constants.NODE_MEMORY_WS_METRIC_NAME:
            pytest.fail("got the metricname: {0} but expected metricname:{1} in the response".format(metricName, constants.NODE_MEMORY_WS_METRIC_NAME))
        timeseries = responseVal['timeseries']
        if not timeseries:
            pytest.fail("metric series shouldnt be null or empty for metric:{0} in namespace: {1}".format(
                constants.NODE_MEMORY_WS_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))
        if len(timeseries) <= 0:
            pytest.fail("length of timeseries should be greater than for 0 for metric: {0} in namespace :{1}".format(constants.NODE_MEMORYE_WS_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))

    # node metric - memoryWorkingSetPercentage
    custommetricsUrl = '{0}{1}/providers/microsoft.Insights/metrics?timespan={2}/{3}&interval=FULL&metricnames={4}&aggregation={5}&metricNamespace={6}&validatedimensions=false&api-version={7}'.format(
        resourceManager.rstrip("/"),
        clusterResourceId,
        starttime,
        endtime,
        constants.NODE_MEMORY_WS_PERCENTAGE_METRIC_NAME,
        constants.NODE_METRIC_METRIC_AGGREGATION,
        constants.NODE_METRICS_NAMESPACE,
        constants.METRICS_API_VERSION)

    response = requests.get(custommetricsUrl, params=params,
                            headers=Headers)

    if not response:
        pytest.fail("response of the metrics query API shouldnt be null or empty")

    if response.status_code != 200:
       pytest.fail("metrics query API failed with an error code: {}".format(
           response.status_code))

    responseJSON = response.json()
    if not responseJSON:
        pytest.fail("response JSON shouldnt be null or empty")

    namespace = responseJSON['namespace']
    if namespace != constants.NODE_METRICS_NAMESPACE:
        pytest.fail("got the namespace: {0} but expected namespace:{1} in the response".format(
            namespace, constants.NODE_METRICS_NAMESPACE))

    responseValues = responseJSON['value']
    if not responseValues:
        pytest.fail("response JSON shouldnt be null or empty")

    if len(responseValues) <= 0:
        pytest.fail("length of value array in the response should be greater than 0")

    for responseVal in responseValues:
        metricName = responseVal['name']['value']
        if metricName != constants.NODE_MEMORY_WS_PERCENTAGE_METRIC_NAME:
            pytest.fail("got the metricname: {0} but expected metricname:{1} in the response".format(metricName, constants.NODE_MEMORY_WS_PERCENTAGE_METRIC_NAME))
        timeseries = responseVal['timeseries']
        if not timeseries:
            pytest.fail("metric series shouldnt be null or empty for metric:{0} in namespace: {1}".format(
                constants.NODE_MEMORY_WS_PERCENTAGE_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))
        if len(timeseries) <= 0:
            pytest.fail("length of timeseries should be greater than for 0 for metric: {0} in namespace :{1}".format(constants.NODE_MEMORY_WS_PERCENTAGE_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))

    # node metric - cpuUsageMilliCores
    custommetricsUrl = '{0}{1}/providers/microsoft.Insights/metrics?timespan={2}/{3}&interval=FULL&metricnames={4}&aggregation={5}&metricNamespace={6}&validatedimensions=false&api-version={7}'.format(
        resourceManager.rstrip("/"),
        clusterResourceId,
        starttime,
        endtime,
        constants.NODE_CPU_USAGE_MILLI_CORES_METRIC_NAME,
        constants.NODE_METRIC_METRIC_AGGREGATION,
        constants.NODE_METRICS_NAMESPACE,
        constants.METRICS_API_VERSION)

    response = requests.get(custommetricsUrl, params=params,
                            headers=Headers)

    if not response:
        pytest.fail("response of the metrics query API shouldnt be null or empty")

    if response.status_code != 200:
       pytest.fail("metrics query API failed with an error code: {}".format(response.status_code))

    responseJSON = response.json()
    if not responseJSON:
        pytest.fail("response JSON shouldnt be null or empty")

    namespace = responseJSON['namespace']
    if namespace != constants.NODE_METRICS_NAMESPACE:
        pytest.fail("got the namespace: {0} but expected namespace:{1} in the response".format(
            namespace, constants.NODE_METRICS_NAMESPACE))

    responseValues = responseJSON['value']
    if not responseValues:
        pytest.fail("response JSON shouldnt be null or empty")

    if len(responseValues) <= 0:
        pytest.fail("length of value array in the response should be greater than 0")

    for responseVal in responseValues:
        metricName = responseVal['name']['value']
        if metricName != constants.NODE_CPU_USAGE_MILLI_CORES_METRIC_NAME:
            pytest.fail("got the metricname: {0} but expected metricname:{1} in the response".format(metricName, constants.NODE_CPU_USAGE_MILLI_CORES_METRIC_NAME))
        timeseries = responseVal['timeseries']
        if not timeseries:
            pytest.fail("metric series shouldnt be null or empty for metric:{0} in namespace: {1}".format(
                constants.NODE_CPU_USAGE_MILLI_CORES_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))
        if len(timeseries) <= 0:
            pytest.fail("length of timeseries should be greater than for 0 for metric: {0} in namespace :{1}".format(constants.NODE_CPU_USAGE_MILLI_CORES_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))

    # node metric - cpuUsagePercentage
    custommetricsUrl = '{0}{1}/providers/microsoft.Insights/metrics?timespan={2}/{3}&interval=FULL&metricnames={4}&aggregation={5}&metricNamespace={6}&validatedimensions=false&api-version={7}'.format(
        resourceManager.rstrip("/"),
        clusterResourceId,
        starttime,
        endtime,
        constants.NODE_CPU_USAGE_PERCENTAGE_METRIC_NAME,
        constants.NODE_METRIC_METRIC_AGGREGATION,
        constants.NODE_METRICS_NAMESPACE,
        constants.METRICS_API_VERSION)

    response = requests.get(custommetricsUrl, params=params,
                            headers=Headers)

    if not response:
        pytest.fail("response of the metrics query API shouldnt be null or empty")

    if response.status_code != 200:
       pytest.fail("metrics query API failed with an error code: {}".format(response.status_code))

    responseJSON = response.json()
    if not responseJSON:
        pytest.fail("response JSON shouldnt be null or empty")

    namespace = responseJSON['namespace']
    if namespace != constants.NODE_METRICS_NAMESPACE:
        pytest.fail("got the namespace: {0} but expected namespace:{1} in the response".format(
            namespace, constants.NODE_METRICS_NAMESPACE))

    responseValues = responseJSON['value']
    if not responseValues:
        pytest.fail("response JSON shouldnt be null or empty")

    if len(responseValues) <= 0:
        pytest.fail("length of value array in the response should be greater than 0")

    for responseVal in responseValues:
        metricName = responseVal['name']['value']
        if metricName != constants.NODE_CPU_USAGE_PERCENTAGE_METRIC_NAME:
            pytest.fail("got the metricname: {0} but expected metricname:{1} in the response".format(metricName, constants.NODE_CPU_USAGE_PERCENTAGE_METRIC_NAME))
        timeseries = responseVal['timeseries']
        if not timeseries:
            pytest.fail("metric series shouldnt be null or empty for metric:{0} in namespace: {1}".format(
                constants.NODE_CPU_USAGE_PERCENTAGE_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))
        if len(timeseries) <= 0:
            pytest.fail("length of timeseries should be greater than for 0 for metric: {0} in namespace :{1}".format(constants.NODE_CPU_USAGE_PERCENTAGE_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))

    # node metric - nodesCount
    custommetricsUrl = '{0}{1}/providers/microsoft.Insights/metrics?timespan={2}/{3}&interval=FULL&metricnames={4}&aggregation={5}&metricNamespace={6}&validatedimensions=false&api-version={7}'.format(
        resourceManager.rstrip("/"),
        clusterResourceId,
        starttime,
        endtime,
        constants.NODE_COUNT_METRIC_NAME,
        constants.NODE_METRIC_METRIC_AGGREGATION,
        constants.NODE_METRICS_NAMESPACE,
        constants.METRICS_API_VERSION)

    response = requests.get(custommetricsUrl, params=params,
                            headers=Headers)

    if not response:
        pytest.fail("response of the metrics query API shouldnt be null or empty")

    if response.status_code != 200:
       pytest.fail("metrics query API failed with an error code: {}".format(response.status_code))

    responseJSON = response.json()
    if not responseJSON:
        pytest.fail("response JSON shouldnt be null or empty")

    namespace = responseJSON['namespace']
    if namespace != constants.NODE_METRICS_NAMESPACE:
        pytest.fail("got the namespace: {0} but expected namespace:{1} in the response".format(
            namespace, constants.NODE_METRICS_NAMESPACE))

    responseValues = responseJSON['value']
    if not responseValues:
        pytest.fail("response JSON shouldnt be null or empty")

    if len(responseValues) <= 0:
        pytest.fail("length of value array in the response should be greater than 0")

    for responseVal in responseValues:
        metricName = responseVal['name']['value']
        if metricName != constants.NODE_COUNT_METRIC_NAME:
            pytest.fail("got the metricname: {0} but expected metricname:{1} in the response".format(metricName, constants.NODE_COUNT_METRIC_NAME))
        timeseries = responseVal['timeseries']
        if not timeseries:
            pytest.fail("metric series shouldnt be null or empty for metric:{0} in namespace: {1}".format(
                constants.NODE_COUNT_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))
        if len(timeseries) <= 0:
            pytest.fail("length of timeseries should be greater than for 0 for metric: {0} in namespace :{1}".format(constants.NODE_COUNT_METRIC_NAME, constants.NODE_METRICS_NAMESPACE))

    append_result_output("test_node_metrics_e2e_workflow end \n",
                         env_dict['TEST_AGENT_LOG_FILE'])
    print("Successfully completed node metrics e2e workflow test.")
