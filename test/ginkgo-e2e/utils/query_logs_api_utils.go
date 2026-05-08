package utils

import (
	"context"
	"fmt"
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

// QueryContainerLogV2CountsByComputer queries the Log Analytics workspace for
// the number of ContainerLogV2 rows ingested per node (Computer) within the
// given time window (e.g. "5m"). Returns a map keyed by lowercased Computer
// name.
//
// ContainerLogV2 and ContainerLog are mutually exclusive — a cluster writes
// to one or the other based on its schema configuration. This helper only
// falls back to ContainerLog when the ContainerLogV2 query *errors* (e.g.
// the V2 table does not exist in a V1-configured workspace). A successful V2
// query that returns zero rows is treated as a real ingestion failure and
// surfaced as an empty map; callers must NOT interpret that as a reason to
// fall back, otherwise V2 ingestion failures would be silently masked.
func QueryContainerLogV2CountsByComputer(logsClient *azquery.LogsClient, resourceID string, window string) (map[string]int64, error) {
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

// AssertContainerLogV2NodeCoverage returns nil if every expected node appears
// in the per-Computer count map with a positive row count (compared
// case-insensitively), or an error listing the missing nodes otherwise.
func AssertContainerLogV2NodeCoverage(expectedNodes []string, observedCountsByComputer map[string]int64) error {
	if len(expectedNodes) == 0 {
		return fmt.Errorf("no expected nodes provided; cannot verify ContainerLogV2 coverage")
	}

	var missing []string
	for _, n := range expectedNodes {
		if observedCountsByComputer[strings.ToLower(n)] <= 0 {
			missing = append(missing, n)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("ContainerLogV2 ingestion is missing for %d/%d expected node(s): %s", len(missing), len(expectedNodes), strings.Join(missing, ", "))
	}
	return nil
}
