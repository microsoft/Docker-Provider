package tomlparser_prom_customconfig

import (
	"fmt"
	"os"
	"strings"

	"dockerprovider-installer-scripts/pkg/logger"
	"dockerprovider-installer-scripts/pkg/types"
	"dockerprovider-installer-scripts/pkg/utils"

	"github.com/pelletier/go-toml"
)

// Parser handles Prometheus custom configuration parsing and template processing
type Parser struct {
	config            *types.PrometheusTemplateConfig
	telemetryConfig   *types.PrometheusTelemetryConfig
	logger            *logger.ConfigErrorLogger
	disableRSTelegraf bool
}

// NewParser creates a new Prometheus custom config parser
func NewParser() *Parser {
	templateConfig := &types.PrometheusTemplateConfig{
		// Environment variables
		ControllerType:         os.Getenv("CONTROLLER_TYPE"),
		ContainerType:          os.Getenv("CONTAINER_TYPE"),
		SidecarScrapingEnabled: os.Getenv("SIDECAR_SCRAPING_ENABLED"),
		OSType:                 os.Getenv("OS_TYPE"),

		// Default values - DaemonSet
		DefaultDsInterval:  "1m",
		DefaultDsPromUrls:  []string{},
		DefaultDsFieldPass: []string{},
		DefaultDsFieldDrop: []string{},

		// Default values - ReplicaSet
		DefaultRsInterval:    "1m",
		DefaultRsPromUrls:    []string{},
		DefaultRsFieldPass:   []string{},
		DefaultRsFieldDrop:   []string{},
		DefaultRsK8sServices: []string{},

		// Default values - Custom Prometheus
		DefaultCustomPrometheusInterval:       "1m",
		DefaultCustomPrometheusFieldPass:      []string{},
		DefaultCustomPrometheusFieldDrop:      []string{},
		DefaultCustomPrometheusMonitorPods:    false,
		DefaultCustomPrometheusLabelSelectors: "",
		DefaultCustomPrometheusFieldSelectors: "",

		// Template constants
		MetricVersion:                2,
		MonitorKubernetesPodsVersion: 2,
		URLTag:                       "scrapeUrl",
		BearerToken:                  "/var/run/secrets/kubernetes.io/serviceaccount/token",
		ResponseTimeout:              "15s",
		TLSCa:                        "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
		InsecureSkipVerify:           true,
		PodNamespace:                 "pod_namespace",

		// Controller type constants
		ReplicaSet:  "replicaset",
		DaemonSet:   "daemonset",
		PromSideCar: "prometheussidecar",
		Windows:     "windows",
	}

	return &Parser{
		config:          templateConfig,
		telemetryConfig: &types.PrometheusTelemetryConfig{},
		logger:          logger.NewConfigErrorLogger(),
	}
}

// ParseConfigMap parses the Prometheus TOML configuration file
func (p *Parser) ParseConfigMap() (*types.PrometheusDataCollectionSettings, error) {
	configMapMountPath := "/etc/config/settings/prometheus-data-collection-settings"

	if !utils.FileExists(configMapMountPath) {
		fmt.Println("config::configmap container-azm-ms-agentconfig for settings not mounted, using defaults for prometheus scraping")
		return nil, nil
	}

	fmt.Println("config::configmap container-azm-ms-agentconfig for settings mounted, parsing values for prometheus config map")

	tree, err := toml.LoadFile(configMapMountPath)
	if err != nil {
		p.logger.LogError(fmt.Sprintf("Exception while parsing config map for prometheus config: %v, using defaults, please check config map for errors", err))
		return nil, err
	}

	var config types.PrometheusDataCollectionSettings
	err = tree.Unmarshal(&config)
	if err != nil {
		p.logger.LogError(fmt.Sprintf("Exception while unmarshaling prometheus config: %v, using defaults", err))
		return nil, err
	}

	fmt.Println("config::Successfully parsed mounted prometheus config map")
	return &config, nil
}

// CheckForType validates if a variable is of the expected type
func (p *Parser) CheckForType(variable interface{}, varType string) bool {
	if variable == nil {
		return true
	}

	switch varType {
	case "string":
		_, ok := variable.(string)
		return ok
	case "bool":
		_, ok := variable.(bool)
		return ok
	default:
		return false
	}
}

// CheckForTypeArray validates if an array variable contains elements of the expected type
func (p *Parser) CheckForTypeArray(arrayValue interface{}, elementType string) bool {
	if arrayValue == nil {
		return true
	}

	arr, ok := arrayValue.([]interface{})
	if !ok {
		return false
	}

	if len(arr) == 0 {
		return true
	}

	switch elementType {
	case "string":
		for _, elem := range arr {
			if _, ok := elem.(string); !ok {
				return false
			}
		}
		return true
	default:
		return false
	}
}

// IsWindows checks if the current OS type is Windows
func (p *Parser) IsWindows() bool {
	return p.config.OSType != "" && strings.ToLower(strings.TrimSpace(p.config.OSType)) == "windows"
}

