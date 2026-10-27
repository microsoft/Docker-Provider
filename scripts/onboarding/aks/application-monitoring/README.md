# ARM templates for AKS application monitoring

These artifacts provide ARM equivalents for the Azure control-plane operations
documented in:

- [Set up codeless monitoring for AKS with Application Insights](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless)
- [Monitor AKS applications with OpenTelemetry Protocol (OTLP)](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol)

Kubernetes custom resources, workload annotations, and rollout restarts are not
native ARM resources. Azure control-plane templates are under
[`arm`](arm), and Kubernetes manifests are under [`kubernetes`](kubernetes).

## Artifacts

| Artifact | Purpose |
| --- | --- |
| [register-preview-features.subscription.json](arm/register-preview-features.subscription.json) | Registers the AKS application-monitoring and Application Insights OTLP preview features. |
| [application-insights-codeless.json](arm/application-insights-codeless.json) | Creates a workspace-based Application Insights component for the codeless monitoring flow. |
| [application-insights-otlp.json](arm/application-insights-otlp.json) | Creates an OTLP-enabled Application Insights component with managed or customer-managed workspaces. |
| [associate-application-insights-dcr.json](arm/associate-application-insights-dcr.json) | Associates the OTLP-enabled Application Insights DCR with the AKS cluster. |
| [aks-otlp-monitoring-prerequisites.json](arm/aks-otlp-monitoring-prerequisites.json) | For a cluster not already monitored, creates or reuses the infrastructure workspaces, creates dedicated Azure Managed Grafana, and invokes pinned Microsoft templates to enable Managed Prometheus and Container Insights. |
| [aks-app-monitoring-profile.json](arm/aks-app-monitoring-profile.json) | Configures AKS autoinstrumentation and the OpenTelemetry metrics and logs/traces receivers. |
| [instrumentation-codeless.yaml](kubernetes/instrumentation-codeless.yaml) | Onboards a namespace for Java autoinstrumentation. Replace `Java` with `NodeJs`, or list both only when every default-onboarded workload should receive both agents. |
| [instrumentation-otlp.yaml](kubernetes/instrumentation-otlp.yaml) | Onboards a namespace for applications already instrumented with OpenTelemetry SDKs. |
| [instrumentation-per-deployment.yaml](kubernetes/instrumentation-per-deployment.yaml) | Defines a named `Instrumentation` resource for selective per-deployment onboarding. |
| [workload-autoinstrumentation.example.yaml](kubernetes/workload-autoinstrumentation.example.yaml) | Shows per-deployment Java and Node.js autoinstrumentation annotations. |
| [workload-autoconfiguration.example.yaml](kubernetes/workload-autoconfiguration.example.yaml) | Shows per-deployment OTLP SDK autoconfiguration and a gRPC protocol override. |

## Documentation placement

### Codeless monitoring article

