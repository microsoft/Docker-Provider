@description('Name of the existing AKS cluster. Deploy this template to the cluster resource group.')
@minLength(1)
param clusterName string

@description('Azure region of the AKS cluster.')
param clusterLocation string

@description('Enable or disable autoinstrumentation.')
param autoInstrumentationEnabled bool

@description('Enable or disable the vendor-neutral OpenTelemetry metrics receiver.')
param openTelemetryMetricsEnabled bool

@description('Optional HTTP/Protobuf host port. Use 0 to omit the property and use the service default. Ignored when the receiver is disabled.')
@minValue(0)
@maxValue(65535)
param openTelemetryMetricsHttpPort int = 0

@description('Optional gRPC host port. Use 0 to omit the property and use the service default. Ignored when the receiver is disabled.')
@minValue(0)
@maxValue(65535)
param openTelemetryMetricsGrpcPort int = 0

@description('Enable or disable the vendor-neutral OpenTelemetry logs and traces receiver.')
param openTelemetryLogsAndTracesEnabled bool

@description('Optional HTTP/Protobuf host port. Use 0 to omit the property and use the service default. Ignored when the receiver is disabled.')
@minValue(0)
@maxValue(65535)
param openTelemetryLogsAndTracesHttpPort int = 0

@description('Optional gRPC host port. Use 0 to omit the property and use the service default. Ignored when the receiver is disabled.')
@minValue(0)
@maxValue(65535)
param openTelemetryLogsAndTracesGrpcPort int = 0

var openTelemetryMetricsProfile = union(
  {
    enabled: openTelemetryMetricsEnabled
  },
  openTelemetryMetricsEnabled && openTelemetryMetricsHttpPort > 0
    ? {
        httpPort: openTelemetryMetricsHttpPort
      }
    : {},
  openTelemetryMetricsEnabled && openTelemetryMetricsGrpcPort > 0
    ? {
        grpcPort: openTelemetryMetricsGrpcPort
      }
    : {}
)

var openTelemetryLogsAndTracesProfile = union(
  {
    enabled: openTelemetryLogsAndTracesEnabled
  },
  openTelemetryLogsAndTracesEnabled && openTelemetryLogsAndTracesHttpPort > 0
    ? {
        httpPort: openTelemetryLogsAndTracesHttpPort
      }
    : {},
  openTelemetryLogsAndTracesEnabled && openTelemetryLogsAndTracesGrpcPort > 0
    ? {
        grpcPort: openTelemetryLogsAndTracesGrpcPort
      }
    : {}
)

var appMonitoringProfile = {
  autoInstrumentation: {
    enabled: autoInstrumentationEnabled
  }
  openTelemetryMetrics: openTelemetryMetricsProfile
  openTelemetryLogsAndTraces: openTelemetryLogsAndTracesProfile
}

#disable-next-line BCP081
resource cluster 'Microsoft.ContainerService/managedClusters@2026-06-01' = {
  name: clusterName
  location: clusterLocation
  properties: {
    azureMonitorProfile: {
      appMonitoring: appMonitoringProfile
    }
  }
}

output clusterResourceId string = cluster.id
output configuredAppMonitoringProfile object = appMonitoringProfile
