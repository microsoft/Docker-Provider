package lib

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var (
	containerCGroupCache      = map[string]string{}
	addonTokenAdapterImageTag = ""
	FLBLogger                 *log.Logger
)

func init() {
	var logPath string
	if strings.EqualFold(osType, "windows") {
		logPath = "/etc/amalogswindows/fluent-bit-input.log"
	} else {
		logPath = "/var/opt/microsoft/docker-cimprov/log/fluent-bit-input.log"
	}

	isTestEnv := os.Getenv("GOUNITTEST") == "true"
	if isTestEnv {
		logPath = "./fluent-bit-input.log"
	}

	FLBLogger = CreateLogger(logPath)
}

func GetContainerInventoryRecords(podItem map[string]interface{}, batchTime string, clusterCollectEnvironmentVar string, isWindows bool) []map[string]interface{} {
	containerInventoryRecords := make([]map[string]interface{}, 0)
	containersInfoMap := getContainersInfoMap(podItem, isWindows)
	podContainersStatuses := make([]interface{}, 0)

	if podStatus, ok := podItem["status"].(map[string]interface{}); ok {
		if containerStatuses, ok := podStatus["containerStatuses"].([]interface{}); ok {
			podContainersStatuses = append(podContainersStatuses, containerStatuses...)
		}
		if initContainerStatuses, ok := podStatus["initContainerStatuses"].([]interface{}); ok {
			podContainersStatuses = append(podContainersStatuses, initContainerStatuses...)
		}
	}

	for _, containerStatus := range podContainersStatuses {
		containerInventoryRecord := make(map[string]interface{})
		containerInventoryRecord["CollectionTime"] = batchTime
		containerStatusMap := containerStatus.(map[string]interface{})
		containerName := containerStatusMap["name"].(string)

		containerRuntime := ""
		containerID := ""
		if containerIDValue, ok := containerStatusMap["containerID"].(string); ok {
			containerRuntime = strings.Split(containerIDValue, ":")[0]
			containerID = strings.Split(containerIDValue, "//")[1]
		}
		containerInventoryRecord["InstanceID"] = containerID

		if imageIDValue, ok := containerStatusMap["imageID"].(string); ok && imageIDValue != "" {
			if atLocation := strings.Index(imageIDValue, "@"); atLocation != -1 {
				containerInventoryRecord["ImageId"] = imageIDValue[atLocation+1:]
			}
		}

		containerInventoryRecord["ExitCode"] = 0
		isContainerTerminated := false
		isContainerWaiting := false

		if containerState, ok := containerStatusMap["state"].(map[string]interface{}); ok {
			if _, ok := containerState["running"]; ok {
				containerInventoryRecord["State"] = "Running"
				containerInventoryRecord["StartedTime"] = containerState["running"].(map[string]interface{})["startedAt"]
			} else if terminatedState, ok := containerState["terminated"].(map[string]interface{}); ok {
				containerInventoryRecord["State"] = "Terminated"
				containerInventoryRecord["StartedTime"] = terminatedState["startedAt"]
				containerInventoryRecord["FinishedTime"] = terminatedState["finishedAt"]
				exitCodeValue := terminatedState["exitCode"].(float64)
				if exitCodeValue < 0 {
					exitCodeValue = 128
				}
				containerInventoryRecord["ExitCode"] = exitCodeValue
				if exitCodeValue > 0 {
					containerInventoryRecord["State"] = "Failed"
				}
				isContainerTerminated = true
			} else if _, ok := containerState["waiting"]; ok {
				containerInventoryRecord["State"] = "Waiting"
				isContainerWaiting = true
			}
		}

		restartCount := 0
		if restartCountValue, ok := containerStatusMap["restartCount"].(float64); ok {
			restartCount = int(restartCountValue)
		}

		if containerInfoMap, ok := containersInfoMap[containerName]; ok {
			if imageValue, ok := containerInfoMap["image"]; ok && imageValue != "" {
				atLocation := strings.Index(imageValue, "@")
				isDigestSpecified := false
				if atLocation != -1 {
					imageValue = imageValue[:atLocation]
					if containerInventoryRecord["ImageId"] == nil || containerInventoryRecord["ImageId"] == "" {
						containerInventoryRecord["ImageId"] = imageValue[atLocation+1:]
					}
					isDigestSpecified = true
				}
				slashLocation := strings.Index(imageValue, "/")
				colonLocation := strings.Index(imageValue, ":")
				if colonLocation != -1 {
					if slashLocation == -1 {
						containerInventoryRecord["Image"] = imageValue[:colonLocation]
					} else {
						containerInventoryRecord["Repository"] = imageValue[:slashLocation]
						containerInventoryRecord["Image"] = imageValue[slashLocation+1 : colonLocation]
					}
					containerInventoryRecord["ImageTag"] = imageValue[colonLocation+1:]
				} else {
					if slashLocation == -1 {
						containerInventoryRecord["Image"] = imageValue
					} else {
						containerInventoryRecord["Repository"] = imageValue[:slashLocation]
						containerInventoryRecord["Image"] = imageValue[slashLocation+1:]
					}
					if !isDigestSpecified {
						containerInventoryRecord["ImageTag"] = "latest"
					}
				}
			}

			podName := containerInfoMap["PodName"]
			namespace := containerInfoMap["Namespace"]
			containerNameInDockerFormat := fmt.Sprintf("k8s_%s_%s_%s_%s_%d", containerName, podName, namespace, containerID, restartCount)
			containerInventoryRecord["ElementName"] = containerNameInDockerFormat
			containerInventoryRecord["Computer"] = containerInfoMap["Computer"]
			containerInventoryRecord["ContainerHostname"] = podName
			containerInventoryRecord["CreatedTime"] = containerInfoMap["CreatedTime"]
			containerInventoryRecord["EnvironmentVar"] = containerInfoMap["EnvironmentVar"]
			containerInventoryRecord["Ports"] = containerInfoMap["Ports"]
			containerInventoryRecord["Command"] = containerInfoMap["Command"]

			if clusterCollectEnvironmentVar != "" && strings.EqualFold(clusterCollectEnvironmentVar, "false") {
				containerInventoryRecord["EnvironmentVar"] = []string{"AZMON_CLUSTER_COLLECT_ENV_VAR=FALSE"}
			} else if isWindows || isContainerTerminated || isContainerWaiting {
				containerInventoryRecord["EnvironmentVar"] = containerInfoMap["EnvironmentVar"]
			} else {
				if containerID == "" || containerRuntime == "" {
					containerInventoryRecord["EnvironmentVar"] = ""
				} else {
					if strings.EqualFold(containerRuntime, "cri-o") {
						containerInventoryRecord["EnvironmentVar"] = obtainContainerEnvironmentVars(fmt.Sprintf("crio-%s", containerID))
					} else {
						containerInventoryRecord["EnvironmentVar"] = obtainContainerEnvironmentVars(containerID)
					}
				}
			}

			containerInventoryRecords = append(containerInventoryRecords, containerInventoryRecord)
		}
	}

	return containerInventoryRecords
}

