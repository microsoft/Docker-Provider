package unit

import (
	"os"
	"testing"

	"dockerprovider-installer-scripts/internal/tomlparser_prom_customconfig"
	"dockerprovider-installer-scripts/pkg/types"

	"github.com/stretchr/testify/assert"
)

func TestNewParser(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()
	assert.NotNil(t, parser)
}

func TestCheckSchemaVersion(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	tests := []struct {
		name     string
		envValue string
		expected bool
	}{
		{
			name:     "Valid v1 schema",
			envValue: "v1",
			expected: true,
		},
		{
			name:     "Valid V1 schema (uppercase)",
			envValue: "V1",
			expected: true,
		},
		{
			name:     "Invalid schema",
			envValue: "v2",
			expected: false,
		},
		{
			name:     "Empty schema",
			envValue: "",
			expected: false,
		},
		{
			name:     "Whitespace schema",
			envValue: "  v1  ",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os.Setenv("AZMON_AGENT_CFG_SCHEMA_VERSION", tt.envValue)
			result := parser.CheckSchemaVersion()
			assert.Equal(t, tt.expected, result)
		})
	}

	// Cleanup
	os.Unsetenv("AZMON_AGENT_CFG_SCHEMA_VERSION")
}

func TestIsWindows(t *testing.T) {
	tests := []struct {
		name     string
		osType   string
		expected bool
	}{
		{
			name:     "Windows OS",
			osType:   "windows",
			expected: true,
		},
		{
			name:     "Windows OS (uppercase)",
			osType:   "WINDOWS",
			expected: true,
		},
		{
			name:     "Linux OS",
			osType:   "linux",
			expected: false,
		},
		{
			name:     "Empty OS",
			osType:   "",
			expected: false,
		},
		{
			name:     "Whitespace Windows",
			osType:   "  windows  ",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os.Setenv("OS_TYPE", tt.osType)
			parser := tomlparser_prom_customconfig.NewParser()
			result := parser.IsWindows()
			assert.Equal(t, tt.expected, result)
		})
	}

	// Cleanup
	os.Unsetenv("OS_TYPE")
}

