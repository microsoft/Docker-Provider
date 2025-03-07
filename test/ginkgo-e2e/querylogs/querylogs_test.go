package querylogs_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"docker-provider/test/utils"
)

var _ = Describe("When querying the logs for the table", func() {
	// > 0 logs in all tables in last 15 minutes
	// number of pods in the kubectl vs LA kubepodinventory
	DescribeTable("All tables should have logs",
		func(table string) {
			query := table + " | where TimeGenerated > ago(15m) | summarize count()"
			err := utils.QueryLogsForCount(LogsClient, AKSResourceId, query, false)
			Expect(err).NotTo(HaveOccurred())
		},
		// Check how to chose containerlog table
		Entry("ContainerLog", "ContainerLog"),
		Entry("ContainerLogV2", "ContainerLogV2"),
		Entry("ContainerInventory", "ContainerInventory"),
		Entry("ContainerNodeInventory", "ContainerNodeInventory"),
		Entry("KubeNodeInventory", "KubeNodeInventory"),
		Entry("KubePodInventory", "KubePodInventory"),
		Entry("KubePVInventory", "KubePVInventory"),
	)
})

var _ = Describe("When querying the logs for the ContainerInventory", func() {
	DescribeTable("Column should have zero empty values",
		func(column string) {
			query := "ContainerInventory | where TimeGenerated > ago(1h) | summarize countif(isempty(" + column + ") or isnull(" + column + "))"
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