func getContainersInfoMap(podItem map[string]interface{}, isWindows bool) map[string]map[string]string {
	containersInfoMap := make(map[string]map[string]string)

	nodeName := ""
	if val, ok := podItem["spec"].(map[string]interface{})["nodeName"].(string); ok {
		nodeName = val
	}

	createdTime := podItem["metadata"].(map[string]interface{})["creationTimestamp"].(string)
	podName := podItem["metadata"].(map[string]interface{})["name"].(string)
	namespace := podItem["metadata"].(map[string]interface{})["namespace"].(string)

	if len(podItem) > 0 && podItem["spec"] != nil && len(podItem["spec"].(map[string]interface{})) > 0 {
		containersField, found := podItem["spec"].(map[string]interface{})["containers"]
		if !found {
			FLBLogger.Printf("KubernetesContainerInventory::getContainersInfoMap: containers field not found in podItem")
			return containersInfoMap
		}
		podContainers, ok := containersField.([]interface{})
		if !ok {
			return containersInfoMap
		}
		initContainersField, found := podItem["spec"].(map[string]interface{})["initContainers"]
		initContainers, ok := initContainersField.([]interface{})
		if found && ok {
			podContainers = append(podContainers, initContainers...)
		}

		if len(podContainers) > 0 {
			for _, container := range podContainers {
				containerMap, ok := container.(map[string]interface{})
				if !ok {
					continue
				}

				containerInfoMap := make(map[string]string)
				containerName := containerMap["name"].(string)
				containerInfoMap["image"] = containerMap["image"].(string)
				containerInfoMap["ElementName"] = containerName
				containerInfoMap["Computer"] = nodeName
				containerInfoMap["PodName"] = podName
				containerInfoMap["Namespace"] = namespace
				containerInfoMap["CreatedTime"] = createdTime

				portsValue := containerMap["ports"]
				portsValueString := ""
				if portsValue != nil {
					jsonStr, err := json.Marshal(portsValue)
					if err != nil {
						continue
					}
					portsValueString = string(jsonStr)
				}
				containerInfoMap["Ports"] = portsValueString

				cmdValue := containerMap["command"]
				cmdValueString := ""
				if cmdValue != nil {
					cmdValueString = fmt.Sprintf("%v", cmdValue)
				}
				containerInfoMap["Command"] = cmdValueString

				//TODO: Remove this DEAD CODE as it was only used by replica set for Windows data
				if isWindows && !IsAADMSIAuthMode() {
					// For Windows container inventory, we don't need to get envvars from the pod's response
					// since it's already taken care of in KPI as part of the pod optimized item
					containerInfoMap["EnvironmentVar"] = containerMap["env"].(string)
				} else {
					containerInfoMap["EnvironmentVar"] = obtainContainerEnvironmentVarsFromPodsResponse(podItem, containerMap)
				}

				containersInfoMap[containerName] = containerInfoMap
			}
		}
	}

	return containersInfoMap
}

