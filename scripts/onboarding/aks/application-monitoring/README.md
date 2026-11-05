# ARM templates for AKS application monitoring

These artifacts provide ARM equivalents for the Azure control-plane operations
documented in:

- [Set up codeless monitoring for AKS with Application Insights](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless)
- [Monitor AKS applications with OpenTelemetry Protocol (OTLP)](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol)

Kubernetes custom resources, workload annotations, and rollout restarts are not
native ARM resources. Azure control-plane templates are under [`arm`](arm) and
[`bicep`](bicep), and Kubernetes manifests are under
[`kubernetes`](kubernetes).

## Artifacts

### Azure templates

| ARM | Bicep | Purpose |
| --- | --- | --- |
| [register-preview-features.subscription.json](arm/register-preview-features.subscription.json) | [register-preview-features.subscription.bicep](bicep/register-preview-features.subscription.bicep) | Registers the AKS application-monitoring and Application Insights OTLP preview features. |
| [application-insights-codeless.json](arm/application-insights-codeless.json) | [application-insights-codeless.bicep](bicep/application-insights-codeless.bicep) | Creates a workspace-based Application Insights component for the codeless monitoring flow. |
| [application-insights-otlp.json](arm/application-insights-otlp.json) | [application-insights-otlp.bicep](bicep/application-insights-otlp.bicep) | Creates an OTLP-enabled Application Insights component with managed or customer-managed workspaces. |
| [associate-application-insights-dcr.json](arm/associate-application-insights-dcr.json) | [associate-application-insights-dcr.bicep](bicep/associate-application-insights-dcr.bicep) | Associates the OTLP-enabled Application Insights DCR with the AKS cluster. |
| [aks-otlp-monitoring-prerequisites.json](arm/aks-otlp-monitoring-prerequisites.json) | [aks-otlp-monitoring-prerequisites.bicep](bicep/aks-otlp-monitoring-prerequisites.bicep) | For a cluster not already monitored, creates or reuses the infrastructure workspaces, creates dedicated Azure Managed Grafana, and invokes pinned Microsoft templates to enable Managed Prometheus and Container Insights. |
| [aks-app-monitoring-profile.json](arm/aks-app-monitoring-profile.json) | [aks-app-monitoring-profile.bicep](bicep/aks-app-monitoring-profile.bicep) | Configures AKS autoinstrumentation and the OpenTelemetry metrics and logs/traces receivers. |

The Bicep prerequisite template uses
[`linked-template-deployment.bicep`](bicep/linked-template-deployment.bicep)
internally to invoke the pinned upstream ARM templates at the correct resource
group scope. Keep both files in the same folder; don't deploy the helper
directly.

### Kubernetes manifests

| Manifest | Purpose |
| --- | --- |
| [instrumentation-codeless.yaml](kubernetes/instrumentation-codeless.yaml) | Onboards a namespace for Java autoinstrumentation. Replace `Java` with `NodeJs`, or list both only when every default-onboarded workload should receive both agents. |
| [instrumentation-otlp.yaml](kubernetes/instrumentation-otlp.yaml) | Onboards a namespace for applications already instrumented with OpenTelemetry SDKs. |
| [instrumentation-per-deployment.yaml](kubernetes/instrumentation-per-deployment.yaml) | Defines a named `Instrumentation` resource for selective per-deployment onboarding. |
| [workload-autoinstrumentation.example.yaml](kubernetes/workload-autoinstrumentation.example.yaml) | Shows per-deployment Java and Node.js autoinstrumentation annotations. |
| [workload-autoconfiguration.example.yaml](kubernetes/workload-autoconfiguration.example.yaml) | Shows per-deployment OTLP SDK autoconfiguration and a gRPC protocol override. |

## Documentation placement

### Codeless monitoring article

