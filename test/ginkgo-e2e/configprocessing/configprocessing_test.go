package configprocessing_test

import (
	"docker-provider/test/utils"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// Linux container process count checks
var _ = DescribeTable("Linux process count matches expected",
	func(labelName, labelValue, containerName, processName string, expectedCount int) {
		count, err := utils.CountProcessInstances(K8sClient, Cfg, "kube-system", labelName, labelValue, containerName, processName)
		Expect(err).NotTo(HaveOccurred())
		Expect(count).To(Equal(expectedCount))
	},

	// === Scenario: process-metrics-enabled ===
	Entry("ama-logs DS: 2 telegraf when process metrics enabled",
		"component", "ama-logs-agent", "ama-logs", "telegraf", 2,
		Label(utils.ConfigProcessMetricsEnabled)),
	Entry("ama-logs-rs: 1 telegraf when process metrics enabled",
		"rsName", "ama-logs-rs", "ama-logs", "telegraf", 1,
		Label(utils.ConfigProcessMetricsEnabled)),
	Entry("ama-logs-prometheus: 1 telegraf when process metrics enabled",
		"component", "ama-logs-agent", "ama-logs-prometheus", "telegraf", 1,
		Label(utils.ConfigProcessMetricsEnabled)),

	// === Scenario: process-metrics-default ===
	Entry("ama-logs DS: 1 telegraf with default config",
		"component", "ama-logs-agent", "ama-logs", "telegraf", 1,
		Label(utils.ConfigProcessMetricsDefault)),
	Entry("ama-logs-rs: 0 telegraf with default config",
		"rsName", "ama-logs-rs", "ama-logs", "telegraf", 0,
		Label(utils.ConfigProcessMetricsDefault)),
	Entry("ama-logs-prometheus: 0 telegraf with default config",
		"component", "ama-logs-agent", "ama-logs-prometheus", "telegraf", 0,
		Label(utils.ConfigProcessMetricsDefault)),
)

// Windows container process count checks (uses PowerShell instead of bash)
var _ = DescribeTable("Windows process count matches expected",
	func(labelName, labelValue, containerName, processName string, expectedCount int) {
		count, err := utils.CountWindowsProcessInstances(K8sClient, Cfg, "kube-system", labelName, labelValue, containerName, processName)
		Expect(err).NotTo(HaveOccurred())
		Expect(count).To(Equal(expectedCount))
	},

	// === Scenario: process-metrics-enabled ===
	Entry("ama-logs-windows: 1 telegraf when process metrics enabled",
		"component", "ama-logs-agent-windows", "ama-logs-windows", "telegraf", 1,
		Label(utils.ConfigProcessMetricsEnabled)),

	// === Scenario: process-metrics-default ===
	Entry("ama-logs-windows: 0 telegraf with default config",
		"component", "ama-logs-agent-windows", "ama-logs-windows", "telegraf", 0,
		Label(utils.ConfigProcessMetricsDefault)),
)
