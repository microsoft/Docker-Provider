import pytest
import requests
import time
import json

from kubernetes import client, config

# Adjusted imports to reference modules in the common directory
from common import constants
from common.arm_rest_utility import fetch_aad_token_credentials, build_scope
from common.kubernetes_pod_utility import get_pod_list
from common.results_utility import append_result_output


pytestmark = pytest.mark.agentests

# Mapping of workflow name to query template attribute in constants for parametrization
WORKFLOWS = [
    ('KUBE_POD_INVENTORY', 'KUBE_POD_INVENTORY_QUERY'),
    ('KUBE_NODE_INVENTORY', 'KUBE_NODE_INVENTORY_QUERY'),
    ('KUBE_SERVICES', 'KUBE_SERVICES_QUERY'),
    ('KUBE_EVENTS', 'KUBE_EVENTS_QUERY'),
    ('CONTAINER_NODE_INVENTORY', 'CONTAINER_NODE_INVENTORY_QUERY'),
    ('NODE_PERF_CPU_CAPCITY', 'NODE_PERF_CPU_CAPCITY_QUERY'),
    ('NODE_PERF_MEMORY_CAPCITY', 'NODE_PERF_MEMORY_CAPCITY_QUERY'),
    ('NODE_PERF_CPU_ALLOCATABLE', 'NODE_PERF_CPU_ALLOCATABLE_QUERY'),
    ('NODE_PERF_MEMORY_ALLOCATABLE', 'NODE_PERF_MEMORY_ALLOCATABLE_QUERY'),
    ('NODE_PERF_CPU_USAGE', 'NODE_PERF_CPU_USAGE_QUERY'),
    ('NODE_PERF_MEMORY_RSS_USAGE', 'NODE_PERF_MEMORY_RSS_USAGE_QUERY'),
    ('NODE_PERF_MEMORY_WS_USAGE', 'NODE_PERF_MEMORY_WS_USAGE_QUERY'),
    ('NODE_PERF_RESTART_TIME_EPOCH', 'NODE_PERF_RESTART_TIME_EPOCH_QUERY'),
    ('CONTAINER_PERF_CPU_LIMITS', 'CONTAINER_PERF_CPU_LIMITS_QUERY'),
    ('CONTAINER_PERF_MEMORY_LIMITS', 'CONTAINER_PERF_MEMORY_LIMITS_QUERY'),
    ('CONTAINER_PERF_CPU_REQUESTS', 'CONTAINER_PERF_CPU_REQUESTS_QUERY'),
    ('CONTAINER_PERF_MEMORY_REQUESTS', 'CONTAINER_PERF_MEMORY_REQUESTS_QUERY'),
    ('CONTAINER_PERF_CPU_USAGE', 'CONTAINER_PERF_CPU_USAGE_QUERY'),
    ('CONTAINER_PERF_MEMORY_RSS_USAGE', 'CONTAINER_PERF_MEMORY_RSS_USAGE_QUERY'),
    ('CONTAINER_PERF_MEMORY_WS_USAGE', 'CONTAINER_PERF_MEMORY_WS_USAGE_QUERY'),
    ('CONTAINER_PERF_RESTART_TIME_EPOCH', 'CONTAINER_PERF_RESTART_TIME_EPOCH_QUERY'),
    ('CONTAINER_LOG_V2', 'CONTAINER_LOG_V2_QUERY'),
    ('CONTAINER_LOG_V2_K8S_METADATA', 'CONTAINER_LOG_V2_K8S_METADATA_QUERY'),
    ('INSIGHTS_METRICS', 'INSIGHTS_METRICS_QUERY'),
]

