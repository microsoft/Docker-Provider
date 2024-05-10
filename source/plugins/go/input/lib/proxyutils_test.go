package lib

import (
	"os"
	"testing"
)

func TestIsProxyCACertConfigured(t *testing.T) {
	// Create a test proxy cert file
	proxyCertPath = "./test-proxy-cert.crt"
	_, err := os.Create(proxyCertPath)
	if err != nil {
		t.Fatalf("Failed to create test proxy cert file: %v", err)
	}
	defer os.Remove(proxyCertPath)

	// Call the function and check the result
	if !isProxyCACertConfigured() {
		t.Errorf("isProxyCACertConfigured returned false, expected true")
	}

	defer func() {
		proxyCertPath = "/etc/ama-logs-secret/PROXYCERT.crt"
	}()
}

func TestIsIgnoreProxySettings(t *testing.T) {
	// Set the IGNORE_PROXY_SETTINGS environment variable to "true"
	defer func() { os.Unsetenv("IGNORE_PROXY_SETTINGS") }()
	os.Setenv("IGNORE_PROXY_SETTINGS", "true")

	// Call the function and check the result
	if !isIgnoreProxySettings() {
		t.Errorf("isIgnoreProxySettings returned false, expected true")
	}
}
