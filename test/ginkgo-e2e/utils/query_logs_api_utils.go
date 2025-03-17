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
		query = logsTable + " | where TimeGenerated > ago(15m) | distinct Computer"
	} else if logsTable == "KubePodInventory" {
		pods, err := GetAllAgentPods(K8sClient)
		if err != nil {
			return err
		}
		for _, pod := range pods {
			resources = append(resources, pod.Name)
		}
		query = logsTable + " | where TimeGenerated > ago(15m) | distinct Name"
	}

	return CompareResourcesHelper(logsClient, resourceID, query, resources)
}
