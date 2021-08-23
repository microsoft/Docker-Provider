AZURE_PUBLIC_CLOUD_ENDPOINTS = {
    "activeDirectory": "https://login.microsoftonline.com/",
    "activeDirectoryDataLakeResourceId": "https://datalake.azure.net/",
    "activeDirectoryGraphResourceId": "https://graph.windows.net/",
    "activeDirectoryResourceId": "https://management.core.windows.net/",
    "appInsights": "https://api.applicationinsights.io",
    "appInsightsTelemetryChannel": "https://dc.applicationinsights.azure.com/v2/track",
    "batchResourceId": "https://batch.core.windows.net/",
    "gallery": "https://gallery.azure.com/",
    "logAnalytics": "https://api.loganalytics.io",
    "management": "https://management.core.windows.net/",
    "mediaResourceId": "https://rest.media.azure.net",
    "microsoftGraphResourceId": "https://graph.microsoft.com/",
    "ossrdbmsResourceId": "https://ossrdbms-aad.database.windows.net",
    "resourceManager": "https://management.azure.com/",
    "sqlManagement": "https://management.core.windows.net:8443/",
    "vmImageAliasDoc": "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/master/arm-compute/quickstart-templates/aliases.json"
}

AZURE_DOGFOOD_ENDPOINTS = {
    "activeDirectory": "https://login.windows-ppe.net/",
    "activeDirectoryDataLakeResourceId": None,
    "activeDirectoryGraphResourceId": "https://graph.ppe.windows.net/",
    "activeDirectoryResourceId": "https://management.core.windows.net/",
    "appInsights": None,
    "appInsightsTelemetryChannel": None,
    "batchResourceId": None,
    "gallery": "https://df.gallery.azure-test.net/",
    "logAnalytics": None,
    "management": "https://management-preview.core.windows-int.net/",
    "mediaResourceId": None,
    "microsoftGraphResourceId": None,
    "ossrdbmsResourceId": None,
    "resourceManager": "https://api-dogfood.resources.windows-int.net/",
    "sqlManagement": None,
    "vmImageAliasDoc": None
}

AZURE_CLOUD_DICT = {"AZURE_PUBLIC_CLOUD" : AZURE_PUBLIC_CLOUD_ENDPOINTS, "AZURE_DOGFOOD": AZURE_DOGFOOD_ENDPOINTS}

TIMEOUT = 300

# WAIT TIME BEFORE READING THE AGENT LOGS
AGENT_WAIT_TIME_SECS = "180"
# Azure Monitor for Container Extension related
AGENT_RESOURCES_NAMESPACE = 'kube-system'
AGENT_DEPLOYMENT_NAME = 'omsagent-rs'
AGENT_DAEMONSET_NAME = 'omsagent'
AGENT_WIN_DAEMONSET_NAME = 'omsagent-win'

AGENT_DEPLOYMENT_PODS_LABEL_SELECTOR = 'rsName=omsagent-rs'
AGENT_DAEMON_SET_PODS_LABEL_SELECTOR = 'dsName=omsagent-ds'
AGENT_DAEMON_SET_PODS_LABEL_SELECTOR_NON_ARC = 'component=oms-agent'
AGENT_FLUENTD_LOG_PATH = '/var/opt/microsoft/docker-cimprov/log/fluentd.log'
AGENT_OMSAGENT_LOG_PATH = '/var/opt/microsoft/omsagent/log/omsagent.log'
AGENT_REPLICASET_WORKFLOWS = ["kubePodInventoryEmitStreamSuccess", "kubeNodeInventoryEmitStreamSuccess"]

# override this through setting enviornment variable if the expected restart count is > 0 for example applying configmap
AGENT_POD_EXPECTED_RESTART_COUNT = 0

# replicaset workflow streams
KUBE_POD_INVENTORY_EMIT_STREAM = "kubePodInventoryEmitStreamSuccess"
KUBE_NODE_INVENTORY_EMIT_STREAM = "kubeNodeInventoryEmitStreamSuccess"
KUBE_DEPLOYMENT_INVENTORY_EMIT_STREAM = "kubestatedeploymentsInsightsMetricsEmitStreamSuccess"
KUBE_CONTAINER_PERF_EMIT_STREAM = "kubeContainerPerfEventEmitStreamSuccess"
KUBE_SERVICES_EMIT_STREAM = "kubeServicesEventEmitStreamSuccess"
KUBE_CONTAINER_NODE_INVENTORY_EMIT_STREAM = "containerNodeInventoryEmitStreamSuccess"
KUBE_EVENTS_EMIT_STREAM = "kubeEventsInventoryEmitStreamSuccess"
# daemonset workflow streams
CONTAINER_PERF_EMIT_STREAM = "cAdvisorPerfEmitStreamSuccess"
CONTAINER_INVENTORY_EMIT_STREAM = "containerInventoryEmitStreamSuccess"

