export interface Query {
  name: string;
  datasource: string;
  kql: string;
}

export type QueryCategory =
  | "triage"
  | "errors"
  | "workload"
  | "pods"
  | "logs"
  | "config";

export const QUERIES: Record<QueryCategory, Query[]> = {
  // ─────────────────────────────────────────────
  // TRIAGE — Initial investigation
  // ─────────────────────────────────────────────
  triage: [
    {
      name: "Agent Version",
      datasource: "ContainerInsightsAppInsights",
      kql: `customEvents
| where timestamp >= _startTime and timestamp <= _endTime
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| extend version = tostring(customDimensions.Version)
| distinct version`,
    },
    {
      name: "Pod Count",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name =~ "PodCount"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| summarize max(value) by bin(timestamp, 10m)
| order by timestamp desc
| take 20`,
    },
    {
      name: "Node Count",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name =~ "NodeCount"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| summarize max(value) by bin(timestamp, 10m)
| order by timestamp desc
| take 20`,
    },
    {
      name: "High Log Scale Mode",
      datasource: "ContainerInsightsAppInsights",
      kql: `customEvents
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerLogDaemonSetHeartbeatEvent"
| extend ID = tostring(customDimensions.ID), isHighLogScaleMode = tostring(customDimensions.isHighLogScaleMode)
| where ID =~ _cluster
| project timestamp, isHighLogScaleMode
| order by timestamp desc
| take 1`,
    },
    {
      name: "PODS_CHUNK_SIZE",
      datasource: "ContainerInsightsAppInsights",
      kql: `customEvents
| where timestamp >= _startTime and timestamp <= _endTime
| where name =~ "KubePodInventoryHeartBeatEvent"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| project timestamp, PODS_CHUNK_SIZE = tostring(customDimensions.PODS_CHUNK_SIZE)
| order by timestamp desc
| take 1`,
    },
    {
      name: "Cluster Scale Metrics",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| extend AksResourceId = tostring(customDimensions.AKS_RESOURCE_ID)
| where AksResourceId =~ _cluster
| where name in ("PodCount", "EventCount", "ServiceCount", "MaxDeploymentCount")
| summarize max = max(value) by bin(timestamp, totimespan(Interval)), name
| order by timestamp desc`,
    },
    {
      name: "Controller Counts",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| extend AksResourceId = tostring(customDimensions.AKS_RESOURCE_ID)
| where AksResourceId =~ _cluster
| where name == "ControllerCount"
| extend ControllerData = parse_json(customDimensions.ControllerData)
| extend ReplicaSetCount = toint(tostring(ControllerData.ReplicaSet)),
         DaemonSetCount = toint(tostring(ControllerData.DaemonSet)),
         StatefulSetCount = toint(tostring(ControllerData.StatefulSet)),
         JobCount = toint(tostring(ControllerData.Job)),
         CronJobCount = toint(tostring(ControllerData.CronJob)),
         DeploymentCount = toint(tostring(ControllerData.Deployment))
| summarize max_total = max(value) by bin(timestamp, totimespan(Interval)),
  ReplicaSetCount, DaemonSetCount, StatefulSetCount, JobCount, CronJobCount, DeploymentCount
| order by timestamp desc
| take 20`,
    },
    {
      name: "Private Cluster Check",
      datasource: "AKS",
      kql: `ManagedClusterSnapshot
| where TIMESTAMP >= _startTime
| where name == '_clusterName'
| top 1 by TIMESTAMP desc
| project TIMESTAMP, privateLinkProfile = tostring(privateLinkProfile)`,
    },
    {
      name: "Fleet Version Distribution",
      datasource: "ContainerInsightsAppInsights",
      kql: `customEvents
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerLogDaemonSetHeartbeatEvent"
| extend Version = tostring(customDimensions.Version)
| summarize Pods = dcount(tostring(customDimensions.Computer)), Events = count() by Version
| order by Events desc`,
    },
    {
      name: "RS Heartbeat Check",
      datasource: "ContainerInsightsAppInsights",
      kql: `customEvents
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "KubePodInventoryHeartBeatEvent"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| extend Computer = tostring(customDimensions.Computer)
| where Computer startswith "ama-logs-rs-"
| summarize HeartbeatCount = count(), LastHeartbeat = max(timestamp) by Computer
| order by LastHeartbeat desc`,
    },
    {
      name: "Managed Cluster Profile",
      datasource: "AKS",
      kql: `ManagedClusterSnapshot
| where TIMESTAMP >= _startTime
| where name == '_clusterName'
| top 1 by TIMESTAMP desc
| project TIMESTAMP,
    location,
    provisioningState,
    omsagent_enabled = tostring(addonProfiles.omsagent.enabled),
    omsagent_useAADAuth = tostring(addonProfiles.omsagent.config.useAADAuth),
    omsagent_addonv2 = tostring(addonProfiles.omsagent.config.addonv2),
    omsagent_workspace = tostring(addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID),
    privateLinkProfile = tostring(privateLinkProfile)`,
    },
    {
      name: "Managed Cluster Addon Identity",
      datasource: "AKS",
      kql: `ManagedClusterMonitoring
| where TIMESTAMP >= _startTime
| where subscriptionID == '_subscriptionId' and resourceName == '_clusterName'
| where entitytype == "managedcluster"
| top 1 by TIMESTAMP desc
| extend msgJson = parse_json(msg)
| project
    controlPlaneID = tostring(msgJson.controlPlaneID),
    omsagent_enabled = tostring(msgJson.containerService.properties.addonProfiles.omsagent.enabled),
    omsagent_useAADAuth = tostring(msgJson.containerService.properties.addonProfiles.omsagent.config.useAADAuth),
    omsagent_identity_resourceId = tostring(msgJson.containerService.properties.addonProfiles.omsagent.identity.resourceId),
    omsagent_identity_clientId = tostring(msgJson.containerService.properties.addonProfiles.omsagent.identity.clientId),
    azureMonitorProfile = tostring(msgJson.containerService.properties.azureMonitorProfile),
    workspace = tostring(msgJson.containerService.properties.addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID)`,
    },
    {
      name: "AKS Alerts Firing",
      datasource: "AKS",
      kql: `AKSAlertmanager
| where PreciseTimeStamp >= _startTime
| where alertname startswith "AmaLogs"
| where status == "firing"
| where resource_id =~ _cluster
| extend PodName = parse_json(log).podName
| extend Status = alertname
| distinct PodName, Status
| order by PodName asc`,
    },
    {
      name: "Addon Enable/Disable History",
      datasource: "AKS",
      kql: `ManagedClusterSnapshot
| where name == '_clusterName'
| where TIMESTAMP >= _startTime
| extend omsEnabled = tostring(parse_json(tostring(addonProfiles.omsagent)).enabled)
| extend omsConfig = tostring(parse_json(tostring(addonProfiles.omsagent)).config)
| summarize arg_min(TIMESTAMP, omsEnabled, omsConfig, provisioningState, latestOperationID) by bin(TIMESTAMP, 1h)
| order by TIMESTAMP asc`,
    },
    {
      name: "Cluster Node Info",
      datasource: "AKS",
      kql: `ManagedClusterSnapshot
| where name == '_clusterName'
| where TIMESTAMP >= _startTime
| top 1 by TIMESTAMP desc
| project
    location,
    provisioningState,
    kubernetesVersion = tostring(orchestratorProfile.orchestratorVersion),
    nodeResourceGroup,
    privateLinkProfile = tostring(privateLinkProfile)`,
    },
    {
      name: "Mutating Operations",
      datasource: "AKS",
      kql: `let tenMinutesInMs = (10*60*1000);
union withsource=TS FrontEndQoSEvents, AsyncQoSEvents
| where PreciseTimeStamp >= _startTime
| where
    subscriptionID =~ '_subscriptionId' and
    resourceGroupName =~ '_resourceGroup' and
    resourceName =~ '_clusterName'
| where httpMethod != "GET" and operationName !startswith "List"
| where operationName !in ('RunCommandHandler.POST')
| extend logPreciseTime = todatetime(coalesce(
    tostring(column_ifexists("logPreciseTime", datetime(null))),
    tostring(column_ifexists("logPreciseTime_datetime", datetime(null))),
    column_ifexists("logPreciseTime_string", ""),
    ""
))
| extend StartTime = datetime_add("millisecond", (latency * -1), logPreciseTime)
| extend EndTime = logPreciseTime
| extend errorDetails = iff(errorDetails != 'na', errorDetails, '')
| summarize
    StartTime = min(StartTime), EndTime = max(EndTime),
    take_any(operationName, suboperationName, agentPoolName, httpMethod, httpStatus, resultCode, result, errorDetails, userAgent, clientPrincipalName)
    by operationID
| extend Content = strcat(tostring(split(operationName, 'Handler')[0]),
    iif(isempty(agentPoolName), strcat(" (", suboperationName, ")"),
    strcat(" - ", suboperationName, " (", agentPoolName, ")")))
| extend durationMin = round(datetime_diff("second", EndTime, StartTime) / 60.0, 1)
| project StartTime, EndTime, durationMin, Content, operationName, suboperationName,
    agentPoolName, result, resultCode, errorDetails, operationID, userAgent, clientPrincipalName
| order by StartTime asc`,
    },
  ],

  // ─────────────────────────────────────────────
  // ERRORS — Error scanning across components
  // ─────────────────────────────────────────────
  errors: [
    {
      name: "Exceptions",
      datasource: "ContainerInsightsAppInsights",
      kql: `exceptions
| where timestamp >= _startTime and timestamp <= _endTime
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| summarize count() by type, outerMessage, bin(timestamp, totimespan(Interval))
| order by count_ desc
| take 50`,
    },
    {
      name: "MDSD Send Errors",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerLogs2MdsdSendErrorCount"
| extend AksResourceId = tostring(customDimensions.AKS_RESOURCE_ID)
| where AksResourceId =~ _cluster
| extend Pod = tostring(customDimensions.Pod)
| summarize sum(value) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "MDSD Client Create Errors",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerLogsMdsdClientCreateErrorCount"
| extend AksResourceId = tostring(customDimensions.AKS_RESOURCE_ID)
| where AksResourceId =~ _cluster
| extend Pod = tostring(customDimensions.Pod)
| summarize sum(value) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "Network Upload Errors (Daemonset)",
      datasource: "ContainerInsightsAppInsights",
      kql: `traces
| where timestamp >= _startTime and timestamp <= _endTime
| project timestamp, ID = tostring(customDimensions.ID), message, Computer = tostring(customDimensions.Computer), cloud_RoleInstance
| where cloud_RoleInstance !startswith "ama-logs-rs-" and cloud_RoleInstance !startswith "ama-logs-windows-"
| where ID =~ _cluster
| where message contains "Failed to upload"
| summarize count() by bin(timestamp, totimespan(Interval)), Computer
| order by count_ desc`,
    },
    {
      name: "Network Upload Errors (Replicaset)",
      datasource: "ContainerInsightsAppInsights",
      kql: `traces
| where timestamp >= _startTime and timestamp <= _endTime
| project timestamp, ID = tostring(customDimensions.ID), message, Computer = tostring(customDimensions.Computer), cloud_RoleInstance
| where cloud_RoleInstance startswith "ama-logs-rs-"
| where ID =~ _cluster
| where message contains "Failed to upload"
| summarize count() by bin(timestamp, totimespan(Interval)), Computer
| order by count_ desc`,
    },
    {
      name: "OMS Homing Errors (Daemonset)",
      datasource: "ContainerInsightsAppInsights",
      kql: `traces
| where timestamp >= _startTime and timestamp <= _endTime
| project timestamp, ID = tostring(customDimensions.ID), message, Computer = tostring(customDimensions.Computer), cloud_RoleInstance
| where cloud_RoleInstance !startswith "ama-logs-rs-" and cloud_RoleInstance !startswith "ama-logs-windows-"
| where ID =~ _cluster
| where message contains "Failed to register certificate with OMS Homing service"
| summarize count() by bin(timestamp, totimespan(Interval)), Computer
| order by count_ desc`,
    },
    {
      name: "OMS Homing Errors (Replicaset)",
      datasource: "ContainerInsightsAppInsights",
      kql: `traces
| where timestamp >= _startTime and timestamp <= _endTime
| project timestamp, ID = tostring(customDimensions.ID), message, Computer = tostring(customDimensions.Computer), cloud_RoleInstance
| where cloud_RoleInstance startswith "ama-logs-rs-"
| where ID =~ _cluster
| where message contains "Failed to register certificate with OMS Homing service"
| summarize count() by bin(timestamp, totimespan(Interval)), Computer
| order by count_ desc`,
    },
    {
      name: "AKS Alerts - Daemonset",
      datasource: "AKS",
      kql: `AKSAlertmanager
| where PreciseTimeStamp >= _startTime
| where alertname startswith "AmaLogsAgentDaemonSet"
| where status == "firing"
| where resource_id =~ _cluster
| extend PodName = parse_json(log).podName
| extend Status = trim_start("AmaLogsAgentDaemonSet", alertname)
| distinct PodName, tostring(parse_json(log).containerName), Status`,
    },
    {
      name: "AKS Alerts - Replicaset",
      datasource: "AKS",
      kql: `AKSAlertmanager
| where PreciseTimeStamp >= _startTime
| where alertname startswith "AmaLogsAgentReplicaSet"
| where status == "firing"
| where resource_id =~ _cluster
| extend PodName = parse_json(log).podName
| extend Status = trim_start("AmaLogsAgentReplicaSet", alertname)
| distinct PodName, tostring(parse_json(log).containerName), Status`,
    },
    {
      name: "Node NetworkNotReady Events",
      datasource: "AKS CCP",
      kql: `KubeSystemEvents
| where TIMESTAMP >= _startTime
| where resourceId =~ _cluster
| where reason == "NetworkNotReady"
| project TIMESTAMP, pod=name, msg=substring(message, 0, 200)
| order by TIMESTAMP desc
| take 20`,
    },
  ],

  // ─────────────────────────────────────────────
  // WORKLOAD — Resource usage and health
  // ─────────────────────────────────────────────
  workload: [
    {
      name: "Memory RSS - Linux Daemonset",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "memoryRssBytes"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod), ContainerName = tostring(customDimensions.ContainerName)
| where ID =~ _cluster
| where Pod !startswith "ama-logs-rs-" and Pod !startswith "ama-logs-windows-"
| where ContainerName !contains "prometheus"
| extend UsageInMB = value/1024/1024
| summarize max_MB = max(UsageInMB) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "Memory RSS - Linux Daemonset Sidecar",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "memoryRssBytes"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod), ContainerName = tostring(customDimensions.ContainerName)
| where ID =~ _cluster
| where Pod !startswith "ama-logs-rs-" and Pod !startswith "ama-logs-windows-"
| where ContainerName contains "prometheus"
| extend UsageInMB = value/1024/1024
| summarize max_MB = max(UsageInMB) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "Memory RSS - Replicaset",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "memoryRssBytes"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod), ContainerName = tostring(customDimensions.ContainerName)
| where ID =~ _cluster
| where Pod startswith "ama-logs-rs-"
| extend UsageInMB = value/1024/1024
| summarize max_MB = max(UsageInMB) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "CPU - Linux Daemonset",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "cpuUsageNanoCores"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod), ContainerName = tostring(customDimensions.ContainerName)
| where ID =~ _cluster
| where Pod !startswith "ama-logs-rs-" and Pod !startswith "ama-logs-windows-"
| where ContainerName !contains "prometheus"
| extend UsageMilliCores = value/1000/1000
| summarize max_mCores = max(UsageMilliCores) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "CPU - Linux Daemonset Sidecar",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "cpuUsageNanoCores"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod), ContainerName = tostring(customDimensions.ContainerName)
| where ID =~ _cluster
| where Pod !startswith "ama-logs-rs-" and Pod !startswith "ama-logs-windows-"
| where ContainerName contains "prometheus"
| extend UsageMilliCores = value/1000/1000
| summarize max_mCores = max(UsageMilliCores) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "CPU - Replicaset",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "cpuUsageNanoCores"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod), ContainerName = tostring(customDimensions.ContainerName)
| where ID =~ _cluster
| where Pod startswith "ama-logs-rs-"
| extend UsageMilliCores = value/1000/1000
| summarize max_mCores = max(UsageMilliCores) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "Container Logs Generated Per Sec",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerLogsGeneratedPerSec"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod), ContainerName = tostring(customDimensions.ContainerName)
| where ID =~ _cluster
| where Pod !startswith "ama-logs-rs-" and Pod !startswith "ama-logs-windows-"
| where ContainerName !contains "prometheus"
| summarize max = max(value) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "Container Log Size Per Sec",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerLogsSize"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod), ContainerName = tostring(customDimensions.ContainerName)
| where ID =~ _cluster
| where Pod !startswith "ama-logs-rs-" and Pod !startswith "ama-logs-windows-"
| where ContainerName !contains "prometheus"
| summarize max = max(value) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "Telegraf Metrics Sent",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "TelegrafMetricsSent"
| extend AksResourceId = tostring(customDimensions.AKS_RESOURCE_ID)
| where AksResourceId =~ _cluster
| summarize max = max(value) by bin(timestamp, totimespan(Interval))
| order by timestamp desc`,
    },
    {
      name: "Memory RSS - Windows Daemonset",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "memoryWorkingSetBytes"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod)
| where ID =~ _cluster
| where Pod startswith "ama-logs-windows-"
| extend UsageInMB = value/1024/1024
| summarize max_MB = max(UsageInMB) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "CPU - Windows Daemonset",
      datasource: "ContainerInsightsAppInsights",
      kql: `customMetrics
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "cpuUsageNanoCores"
| project timestamp, value, ID = tostring(customDimensions.ID), Pod = tostring(customDimensions.Pod)
| where ID =~ _cluster
| where Pod startswith "ama-logs-windows-"
| extend UsageMilliCores = value/1000/1000
| summarize max_mCores = max(UsageMilliCores) by bin(timestamp, totimespan(Interval)), Pod
| order by timestamp desc`,
    },
    {
      name: "Container Count by ReplicaSet",
      datasource: "ContainerInsightsAppInsights",
      kql: `customEvents
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerInventoryHeartBeatEvent"
| extend AksResourceId = tostring(customDimensions.AKS_RESOURCE_ID)
| where AksResourceId =~ _cluster
| extend ControllerType = tostring(customDimensions.ControllerType)
| where ControllerType == "ReplicaSet"
| extend ContainerCount = toint(tostring(customDimensions.ContainerCount))
| summarize max = max(ContainerCount) by bin(timestamp, totimespan(Interval))
| order by timestamp desc`,
    },
    {
      name: "Addon CPU Throttling",
      datasource: "AKS",
      kql: `let ccpId = toscalar(KubeSystemEvents | where PreciseTimeStamp >= _startTime | where resourceId =~ _cluster | take 1 | project cluster_id);
