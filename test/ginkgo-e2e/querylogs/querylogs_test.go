package querylogs_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"docker-provider/test/utils"
)

var _ = Describe("Querylogs", func() {
	DescribeTable("The logs should be queried",
		func(resourceID string, query string) {
			err := utils.Querylogs(resourceID, query)
			Expect(err).NotTo(HaveOccurred())
		},
		Entry("when querying the logs for the resource",
			"/subscriptions/6e377996-dbe0-4f90-aeee-e1592d1d7c0d/resourceGroups/AKSTest/providers/Microsoft.ContainerService/managedClusters/aks-rp-test",
			"ContainerInventory | take 1"),
	)
})
