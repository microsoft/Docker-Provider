package utils

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/monitor/azquery"
	"github.com/distribution/reference"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/client-go/kubernetes"
)

func SetupLogsClient() (*azquery.LogsClient, error) {
	// Create a new LogsClient
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create a new LogsClient: %v", err)
	}
	client, err := azquery.NewLogsClient(cred, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create a new LogsClient: %v", err)
	}
	return client, nil
}

func QueryLogs(logsClient *azquery.LogsClient, resourceID string, query string) ([]*azquery.Table, error) {
	res, err := logsClient.QueryResource(
		context.TODO(),
		resourceID,
		azquery.Body{Query: to.Ptr(query)},
		nil)
	if err != nil {
		return nil, fmt.Errorf("Failed to query logs: %v", err)
	}
	if res.Error != nil {
		return nil, fmt.Errorf("The query returned the error: %v", *&res.Error)
	}

	return res.Tables, nil
}

func QueryLogsForCount(logsClient *azquery.LogsClient, resourceID string, query string, expectZeroCount bool) error {
	tables, err := QueryLogs(logsClient, resourceID, query)
	if err != nil {
		return err
	}

	if tables == nil || len(tables) == 0 {
		return fmt.Errorf("The query returned 0 tables")
	}

	fmt.Println("Query result of query: ", query)

	for _, table := range tables {
		fmt.Println("Number of rows: ", len(table.Rows))
		if table.Rows == nil || len(table.Rows) == 0 {
			return fmt.Errorf("The query returned 0 rows")
		}

		if len(table.Rows) > 1 {
			return fmt.Errorf("The query returned more than 1 row, this test is only used for summarize count queries")
		}

		fmt.Println("Count: ", table.Rows[0][0])

		if table.Rows[0][0].(float64) == 0 {
			if expectZeroCount {
				return nil
			}
			return fmt.Errorf("The query returned 0 count")
		}

		if table.Rows[0][0].(float64) > 0 {
			if !expectZeroCount {
				return nil
			}
			return fmt.Errorf("The query returned count greater than 0")
		}
	}

	return fmt.Errorf("The query returned unexpected result")
}

func CompareContainerInventoryImageTags(k8sClient *kubernetes.Clientset, logsClient *azquery.LogsClient, resourceID string) error {
	query := `ContainerInventory
| where TimeGenerated > ago(5m) and (ContainerState !~ 'Waiting' or ContainerHostname contains 'ama-logs')
| distinct ContainerID, ContainerHostname, ImageTag`
	tables, err := QueryLogs(logsClient, resourceID, query)
	if err != nil {
		return err
	}
	pods, err := GetAllAgentPods(k8sClient)
	if err != nil {
		return err
	}
	return validateContainerInventoryImageTags(pods, tables)
}

type containerImageReference struct {
	image string
	tag   string
}

func containerImageReferences(pods []corev1.Pod) (map[string]containerImageReference, error) {
	images := make(map[string]containerImageReference)
	for _, pod := range pods {
		specs := make(map[string]string)
		for _, containers := range [][]corev1.Container{pod.Spec.Containers, pod.Spec.InitContainers} {
			for _, container := range containers {
				specs[container.Name] = container.Image
			}
		}
		for _, statuses := range [][]corev1.ContainerStatus{pod.Status.ContainerStatuses, pod.Status.InitContainerStatuses} {
			for _, status := range statuses {
				if status.ContainerID == "" {
					continue
				}
				runtime, id, ok := strings.Cut(status.ContainerID, "://")
				if !ok || runtime == "" || id == "" {
					return nil, fmt.Errorf("invalid container ID %q for %s/%s/%s", status.ContainerID, pod.Namespace, pod.Name, status.Name)
				}
				image := specs[status.Name]
				named, err := reference.ParseNormalizedNamed(image)
				if err != nil {
					return nil, fmt.Errorf("invalid image reference for %s/%s/%s: %w", pod.Namespace, pod.Name, status.Name, err)
				}
				expected := containerImageReference{image: image}
				if tagged, ok := named.(reference.Tagged); ok {
					expected.tag = tagged.Tag()
				} else if _, digested := named.(reference.Digested); !digested {
					expected.tag = "latest"
				}
				images[id] = expected
			}
		}
	}
	if len(images) == 0 {
		return nil, fmt.Errorf("no Kubernetes container image references found")
	}
	return images, nil
}