func obtainContainerEnvironmentVars(containerID string) string {
	envValueString := ""
	isCGroupPidFetchRequired := false

	if _, exists := containerCGroupCache[containerID]; !exists {
		isCGroupPidFetchRequired = true
	} else {
		cGroupPid := containerCGroupCache[containerID]
		if cGroupPid == "" || !fileExists(fmt.Sprintf("/hostfs/proc/%s/environ", cGroupPid)) {
			isCGroupPidFetchRequired = true
			delete(containerCGroupCache, containerID)
		}
	}

	if isCGroupPidFetchRequired {
		cGroupPids, err := filepath.Glob("/hostfs/proc/*/cgroup")
		if err != nil {
			FLBLogger.Printf("KubernetesContainerInventory::obtainContainerEnvironmentVars: Failed to read cgroup files: %v", err)
		} else {
			for _, filename := range cGroupPids {
				cGroupPid := strings.Split(filename, "/")[3]
				pattern := regexp.MustCompile(regexp.QuoteMeta(containerID))
				if fileExists(filename) && fileContains(filename, pattern) {
					if isNumber(cGroupPid) {
						if existingCGroupPid, exists := containerCGroupCache[containerID]; exists {
							tempCGroupPid, _ := strconv.Atoi(existingCGroupPid)
							newCGroupPid, _ := strconv.Atoi(cGroupPid)
							if tempCGroupPid > newCGroupPid {
								containerCGroupCache[containerID] = cGroupPid
							}
						} else {
							containerCGroupCache[containerID] = cGroupPid
						}
					}
				}
			}
		}
	}

	cGroupPid := containerCGroupCache[containerID]
	if cGroupPid != "" {
		environFilePath := fmt.Sprintf("/hostfs/proc/%s/environ", cGroupPid)
		if fileExists(environFilePath) {
			pattern := regexp.MustCompile(`(?i)` + regexp.QuoteMeta("AZMON_COLLECT_ENV=FALSE"))
			if fileContains(environFilePath, pattern) {
				envValueString = `["AZMON_COLLECT_ENV=FALSE"]`
				FLBLogger.Printf("KubernetesContainerInventory::obtainContainerEnvironmentVars: Environment Variable collection for container: %s skipped because AZMON_COLLECT_ENV is set to false", containerID)
			} else {
				envVars, err := ioutil.ReadFile(environFilePath)
				if err != nil {
					FLBLogger.Printf("KubernetesContainerInventory::obtainContainerEnvironmentVars: Failed to read environment variables file: %v", err)
				} else {
					envVarsString := string(envVars)
					if envVarsString != "" {
						envVarsList := strings.Split(envVarsString, "\u0000")
						envValueBytes, err := json.Marshal(envVarsList)
						if err != nil {
							FLBLogger.Printf("KubernetesContainerInventory::obtainContainerEnvironmentVars: Failed to marshal environment variables: %v", err)
						}
						envValueString = string(envValueBytes)
						if len(envValueString) >= 200000 {
							lastIndex := strings.LastIndex(string(envValueString), `",`)
							if lastIndex != -1 {
								envValueStringTruncated := string(envValueString[:lastIndex]) + `]`
								envValueString = envValueStringTruncated
							}
						}
					}
				}
			}
		}
	} else {
		FLBLogger.Printf("KubernetesContainerInventory::obtainContainerEnvironmentVars: cGroupPid is NIL or empty for containerId: %s", containerID)
	}

	return envValueString
}

