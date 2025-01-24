package utils

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/rest"

	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/remotecommand"

	"bytes"
	"fmt"
	"io"
)

/*
 * Checks that the logs of all containers in all pods with the given label do not contain any errors.
 * Also returns an error if there are no pods that exist with the given label.
 */
func CheckContainerLogsForErrors(clientset *kubernetes.Clientset, namespace, labelName, labelValue string) error {
	// Get all pods with the given label
	pods, err := GetPodsWithLabel(clientset, namespace, labelName, labelValue)
	if err != nil {
		return err
	}

	// Check the logs of each container in each pod for errors
	for _, pod := range pods {
		for _, container := range pod.Spec.Containers {
			logs, err := getContainerLogs(clientset, pod.Namespace, pod.Name, container.Name)
			if err != nil {
				return err
			}

			if strings.Contains(logs, "error") || strings.Contains(logs, "Error") {
				// Get the exact log line of the error
				for _, line := range strings.Split(logs, "\n") {

					if strings.Contains(line, "error") || strings.Contains(line, "Error") {

						// Exclude known error lines that are transient
						shouldExcludeLine := false
						for _, lineToExclude := range LogLineErrorsToExclude {
							if strings.Contains(line, lineToExclude) {
								shouldExcludeLine = true
								break
							}
						}
						if shouldExcludeLine {
							continue
						}

						return fmt.Errorf("Logs for container %s in pod %s contain errors:\n %s", container.Name, pod.Name, line)
					}
				}
			}
		}
	}
	return nil
}

/*
 * Returns all pods in the given namespace with the given label.
 */
func GetPodsWithLabel(clientset *kubernetes.Clientset, namespace string, labelKey string, labelValue string) ([]corev1.Pod, error) {
	podList, err := clientset.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
		LabelSelector: labelKey + "=" + labelValue,
	})
	if err != nil {
		return nil, err
	}
	if podList == nil || len(podList.Items) == 0 {
		return nil, fmt.Errorf("no pods found with label %s=%s", labelKey, labelValue)
	}

	return podList.Items, nil
}

/*
 * Helper function that returns the logs of the given container in the given pod.
 */
func getContainerLogs(clientset *kubernetes.Clientset, namespace string, podName string, containerName string) (string, error) {
	req := clientset.CoreV1().RESTClient().Get().
		Namespace(namespace).
		Name(podName).
		Resource("pods").
		SubResource("log").
		Param("container", containerName).
		Param("timestamps", "true")

	readCloser, err := req.Stream(context.Background())
	if err != nil {
		return "", fmt.Errorf("failed to get logs for container %s in pod %s: %v", containerName, podName, err)
	}
	defer readCloser.Close()

	buf := new(bytes.Buffer)
	_, err = io.Copy(buf, readCloser)
	if err != nil {
		return "", fmt.Errorf("failed to read logs for container %s in pod %s: %v", containerName, podName, err)
	}

	return buf.String(), nil
}

/*
 * For the given list of processes, checks that all of them are running in all the containers with the given name, in the pods with the given label.
 */
func CheckAllProcessesRunning(K8sClient *kubernetes.Clientset, Cfg *rest.Config, labelName, labelValue, namespace, containerName string, processes []string) error {
	var processesGrepStringBuilder strings.Builder
	for _, process := range processes {
		processesGrepStringBuilder.WriteString(fmt.Sprintf("ps | grep \"%s\" | grep -v grep && ", process))
	}

	processesGrepString := strings.TrimSuffix(processesGrepStringBuilder.String(), " && ")

	command := []string{"bash", "-c", processesGrepString}

	pods, err := GetPodsWithLabel(K8sClient, namespace, labelName, labelValue)
	if err != nil {
		return fmt.Errorf("Error when getting pods with label %s=%s: %v", labelName, labelValue, err)
	}

	for _, pod := range pods {
		_, _, err := ExecCmd(K8sClient, Cfg, pod.Name, containerName, namespace, command)
		if err != nil {
			return fmt.Errorf("Error when running command %v in the container: %v", command, err)
		}
	}
	return nil
}

/*
 * For the given list of processes, checks that all of them are running in all the containers with the given name, in the pods with the given label.
 */
