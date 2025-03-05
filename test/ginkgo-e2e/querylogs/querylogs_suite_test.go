package querylogs_test

import (
	"testing"

	"docker-provider/test/utils"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

var resourceId string
var K8sClient *kubernetes.Clientset
var Cfg *rest.Config

func TestQuerylogs(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Querylogs Suite")
}

var _ = BeforeSuite(func() {
	var err error
	K8sClient, Cfg, err = utils.SetupKubernetesClient()
	Expect(err).NotTo(HaveOccurred())
	resourceId, err = utils.GetAKSResourceID(K8sClient, "kube-system", "component", "ama-logs-agent", "ama-logs")
	Expect(err).NotTo(HaveOccurred())
})

var _ = AfterSuite(func() {
	By("tearing down the test environment")
})
