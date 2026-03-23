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

// categorizeErrors categorizes error lines into expected intermittent errors (with counts) and unexpected errors.
// Returns an error if any pattern exceeds the threshold or if there are unexpected errors.
func categorizeErrors(errorLines []string, threshold int) error {
	errorCounts := make(map[string]int)
	unexpectedErrors := []string{}

	for _, line := range errorLines {
		if line == "" {
			continue
		}

		// Check if this line matches any expected intermittent error pattern (case-insensitive)
		matchedPattern := false
		lowerLine := strings.ToLower(line)
		for _, pattern := range ExpectedIntermittentErrors {
			if strings.Contains(lowerLine, strings.ToLower(pattern)) {
				errorCounts[pattern]++
				matchedPattern = true
				break
			}
		}

		// If no pattern matched, it's an unexpected error
		if !matchedPattern {
			unexpectedErrors = append(unexpectedErrors, line)
		}
	}

	// Check if any expected error pattern exceeded the threshold
	var exceededErrors []string
	for pattern, count := range errorCounts {
		if count > threshold {
			exceededErrors = append(exceededErrors, fmt.Sprintf("'%s': %d occurrences (threshold: %d)", pattern, count, threshold))
		}
	}

	// Build error message if there are exceeded or unexpected errors
	if len(exceededErrors) > 0 || len(unexpectedErrors) > 0 {
		var errorMsg strings.Builder

		if len(exceededErrors) > 0 {
			errorMsg.WriteString("Expected errors exceeding threshold:\n")
			for _, err := range exceededErrors {
				errorMsg.WriteString("  - " + err + "\n")
			}
		}

		if len(unexpectedErrors) > 0 {
			if len(exceededErrors) > 0 {
				errorMsg.WriteString("\n")
			}
			errorMsg.WriteString("Unexpected errors:\n")
			for _, err := range unexpectedErrors {
				errorMsg.WriteString("  - " + err + "\n")
			}
		}

		return fmt.Errorf("%s", strings.TrimSuffix(errorMsg.String(), "\n"))
	}

	return nil
}

/*
 * Checks that the logs of all containers in all pods with the given label do not contain any errors.
 * Also returns an error if there are no pods that exist with the given label.
 * It tolerates intermittent errors up to 10 occurrences per pattern.
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

			// Collect error lines
			errorLines := []string{}
			for _, line := range strings.Split(logs, "\n") {
				if strings.Contains(line, "error") || strings.Contains(line, "Error") {
					errorLines = append(errorLines, line)
				}
			}

			// Categorize errors and check thresholds
			err = categorizeErrors(errorLines, IntermittentErrorThreshold)
			if err != nil {
				return fmt.Errorf("logs for container %s in pod %s:\n%v", container.Name, pod.Name, err)
			}
		}
	}
	return nil
}

/*
 * Returns the environment variables of the agent container.
 */
func GetContainerEnvVars(clientset *kubernetes.Clientset, namespace string, labelKey string, labelValue string, containerName string) (map[string]string, error) {
	pods, err := GetPodsWithLabel(clientset, namespace, labelKey, labelValue)
	if err != nil || len(pods) == 0 {
		return nil, fmt.Errorf("failed to get pods with label %s=%s: %v", labelKey, labelValue, err)
	}

	// Get the environment variables of the agent container from the first pod
	for _, container := range pods[0].Spec.Containers {
		if container.Name == containerName {
			envVars := make(map[string]string)
			for _, env := range container.Env {
				envVars[env.Name] = env.Value
			}
			return envVars, nil
		}
	}

	return nil, fmt.Errorf("container %s not found in pod %s", containerName, &pods[0].Name)
}

func GetAKSResourceID(clientset *kubernetes.Clientset, namespace string, labelKey string, labelValue string, containerName string) (string, error) {
	envVars, error := GetContainerEnvVars(clientset, namespace, labelKey, labelValue, containerName)
	if error != nil {
		return "", fmt.Errorf("failed to get environment variables for container %s in pod with label %s=%s: %v", containerName, labelKey, labelValue, error)
	}
	return envVars["AKS_RESOURCE_ID"], nil
}