@pytest.fixture(scope='session')
def la_context(env_dict):
    """Session-scoped context containing headers/queryUrl so each workflow test can reuse them.
    Performs the initial wait once and caches results in a dict for summary reporting.
    """
    append_result_output("la_context init start\n", env_dict['TEST_AGENT_LOG_FILE'])
    # Load kube config once
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))

    queryTimeInterval = env_dict.get('DEFAULT_QUERY_TIME_INTERVAL_IN_MINUTES')
    if not queryTimeInterval:
        pytest.fail("DEFAULT_QUERY_TIME_INTERVAL_IN_MINUTES should not be null or empty")

    api_instance = client.CoreV1Api()
    pod_list = get_pod_list(api_instance, constants.AGENT_RESOURCES_NAMESPACE,
                            constants.AGENT_DEPLOYMENT_PODS_LABEL_SELECTOR)
    if not pod_list or len(pod_list.items) <= 0:
        pytest.fail("pod_list empty while building la_context")

    envVars = pod_list.items[0].spec.containers[0].env
    if (len(pod_list.items[0].spec.containers) > 1):
        for container in pod_list.items[0].spec.containers:
            if (container.name == constants.AMA_LOGS_MAIN_CONTAINER_NAME):
                envVars = container.env
                break
    clusterResourceId = ''
    for env in envVars:
        if env.name == "AKS_RESOURCE_ID":
            clusterResourceId = env.value
            print("cluster resource id: {}".format(clusterResourceId))
            break
    if not clusterResourceId:
        pytest.fail("Failed to retrieve AKS_RESOURCE_ID for la_context")

    tenant_id = env_dict.get('TENANT_ID')
    # Pass base authority host only (tenant supplied separately)
    authority_uri = env_dict.get('AZURE_ENDPOINTS').get('activeDirectory')
    client_id = env_dict.get('CLIENT_ID')
    client_secret = env_dict.get('CLIENT_SECRET')
    resource = env_dict.get('AZURE_ENDPOINTS').get('logAnalytics')

    credential = fetch_aad_token_credentials(
        tenant_id=tenant_id,
        client_id=client_id,
        client_secret=client_secret,
        authority=authority_uri,
        use_cert_auth=False,
        use_SPN_auth=False,
        use_FIC_auth=True
    )
    try:
        token = credential.get_token(build_scope(resource))
    except Exception as ex:
        pytest.fail(f"Failed to acquire access token via credential: {ex}")
    access_token = token.token
    if not access_token:
        pytest.fail("access_token shouldn't be null or empty in la_context")
    queryUrl = resource.rstrip('/') + "/v1" + clusterResourceId + "/query"
    headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}

    waitTimeSeconds = env_dict.get('AGENT_WAIT_TIME_SECS', 0)
    if waitTimeSeconds and int(waitTimeSeconds) > 0:
        print(f"[la_context] Sleeping {waitTimeSeconds}s for workflows emission")
        time.sleep(int(waitTimeSeconds))

    context = {
        'queryTimeInterval': queryTimeInterval,
        'queryUrl': queryUrl,
        'headers': headers,
        'clusterResourceId': clusterResourceId,
        'results': {}
    }
    append_result_output("la_context init end\n", env_dict['TEST_AGENT_LOG_FILE'])
    return context

@pytest.fixture(scope='session', autouse=True)
def la_results_report(env_dict, la_context):
    """After all workflow tests have run, output a summary of rowCounts."""
    yield
    results = la_context.get('results', {})
    lines = ["Workflow Query Summary (rowCount):"]
    for wf, rowCount in results.items():
        lines.append(f" - {wf}: {rowCount}")
    summary = "\n".join(lines) + "\n"
    print(summary)
    append_result_output(summary, env_dict['TEST_AGENT_LOG_FILE'])

@pytest.mark.parametrize('workflow_name,query_attr', WORKFLOWS)
def test_la_workflow_rowcount(workflow_name, query_attr, la_context):
    """Parametrized test executing each workflow query independently."""
    query_template = getattr(constants, query_attr)
    query = query_template.format(la_context['queryTimeInterval'])
    row_count = _validate_la_query(workflow_name, la_context['queryUrl'], query, la_context['headers'])
    la_context['results'][workflow_name] = row_count

def _validate_la_query(workflow_name: str, query_url: str, query: str, headers: dict):
    """Execute a Log Analytics resource-centric query and return row count.

    Provides richer failure diagnostics than the previous inline pattern:
    - Asserts HTTP status code is 200.
    - Logs response text when JSON parsing fails.
    - Includes workflow name, status code, and partial body in failure message.
    """
    params = { 'query': query }
    try:
        resp = requests.get(query_url, params=params, headers=headers, timeout=30)
    except Exception as ex:
        pytest.fail(f"Exception during request for workflow {workflow_name}: {ex}")

    if resp is None:
        pytest.fail(f"No response object returned for workflow {workflow_name}")

    if resp.status_code != 200:
        body_snippet = resp.text[:500] if resp.text else '<empty body>'
        pytest.fail(f"Unexpected status code {resp.status_code} for workflow {workflow_name}. Body (truncated): {body_snippet}")

    try:
        data = resp.json()
    except ValueError:
        body_snippet = resp.text[:500] if resp.text else '<empty body>'
        pytest.fail(f"Failed to parse JSON for workflow {workflow_name}. Body (truncated): {body_snippet}")

    # Defensive checks on expected structure
    if 'tables' not in data or not data['tables']:
        pytest.fail(f"Response JSON missing 'tables' for workflow {workflow_name}: {json.dumps(data)[:500]}")
    if 'rows' not in data['tables'][0] or not data['tables'][0]['rows']:
        pytest.fail(f"Response JSON missing 'rows' in first table for workflow {workflow_name}: {json.dumps(data['tables'][0])[:500]}")
    if not data['tables'][0]['rows'][0] or len(data['tables'][0]['rows'][0]) < 1:
        pytest.fail(f"First row empty for workflow {workflow_name}: {json.dumps(data['tables'][0]['rows'][0])[:200]}")

    row_count = data['tables'][0]['rows'][0][0]
    if not row_count:
        pytest.fail(f"rowCount should be greater than 0 for workflow {workflow_name}. Full first row: {data['tables'][0]['rows'][0]}")
    print(f"Workflow {workflow_name} query succeeded with rowCount={row_count}")
    return row_count

# Removed legacy monolithic test_e2e_workflows in favor of parametrized tests.
