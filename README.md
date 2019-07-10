# Azure Monitor for Containers

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).  For more
information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact
[opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Release History

Note : The agent version(s) below has dates (ciprod<mmddyyyy>), which indicate the agent build dates (not release dates)
  
### 06/14/2019 - 
##### Version microsoft/oms:ciprod06142019 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06142019
- MDM pod metrics bug fixes - MDM rejecting pod metrics due to nodename or controllername dimensions being empty
- Prometheus metrics collection by default in every node for kubelet docker operations and kubelet docker operation errors
- Telegraf metric collection for diskio and networkio metrics
- Agent Configuration/ Settings for data collection
  * Cluster level log collection enable/disable option
  * Ability to enable/disable stdout and/or stderr logs collection per namespace
  * Cluster level environment variable collection enable/disable option
  * Config file version & config schema version
  * Pod annotation for supported config schema version(s)
- Log collection optimization/tuning for better performance
  * Derive k8s namespaces from log file name (instead of making call to k8s api service)
  * Do not tail log files for containers in the excluded namespace list (if excluded both in stdout & stderr)
  * Limit buffer size to 1M and flush logs more frequently [every 10 secs (instead of 30 secs)] 
  * Tuning of several other fluent bit settings
-	Increase requests 
  * Replica set memory request by 75M (100M to 175M)
  * Daemonset CPU request by 25m (50m to 75m)
- Will be pushing image only to MCR ( no more Docker) starting this release. AKS-engine will also start to pull our agent image from MCR

### 04/23/2019 - 
##### Version microsoft/oms:ciprod043232019 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod04232019
- Windows node monitoring (metrics & inventory)
- Telegraf integration (Telegraf metrics to LogAnalytics)
- Node Disk usage metrics (used, free, used%) as InsightsMetrics
- Resource stamping for all types (inventory, metrics (perf), metrics (InsightsMetrics), logs) [Applicable only for AKS clusters]
- Upped daemonset memory request (not limit) from 150Mi to 225 Mi
- Added liveness probe for fluentbit
- Fix for MDM filter plugin when kubeapi returns non-200 response

### 03/12/2019 - Version microsoft/oms:ciprod03122019
- Fix for closing response.Body in outoms
- Update Mem_Buf_Limit to 5m for fluentbit
- Tail only files that were modified since 5 minutes
- Remove some unwanted logs that are chatty in outoms
- Fix for MDM disablement for AKS-Engine
- Fix for Pod count metric (same as container count) in MDM
  
### 02/21/2019 - Version microsoft/oms:ciprod02212019
- Container logs enrichment optimization
  * Get container meta data only for containers in current node (vs cluster before)
- Update fluent bit 0.13.7 => 0.14.4
  * This fixes the escaping issue in the container logs
- Mooncake cloud support for agent (AKS only)
  * Ability to disable agent telemetry
  * Ability to onboard and ingest to mooncake cloud
- Add & populate 'ContainerStatusReason'  column to KubePodInventory
- Alertable (custom) metrics (to AzureMonitor - only for AKS clusters)
  * Cpuusagenanocores & % metric
  * MemoryWorkingsetBytes & % metric
  * MemoryRssBytes & % metric
  * Podcount by node, phase & namespace metric
  * Nodecount metric
- ContainerNodeInventory_CL to fixed type
  
### 01/09/2018 - Version microsoft/oms:ciprod01092019
- Omsagent - 1.8.1.256 (nov 2018 release)
- Persist fluentbit state between container restarts
- Populate 'TimeOfCommand' for agent ingest time for container logs
- Get node cpu usage from cpuusagenanoseconds (and convert to cpuusgaenanocores)
- Container Node Inventory - move to fluentD from OMI
- Mount docker.sock (Daemon set) as /var/run/host
- Add omsagent user to docker group
- Move to fixed type for kubeevents & kubeservices
- Disable collecting ENV for our oms agent container (daemonset & replicaset)
- Disable container inventory collection for 'sandbox' containers & non kubernetes managed containers
- Agent telemetry - ContainerLogsAgentSideLatencyMs
- Agent telemetry - PodCount
- Agent telemetry - ControllerCount
- Agent telemetry - K8S Version
- Agent telemetry - NodeCoreCapacity
- Agent telemetry - NodeMemoryCapacity
- Agent telemetry - KubeEvents (exceptions)
- Agent telemetry - Kubenodes (exceptions)
- Agent telemetry - kubepods (exceptions)
- Agent telemetry - kubeservices (exceptions)
- Agent telemetry - Daemonset , Replicaset as dimensions (bug fix)

### 11/29/2018 - Version microsoft/oms:ciprod11292018
- Disable Container Image inventory workflow
- Kube_Events memory leak fix for replica-set
- Timeout (30 secs) for outOMS
- Reduce critical lock duration for quicker log processing (for log enrichment)
- Disable OMI based Container Inventory workflow to fluentD based Container Inventory
- Moby support for the new Container Inventory workflow
- Ability to disable environment variables collection by individual container
- Bugfix - No inventory data due to container status(es) not available
- Agent telemetry cpu usage & memory usage (for DaemonSet and ReplicaSet)
- Agent telemetry - log generation rate
- Agent telemetry - container count per node
- Agent telemetry - collect container logs from agent (DaemonSet and ReplicaSet) as AI trace
- Agent telemetry - errors/exceptions for Container Inventory workflow
- Agent telemetry - Container Inventory Heartbeat

### 10/16/2018 - Version microsoft/oms:ciprod10162018-2
- Fix for containerID being 00000-00000-00000
- Move from fluentD to fluentbit for container log collection
- Seg fault fixes in json parsing for container inventory & container image inventory
- Telemetry enablement
- Remove ContainerPerf, ContainerServiceLog, ContainerProcess fluentd-->OMI workflows
- Update log level for all fluentD based workflows 

### 7/31/2018 - Version microsoft/oms:ciprod07312018
- Changes for node lost scenario (roll-up pod & container statuses as Unknown)
- Discover unscheduled pods
- KubeNodeInventory - delimit multiple true node conditions for node status
- UTF Encoding support for container logs
- Container environment variable truncated to 200K
- Handle json parsing errors for OMI provider for docker
- Test mode enablement for ACS-engine testing
- Latest OMS agent (1.6.0-163)
- Latest OMI (1.4.2.5)


### 6/7/2018 - Version microsoft/oms:ciprod06072018
- Remove node-0 dependency 
- Remove passing WSID & Key as environment variables and pass them as kubernetes secret (for non-AKS; we already pass them as secret for AKS)
- Please note that if you are manually deploying thru yaml you need to - 
- Provide workspaceid & key as base64 encoded strings with in double quotes (.yaml has comments to do so as well)
- Provide cluster name twice (for each container – daemonset & replicaset) 

### 5/8/2018 - Version microsoft/oms:ciprod05082018
- Kubernetes RBAC enablement
- Latest released omsagent (1.6.0-42)
- Bug fix so that we do not collect kube-system namespace container logs when kube api calls fail occasionally (Bug #215107)
- .yaml changes (for RBAC)
