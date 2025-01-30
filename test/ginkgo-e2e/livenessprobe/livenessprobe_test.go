package livenessprobe_test

import (
	"docker-provider/test/utils"
	"fmt"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// All events that restart the replicaset pods need to be run sequentially to not conflict.
var _ = Describe("When replicaset ama-logs-rs container liveness probe detects that", Ordered, func() {
	// Check restarts for each process not running.
	DescribeTable("the process", Ordered,
		func(namespace, labelName, labelValue, containerName, terminatedMessage, processName string, timeout int64) {
			restartCommand := []string{
				"sh",
				"-c",
				fmt.Sprintf("kill -9 $(ps ax | grep \"%s\" | fgrep -v grep | awk '{ print $1 }')", processName),
			}
			err := utils.CheckLivenessProbeRestartForProcess(K8sClient, Cfg, labelName, labelValue, namespace, containerName, terminatedMessage, processName, restartCommand, timeout)
			Expect(err).NotTo(HaveOccurred())

			// Wait for all processes in pod to start up before running any other tests
			time.Sleep(120 * time.Second)
		},
		Entry("Fluentbit is not running, the container should restart", "kube-system", "rsName", "ama-logs-rs", "ama-logs",
			"Fluentbit is not running", "fluent-bit", int64(180),
		),
		Entry("fluentd is not running, the container should restart", "kube-system", "rsName", "ama-logs-rs", "ama-logs",
			"fluentd is not running", "fluentd", int64(180),
		),
		Entry("mdsd is not running, the container should restart", "kube-system", "rsName", "ama-logs-rs", "ama-logs",
			"mdsd is not running", "mdsd -a -A -r", int64(180),
		),

		// ToDo: add telegraf check
	)

	Specify("the container-azm-ms-aks-k8scluster configmap has updated, the container should restart", func() {
		err := utils.GetAndUpdateConfigMap(K8sClient, "container-azm-ms-aks-k8scluster", "kube-system")
		Expect(err).NotTo(HaveOccurred())
		err = utils.WatchForPodRestart(K8sClient, "kube-system", "rsName", "ama-logs-rs", 180, "ama-logs",
			"inotifyoutput.txt has been updated - config changed",
		)
		Expect(err).NotTo(HaveOccurred())
	})

	// ToDo: check for certifical renewal - do we need this given we rely on MSI now?
})

// var _ = Describe("When the daemonset ama-logs container liveness probe detects that", Ordered, func() {
// 	DescribeTable("the process", Ordered,
// 		func(namespace, labelName, labelValue, containerName, terminatedMessage, processName string, timeout int64) {
// 			restartCommand := []string{"sh", "-c", fmt.Sprintf("kill -9 $(ps ax | grep \"%s\" | fgrep -v grep | awk '{ print $1 }')", processName)}
// 			err := utils.CheckLivenessProbeRestartForProcess(K8sClient, Cfg, labelName, labelValue, namespace, containerName, terminatedMessage, processName, restartCommand, timeout)
// 			Expect(err).NotTo(HaveOccurred())

// 			// Wait for all processes in pod to start up before running any other tests
// 			time.Sleep(180 * time.Second)
// 		},
// 		Entry("Fluentbit is not running, the container should restart", "kube-system", "component", "ama-logs-agent", "ama-logs",
// 			"Fluentbit is not running", "fluent-bit", int64(180),
// 		),
// 		Entry("fluentd is not running, the container should restart", "kube-system", "component", "ama-logs-agent", "ama-logs",
// 			"fluentd is not running", "fluentd", int64(180),
// 		),
// 		Entry("mdsd is not running, the container should restart", "kube-system", "component", "ama-logs-agent", "ama-logs",
// 			"mdsd is not running", "mdsd -a -A -r", int64(180),
// 		),

// 		// ToDo: add telegraf check
// 	)

// 	It("the container-azm-ms-aks-k8scluster configmap has updated, the container should restart", Label(utils.LinuxDaemonsetCustomConfig), func() {
// 		err := utils.GetAndUpdateConfigMap(K8sClient, "container-azm-ms-aks-k8scluster", "kube-system")
// 		Expect(err).NotTo(HaveOccurred())
// 		err = utils.WatchForPodRestart(K8sClient, "kube-system", "component", "ama-logs-agent", 180, "ama-logs",
// 			"inotifyoutput.txt has been updated - config changed",
// 		)
// 		Expect(err).NotTo(HaveOccurred())
// 	})
// })

// var _ = Describe("When the windows ama-logs-windows container liveness probe detects that", Ordered, Label(utils.WindowsLabel), func() {
// 	DescribeTable("the process", Ordered,
// 		func(namespace, labelName, labelValue, containerName, terminatedMessage, processName string, timeout int64) {
// 			restartCommand := []string{"powershell", fmt.Sprintf("get-process \"%s\" | stop-process", processName)}
// 			err := utils.CheckLivenessProbeRestartForProcess(K8sClient, Cfg, labelName, labelValue, namespace, containerName, terminatedMessage, processName, restartCommand, timeout)
// 			Expect(err).NotTo(HaveOccurred())

// 			// Wait for all processes in pod to start up before running any other tests
// 			time.Sleep(240 * time.Second)
// 		},
// 		Entry("Fluentbit is not running, the container should restart", "kube-system", "component", "ama-logs-agent-windows", "ama-logs-windows",
// 			"Fluentbit is not running", "fluent-bit", int64(180),
// 		),
// 		Entry("MonAgentLauncher is not running, the container should restart", "kube-system", "component", "ama-logs-agent-windows", "ama-logs-windows",
// 			"MonAgentLauncher is not running", "MonAgentLauncher", int64(180),
// 		),
// 		// ToDo: MonAgetnCore and others?
// 	)

// 	It("the container-azm-ms-aks-k8scluster config for the windows daemonset has updated, the container should restart", func() {
// 		err := utils.GetAndUpdateConfigMap(K8sClient, "container-azm-ms-aks-k8scluster", "kube-system")
// 		Expect(err).NotTo(HaveOccurred())
// 		err = utils.WatchForPodRestart(K8sClient, "kube-system", "component", "ama-logs-agent-windows", 300, "ama-logs-windows", "")
// 		Expect(err).NotTo(HaveOccurred())
// 	})
// })
