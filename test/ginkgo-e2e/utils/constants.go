package utils

var (
	// Slices can't be constants
	LogLineErrorsToExclude = [...]string{
		// Arc token adapter
		"create or renew cluster identity error",
		"get token from status error",
		"Objects listed",
		// Target allocator
		"client connection lost",
	}
)

const (
	OperatorLabel              = "operator"
	ArcExtensionLabel          = "arc-extension"
	WindowsLabel               = "windows"
	ARM64Label                 = "arm64"
	FIPSLabel                  = "fips"
	LinuxDaemonsetCustomConfig = "linux-daemonset-custom-config"
)