AKSClusterMetrics
| where PreciseTimeStamp >= _startTime
| where cluster_id == ccpId
| where metric == "pod_container:container_cpu_cfs_throttled_milliseconds:max_rate5m"
| where podName startswith "ama-logs"
| summarize max_throttle_ms = max(value) by bin(PreciseTimeStamp, 5m), podName, containerName
| order by PreciseTimeStamp desc`,
    },
  ],

  // ─────────────────────────────────────────────
  // PODS — Pod health and restarts
  // ─────────────────────────────────────────────
  pods: [
    {
      name: "AMA-Logs Pod Restarts",
      datasource: "AKS",
      kql: `AKSAlertmanager
| where PreciseTimeStamp >= _startTime
| where alertname startswith "AmaLogs"
| where status == "firing"
| where resource_id =~ _cluster
| extend PodName = tostring(parse_json(log).podName)
| extend containerName = tostring(parse_json(log).containerName)
| extend Status = alertname
| summarize count() by PodName, containerName, Status
| order by count_ desc`,
    },
    {
      name: "Daemonset Pod Status",
      datasource: "AKS",
      kql: `AKSAlertmanager
| where PreciseTimeStamp >= _startTime
| where alertname startswith "AmaLogsAgentDaemonSet"
| where status == "firing"
| where resource_id =~ _cluster
| extend PodName = tostring(parse_json(log).podName)
| extend containerName = tostring(parse_json(log).containerName)
| extend AlertStatus = trim_start("AmaLogsAgentDaemonSet", alertname)
| distinct PodName, containerName, AlertStatus`,
    },
    {
      name: "Replicaset Pod Status",
      datasource: "AKS",
      kql: `AKSAlertmanager
