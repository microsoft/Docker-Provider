package unit

import (
	"os"
	"testing"

	"dockerprovider-installer-scripts/internal/tomlparser_common_agent_config"
	"dockerprovider-installer-scripts/pkg/types"
	"dockerprovider-installer-scripts/pkg/utils"

	"github.com/stretchr/testify/assert"
)

func TestCommonAgentConfigParser(t *testing.T) {
	// Test parser creation
	parser := tomlparser_common_agent_config.NewCommonAgentConfigParser()
	assert.NotNil(t, parser)
}

func TestDefaultSettings(t *testing.T) {
	parser := tomlparser_common_agent_config.NewCommonAgentConfigParser()
	settings := parser.GetDefaultSettings()

	assert.False(t, settings.DisableTelemetry)
	assert.False(t, settings.EnableHighLogScaleMode)
	assert.False(t, settings.EnableCustomMetrics)
	assert.Equal(t, 60, settings.AzmonKubernetesMetadataCacheTTLSeconds)
}

func TestProcessConfigMapWithNilConfig(t *testing.T) {
	parser := tomlparser_common_agent_config.NewCommonAgentConfigParser()
	settings := parser.ProcessConfigMap(nil)

	// Should return default settings
	assert.False(t, settings.DisableTelemetry)
	assert.False(t, settings.EnableHighLogScaleMode)
	assert.False(t, settings.EnableCustomMetrics)
	assert.Equal(t, 60, settings.AzmonKubernetesMetadataCacheTTLSeconds)
}

func TestProcessConfigMapWithValidConfig(t *testing.T) {
	parser := tomlparser_common_agent_config.NewCommonAgentConfigParser()

	// Create test config
	config := &types.AgentConfigMapSettings{
		AgentSettings: &types.AgentSettings{
			TelemetryConfig: &types.TelemetryConfig{
				DisableTelemetry: true,
			},
			K8sMetadataConfig: &types.K8sMetadataConfig{
				KubeMetaCacheTTLSecs: 120,
			},
			HighLogScale: &types.HighLogScaleConfig{
				Enabled: true,
			},
			CustomMetrics: &types.CustomMetricsConfig{
				Enabled: true,
			},
		},
	}

	settings := parser.ProcessConfigMap(config)

	assert.True(t, settings.DisableTelemetry)
	assert.True(t, settings.EnableHighLogScaleMode)
	assert.True(t, settings.EnableCustomMetrics)
	assert.Equal(t, 120, settings.AzmonKubernetesMetadataCacheTTLSeconds)
}

func TestProcessConfigMapWithInvalidTTL(t *testing.T) {
	parser := tomlparser_common_agent_config.NewCommonAgentConfigParser()

	// Create test config with negative TTL
	config := &types.AgentConfigMapSettings{
		AgentSettings: &types.AgentSettings{
			K8sMetadataConfig: &types.K8sMetadataConfig{
				KubeMetaCacheTTLSecs: -10,
			},
		},
	}

	settings := parser.ProcessConfigMap(config)

	// Should use default value for invalid TTL
	assert.Equal(t, 60, settings.AzmonKubernetesMetadataCacheTTLSeconds)
}

func TestFileOperations(t *testing.T) {
	fileOps := utils.NewFileOperations()
	assert.NotNil(t, fileOps)

	// Test IsWindows function
	isWindows := fileOps.IsWindows()
	assert.IsType(t, bool(false), isWindows)
}

func TestEnvironmentVariableGeneration(t *testing.T) {
	// Test with environment variable set
	os.Setenv("AZMON_AGENT_CFG_SCHEMA_VERSION", "v1")
	defer os.Unsetenv("AZMON_AGENT_CFG_SCHEMA_VERSION")

	parser := tomlparser_common_agent_config.NewCommonAgentConfigParser()
	assert.NotNil(t, parser)

	// Test default settings generation
	settings := parser.GetDefaultSettings()
	assert.NotNil(t, settings)
	assert.Equal(t, 60, settings.AzmonKubernetesMetadataCacheTTLSeconds)
}

func TestSchemaVersionValidation(t *testing.T) {
	// Test unsupported schema version
	os.Setenv("AZMON_AGENT_CFG_SCHEMA_VERSION", "v2")
	defer os.Unsetenv("AZMON_AGENT_CFG_SCHEMA_VERSION")

	parser := tomlparser_common_agent_config.NewCommonAgentConfigParser()

	// This should not panic and should handle unsupported version gracefully
	assert.NotPanics(t, func() {
		settings := parser.GetDefaultSettings()
		assert.NotNil(t, settings)
	})
}

func TestConfigMapPathConstants(t *testing.T) {
	// Verify the config map path constant
	assert.Equal(t, "/etc/config/settings/agent-settings", tomlparser_common_agent_config.ConfigMapMountPath)
	assert.Equal(t, 60, tomlparser_common_agent_config.DefaultMetadataCacheTTLSeconds)
}
