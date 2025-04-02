package lib

const (
	ExtensionOutputStreamIDTagPrefix  = "dcr-"
	ContainerInventoryDataType        = "CONTAINER_INVENTORY_BLOB"
	PerfDataType                      = "LINUX_PERF_BLOB"
	InsightsMetricsDataType           = "INSIGHTS_METRICS_BLOB"
	DiskDataType                      = "DISK_BLOB"
	AgentConfigRefreshIntervalSeconds = 300

	// interval to refresh in-memory service account token from file
	// service account token expiry is 1 hour and we refresh before 10 minutes expiry
	SERVICE_ACCOUNT_TOKEN_REFRESH_INTERVAL_SECONDS = 600

	// Legacy service account token is not in JWT and hence we cant infer expiry from token
	LEGACY_SERVICE_ACCOUNT_TOKEN_EXPIRY_SECONDS = 3600
)
