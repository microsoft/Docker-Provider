package types

// MDMMetricsConfigMapSettings represents the main MDM metrics configuration structure
type MDMMetricsConfigMapSettings struct {
	AlertableMetricsConfigurationSettings *AlertableMetricsConfigurationSettings `toml:"alertable_metrics_configuration_settings,omitempty"`
}

// AlertableMetricsConfigurationSettings represents the alertable metrics configuration
type AlertableMetricsConfigurationSettings struct {
	ContainerResourceUtilizationThresholds *ContainerResourceUtilizationThresholds `toml:"container_resource_utilization_thresholds,omitempty"`
	PVUtilizationThresholds                *PVUtilizationThresholds                `toml:"pv_utilization_thresholds,omitempty"`
	JobCompletionThreshold                 *JobCompletionThreshold                 `toml:"job_completion_threshold,omitempty"`
}

// ContainerResourceUtilizationThresholds represents CPU and memory thresholds
type ContainerResourceUtilizationThresholds struct {
	ContainerCPUThresholdPercentage              float64 `toml:"container_cpu_threshold_percentage"`
	ContainerMemoryRSSThresholdPercentage        float64 `toml:"container_memory_rss_threshold_percentage"`
	ContainerMemoryWorkingSetThresholdPercentage float64 `toml:"container_memory_working_set_threshold_percentage"`
}

// PVUtilizationThresholds represents persistent volume utilization thresholds
type PVUtilizationThresholds struct {
	PVUsageThresholdPercentage float64 `toml:"pv_usage_threshold_percentage"`
}

// JobCompletionThreshold represents job completion time threshold
type JobCompletionThreshold struct {
	JobCompletionThresholdTimeMinutes int `toml:"job_completion_threshold_time_minutes"`
}

// MDMMetricsEnvironment represents the environment variables for MDM metrics configuration
type MDMMetricsEnvironment struct {
	ContainerCPUThreshold              float64
	ContainerMemoryRSSThreshold        float64
	ContainerMemoryWorkingSetThreshold float64
	PVUsageThreshold                   float64
	JobCompletionTimeThreshold         int
}
