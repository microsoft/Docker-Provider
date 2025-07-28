package types

// PrometheusDataCollectionSettings represents the top-level structure for Prometheus configuration
type PrometheusDataCollectionSettings struct {
	PrometheusDataCollectionSettings *PrometheusConfig `toml:"prometheus_data_collection_settings"`
}

// PrometheusConfig contains cluster and node-specific Prometheus settings
type PrometheusConfig struct {
	Cluster *ClusterPrometheusConfig `toml:"cluster"`
	Node    *NodePrometheusConfig    `toml:"node"`
}

// ClusterPrometheusConfig contains configuration for cluster-level Prometheus scraping
type ClusterPrometheusConfig struct {
	Interval                        *string  `toml:"interval"`
	FieldPass                       []string `toml:"fieldpass"`
	FieldDrop                       []string `toml:"fielddrop"`
	URLs                            []string `toml:"urls"`
	KubernetesServices              []string `toml:"kubernetes_services"`
	MonitorKubernetesPods           *bool    `toml:"monitor_kubernetes_pods"`
	MonitorKubernetesPodsNamespaces []string `toml:"monitor_kubernetes_pods_namespaces"`
	KubernetesLabelSelector         *string  `toml:"kubernetes_label_selector"`
	KubernetesFieldSelector         *string  `toml:"kubernetes_field_selector"`
}

// NodePrometheusConfig contains configuration for node-level Prometheus scraping
type NodePrometheusConfig struct {
	Interval  *string  `toml:"interval"`
	FieldPass []string `toml:"fieldpass"`
	FieldDrop []string `toml:"fielddrop"`
	URLs      []string `toml:"urls"`
}

// PrometheusTemplateConfig contains the processed configuration for template substitution
type PrometheusTemplateConfig struct {
	ControllerType         string
	ContainerType          string
	SidecarScrapingEnabled string
	OSType                 string

	// Default values
	DefaultDsInterval                     string
	DefaultDsPromUrls                     []string
	DefaultDsFieldPass                    []string
	DefaultDsFieldDrop                    []string
	DefaultRsInterval                     string
	DefaultRsPromUrls                     []string
	DefaultRsFieldPass                    []string
	DefaultRsFieldDrop                    []string
	DefaultRsK8sServices                  []string
	DefaultCustomPrometheusInterval       string
	DefaultCustomPrometheusFieldPass      []string
	DefaultCustomPrometheusFieldDrop      []string
	DefaultCustomPrometheusMonitorPods    bool
	DefaultCustomPrometheusLabelSelectors string
	DefaultCustomPrometheusFieldSelectors string

	// Template constants
	MetricVersion                int
	MonitorKubernetesPodsVersion int
	URLTag                       string
	BearerToken                  string
	ResponseTimeout              string
	TLSCa                        string
	InsecureSkipVerify           bool
	PodNamespace                 string

	// Controller type constants
	ReplicaSet  string
	DaemonSet   string
	PromSideCar string
	Windows     string
}

// PrometheusTelemetryConfig contains telemetry metrics for Prometheus configuration
type PrometheusTelemetryConfig struct {
	RStelegrafDisabled        bool
	RSPromInterval            string
	RSPromFieldPassLength     int
	RSPromFieldDropLength     int
	RSPromK8sServicesLength   int
	RSPromURLsLength          int
	RSPromMonitorPods         bool
	RSPromMonitorPodsNSLength int
	RSPromLabelSelectorLength int
	RSPromFieldSelectorLength int

	CustomPromMonitorPods         bool
	CustomPromMonitorPodsNSLength int
	CustomPromLabelSelectorLength int
	CustomPromFieldSelectorLength int

	DSPromInterval        string
	DSPromFieldPassLength int
	DSPromFieldDropLength int
	DSPromURLsLength      int
}
