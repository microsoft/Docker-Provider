module docker-provider/test/configprocessing

go 1.26.1

replace docker-provider/test/utils => ../utils

require (
	docker-provider/test/utils v0.0.0
	github.com/onsi/ginkgo/v2 v2.27.2
	github.com/onsi/gomega v1.38.2
	k8s.io/client-go v0.35.3
)
