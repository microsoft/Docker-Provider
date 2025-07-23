package main

import (
	"os"
	"fmt"
	"dockerprovider-installer-scripts/tomlparser_common_agent_config"
	// import other parser packages as needed
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: main <parser>")
		os.Exit(1)
	}

	switch os.Args[1] {
	case "common-agent-config":
		tomlparser_common_agent_config.ProcessCommonAgentConfig()
	// case "other-parser":
	//     otherparser.ProcessOtherConfig()
	default:
		fmt.Printf("Unknown parser: %s\n", os.Args[1])
		os.Exit(1)
	}
}
