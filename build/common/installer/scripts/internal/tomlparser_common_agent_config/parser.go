package tomlparser_common_agent_config

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
	DefaultMetadataCacheTTLSeconds = 60
	ConfigMapMountPath             = "/etc/config/settings/agent-settings"
)

// CommonAgentConfigParser handles parsing of common agent configuration
type CommonAgentConfigParser struct {
	fileOps *utils.FileOperations
	logger  logger.Logger
}

// NewCommonAgentConfigParser creates a new parser instance
func NewCommonAgentConfigParser() *CommonAgentConfigParser {
	return &CommonAgentConfigParser{
		fileOps: utils.NewFileOperations(),
		logger:  logger.NewConfigErrorLogger(),
	}
}

// ParseAndProcess parses the agent config and generates environment files
func (p *CommonAgentConfigParser) ParseAndProcess() error {
	fmt.Println("****************Start Config Processing********************")

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
func (p *CommonAgentConfigParser) parseConfigMap() (*types.AgentConfigMapSettings, error) {
	if !p.fileOps.FileExists(ConfigMapMountPath) {
		fmt.Println("config::configmap container-azm-ms-agentconfig for common agent settings not mounted, using defaults")
		return nil, nil
	}

	fmt.Println("config::configmap container-azm-ms-agentconfig for common agent settings mounted, parsing values")

	content, err := p.fileOps.ReadFile(ConfigMapMountPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config types.AgentConfigMapSettings
	err = toml.Unmarshal([]byte(content), &config)
	if err != nil {
		return nil, fmt.Errorf("failed to parse TOML: %w", err)
	}

	fmt.Println("config::Successfully parsed mounted config map")
	return &config, nil
}

// ProcessConfigMap extracts settings from parsed configuration
func (p *CommonAgentConfigParser) ProcessConfigMap(config *types.AgentConfigMapSettings) *types.AgentEnvironment {
	settings := p.GetDefaultSettings()

	if config == nil || config.AgentSettings == nil {
		return settings
	}

	agentSettings := config.AgentSettings

	// Process telemetry config
	if agentSettings.TelemetryConfig != nil {
		settings.DisableTelemetry = agentSettings.TelemetryConfig.DisableTelemetry
		fmt.Printf("Using config map value: disable_telemetry = %t\n", settings.DisableTelemetry)
	}

	// Process k8s metadata config
	if agentSettings.K8sMetadataConfig != nil {
		ttlValue := agentSettings.K8sMetadataConfig.KubeMetaCacheTTLSecs
		if ttlValue >= 0 {
			settings.AzmonKubernetesMetadataCacheTTLSeconds = ttlValue
			fmt.Printf("config::INFO: Using config map value: kube_meta_cache_ttl_secs = %d\n", settings.AzmonKubernetesMetadataCacheTTLSeconds)
		} else {
			fmt.Println("config::WARN: Using the default value for kube_meta_cache_ttl_secs since provided config value is invalid")
		}
	}

	// Process high log scale config
	if agentSettings.HighLogScale != nil {
		settings.EnableHighLogScaleMode = agentSettings.HighLogScale.Enabled
		fmt.Printf("Using config map value: enabled = %t for high log scale config\n", settings.EnableHighLogScaleMode)
	}

	// Process custom metrics config
	if agentSettings.CustomMetrics != nil {
		settings.EnableCustomMetrics = agentSettings.CustomMetrics.Enabled
		fmt.Printf("Using config map value: enabled = %t for custom metrics\n", settings.EnableCustomMetrics)
	}

	return settings
}

// GetDefaultSettings returns default configuration values
func (p *CommonAgentConfigParser) GetDefaultSettings() *types.AgentEnvironment {
	return &types.AgentEnvironment{
		DisableTelemetry:                       false,
		EnableHighLogScaleMode:                 false,
		EnableCustomMetrics:                    false,
		AzmonKubernetesMetadataCacheTTLSeconds: DefaultMetadataCacheTTLSeconds,
	}
}

// writeEnvironmentFiles generates environment variable files for both Windows and Linux
func (p *CommonAgentConfigParser) writeEnvironmentFiles(settings *types.AgentEnvironment) error {
	if p.fileOps.IsWindows() {
		return p.writeWindowsEnvironmentFile(settings)
	} else {
		return p.writeLinuxEnvironmentFile(settings)
	}
}

// writeWindowsEnvironmentFile creates Windows-format environment file
func (p *CommonAgentConfigParser) writeWindowsEnvironmentFile(settings *types.AgentEnvironment) error {
	var content strings.Builder

	if settings.DisableTelemetry {
		content.WriteString(fmt.Sprintf("DISABLE_TELEMETRY=%t\n", settings.DisableTelemetry))
	}

	if settings.EnableHighLogScaleMode {
		content.WriteString(fmt.Sprintf("ENABLE_HIGH_LOG_SCALE_MODE=%t\n", settings.EnableHighLogScaleMode))
	}

	if settings.EnableCustomMetrics {
		content.WriteString(fmt.Sprintf("ENABLE_CUSTOM_METRICS=%t\n", settings.EnableCustomMetrics))
	}

	content.WriteString(fmt.Sprintf("AZMON_KUBERNETES_METADATA_CACHE_TTL_SECONDS=%d\n", settings.AzmonKubernetesMetadataCacheTTLSeconds))

	err := p.fileOps.WriteFile("setcommonagentenv.txt", content.String())
	if err != nil {
		logger.LogError(fmt.Sprintf("Exception while opening file for writing config environment variables for WINDOWS: %v", err))
		fmt.Println("****************End Config Processing********************")
		return err
	}

	fmt.Println("****************End Config Processing********************")
	return nil
}

// writeLinuxEnvironmentFile creates Linux-format environment file
func (p *CommonAgentConfigParser) writeLinuxEnvironmentFile(settings *types.AgentEnvironment) error {
	var content strings.Builder

	if settings.DisableTelemetry {
		content.WriteString(fmt.Sprintf("export DISABLE_TELEMETRY=%t\n", settings.DisableTelemetry))
	}

	if settings.EnableHighLogScaleMode {
		content.WriteString(fmt.Sprintf("export ENABLE_HIGH_LOG_SCALE_MODE=%t\n", settings.EnableHighLogScaleMode))
	}

	if settings.EnableCustomMetrics {
		content.WriteString(fmt.Sprintf("export ENABLE_CUSTOM_METRICS=%t\n", settings.EnableCustomMetrics))
	}

	content.WriteString(fmt.Sprintf("export AZMON_KUBERNETES_METADATA_CACHE_TTL_SECONDS=%d\n", settings.AzmonKubernetesMetadataCacheTTLSeconds))

	err := p.fileOps.WriteFile("common_agent_config_env_var", content.String())
	if err != nil {
		logger.LogError(fmt.Sprintf("Exception while opening file for writing config environment variables: %v", err))
		fmt.Println("****************End Config Processing********************")
		return err
	}

	return nil
}

// ProcessCommonAgentConfig is the main entry point for processing agent configuration
func ProcessCommonAgentConfig() {
	parser := NewCommonAgentConfigParser()
	if err := parser.ParseAndProcess(); err != nil {
		logger.LogError(fmt.Sprintf("Failed to process common agent config: %v", err))
		os.Exit(1)
	}
}