func validateContainerInventoryImageTags(pods []corev1.Pod, tables []*azquery.Table) error {
	images, err := containerImageReferences(pods)
	if err != nil {
		return err
	}
	rows := 0
	var failures []string
	for _, table := range tables {
		if table == nil {
			return fmt.Errorf("ContainerInventory returned a nil table")
		}
		for _, row := range table.Rows {
			rows++
			if len(row) != 3 {
				return fmt.Errorf("expected ContainerID, ContainerHostname and ImageTag, got %d columns", len(row))
			}
			id, idOK := row[0].(string)
			pod, podOK := row[1].(string)
			tag, tagOK := row[2].(string)
			if !idOK || !podOK || (!tagOK && row[2] != nil) {
				return fmt.Errorf("unexpected ContainerInventory image-tag row: %v", row)
			}
			expected, found := images[id]
			if !found {
				// Old container records may outlive their pods. Only a matched original
				// image reference can justify an empty tag; ImageID alone cannot.
				if tag == "" {
					failures = append(failures, fmt.Sprintf("pod %s container %s has an empty ImageTag with no matching Kubernetes image reference", pod, id))
				}
				continue
			}
			if expected.tag != "" && tag != expected.tag {
				failures = append(failures, fmt.Sprintf("pod %s container %s image %q: expected ImageTag %q, got %q", pod, id, expected.image, expected.tag, tag))
			}
		}
	}
	if rows == 0 {
		return fmt.Errorf("ContainerInventory returned no image-tag records")
	}
	if len(failures) > 0 {
		return fmt.Errorf("ContainerInventory image-tag validation failed:\n%s", strings.Join(failures, "\n"))
	}
	return nil
}

func BuildAgentTelemetryQuery(source, resourceID, version, deploymentStart string, now time.Time) (string, error) {
	if resourceID == "" || version == "" {
		return "", fmt.Errorf("agent telemetry requires a cluster resource ID and expected version")
	}
	start, err := time.Parse(time.RFC3339, deploymentStart)
	if err != nil {
		return "", fmt.Errorf("AGENT_DEPLOYMENT_START_TIME must be the RFC3339 timestamp recorded before deployment: %w", err)
	}
	if start.IsZero() || start.After(now) {
		return "", fmt.Errorf("AGENT_DEPLOYMENT_START_TIME must be nonzero and not in the future")
	}
	window := "timestamp > ago(30m)"
	switch source {
	case "traces":
		window = fmt.Sprintf("timestamp between (datetime(%s) .. datetime(%s))", start.UTC().Format(time.RFC3339Nano), now.UTC().Format(time.RFC3339Nano))
	case "customMetrics":
	case "heartbeat":
		source = `customEvents | where name == "ContainerLogDaemonSetHeartbeatEvent"`
	default:
		return "", fmt.Errorf("unsupported agent telemetry source %q", source)
	}
	return fmt.Sprintf(`%s
| where %s
| extend ClusterId = iff(isnotempty(tostring(customDimensions.ID)), tostring(customDimensions.ID), tostring(customDimensions.AKS_RESOURCE_ID))
| where ClusterId =~ %q
| where tostring(customDimensions.Version) in (%q, %q)
| distinct Computer = tolower(tostring(customDimensions.Computer))`, source, window, resourceID, version, "win-"+version), nil
}

