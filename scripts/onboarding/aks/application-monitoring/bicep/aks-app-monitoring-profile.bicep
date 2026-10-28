@description('Name of the existing AKS cluster. Deploy this template to the cluster resource group.')
@minLength(1)
param clusterName string

@description('Azure region of the AKS cluster.')
param clusterLocation string

@description('Include the autoinstrumentation profile in this update.')
param configureAutoInstrumentation bool = true

param autoInstrumentationEnabled bool = true

@description('Include the vendor-neutral OpenTelemetry metrics receiver profile in this update.')
param configureOpenTelemetryMetrics bool = false

param openTelemetryMetricsEnabled bool = true

@description('Optional HTTP/Protobuf host port. Use 0 to omit the property and use the service default.')
@minValue(0)
@maxValue(65535)
param openTelemetryMetricsHttpPort int = 0

@description('Optional gRPC host port. Use 0 to omit the property and use the service default.')
@minValue(0)
@maxValue(65535)
param openTelemetryMetricsGrpcPort int = 0

@description('Include the vendor-neutral OpenTelemetry logs and traces receiver profile in this update.')
param configureOpenTelemetryLogsAndTraces bool = false

param openTelemetryLogsAndTracesEnabled bool = true

@description('Optional HTTP/Protobuf host port. Use 0 to omit the property and use the service default.')
@minValue(0)
@maxValue(65535)
param openTelemetryLogsAndTracesHttpPort int = 0

@description('Optional gRPC host port. Use 0 to omit the property and use the service default.')
@minValue(0)
@maxValue(65535)
param openTelemetryLogsAndTracesGrpcPort int = 0

var openTelemetryMetricsProfile = union(
  {
    enabled: openTelemetryMetricsEnabled
  },
  openTelemetryMetricsHttpPort > 0
    ? {
        httpPort: openTelemetryMetricsHttpPort
      }
    : {},
  openTelemetryMetricsGrpcPort > 0
    ? {
        grpcPort: openTelemetryMetricsGrpcPort
      }
    : {}
)

var openTelemetryLogsAndTracesProfile = union(
  {
    enabled: openTelemetryLogsAndTracesEnabled
  },
  openTelemetryLogsAndTracesHttpPort > 0
    ? {
        httpPort: openTelemetryLogsAndTracesHttpPort
      }
    : {},
  openTelemetryLogsAndTracesGrpcPort > 0
    ? {
        grpcPort: openTelemetryLogsAndTracesGrpcPort
      }
    : {}
)

var appMonitoringProfile = union(
  configureAutoInstrumentation
    ? {
        autoInstrumentation: {
          enabled: autoInstrumentationEnabled
        }
      }
    : {},
  configureOpenTelemetryMetrics
    ? {
        openTelemetryMetrics: openTelemetryMetricsProfile
      }
    : {},
  configureOpenTelemetryLogsAndTraces
    ? {
        openTelemetryLogsAndTraces: openTelemetryLogsAndTracesProfile
      }
    : {}
)

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