| where PreciseTimeStamp >= _startTime
| where alertname startswith "AmaLogsAgentReplicaSet"
| where status == "firing"
| where resource_id =~ _cluster
| extend PodName = tostring(parse_json(log).podName)
| extend containerName = tostring(parse_json(log).containerName)
| extend AlertStatus = trim_start("AmaLogsAgentReplicaSet", alertname)
| distinct PodName, containerName, AlertStatus`,
    },
    {
      name: "Pod Events Summary",
      datasource: "AKS CCP",
      kql: `KubeSystemEvents
| where TIMESTAMP >= _startTime
| where resourceId =~ _cluster
| where name has "ama-logs"
| summarize count() by reason
| order by count_ desc`,
    },
    {
      name: "Pod Lifecycle Timeline",
      datasource: "AKS CCP",
      kql: `KubeSystemEvents
| where TIMESTAMP >= _startTime
| where resourceId =~ _cluster
| where name has "ama-logs"
| where reason in ("Created", "Started", "BackOff", "Killing", "Unhealthy", "FailedMount", "NetworkNotReady", "SandboxChanged", "Scheduled", "SuccessfulCreate", "ScalingReplicaSet")
| project TIMESTAMP, pod=name, reason, msg=substring(message, 0, 150)
| order by TIMESTAMP desc
| take 100`,
    },
    {
      name: "Per-Pod Crash Summary",
      datasource: "AKS CCP",
      kql: `KubeSystemEvents
