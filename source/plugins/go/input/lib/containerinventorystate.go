package lib

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"regexp"
	"strings"
)

type Container map[string]interface{}

var containerIDPattern = regexp.MustCompile(`^[a-zA-Z0-9_.+-]+$`)
var reservedContainerIDPattern = regexp.MustCompile(`(?i)^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)`)

func isValidContainerID(containerID string) bool {
	return len(containerID) > 0 && len(containerID) <= 255 &&
		containerIDPattern.MatchString(containerID) && !strings.HasSuffix(containerID, ".") &&
		!reservedContainerIDPattern.MatchString(containerID)
}

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
	value := container["InstanceID"]
	if value == nil || value == "" {
		return
	}
	containerId, ok := value.(string)
	if !ok || !isValidContainerID(containerId) {
		FLBLogger.Println("Invalid container ID in WriteContainerState; skipping state write")
		return
	}
	containerBytes, err := json.Marshal(container)
	if err != nil {
		FLBLogger.Printf("Exception serializing container state: %v\n", err)
		return
	}
	root, err := os.OpenRoot(getInventoryDirectory())
	if err != nil {
		FLBLogger.Printf("Exception opening inventory directory: %v\n", err)
		return
	}
	defer root.Close()
	file, err := openContainerStateFile(root, containerId, os.O_WRONLY|os.O_CREATE|os.O_TRUNC)
	if err != nil {
		FLBLogger.Printf("Exception opening container state: %v\n", err)
		return
	}
	defer file.Close()
	if _, err = file.Write(containerBytes); err != nil {
		FLBLogger.Printf("Exception in WriteContainerState: %v\n", err)
	}
}

func openContainerStateFile(root *os.Root, containerID string, flag int) (*os.File, error) {
	info, err := root.Lstat(containerID)
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	if err == nil && !info.Mode().IsRegular() {
		return nil, fmt.Errorf("container state is not a regular file")
	}
	// Root also confines file opens if a directory entry changes after Lstat.
	return root.OpenFile(containerID, flag, 0666)
}

// ReadContainerState reads the container state for the deleted container
func ReadContainerState(containerId string) (containerObject Container) {
	if !isValidContainerID(containerId) {
		FLBLogger.Println("Invalid container ID in ReadContainerState; skipping state read")
		return
	}
	root, err := os.OpenRoot(getInventoryDirectory())
	if err != nil {
		FLBLogger.Printf("Exception opening inventory directory: %v\n", err)
		return
	}
	defer root.Close()
	file, err := openContainerStateFile(root, containerId, os.O_RDONLY)
	if err != nil {
		FLBLogger.Printf("Exception opening container state: %v\n", err)
		return
	}
	defer file.Close()

	fileContents, err := ioutil.ReadAll(file)
	if err != nil {
		FLBLogger.Printf("Exception reading container state: %v\n", err)
		return
	}
	if err = json.Unmarshal(fileContents, &containerObject); err != nil {
		FLBLogger.Printf("Exception decoding container state: %v\n", err)
		return nil
	}
	if err = root.Remove(containerId); err != nil {
		FLBLogger.Printf("Exception deleting container state: %v\n", err)
	}

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
		if !file.Mode().IsRegular() || !isValidContainerID(file.Name()) {
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
