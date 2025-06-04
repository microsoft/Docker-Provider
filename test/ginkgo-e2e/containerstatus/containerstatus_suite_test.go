package containerstatus_test

import (
	"os"
	"testing"

	"docker-provider/test/utils"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

// These tests use Ginkgo (BDD-style Go testing framework). Refer to
// http://onsi.github.io/ginkgo/ to learn more about Ginkgo.

var K8sClient *kubernetes.Clientset
var Cfg *rest.Config
var ResourceOptimizationEnabled string
var GenevaIntegrationEnabled string

func TestContainerStatus(t *testing.T) {
	RegisterFailHandler(Fail)

	RunSpecs(t, "Container Status Test Suite")
}

var _ = BeforeSuite(func() {
	var err error
	K8sClient, Cfg, err = utils.SetupKubernetesClient()
	Expect(err).NotTo(HaveOccurred())
	ResourceOptimizationEnabled, err = utils.IsResourceOptimizationEnabled(K8sClient, "kube-system", "component", "ama-logs-agent", "ama-logs")
	Expect(err).NotTo(HaveOccurred())
	GenevaIntegrationEnabled = os.Getenv("GENEVA_INTEGRATION")
})

var _ = AfterSuite(func() {
	By("tearing down the test environment")
})