| where TIMESTAMP >= _startTime
| where resourceId =~ _cluster
| where name has "ama-logs"
| where reason == "BackOff"
| extend container = extract("container \\"([^\\"]+)\\"", 1, message)
| summarize BackOffs = count(), FirstSeen = min(TIMESTAMP), LastSeen = max(TIMESTAMP) by name, container
| order by BackOffs desc`,
    },
    {
      name: "FailedMount Events",
      datasource: "AKS CCP",
      kql: `KubeSystemEvents
| where TIMESTAMP >= _startTime
| where resourceId =~ _cluster
| where name has "ama-logs"
| where reason == "FailedMount"
| project TIMESTAMP, pod=name, message
| order by TIMESTAMP desc
| take 50`,
    },
    {
      name: "Liveness Probe Failures",
      datasource: "AKS CCP",
      kql: `KubeSystemEvents
| where TIMESTAMP >= _startTime
| where resourceId =~ _cluster
| where name has "ama-logs"
| where reason in ("Unhealthy", "Killing")
| project TIMESTAMP, pod=name, reason, msg=substring(message, 0, 200)
| order by TIMESTAMP desc
| take 50`,
    },
    {
      name: "Container Start/Exit Timeline",
      datasource: "AKS CCP",
      kql: `KubeSystemEvents
| where TIMESTAMP >= _startTime
| where resourceId =~ _cluster
| where name has "ama-logs"
| where reason in ("Created", "Started", "BackOff", "Killing")
| extend container = case(
    message has "addon-token-adapter", "addon-token-adapter",
    message has "ama-logs-prometheus", "ama-logs-prometheus",
    message has "ama-logs", "ama-logs",
    extract("container \\"([^\\"]+)\\"", 1, message))
| summarize count() by name, reason, container
| order by name asc, reason asc`,
    },
    {
      name: "Container Termination Reason (Kube-Audit)",
      datasource: "AKS CCP",
      kql: `let ccpId = toscalar(KubeSystemEvents | where TIMESTAMP >= _startTime | where resourceId =~ _cluster | take 1 | project cluster_id);
KubeAudit
| where TIMESTAMP >= _startTime
| where cluster_id == ccpId
| where objectRef has "ama-logs" and verb == "patch"
| where requestObject has "terminated"
| extend ro = parse_json(requestObject)
| extend statuses = ro.status.containerStatuses
| mvexpand statuses
| where tostring(statuses.lastState) has "terminated"
| extend terminated = parse_json(tostring(statuses.lastState.terminated))
| project TIMESTAMP,
    container = tostring(statuses.name),
    reason = tostring(terminated.reason),
    exitCode = toint(terminated.exitCode),
    startedAt = tostring(terminated.startedAt),
    finishedAt = tostring(terminated.finishedAt)
| order by TIMESTAMP desc
| take 20`,
    },
    {
      name: "Kill Reason Breakdown",
      datasource: "AKS CCP",
      kql: `KubeSystemEvents
| where TIMESTAMP >= _startTime
| where resourceId =~ _cluster
| where name startswith "ama-logs"
| where reason == "Killing" or message has "OOM" or message has "evict" or message has "memory"
| summarize count() by reason, message=substring(message, 0, 300)
| order by count_ desc`,
    },
    {
      name: "AKSKubeEvents - Non-Routine Events",
      datasource: "AKS CCP",
      kql: `let ccpId = toscalar(KubeSystemEvents | where TIMESTAMP >= _startTime | where resourceId =~ _cluster | take 1 | project cluster_id);
AKSKubeEvents
| where TIMESTAMP >= _startTime
| where cluster_id == ccpId
| where name startswith "ama-logs"
| where reason !in ("BackOff", "Pulled", "Created", "Started")
| summarize count() by reason, container, message=substring(message, 0, 300)
| order by count_ desc`,
    },
  ],

  // ─────────────────────────────────────────────
  // LOGS — Raw telemetry logs
  // ─────────────────────────────────────────────
  logs: [
    {
      name: "Recent Traces (Daemonset)",
      datasource: "ContainerInsightsAppInsights",
      kql: `traces
| where timestamp >= _startTime and timestamp <= _endTime
| project timestamp, ID = tostring(customDimensions.ID), message, Computer = tostring(customDimensions.Computer), cloud_RoleInstance
| where cloud_RoleInstance !startswith "ama-logs-rs-" and cloud_RoleInstance !startswith "ama-logs-windows-"
| where ID =~ _cluster
| order by timestamp desc
| take 100`,
    },
    {
      name: "Recent Traces (Replicaset)",
      datasource: "ContainerInsightsAppInsights",
      kql: `traces
| where timestamp >= _startTime and timestamp <= _endTime
| project timestamp, ID = tostring(customDimensions.ID), message, Computer = tostring(customDimensions.Computer), cloud_RoleInstance
| where cloud_RoleInstance startswith "ama-logs-rs-"
| where ID =~ _cluster
| order by timestamp desc
| take 100`,
    },
    {
      name: "Recent Traces (Windows)",
      datasource: "ContainerInsightsAppInsights",
      kql: `traces
| where timestamp >= _startTime and timestamp <= _endTime
| project timestamp, ID = tostring(customDimensions.ID), message, Computer = tostring(customDimensions.Computer), cloud_RoleInstance
| where cloud_RoleInstance startswith "ama-logs-windows-"
| where ID =~ _cluster
| order by timestamp desc
| take 100`,
    },
  ],

  // ─────────────────────────────────────────────
  // CONFIG — Configuration validation
  // ─────────────────────────────────────────────
  config: [
    {
      name: "Agent ConfigMap Settings",
      datasource: "ContainerInsightsAppInsights",
      kql: `customEvents
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerLogDaemonSetHeartbeatEvent"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| project timestamp, 
  isHighLogScaleMode = tostring(customDimensions.isHighLogScaleMode),
  excludedNamespaces = tostring(customDimensions.excludedNamespaces),
  enrichContainerLogs = tostring(customDimensions.enrichContainerLogs),
  collectStdoutLogs = tostring(customDimensions.collectStdoutLogs),
  collectStderrLogs = tostring(customDimensions.collectStderrLogs)
| order by timestamp desc
| take 1`,
    },
    {
      name: "Addon Reconciler Events",
      datasource: "AKS",
      kql: `AddonConfigReconcilerEvents
| where TIMESTAMP >= _startTime
| where helmReleaseName == "azure-monitor-logs-adapter-helmrelease"
| where level in ("error", "warning")
| project TIMESTAMP, level, Underlay, msg=substring(msg, 0, 200)
| order by TIMESTAMP desc
| take 20`,
    },
    {
      name: "Data Collection Table",
      datasource: "ContainerInsightsAppInsights",
      kql: `customEvents
| where timestamp >= _startTime and timestamp <= _endTime
| where name == "ContainerLogDaemonSetHeartbeatEvent"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| project timestamp,
  containerLogTable = tostring(customDimensions.containerLogTable)
| order by timestamp desc
| take 1`,
    },
  ],
};

/**
 * Replace KQL placeholder tokens with actual values.
 */
export function parameterizeQuery(
  kql: string,
  params: {
    cluster: string;
    timeRange?: string;
    interval?: string;
    startTime?: string;
    endTime?: string;
  },
): string {
  const timeRange = params.timeRange || "24h";
  const interval = params.interval || "6h";
  let q = kql;

  // Time parameters (absolute or relative)
  if (params.startTime && params.endTime) {
    const start = `datetime("${params.startTime}")`;
    const end = `datetime("${params.endTime}")`;
    q = q.replace(/_startTime/g, start);
    q = q.replace(/_endTime/g, end);
  } else {
    q = q.replace(/_startTime/g, `ago(${timeRange})`);
    q = q.replace(/_endTime/g, "now()");
  }

  // Interval parameter
  q = q.replace(/totimespan\(Interval\)/g, `totimespan("${interval}")`);

  // Cluster parameter (word-boundary protected)
  q = q.replace(/(?<![a-zA-Z0-9])_cluster(?![a-zA-Z0-9_])/g, `"${params.cluster}"`);

  // Subscription ID (extracted from ARM ID)
  const subMatch = params.cluster.match(/\/subscriptions\/([^/]+)\//i);
  if (subMatch) {
    q = q.replace(/'_subscriptionId'/g, `'${subMatch[1]}'`);
  }

  // Cluster name (extracted from ARM ID)
  const nameMatch = params.cluster.match(/\/managedClusters\/([^/]+)$/i);
  if (nameMatch) {
    q = q.replace(/'_clusterName'/g, `'${nameMatch[1]}'`);
  }

  // Resource group (extracted from ARM ID)
  const rgMatch = params.cluster.match(/\/resourceGroups\/([^/]+)\//i);
  if (rgMatch) {
    q = q.replace(/'_resourceGroup'/g, `'${rgMatch[1]}'`);
  }

  return q;
}
