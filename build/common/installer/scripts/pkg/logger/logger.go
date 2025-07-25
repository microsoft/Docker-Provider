package logger

import (
	"fmt"
	"log"
	"os"
	"time"
)

// Logger interface for different logging implementations
type Logger interface {
	LogError(message string)
	LogInfo(message string)
	LogWarning(message string)
}

// ConfigErrorLogger implements the Logger interface
// Replaces ConfigParseErrorLogger.rb functionality
type ConfigErrorLogger struct {
	prefix string
}

// NewConfigErrorLogger creates a new config error logger
func NewConfigErrorLogger() *ConfigErrorLogger {
	return &ConfigErrorLogger{
		prefix: "config",
	}
}

// LogError logs an error message with timestamp
// Matches the functionality of ConfigParseErrorLogger.logError in Ruby
func (l *ConfigErrorLogger) LogError(message string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	errorMsg := fmt.Sprintf("[%s] %s::error: %s", timestamp, l.prefix, message)

	// Write to stderr like the Ruby version
	fmt.Fprintln(os.Stderr, errorMsg)
	// Also log using Go's standard logger
	log.Printf("ERROR: %s", message)
}

// LogInfo logs an informational message
func (l *ConfigErrorLogger) LogInfo(message string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	infoMsg := fmt.Sprintf("[%s] %s::info: %s", timestamp, l.prefix, message)
	fmt.Println(infoMsg)
	log.Printf("INFO: %s", message)
}

// LogWarning logs a warning message
func (l *ConfigErrorLogger) LogWarning(message string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	warnMsg := fmt.Sprintf("[%s] %s::warn: %s", timestamp, l.prefix, message)
	fmt.Println(warnMsg)
	log.Printf("WARN: %s", message)
}

// Global logger instance for backward compatibility
var globalLogger = NewConfigErrorLogger()

// LogError provides global access to error logging
// This matches the Ruby usage: ConfigParseErrorLogger.logError(message)
func LogError(message string) {
	globalLogger.LogError(message)
}

// LogInfo provides global access to info logging
func LogInfo(message string) {
	globalLogger.LogInfo(message)
}

// LogWarning provides global access to warning logging
func LogWarning(message string) {
	globalLogger.LogWarning(message)
}