// ReplaceDefaultMonitorPodSettings replaces default monitoring pod settings in template
func (p *Parser) ReplaceDefaultMonitorPodSettings(content string, monitorKubernetesPods bool, kubernetesLabelSelectors, kubernetesFieldSelectors string) string {
	fmt.Println("config::Starting to substitute the placeholders in telegraf conf copy file with no namespace filters")

	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS", fmt.Sprintf("monitor_kubernetes_pods = %t", monitorKubernetesPods))

	scrapeScope := "node"
	if strings.ToLower(p.config.ControllerType) == p.config.ReplicaSet {
		scrapeScope = "cluster"
	}
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_SCRAPE_SCOPE", fmt.Sprintf("pod_scrape_scope = \"%s\"", scrapeScope))
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_PLUGINS_WITH_NAMESPACE_FILTER", "")
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_LABEL_SELECTOR", fmt.Sprintf("kubernetes_label_selector = \"%s\"", kubernetesLabelSelectors))
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_FIELD_SELECTOR", fmt.Sprintf("kubernetes_field_selector = \"%s\"", kubernetesFieldSelectors))

	return content
}

// CreatePrometheusPluginsWithNamespaceSetting creates namespace-specific prometheus plugins
func (p *Parser) CreatePrometheusPluginsWithNamespaceSetting(monitorKubernetesPods bool, monitorKubernetesPodsNamespaces []string, content, interval, fieldPassSetting, fieldDropSetting, kubernetesLabelSelectors, kubernetesFieldSelectors string) string {
	fmt.Println("config::Starting to substitute the placeholders in telegraf conf copy file with namespace filters")

	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS", "# Commenting this out since new plugins will be created per namespace\n  # $AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS")
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_LABEL_SELECTOR", "# Commenting this out since new plugins will be created per namespace\n  # $AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_LABEL_SELECTOR")
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_FIELD_SELECTOR", "# Commenting this out since new plugins will be created per namespace\n  # $AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_FIELD_SELECTOR")
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_SCRAPE_SCOPE", "# Commenting this out since new plugins will be created per namespace\n  # $AZMON_TELEGRAF_CUSTOM_PROM_SCRAPE_SCOPE")

	timeoutConfigKey := "timeout"
	if p.IsWindows() {
		// For windows, the timeout config key is different because of old version of telegraf
		timeoutConfigKey = "response_timeout"
	}

	scrapeScope := "node"
	if strings.ToLower(p.config.ControllerType) == p.config.ReplicaSet {
		scrapeScope = "cluster"
	}

	pluginConfigsWithNamespaces := ""
	for _, namespace := range monitorKubernetesPodsNamespaces {
		namespace = strings.TrimSpace(namespace)
		if len(namespace) > 0 {
			pluginConfigsWithNamespaces += fmt.Sprintf(`
[[inputs.prometheus]]
  interval = "%s"
  monitor_kubernetes_pods = true
  pod_namespace_label_name = "%s"
  pod_scrape_scope = "%s"
  monitor_kubernetes_pods_namespace = "%s"
  kubernetes_label_selector = "%s"
  kubernetes_field_selector = "%s"
  fieldpass = %s
  fielddrop = %s
  metric_version = %d
  url_tag = "%s"
  %s = "%s"
  tls_ca = "%s"
  insecure_skip_verify = %t
`,
				interval,
				p.config.PodNamespace,
				scrapeScope,
				namespace,
				kubernetesLabelSelectors,
				kubernetesFieldSelectors,
				fieldPassSetting,
				fieldDropSetting,
				p.config.MetricVersion,
				p.config.URLTag,
				timeoutConfigKey,
				p.config.ResponseTimeout,
				p.config.TLSCa,
				p.config.InsecureSkipVerify)
		}
	}

	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_PLUGINS_WITH_NAMESPACE_FILTER", pluginConfigsWithNamespaces)
	return content
}

// FormatStringArray formats a string array for Telegraf configuration
func (p *Parser) FormatStringArray(arr []string) string {
	if len(arr) == 0 {
		return "[]"
	}
	quoted := make([]string, len(arr))
	for i, s := range arr {
		quoted[i] = fmt.Sprintf("\"%s\"", s)
	}
	return "[" + strings.Join(quoted, ",") + "]"
}

// CountSelectorPairs counts the number of selector pairs in label/field selectors
func (p *Parser) CountSelectorPairs(selectors string, selectorType string) int {
	if selectors == "" {
		return 0
	}

	if selectorType == "label" {
		// Label selectors can be formatted as "app in (app1, app2, app3)"
		// We need to count commas not inside parentheses
		parenCount := 0
		selectorCount := 1
		for _, char := range selectors {
			if char == '(' {
				parenCount++
			} else if char == ')' {
				parenCount--
			} else if char == ',' && parenCount == 0 {
				selectorCount++
			}
		}
		return selectorCount
	} else {
		// Field selectors, split by commas to get the number of key-value pairs
		return len(strings.Split(selectors, ","))
	}
}

// GetCommandWindows formats environment variable for Windows
func (p *Parser) GetCommandWindows(envVariableName, envVariableValue string) string {
	return fmt.Sprintf("%s=%s\n", envVariableName, envVariableValue)
}

// WriteFile writes content to a file
func (p *Parser) WriteFile(filename, content string) error {
	return utils.WriteFile(filename, content)
}

// CopyFile copies a file from source to destination
func (p *Parser) CopyFile(src, dst string) error {
	return utils.CopyFile(src, dst)
}

// ReadFile reads content from a file
func (p *Parser) ReadFile(filename string) (string, error) {
	return utils.ReadFile(filename)
}

// Config returns the parser configuration for testing
func (p *Parser) Config() *types.PrometheusTemplateConfig {
	return p.config
}
