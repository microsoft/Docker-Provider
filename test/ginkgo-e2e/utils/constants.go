package utils

var (
	// ExpectedIntermittentErrors are error patterns that should be tolerated up to IntermittentErrorThreshold occurrences
	ExpectedIntermittentErrors = []string{
		"Error in plugin: error making HTTP request",
		"connection refused",
		"HTTP/1.1 500 Internal Server Error",
		"WINHTTP_CALLBACK_STATUS_REQUEST_ERROR",
		"The connection with the server was terminated abnormally",
		"TCP connection failed",
		"no upstream connections available",
		"internet connectivity",
		"GetAgentConfigurations",
		"RefreshConfigurations",
		"canceled by user",
	}
)

const (
	WindowsLabel = "windows"
	ARM64Label   = "arm64"
	FIPSLabel    = "fips"

	// IntermittentErrorThreshold is the maximum number of occurrences allowed for expected intermittent errors
	IntermittentErrorThreshold = 10
)
