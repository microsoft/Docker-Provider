package tomlparser_mdm_metrics_config

import (
	"fmt"
	"os"
	"strings"

	"dockerprovider-installer-scripts/pkg/logger"
	"dockerprovider-installer-scripts/pkg/types"
	"dockerprovider-installer-scripts/pkg/utils"

	"github.com/pelletier/go-toml"
)

const (
	// Default MDM metric thresholds based on Ruby script behavior
	DefaultCPUUtilizationThreshold          = 95.0
	DefaultMemoryRSSThreshold               = 90.0
	DefaultMemoryWorkingSetThreshold        = 95.0
	DefaultPVUtilizationThreshold           = 80.0
	DefaultJobCompletedTimeThresholdMinutes = 360
	ConfigMapMountPath                      = "/etc/config/settings/alertable-metrics-configuration-settings"
)

// MDMMetricsConfigParser handles parsing of MDM metrics configuration
type MDMMetricsConfigParser struct {
	fileOps *utils.FileOperations
	logger  logger.Logger
}

// NewMDMMetricsConfigParser creates a new parser instance
func NewMDMMetricsConfigParser() *MDMMetricsConfigParser {
	return &MDMMetricsConfigParser{
		fileOps: utils.NewFileOperations(),
		logger:  logger.NewConfigErrorLogger(),
	}
}

// ParseAndProcess parses the MDM metrics config and generates environment files
func (p *MDMMetricsConfigParser) ParseAndProcess() error {
	fmt.Println("****************Start MDM Metrics Config Processing********************")

	// Check schema version
	schemaVersion := os.Getenv("AZMON_AGENT_CFG_SCHEMA_VERSION")
	if schemaVersion == "" || strings.ToLower(strings.TrimSpace(schemaVersion)) != "v1" {
		if p.fileOps.FileExists(ConfigMapMountPath) {
			logger.LogError(fmt.Sprintf("config::unsupported/missing config schema version - '%s', using defaults, please use supported schema version", schemaVersion))
		}
		return p.writeEnvironmentFiles(p.GetDefaultSettings())
	}

	// Parse config map
	config, err := p.parseConfigMap()
	if err != nil {
		logger.LogError(fmt.Sprintf("Failed to parse config map: %v", err))
		return p.writeEnvironmentFiles(p.GetDefaultSettings())
	}

	// Process settings
	settings := p.ProcessConfigMap(config)

	// Write environment files
	return p.writeEnvironmentFiles(settings)
}

