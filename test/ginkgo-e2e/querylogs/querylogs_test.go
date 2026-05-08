package querylogs_test

import (
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"docker-provider/test/utils"
)

var _ = Describe("When querying the logs for the table", func() {
	DescribeTable("All tables should have logs",
		func(table string) {
			// Skip RetinaNetworkFlowLogs test if the feature is not enabled
			if table == "RetinaNetworkFlowLogs" && RetinaNetworkFlowLogsEnabled != "true" {
				Skip("RetinaNetworkFlowLogs test skipped because ENABLE_RETINA_NETWORK_FLOW_LOGS is not set to 'true'")
			}
			if table == "ContainerLog" && GenevaIntegrationEnabled == "true" {
				Skip("ContainerLog test skipped because GENEVA_INTEGRATION is set to 'true'")
			}
			var err error
			query := table + " | where TimeGenerated > ago(5m) | summarize count()"
			err = utils.QueryLogsForCount(LogsClient, AKSResourceId, query, false)
			// If ContainerLogV2 is configured, query ContainerLogV2 table instead of ContainerLog
			if err != nil && strings.Contains(table, "ContainerLog") {
				query := "ContainerLogV2 | where TimeGenerated > ago(5m) | summarize count()"
				err = utils.QueryLogsForCount(LogsClient, AKSResourceId, query, false)
			}
			Expect(err).NotTo(HaveOccurred())
		},
		Entry("Perf", "Perf"),
		Entry("InsightsMetrics", "InsightsMetrics"),
		Entry("ContainerLog", "ContainerLog"),
		Entry("ContainerInventory", "ContainerInventory"),
		Entry("ContainerNodeInventory", "ContainerNodeInventory"),
		Entry("KubeNodeInventory", "KubeNodeInventory"),
		Entry("KubePodInventory", "KubePodInventory"),
		Entry("KubePVInventory", "KubePVInventory"),
		Entry("RetinaNetworkFlowLogs", "RetinaNetworkFlowLogs"),
	)
})

var _ = Describe("When querying ContainerLogV2 per node", func() {
	It("Every node hosting an ama-logs DaemonSet pod should have ContainerLogV2 rows", func() {
		if PerNodeLogCoverageEnabled != "true" {
			Skip("Per-node ContainerLogV2 coverage skipped because PER_NODE_LOG_COVERAGE is not set to 'true'")
		}
		if GenevaIntegrationEnabled == "true" {
			Skip("ContainerLogV2 per-node coverage skipped because GENEVA_INTEGRATION is set to 'true'")
		}

		expectedNodes, err := utils.GetExpectedAmaLogsNodes(K8sClient)
		Expect(err).NotTo(HaveOccurred())

		observed, err := utils.GetComputerFromContainerLog(LogsClient, AKSResourceId, "5m")
		Expect(err).NotTo(HaveOccurred())

		Expect(utils.AssertContainerLogNodeCoverage(expectedNodes, observed)).NotTo(HaveOccurred())
	})
})

var _ = Describe("When querying the logs for the ContainerInventory", func() {
	DescribeTable("Column should have zero empty values",
		func(column string) {
			// Skip records with ContainerState 'Waiting' to avoid false positives due to the container being in a waiting state.
			// If the pod name contains 'ama-logs', we include it to ensure we capture the ama-logs agent containers.
			query := "ContainerInventory | where TimeGenerated > ago(5m) and (ContainerState !~ 'Waiting' or ContainerHostname contains 'ama-logs') | summarize countif(isempty(" + column + ") or isnull(" + column + "))"
			err := utils.QueryLogsForCount(LogsClient, AKSResourceId, query, true)
			Expect(err).NotTo(HaveOccurred())
		},
		Entry("Image", "Image"),
		Entry("ImageID", "ImageID"),
		Entry("ImageTag", "ImageTag"),
		Entry("Repository", "Repository"),
	)
})

var _ = Describe("When querying the number of resources of the cluster", func() {
	DescribeTable("The resource from kube api should be present in logs",
		func(table string) {
			err := utils.CompareResourcesInLogsAndKubeAPI(K8sClient, LogsClient, AKSResourceId, table)
			Expect(err).NotTo(HaveOccurred())
		},
		Entry("Pods", "KubePodInventory"),
		Entry("Nodes", "KubeNodeInventory"),
	)
})