func TestCheckForType(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	tests := []struct {
		name     string
		variable interface{}
		varType  string
		expected bool
	}{
		{
			name:     "Nil string",
			variable: nil,
			varType:  "string",
			expected: true,
		},
		{
			name:     "Valid string",
			variable: "test",
			varType:  "string",
			expected: true,
		},
		{
			name:     "Invalid string (int)",
			variable: 123,
			varType:  "string",
			expected: false,
		},
		{
			name:     "Nil bool",
			variable: nil,
			varType:  "bool",
			expected: true,
		},
		{
			name:     "Valid bool",
			variable: true,
			varType:  "bool",
			expected: true,
		},
		{
			name:     "Invalid bool (string)",
			variable: "true",
			varType:  "bool",
			expected: false,
		},
		{
			name:     "Unknown type",
			variable: "test",
			varType:  "unknown",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.CheckForType(tt.variable, tt.varType)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestCheckForTypeArray(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	tests := []struct {
		name        string
		arrayValue  interface{}
		elementType string
		expected    bool
	}{
		{
			name:        "Nil array",
			arrayValue:  nil,
			elementType: "string",
			expected:    true,
		},
		{
			name:        "Empty string array",
			arrayValue:  []interface{}{},
			elementType: "string",
			expected:    true,
		},
		{
			name:        "Valid string array",
			arrayValue:  []interface{}{"test1", "test2"},
			elementType: "string",
			expected:    true,
		},
		{
			name:        "Invalid string array (mixed types)",
			arrayValue:  []interface{}{"test1", 123},
			elementType: "string",
			expected:    false,
		},
		{
			name:        "Not an array",
			arrayValue:  "not an array",
			elementType: "string",
			expected:    false,
		},
		{
			name:        "Unknown element type",
			arrayValue:  []interface{}{"test"},
			elementType: "unknown",
			expected:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.CheckForTypeArray(tt.arrayValue, tt.elementType)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestFormatStringArray(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	tests := []struct {
		name     string
		input    []string
		expected string
	}{
		{
			name:     "Empty array",
			input:    []string{},
			expected: "[]",
		},
		{
			name:     "Single element",
			input:    []string{"test"},
			expected: "[\"test\"]",
		},
		{
			name:     "Multiple elements",
			input:    []string{"test1", "test2", "test3"},
			expected: "[\"test1\",\"test2\",\"test3\"]",
		},
		{
			name:     "Elements with spaces",
			input:    []string{"test one", "test two"},
			expected: "[\"test one\",\"test two\"]",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.FormatStringArray(tt.input)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestCountSelectorPairs(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	tests := []struct {
		name         string
		selectors    string
		selectorType string
		expected     int
	}{
		{
			name:         "Empty selector",
			selectors:    "",
			selectorType: "label",
			expected:     0,
		},
		{
			name:         "Single label selector",
			selectors:    "app=myapp",
			selectorType: "label",
			expected:     1,
		},
		{
			name:         "Multiple label selectors",
			selectors:    "app=myapp,version=v1",
			selectorType: "label",
			expected:     2,
		},
		{
			name:         "Label selector with parentheses",
			selectors:    "app in (app1, app2, app3)",
			selectorType: "label",
			expected:     1,
		},
		{
			name:         "Mixed label selectors",
			selectors:    "app=myapp,version in (v1, v2)",
			selectorType: "label",
			expected:     2,
		},
		{
			name:         "Single field selector",
			selectors:    "status.phase=Running",
			selectorType: "field",
			expected:     1,
		},
		{
			name:         "Multiple field selectors",
			selectors:    "status.phase=Running,metadata.namespace=default",
			selectorType: "field",
			expected:     2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.CountSelectorPairs(tt.selectors, tt.selectorType)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestGetCommandWindows(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	tests := []struct {
		name     string
		envVar   string
		value    string
		expected string
	}{
		{
			name:     "Simple env var",
			envVar:   "TEST_VAR",
			value:    "test_value",
			expected: "TEST_VAR=test_value\n",
		},
		{
			name:     "Boolean env var",
			envVar:   "ENABLE_FEATURE",
			value:    "true",
			expected: "ENABLE_FEATURE=true\n",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.GetCommandWindows(tt.envVar, tt.value)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestReplaceDefaultMonitorPodSettings(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	// Set up environment for ReplicaSet controller
	os.Setenv("CONTROLLER_TYPE", "replicaset")
	parser = tomlparser_prom_customconfig.NewParser()

	template := `
monitor_kubernetes_pods = $AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS
pod_scrape_scope = $AZMON_TELEGRAF_CUSTOM_PROM_SCRAPE_SCOPE
kubernetes_label_selector = $AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_LABEL_SELECTOR
kubernetes_field_selector = $AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_FIELD_SELECTOR
$AZMON_TELEGRAF_CUSTOM_PROM_PLUGINS_WITH_NAMESPACE_FILTER
`

	result := parser.ReplaceDefaultMonitorPodSettings(template, true, "app=myapp", "status.phase=Running")

	assert.Contains(t, result, "monitor_kubernetes_pods = true")
	assert.Contains(t, result, "pod_scrape_scope = \"cluster\"")
	assert.Contains(t, result, "kubernetes_label_selector = \"app=myapp\"")
	assert.Contains(t, result, "kubernetes_field_selector = \"status.phase=Running\"")
	assert.NotContains(t, result, "$AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS")

	// Cleanup
	os.Unsetenv("CONTROLLER_TYPE")
}

func TestCreatePrometheusPluginsWithNamespaceSetting(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	// Set up environment for ReplicaSet controller
	os.Setenv("CONTROLLER_TYPE", "replicaset")
	os.Setenv("OS_TYPE", "linux")
	parser = tomlparser_prom_customconfig.NewParser()

	template := `
monitor_kubernetes_pods = $AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS
$AZMON_TELEGRAF_CUSTOM_PROM_PLUGINS_WITH_NAMESPACE_FILTER
`

	namespaces := []string{"default", "kube-system"}
	result := parser.CreatePrometheusPluginsWithNamespaceSetting(
		true, namespaces, template, "1m", "[\"cpu\"]", "[\"memory\"]", "app=myapp", "status.phase=Running")

	// Check that original placeholders are commented out
	assert.Contains(t, result, "# Commenting this out since new plugins will be created per namespace")

	// Check that namespace-specific plugins are created
	assert.Contains(t, result, "monitor_kubernetes_pods_namespace = \"default\"")
	assert.Contains(t, result, "monitor_kubernetes_pods_namespace = \"kube-system\"")
	assert.Contains(t, result, "pod_scrape_scope = \"cluster\"")
	assert.Contains(t, result, "timeout = \"15s\"") // Linux timeout key

	// Cleanup
	os.Unsetenv("CONTROLLER_TYPE")
	os.Unsetenv("OS_TYPE")
}

func TestCreatePrometheusPluginsWithNamespaceSettingWindows(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()

	// Set up environment for Windows
	os.Setenv("CONTROLLER_TYPE", "daemonset")
	os.Setenv("OS_TYPE", "windows")
	parser = tomlparser_prom_customconfig.NewParser()

	template := `
$AZMON_TELEGRAF_CUSTOM_PROM_PLUGINS_WITH_NAMESPACE_FILTER
`

	namespaces := []string{"default"}
	result := parser.CreatePrometheusPluginsWithNamespaceSetting(
		true, namespaces, template, "1m", "[]", "[]", "", "")

	// Check that Windows timeout key is used
	assert.Contains(t, result, "response_timeout = \"15s\"")  // Windows timeout key
	assert.Contains(t, result, "pod_scrape_scope = \"node\"") // DaemonSet scope

	// Cleanup
	os.Unsetenv("CONTROLLER_TYPE")
	os.Unsetenv("OS_TYPE")
}

func TestProcessConfiguration(t *testing.T) {
	tests := []struct {
		name           string
		controllerType string
		containerType  string
		config         *types.PrometheusDataCollectionSettings
		expectError    bool
	}{
		{
			name:           "No controller type",
			controllerType: "",
			config:         nil,
			expectError:    true,
		},
		{
			name:           "Nil config",
			controllerType: "replicaset",
			config:         nil,
			expectError:    false,
		},
		{
			name:           "Empty config",
			controllerType: "replicaset",
			config:         &types.PrometheusDataCollectionSettings{},
			expectError:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os.Setenv("CONTROLLER_TYPE", tt.controllerType)
			os.Setenv("CONTAINER_TYPE", tt.containerType)
			parser := tomlparser_prom_customconfig.NewParser()

			err := parser.ProcessConfiguration(tt.config)

			if tt.expectError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}

	// Cleanup
	os.Unsetenv("CONTROLLER_TYPE")
	os.Unsetenv("CONTAINER_TYPE")
}

func TestEnvironmentVariableHandling(t *testing.T) {
	tests := []struct {
		name                   string
		controllerType         string
		containerType          string
		sidecarScrapingEnabled string
		osType                 string
	}{
		{
			name:           "ReplicaSet Linux",
			controllerType: "replicaset",
			osType:         "linux",
		},
		{
			name:           "DaemonSet Windows",
			controllerType: "daemonset",
			osType:         "windows",
		},
		{
			name:                   "Prometheus Sidecar",
			controllerType:         "daemonset",
			containerType:          "prometheussidecar",
			sidecarScrapingEnabled: "true",
			osType:                 "linux",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os.Setenv("CONTROLLER_TYPE", tt.controllerType)
			os.Setenv("CONTAINER_TYPE", tt.containerType)
			os.Setenv("SIDECAR_SCRAPING_ENABLED", tt.sidecarScrapingEnabled)
			os.Setenv("OS_TYPE", tt.osType)

			parser := tomlparser_prom_customconfig.NewParser()

			// Verify environment variables are correctly read
			assert.Equal(t, tt.controllerType, parser.Config().ControllerType)
			assert.Equal(t, tt.containerType, parser.Config().ContainerType)
			assert.Equal(t, tt.sidecarScrapingEnabled, parser.Config().SidecarScrapingEnabled)
			assert.Equal(t, tt.osType, parser.Config().OSType)
		})
	}

	// Cleanup
	os.Unsetenv("CONTROLLER_TYPE")
	os.Unsetenv("CONTAINER_TYPE")
	os.Unsetenv("SIDECAR_SCRAPING_ENABLED")
	os.Unsetenv("OS_TYPE")
}

func TestDefaultValues(t *testing.T) {
	parser := tomlparser_prom_customconfig.NewParser()
	config := parser.Config()

	// Test default intervals
	assert.Equal(t, "1m", config.DefaultDsInterval)
	assert.Equal(t, "1m", config.DefaultRsInterval)
	assert.Equal(t, "1m", config.DefaultCustomPrometheusInterval)

	// Test default arrays are empty
	assert.Empty(t, config.DefaultDsPromUrls)
	assert.Empty(t, config.DefaultDsFieldPass)
	assert.Empty(t, config.DefaultDsFieldDrop)
	assert.Empty(t, config.DefaultRsPromUrls)
	assert.Empty(t, config.DefaultRsFieldPass)
	assert.Empty(t, config.DefaultRsFieldDrop)
	assert.Empty(t, config.DefaultRsK8sServices)

	// Test default booleans
	assert.False(t, config.DefaultCustomPrometheusMonitorPods)

	// Test default strings
	assert.Empty(t, config.DefaultCustomPrometheusLabelSelectors)
	assert.Empty(t, config.DefaultCustomPrometheusFieldSelectors)

	// Test template constants
	assert.Equal(t, 2, config.MetricVersion)
	assert.Equal(t, 2, config.MonitorKubernetesPodsVersion)
	assert.Equal(t, "scrapeUrl", config.URLTag)
	assert.Equal(t, "/var/run/secrets/kubernetes.io/serviceaccount/token", config.BearerToken)
	assert.Equal(t, "15s", config.ResponseTimeout)
	assert.Equal(t, "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt", config.TLSCa)
	assert.True(t, config.InsecureSkipVerify)
	assert.Equal(t, "pod_namespace", config.PodNamespace)

	// Test controller constants
	assert.Equal(t, "replicaset", config.ReplicaSet)
	assert.Equal(t, "daemonset", config.DaemonSet)
	assert.Equal(t, "prometheussidecar", config.PromSideCar)
	assert.Equal(t, "windows", config.Windows)
}
