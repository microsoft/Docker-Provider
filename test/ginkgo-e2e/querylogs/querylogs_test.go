package querylogs_test

import (
	"fmt"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"docker-provider/test/utils"
)

const (
	// The Go output plugin publishes telemetry every defaultTelemetryPushIntervalSeconds
	// (300s), so a pod younger than this has legitimately not reported a heartbeat yet.
	agentTelemetryPublishInterval = 5 * time.Minute
	// Span several publish intervals so one delayed batch does not fail the assertion.
	agentTelemetryWindow = "20m"
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

var _ = Describe("When querying Container logs per node", func() {
	It("Every node hosting an ama-logs DaemonSet pod should have Container logs", func() {
		if PerNodeLogCoverageEnabled != "true" {
			Skip("Per-node Container log coverage skipped because PER_NODE_LOG_COVERAGE is not set to 'true'")
		}
		if GenevaIntegrationEnabled == "true" {
			Skip("Container log per-node coverage skipped because GENEVA_INTEGRATION is set to 'true'")
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

var _ = Describe("When querying the agent telemetry", func() {
	// expectedVersionByNode maps each node to the image tag its agent is running, which the
	// agent reports back as customDimensions.Version. Resolving it per node is what makes these
	// assertions verify the image the deploy stage just rolled out, rather than accepting
	// telemetry that its predecessor published earlier in the same query window.
	var expectedVersionByNode map[string]string

	BeforeEach(func() {
		if AgentTelemetryResourceId == "" {
			Skip("Agent telemetry checks skipped because AGENT_TELEMETRY_RESOURCE_ID is not set")
		}

		var err error
		expectedVersionByNode, err = utils.GetAgentImageTagsByNode(K8sClient, "kube-system", "component", "ama-logs-agent", "ama-logs", agentTelemetryPublishInterval)
		Expect(err).NotTo(HaveOccurred())
		if len(expectedVersionByNode) == 0 {
			Skip("No ama-logs DaemonSet pod has been running long enough to have published telemetry")
		}

		// The build bakes AGENT_VERSION in from its own telemetry tag rather than from the
		// image tag, and the two diverge on release builds, where TELEMETRY_TAG overrides it.
		// When the pipeline passes that tag it is authoritative, so prefer it over the tag
		// read off the pod.
		if AgentTelemetryVersion != "" {
			for node := range expectedVersionByNode {
				expectedVersionByNode[node] = AgentTelemetryVersion
			}
		}
	})

	It("Every node running an ama-logs DaemonSet pod should report a telemetry heartbeat from the deployed image", func() {
		// A running agent does not imply working telemetry. Container logs reach the workspace
		// over a local mdsd socket, so they keep flowing even when the agent's outbound
		// telemetry path is entirely broken. Asserting that the heartbeat actually arrived is
		// what distinguishes the two.
		observed, err := utils.GetAgentTelemetryVersionsByNode(LogsClient, AgentTelemetryResourceId, AKSResourceId, agentTelemetryWindow, "customEvents", utils.AgentTelemetryHeartbeatEvent)
		Expect(err).NotTo(HaveOccurred())

		Expect(utils.AssertNodeVersionCoverage("agent telemetry heartbeat", expectedVersionByNode, observed)).NotTo(HaveOccurred())
	})

	DescribeTable("Every node should publish agent telemetry from the deployed image to the table",
		func(table string) {
			// The heartbeat only proves the custom event path works. Metrics travel the same
			// outbound connection but through a different SDK track call, so a break confined
			// to one of them stays invisible until each table is asserted on its own.
			observed, err := utils.GetAgentTelemetryVersionsByNode(LogsClient, AgentTelemetryResourceId, AKSResourceId, agentTelemetryWindow, table, "")
			Expect(err).NotTo(HaveOccurred())

			Expect(utils.AssertNodeVersionCoverage(table, expectedVersionByNode, observed)).NotTo(HaveOccurred())
		},
		Entry("customEvents", "customEvents"),
		Entry("customMetrics", "customMetrics"),
	)

	It("Agent log traces that arrive should come from the deployed image", func() {
		// traces carries the agent's own log lines, and only those that are not "Information"
		// level, so a healthy agent emits none: in a sampled 30 minute window only 41,491 of
		// the 107,982 clusters reporting a heartbeat produced a single trace. Requiring traces
		// would fail the majority of healthy clusters, so the query still has to succeed and
		// any trace that does arrive still has to come from the deployed image, but an empty
		// result is reported rather than failed.
		observed, err := utils.GetAgentTelemetryVersionsByNode(LogsClient, AgentTelemetryResourceId, AKSResourceId, agentTelemetryWindow, "traces", "")
		Expect(err).NotTo(HaveOccurred())

		AddReportEntry("agent log traces", fmt.Sprintf("%d trace(s) from %d/%d node(s) in the last %s", utils.TotalItems(observed), len(observed), len(expectedVersionByNode), agentTelemetryWindow))

		Expect(utils.AssertReportedNodeVersions("agent log traces", expectedVersionByNode, observed)).NotTo(HaveOccurred())
	})
})
