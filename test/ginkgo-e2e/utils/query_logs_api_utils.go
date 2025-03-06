package utils

import (
	"context"
	"fmt"

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
		azquery.Body{
			Query: to.Ptr(query),
		},
		nil)
	if err != nil {
		return nil, fmt.Errorf("Failed to query logs: %v", err)
	}
	if res.Error != nil {
		return nil, fmt.Errorf("The query returned the error: %v", *&res.Error)
	}

	return res.Tables, nil
}

// Print Rows
// for _, table := range res.Tables {
// 	// column, err := table.Columns[0].MarshalJSON()
// 	// if err != nil {
// 	// 	return fmt.Errorf("failed to marshal table: %v", err)
// 	// }
// 	for _, row := range table.Rows {
// 		for index, cell := range row {
// 			fmt.Print(*table.Columns[index].Name + ":" + fmt.Sprintf("%v", cell) + "\t")
// 		}
// 	}
// }

func QueryLogsForCount(logsClient *azquery.LogsClient, resourceID string, query string, expectZeroCount bool) error {
	tables, err := QueryLogs(logsClient, resourceID, query)
	if err != nil {
		return err
	}

	if tables == nil || len(tables) == 0 {
		return fmt.Errorf("The query returned 0 tables")
	}

	fmt.Println("Query result:")

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

func ComparePodsInLogsAndKubeAPI(K8sClient *kubernetes.Clientset, logsClient *azquery.LogsClient, resourceID string, logsTable string) error {
	// Get the resource list from the kube API
	pods, err := getAllAgentPods(K8sClient)

	// Query the logs for the table
	query := logsTable + " | where TimeGenerated > ago(15m) | where ContainerName contains \"ama-logs\" | distinct Name"
	tables, err := QueryLogs(logsClient, resourceID, query)
	if err != nil {
		return err
	}

	if tables == nil || len(tables) == 0 {
		return fmt.Errorf("The query returned 0 tables")
	}

	fmt.Println("Query result:")
	for _, table := range tables {
		// check if the pod exists in the logs
		for _, pod := range pods {
			fmt.Println("Checking pod: ", pod.Name)
			found := false
			for _, row := range table.Rows {
				for _, cell := range row {
					if cell == pod.Name {
						found = true
						break
					}
				}
				if found {
					break
				}
			}
			if !found {
				return fmt.Errorf("Pod %s not found in logs", pod.Name)
			}
		}

		// if all pods found, return nil
		return nil
	}

	return fmt.Errorf("The query returned unexpected result")
}
