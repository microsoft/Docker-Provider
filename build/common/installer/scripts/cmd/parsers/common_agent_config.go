package parsers

import (
	"dockerprovider-installer-scripts/internal/tomlparser_common_agent_config"

	"github.com/spf13/cobra"
)

// CommonAgentConfigCmd creates the command for common agent configuration parsing
func CommonAgentConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "common-agent-config",
		Short: "Parse common agent configuration from TOML",
		Long: `Parse common agent configuration settings from TOML file and generate environment variables.
This replaces the functionality of tomlparser-common-agent-config.rb.

The parser reads from /etc/config/settings/agent-settings and generates:
- Linux: common_agent_config_env_var (export format)
- Windows: setcommonagentenv.txt (KEY=VALUE format)

Configuration options include:
- Telemetry settings (disable_telemetry)
- Kubernetes metadata cache TTL (kube_meta_cache_ttl_secs)
- High log scale mode (enabled)
- Custom metrics (enabled)`,
		Run: func(cmd *cobra.Command, args []string) {
			tomlparser_common_agent_config.ProcessCommonAgentConfig()
		},
	}

	return cmd
}