func IsResourceOptimizationEnabled(clientset *kubernetes.Clientset, namespace string, labelKey string, labelValue string, containerName string) (string, error) {
	envVars, error := GetContainerEnvVars(clientset, namespace, labelKey, labelValue, containerName)
	if error != nil {
		return "", fmt.Errorf("failed to get environment variables for container %s in pod with label %s=%s: %v", containerName, labelKey, labelValue, error)
	}
	return envVars["AZMON_RESOURCE_OPTIMIZATION_ENABLED"], nil
}

func IsRetinaNetworkFlowLogsEnabled(clientset *kubernetes.Clientset, namespace string, labelKey string, labelValue string, containerName string) (string, error) {
	envVars, error := GetContainerEnvVars(clientset, namespace, labelKey, labelValue, containerName)
	if error != nil {
		return "", fmt.Errorf("failed to get environment variables for container %s in pod with label %s=%s: %v", containerName, labelKey, labelValue, error)
	}
	return envVars["ENABLE_RETINA_NETWORK_FLOW_LOGS"], nil
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
func CheckIfAllPodsScheduleOnSpecificNodesLabels(clientset *kubernetes.Clientset, namespace, contollerLabelKey string, ControllerLabelValue string, nodeLabelKey string, nodeLabelValue string) error {

	// Get list of all nodes
	nodes, err := clientset.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})

	if err != nil {
		return errors.New(fmt.Sprintf("Error getting nodes with the specified labels: %v", err))
	}

	osLabel := "kubernetes.io/os"
	osLabelValue := "linux"
	if ControllerLabelValue == "ama-logs-agent-windows" {
		osLabelValue = "windows"
	}

	for _, node := range nodes.Items {
		if value, ok := node.Labels[nodeLabelKey]; ok && value == nodeLabelValue && node.Labels[osLabel] == osLabelValue {

			// Get list of pods scheduled on this node
			pods, err := clientset.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
				FieldSelector: "spec.nodeName=" + node.Name,
				LabelSelector: contollerLabelKey + "=" + ControllerLabelValue,
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

func GetAllAgentPods(clientset *kubernetes.Clientset) ([]corev1.Pod, error) {
	podList, err := clientset.CoreV1().Pods("").List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	if podList == nil || len(podList.Items) == 0 {
		return nil, fmt.Errorf("no pods found")
	}

	return podList.Items, nil
}

func GetAllNodes(clientset *kubernetes.Clientset) ([]corev1.Node, error) {
	nodes, err := clientset.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	if nodes == nil || len(nodes.Items) == 0 {
		return nil, fmt.Errorf("no nodes found")
	}

	return nodes.Items, nil
}

// CheckFileForErrors checks if a specific file in a linux container contains errors.
// It tolerates intermittent errors up to 10 occurrences per pattern.
func CheckFileForErrors(clientset *kubernetes.Clientset, Cfg *rest.Config, namespace, labelName, labelValue, containerName, filePath string) error {
	pods, err := GetPodsWithLabel(clientset, namespace, labelName, labelValue)
	if err != nil {
		return fmt.Errorf("failed to get pods with label %s=%s: %v", labelName, labelValue, err)
	}

	for _, pod := range pods {
		command := []string{"bash", "-c", fmt.Sprintf("grep -i error %s", filePath)}
		stdout, stderr, err := ExecCmd(clientset, Cfg, pod.Name, containerName, namespace, command)
		if err != nil {
			// If grep returns exit code 1, it means no matches were found, which is not an error for our use case
			if strings.Contains(err.Error(), "exit code 1") {
				// No errors found in the file, continue
				continue
			}
			return fmt.Errorf("error executing command in pod %s, container %s: %v, stderr: %s", pod.Name, containerName, err, stderr)
		}

		if stdout != "" {
			// Parse the stdout and categorize errors
			lines := strings.Split(stdout, "\n")
			err = categorizeErrors(lines, IntermittentErrorThreshold)
			if err != nil {
				return fmt.Errorf("in file %s in pod %s, container %s:\n%v", filePath, pod.Name, containerName, err)
			}
		}
	}

	return nil
}
