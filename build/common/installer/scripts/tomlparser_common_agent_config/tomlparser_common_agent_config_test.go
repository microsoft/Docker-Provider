// tomlparser-common-agent-config_test.go
package tomlparser_common_agent_config

import (
	"os"
	"testing"

	"github.com/pelletier/go-toml"
)

func TestParseAgentSettings(t *testing.T) {
	// Create a sample TOML config for testing
	tomlContent := `
[agent_settings]
  [agent_settings.telemetry_config]
    disable_telemetry = true
  [agent_settings.k8s_metadata_config]
    kube_meta_cache_ttl_secs = 120
  [agent_settings.high_log_scale]
    enabled = true
  [agent_settings.custom_metrics]
    enabled = false
`
	tmpFile := "agent-settings-test.toml"
	err := os.WriteFile(tmpFile, []byte(tomlContent), 0644)
	if err != nil {
		t.Fatalf("Failed to create test TOML file: %v", err)
	}
	defer os.Remove(tmpFile)

	parsedConfig, err := toml.LoadFile(tmpFile)
	if err != nil {
		t.Fatalf("Failed to parse TOML file: %v", err)
	}

	agentSettings := parsedConfig.Get("agent_settings").(*toml.Tree)
	if agentSettings == nil {
		t.Fatal("agent_settings section missing")
	}

	telemetryConfig := agentSettings.Get("telemetry_config").(*toml.Tree)
	if telemetryConfig == nil || telemetryConfig.Get("disable_telemetry") != true {
		t.Error("disable_telemetry not parsed correctly")
	}

	k8sMetadataConfig := agentSettings.Get("k8s_metadata_config").(*toml.Tree)
	if k8sMetadataConfig == nil || k8sMetadataConfig.Get("kube_meta_cache_ttl_secs").(int64) != 120 {
		t.Error("kube_meta_cache_ttl_secs not parsed correctly")
	}

	highLogScale := agentSettings.Get("high_log_scale").(*toml.Tree)
	if highLogScale == nil || highLogScale.Get("enabled") != true {
		t.Error("high_log_scale.enabled not parsed correctly")
	}

	customMetrics := agentSettings.Get("custom_metrics").(*toml.Tree)
	if customMetrics == nil || customMetrics.Get("enabled") != false {
		t.Error("custom_metrics.enabled not parsed correctly")
	}
}
