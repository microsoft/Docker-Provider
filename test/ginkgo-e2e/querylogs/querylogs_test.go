package querylogs_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"docker-provider/test/utils"
)

var _ = DescribeTable("The logs should be queried",
	func(query string) {
		err := utils.Querylogs(resourceId, query)
		Expect(err).NotTo(HaveOccurred())
	},
	Entry("when querying the logs for the resource", "ContainerInventory | take 5 | where TimeGenerated > ago(1d) | where Name == \"\" | summarize count()"),
)
