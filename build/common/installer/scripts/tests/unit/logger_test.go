package unit

import (
	"testing"

	"dockerprovider-installer-scripts/pkg/logger"

	"github.com/stretchr/testify/assert"
)

func TestConfigErrorLogger(t *testing.T) {
	// Test logger creation
	l := logger.NewConfigErrorLogger()
	assert.NotNil(t, l)

	// Test global logging functions exist and don't panic
	assert.NotPanics(t, func() {
		logger.LogInfo("Test info message")
	})

	assert.NotPanics(t, func() {
		logger.LogWarning("Test warning message")
	})

	assert.NotPanics(t, func() {
		logger.LogError("Test error message")
	})
}
