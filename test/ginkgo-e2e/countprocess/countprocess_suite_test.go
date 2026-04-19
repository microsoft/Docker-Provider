package countprocess_test

import (
	"testing"

	"docker-provider/test/utils"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

var K8sClient *kubernetes.Clientset
var Cfg *rest.Config

func TestCountProcess(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Count Process Test Suite")
}

var _ = BeforeSuite(func() {
	var err error
	K8sClient, Cfg, err = utils.SetupKubernetesClient()
	Expect(err).NotTo(HaveOccurred())
})
