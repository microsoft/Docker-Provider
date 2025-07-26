package parsers

import (
	"dockerprovider-installer-scripts/internal/tomlparser_mdm_metrics_config"

	"github.com/spf13/cobra"
)

// MDMMetricsConfigCmd creates the command for MDM metrics configuration parsing
func MDMMetricsConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "mdm-metrics-config",
		Short: "Parse MDM metrics configuration from TOML",
		Long: `Parse MDM metrics configuration settings from TOML file and generate environment variables.
This replaces the functionality of tomlparser-mdm-metrics-config.rb.

The parser reads from /etc/config/settings/alertable-metrics-configuration-settings and generates:
- Linux: config_mdm_metrics_env_var (export format)
- Windows: setmdmenv.txt (KEY=VALUE format)

Configuration options include:
- Container CPU threshold percentage
- Container memory RSS threshold percentage  
- Container memory working set threshold percentage
- PV usage threshold percentage
- Job completion time threshold in minutes`,
		Run: func(cmd *cobra.Command, args []string) {
			tomlparser_mdm_metrics_config.ProcessMDMMetricsConfig()
		},
	}

	return cmd
}