# simple log analytics queries to validate for e2e workflows
DEFAULT_QUERY_TIME_INTERVAL_IN_MINUTES = 10
KUBE_POD_INVENTORY_QUERY = "KubePodInventory |  where TimeGenerated > ago({0}) | count"
KUBE_NODE_INVENTORY_QUERY = "KubeNodeInventory |  where TimeGenerated > ago({0}) | count"
KUBE_SERVICES_QUERY = "KubeServices |  where TimeGenerated > ago({0}) | count"
KUBE_EVENTS_QUERY = "KubeEvents |  where TimeGenerated > ago({0}) | count"
CONTAINER_NODE_INVENTORY_QUERY = "ContainerNodeInventory |  where TimeGenerated > ago({0}) | count"
CONTAINER_INVENTORY_QUERY = "ContainerInventory |  where TimeGenerated > ago({0}) | count"
# node perf
NODE_PERF_CPU_CAPCITY_QUERY = "Perf | where ObjectName == 'K8SNode' | where CounterName == 'cpuCapacityNanoCores' |  where TimeGenerated > ago({0}) | count"
NODE_PERF_MEMORY_CAPCITY_QUERY = "Perf | where ObjectName == 'K8SNode' | where CounterName == 'memoryCapacityBytes' |  where TimeGenerated > ago({0}) | count"
NODE_PERF_CPU_ALLOCATABLE_QUERY = "Perf | where ObjectName == 'K8SNode' | where CounterName == 'cpuAllocatableNanoCores' |  where TimeGenerated > ago({0}) | count"
NODE_PERF_MEMORY_ALLOCATABLE_QUERY = "Perf | where ObjectName == 'K8SNode' | where CounterName == 'memoryAllocatableBytes' |  where TimeGenerated > ago({0}) | count"
NODE_PERF_CPU_USAGE_QUERY = "Perf | where ObjectName == 'K8SNode' | where CounterName == 'cpuUsageNanoCores' |  where TimeGenerated > ago({0}) | count"
NODE_PERF_MEMORY_RSS_USAGE_QUERY = "Perf | where ObjectName == 'K8SNode' | where CounterName == 'memoryRssBytes' |  where TimeGenerated > ago({0}) | count"
NODE_PERF_MEMORY_WS_USAGE_QUERY = "Perf | where ObjectName == 'K8SNode' | where CounterName =='memoryWorkingSetBytes' |  where TimeGenerated > ago({0}) | count"
NODE_PERF_RESTART_TIME_EPOCH_QUERY = "Perf | where ObjectName == 'K8SNode' | where CounterName == 'restartTimeEpoch' |  where TimeGenerated > ago({0}) | count"
# container perf
CONTAINER_PERF_CPU_LIMITS_QUERY = "Perf | where ObjectName == 'K8SContainer' | where CounterName == 'cpuLimitNanoCores' |  where TimeGenerated > ago({0}) | count"
CONTAINER_PERF_MEMORY_LIMITS_QUERY = "Perf | where ObjectName == 'K8SContainer' | where CounterName == 'memoryLimitBytes' |  where TimeGenerated > ago({0}) | count"
CONTAINER_PERF_CPU_REQUESTS_QUERY = "Perf | where ObjectName == 'K8SContainer' | where CounterName == 'cpuRequestNanoCores' |  where TimeGenerated > ago({0}) | count"
CONTAINER_PERF_MEMORY_REQUESTS_QUERY = "Perf | where ObjectName == 'K8SContainer' | where CounterName == 'memoryRequestBytes' |  where TimeGenerated > ago({0}) | count"
CONTAINER_PERF_CPU_USAGE_QUERY = "Perf | where ObjectName == 'K8SContainer' | where CounterName == 'cpuUsageNanoCores' |  where TimeGenerated > ago({0}) | count"
CONTAINER_PERF_MEMORY_RSS_USAGE_QUERY = "Perf | where ObjectName == 'K8SContainer' | where CounterName == 'memoryRssBytes' |  where TimeGenerated > ago({0}) | count"
CONTAINER_PERF_MEMORY_WS_USAGE_QUERY = "Perf | where ObjectName == 'K8SContainer' | where CounterName == 'memoryWorkingSetBytes' |  where TimeGenerated > ago({0}) | count"
CONTAINER_PERF_RESTART_TIME_EPOCH_QUERY = "Perf | where ObjectName == 'K8SContainer' | where CounterName == 'restartTimeEpoch' |  where TimeGenerated > ago({0}) | count"
# container log
CONTAINER_LOG_QUERY = "ContainerLog |  where TimeGenerated > ago({0}) | count"
# insights metrics
INSIGHTS_METRICS_QUERY = "InsightsMetrics |  where TimeGenerated > ago({0}) | count"

# custom metrics
METRICS_API_VERSION = '2019-07-01'
DEFAULT_METRICS_QUERY_TIME_INTERVAL_IN_MINUTES = 10

# node metrics
NODE_METRICS_NAMESPACE = 'insights.container/nodes'
NODE_METRIC_METRIC_AGGREGATION = 'average'
NODE_CPU_USAGE_MILLI_CORES_METRIC_NAME = 'cpuUsageMilliCores'
NODE_CPU_USAGE_PERCENTAGE_METRIC_NAME = 'cpuUsagePercentage'
NODE_MEMORY_RSS_METRIC_NAME = 'memoryRssBytes'
NODE_MEMORY_RSS_PERCENTAGE_METRIC_NAME = 'memoryRssPercentage'
NODE_MEMORY_WS_METRIC_NAME = 'memoryWorkingSetBytes'
NODE_MEMORY_WS_PERCENTAGE_METRIC_NAME = 'memoryWorkingSetPercentage'
NODE_COUNT_METRIC_NAME = 'nodesCount'
NODE_DISK_USAGE_PERCENTAGE_METRIC_NAME = 'diskUsedPercentage(Preview)'

# pod metrics
POD_METRICS_NAMESPACE = 'insights.container/pods'
POD_METRIC_METRIC_AGGREGATION = 'average'
POD_COUNT_METRIC_NAME = 'PodCount'
