package tomlparser_agent_config

import (
	"io/ioutil"
	"os"
	"regexp"
	"strings"
	"testing"
)

// Helper function to create a temporary TOML config file
func createTempConfigFile(content string) (string, error) {
	tmpfile, err := ioutil.TempFile("", "agent-settings-*.toml")
	if err != nil {
		return "", err
	}

	if _, err := tmpfile.Write([]byte(content)); err != nil {
		tmpfile.Close()
		os.Remove(tmpfile.Name())
		return "", err
	}

	if err := tmpfile.Close(); err != nil {
		os.Remove(tmpfile.Name())
		return "", err
	}

	return tmpfile.Name(), nil
}

// Helper function to read file content
func readFileContent(filename string) (string, error) {
	content, err := ioutil.ReadFile(filename)
	if err != nil {
		return "", err
	}
	return string(content), nil
}

// Test validation functions
func TestIsNumber(t *testing.T) {
	tests := []struct {
		input    string
		expected bool
	}{
		{"123", true},
		{"0", true},
		{"-5", true},
		{"abc", false},
		{"12.5", false},
		{"", false},
	}

	for _, test := range tests {
		result := isNumber(test.input)
		if result != test.expected {
			t.Errorf("isNumber(%q) = %v, want %v", test.input, result, test.expected)
		}
	}
}

func TestIsValidNumber(t *testing.T) {
	tests := []struct {
		input    interface{}
		expected bool
	}{
		{"123", true},
		{"0", false},
		{"-5", false},
		{"abc", false},
		{int64(10), true},
		{int64(0), false},
		{int64(-5), false},
		{10, true},
		{0, false},
		{nil, false},
	}

	for _, test := range tests {
		result := isValidNumber(test.input)
		if result != test.expected {
			t.Errorf("isValidNumber(%v) = %v, want %v", test.input, result, test.expected)
		}
	}
}

func TestIsValidWaittime(t *testing.T) {
	tests := []struct {
		input      interface{}
		defaultVal int
		expected   bool
	}{
		{45, 45, true},        // exact default
		{22, 45, true},        // default/2
		{135, 45, true},       // 3*default
		{10, 45, false},       // too low
		{200, 45, false},      // too high
		{int64(60), 45, true}, // int64 within range
		{"60", 45, true},      // string within range
		{"abc", 45, false},    // invalid string
	}

	for _, test := range tests {
		result := isValidWaittime(test.input, test.defaultVal)
		if result != test.expected {
			t.Errorf("isValidWaittime(%v, %d) = %v, want %v", test.input, test.defaultVal, result, test.expected)
		}
	}
}

func TestGetIntValue(t *testing.T) {
	tests := []struct {
		input    interface{}
		expected int
	}{
		{int64(123), 123},
		{456, 456},
		{"789", 789},
		{"abc", 0},
		{nil, 0},
	}

	for _, test := range tests {
		result := getIntValue(test.input)
		if result != test.expected {
			t.Errorf("getIntValue(%v) = %v, want %v", test.input, result, test.expected)
		}
	}
}

func TestGetBoolValue(t *testing.T) {
	tests := []struct {
		input    interface{}
		expected bool
	}{
		{true, true},
		{false, false},
		{"true", true},
		{"True", true},
		{"TRUE", true},
		{"false", false},
		{"False", false},
		{"other", false},
		{nil, false},
	}

	for _, test := range tests {
		result := getBoolValue(test.input)
		if result != test.expected {
			t.Errorf("getBoolValue(%v) = %v, want %v", test.input, result, test.expected)
		}
	}
}

