package utils

import (
	"context"
	"fmt"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/monitor/azquery"
)

func CreateLogsClient() (*azquery.LogsClient, error) {
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

func Querylogs(resourceID string, query string) error {
	// Query logs
	logsClient, err := CreateLogsClient()
	if err != nil {
		return fmt.Errorf("failed to create a new LogsClient: %v", err)
	}
	res, err := logsClient.QueryResource(
		context.TODO(),
		resourceID,
		azquery.Body{
			Query: to.Ptr(query),
		},
		nil)
	if err != nil {
		//TODO: handle error
	}
	if res.Error != nil {
		//TODO: handle partial error
	}

	fmt.Println("Query Results:")

	// Print Rows
	for _, table := range res.Tables {
		// column, err := table.Columns[0].MarshalJSON()
		// if err != nil {
		// 	return fmt.Errorf("failed to marshal table: %v", err)
		// }
		for _, row := range table.Rows {
			for index, cell := range row {
				fmt.Print(*table.Columns[index].Name + ":" + fmt.Sprintf("%v", cell) + "\t")
			}
		}
	}
	return nil
}
