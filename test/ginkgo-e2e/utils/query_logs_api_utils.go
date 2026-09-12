package utils

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/monitor/azquery"
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

// AgentTelemetryHeartbeatEvent is the App Insights custom event the Go output plugin emits once
// per publish interval from every DaemonSet pod. It is the signal that goes silent when the
// agent's outbound telemetry path breaks while container logs keep flowing over the local mdsd
// socket, so its arrival is asserted directly rather than inferred from the agent's own logs.
const AgentTelemetryHeartbeatEvent = "ContainerLogDaemonSetHeartbeatEvent"

// AgentTelemetryPeriodicTables are the Application Insights tables the agent writes to on a
// fixed interval, so every node running a healthy agent has to appear in all of them.
//
// `traces` is deliberately not in this list. It carries the agent's own log lines, and only
// those that are not "Information" level, so an agent with nothing to complain about emits
// none at all: in a sampled 30 minute window only 41,491 of the 107,982 clusters that reported
// a heartbeat produced a single trace. Requiring traces would therefore fail the majority of
// healthy clusters, so their arrival is reported rather than asserted.
var AgentTelemetryPeriodicTables = []string{"customEvents", "customMetrics"}

// GetAgentTelemetryVersionsByNode returns the telemetry item count for one Application Insights
// table, keyed by lowercased node name and then by the agent version that reported it. It
// queries the agent telemetry Application Insights resource rather than the cluster's
// workspace: this is agent self-telemetry and is never ingested into the customer workspace.
//
// Keeping the version in the result is what allows a caller to tell a node that is reporting
// from the image under test apart from one that is only still reporting from its predecessor.
// Pass an empty eventName for tables such as `traces` that have no name column.
func GetAgentTelemetryVersionsByNode(logsClient *azquery.LogsClient, telemetryResourceID string, aksResourceID string, window string, table string, eventName string) (map[string]map[string]int64, error) {
	nameFilter := ""
	if eventName != "" {
		nameFilter = fmt.Sprintf("\n| where name == \"%s\"", eventName)
	}

	// Resource IDs are matched case-insensitively because the agent reports both
	// /resourcegroups/ and /resourceGroups/ spellings for the same cluster.
	query := fmt.Sprintf(`%s
| where timestamp > ago(%s)%s
| extend ClusterId = iff(isnotempty(tostring(customDimensions.ID)), tostring(customDimensions.ID), tostring(customDimensions.AKS_RESOURCE_ID))
| where ClusterId =~ "%s"
| summarize count() by Computer = tostring(customDimensions.Computer), Version = tostring(customDimensions.Version)`,
		table, window, nameFilter, aksResourceID)

	tables, err := QueryLogs(logsClient, telemetryResourceID, query)
	if err != nil {
		return nil, err
	}

	counts := map[string]map[string]int64{}
	for _, t := range tables {
		for _, row := range t.Rows {
			if len(row) < 3 {
				continue
			}
			computer, ok := row[0].(string)
			if !ok || computer == "" {
				continue
			}
			version, _ := row[1].(string)
			count, _ := row[2].(float64)
			node := strings.ToLower(computer)
			if counts[node] == nil {
				counts[node] = map[string]int64{}
			}
			counts[node][version] += int64(count)
		}
	}
	return counts, nil
}

// AssertNodeVersionCoverage returns nil when every node in expectedVersionByNode reported the
// signal under the agent version that node is actually running.
//
// A node that reported nothing and a node that reported only some other version are listed
// separately, because they are different faults: the first is a node whose telemetry is not
// arriving at all, while the second is telemetry arriving from an agent that is no longer the
// one deployed, which is what a stale image or a half-finished rollout looks like.
func AssertNodeVersionCoverage(signal string, expectedVersionByNode map[string]string, observed map[string]map[string]int64) error {
	if len(expectedVersionByNode) == 0 {
		return fmt.Errorf("no expected nodes provided; cannot verify %s coverage", signal)
	}

	var missing, staleVersion []string
	for node, expectedVersion := range expectedVersionByNode {
		reported := observed[strings.ToLower(node)]
		if len(reported) == 0 {
			missing = append(missing, node)
			continue
		}
		if reported[expectedVersion] <= 0 {
			staleVersion = append(staleVersion, fmt.Sprintf("%s (expected %q, reported %s)", node, expectedVersion, strings.Join(sortedVersions(reported), ", ")))
		}
	}

	sort.Strings(missing)
	sort.Strings(staleVersion)

	var problems []string
	if len(missing) > 0 {
		problems = append(problems, fmt.Sprintf("%s is missing for %d/%d expected node(s): %s", signal, len(missing), len(expectedVersionByNode), strings.Join(missing, ", ")))
	}
	if len(staleVersion) > 0 {
		problems = append(problems, fmt.Sprintf("%s arrived for %d node(s) but not from the deployed agent version: %s", signal, len(staleVersion), strings.Join(staleVersion, "; ")))
	}
	if len(problems) > 0 {
		return errors.New(strings.Join(problems, "; "))
	}
	return nil
}

// AssertReportedNodeVersions returns nil when every node that did report the signal reported it
// under the version that node is running. Nodes that reported nothing are ignored, which makes
// it the right check for a signal whose absence is legitimate.
func AssertReportedNodeVersions(signal string, expectedVersionByNode map[string]string, observed map[string]map[string]int64) error {
	reporting := map[string]string{}
	for node, expectedVersion := range expectedVersionByNode {
		if len(observed[strings.ToLower(node)]) > 0 {
			reporting[node] = expectedVersion
		}
	}
	if len(reporting) == 0 {
		return nil
	}
	return AssertNodeVersionCoverage(signal, reporting, observed)
}

// sortedVersions returns the versions in a per-version count map in a stable order so that
// failure messages do not change between runs for the same underlying data.
func sortedVersions(counts map[string]int64) []string {
	versions := make([]string, 0, len(counts))
	for version := range counts {
		if version == "" {
			version = "<empty>"
		}
		versions = append(versions, version)
	}
	sort.Strings(versions)
	return versions
}

// TotalItems returns the number of telemetry items across every node and version in a result
// from GetAgentTelemetryVersionsByNode.
func TotalItems(observed map[string]map[string]int64) int64 {
	var total int64
	for _, byVersion := range observed {
		for _, count := range byVersion {
			total += count
		}
	}
	return total
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
