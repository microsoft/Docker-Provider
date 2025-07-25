package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// FileOperations provides file operation utilities
type FileOperations struct{}

// NewFileOperations creates a new file operations instance
func NewFileOperations() *FileOperations {
	return &FileOperations{}
}

// IsWindows checks if the current OS is Windows
func (f *FileOperations) IsWindows() bool {
	osType := os.Getenv("OS_TYPE")
	if osType != "" {
		return strings.ToLower(strings.TrimSpace(osType)) == "windows"
	}
	return runtime.GOOS == "windows"
}

// FileExists checks if a file exists
func (f *FileOperations) FileExists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

// ReadFile reads a file and returns its contents
func (f *FileOperations) ReadFile(path string) (string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("failed to read file %s: %w", path, err)
	}
	return string(content), nil
}

// WriteFile writes content to a file
func (f *FileOperations) WriteFile(path, content string) error {
	// Create directory if it doesn't exist
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	err := os.WriteFile(path, []byte(content), 0644)
	if err != nil {
		return fmt.Errorf("failed to write file %s: %w", path, err)
	}
	return nil
}

// GetConfigMapPath returns the config map path based on OS
func (f *FileOperations) GetConfigMapPath() string {
	return "/etc/config/settings/log-data-collection-settings"
}

// GetFluentBitConfPath returns the fluent-bit config path based on OS
func (f *FileOperations) GetFluentBitConfPath() string {
	if f.IsWindows() {
		return "/etc/fluent-bit/fluent-bit.conf"
	}
	return "/etc/opt/microsoft/docker-cimprov/fluent-bit.conf"
}

// GetFluentBitCommonConfPath returns the fluent-bit common config path based on OS
func (f *FileOperations) GetFluentBitCommonConfPath() string {
	if f.IsWindows() {
		return "/etc/fluent-bit/fluent-bit-common.conf"
	}
	return "/etc/opt/microsoft/docker-cimprov/fluent-bit-common.conf"
}

// GetTenantTemplateFilePath returns the tenant template file path based on OS
func (f *FileOperations) GetTenantTemplateFilePath() string {
	if f.IsWindows() {
		return "C:\\etc\\fluent-bit\\fluent-bit-azmon-logs_tenant.conf"
	}
	return "/etc/opt/microsoft/docker-cimprov/fluent-bit-azmon-logs_tenant.conf"
}

// GetTenantFilePath returns the tenant file path for a specific namespace
func (f *FileOperations) GetTenantFilePath(tenantNamespace string) string {
	if f.IsWindows() {
		return fmt.Sprintf("C:\\etc\\fluent-bit\\fluent-bit-azmon-logs_tenant_%s.conf", tenantNamespace)
	}
	return fmt.Sprintf("/etc/opt/microsoft/docker-cimprov/fluent-bit-azmon-logs_tenant_%s.conf", tenantNamespace)
}

// ClearFile truncates a file (empties it)
func (f *FileOperations) ClearFile(path string) error {
	if !f.FileExists(path) {
		return nil // File doesn't exist, nothing to clear
	}

	file, err := os.OpenFile(path, os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		return fmt.Errorf("failed to open file for clearing %s: %w", path, err)
	}
	defer file.Close()

	return nil
}

// Global instance for convenience
var GlobalFileOps = NewFileOperations()

// Convenience functions for global access
func IsWindows() bool {
	return GlobalFileOps.IsWindows()
}

func FileExists(path string) bool {
	return GlobalFileOps.FileExists(path)
}

func ReadFile(path string) (string, error) {
	return GlobalFileOps.ReadFile(path)
}

func WriteFile(path, content string) error {
	return GlobalFileOps.WriteFile(path, content)
}
