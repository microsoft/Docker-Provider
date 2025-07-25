package main

import (
	"fmt"
	"os"

	"dockerprovider-installer-scripts/cmd/parsers"

	"github.com/spf13/cobra"
)

var version = "1.0.0"

var rootCmd = &cobra.Command{
	Use:   "config-parser",
	Short: "Azure Monitor configuration parser and modifier",
	Long: `A unified Go application that replaces Ruby scripts for parsing TOML configurations
and modifying Fluent Bit configuration files for Azure Monitor containers.`,
	Version: version,
}

var parseCmd = &cobra.Command{
	Use:   "parse",
	Short: "Parse TOML configuration files",
	Long:  "Parse various TOML configuration files and generate environment variables",
}

var modifyCmd = &cobra.Command{
	Use:   "modify",
	Short: "Modify configuration files",
	Long:  "Modify Fluent Bit and other configuration files by substituting placeholders",
}

func init() {
	// Add subcommands
	rootCmd.AddCommand(parseCmd)
	rootCmd.AddCommand(modifyCmd)

	// Parse commands
	parseCmd.AddCommand(&cobra.Command{
		Use:   "toml",
		Short: "Main TOML parser (replaces tomlparser.rb)",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("TOML parser - not implemented yet")
		},
	})

	// Add the real common agent config command
	parseCmd.AddCommand(parsers.CommonAgentConfigCmd())

	// Modify commands (placeholders for now)
	modifyCmd.AddCommand(&cobra.Command{
		Use:   "fluent-bit",
		Short: "Fluent Bit configuration customizer",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Fluent Bit customizer - not implemented yet")
		},
	})

	modifyCmd.AddCommand(&cobra.Command{
		Use:   "fluent-bit-geneva",
		Short: "Geneva Fluent Bit configuration customizer",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Geneva Fluent Bit customizer - not implemented yet")
		},
	})
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
