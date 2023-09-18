//go:build linux

package main

import "net"

func CreateWindowsNamedPipeClient(namedPipe string, namedPipeConnection *net.Conn) {
	//function unimplemented
	Log("Error::CreateWindowsNamedPipeClient not implemented for Linux")
}

func CreateGenevaOr3PNamedPipe(namedPipeConnection *net.Conn, datatype string, errorCount *float64, isGenevaLogsIntegrationEnabled bool, refreshTracker *time.Time) bool {
	//function unimplemented
	Log("Error::CreateGenevaOr3PNamedPipe not implemented for Linux")
	return false
}
