//go:build linux

package main

import (
	"errors"
	"net"
	"os/exec"
	"strings"
	"time"
)

func CreateWindowsNamedPipeClient(namedPipe string, namedPipeConnection *net.Conn) error {
	return errors.New("Error::CreateWindowsNamedPipeClient not implemented for Linux")
}

func EnsureGenevaOr3PNamedPipeExists(namedPipeConnection *net.Conn, datatype string, errorCount *float64, isGenevaLogsIntegrationEnabled bool, refreshTracker *time.Time) bool {
	//function unimplemented
	Log("Error::EnsureGenevaOr3PNamedPipeExists not implemented for Linux")
	return false
}

func isProcessRunning(processName string) (string, error) {
	cmd := exec.Command("pgrep", processName)
	output, err := cmd.Output()

	if err != nil || len(strings.TrimSpace(string(output))) == 0 {
		return "false", err
	}

	return "true", nil
}
