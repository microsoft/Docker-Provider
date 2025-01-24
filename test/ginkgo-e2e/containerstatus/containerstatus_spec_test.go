package containerstatus_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"docker-provider/test/utils"
)

/*
 * For each of the pods that we deploy in our chart, ensure each container within that pod has status 'Running'.
 * The replicaset, daemonset, and kube-state-metrics are always deployed.
 * The operator-targets and node-exporter workloads are checked if the 'operator' or 'arc-extension' label is included in the test run.
 * The label and values are provided to get a list of pods only with that label.
 */
var _ = DescribeTable("The containers should be running",
	func(namespace string, controllerLabelName string, controllerLabelValue string) {
		err := utils.CheckIfAllContainersAreRunning(K8sClient, namespace, controllerLabelName, controllerLabelValue)
		Expect(err).NotTo(HaveOccurred())
	},
	Entry("when checking the ama-logs", "kube-system", "component", "ama-logs-agent"),
	Entry("when checking the ama-logs-rs replica pod(s)", "kube-system", "rsName", "ama-logs-rs"),
)

/*
 * For each of the DS pods that we deploy in our chart, ensure that all nodes have been used to schedule these pods.
 * The label and values are provided to get a list of pods only with that label.
 * The osLabel is provided to check on all DS pods based on the OS.
 */
var _ = DescribeTable("The pods should be scheduled in all nodes",
	func(namespace string, controllerLabelName string, controllerLabelValue string, osLabel string) {
		err := utils.CheckIfAllPodsScheduleOnNodes(K8sClient, namespace, controllerLabelName, controllerLabelValue, osLabel)
		Expect(err).NotTo(HaveOccurred())
	},
	Entry("when checking the ama-logs", "kube-system", "component", "ama-logs-agent", "linux"),
	Entry("when checking the ama-logs-win pod", "kube-system", "component", "ama-logs-agent", "windows", Label(utils.WindowsLabel)),
)

/*
* For each of the DS pods that we deploy in our chart, ensure that all specific nodes like ARM64,FIPS have been used to schedule these pods.
* The label and values are provided to get a list of pods only with that label.
 */
var _ = DescribeTable("The pods should be scheduled in all Fips and ARM64 nodes",
	func(namespace string, controllerLabelName string, controllerLabelValue string, nodeLabelKey string, nodeLabelValue string) {
		err := utils.CheckIfAllPodsScheduleOnSpecificNodesLabels(K8sClient, namespace, controllerLabelName, controllerLabelValue, nodeLabelKey, nodeLabelValue)
		Expect(err).NotTo(HaveOccurred())
	},
	Entry("when checking the ama-logs", "kube-system", "component", "ama-logs-agent", "kubernetes.azure.com/fips_enabled", "true", Label(utils.FIPSLabel)),
	Entry("when checking the ama-logs-win pod", "kube-system", "component", "ama-logs-agent", "kubernetes.azure.com/fips_enabled", "true", Label(utils.WindowsLabel), Label(utils.FIPSLabel)),
	Entry("when checking the ama-logs", "kube-system", "component", "ama-logs-agent", "kubernetes.io/arch", "arm64", Label(utils.ARM64Label)),
)

/*
* For each of the pods that have the ama-logs container, check all expected processes are running.
* The linux replicaset and daemonset will should have the same processes running.
 */
var _ = DescribeTable("All processes are running",
	func(namespace, labelName, labelValue, containerName string, processes []string) {
		err := utils.CheckAllProcessesRunning(K8sClient, Cfg, labelName, labelValue, namespace, containerName, processes)
		Expect(err).NotTo(HaveOccurred())
	},
	Entry("when checking the ama-logs-rs replica pod(s)", "kube-system", "rsName", "ama-logs-rs", "ama-logs",
		[]string{
			"fluent-bit",
			// "otelcollector",
			// "mdsd -a -A -e",
			// "MetricsExtension",
			// "inotifywait /etc/config/settings",
			// "inotifywait /etc/mdsd.d",
			// "crond",
		},
	),
	Entry("when checking the ama-logs daemonset pods", "kube-system", "component", "ama-logs-agent", "ama-logs",
		[]string{
			"fluent-bit",
			// "otelcollector",
			// "mdsd -a -A -e",
			// "MetricsExtension",
			// "inotifywait /etc/config/settings",
			// "inotifywait /etc/mdsd.d",
			// "crond",
		},
	),
)

/*
* For windows daemonset pods that have the ama-logs container, check all expected processes are running.
 */
// var _ = DescribeTable("All processes are running",
// 	func(namespace, labelName, labelValue, containerName string, processes []string) {
// 		err := utils.CheckAllWindowsProcessesRunning(K8sClient, Cfg, labelName, labelValue, namespace, containerName, processes)
// 		Expect(err).NotTo(HaveOccurred())
// 	},
// 	Entry("when checking the ama-metrics-win-node daemonset pods", "kube-system", "component", "ama-logs-agent", "ama-logs",
// 		[]string{
// 			"fluent-bit",
// 			// "otelcollector",
// 			// "MetricsExtension",
// 			// "MonAgentLauncher",
// 			// "MonAgentHost",
// 			// "MonAgentManager",
// 			// "MonAgentCore",
// 		},
// 		Label(utils.WindowsLabel),
// 		FlakeAttempts(3),
// 	),
// )

/*
- For each of the pods that we deploy in our chart, ensure each container within that pod doesn't have errors in the logs.
- The replicaset, daemonset, and kube-state-metrics are always deployed.
- The operator-targets and node-exporter workloads are checked if the 'operator' or 'arc-extension' label is included in the test run.
- The label and values are provided to get a list of pods only with that label.
*/
var _ = DescribeTable("The container logs should not contain errors",
	func(namespace string, controllerLabelName string, controllerLabelValue string) {
		err := utils.CheckContainerLogsForErrors(K8sClient, namespace, controllerLabelName, controllerLabelValue)
		Expect(err).NotTo(HaveOccurred())
	},
	Entry("when checking the ama-logs-rs pods", "kube-system", "rsName", "ama-logs-rs"),
	Entry("when checking the ama-logs", "kube-system", "component", "ama-logs-agent"),
	// Entry("when checking the ama-metrics replica pods", "kube-system", "rsName", "ama-metrics", Label(utils.ARM64Label)),
	// Entry("when checking the ama-metrics-node", "kube-system", "dsName", "ama-metrics-node", Label(utils.ARM64Label)),
	// Entry("when checking the ama-metrics-win-node", "kube-system", "dsName", "ama-metrics-win-node", Label(utils.WindowsLabel)),
	// Entry("when checking the ama-metrics-ksm pod", "kube-system", "app.kubernetes.io/name", "ama-metrics-ksm"),
	// Entry("when checking the ama-metrics-operator-targets pod", "kube-system", "rsName", "ama-metrics-operator-targets", Label(utils.OperatorLabel)),
	// Entry("when checking the prometheus-node-exporter pod", "kube-system", "app", "prometheus-node-exporter", Label(utils.ArcExtensionLabel)),
)