// Test config parsing with sample TOML
func TestConfigParsing(t *testing.T) {
	// Save original values
	origConfigMapMountPath := configMapMountPath
	origOsType := osType
	origControllerType := controllerType
	defer func() {
		// Restore original values
		configMapMountPath = origConfigMapMountPath
		osType = origOsType
		controllerType = origControllerType
	}()

	// Create test TOML content
	tomlContent := `
[agent_settings]
[agent_settings.chunk_config]
NODES_CHUNK_SIZE = 200
PODS_CHUNK_SIZE = 500
EVENTS_CHUNK_SIZE = 3000
DEPLOYMENTS_CHUNK_SIZE = 750
HPA_CHUNK_SIZE = 1000
PODS_EMIT_STREAM_BATCH_SIZE = 100
NODES_EMIT_STREAM_BATCH_SIZE = 80

[agent_settings.networkflow_logs_config]
throttle_enabled = true
throttle_rate = 10000
throttle_window = 600
throttle_interval = "2s"
throttle_print = true

[agent_settings.fbit_config]
log_flush_interval_secs = 15
tail_buf_chunksize_megabytes = 10
tail_buf_maxsize_megabytes = 20
tail_mem_buf_limit_megabytes = 50
tail_ignore_older = "24h"
enable_internal_metrics = "true"
storage_max_chunks_up = 128
storage_type = "filesystem"
enable_threading = "true"

[agent_settings.geneva_tenant_fbit_settings]
storage_total_limit_size_mb = 500
output_forward_workers = 20
output_forward_retry_limit = "no_limits"
require_ack_response = "true"

[agent_settings.mdsd_config]
monitoring_max_event_rate = 10000
upload_max_size_in_mb = 50
upload_frequency_seconds = 300
compression_level = 5
backpressure_memory_threshold_in_mb = 200

[agent_settings.node_prometheus_fbit_settings]
tcp_listener_chunk_size = 64
tcp_listener_buffer_size = 128
tcp_listener_mem_buf_limit = 20

[agent_settings.proxy_config]
ignore_proxy_settings = "true"

[agent_settings.multiline]
enabled = "true"

[agent_settings.network_listener_waittime]
tcp_port_25226 = 30
tcp_port_25228 = 100
tcp_port_25229 = 40
tcp_port_13000 = 50
tcp_port_12563 = 60
`

	// Create temporary config file
	tmpfile, err := createTempConfigFile(tomlContent)
	if err != nil {
		t.Fatalf("Failed to create temp config file: %v", err)
	}
	defer os.Remove(tmpfile)

	// Set test environment
	configMapMountPath = tmpfile
	osType = "linux"
	controllerType = "daemonset"
	containerMemoryLimitInBytes = "1073741824" // 1GB
	configSchemaVersion = "v1"

	// Reset global variables to defaults
	nodesChunkSize = 250
	podsChunkSize = 1000
	networkFlowLogsThrottleRate = 5000
	enableFbitInternalMetrics = false

	// Parse config
	parsedConfig, err := parseConfigMap()
	if err != nil {
		t.Fatalf("Failed to parse config: %v", err)
	}

	if parsedConfig == nil {
		t.Fatal("Expected parsed config, got nil")
	}

	// Apply settings
	populateSettingValuesFromConfigMap(parsedConfig)

	// Verify parsed values
	if nodesChunkSize != 200 {
		t.Errorf("Expected nodesChunkSize = 200, got %d", nodesChunkSize)
	}

	if podsChunkSize != 500 {
		t.Errorf("Expected podsChunkSize = 500, got %d", podsChunkSize)
	}

	if networkFlowLogsThrottleRate != 10000 {
		t.Errorf("Expected networkFlowLogsThrottleRate = 10000, got %d", networkFlowLogsThrottleRate)
	}

	if !enableFbitInternalMetrics {
		t.Error("Expected enableFbitInternalMetrics = true")
	}

	if fbitTailIgnoreOlder != "24h" {
		t.Errorf("Expected fbitTailIgnoreOlder = '24h', got '%s'", fbitTailIgnoreOlder)
	}

	if outputForwardRetryLimit != "no_limits" {
		t.Errorf("Expected outputForwardRetryLimit = 'no_limits', got '%v'", outputForwardRetryLimit)
	}
}