func CheckAllWindowsProcessesRunning(K8sClient *kubernetes.Clientset, Cfg *rest.Config, labelName, labelValue, namespace, containerName string, processes []string) error {
	var processesGrepStringBuilder strings.Builder
	processesGrepStringBuilder.WriteString(fmt.Sprintf("ps | findstr"))
	for _, process := range processes {
		processesGrepStringBuilder.WriteString(fmt.Sprintf(" /c:'%s'", process))
	}

	processesGrepString := strings.TrimSuffix(processesGrepStringBuilder.String(), "; ")

	command := []string{"powershell", "-Command", processesGrepString}

	pods, err := GetPodsWithLabel(K8sClient, namespace, labelName, labelValue)
	if err != nil {
		return fmt.Errorf("Error when getting pods with label %s=%s: %v", labelName, labelValue, err)
	}

	for _, pod := range pods {
		ret_stdout, _, err := ExecCmd(K8sClient, Cfg, pod.Name, containerName, namespace, command)
		if err != nil {
			return fmt.Errorf("Error when running command %v in the container: %v", command, err)
		}
		// Check if all processes are present in the ret_stdout
		for _, process := range processes {
			if !strings.Contains(ret_stdout, process) {
				return fmt.Errorf("Process %s is not running in pod %s container %s", process, pod.Name, containerName)
			}
		}
	}
	return nil
}

/*
 * Executes the given command in the specified container of the pod and returns the stdout and stderr.
 */
func ExecCmd(client *kubernetes.Clientset, config *rest.Config, podName string, containerName string, namespace string, command []string) (stdout string, stderr string, err error) {
	req := client.CoreV1().RESTClient().Post().
		Resource("pods").
		Name(podName).
		Namespace(namespace).
		SubResource("exec")
	scheme := runtime.NewScheme()
	if err := corev1.AddToScheme(scheme); err != nil {
		return "", "", fmt.Errorf("Error setting up exec request: %v", err)
	}

	parameterCodec := runtime.NewParameterCodec(scheme)
	req.VersionedParams(&corev1.PodExecOptions{
		Command:   command,
		Container: containerName,
		Stdin:     false,
		Stdout:    true,
		Stderr:    true,
		TTY:       false,
	}, parameterCodec)

	exec, err := remotecommand.NewSPDYExecutor(config, "POST", req.URL())
	if err != nil {
		return "", "", fmt.Errorf("Error while creating command executor: %v", err)
	}

	ctx, _ := context.WithTimeout(context.Background(), 60*time.Second)
	var stdoutB, stderrB bytes.Buffer
	if err := exec.StreamWithContext(ctx, remotecommand.StreamOptions{
		Stdout: &stdoutB,
		Stderr: &stderrB,
	}); err != nil {
		return stdoutB.String(), stderrB.String(), fmt.Errorf("Error when running command %v in the container: %v. Stderr: %s", command, err, stderrB.String())
	}

	return stdoutB.String(), stderrB.String(), nil
}

/*
 * For a specified container name in pods with a given label and a process name, this checks that the liveness probe restarts the container when the process is terminated.
 */
func CheckLivenessProbeRestartForProcess(K8sClient *kubernetes.Clientset, Cfg *rest.Config, labelName, labelValue, namespace, containerName, terminatedMessage, processName string, restartCommand []string, timeout int64) error {
	pods, err := GetPodsWithLabel(K8sClient, namespace, labelName, labelValue)
	if err != nil {
		return err
	}

	for _, pod := range pods {
		_, stderr, err := ExecCmd(K8sClient, Cfg, pod.Name, containerName, namespace, restartCommand)
		if err != nil {
			return err
		}

		if stderr != "" {
			return fmt.Errorf("stderr: %s", stderr)
		}

		err = WatchForPodRestart(K8sClient, namespace, labelName, labelValue, timeout, containerName, terminatedMessage)
		if err != nil {
			return err
		}
	}

	return nil
}

/*
 * Waits for the container in the pod to restart and checks that the terminated message contains the specified message.
 * Errors if the container does not restart before the timeout.
 */
func WatchForPodRestart(K8sClient *kubernetes.Clientset, namespace, labelName, labelValue string, timeout int64, containerName, terminatedMessage string) error {
	watcher, err := K8sClient.CoreV1().Pods(namespace).Watch(context.Background(), metav1.ListOptions{
		LabelSelector:  fmt.Sprintf("%s=%s", labelName, labelValue),
		TimeoutSeconds: &timeout,
	})
	if err != nil {
		return err
	}
	defer watcher.Stop()

	for {
		select {
		case event, ok := <-watcher.ResultChan():
			if !ok {
				return fmt.Errorf("%s=%s pod did not restart before timeout", labelName, labelValue)
			}
			if event.Type != "MODIFIED" {
				continue
			}

			p, ok := event.Object.(*corev1.Pod)
			if !ok {
				return fmt.Errorf("event.Object is not of type *corev1.Pod")
			}

			for _, containerStatus := range p.Status.ContainerStatuses {
				if containerStatus.Name == containerName && containerStatus.LastTerminationState.Terminated != nil {
					if containerStatus.LastTerminationState.Terminated.Reason == "Error" &&
						(terminatedMessage == "" || strings.Contains(containerStatus.LastTerminationState.Terminated.Message, terminatedMessage)) {
						return nil
					}
				}
			}
		}
		break
	}

	return nil
}

