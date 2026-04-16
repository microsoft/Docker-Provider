export interface DataSource {
  name: string;
  clusterUri: string;
  database: string;
  description: string;
}

export const DATA_SOURCES: Record<string, DataSource> = {
  ContainerInsightsAppInsights: {
    name: "ContainerInsightsAppInsights",
    clusterUri:
      "https://ade.applicationinsights.io/subscriptions/13d371f9-5a39-46d5-8e1b-60158c49db84/resourceGroups/ContainerInsightsAgent-Prod/providers/microsoft.insights/components/ContainerInsightsAgent-Prod",
    database: "ContainerInsightsAgent-Prod",
    description: "Agent telemetry: customMetrics, customEvents, traces, exceptions (App Insights)",
  },
  AKS: {
    name: "AKS",
    clusterUri: "https://aks.centralus.kusto.windows.net",
    database: "AKSprod",
    description: "AKS cluster state, pod restarts, node status",
  },
  "AKS CCP": {
    name: "AKS CCP",
    clusterUri: "https://aksccp.centralus.kusto.windows.net",
    database: "AKSccpVMProd",
    description: "AKS control plane configuration and snapshots",
  },
};

export const APP_INSIGHTS = {
  appId: "ContainerInsightsAgent-Prod",
  resourceId:
    "/subscriptions/13d371f9-5a39-46d5-8e1b-60158c49db84/resourceGroups/ContainerInsightsAgent-Prod/providers/microsoft.insights/components/ContainerInsightsAgent-Prod",
  apiScope: "https://api.applicationinsights.io/.default",
};