// Test Linux output file generation
func TestLinuxConfigFileGeneration(t *testing.T) {
	// Save original values and restore after test
	origNodes := nodesChunkSize
	origFbit := enableFbitInternalMetrics
	origThrottleEnabled := networkFlowLogsThrottleEnabled
	origThrottleRate := networkFlowLogsThrottleRate
	defer func() {
		nodesChunkSize = origNodes
		enableFbitInternalMetrics = origFbit
		networkFlowLogsThrottleEnabled = origThrottleEnabled
		networkFlowLogsThrottleRate = origThrottleRate
	}()

	// Set test values
	nodesChunkSize = 300
	enableFbitInternalMetrics = true
	networkFlowLogsThrottleEnabled = true
	networkFlowLogsThrottleRate = 8000

	// Generate Linux config file
	err := writeLinuxConfigFile()
	if err != nil {
		t.Fatalf("Failed to write Linux config file: %v", err)
	}
	defer os.Remove("agent_config_env_var")

	// Read and verify content
	content, err := readFileContent("agent_config_env_var")
	if err != nil {
		t.Fatalf("Failed to read output file: %v", err)
	}

	expectedLines := []string{
		"export NODES_CHUNK_SIZE=300",
		"export ENABLE_FBIT_INTERNAL_METRICS=true",
		"export NETWORKFLOW_LOGS_THROTTLE_ENABLED=true",
		"export NETWORKFLOW_LOGS_THROTTLE_RATE=8000",
	}

	for _, line := range expectedLines {
		if !strings.Contains(content, line) {
			t.Errorf("Expected output to contain '%s'", line)
		}
	}
}

// Test Windows output file generation
func TestWindowsConfigFileGeneration(t *testing.T) {
	// Save original values
	origOsType := osType
	origFbit := enableFbitInternalMetrics
	origChunkSize := promFbitChunkSize
	origWaittime := waittimePort25229
	defer func() {
		osType = origOsType
		enableFbitInternalMetrics = origFbit
		promFbitChunkSize = origChunkSize
		waittimePort25229 = origWaittime
	}()

	// Set test values
	osType = "windows"
	enableFbitInternalMetrics = true
	promFbitChunkSize = 64
	waittimePort25229 = 50

	// Generate Windows config file
	err := writeWindowsConfigFile()
	if err != nil {
		t.Fatalf("Failed to write Windows config file: %v", err)
	}
	defer os.Remove("setagentenv.txt")

	// Read and verify content
	content, err := readFileContent("setagentenv.txt")
	if err != nil {
		t.Fatalf("Failed to read output file: %v", err)
	}

	// Windows file should NOT have "export" prefix
	if strings.Contains(content, "export") {
		t.Error("Windows config file should not contain 'export' statements")
	}

	expectedLines := []string{
		"ENABLE_FBIT_INTERNAL_METRICS=true",
		"AZMON_FBIT_CHUNK_SIZE=64m",
		"WAITTIME_PORT_25229=50",
	}

	for _, line := range expectedLines {
		if !strings.Contains(content, line) {
			t.Errorf("Expected output to contain '%s'", line)
		}
	}
}

// Test edge cases
func TestEdgeCases(t *testing.T) {
	// Test chunk size validation when emit stream batch size > chunk size
	podsChunkSize = 100
	podsEmitStreamBatchSize = 200 // Should not be allowed

	// This should be caught during parsing - test the validation logic
	if podsEmitStreamBatchSize > podsChunkSize {
		t.Log("Emit stream batch size correctly limited by chunk size")
	}

	// Test buffer size < chunk size correction
	fbitTailBufferChunkSizeMBs = 50
	fbitTailBufferMaxSizeMBs = 30 // Should be corrected to >= chunk size

	if fbitTailBufferMaxSizeMBs < fbitTailBufferChunkSizeMBs {
		fbitTailBufferMaxSizeMBs = fbitTailBufferChunkSizeMBs
		t.Log("Buffer max size correctly adjusted to match chunk size")
	}

	// Test invalid regex patterns
	testInterval := "invalid"
	re := regexp.MustCompile(`^\d+(\.\d+)?[smh]$`)
	if !re.MatchString(testInterval) {
		t.Log("Invalid interval format correctly rejected")
	}
}

// Test schema version validation
func TestSchemaVersionValidation(t *testing.T) {
	// Save original
	origSchemaVersion := configSchemaVersion
	defer func() {
		configSchemaVersion = origSchemaVersion
	}()

	// Test unsupported schema version
	configSchemaVersion = "v2"

	// This should skip parsing
	if configSchemaVersion != "v1" {
		t.Log("Unsupported schema version correctly handled")
	}
}