/*
 * For all pods with the specified namespace and label value, ensure all containers within those pods have the status 'Running'.
 */
func CheckIfAllContainersAreRunning(clientset *kubernetes.Clientset, namespace, labelKey string, labelValue string) error {
	pods, err := GetPodsWithLabel(clientset, namespace, labelKey, labelValue)
	if err != nil {
		return errors.New(fmt.Sprintf("Error getting pods with the specified labels: %v", err))
	}

	for _, pod := range pods {
		if pod.Status.Phase != corev1.PodRunning {
			return errors.New(fmt.Sprintf("Pod is not runinng. Phase is: %v", pod.Status.Phase))
		}

		for _, containerStatus := range pod.Status.ContainerStatuses {
			if containerStatus.State.Running == nil {
				return errors.New(fmt.Sprintf("Container %s is not running", containerStatus.Name))
			}
		}
	}

	return nil
}

/*
 * Check that pods with the specified namespace and label value are scheduled in all the nodes. If a node has no schduled pod on it, return an error.
 * Also check that the containers are scheduled and running on those nodes.
 */
func CheckIfAllPodsScheduleOnNodes(clientset *kubernetes.Clientset, namespace, labelKey string, labelValue string, osLabel string) error {

	// Get list of all nodes
	nodes, err := clientset.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})

	if err != nil {
		return errors.New(fmt.Sprintf("Error getting nodes with the specified labels: %v", err))
	}

	for _, node := range nodes.Items {
		if node.Labels["beta.kubernetes.io/os"] == osLabel {
			// Get list of pods scheduled on this node
			pods, err := clientset.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
				FieldSelector: "spec.nodeName=" + node.Name,
				LabelSelector: labelKey + "=" + labelValue,
			})

			if err != nil || pods == nil || len(pods.Items) == 0 {
				return errors.New(fmt.Sprintf("Error getting pods on node %s:", node.Name))
			}

			for _, pod := range pods.Items {
				if pod.Status.Phase != corev1.PodRunning {
					return errors.New(fmt.Sprintf("Pod is not runinng. Phase is: %v", pod.Status.Phase))
				}

				for _, containerStatus := range pod.Status.ContainerStatuses {
					if containerStatus.State.Running == nil {
						return errors.New(fmt.Sprintf("Container %s is not running", containerStatus.Name))
					}
				}
			}
		}
	}

	return nil
}

/*
 * Check that pods with the specified namespace and label value are scheduled in all the Fips and ARM64 nodes. If a node has no schduled pod on it, return an error.
 * Also check that the containers are scheduled and running on those nodes.
 */
func CheckIfAllPodsScheduleOnSpecificNodesLabels(clientset *kubernetes.Clientset, namespace, labelKey string, labelValue string, nodeLabelKey string, nodeLabelValue string) error {

	// Get list of all nodes
	nodes, err := clientset.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})

	if err != nil {
		return errors.New(fmt.Sprintf("Error getting nodes with the specified labels: %v", err))
	}

	for _, node := range nodes.Items {
		if value, ok := node.Labels[nodeLabelKey]; ok && value == nodeLabelValue {

			// Get list of pods scheduled on this node
			pods, err := clientset.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
				FieldSelector: "spec.nodeName=" + node.Name,
				LabelSelector: labelKey + "=" + labelValue,
			})

			if err != nil || pods == nil || len(pods.Items) == 0 {
				return errors.New(fmt.Sprintf("Error getting pods on node %s:", node.Name))
			}
			for _, pod := range pods.Items {
				if pod.Status.Phase != corev1.PodRunning {
					return errors.New(fmt.Sprintf("Pod is not runinng. Phase is: %v", pod.Status.Phase))
				}

				for _, containerStatus := range pod.Status.ContainerStatuses {
					if containerStatus.State.Running == nil {
						return errors.New(fmt.Sprintf("Container %s is not running", containerStatus.Name))
					}
				}
			}
		}
	}

	return nil
}

/*
 * Update an unused field in configmap with a random value to cause a configmap update event.
 */
func GetAndUpdateConfigMap(clientset *kubernetes.Clientset, configMapName, configMapNamespace string) error {
	ctx := context.Background()

	// Get the configmap
	configMap, err := clientset.CoreV1().ConfigMaps(configMapNamespace).Get(ctx, configMapName, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("Failed to get configmap: %s", err.Error())
	}

	// Update the configmap
	configMap.Data["test_field"] = uuid.New().String()
	_, err = clientset.CoreV1().ConfigMaps(configMapNamespace).Update(ctx, configMap, metav1.UpdateOptions{})
	if err != nil {
		return fmt.Errorf("Failed to update configmap: %s", err.Error())
	}

	return nil
}
