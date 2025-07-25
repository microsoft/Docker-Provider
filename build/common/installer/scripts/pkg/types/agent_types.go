package types

// AgentSettings represents the agent-specific configuration structure
type AgentSettings struct {
	TelemetryConfig   *TelemetryConfig     `toml:"telemetry_config,omitempty"`
	K8sMetadataConfig *K8sMetadataConfig   `toml:"k8s_metadata_config,omitempty"`
	HighLogScale      *HighLogScaleConfig  `toml:"high_log_scale,omitempty"`
	CustomMetrics     *CustomMetricsConfig `toml:"custom_metrics,omitempty"`
}

// TelemetryConfig represents telemetry configuration
type TelemetryConfig struct {
	DisableTelemetry bool `toml:"disable_telemetry"`
}

// K8sMetadataConfig represents Kubernetes metadata configuration
type K8sMetadataConfig struct {
	KubeMetaCacheTTLSecs int `toml:"kube_meta_cache_ttl_secs"`
}

// HighLogScaleConfig represents high log scale mode configuration
type HighLogScaleConfig struct {
	Enabled bool `toml:"enabled"`
}

// CustomMetricsConfig represents custom metrics configuration
type CustomMetricsConfig struct {
	Enabled bool `toml:"enabled"`
}

// AgentConfigMapSettings represents the main agent configuration structure
type AgentConfigMapSettings struct {
	AgentSettings *AgentSettings `toml:"agent_settings,omitempty"`
}

// AgentEnvironment represents the environment variables for agent configuration
type AgentEnvironment struct {
	DisableTelemetry                       bool
	EnableHighLogScaleMode                 bool
	EnableCustomMetrics                    bool
	AzmonKubernetesMetadataCacheTTLSeconds int
}
