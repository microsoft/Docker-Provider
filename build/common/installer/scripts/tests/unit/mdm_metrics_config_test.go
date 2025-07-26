package unit

import (
	"os"
	"testing"

	"dockerprovider-installer-scripts/internal/tomlparser_mdm_metrics_config"
	"dockerprovider-installer-scripts/pkg/types"
	"dockerprovider-installer-scripts/pkg/utils"

	"github.com/stretchr/testify/assert"
)

func TestMDMMetricsConfigParser(t *testing.T) {
	// Test parser creation
	parser := tomlparser_mdm_metrics_config.NewMDMMetricsConfigParser()
	assert.NotNil(t, parser)
}

func TestMDMDefaultSettings(t *testing.T) {
	parser := tomlparser_mdm_metrics_config.NewMDMMetricsConfigParser()
	settings := parser.GetDefaultSettings()

	assert.Equal(t, 95.0, settings.ContainerCPUThreshold)
	assert.Equal(t, 90.0, settings.ContainerMemoryRSSThreshold)
	assert.Equal(t, 95.0, settings.ContainerMemoryWorkingSetThreshold)
	assert.Equal(t, 80.0, settings.PVUsageThreshold)
	assert.Equal(t, 360, settings.JobCompletionTimeThreshold)
}

func TestMDMProcessConfigMapWithNilConfig(t *testing.T) {
	parser := tomlparser_mdm_metrics_config.NewMDMMetricsConfigParser()
	settings := parser.ProcessConfigMap(nil)

	// Should return default settings
	assert.Equal(t, 95.0, settings.ContainerCPUThreshold)
	assert.Equal(t, 90.0, settings.ContainerMemoryRSSThreshold)
	assert.Equal(t, 95.0, settings.ContainerMemoryWorkingSetThreshold)
	assert.Equal(t, 80.0, settings.PVUsageThreshold)
	assert.Equal(t, 360, settings.JobCompletionTimeThreshold)
}

func TestMDMProcessConfigMapWithValidConfig(t *testing.T) {
	parser := tomlparser_mdm_metrics_config.NewMDMMetricsConfigParser()

	// Create test config
	config := &types.MDMMetricsConfigMapSettings{
		AlertableMetricsConfigurationSettings: &types.AlertableMetricsConfigurationSettings{
			ContainerResourceUtilizationThresholds: &types.ContainerResourceUtilizationThresholds{
				ContainerCPUThresholdPercentage:              85.0,
				ContainerMemoryRSSThresholdPercentage:        75.0,
				ContainerMemoryWorkingSetThresholdPercentage: 88.0,
			},
			PVUtilizationThresholds: &types.PVUtilizationThresholds{
				PVUsageThresholdPercentage: 70.0,
			},
			JobCompletionThreshold: &types.JobCompletionThreshold{
				JobCompletionThresholdTimeMinutes: 240,
			},
		},
	}

	settings := parser.ProcessConfigMap(config)

	assert.Equal(t, 85.0, settings.ContainerCPUThreshold)
	assert.Equal(t, 75.0, settings.ContainerMemoryRSSThreshold)
	assert.Equal(t, 88.0, settings.ContainerMemoryWorkingSetThreshold)
	assert.Equal(t, 70.0, settings.PVUsageThreshold)
	assert.Equal(t, 240, settings.JobCompletionTimeThreshold)
}

func TestMDMProcessConfigMapWithInvalidFloats(t *testing.T) {
	parser := tomlparser_mdm_metrics_config.NewMDMMetricsConfigParser()

	// Create test config with zero/invalid values
	config := &types.MDMMetricsConfigMapSettings{
		AlertableMetricsConfigurationSettings: &types.AlertableMetricsConfigurationSettings{
			ContainerResourceUtilizationThresholds: &types.ContainerResourceUtilizationThresholds{
				ContainerCPUThresholdPercentage:              0.0,  // Invalid
				ContainerMemoryRSSThresholdPercentage:        85.0, // Valid
				ContainerMemoryWorkingSetThresholdPercentage: 0.0,  // Invalid
			},
			PVUtilizationThresholds: &types.PVUtilizationThresholds{
				PVUsageThresholdPercentage: 0.0, // Invalid
			},
			JobCompletionThreshold: &types.JobCompletionThreshold{
				JobCompletionThresholdTimeMinutes: 0, // Invalid
			},
		},
	}

	settings := parser.ProcessConfigMap(config)

	// Should use defaults for invalid values, valid for others
	assert.Equal(t, 95.0, settings.ContainerCPUThreshold)              // Default (was 0.0)
	assert.Equal(t, 85.0, settings.ContainerMemoryRSSThreshold)        // Valid value
	assert.Equal(t, 95.0, settings.ContainerMemoryWorkingSetThreshold) // Default (was 0.0)
	assert.Equal(t, 80.0, settings.PVUsageThreshold)                   // Default (was 0.0)
	assert.Equal(t, 360, settings.JobCompletionTimeThreshold)          // Default (was 0)
}

