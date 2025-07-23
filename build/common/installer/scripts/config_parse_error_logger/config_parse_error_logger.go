package config_parse_error_logger

import (
	"encoding/json"
	"fmt"
	"os"
)

// LogError prints a JSON-formatted error message to stderr in red.
func LogError(message string) {
	errorMessage := "config::error::" + message
	jsonMessage, err := json.Marshal(errorMessage)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error in ConfigParseErrorLogger::LogError: %v\n", err)
		return
	}
	// Print in red using ANSI escape codes
	fmt.Fprintf(os.Stderr, "\033[31m%s\033[0m\n", string(jsonMessage))
}