func obtainContainerEnvironmentVarsFromPodsResponse(pod map[string]interface{}, container map[string]interface{}) string {
	envValueString := ""

	envVars := []string{}

	envVarField, ok := container["env"]
	if !ok {
		return envValueString
	}
	envVarsJSON := envVarField.([]interface{})

	if len(pod) > 0 && envVarsJSON != nil && len(envVarsJSON) > 0 {
		for _, envVar := range envVarsJSON {
			envVarMap := envVar.(map[string]interface{})
			key := envVarMap["name"].(string)
			value := ""

			if envVarMap["value"] != nil {
				value = envVarMap["value"].(string)
			} else if envVarMap["valueFrom"] != nil {
				valueFrom := envVarMap["valueFrom"].(map[string]interface{})

				if fieldRef, ok := valueFrom["fieldRef"].(map[string]interface{}); ok && fieldRef["fieldPath"] != nil && fieldRef["fieldPath"].(string) != "" {
					fieldPath := fieldRef["fieldPath"].(string)
					fields := strings.Split(fieldPath, ".")

					if len(fields) == 2 {
						if fields[1] != "" && strings.HasSuffix(fields[1], "]") {
							indexFields := strings.Split(fields[1][:len(fields[1])-1], "[")
							hashMapValue := pod[fields[0]].(map[string]interface{})[indexFields[0]].(map[string]interface{})
							if len(hashMapValue) > 0 {
								subField := strings.Trim(indexFields[1], `'"`)
								value = hashMapValue[subField].(string)
							}
						} else {
							value = pod[fields[0]].(map[string]interface{})[fields[1]].(string)
						}
					}
				} else if resourceFieldRef, ok := valueFrom["resourceFieldRef"].(map[string]interface{}); ok && resourceFieldRef["resource"] != nil && resourceFieldRef["resource"].(string) != "" {
					resource := resourceFieldRef["resource"].(string)
					resourceFields := strings.Split(resource, ".")
					containerResources := container["resources"].(map[string]interface{})

					if len(containerResources) > 0 && len(resourceFields) == 2 {
						value = containerResources[resourceFields[0]].(map[string]interface{})[resourceFields[1]].(string)
					}
				} else if secretKeyRef, ok := valueFrom["secretKeyRef"].(map[string]interface{}); ok {
					secretName := secretKeyRef["name"].(string)
					secretKey := secretKeyRef["key"].(string)

					if secretName != "" && secretKey != "" {
						value = fmt.Sprintf("secretKeyRef_%s_%s", secretName, secretKey)
					}
				} else {
					value = fmt.Sprintf("%v", envVarMap["valueFrom"])
				}
			}

			envVars = append(envVars, fmt.Sprintf("%s=%s", key, value))
		}

		envValueString = strings.Join(envVars, ",")
		containerName := container["name"].(string)

		// Skip environment variable processing if it contains the flag AZMON_COLLECT_ENV=FALSE
		// Check to see if the environment variable collection is disabled for this container.
		if strings.Contains(envValueString, "AZMON_COLLECT_ENV=FALSE") {
			envValueString = `["AZMON_COLLECT_ENV=FALSE"]`
			fmt.Printf("Environment Variable collection for container: %s skipped because AZMON_COLLECT_ENV is set to false\n", containerName)
		} else if len(envValueString) > 200000 { // Restricting the ENV string value to 200kb since the size of this string can go very high
			envValueStringTruncated := envValueString[:200000]
			lastIndex := strings.LastIndex(envValueStringTruncated, `",`)
			if lastIndex != -1 {
				envValueString = envValueStringTruncated[:lastIndex+2] + "]"
			} else {
				envValueString = envValueStringTruncated
			}
		}
	}

	return envValueString
}

