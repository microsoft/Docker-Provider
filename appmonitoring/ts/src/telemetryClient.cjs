const applicationInsights = require("applicationinsights");

process.env.APPLICATION_INSIGHTS_ENABLE_DEBUG_LOGS = "true";

applicationInsights.setup("InstrumentationKey=ac00484a-3c6f-41de-b5e8-95dda51d5a60;IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/") // global AI component collecting telemetry from all webhooks
  .setInternalLogging(true, true)
  .setAutoCollectRequests(false)
  .setAutoCollectPerformance(false, false)
  .setAutoCollectExceptions(false)
  .setAutoCollectDependencies(false)
  .setAutoCollectConsole(false, false)
  .setAutoCollectPreAggregatedMetrics(false)
  .setSendLiveMetrics(false)
  .start();

module.exports = {
  telemetryClient: applicationInsights.defaultClient
}