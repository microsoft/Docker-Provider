package querylogs_test

import (
	"testing"

	"docker-provider/test/utils"

	"github.com/Azure/azure-sdk-for-go/sdk/monitor/azquery"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

var K8sClient *kubernetes.Clientset
var LogsClient *azquery.LogsClient
var AKSResourceId string
var RetinaNetworkFlowLogsEnabled string
var Cfg *rest.Config

func TestQuerylogs(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Querylogs Suite")
}

var _ = BeforeSuite(func() {
	var err error
	K8sClient, Cfg, err = utils.SetupKubernetesClient()
	Expect(err).NotTo(HaveOccurred())
	AKSResourceId, err = utils.GetAKSResourceID(K8sClient, "kube-system", "component", "ama-logs-agent", "ama-logs")
	Expect(err).NotTo(HaveOccurred())
	RetinaNetworkFlowLogsEnabled, err = utils.IsRetinaNetworkFlowLogsEnabled(K8sClient, "kube-system", "component", "ama-logs-agent", "ama-logs")
	Expect(err).NotTo(HaveOccurred())
	LogsClient, err = utils.SetupLogsClient()
	Expect(err).NotTo(HaveOccurred())
})

var _ = AfterSuite(func() {
	By("tearing down the test environment")
})