func DeleteCGroupCacheEntryForDeletedContainer(containerID string) {
	if containerID != "" && containerCGroupCache != nil && len(containerCGroupCache) > 0 {
		delete(containerCGroupCache, containerID)
	}
}

func fileExists(filePath string) bool {
	_, err := os.Stat(filePath)
	return !os.IsNotExist(err)
}

func fileContains(environFilePath string, pattern *regexp.Regexp) bool {
	file, err := os.Open(environFilePath)
	if err != nil {
		return false
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if pattern.MatchString(scanner.Text()) {
			return true
		}
	}

	if err := scanner.Err(); err != nil {
		return false
	}

	return false
}

func isNumber(value string) bool {
	_, err := strconv.Atoi(value)
	return err == nil
}

func GetContainerInventory(namespaceFilteringMode string, namespaces []string, batchTime string) ([]string, []map[string]interface{}) {
	response, err := GetPodsFromCAdvisor(nil)
	if err != nil {
		FLBLogger.Println("KubernetesContainerInventory::GetContainerInventory:getPodsFromCAdvisor failed: ", err)
		telemetryProps := make(map[string]string)
		telemetryProps["Computer"] = hostName
		SendExceptionTelemetry(err.Error(), telemetryProps)
		return nil, nil
	}

	if response == nil || response.Body == nil {
		FLBLogger.Printf("KubernetesContainerInventory::GetContainerInventory:getPodsFromCAdvisor returned nil response or body")
		return nil, nil
	}

	defer response.Body.Close()

	var podList map[string]interface{}
	bodybytes, err := io.ReadAll(response.Body)
	if err != nil {
		FLBLogger.Println("KubernetesContainerInventory::GetContainerInventory:getPodsFromCAdvisor io.ReadAll failed: ", err)
		return nil, nil
	}
	err = json.Unmarshal(bodybytes, &podList)
	if err != nil {
		FLBLogger.Println("KubernetesContainerInventory::GetContainerInventory:getPodsFromCAdvisor json.Unmarshal failed: ", err, bodybytes)
		return nil, nil
	}

	return GetContainerInventoryHelper(podList, namespaceFilteringMode, namespaces, batchTime)
}

func GetContainerInventoryHelper(podList map[string]interface{}, namespaceFilteringMode string, namespaces []string, batchTime string) ([]string, []map[string]interface{}) {
	containerIds := []string{}
	containerInventory := []map[string]interface{}{}
	clusterCollectEnvironmentVar := os.Getenv("AZMON_CLUSTER_COLLECT_ENV_VAR")
	items, ok := podList["items"].([]interface{})
	if ok && len(items) > 0 {
		for _, item := range items {
			metadata := item.(map[string]interface{})["metadata"].(map[string]interface{})
			name := metadata["name"].(string)
			namespace := metadata["namespace"].(string)

			if !IsExcludeResourceItem(name, namespace, namespaceFilteringMode, namespaces) {
				isWindows := false
				if strings.EqualFold(osType, "windows") {
					isWindows = true
				}
				containerInventoryRecords := GetContainerInventoryRecords(item.(map[string]interface{}), batchTime, clusterCollectEnvironmentVar, isWindows)

				for _, containerRecord := range containerInventoryRecords {
					WriteContainerState(containerRecord)

					computer := containerRecord["Computer"].(string)
					if hostName == "" && computer != "" {
						hostName = computer
					}

					elementName := containerRecord["ElementName"].(string)
					imageTag := containerRecord["ImageTag"].(string)
					if addonTokenAdapterImageTag == "" && IsAADMSIAuthMode() &&
						elementName != "" && strings.Contains(elementName, "_kube-system_") &&
						strings.Contains(elementName, "addon-token-adapter_ama-logs") &&
						imageTag != "" {
						addonTokenAdapterImageTag = imageTag
					}

					instanceID := containerRecord["InstanceID"].(string)
					containerIds = append(containerIds, instanceID)
					containerInventory = append(containerInventory, containerRecord)
				}
			}
		}
	}

	return containerIds, containerInventory

}
