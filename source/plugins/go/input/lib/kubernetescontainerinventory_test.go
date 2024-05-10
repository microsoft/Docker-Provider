package lib

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"testing"
)

func Test_GetContainerInventoryHelper(t *testing.T) {
	inventoryDirectory = "./tempData/"
	err := os.MkdirAll(inventoryDirectory, 0755)
	if err != nil {
		panic(err)
	}
	defer func() {
		err = os.RemoveAll(inventoryDirectory)
		inventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"
		if err != nil {
			panic(err)
		}
	}()
	podList := map[string]interface{}{}
	jsonData, err := ioutil.ReadFile("testdata/pods1.json")
	if err != nil {
		t.Fatalf("Failed to read pods1.json file: %v", err)
	}
	err = json.Unmarshal(jsonData, &podList)
	if err != nil {
		t.Fatalf("Failed to read pods1.json file: %v", err)
	}

	containerIds, containerInventory := GetContainerInventoryHelper(podList, "", nil, "")
	if containerIds == nil || containerInventory == nil {
		t.Fatalf("Failed to get dataItems")
	}

	jsonData, err = ioutil.ReadFile("testdata/pods2.json")
	if err != nil {
		t.Fatalf("Failed to read pods2.json file: %v", err)
	}
	err = json.Unmarshal(jsonData, &podList)
	if err != nil {
		t.Fatalf("Failed to read pods2.json file: %v", err)
	}
	containerIds, containerInventory = GetContainerInventoryHelper(podList, "", nil, "")
	if containerIds == nil || containerInventory == nil {
		t.Fatalf("Failed to get dataItems")
	}
}
