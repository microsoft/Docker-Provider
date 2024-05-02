package lib

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"path/filepath"
)

type Container map[string]interface{}

func getInventoryDirectory() string {
	osType := os.Getenv("OS_TYPE")
	isTestEnv := os.Getenv("GOUNITTEST") == "true"
	if isTestEnv {
		return os.Getenv("TESTDIR")
	}
	if osType == "windows" {
		return "/opt/amalogswindows/state/ContainerInventory/"
	} else {
		return "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"
	}
}

// WriteContainerState writes the container information to disk with the data that is obtained from the current plugin execution
func WriteContainerState(container Container) {
	containerId := container["InstanceID"].(string)
	if containerId != "" {
		file, err := os.Create(filepath.Join(getInventoryDirectory(), containerId))
		if err != nil {
			FLBLogger.Printf("Exception while opening file with id: %v\n", containerId)
			return
		}
		defer file.Close()

		containerBytes, _ := json.Marshal(container)
		_, err = file.Write(containerBytes)
		if err != nil {
			FLBLogger.Printf("Exception in WriteContainerState: %v\n", err)
		}
	}
}

// ReadContainerState reads the container state for the deleted container
func ReadContainerState(containerId string) (containerObject Container) {
	filepath := filepath.Join(getInventoryDirectory(), containerId)
	file, err := os.Open(filepath)
	if err != nil {
		FLBLogger.Printf("Open file for container with id returned nil: %v\n", containerId)
		return
	}
	defer file.Close()

	fileContents, _ := ioutil.ReadAll(file)
	_ = json.Unmarshal(fileContents, &containerObject)

	_ = os.Remove(filepath)

	return
}

// GetDeletedContainers gets the containers that were written to the disk with the previous plugin invocation but do not exist in the current container list
func GetDeletedContainers(containerIds []string) (deletedContainers []string) {
	files, err := ioutil.ReadDir(getInventoryDirectory())
	if err != nil {
		FLBLogger.Printf("Exception in GetDeletedContainers: %v\n", err)
		return
	}

	for _, file := range files {
		if file.IsDir() {
			continue
		}
		filename := file.Name()
		found := false
		for _, id := range containerIds {
			if filename == id {
				found = true
				break
			}
		}
		if !found {
			deletedContainers = append(deletedContainers, filename)
		}
	}

	return
}
