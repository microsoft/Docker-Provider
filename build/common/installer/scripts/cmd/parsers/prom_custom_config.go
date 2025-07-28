package parsers

import (
	"fmt"
	"os"

	"dockerprovider-installer-scripts/internal/tomlparser_prom_customconfig"

	"github.com/spf13/cobra"
)

// PromCustomConfigCmd creates the command for Prometheus custom configuration parsing
func PromCustomConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "prom-custom-config",
		Short: "Parse Prometheus custom configuration",
		Long: `Parse Prometheus custom configuration and generate Telegraf configuration files.
This replaces the functionality of tomlparser-prom-customconfig.rb.

This parser handles Prometheus custom configuration for different controller types:
- ReplicaSet: Cluster-level Prometheus scraping configuration
- DaemonSet (Prometheus Sidecar): Custom Prometheus scraping for monitor pods
- DaemonSet (Node): Node-level Prometheus scraping configuration

The parser processes TOML configuration files and generates:
- Modified Telegraf configuration files with replaced placeholders
- Telemetry environment files for monitoring
- Cross-platform environment files (Linux/Windows)

Environment variables used:
- CONTROLLER_TYPE: Type of controller (replicaset/daemonset)
- CONTAINER_TYPE: Container type (prometheussidecar for sidecar mode)
- SIDECAR_SCRAPING_ENABLED: Enable sidecar scraping (true/false)
- OS_TYPE: Operating system type (windows/linux)
- AZMON_AGENT_CFG_SCHEMA_VERSION: Configuration schema version (v1)`,
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("****************Start Prometheus Config Processing********************")

			// Create parser instance
			parser := tomlparser_prom_customconfig.NewParser()

			// Check schema version
			if !parser.CheckSchemaVersion() {
				configMapMountPath := "/etc/config/settings/prometheus-data-collection-settings"
				if _, err := os.Stat(configMapMountPath); err == nil {
					return fmt.Errorf("config::unsupported/missing config schema version, using defaults, please use supported version")
				} else {
					fmt.Println("config::No configmap mounted for prometheus custom config, using defaults")
					fmt.Println("****************End Prometheus Config Processing********************")
					return nil
				}
			}

			// Parse the configuration map
			config, err := parser.ParseConfigMap()
			if err != nil {
				fmt.Printf("Error parsing configuration: %v\n", err)
				fmt.Println("****************End Prometheus Config Processing********************")
				return err
			}

			// Process the configuration based on controller type
			err = parser.ProcessConfiguration(config)
			if err != nil {
				fmt.Printf("Error processing configuration: %v\n", err)
				fmt.Println("****************End Prometheus Config Processing********************")
				return err
			}

			fmt.Println("****************End Prometheus Config Processing********************")
			return nil
		},
	}

	return cmd
}