// parseConfigMap reads and parses the TOML configuration file
func (p *MDMMetricsConfigParser) parseConfigMap() (*types.MDMMetricsConfigMapSettings, error) {
	if !p.fileOps.FileExists(ConfigMapMountPath) {
		fmt.Println("config::configmap container-azm-ms-agentconfig for MDM metrics settings not mounted, using defaults")
		return nil, nil
	}

	fmt.Println("config::configmap container-azm-ms-agentconfig for MDM metric settings mounted, parsing values")

	content, err := p.fileOps.ReadFile(ConfigMapMountPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config types.MDMMetricsConfigMapSettings
	err = toml.Unmarshal([]byte(content), &config)
	if err != nil {
		return nil, fmt.Errorf("failed to parse TOML: %w", err)
	}

	fmt.Println("config::Successfully parsed mounted config map")
	return &config, nil
}

// ProcessConfigMap extracts settings from parsed configuration
func (p *MDMMetricsConfigParser) ProcessConfigMap(config *types.MDMMetricsConfigMapSettings) *types.MDMMetricsEnvironment {
	settings := p.GetDefaultSettings()

	if config == nil || config.AlertableMetricsConfigurationSettings == nil {
		return settings
	}

	alertSettings := config.AlertableMetricsConfigurationSettings

	// Process container resource utilization thresholds
	if alertSettings.ContainerResourceUtilizationThresholds != nil {
		resourceThresholds := alertSettings.ContainerResourceUtilizationThresholds

		// CPU threshold
		if p.isValidFloat(resourceThresholds.ContainerCPUThresholdPercentage) {
			settings.ContainerCPUThreshold = resourceThresholds.ContainerCPUThresholdPercentage
			fmt.Printf("config::Using config map setting for CPU threshold: %g\n", settings.ContainerCPUThreshold)
		} else {
			fmt.Println("config::Non floating point value or value not convertible to float specified for CPU threshold, using default")
			settings.ContainerCPUThreshold = DefaultCPUUtilizationThreshold
		}

		// Memory RSS threshold
		if p.isValidFloat(resourceThresholds.ContainerMemoryRSSThresholdPercentage) {
			settings.ContainerMemoryRSSThreshold = resourceThresholds.ContainerMemoryRSSThresholdPercentage
			fmt.Printf("config::Using config map setting for Memory RSS threshold: %g\n", settings.ContainerMemoryRSSThreshold)
		} else {
			fmt.Println("config::Non floating point value or value not convertible to float specified for Memory RSS threshold, using default")
			settings.ContainerMemoryRSSThreshold = DefaultMemoryRSSThreshold
		}

		// Memory Working Set threshold
		if p.isValidFloat(resourceThresholds.ContainerMemoryWorkingSetThresholdPercentage) {
			settings.ContainerMemoryWorkingSetThreshold = resourceThresholds.ContainerMemoryWorkingSetThresholdPercentage
			fmt.Printf("config::Using config map setting for Memory Working Set threshold: %g\n", settings.ContainerMemoryWorkingSetThreshold)
		} else {
			fmt.Println("config::Non floating point value or value not convertible to float specified for Memory Working Set threshold, using default")
			settings.ContainerMemoryWorkingSetThreshold = DefaultMemoryWorkingSetThreshold
		}

		fmt.Println("config::Using config map settings for MDM metric configuration settings for container resource utilization")
	}

	// Process PV utilization thresholds
	isUsingPVThresholdConfig := false
	if alertSettings.PVUtilizationThresholds != nil {
		pvThresholds := alertSettings.PVUtilizationThresholds
		if p.isValidFloat(pvThresholds.PVUsageThresholdPercentage) {
			settings.PVUsageThreshold = pvThresholds.PVUsageThresholdPercentage
			isUsingPVThresholdConfig = true
		}
	}

	if isUsingPVThresholdConfig {
		fmt.Println("config::Using config map settings for MDM metric configuration settings for PV utilization")
	} else {
		fmt.Println("config::Non floating point value or value not convertible to float specified for PV threshold, using default")
		settings.PVUsageThreshold = DefaultPVUtilizationThreshold
	}

	// Process job completion threshold
	if alertSettings.JobCompletionThreshold != nil {
		jobThreshold := alertSettings.JobCompletionThreshold
		if p.isValidInt(jobThreshold.JobCompletionThresholdTimeMinutes) {
			settings.JobCompletionTimeThreshold = jobThreshold.JobCompletionThresholdTimeMinutes
			fmt.Println("config::Using config map settings for MDM metric configuration settings for job completion")
		} else {
			fmt.Println("config::Non integer value or value not convertible to integer specified for job completion threshold, using default")
			settings.JobCompletionTimeThreshold = DefaultJobCompletedTimeThresholdMinutes
		}
	}

	return settings
}

// GetDefaultSettings returns default configuration values
func (p *MDMMetricsConfigParser) GetDefaultSettings() *types.MDMMetricsEnvironment {
	return &types.MDMMetricsEnvironment{
		ContainerCPUThreshold:              DefaultCPUUtilizationThreshold,
		ContainerMemoryRSSThreshold:        DefaultMemoryRSSThreshold,
		ContainerMemoryWorkingSetThreshold: DefaultMemoryWorkingSetThreshold,
		PVUsageThreshold:                   DefaultPVUtilizationThreshold,
		JobCompletionTimeThreshold:         DefaultJobCompletedTimeThresholdMinutes,
	}
}

// isValidFloat checks if a float64 value is valid (finite and not NaN)
// Note: Zero values are considered invalid based on Ruby script behavior
func (p *MDMMetricsConfigParser) isValidFloat(value float64) bool {
	return value > 0.0 && !isNaN(value) && !isInf(value)
}

// isValidInt checks if an int value is valid (greater than zero)
func (p *MDMMetricsConfigParser) isValidInt(value int) bool {
	return value > 0
}

// Helper functions for float validation
func isNaN(f float64) bool {
	return f != f
}

func isInf(f float64) bool {
	return f > 1.7976931348623157e+308 || f < -1.7976931348623157e+308
}

// writeEnvironmentFiles generates environment variable files for both Windows and Linux
func (p *MDMMetricsConfigParser) writeEnvironmentFiles(settings *types.MDMMetricsEnvironment) error {
	if p.fileOps.IsWindows() {
		return p.writeWindowsEnvironmentFile(settings)
	} else {
		return p.writeLinuxEnvironmentFile(settings)
	}
}

// writeWindowsEnvironmentFile creates Windows-format environment file
func (p *MDMMetricsConfigParser) writeWindowsEnvironmentFile(settings *types.MDMMetricsEnvironment) error {
	var content strings.Builder

	content.WriteString(fmt.Sprintf("AZMON_ALERT_CONTAINER_CPU_THRESHOLD=%g\n", settings.ContainerCPUThreshold))
	content.WriteString(fmt.Sprintf("AZMON_ALERT_CONTAINER_MEMORY_WORKING_SET_THRESHOLD=%g\n", settings.ContainerMemoryWorkingSetThreshold))

	err := p.fileOps.WriteFile("setmdmenv.txt", content.String())
	if err != nil {
		logger.LogError(fmt.Sprintf("Exception while opening file for writing MDM metric config environment variables: %v", err))
		fmt.Println("****************End MDM Metrics Config Processing********************")
		return err
	}

	fmt.Println("****************End MDM Metrics Config Processing********************")
	return nil
}

// writeLinuxEnvironmentFile creates Linux-format environment file
func (p *MDMMetricsConfigParser) writeLinuxEnvironmentFile(settings *types.MDMMetricsEnvironment) error {
	var content strings.Builder

	content.WriteString(fmt.Sprintf("export AZMON_ALERT_CONTAINER_CPU_THRESHOLD=%g\n", settings.ContainerCPUThreshold))
	content.WriteString(fmt.Sprintf("export AZMON_ALERT_CONTAINER_MEMORY_RSS_THRESHOLD=%g\n", settings.ContainerMemoryRSSThreshold))
	content.WriteString(fmt.Sprintf("export AZMON_ALERT_CONTAINER_MEMORY_WORKING_SET_THRESHOLD=\"%g\"\n", settings.ContainerMemoryWorkingSetThreshold))
	content.WriteString(fmt.Sprintf("export AZMON_ALERT_PV_USAGE_THRESHOLD=%g\n", settings.PVUsageThreshold))
	content.WriteString(fmt.Sprintf("export AZMON_ALERT_JOB_COMPLETION_TIME_THRESHOLD=%d\n", settings.JobCompletionTimeThreshold))

	err := p.fileOps.WriteFile("config_mdm_metrics_env_var", content.String())
	if err != nil {
		logger.LogError(fmt.Sprintf("Exception while opening file for writing MDM metric config environment variables: %v", err))
		fmt.Println("****************End MDM Metrics Config Processing********************")
		return err
	}

	fmt.Println("****************End MDM Metrics Config Processing********************")
	return nil
}

// ProcessMDMMetricsConfig is the main entry point for processing MDM metrics configuration
func ProcessMDMMetricsConfig() {
	parser := NewMDMMetricsConfigParser()
	if err := parser.ParseAndProcess(); err != nil {
		logger.LogError(fmt.Sprintf("Failed to process MDM metrics config: %v", err))
		os.Exit(1)
	}
}
