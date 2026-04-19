package countprocess_test

import (
	"fmt"
	"os"
	"strconv"

	"docker-provider/test/utils"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// envInt reads an integer from an environment variable, returning defaultVal if unset or invalid.
func envInt(key string, defaultVal int) int {
	v := os.Getenv(key)
	if v == "" {
		return defaultVal
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return defaultVal
	}
	return n
}

var _ = Describe("Process count validation", func() {
	var (
		expectedTelegrafDS         int
		expectedTelegrafRS         int
		expectedTelegrafPrometheus int
		expectedTelegrafWindows    int
	)

	BeforeEach(func() {
		expectedTelegrafDS = envInt("EXPECTED_TELEGRAF_DS", 1)
		expectedTelegrafRS = envInt("EXPECTED_TELEGRAF_RS", 0)
		expectedTelegrafPrometheus = envInt("EXPECTED_TELEGRAF_PROMETHEUS", 0)
		expectedTelegrafWindows = envInt("EXPECTED_TELEGRAF_WINDOWS", 0)
	})

	It("ama-logs DS has expected telegraf count", func() {
		count, err := utils.CountProcessInstances(K8sClient, Cfg, "kube-system",
			"component", "ama-logs-agent", "ama-logs", "telegraf")
		Expect(err).NotTo(HaveOccurred())
		Expect(count).To(Equal(expectedTelegrafDS),
			fmt.Sprintf("expected %d telegraf in ama-logs DS, got %d", expectedTelegrafDS, count))
	})

	It("ama-logs-rs has expected telegraf count", func() {
		count, err := utils.CountProcessInstances(K8sClient, Cfg, "kube-system",
			"rsName", "ama-logs-rs", "ama-logs", "telegraf")
		Expect(err).NotTo(HaveOccurred())
		Expect(count).To(Equal(expectedTelegrafRS),
			fmt.Sprintf("expected %d telegraf in ama-logs-rs, got %d", expectedTelegrafRS, count))
	})

	It("ama-logs-prometheus has expected telegraf count", func() {
		count, err := utils.CountProcessInstances(K8sClient, Cfg, "kube-system",
			"component", "ama-logs-agent", "ama-logs-prometheus", "telegraf")
		Expect(err).NotTo(HaveOccurred())
		Expect(count).To(Equal(expectedTelegrafPrometheus),
			fmt.Sprintf("expected %d telegraf in ama-logs-prometheus, got %d", expectedTelegrafPrometheus, count))
	})

	It("ama-logs-windows has expected telegraf count", func() {
		count, err := utils.CountWindowsProcessInstances(K8sClient, Cfg, "kube-system",
			"component", "ama-logs-agent-windows", "ama-logs-windows", "telegraf")
		Expect(err).NotTo(HaveOccurred())
		Expect(count).To(Equal(expectedTelegrafWindows),
			fmt.Sprintf("expected %d telegraf in ama-logs-windows, got %d", expectedTelegrafWindows, count))
	})
})
