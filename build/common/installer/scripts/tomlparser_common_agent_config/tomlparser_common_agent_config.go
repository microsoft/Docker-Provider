// tomlparser-common-agent-config.go
package tomlparser_common_agent_config

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/pelletier/go-toml"
)

func isWindows(osType string) bool {
	return strings.EqualFold(strings.TrimSpace(osType), "windows")
}

func isNumber(value string) bool {
	_, err := strconv.Atoi(value)
	return err == nil
}

func isValidNumber(value string) bool {
	if value == "" {
		return false
	}
	num, err := strconv.Atoi(value)
	return err == nil && num > 0
}

func isValidWaittime(value string, def int) bool {
	if value == "" {
		return false
	}
	num, err := strconv.Atoi(value)
	return err == nil && num >= def/2 && num <= 3*def
}

// ProcessCommonAgentConfig parses the agent config and writes environment variables.
func ProcessCommonAgentConfig() {
	osType := os.Getenv("OS_TYPE")
	configSchemaVersion := os.Getenv("AZMON_AGENT_CFG_SCHEMA_VERSION")
	configMapMountPath := "/etc/config/settings/agent-settings"

	disableTelemetry := false
	logEnableKubernetesMetadataCacheTTLSeconds := 60
	enableHighLogScaleMode := false
	enableCustomMetrics := false

	fmt.Println("****************Start Config Processing********************")
	if strings.EqualFold(strings.TrimSpace(configSchemaVersion), "v1") {
		parsedConfig, err := toml.LoadFile(configMapMountPath)
		if err == nil {
			agentSettings := parsedConfig.Get("agent_settings").(*toml.Tree)
			if agentSettings != nil {
				telemetryConfig := agentSettings.Get("telemetry_config").(*toml.Tree)
				if telemetryConfig != nil {
					if v := telemetryConfig.Get("disable_telemetry"); v != nil {
						disableTelemetry, _ = v.(bool)
						fmt.Printf("Using config map value: disable_telemetry = %v\n", disableTelemetry)
					}
				}
				k8sMetadataConfig := agentSettings.Get("k8s_metadata_config").(*toml.Tree)
				if k8sMetadataConfig != nil {
					if v := k8sMetadataConfig.Get("kube_meta_cache_ttl_secs"); v != nil {
						if ttl, ok := v.(int64); ok && ttl >= 0 {
							logEnableKubernetesMetadataCacheTTLSeconds = int(ttl)
							fmt.Printf("config::INFO: Using config map value: kube_meta_cache_ttl_secs = %d\n", logEnableKubernetesMetadataCacheTTLSeconds)
						} else {
							fmt.Println("config::WARN: Using the default value for kube_meta_cache_ttl_secs since provided config value is invalid")
						}
					}
				}
				highLogScale := agentSettings.Get("high_log_scale").(*toml.Tree)
				if highLogScale != nil {
					if v := highLogScale.Get("enabled"); v != nil {
						enableHighLogScaleMode, _ = v.(bool)
						fmt.Printf("Using config map value: enabled = %v for high log scale config\n", enableHighLogScaleMode)
					}
				}
				customMetrics := agentSettings.Get("custom_metrics").(*toml.Tree)
				if customMetrics != nil {
					if v := customMetrics.Get("enabled"); v != nil {
						enableCustomMetrics, _ = v.(bool)
						fmt.Printf("Using config map value: enabled = %v for custom metrics\n", enableCustomMetrics)
					}
				}
			}
		} else {
			fmt.Println("config::configmap container-azm-ms-agentconfig for common agent settings not mounted, using defaults")
		}
	} else {
		if _, err := os.Stat(configMapMountPath); err == nil {
			fmt.Printf("config::unsupported/missing config schema version - '%s' , using defaults, please use supported schema version\n", configSchemaVersion)
		}
	}

	if isWindows(osType) {
		file, err := os.Create("setcommonagentenv.txt")
		if err == nil {
			if disableTelemetry {
				file.WriteString(fmt.Sprintf("DISABLE_TELEMETRY=%v\n", disableTelemetry))
			}
			if enableHighLogScaleMode {
				file.WriteString(fmt.Sprintf("ENABLE_HIGH_LOG_SCALE_MODE=%v\n", enableHighLogScaleMode))
			}
			if enableCustomMetrics {
				file.WriteString(fmt.Sprintf("ENABLE_CUSTOM_METRICS=%v\n", enableCustomMetrics))
			}
			file.WriteString(fmt.Sprintf("AZMON_KUBERNETES_METADATA_CACHE_TTL_SECONDS=%d\n", logEnableKubernetesMetadataCacheTTLSeconds))
			file.Close()
			fmt.Println("****************End Config Processing********************")
		} else {
			fmt.Println("Exception while opening file for writing config environment variables for WINDOWS LOG")
			fmt.Println("****************End Config Processing********************")
		}
	} else {
		file, err := os.Create("common_agent_config_env_var")
		if err == nil {
			if disableTelemetry {
				file.WriteString(fmt.Sprintf("export DISABLE_TELEMETRY=%v\n", disableTelemetry))
			}
			if enableHighLogScaleMode {
				file.WriteString(fmt.Sprintf("export ENABLE_HIGH_LOG_SCALE_MODE=%v\n", enableHighLogScaleMode))
			}
			if enableCustomMetrics {
				file.WriteString(fmt.Sprintf("export ENABLE_CUSTOM_METRICS=%v\n", enableCustomMetrics))
			}
			file.WriteString(fmt.Sprintf("export AZMON_KUBERNETES_METADATA_CACHE_TTL_SECONDS=%d\n", logEnableKubernetesMetadataCacheTTLSeconds))
			file.Close()
		} else {
			fmt.Println("Exception while opening file for writing config environment variables")
			fmt.Println("****************End Config Processing********************")
		}
	}
}
