package containerstatus_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"docker-provider/test/utils"
)

var _ = DescribeTable("The containers should be running",
	func(namespace string, controllerLabelName string, controllerLabelValue string) {
		err := utils.CheckIfAllContainersAreRunning(K8sClient, namespace, controllerLabelName, controllerLabelValue)
		Expect(err).NotTo(HaveOccurred())
	},
	Entry("when checking the ama-metrics replica pod(s)", "kube-system", "rsName", "ama-logs-rs"),
	Entry("when checking the ama-metrics-node", "kube-system", "dsName", "ama-logs"),

// Entry("when checking the ama-metrics-win-node pod", "kube-system", "dsName", "ama-metrics-win-node", Label(utils.WindowsLabel)),
// Entry("when checking the ama-metrics-ksm pod", "kube-system", "app.kubernetes.io/name", "ama-metrics-ksm"),
// Entry("when checking the ama-metrics-operator-targets pod", "kube-system", "rsName", "ama-metrics-operator-targets", Label(utils.OperatorLabel)),
// Entry("when checking the prometheus-node-exporter pod", "kube-system", "app", "prometheus-node-exporter", Label(utils.ArcExtensionLabel)),
)