| Documentation section | Artifact or note to add |
| --- | --- |
| [Prerequisites](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#prerequisites) | Link the [ARM](arm/application-insights-codeless.json) and [Bicep](bicep/application-insights-codeless.bicep) options for creating the required workspace-based Application Insights component. |
| [Prepare a cluster](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#prepare-a-cluster) | Add ARM and Bicep tabs using [aks-app-monitoring-profile.json](arm/aks-app-monitoring-profile.json) and [aks-app-monitoring-profile.bicep](bicep/aks-app-monitoring-profile.bicep) with only autoinstrumentation configured. |
| [Namespace-wide onboarding](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#namespace-wide-onboarding) | Link [instrumentation-codeless.yaml](kubernetes/instrumentation-codeless.yaml). This remains YAML rather than ARM. |
| [Per-deployment onboarding](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#per-deployment-onboarding) | Link [instrumentation-per-deployment.yaml](kubernetes/instrumentation-per-deployment.yaml) and the deployments in [workload-autoinstrumentation.example.yaml](kubernetes/workload-autoinstrumentation.example.yaml). |
| [Restart deployment](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#restart-deployment) | State that rollout restart is a Kubernetes action with no native ARM equivalent. |
| [Remove autoinstrumentation for AKS](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#remove-autoinstrumentation-for-aks) | Delete the applicable `Instrumentation` resources and restart affected deployments while the webhook is still enabled. Only then reuse the [ARM](arm/aks-app-monitoring-profile.json) or [Bicep](bicep/aks-app-monitoring-profile.bicep) profile template with `autoInstrumentationEnabled=false`. |
| [Annotations](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#annotations) | Link [workload-autoinstrumentation.example.yaml](kubernetes/workload-autoinstrumentation.example.yaml) for language injection and application-log annotations. |
| [Prepare a cluster during AKS cluster create](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-codeless#prepare-a-cluster-during-aks-cluster-create) | Add the literal `azureMonitorProfile.appMonitoring` object shown below to the full AKS creation template. |

### OTLP article

| Documentation section | Artifact or note to add |
| --- | --- |
| [Register the preview features](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#1-register-the-preview-features) | Add ARM and Bicep tabs using [register-preview-features.subscription.json](arm/register-preview-features.subscription.json) and [register-preview-features.subscription.bicep](bicep/register-preview-features.subscription.bicep). Registration must complete before dependent templates are deployed. |
| [Prepare the cluster](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#2-prepare-the-cluster) | If the cluster is not already monitored, deploy the [ARM](arm/aks-otlp-monitoring-prerequisites.json) or [Bicep](bicep/aks-otlp-monitoring-prerequisites.bicep) prerequisites. The Bicep download must include [linked-template-deployment.bicep](bicep/linked-template-deployment.bicep) in the same folder. Then deploy the corresponding application-monitoring profile template with all three profiles configured. |
| [Create an Application Insights resource with OTLP support](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#3-create-an-application-insights-resource-with-otlp-support) | Add ARM and Bicep tabs using [application-insights-otlp.json](arm/application-insights-otlp.json) and [application-insights-otlp.bicep](bicep/application-insights-otlp.bicep). |
| [Onboard applications to Application Insights](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#4-onboard-applications-to-application-insights) | First deploy the [ARM](arm/associate-application-insights-dcr.json) or [Bicep](bicep/associate-application-insights-dcr.bicep) DCR association. Then link the three `Instrumentation` manifests plus [workload-autoinstrumentation.example.yaml](kubernetes/workload-autoinstrumentation.example.yaml) and [workload-autoconfiguration.example.yaml](kubernetes/workload-autoconfiguration.example.yaml). |
| [Restart deployments to apply changes](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#43-restart-deployments-to-apply-changes) | State that rollout restart is a Kubernetes action with no native ARM equivalent. |
| [Advanced onboarding](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-open-protocol#advanced-onboarding-custom-resources) | Use the YAML artifacts as downloadable examples. |

## Choose ARM or Bicep

Each public Bicep template has the same parameter and output names as its ARM
counterpart. Use one format consistently for a deployment step. In the commands
below, replace `arm/<name>.json` with `bicep/<name>.bicep` to use Bicep.

## Deployment order

1. For the OTLP preview only, deploy
   the [ARM](arm/register-preview-features.subscription.json) or
   [Bicep](bicep/register-preview-features.subscription.bicep) feature
   registration template
   to each applicable subscription. The codeless flow doesn't require this
   step.
2. Wait until each feature reports `Registered`, then re-register
   `Microsoft.ContainerService` and `Microsoft.Insights` to propagate the
   feature registrations.
3. Deploy either
   the codeless [ARM](arm/application-insights-codeless.json) or
   [Bicep](bicep/application-insights-codeless.bicep) template, or the OTLP
   [ARM](arm/application-insights-otlp.json) or
   [Bicep](bicep/application-insights-otlp.bicep) template.
4. For the OTLP flow, check whether Managed Prometheus and Container Insights
   are enabled:

   ```azurecli
   az aks show \
     --resource-group <aks-resource-group> \
     --name <aks-name> \
     --query "{prometheus:azureMonitorProfile.metrics.enabled, containerInsights:addonProfiles.omsagent.enabled}"
   ```

   Deploy
   the [ARM](arm/aks-otlp-monitoring-prerequisites.json) or
   [Bicep](bicep/aks-otlp-monitoring-prerequisites.bicep) prerequisite template
   only when **both** values are disabled. If one is already enabled, onboard
   only the missing feature with its dedicated Azure Monitor template or CLI
   command so existing workspaces, associations, and collection settings
   aren't replaced. `monitoringWorkspaceLocation` can differ from the AKS
   region when the selected Azure Monitor and Log Analytics regions are
   supported.
5. Deploy the application-monitoring profile
   [ARM](arm/aks-app-monitoring-profile.json) or
   [Bicep](bicep/aks-app-monitoring-profile.bicep) template
   to the AKS resource group.
6. For the OTLP flow, deploy
   the DCR association [ARM](arm/associate-application-insights-dcr.json) or
   [Bicep](bicep/associate-application-insights-dcr.bicep) template
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
# ARM
az deployment sub create \
  --location <deployment-location> \
  --template-file arm/register-preview-features.subscription.json

# Bicep
az deployment sub create \
  --location <deployment-location> \
  --template-file bicep/register-preview-features.subscription.bicep
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

The equivalent Bicep resource fragment is:

```bicep
properties: {
  azureMonitorProfile: {
    appMonitoring: {
      autoInstrumentation: {
        enabled: true
      }
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
  the competing operation finishes, then redeploy with the same parameters.
  `az aks show` can report `provisioningState=Succeeded` while a
  `Microsoft.KubernetesConfiguration/extensions` write is still creating or
  updating an extension. Inspect extension states and the activity log when the
  error identifies an in-progress extension operation. Resource and association
  names are deterministic, so retry is idempotent.
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

## Cleanup order

Before deleting an OTLP-enabled Application Insights component, or any resource
group containing its DCR, remove every cluster association that points at that
DCR. Apply the same rule before deleting a resource group containing an
`MSProm-*` DCR. Otherwise deletion can fail with
`ExistingAssociationsPreventDelete`; the managed resource group can roll back
to `Succeeded` and require explicit cleanup rather than retrying automatically.

Find associations by DCR:

```azurecli
az monitor data-collection rule association list \
  --resource-group <dcr-resource-group> \
  --rule-name <dcr-name>
```

The Application Insights association template returns `associationName` for
use during cleanup.

```powershell
az monitor data-collection rule association delete `
  --resource <aks-resource-id> `
  --name <application-insights-association-name> `
  --yes

az group delete `
  --subscription <subscription> `
  --name <resource-group> `
  --yes
```

If an Application Insights or Azure Monitor managed resource group remains
after its associations are gone, delete that managed resource group explicitly.

## Application Insights OTLP workspace modes

The default deployment of
the [ARM](arm/application-insights-otlp.json) or
[Bicep](bicep/application-insights-otlp.bicep) OTLP Application Insights
template sets
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

## Manifest notes

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

The [ARM](arm/aks-otlp-monitoring-prerequisites.json) and
[Bicep](bicep/aks-otlp-monitoring-prerequisites.bicep) prerequisite templates
use pinned versions of Microsoft's published onboarding templates:

- Managed Prometheus:
  `Azure/prometheus-collector@71a784f49d633b9f182a50c878c6dd48c75fd58d`
- Container Insights:
  `microsoft/Docker-Provider@804bfb6d7eec35d04312fd5713559c65ab1fa548`

Pinning avoids silently changing an existing documentation sample when either
upstream repository advances.