| Documentation section | Artifact or note to add |
| --- | --- |
| [Prerequisites](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#prerequisites) | Link [application-insights-codeless.json](arm/application-insights-codeless.json) as the ARM option for creating the required workspace-based Application Insights component. |
| [Prepare a cluster](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#prepare-a-cluster) | Add an ARM tab using [aks-app-monitoring-profile.json](arm/aks-app-monitoring-profile.json) with only autoinstrumentation configured. |
| [Namespace-wide onboarding](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#namespace-wide-onboarding) | Link [instrumentation-codeless.yaml](kubernetes/instrumentation-codeless.yaml). This remains YAML rather than ARM. |
| [Per-deployment onboarding](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#per-deployment-onboarding) | Link [instrumentation-per-deployment.yaml](kubernetes/instrumentation-per-deployment.yaml) and the deployments in [workload-autoinstrumentation.example.yaml](kubernetes/workload-autoinstrumentation.example.yaml). |
| [Restart deployment](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#restart-deployment) | State that rollout restart is a Kubernetes action with no native ARM equivalent. |
| [Remove autoinstrumentation for AKS](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#remove-autoinstrumentation-for-aks) | Delete the applicable `Instrumentation` resources and restart affected deployments while the webhook is still enabled. Only then reuse [aks-app-monitoring-profile.json](arm/aks-app-monitoring-profile.json) with `autoInstrumentationEnabled=false`. |
| [Annotations](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#annotations) | Link [workload-autoinstrumentation.example.yaml](kubernetes/workload-autoinstrumentation.example.yaml) for language injection and application-log annotations. |
| [Prepare a cluster during AKS cluster create](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#prepare-a-cluster-during-aks-cluster-create) | Add the literal `azureMonitorProfile.appMonitoring` object shown below to the full AKS creation template. |

### OTLP article

| Documentation section | Artifact or note to add |
| --- | --- |
| [Register the preview features](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#1-register-the-preview-features) | Add an ARM tab using [register-preview-features.subscription.json](arm/register-preview-features.subscription.json). Registration must complete before dependent templates are deployed. |
| [Prepare the cluster](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#2-prepare-the-cluster) | If the cluster is not already monitored, deploy [aks-otlp-monitoring-prerequisites.json](arm/aks-otlp-monitoring-prerequisites.json). Then deploy [aks-app-monitoring-profile.json](arm/aks-app-monitoring-profile.json) with all three application-monitoring profiles configured. |
| [Create an Application Insights resource with OTLP support](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#3-create-an-application-insights-resource-with-otlp-support) | Add an ARM tab using [application-insights-otlp.json](arm/application-insights-otlp.json). |
| [Onboard applications to Application Insights](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#4-onboard-applications-to-application-insights) | First deploy [associate-application-insights-dcr.json](arm/associate-application-insights-dcr.json). Then link the three `Instrumentation` manifests plus [workload-autoinstrumentation.example.yaml](kubernetes/workload-autoinstrumentation.example.yaml) and [workload-autoconfiguration.example.yaml](kubernetes/workload-autoconfiguration.example.yaml). |
| [Restart deployments to apply changes](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#43-restart-deployments-to-apply-changes) | State that rollout restart is a Kubernetes action with no native ARM equivalent. |
| [Advanced onboarding](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#advanced-onboarding-custom-resources) | Use the YAML artifacts as downloadable examples. |

## Deployment order

1. For the OTLP preview only, deploy
   [register-preview-features.subscription.json](arm/register-preview-features.subscription.json)
   to each applicable subscription. The codeless flow doesn't require this
   step.
2. Wait until each feature reports `Registered`, then re-register
   `Microsoft.ContainerService` and `Microsoft.Insights` to propagate the
   feature registrations.
3. Deploy either
   [application-insights-codeless.json](arm/application-insights-codeless.json)
   or [application-insights-otlp.json](arm/application-insights-otlp.json).
4. For the OTLP flow, check whether Managed Prometheus and Container Insights
   are enabled:

   ```azurecli
   az aks show \
     --resource-group <aks-resource-group> \
     --name <aks-name> \
     --query "{prometheus:azureMonitorProfile.metrics.enabled, containerInsights:addonProfiles.omsagent.enabled}"
   ```

   Deploy
   [aks-otlp-monitoring-prerequisites.json](arm/aks-otlp-monitoring-prerequisites.json)
   only when **both** values are disabled. If one is already enabled, onboard
   only the missing feature with its dedicated Azure Monitor template or CLI
   command so existing workspaces, associations, and collection settings
   aren't replaced. `monitoringWorkspaceLocation` can differ from the AKS
   region when the selected Azure Monitor and Log Analytics regions are
   supported.
5. Deploy [aks-app-monitoring-profile.json](arm/aks-app-monitoring-profile.json)
   to the AKS resource group.
6. For the OTLP flow, deploy
   [associate-application-insights-dcr.json](arm/associate-application-insights-dcr.json)
   to the AKS resource group using `dataCollectionRuleResourceId` from the
   Application Insights deployment output.
7. Replace the placeholders in the appropriate `Instrumentation` manifest,
   apply it to the cluster, add any per-deployment annotations, and restart the
   affected deployments.

The two manifests named `default` are alternatives. Don't apply
[instrumentation-codeless.yaml](kubernetes/instrumentation-codeless.yaml) and
[instrumentation-otlp.yaml](kubernetes/instrumentation-otlp.yaml) to the same
namespace.

Deploy preview registration at subscription scope:

```azurecli
az deployment sub create \
  --location <deployment-location> \
  --template-file arm/register-preview-features.subscription.json
```

When AKS and Application Insights use different subscriptions, deploy once in
each subscription and set the unrelated registration parameter to `false`.

## Apply manifests without persisting connection strings

The Application Insights templates intentionally don't return the connection
string as a deployment output because ordinary ARM outputs are retained in
deployment history. Resolve it immediately before applying an
`Instrumentation` manifest, keep it in memory, and don't commit a rendered
manifest.

```powershell
$connectionString = az monitor app-insights component show `
  --resource-group <application-insights-resource-group> `
  --app <application-insights-name> `
  --query connectionString `
  --output tsv

$namespace = '<namespace>'
$manifest = Get-Content kubernetes\instrumentation-codeless.yaml -Raw
$manifest = $manifest.Replace('replace-with-namespace', $namespace)
$manifest = $manifest.Replace('replace-with-application-insights-connection-string', $connectionString)
$manifest | kubectl apply -f -

Remove-Variable connectionString, manifest, namespace
```

For the OTLP manifest, replace
`replace-with-otlp-enabled-application-insights-connection-string` instead.
For namespace-wide Node.js autoinstrumentation, replace `Java` with `NodeJs`
before applying the codeless manifest.

## AKS application-monitoring profile examples

For codeless monitoring, configure only autoinstrumentation:

```azurecli
az deployment group create \
  --resource-group <aks-resource-group> \
  --template-file arm/aks-app-monitoring-profile.json \
  --parameters clusterName=<aks-name> \
               clusterLocation=<aks-location>
```

For the full OTLP experience, configure all three profiles:

```azurecli
az deployment group create \
  --resource-group <aks-resource-group> \
  --template-file arm/aks-app-monitoring-profile.json \
  --parameters clusterName=<aks-name> \
               clusterLocation=<aks-location> \
               configureOpenTelemetryMetrics=true \
               configureOpenTelemetryLogsAndTraces=true
```

Before that profile update, enable the required infrastructure monitoring:

```azurecli
az deployment group create \
  --resource-group <monitoring-resource-group> \
  --template-file arm/aks-otlp-monitoring-prerequisites.json \
  --parameters clusterResourceId=<aks-resource-id> \
               clusterLocation=<aks-location> \
               monitoringWorkspaceLocation=<monitoring-workspace-location> \
               managedGrafanaName=<new-dedicated-grafana-name> \
               managedGrafanaLocation=<grafana-location> \
               grafanaAdminPrincipalId=<optional-object-id> \
               grafanaAdminPrincipalType=User
```

Use this prerequisite wrapper only for first-time monitoring onboarding. Running
it on an already monitored cluster can replace Container Insights settings or
add a second Prometheus DCR association. When monitoring is already enabled,
keep the existing infrastructure workspaces and associations.

When reusing workspaces, deploy the wrapper to the existing Azure Monitor
workspace's resource group. The Azure Monitor and Log Analytics workspaces must
both use `monitoringWorkspaceLocation`; this wrapper doesn't support existing
workspaces in different regions.

The prerequisite template creates dedicated Azure Managed Grafana because the
published Managed Prometheus ARM template replaces the complete workspace
integration list on Grafana. To reuse a shared Grafana instance, follow the
existing-workspace procedure in the Azure Monitor onboarding documentation and
preserve every existing `azureMonitorWorkspaceIntegrations` entry. Use
`managedGrafanaLocation` to select a region where Azure Managed Grafana is
available; it does not have to match `monitoringWorkspaceLocation`. The
dedicated Grafana resource incurs its own Azure charges.

The Grafana assignment parameters are optional. If
`grafanaAdminPrincipalId` is omitted, the data source is configured but no
principal receives Grafana data-plane access. Creating the assignment requires
`Microsoft.Authorization/roleAssignments/write` at the Grafana resource scope.
`grafanaAdminPrincipalType` accepts `User`, `Group`, `ForeignGroup`, or
`ServicePrincipal`; use `ServicePrincipal` for managed identities. Grafana
workspace names must be 2-23 characters.

The published Managed Prometheus template always grants the Grafana managed
identity Monitoring Data Reader on the Azure Monitor workspace. The deployment
identity therefore needs Contributor on the resource groups and
`Microsoft.Authorization/roleAssignments/write` on the Azure Monitor workspace
even when `grafanaAdminPrincipalId` is omitted.

The Java and Node.js workload examples enable Application Insights application
logs to demonstrate the documented annotation. Remove
`monitor.azure.com/enable-application-logs` when Container Insights already
collects the required logs and duplicate ingestion isn't wanted.

To remove the webhook while leaving the node-local OTLP receivers enabled:

1. Delete the applicable `Instrumentation` resources.
2. Restart every affected deployment while the webhook remains enabled, then
   verify the `monitor.azure.com/instrumentation` annotation is absent.
3. Disable the cluster autoinstrumentation profile:

```azurecli
az deployment group create \
  --resource-group <aks-resource-group> \
  --template-file arm/aks-app-monitoring-profile.json \
  --parameters clusterName=<aks-name> \
               clusterLocation=<aks-location> \
               autoInstrumentationEnabled=false
```

The metrics and logs/traces receiver profiles remain enabled, but disabling
autoinstrumentation removes the webhook that injects both language agents and
OTLP autoconfiguration environment variables. Only workloads that were already
mutated or that configure their own exporters to use the node-local receiver
ports continue sending.

To disable all three application-monitoring profiles, configure all three and
set each corresponding `Enabled` parameter to `false`.

For a new AKS cluster, add this literal codeless profile to the complete cluster
resource:

```json
"azureMonitorProfile": {
  "appMonitoring": {
    "autoInstrumentation": {
      "enabled": true
    }
  }
}
```

Don't add the OTLP receiver profiles by themselves to a new-cluster template.
OTLP metrics require Managed Prometheus, and OTLP logs and traces require
Container Insights plus their DCR associations. Create the cluster with the
codeless profile, deploy the prerequisite wrapper, and then enable all three
profiles with [aks-app-monitoring-profile.json](arm/aks-app-monitoring-profile.json).

Associate the Application Insights DCR before applying the OTLP
`Instrumentation` resource:

```powershell
$dcrId = az deployment group show `
  --resource-group <application-insights-resource-group> `
  --name <application-insights-deployment-name> `
  --query properties.outputs.dataCollectionRuleResourceId.value `
  --output tsv

az deployment group create `
  --resource-group <aks-resource-group> `
  --template-file arm/associate-application-insights-dcr.json `
  --parameters clusterName=<aks-name> `
               clusterLocation=<aks-location> `
               dataCollectionRuleResourceId=$dcrId

Remove-Variable dcrId
```

## Operational safeguards

- **Concurrent AKS updates:** The prerequisite wrapper performs nested AKS
  updates. If deployment fails with `OperationNotAllowed` because Policy,
  Defender, or another operation is updating the cluster, wait until
  `provisioningState` is `Succeeded`, then redeploy with the same parameters.
  Resource and association names are deterministic, so retry is idempotent.
  A `PrincipalNotFound` error while assigning the newly created Grafana
  identity can also be retried after Microsoft Entra replication completes.
- **AKS `what-if`:** `what-if` can report deletion of omitted AKS properties
  such as identity, node pools, add-ons, networking, or sibling monitoring
  profiles. Live validation with `Microsoft.ContainerService@2026-06-01`
  preserved those properties during focused profile updates. Verify the
  cluster after deployment rather than treating those predictions as actual
  deletions.
- **In-cluster reconciliation:** ARM success can precede the webhook and agent
  rollout. Before restarting applications, wait for the webhook deployment and
  monitoring agents to become ready:

  ```shell
  until kubectl -n kube-system get deployment app-monitoring-webhook >/dev/null 2>&1; do sleep 10; done
  kubectl -n kube-system rollout status deployment/app-monitoring-webhook --timeout=10m
  kubectl -n kube-system get daemonset ama-logs ama-metrics-node
  kubectl -n kube-system get deployment app-monitoring-webhook \
    -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}'
  ```

  For full OTLP onboarding, confirm the final output includes
  `OTEL_LOGS_ENABLED=true` and `OTEL_METRICS_ENABLED=true`.

- **Capacity:** Leave scheduling headroom for two webhook replicas, monitoring
  agents, and pod rollout surge. In the validated version, each injected
  autoinstrumentation init container requested 100m CPU and 128 MiB memory.
  Small governed clusters can otherwise stall with `Insufficient cpu`.
- **Disable semantics:** Disabling autoinstrumentation removes the webhook but
  leaves the `instrumentations.monitor.azure.com` CRD. CRs created while the
  webhook is disabled are inert. A deployment that wasn't restarted and
  cleaned before disable remains instrumented; a later restart can't remove
  the persisted mutation without restoring the webhook or redeploying the
  original workload manifest.

## Application Insights OTLP workspace modes

The default deployment of
[application-insights-otlp.json](arm/application-insights-otlp.json) sets
`AzureMonitorWorkspaceIngestionMode` to `Enabled` and omits workspace IDs. The
Application Insights service creates and manages the Log Analytics workspace,
Azure Monitor workspace, data collection rule, and OTLP endpoints.

To use existing workspaces, set `useManagedWorkspaces=false` and supply both
`logAnalyticsWorkspaceResourceId` and `azureMonitorWorkspaceResourceId`. The
Application Insights service still creates and links the OTLP data collection
resources.

The Azure Monitor workspace used for Application Insights application metrics
must be different from the infrastructure Azure Monitor workspace used by
Managed Prometheus.

## Intentional corrections to current documentation samples

- The codeless namespace-wide manifest selects `Java`. An empty
  `autoInstrumentationPlatforms` list injects no language agent, so replace it
  with `NodeJs` for a Node.js-only namespace or list both only when every
  default-onboarded workload needs both.
- Namespace-wide OTLP SDK autoconfiguration requires an `Instrumentation`
  resource named `default`. A resource named `cr1` applies only when a
  deployment references it with
  `instrumentation.opentelemetry.io/inject-configuration`.
- A named resource used with `inject-configuration` must contain the connection
  string of an OTLP-enabled Application Insights component. The same named
  resource can be used for Java or Node.js autoinstrumentation with the
  corresponding language annotation.

## Native ARM limitations

- ARM has no native resource type for an `Instrumentation` custom resource or
  arbitrary Kubernetes workload annotations.
- ARM cannot natively perform `kubectl rollout restart`.
- The portal's per-deployment `Instrumented` status is runtime Kubernetes
  state, not ARM deployment state.
- `AzureMonitorWorkspaceIngestionMode=Enabled` is one-way. The Application
  Insights API does not support opting back out after OTLP ingestion is
  enabled.
- Preview feature registration is asynchronous and can require approval. Do
  not deploy preview registration and dependent resources in one deployment.

For an ARM-managed entry point to Kubernetes configuration, use
`Microsoft.KubernetesConfiguration/fluxConfigurations` to reconcile these YAML
files from Git, OCI, or Azure Blob. A deployment script can invoke `kubectl`,
but that is imperative orchestration rather than a native ARM representation.

## Upstream templates

[aks-otlp-monitoring-prerequisites.json](arm/aks-otlp-monitoring-prerequisites.json)
uses pinned versions of Microsoft's published onboarding templates:

- Managed Prometheus:
  `Azure/prometheus-collector@71a784f49d633b9f182a50c878c6dd48c75fd58d`
- Container Insights:
  `microsoft/Docker-Provider@804bfb6d7eec35d04312fd5713559c65ab1fa548`

Pinning avoids silently changing an existing documentation sample when either
upstream repository advances.