func CompareResourcesHelper(logsClient *azquery.LogsClient, resourceID string, query string, resources []string) error {
	tables, err := QueryLogs(logsClient, resourceID, query)
	if err != nil {
		return err
	}

	if tables == nil || len(tables) == 0 {
		return fmt.Errorf("The query returned 0 tables")
	}

	fmt.Println("Compare resources result:")
	for _, table := range tables {
		// check if the resource exists in the logs
		for _, resource := range resources {
			fmt.Println("Checking resource: ", resource)
			found := false
			for _, row := range table.Rows {
				for _, cell := range row {
					if cell == resource {
						found = true
						break
					}
				}
				if found {
					break
				}
			}
			if !found {
				return fmt.Errorf("Resource %s not found in logs", resource)
			}
		}

		// if all resources found, return nil
		return nil
	}

	return fmt.Errorf("The query returned unexpected result")
}

func CompareResourcesInLogsAndKubeAPI(K8sClient *kubernetes.Clientset, logsClient *azquery.LogsClient, resourceID string, logsTable string) error {
	var resources []string
	var query string
	if logsTable == "KubeNodeInventory" {
		nodes, err := GetAllNodes(K8sClient)
		if err != nil {
			return err
		}
		for _, node := range nodes {
			resources = append(resources, node.Name)
		}
		query = logsTable + " | where TimeGenerated > ago(5m) | distinct Computer"
	} else if logsTable == "KubePodInventory" {
		pods, err := GetAllAgentPods(K8sClient)
		if err != nil {
			return err
		}
		for _, pod := range pods {
			// skip the testkube namespace as it creates runtime pods for the triggered test which might not be present in the logs
			if pod.Namespace == "testkube" {
				continue
			}
			resources = append(resources, pod.Name)
		}
		query = logsTable + " | where TimeGenerated > ago(5m) | distinct Name"
	}

	return CompareResourcesHelper(logsClient, resourceID, query, resources)
}

func GetComputerFromContainerLog(logsClient *azquery.LogsClient, resourceID string, window string) (map[string]int64, error) {
	counts, v2Err := queryCountsByComputer(logsClient, resourceID, "ContainerLogV2", window)
	if v2Err == nil {
		return counts, nil
	}

	fallback, fbErr := queryCountsByComputer(logsClient, resourceID, "ContainerLog", window)
	if fbErr != nil {
		return nil, fmt.Errorf("ContainerLogV2 query failed: %v; ContainerLog fallback failed: %v", v2Err, fbErr)
	}
	return fallback, nil
}

func queryCountsByComputer(logsClient *azquery.LogsClient, resourceID string, table string, window string) (map[string]int64, error) {
	query := fmt.Sprintf("%s | where TimeGenerated > ago(%s) | summarize count() by Computer", table, window)
	tables, err := QueryLogs(logsClient, resourceID, query)
	if err != nil {
		return nil, err
	}

	counts := map[string]int64{}
	for _, t := range tables {
		for _, row := range t.Rows {
			if len(row) < 2 {
				continue
			}
			computer, ok := row[0].(string)
			if !ok || computer == "" {
				continue
			}
			count, _ := row[1].(float64)
			counts[strings.ToLower(computer)] += int64(count)
		}
	}
	return counts, nil
}

// AssertNodeCoverage returns nil if every expected node appears in the per-Computer count map
// with a positive count (compared case-insensitively), or an error listing the missing nodes.
func AssertNodeCoverage(signal string, expectedNodes []string, observedCountsByComputer map[string]int64) error {
	if len(expectedNodes) == 0 {
		return fmt.Errorf("no expected nodes provided; cannot verify %s coverage", signal)
	}

	var missing []string
	for _, n := range expectedNodes {
		if observedCountsByComputer[strings.ToLower(n)] <= 0 {
			missing = append(missing, n)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("%s is missing for %d/%d expected node(s): %s", signal, len(missing), len(expectedNodes), strings.Join(missing, ", "))
	}
	return nil
}

// AssertContainerLogNodeCoverage returns nil if every expected node appears
// in the per-Computer count map with a positive row count (compared
// case-insensitively), or an error listing the missing nodes otherwise.
func AssertContainerLogNodeCoverage(expectedNodes []string, observedCountsByComputer map[string]int64) error {
	return AssertNodeCoverage("ContainerLogV2", expectedNodes, observedCountsByComputer)
}