func TestMDMProcessConfigMapWithPartialConfig(t *testing.T) {
	parser := tomlparser_mdm_metrics_config.NewMDMMetricsConfigParser()

	// Create test config with only CPU threshold
	config := &types.MDMMetricsConfigMapSettings{
		AlertableMetricsConfigurationSettings: &types.AlertableMetricsConfigurationSettings{
			ContainerResourceUtilizationThresholds: &types.ContainerResourceUtilizationThresholds{
				ContainerCPUThresholdPercentage: 92.0,
				// Other fields are zero values
			},
			// PV and Job thresholds are nil
		},
	}

	settings := parser.ProcessConfigMap(config)

	assert.Equal(t, 92.0, settings.ContainerCPUThreshold)              // Set value
	assert.Equal(t, 90.0, settings.ContainerMemoryRSSThreshold)        // Default (zero value)
	assert.Equal(t, 95.0, settings.ContainerMemoryWorkingSetThreshold) // Default (zero value)
	assert.Equal(t, 80.0, settings.PVUsageThreshold)                   // Default (nil section)
	assert.Equal(t, 360, settings.JobCompletionTimeThreshold)          // Default (nil section)
}

func TestMDMFileOperations(t *testing.T) {
	fileOps := utils.NewFileOperations()
	assert.NotNil(t, fileOps)

	// Test IsWindows function
	isWindows := fileOps.IsWindows()
	assert.IsType(t, bool(false), isWindows)
}

func TestMDMEnvironmentVariableGeneration(t *testing.T) {
	// Test with environment variable set
	os.Setenv("AZMON_AGENT_CFG_SCHEMA_VERSION", "v1")
	defer os.Unsetenv("AZMON_AGENT_CFG_SCHEMA_VERSION")

	parser := tomlparser_mdm_metrics_config.NewMDMMetricsConfigParser()
	assert.NotNil(t, parser)

	// Test default settings generation
	settings := parser.GetDefaultSettings()
	assert.NotNil(t, settings)
	assert.Equal(t, 95.0, settings.ContainerCPUThreshold)
}

func TestMDMSchemaVersionValidation(t *testing.T) {
	// Test unsupported schema version
	os.Setenv("AZMON_AGENT_CFG_SCHEMA_VERSION", "v2")
	defer os.Unsetenv("AZMON_AGENT_CFG_SCHEMA_VERSION")

	parser := tomlparser_mdm_metrics_config.NewMDMMetricsConfigParser()

	// This should not panic and should handle unsupported version gracefully
	assert.NotPanics(t, func() {
		settings := parser.GetDefaultSettings()
		assert.NotNil(t, settings)
	})
}

func TestMDMConfigMapPathConstants(t *testing.T) {
	// Verify the config map path constant
	assert.Equal(t, "/etc/config/settings/alertable-metrics-configuration-settings", tomlparser_mdm_metrics_config.ConfigMapMountPath)
	assert.Equal(t, 95.0, tomlparser_mdm_metrics_config.DefaultCPUUtilizationThreshold)
	assert.Equal(t, 90.0, tomlparser_mdm_metrics_config.DefaultMemoryRSSThreshold)
	assert.Equal(t, 95.0, tomlparser_mdm_metrics_config.DefaultMemoryWorkingSetThreshold)
	assert.Equal(t, 80.0, tomlparser_mdm_metrics_config.DefaultPVUtilizationThreshold)
	assert.Equal(t, 360, tomlparser_mdm_metrics_config.DefaultJobCompletedTimeThresholdMinutes)
}
