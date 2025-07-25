package types

// Common configuration types used across all parsers

// OSType represents the operating system
type OSType string

const (
	OSLinux   OSType = "linux"
	OSWindows OSType = "windows"
)

// ConfigSchemaVersion represents the configuration schema version
type ConfigSchemaVersion string

const (
	SchemaV1 ConfigSchemaVersion = "v1"
)

// LogCollectionSettings represents log collection configuration
type LogCollectionSettings struct {
	Stdout                 *StdoutSettings                 `toml:"stdout,omitempty"`
	Stderr                 *StderrSettings                 `toml:"stderr,omitempty"`
	EnvVar                 *EnvVarSettings                 `toml:"env_var,omitempty"`
	EnrichContainerLogs    *EnrichContainerLogsSettings    `toml:"enrich_container_logs,omitempty"`
	CollectAllKubeEvents   *CollectAllKubeEventsSettings   `toml:"collect_all_kube_events,omitempty"`
	Schema                 *SchemaSettings                 `toml:"schema,omitempty"`
	EnableMultilineLogs    *EnableMultilineLogsSettings    `toml:"enable_multiline_logs,omitempty"`
	RouteContainerLogs     *RouteContainerLogsSettings     `toml:"route_container_logs,omitempty"`
	MetadataCollection     *MetadataCollectionSettings     `toml:"metadata_collection,omitempty"`
	FilterUsingAnnotations *FilterUsingAnnotationsSettings `toml:"filter_using_annotations,omitempty"`
	MultiTenancy           *MultiTenancySettings           `toml:"multi_tenancy,omitempty"`
}

// StdoutSettings represents stdout log collection settings
type StdoutSettings struct {
	Enabled              bool     `toml:"enabled"`
	ExcludeNamespaces    []string `toml:"exclude_namespaces,omitempty"`
	CollectSystemPodLogs []string `toml:"collect_system_pod_logs,omitempty"`
}

// StderrSettings represents stderr log collection settings
type StderrSettings struct {
	Enabled              bool     `toml:"enabled"`
	ExcludeNamespaces    []string `toml:"exclude_namespaces,omitempty"`
	CollectSystemPodLogs []string `toml:"collect_system_pod_logs,omitempty"`
}

// EnvVarSettings represents environment variable collection settings
type EnvVarSettings struct {
	Enabled bool `toml:"enabled"`
}

// EnrichContainerLogsSettings represents container log enrichment settings
type EnrichContainerLogsSettings struct {
	Enabled bool `toml:"enabled"`
}

// CollectAllKubeEventsSettings represents Kubernetes events collection settings
type CollectAllKubeEventsSettings struct {
	Enabled bool `toml:"enabled"`
}

// SchemaSettings represents schema version settings
type SchemaSettings struct {
	ContainerLogSchemaVersion string `toml:"containerlog_schema_version,omitempty"`
}

// EnableMultilineLogsSettings represents multiline log settings
type EnableMultilineLogsSettings struct {
	Enabled             bool     `toml:"enabled"`
	StacktraceLanguages []string `toml:"stacktrace_languages,omitempty"`
}

// RouteContainerLogsSettings represents container log routing settings
type RouteContainerLogsSettings struct {
	Version string `toml:"version"`
}

// MetadataCollectionSettings represents Kubernetes metadata collection settings
type MetadataCollectionSettings struct {
	Enabled       bool     `toml:"enabled"`
	IncludeFields []string `toml:"include_fields,omitempty"`
}

// FilterUsingAnnotationsSettings represents annotation-based filtering settings
type FilterUsingAnnotationsSettings struct {
	Enabled bool `toml:"enabled"`
}

// MultiTenancySettings represents multi-tenancy configuration
type MultiTenancySettings struct {
	Enabled                         bool     `toml:"enabled"`
	DisableFallbackIngestion        bool     `toml:"disable_fallback_ingestion,omitempty"`
	AdvancedModeEnabled             bool     `toml:"advanced_mode_enabled,omitempty"`
	Namespaces                      []string `toml:"namespaces,omitempty"`
	StorageMaxChunksUp              int      `toml:"storage_max_chunks_up,omitempty"`
	StorageType                     string   `toml:"storage_type,omitempty"`
	MemBufLimit                     string   `toml:"mem_buf_limit,omitempty"`
	BufferChunkSize                 string   `toml:"buffer_chunk_size,omitempty"`
	BufferMaxSize                   string   `toml:"buffer_max_size,omitempty"`
	ThrottleRate                    string   `toml:"throttle_rate,omitempty"`
	ThrottleWindow                  string   `toml:"throttle_window,omitempty"`
	OutForwardWorkerCount           string   `toml:"out_forward_worker_count,omitempty"`
	OutForwardRetryLimit            string   `toml:"out_forward_retry_limit,omitempty"`
	OutForwardStorageTotalLimitSize string   `toml:"out_forward_storage_total_limit_size,omitempty"`
	OutForwardRequireAckResponse    string   `toml:"out_forward_require_ack_response,omitempty"`
	DisableThrottle                 string   `toml:"disable_throttle,omitempty"`
	NamespaceSettings               []string `toml:"namespace_settings,omitempty"`
	ServiceBufferChunkSize          string   `toml:"service_buffer_chunk_size,omitempty"`
	ServiceBufferMaxSize            string   `toml:"service_buffer_max_size,omitempty"`
}

// ConfigMapSettings represents the main configuration structure
type ConfigMapSettings struct {
	LogCollectionSettings *LogCollectionSettings `toml:"log_collection_settings,omitempty"`
}

// Environment represents environment variables to be set
type Environment struct {
	Variables map[string]string
}

// AddVariable adds an environment variable
func (e *Environment) AddVariable(key, value string) {
	if e.Variables == nil {
		e.Variables = make(map[string]string)
	}
	e.Variables[key] = value
}
