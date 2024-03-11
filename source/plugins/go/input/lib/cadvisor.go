package lib

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"math"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

const (
	CADVISOR_SECURE_PORT     = "10250"
	CADVISOR_NON_SECURE_PORT = "10255"
	CA_CERT_PATH             = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
	BEARER_TOKEN_FILE        = "/var/run/secrets/kubernetes.io/serviceaccount/token"
)

// Constants for metric keys
const (
	MEMORY_WORKING_SET_BYTES               = "memoryWorkingSetBytes"
	CPU_USAGE_NANO_CORES                   = "cpuUsageNanoCores"
	MEMORY_RSS_BYTES                       = "memoryRSSBytes"
	OBJECT_NAME_K8S_NODE                   = "K8SNode"
	OBJECT_NAME_K8S_CONTAINER              = "K8SContainer"
	PV_USED_BYTES                          = "pvUsedBytes"
	TELEMETRY_FLUSH_INTERVAL_IN_MINUTES    = 10
	configMapMountPath                     = "/etc/config/settings/log-data-collection-settings"
	promConfigMountPath                    = "/etc/config/settings/prometheus-data-collection-settings"
	INSIGHTSMETRICS_TAGS_ORIGIN            = "container.azm.ms"
	INSIGHTSMETRICS_TAGS_CLUSTERID         = "container.azm.ms/clusterId"
	INSIGHTSMETRICS_TAGS_CLUSTERNAME       = "container.azm.ms/clusterName"
	INSIGHTSMETRICS_TAGS_CONTAINER_NAME    = "containerName"
	INSIGHTSMETRICS_TAGS_GPU_NAMESPACE     = "container.azm.ms/gpu"
	INSIGHTSMETRICS_TAGS_GPU_VENDOR        = "gpuVendor"
	INSIGHTSMETRICS_TAGS_GPU_MODEL         = "gpuModel"
	INSIGHTSMETRICS_TAGS_GPU_ID            = "gpuId"
	INSIGHTSMETRICS_TAGS_PV_NAMESPACE      = "container.azm.ms/pv"
	INSIGHTSMETRICS_TAGS_PVC_NAME          = "pvcName"
	INSIGHTSMETRICS_TAGS_PVC_NAMESPACE     = "pvcNamespace"
	INSIGHTSMETRICS_TAGS_POD_NAME          = "podName"
	INSIGHTSMETRICS_TAGS_PV_CAPACITY_BYTES = "pvCapacityBytes"
	INSIGHTSMETRICS_TAGS_VOLUME_NAME       = "volumeName"
	INSIGHTSMETRICS_FLUENT_TAG             = "oms.api.InsightsMetrics"
	INSIGHTSMETRICS_TAGS_POD_UID           = "podUid"
	PV_KUBE_SYSTEM_METRICS_ENABLED_EVENT   = "CollectPVKubeSystemMetricsEnabled"
)

var (
	telemetryCpuMetricTimeTracker           = time.Now().Unix()
	telemetryMemoryMetricTimeTracker        = time.Now().Unix()
	telemetryPVKubeSystemMetricsTimeTracker = time.Now().Unix()
	nodeTelemetryTimeTracker                = map[string]interface{}{}
	operatingSystem                         string
	nodeCpuUsageNanoSecondsLast             float64
	nodeCpuUsageNanoSecondsTimeLast         string
	linuxNodePrevMetricRate                 float64
	winNodePrevMetricRate                   = map[string]float64{}
	winNodeCpuUsageNanoSecondsLast          = map[string]float64{}
	winNodeCpuUsageNanoSecondsTimeLast      = map[string]interface{}{}
	winContainerIdCache                     = map[string]bool{}
	winContainerCpuUsageNanoSecondsLast     = make(map[string]float64)
	winContainerCpuUsageNanoSecondsTimeLast = make(map[string]time.Time)
	winContainerPrevMetricRate              = make(map[string]float64)
	Log                                     *logrus.Logger
	osType                                  string
)

func init() {
	Log = logrus.New()

	osType = os.Getenv("OS_TYPE")
	if osType != "" && osType == "windows" {
		LogPath = WindowsLogPath + "kubernetes_perf_log.txt"
	} else {
		LogPath = LinuxLogPath + "kubernetes_perf_log.txt"
	}

	isTestEnv := os.Getenv("ISTEST") == "true"
	if isTestEnv {
		LogPath = "./kubernetes_perf_log.txt"
	}

	// Open file
	file, err := os.OpenFile(LogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		Log.Fatalf("Failed to open log file: %v", err)
	}

	Log.SetOutput(file)
	Log.SetLevel(logrus.InfoLevel)
}

type metricDataItem map[string]interface{}

func getSummaryStatsFromCAdvisor(winNode map[string]string) (*http.Response, error) {
	relativeUri := "/stats/summary"
	return getResponse(winNode, relativeUri)
}

func GetPodsFromCAdvisor(winNode map[string]string) (*http.Response, error) {
	relativeUri := "/pods"
	return getResponse(winNode, relativeUri)
}

func getBaseCAdvisorUrl(winNode map[string]string) string {
	cAdvisorSecurePort := isCAdvisorOnSecurePort()

	var defaultHost string
	if cAdvisorSecurePort {
		defaultHost = fmt.Sprintf("https://localhost:%s", CADVISOR_SECURE_PORT)
	} else {
		defaultHost = fmt.Sprintf("http://localhost:%s", CADVISOR_NON_SECURE_PORT)
	}

	var nodeIP string
	if winNode != nil {
		nodeIP = winNode["InternalIP"]
	} else {
		nodeIP = os.Getenv("NODE_IP")
	}

	if nodeIP != "" {
		Log.Infof("Using %s for CAdvisor Host", nodeIP)
		if cAdvisorSecurePort {
			return fmt.Sprintf("https://%s:%s", nodeIP, CADVISOR_SECURE_PORT)
		} else {
			return fmt.Sprintf("http://%s:%s", nodeIP, CADVISOR_NON_SECURE_PORT)
		}
	} else {
		Log.Warnf("NODE_IP environment variable not set. Using default as: %s", defaultHost)
		if winNode != nil {
			return ""
		} else {
			return defaultHost
		}
	}
}

func getCAdvisorUri(winNode map[string]string, relativeUri string) string {
	baseCAdvisorUrl := getBaseCAdvisorUrl(winNode)
	if baseCAdvisorUrl == "" {
		return ""
	}
	return fmt.Sprintf("%s%s", baseCAdvisorUrl, relativeUri)
}

func isCAdvisorOnSecurePort() bool {
	cAdvisorSecurePort := false
	if os.Getenv("IS_SECURE_CADVISOR_PORT") == "true" {
		cAdvisorSecurePort = true
	}
	return cAdvisorSecurePort
}

func getResponse(winNode map[string]string, relativeUri string) (*http.Response, error) {
	var response *http.Response
	Log.Infof("Getting CAdvisor Uri Response")
	bearerToken, _ := ioutil.ReadFile(BEARER_TOKEN_FILE)

	cAdvisorUri := getCAdvisorUri(winNode, relativeUri)
	Log.Infof("CAdvisor Uri: %s", cAdvisorUri)

	if cAdvisorUri != "" {
		uri, err := url.Parse(cAdvisorUri)
		if err != nil {
			Log.Errorf("Failed to parse CAdvisor Uri: %s", err)
			return nil, err
		}

		var httpClient *http.Client
		if isCAdvisorOnSecurePort() {
			caCert, err := ioutil.ReadFile(CA_CERT_PATH)
			if err != nil {
				Log.Errorf("Failed to read CA cert: %s", err)
				return nil, err
			}

			caCertPool := x509.NewCertPool()
			caCertPool.AppendCertsFromPEM(caCert)

			httpClient = &http.Client{
				Transport: &http.Transport{
					Proxy: http.ProxyFromEnvironment,
					DialContext: (&net.Dialer{
						Timeout: 20 * time.Second,
					}).DialContext,
					TLSHandshakeTimeout:   20 * time.Second,
					ExpectContinueTimeout: 1 * time.Second,
					TLSClientConfig: &tls.Config{
						RootCAs:            caCertPool,
						InsecureSkipVerify: true,
					},
				},
				Timeout: 40 * time.Second,
			}
		} else {
			httpClient = &http.Client{
				Timeout: 40 * time.Second,
			}
		}

		req, err := http.NewRequest("GET", uri.String(), nil)
		if err != nil {
			Log.Errorf("Failed to create HTTP request: %s", err)
			return nil, err
		}
		req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", bearerToken))
		response, err = httpClient.Do(req)
		if err != nil {
			Log.Errorf("Failed to get HTTP response: %s", err)
			return nil, err
		}
		// defer response.Body.Close()

		Log.Infof("Got response code %d from %s", response.StatusCode, uri.RequestURI())
	}

	return response, nil
}

func GetMetrics(winNode map[string]string, namespaceFilteringMode string, namespaces []string, metricTime string) []metricDataItem {
	cAdvisorStats, err := getSummaryStatsFromCAdvisor(winNode)

	if err != nil {
		Log.Errorf("Failed to get summary stats from cadvisor: %s", err)
		telemetryProps := make(map[string]string)
		telemetryProps["Computer"] = hostName
		SendExceptionTelemetry(err.Error(), telemetryProps)
	} else {
		defer cAdvisorStats.Body.Close()
	}

	var metricInfo map[string]interface{}
	if cAdvisorStats != nil {
		bodybytes, err := io.ReadAll(cAdvisorStats.Body)
		if err != nil {
			Log.Errorf("Error reading cAdvisorStats: %s", err)
		}
		err = json.Unmarshal(bodybytes, &metricInfo)
		if err != nil {
			Log.Errorf("Error parsing cAdvisorStats: %s", err)
		}
	}

	return GetMetricsHelper(metricInfo, winNode, namespaceFilteringMode, namespaces, metricTime)
}

func GetMetricsHelper(metricInfo map[string]interface{}, winNode map[string]string, namespaceFilteringMode string, namespaces []string, metricTime string) []metricDataItem {
	var metricDataItems []metricDataItem
	if winNode != nil {
		hostName = winNode["Hostname"]
		operatingSystem = "Windows"
	} else {
		if metricInfo != nil {
			nodeName, found := metricInfo["node"].(map[string]interface{})["nodeName"].(string)
			if found {
				hostName = nodeName
			} else {
				hostName = GetHostname()
			}
		} else {
			hostName = GetHostname()
		}
		if osType != "" && strings.EqualFold(osType, "windows") {
			operatingSystem = "Windows"
		} else {
			operatingSystem = "Linux"
		}
	}

	//TODO: Remove this DEAD CODE as it was only used by replica set for Windows data
	// Checking if we are in windows daemonset and sending only a few metrics that are needed for MDM
	if osType != "" && strings.EqualFold(osType, "windows") && !IsAADMSIAuthMode() {
		// Container metrics
		metricDataItems = append(metricDataItems, getContainerMemoryMetricItems(metricInfo, hostName, "workingSetBytes", MEMORY_WORKING_SET_BYTES, metricTime, operatingSystem, namespaceFilteringMode, namespaces)...)
		containerCpuUsageNanoSecondsRate := getContainerCpuMetricItemRate(metricInfo, hostName, "usageCoreNanoSeconds", CPU_USAGE_NANO_CORES, metricTime, namespaceFilteringMode, namespaces)
		if len(containerCpuUsageNanoSecondsRate) > 0 {
			metricDataItems = append(metricDataItems, containerCpuUsageNanoSecondsRate...)
		}

		// Node metrics
		cpuUsageNanoSecondsRate := getNodeMetricItemRate(metricInfo, hostName, "cpu", "usageCoreNanoSeconds", CPU_USAGE_NANO_CORES, operatingSystem, metricTime)
		if cpuUsageNanoSecondsRate != nil {
			metricDataItems = append(metricDataItems, cpuUsageNanoSecondsRate)
		}

		metricDataItems = append(metricDataItems, getNodeMetricItem(metricInfo, hostName, "memory", "workingSetBytes", MEMORY_WORKING_SET_BYTES, metricTime))
	} else {
		metricDataItems = append(metricDataItems, getContainerMemoryMetricItems(metricInfo, hostName, "workingSetBytes", MEMORY_WORKING_SET_BYTES, metricTime, operatingSystem, namespaceFilteringMode, namespaces)...)
		metricDataItems = append(metricDataItems, getContainerStartTimeMetricItems(metricInfo, hostName, "restartTimeEpoch", metricTime, namespaceFilteringMode, namespaces)...)

		if operatingSystem == "Linux" {
			metricDataItems = append(metricDataItems, getContainerCpuMetricItems(metricInfo, hostName, "usageNanoCores", CPU_USAGE_NANO_CORES, metricTime, namespaceFilteringMode, namespaces)...)
			metricDataItems = append(metricDataItems, getContainerMemoryMetricItems(metricInfo, hostName, "rssBytes", MEMORY_RSS_BYTES, metricTime, operatingSystem, namespaceFilteringMode, namespaces)...)
			metricDataItems = append(metricDataItems, getNodeMetricItem(metricInfo, hostName, "memory", "rssBytes", MEMORY_RSS_BYTES, metricTime))
		} else if operatingSystem == "Windows" {
			containerCpuUsageNanoSecondsRate := getContainerCpuMetricItemRate(metricInfo, hostName, "usageCoreNanoSeconds", CPU_USAGE_NANO_CORES, metricTime, namespaceFilteringMode, namespaces)
			if len(containerCpuUsageNanoSecondsRate) > 0 {
				metricDataItems = append(metricDataItems, containerCpuUsageNanoSecondsRate...)
			}
		}

		cpuUsageNanoSecondsRate := getNodeMetricItemRate(metricInfo, hostName, "cpu", "usageCoreNanoSeconds", CPU_USAGE_NANO_CORES, operatingSystem, metricTime)
		if cpuUsageNanoSecondsRate != nil {
			metricDataItems = append(metricDataItems, cpuUsageNanoSecondsRate)
		}

		metricDataItems = append(metricDataItems, getNodeMetricItem(metricInfo, hostName, "memory", "workingSetBytes", MEMORY_WORKING_SET_BYTES, metricTime))
		metricDataItems = append(metricDataItems, getNodeLastRebootTimeMetric(metricInfo, hostName, "restartTimeEpoch", metricTime))
	}

	return metricDataItems
}

func GetInsightsMetrics(winNode map[string]string, namespaceFilteringMode string, namespaces []string, metricTime string) []metricDataItem {
	metricDataItems := []metricDataItem{}
	cAdvisorStats, err := getSummaryStatsFromCAdvisor(winNode)
	if err != nil {
		Log.Errorf("Error getting cAdvisorStats: %s", err)
		telemetryProps := make(map[string]string)
		telemetryProps["Computer"] = hostName
		SendExceptionTelemetry(err.Error(), telemetryProps)
	} else {
		defer cAdvisorStats.Body.Close()
	}
	var metricInfo map[string]interface{}
	if cAdvisorStats != nil {
		bodybytes, err := io.ReadAll(cAdvisorStats.Body)
		if err != nil {
			Log.Errorf("Error reading cAdvisorStats response: %s", err)
			return metricDataItems
		}
		err = json.Unmarshal(bodybytes, &metricInfo)
		if err != nil {
			Log.Errorf("Error parsing cAdvisorStats: %s", err)
			return metricDataItems
		}
	}

	if winNode != nil {
		hostName = winNode["Hostname"]
		operatingSystem = "Windows"
	} else {
		if metricInfo != nil && metricInfo["node"] != nil && metricInfo["node"].(map[string]interface{})["nodeName"] != nil {
			hostName = metricInfo["node"].(map[string]interface{})["nodeName"].(string)
		} else {
			hostName = GetHostname()
		}
		operatingSystem = "Linux"
	}

	if metricInfo != nil {
		metricDataItems = append(metricDataItems, getContainerGpuMetricsAsInsightsMetrics(metricInfo, hostName, "memoryTotal", "containerGpumemoryTotalBytes", metricTime, namespaceFilteringMode, namespaces)...)
		metricDataItems = append(metricDataItems, getContainerGpuMetricsAsInsightsMetrics(metricInfo, hostName, "memoryUsed", "containerGpumemoryUsedBytes", metricTime, namespaceFilteringMode, namespaces)...)
		metricDataItems = append(metricDataItems, getContainerGpuMetricsAsInsightsMetrics(metricInfo, hostName, "dutyCycle", "containerGpuDutyCycle", metricTime, namespaceFilteringMode, namespaces)...)

		metricDataItems = append(metricDataItems, getPersistentVolumeMetrics(metricInfo, hostName, "usedBytes", PV_USED_BYTES, metricTime, namespaceFilteringMode, namespaces)...)
	} else {
		Log.Warnf("GetInsightsMetrics: metricInfo is nil")
		return metricDataItems
	}

	return metricDataItems
}

func getContainerMemoryMetricItems(metricInfo map[string]interface{}, hostName, metricKey, metricName, metricTime, operatingSystem, namespaceFilteringMode string, namespaces []string) []metricDataItem {
	metricItems := []metricDataItem{}
	clusterID := GetClusterID() // Assume that GetClusterID() function returns the cluster ID.
	timeDifference := math.Abs(float64(time.Now().Unix() - telemetryMemoryMetricTimeTracker))
	timeDifferenceInMinutes := timeDifference / 60

	pods, ok := metricInfo["pods"].([]interface{})
	if !ok {
		Log.Warnf("Pods information not found in the metricInfo.")
		return metricItems
	}

	for _, pod := range pods {
		podData, ok := pod.(map[string]interface{})
		if !ok {
			Log.Warnf("Error: pod data is not a map")
			continue
		}
		podRef, ok := podData["podRef"].(map[string]interface{})
		if !ok {
			Log.Warnf("Error: podRef data is not a map")
			continue
		}

		podUid, _ := podRef["uid"].(string)
		podName, _ := podRef["name"].(string)
		podNamespace, _ := podRef["namespace"].(string)

		if !IsExcludeResourceItem(podName, podNamespace, namespaceFilteringMode, namespaces) {
			containers, ok := podData["containers"].([]interface{})
			if !ok {
				Log.Warnf("Error: 'containers' key not found or not an array")
				continue
			}

			for _, container := range containers {
				containerData, ok := container.(map[string]interface{})
				if !ok {
					Log.Warnf("Error: container data is not a map")
					continue
				}

				containerName, _ := containerData["name"].(string)
				containerDataMemory := containerData["memory"]
				metricValue := containerDataMemory.(map[string]interface{})[metricKey].(float64)

				metricItem := metricDataItem{}
				metricItem["Timestamp"] = metricTime
				metricItem["Host"] = hostName
				metricItem["ObjectName"] = OBJECT_NAME_K8S_CONTAINER
				metricItem["InstanceName"] = clusterID + "/" + podUid + "/" + containerName

				metricCollection := map[string]interface{}{
					"CounterName": metricName,
					"Value":       metricValue,
				}

				metricCollections := []map[string]interface{}{metricCollection}
				metricCollectionsJSON, err := json.Marshal(metricCollections)
				if err != nil {
					Log.Warnf("Error marshaling metricCollections: %s", err)
					continue
				}

				metricItem["json_Collections"] = string(metricCollectionsJSON)
				metricItems = append(metricItems, metricItem)

				podNameLower := strings.ToLower(podName)
				podNamespaceLower := strings.ToLower(podNamespace)
				containerNameLower := strings.ToLower(containerName)
				operatingSystemLower := strings.ToLower(operatingSystem)

				isAmaLogsPod := strings.HasPrefix(podNameLower, "ama-logs-")
				isKubeSystemNamespace := podNamespaceLower == "kube-system"
				isAmaLogsContainer := strings.HasPrefix(containerNameLower, "ama-logs")

				if (isAmaLogsPod && isKubeSystemNamespace && isAmaLogsContainer && strings.EqualFold(metricName, MEMORY_RSS_BYTES) && operatingSystemLower == "linux") || (strings.EqualFold(metricName, MEMORY_WORKING_SET_BYTES) && operatingSystemLower == "windows") {
					if timeDifferenceInMinutes >= TELEMETRY_FLUSH_INTERVAL_IN_MINUTES {
						telemetryProps := map[string]string{}
						telemetryProps["Pod"] = podName
						telemetryProps["ContainerName"] = containerName
						telemetryProps["Computer"] = hostName
						SendMetricTelemetry(metricName, metricValue, telemetryProps)
					}
				}
			}

		}
	}

	if timeDifferenceInMinutes >= TELEMETRY_FLUSH_INTERVAL_IN_MINUTES && strings.EqualFold(metricName, MEMORY_RSS_BYTES) {
		telemetryMemoryMetricTimeTracker = time.Now().Unix()
	}

	return metricItems

}

func getContainerCpuMetricItemRate(metricInfo map[string]interface{}, hostName, metricKey, metricName, metricTime, namespaceFilteringMode string, namespaces []string) []metricDataItem {
	metricItems := []metricDataItem{}
	clusterID := GetClusterID() // Assume that GetClusterID() function returns the cluster ID.
	timeDifference := math.Abs(float64(time.Now().Unix() - telemetryCpuMetricTimeTracker))
	timeDifferenceInMinutes := timeDifference / 60

	pods, ok := metricInfo["pods"].([]interface{})
	if !ok {
		Log.Warnf("Pods information not found in the metricInfo.")
		return metricItems
	}

	containerCount := 0
	for _, pod := range pods {
		podData, ok := pod.(map[string]interface{})
		if !ok {
			Log.Warnf("Error: pod data is not a map")
			continue
		}
		podRef, ok := podData["podRef"].(map[string]interface{})
		if !ok {
			Log.Warnf("Error: podRef data is not a map")
			continue
		}

		podUid, _ := podRef["uid"].(string)
		podName, _ := podRef["name"].(string)
		podNamespace, _ := podRef["namespace"].(string)

		if !IsExcludeResourceItem(podName, podNamespace, namespaceFilteringMode, namespaces) {
			containers, ok := podData["containers"].([]interface{})
			if !ok {
				Log.Warnf("Error: 'containers' key not found or not an array")
				continue
			}

			for _, container := range containers {
				containerData, ok := container.(map[string]interface{})
				if !ok {
					Log.Warnf("Error: container data is not a map")
					continue
				}

				containerCount++

				containerName, _ := containerData["name"].(string)
				containerDataCpu := containerData["cpu"]
				metricValue := containerDataCpu.(map[string]interface{})[metricKey].(float64)

				metricItem := metricDataItem{}
				metricItem["Timestamp"] = metricTime
				metricItem["Host"] = hostName
				metricItem["ObjectName"] = OBJECT_NAME_K8S_CONTAINER
				metricItem["InstanceName"] = clusterID + "/" + podUid + "/" + containerName

				metricCollection := map[string]interface{}{
					"CounterName": metricName,
				}

				containerId := podUid + "/" + containerName
				winContainerIdCache[containerId] = true
				metricTimeParsed, _ := time.Parse(time.RFC3339, metricTime)
				if lastTime, exists := winContainerCpuUsageNanoSecondsTimeLast[containerId]; !exists || winContainerCpuUsageNanoSecondsLast[containerId] > metricValue {
					winContainerCpuUsageNanoSecondsLast[containerId] = metricValue
					winContainerCpuUsageNanoSecondsTimeLast[containerId] = metricTimeParsed
					// Equivalent of 'next' in Ruby:
					continue
				} else {
					timeDifference := metricTimeParsed.Sub(lastTime)
					containerCpuUsageDifference := metricValue - winContainerCpuUsageNanoSecondsLast[containerId]
					var metricRateValue float64
					if timeDifference.Seconds() != 0 && containerCpuUsageDifference != 0 {
						metricRateValue = containerCpuUsageDifference / timeDifference.Seconds()
					} else {
						Log.Warnf("Error: timeDifference.Seconds() is 0 or containerCpuUsageDifference is 0")
						if value, exists := winContainerPrevMetricRate[containerId]; exists {
							metricRateValue = value
						} else {
							metricRateValue = 0
						}
					}

					winContainerCpuUsageNanoSecondsLast[containerId] = metricValue
					winContainerCpuUsageNanoSecondsTimeLast[containerId] = metricTimeParsed
					metricValue = metricRateValue
					winContainerPrevMetricRate[containerId] = metricRateValue
				}

				metricCollection["Value"] = metricValue

				metricCollections := []map[string]interface{}{metricCollection}
				metricCollectionsJSON, err := json.Marshal(metricCollections)
				if err != nil {
					Log.Warnf("Error marshaling metricCollections: %s", err)
					continue
				}

				metricItem["json_Collections"] = string(metricCollectionsJSON)
				metricItems = append(metricItems, metricItem)

				podNameLower := strings.ToLower(podName)
				podNamespaceLower := strings.ToLower(podNamespace)
				containerNameLower := strings.ToLower(containerName)

				isAmaLogsPod := strings.HasPrefix(podNameLower, "ama-logs-")
				isKubeSystemNamespace := podNamespaceLower == "kube-system"
				isAmaLogsContainer := strings.HasPrefix(containerNameLower, "ama-logs")

				if isAmaLogsPod && isKubeSystemNamespace && isAmaLogsContainer && strings.EqualFold(metricName, CPU_USAGE_NANO_CORES) {
					if timeDifferenceInMinutes >= TELEMETRY_FLUSH_INTERVAL_IN_MINUTES {
						telemetryProps := map[string]string{}
						telemetryProps["Pod"] = podName
						telemetryProps["ContainerName"] = containerName
						telemetryProps["Computer"] = hostName
						telemetryProps["CAdvisorIsSecure"] = os.Getenv("IS_SECURE_CADVISOR_PORT")

						_, err := os.Stat(configMapMountPath)
						if err == nil {
							telemetryProps["clustercustomsettings"] = "true"
							telemetryProps["clusterenvvars"] = os.Getenv("AZMON_CLUSTER_COLLECT_ENV_VAR")
							telemetryProps["clusterstderrlogs"] = os.Getenv("AZMON_CLUSTER_COLLECT_STDERR_LOGS")
							telemetryProps["clusterstdoutlogs"] = os.Getenv("AZMON_CLUSTER_COLLECT_STDOUT_LOGS")
							telemetryProps["clusterlogtailexcludepath"] = os.Getenv("AZMON_CLUSTER_LOG_TAIL_EXCLUDE_PATH")
							telemetryProps["clusterLogTailPath"] = os.Getenv("AZMON_LOG_TAIL_PATH")
							telemetryProps["clusterAgentSchemaVersion"] = os.Getenv("AZMON_AGENT_CFG_SCHEMA_VERSION")
							telemetryProps["clusterCLEnrich"] = os.Getenv("AZMON_CLUSTER_CONTAINER_LOG_ENRICH")
						}
						// telemetry about prometheus metric collections settings for daemonset
						_, err = os.Stat(promConfigMountPath)
						if err == nil {
							telemetryProps["dsPromInt"] = os.Getenv("TELEMETRY_DS_PROM_INTERVAL")
							telemetryProps["dsPromFPC"] = os.Getenv("TELEMETRY_DS_PROM_FIELDPASS_LENGTH")
							telemetryProps["dsPromFDC"] = os.Getenv("TELEMTRY_DS_PROM_FIELDDROP_LENGTH")
							telemetryProps["dsPromUrl"] = os.Getenv("TELEMETRY_DS_PROM_URLS_LENGTH")
						}
						SendMetricTelemetry(metricName, metricValue, telemetryProps)
					}
				}
			}

		}
	}

	if _, found := nodeTelemetryTimeTracker[hostName]; !found {
		nodeTelemetryTimeTracker[hostName] = time.Now().Unix()
	} else {
		timeDifference := math.Abs(float64(time.Now().Unix() - telemetryMemoryMetricTimeTracker))
		timeDifferenceInMinutes := timeDifference / 60
		if timeDifferenceInMinutes >= 5 {
			nodeTelemetryTimeTracker[hostName] = time.Now().Unix()
			telemetryProperties := map[string]string{}
			telemetryProperties["Computer"] = hostName
			telemetryProperties["ContainerCount"] = fmt.Sprintf("%d", containerCount)
			telemetryProperties["OS"] = "Windows"
			Log.Infof("Sending ContainerInventoryHeartBeatEvent")
			SendCustomEvent("ContainerInventoryHeartBeatEvent", telemetryProperties)
		}
	}
	return metricItems
}

func getNodeMetricItemRate(metricInfo map[string]interface{}, hostName, metricGroup, metricKey, metricName, operatingSystem, metricTime string) metricDataItem {
	nodeMetricItem := metricDataItem{}
	clusterId := GetClusterID() // Assume that GetClusterID() function returns the cluster ID.

	node, found := metricInfo["node"].(map[string]interface{})
	if !found {
		Log.Warnf("Node information not found in the metricInfo.")
		return nodeMetricItem
	}

	nodeName, found := node["nodeName"].(string)
	if !found {
		Log.Warnf("Node name not found in the metricInfo.")
		return nodeMetricItem
	}

	metricCategoryData, found := node[metricGroup].(map[string]interface{})
	if !found {
		Log.Warnf("getNodeMetricItemRate: metricGroup %v not found in the metricInfo.", metricGroup)
		return nil
	}
	metricValue, found := metricCategoryData[metricKey]
	if !found {
		Log.Warnf("getNodeMetricItemRate: metricKey %v not found in the metricInfo.", metricKey)
	}

	if metricKey != "usageCoreNanoSeconds" {
		Log.Warnf("getNodeMetricItemRate: rateMetric is support only for usageCoreNanoSeconds and not for %v", metricKey)
		return nil
	} else {
		metricRateValue := 0.0
		if operatingSystem == "Linux" || (operatingSystem == "Windows" && IsAADMSIAuthMode()) { // For Linux and Windows with MSI mode
			if nodeCpuUsageNanoSecondsLast == 0 || len(nodeCpuUsageNanoSecondsTimeLast) == 0 || nodeCpuUsageNanoSecondsLast > metricValue.(float64) {
				metricValueFloat := metricValue.(float64)
				nodeCpuUsageNanoSecondsLast = metricValueFloat
				nodeCpuUsageNanoSecondsTimeLast = metricTime
				return nil
			} else {
				metricTimeParsed, _ := time.Parse(time.RFC3339, metricTime)
				nodeCpuUsageNanoSecondsTimeLastParsed, _ := time.Parse(time.RFC3339, nodeCpuUsageNanoSecondsTimeLast)

				timeDifference := metricTimeParsed.Sub(nodeCpuUsageNanoSecondsTimeLastParsed)
				nodeCpuUsageDifference := metricValue.(float64) - float64(nodeCpuUsageNanoSecondsLast)

				if timeDifference.Seconds() > 0 && nodeCpuUsageDifference != 0 {
					metricRateValue = nodeCpuUsageDifference / timeDifference.Seconds()
				} else if linuxNodePrevMetricRate != 0.0 {
					metricRateValue = linuxNodePrevMetricRate
				}

				nodeCpuUsageNanoSecondsLast = metricValue.(float64)
				nodeCpuUsageNanoSecondsTimeLast = metricTime
				linuxNodePrevMetricRate = metricRateValue
				metricValue = metricRateValue
			}
		} else if operatingSystem == "Windows" { // For Windows with non-MSI mode
			//TODO: Remove this DEAD CODE as it was only used by replica set for Windows data
			if _, ok := winNodeCpuUsageNanoSecondsLast[hostName]; ok || winNodeCpuUsageNanoSecondsTimeLast[hostName] == nil || winNodeCpuUsageNanoSecondsLast[hostName] > metricValue.(float64) {
				winNodeCpuUsageNanoSecondsLast[hostName] = metricValue.(float64)
				winNodeCpuUsageNanoSecondsTimeLast[hostName] = metricTime
				return nil
			} else {
				metricTimeParsed, _ := time.Parse(time.RFC3339, metricTime)
				winNodeCpuUsageNanoSecondsTimeLastParsed, _ := time.Parse(time.RFC3339, winNodeCpuUsageNanoSecondsTimeLast[hostName].(string))

				timeDifference := metricTimeParsed.Sub(winNodeCpuUsageNanoSecondsTimeLastParsed)
				nodeCpuUsageDifference := metricValue.(float64) - winNodeCpuUsageNanoSecondsLast[hostName]

				if timeDifference.Seconds() > 0 && nodeCpuUsageDifference != 0 {
					metricRateValue = nodeCpuUsageDifference / timeDifference.Seconds()
				} else if winNodePrevMetricRate[hostName] != 0.0 {
					metricRateValue = winNodePrevMetricRate[hostName]
				}

				winNodeCpuUsageNanoSecondsLast[hostName] = metricValue.(float64)
				winNodeCpuUsageNanoSecondsTimeLast[hostName] = metricTime
				winNodePrevMetricRate[hostName] = metricRateValue
				metricValue = metricRateValue
			}
		}
	}

	nodeMetricItem["Timestamp"] = metricTime
	nodeMetricItem["Host"] = hostName
	nodeMetricItem["ObjectName"] = OBJECT_NAME_K8S_NODE
	nodeMetricItem["InstanceName"] = clusterId + "/" + nodeName

	metricCollection := map[string]interface{}{
		"CounterName": metricName,
		"Value":       metricValue,
	}

	metricCollections := []map[string]interface{}{metricCollection}
	metricCollectionsJSON, err := json.Marshal(metricCollections)
	if err != nil {
		Log.Warnf("Error marshaling metricCollections: %s", err)
		return nil
	}

	nodeMetricItem["json_Collections"] = string(metricCollectionsJSON)

	return nodeMetricItem
}

func getNodeMetricItem(metricInfo map[string]interface{}, hostName, metricGroup, metricKey, metricName, metricTime string) metricDataItem {
	nodeMetricItem := metricDataItem{}

	clusterID := GetClusterID() // Assume that GetClusterID() function returns the cluster ID.

	node, found := metricInfo["node"].(map[string]interface{})
	if !found {
		Log.Warnf("Node information not found in the metricInfo.")
		return nodeMetricItem
	}

	nodeName, found := node["nodeName"].(string)
	if !found {
		Log.Warnf("Node name not found in the metricInfo.")
		return nodeMetricItem
	}

	metricCategoryData, found := node[metricGroup].(map[string]interface{})
	if !found {
		Log.Warnf("Metric category data not found in the metricInfo.")
		return nodeMetricItem
	}

	metricValue, found := metricCategoryData[metricKey]
	if !found {
		Log.Warnf("Metric value not found in the metricInfo.")
		return nodeMetricItem
	}

	nodeMetricItem["Timestamp"] = metricTime
	nodeMetricItem["Host"] = hostName
	nodeMetricItem["ObjectName"] = OBJECT_NAME_K8S_NODE
	nodeMetricItem["InstanceName"] = clusterID + "/" + nodeName

	metricCollection := map[string]interface{}{
		"CounterName": metricName,
		"Value":       metricValue,
	}

	metricCollections := []map[string]interface{}{metricCollection}
	metricCollectionsJSON, err := json.Marshal(metricCollections)
	if err != nil {
		Log.Warnf("Error marshaling metricCollections: %s", err)
		return nodeMetricItem
	}

	nodeMetricItem["json_Collections"] = string(metricCollectionsJSON)

	return nodeMetricItem
}

func getNodeLastRebootTimeMetric(metricInfo map[string]interface{}, hostName, metricKey, metricTime string) metricDataItem {
	nodeMetricItem := metricDataItem{}
	cluserId := GetClusterID() // Assume that GetClusterID() function returns the cluster ID.
	node, found := metricInfo["node"].(map[string]interface{})
	if !found {
		Log.Warnf("Node information not found in the metricInfo.")
		return nodeMetricItem
	}

	nodeName, found := node["nodeName"].(string)
	if !found {
		Log.Warnf("Node name not found in the metricInfo.")
		return nodeMetricItem
	}

	nodeMetricItem["Timestamp"] = metricTime
	nodeMetricItem["Host"] = hostName
	nodeMetricItem["ObjectName"] = OBJECT_NAME_K8S_NODE
	nodeMetricItem["InstanceName"] = cluserId + "/" + nodeName

	// Parse the time string as a time in UTC
	parsedTime, err := time.Parse(time.RFC3339, metricTime)
	if err != nil {
		Log.Warnf("Error parsing time: %s", err)
		return nodeMetricItem
	}

	var epochTime int64
	if osType != "" && strings.EqualFold(osType, "windows") && IsAADMSIAuthMode() {
		//Stat the modification time from "C:\\etc\\kubernetes\\host\\windowsnodereset.log"
		fileStat, err := os.Stat("C:\\etc\\kubernetes\\host\\windowsnodereset.log")
		if err != nil {
			Log.Warnf("Error stating C:\\etc\\kubernetes\\host\\windowsnodereset.log: %s", err)
			return nodeMetricItem
		}
		modificationTime := fileStat.ModTime()
		epochTime = modificationTime.Unix()
	} else {
		// Read the first value from /proc/uptime and convert it to a float64
		uptimeStr, err := ioutil.ReadFile("/proc/uptime")
		if err != nil {
			Log.Warnf("Error reading /proc/uptime: %s", err)
			return nodeMetricItem
		}
		uptimeSecondsStr := strings.Fields(string(uptimeStr))[0]
		uptimeSeconds, err := strconv.ParseFloat(uptimeSecondsStr, 64)
		if err != nil {
			Log.Warnf("Error parsing uptime value: %s", err)
			return nodeMetricItem
		}

		epochTime = parsedTime.Unix() - int64(uptimeSeconds)
	}

	metricCollection := map[string]interface{}{
		"CounterName": metricKey,
		"Value":       epochTime,
	}

	metricCollections := []map[string]interface{}{metricCollection}
	metricCollectionsJSON, err := json.Marshal(metricCollections)
	if err != nil {
		Log.Warnf("Error marshaling metricCollections: %s", err)
		return nodeMetricItem
	}

	nodeMetricItem["json_Collections"] = string(metricCollectionsJSON)
	return nodeMetricItem
}

func getContainerStartTimeMetricItems(metricInfo map[string]interface{}, hostName, metricName, metricTime, namespaceFilteringMode string, namespaces []string) []metricDataItem {
	metricItems := []metricDataItem{}
	clusterID := GetClusterID() // Assume that GetClusterID() function returns the cluster ID.
	pods, ok := metricInfo["pods"].([]interface{})
	if !ok {
		Log.Warnf("Pods information not found in the metricInfo.")
		return metricItems
	}
	for _, pod := range pods {
		podData, ok := pod.(map[string]interface{})
		if !ok {
			Log.Warnf("Error: pod data is not a map")
			continue
		}
		podRef, ok := podData["podRef"].(map[string]interface{})
		if !ok {
			Log.Warnf("Error: podRef data is not a map")
			continue
		}

		podUid, _ := podRef["uid"].(string)
		podName, _ := podRef["name"].(string)
		podNamespace, _ := podRef["namespace"].(string)

		if !IsExcludeResourceItem(podName, podNamespace, namespaceFilteringMode, namespaces) {
			containers, ok := podData["containers"].([]interface{})
			if !ok {
				Log.Warnf("Error: 'containers' key not found or not an array")
				continue
			}

			for _, container := range containers {
				containerData, ok := container.(map[string]interface{})
				if !ok {
					Log.Warnf("Error: container data is not a map")
					continue
				}

				containerName, _ := containerData["name"].(string)
				metricValue, _ := containerData["startTime"].(string)
				metricValueParsed, _ := time.Parse(time.RFC3339, metricValue)

				metricItem := metricDataItem{}
				metricItem["Timestamp"] = metricTime
				metricItem["Host"] = hostName
				metricItem["ObjectName"] = OBJECT_NAME_K8S_CONTAINER
				metricItem["InstanceName"] = clusterID + "/" + podUid + "/" + containerName

				metricCollection := map[string]interface{}{
					"CounterName": metricName,
					"Value":       metricValueParsed.Unix(),
				}
				metricCollections := []map[string]interface{}{metricCollection}
				metricCollectionsJSON, err := json.Marshal(metricCollections)
				if err != nil {
					Log.Warnf("Error marshaling metricCollections: %s", err)
					continue
				}

				metricItem["json_Collections"] = string(metricCollectionsJSON)
				metricItems = append(metricItems, metricItem)
			}
		}
	}

	return metricItems
}

func getContainerCpuMetricItems(metricInfo map[string]interface{}, hostName, metricKey, metricName, metricTime, namespaceFilteringMode string, namespaces []string) []metricDataItem {
	metricItems := []metricDataItem{}
	clusterID := GetClusterID() // Assume that GetClusterID() function returns the cluster ID.
	timeDifference := math.Abs(float64(time.Now().Unix() - telemetryMemoryMetricTimeTracker))
	timeDifferenceInMinutes := timeDifference / 60

	pods, ok := metricInfo["pods"].([]interface{})
	if !ok {
		Log.Println("Pods information not found in the metricInfo.")
		return metricItems
	}

	for _, pod := range pods {
		podData, ok := pod.(map[string]interface{})
		if !ok {
			Log.Warnf("Error: pod data is not a map")
			continue
		}
		podRef, ok := podData["podRef"].(map[string]interface{})
		if !ok {
			Log.Warnf("Error: podRef data is not a map")
			continue
		}

		podUid, _ := podRef["uid"].(string)
		podName, _ := podRef["name"].(string)
		podNamespace, _ := podRef["namespace"].(string)

		if !IsExcludeResourceItem(podName, podNamespace, namespaceFilteringMode, namespaces) {
			containers, ok := podData["containers"].([]interface{})
			if !ok {
				Log.Warnf("Error: 'containers' key not found or not an array")
				continue
			}

			for _, container := range containers {
				containerData, ok := container.(map[string]interface{})
				if !ok {
					Log.Warnf("Error: container data is not a map")
					continue
				}

				containerName, _ := containerData["name"].(string)
				containerDataCpu := containerData["cpu"]
				metricValue := containerDataCpu.(map[string]interface{})[metricKey].(float64)

				metricItem := metricDataItem{}
				metricItem["Timestamp"] = metricTime
				metricItem["Host"] = hostName
				metricItem["ObjectName"] = OBJECT_NAME_K8S_CONTAINER
				metricItem["InstanceName"] = clusterID + "/" + podUid + "/" + containerName

				metricCollection := map[string]interface{}{
					"CounterName": metricName,
					"Value":       metricValue,
				}

				metricCollections := []map[string]interface{}{metricCollection}
				metricCollectionsJSON, err := json.Marshal(metricCollections)
				if err != nil {
					Log.Warnf("Error marshaling metricCollections: %s", err)
					continue
				}

				metricItem["json_Collections"] = string(metricCollectionsJSON)
				metricItems = append(metricItems, metricItem)

				podNameLower := strings.ToLower(podName)
				podNamespaceLower := strings.ToLower(podNamespace)
				containerNameLower := strings.ToLower(containerName)

				isAmaLogsPod := strings.HasPrefix(podNameLower, "ama-logs-")
				isKubeSystemNamespace := podNamespaceLower == "kube-system"
				isAmaLogsContainer := strings.HasPrefix(containerNameLower, "ama-logs")

				if isAmaLogsPod && isKubeSystemNamespace && isAmaLogsContainer && strings.EqualFold(metricName, CPU_USAGE_NANO_CORES) {
					if timeDifferenceInMinutes >= TELEMETRY_FLUSH_INTERVAL_IN_MINUTES {
						telemetryProps := map[string]string{}
						telemetryProps["Pod"] = podName
						telemetryProps["ContainerName"] = containerName
						telemetryProps["Computer"] = hostName
						telemetryProps["CAdvisorIsSecure"] = os.Getenv("IS_SECURE_CADVISOR_PORT")

						_, err := os.Stat(configMapMountPath)
						if err == nil {
							telemetryProps["clustercustomsettings"] = "true"
							telemetryProps["clusterenvvars"] = os.Getenv("AZMON_CLUSTER_COLLECT_ENV_VAR")
							telemetryProps["clusterstderrlogs"] = os.Getenv("AZMON_CLUSTER_COLLECT_STDERR_LOGS")
							telemetryProps["clusterstdoutlogs"] = os.Getenv("AZMON_CLUSTER_COLLECT_STDOUT_LOGS")
							telemetryProps["clusterlogtailexcludepath"] = os.Getenv("AZMON_CLUSTER_LOG_TAIL_EXCLUDE_PATH")
							telemetryProps["clusterLogTailPath"] = os.Getenv("AZMON_LOG_TAIL_PATH")
							telemetryProps["clusterAgentSchemaVersion"] = os.Getenv("AZMON_AGENT_CFG_SCHEMA_VERSION")
							telemetryProps["clusterCLEnrich"] = os.Getenv("AZMON_CLUSTER_CONTAINER_LOG_ENRICH")
						}
						// telemetry about prometheus metric collections settings for daemonset
						_, err = os.Stat(promConfigMountPath)
						if err == nil {
							telemetryProps["dsPromInt"] = os.Getenv("TELEMETRY_DS_PROM_INTERVAL")
							telemetryProps["dsPromFPC"] = os.Getenv("TELEMETRY_DS_PROM_FIELDPASS_LENGTH")
							telemetryProps["dsPromFDC"] = os.Getenv("TELEMTRY_DS_PROM_FIELDDROP_LENGTH")
							telemetryProps["dsPromUrl"] = os.Getenv("TELEMETRY_DS_PROM_URLS_LENGTH")
						}

						// telemetry about containerlog Routing for daemonset
						telemetryProps["containerLogsRoute"] = os.Getenv("AZMON_CONTAINER_LOGS_ROUTE")
						SendMetricTelemetry(metricName, metricValue, telemetryProps)
						// telemetry for npm integration
						if len(os.Getenv("TELEMETRY_NPM_INTEGRATION_METRICS_ADVANCED")) > 0 {
							telemetryProps["int-npm-a"] = "1"
						} else if len(os.Getenv("TELEMETRY_NPM_INTEGRATION_METRICS_BASIC")) > 0 {
							telemetryProps["int-npm-b"] = "1"
						}
						// telemetry for subnet ip usage integration
						if len(os.Getenv("TELEMETRY_SUBNET_IP_USAGE_INTEGRATION_METRICS")) > 0 {
							telemetryProps["int-int-ipsubnetusage"] = "1"
						}
						if len(os.Getenv("AZMON_CONTAINER_LOG_SCHEMA_VERSION")) > 0 {
							telemetryProps["containerLogVer"] = os.Getenv("AZMON_CONTAINER_LOG_SCHEMA_VERSION")
						}
						if len(os.Getenv("AZMON_MULTILINE_ENABLED")) > 0 {
							telemetryProps["multilineEnabled"] = os.Getenv("AZMON_MULTILINE_ENABLED")
						}
						if len(os.Getenv("AZMON_RESOURCE_OPTIMIZATION_ENABLED")) > 0 {
							telemetryProps["resoureceOptimizationEnabled"] = os.Getenv("AZMON_RESOURCE_OPTIMIZATION_ENABLED")
						}
						SendMetricTelemetry(metricName, metricValue, telemetryProps)
					}
				}
			}

		}
	}

	// reset time outside pod iterator as we use one timer per metric for 2 pods (ds & rs)
	if timeDifferenceInMinutes >= TELEMETRY_FLUSH_INTERVAL_IN_MINUTES && strings.EqualFold(metricName, CPU_USAGE_NANO_CORES) {
		telemetryCpuMetricTimeTracker = time.Now().Unix()
	}

	return metricItems
}

func getContainerGpuMetricsAsInsightsMetrics(metricInfo map[string]interface{}, hostName, metricKey, metricName, metricTime, namespaceFilteringMode string, namespaces []string) []metricDataItem {
	metricItems := []metricDataItem{}
	clusterId := GetClusterID()
	clusterName := GetClusterName()

	pods, ok := metricInfo["pods"].([]interface{})
	if !ok {
		Log.Println("Pods information not found in the metricInfo.")
		return metricItems
	}

	for _, pod := range pods {
		podData, ok := pod.(map[string]interface{})
		if !ok {
			Log.Warnf("Error: pod data is not a map")
			continue
		}
		podRef, ok := podData["podRef"].(map[string]interface{})
		if !ok {
			Log.Warnf("Error: podRef data is not a map")
			continue
		}

		podUid, _ := podRef["uid"].(string)
		podName, _ := podRef["name"].(string)
		podNamespace, _ := podRef["namespace"].(string)

		if !IsExcludeResourceItem(podName, podNamespace, namespaceFilteringMode, namespaces) {
			containers, ok := podData["containers"].([]interface{})
			if !ok {
				Log.Warnf("Error: 'containers' key not found or not an array")
				continue
			}

			for _, container := range containers {
				containerData, ok := container.(map[string]interface{})
				if !ok {
					Log.Warnf("Error: container data is not a map")
					continue
				}

				accelerators, ok := containerData["accelerators"].([]interface{})
				if !ok {
					continue
				}
				for _, accelerator := range accelerators {
					metricValue := accelerator.(map[string]interface{})[metricKey]
					if !ok {
						continue
					}
					containerName, _ := containerData["name"].(string)

					metricItem := metricDataItem{}
					metricItem["CollectionTime"] = metricTime
					metricItem["Computer"] = hostName
					metricItem["Name"] = metricName
					metricItem["Value"] = metricValue
					metricItem["Origin"] = INSIGHTSMETRICS_TAGS_ORIGIN
					metricItem["Namespace"] = INSIGHTSMETRICS_TAGS_GPU_NAMESPACE

					metricTags := make(map[string]string)
					metricTags[INSIGHTSMETRICS_TAGS_CLUSTERID] = clusterId
					metricTags[INSIGHTSMETRICS_TAGS_CLUSTERNAME] = clusterName
					metricTags[INSIGHTSMETRICS_TAGS_CONTAINER_NAME] = podUid + "/" + containerName

					make := accelerator.(map[string]interface{})["make"].(string)
					model := accelerator.(map[string]interface{})["model"].(string)
					id := accelerator.(map[string]interface{})["id"].(string)

					if len(make) > 0 {
						metricTags[INSIGHTSMETRICS_TAGS_GPU_VENDOR] = make
					}
					if len(model) > 0 {
						metricTags[INSIGHTSMETRICS_TAGS_GPU_MODEL] = model
					}
					if len(id) > 0 {
						metricTags[INSIGHTSMETRICS_TAGS_GPU_ID] = id
					}

					metricItem["Tags"] = metricTags
					metricItems = append(metricItems, metricItem)
				}
			}
		}
	}

	return metricItems
}

func getPersistentVolumeMetrics(metricInfo map[string]interface{}, hostName, metricKey, metricName, metricTime, namespaceFilteringMode string, namespaces []string) []metricDataItem {
	telemetryTimeDifference := math.Abs(float64(time.Now().Unix() - telemetryPVKubeSystemMetricsTimeTracker))
	telemetryTimeDifferenceInMinutes := telemetryTimeDifference / 60
	pvKubeSystemCollectionMetricsEnabled := os.Getenv("AZMON_PV_COLLECT_KUBE_SYSTEM_METRICS")

	metricItems := []metricDataItem{}
	clusterID := GetClusterID() // Assume that GetClusterID() function returns the cluster ID.
	clusterName := GetClusterName()
	pods, ok := metricInfo["pods"].([]interface{})
	if !ok {
		Log.Println("Pods information not found in the metricInfo.")
		return metricItems
	}

	for _, pod := range pods {
		podData, ok := pod.(map[string]interface{})
		if !ok {
			Log.Warnf("Error: pod data is not a map")
			continue
		}
		podRef, ok := podData["podRef"].(map[string]interface{})
		if !ok {
			Log.Warnf("Error: podRef data is not a map")
			continue
		}

		podNamespace, _ := podRef["namespace"].(string)
		podName, _ := podRef["name"].(string)

		if !IsExcludeResourceItem(podName, podNamespace, namespaceFilteringMode, namespaces) {
			excludeNamespace := false
			if strings.EqualFold(podNamespace, "kube-system") && pvKubeSystemCollectionMetricsEnabled == "false" {
				excludeNamespace = true
			}

			podVolume, ok := podData["volume"].(map[string]interface{})
			if !excludeNamespace && ok {
				for _, volume := range podVolume {
					pvcRef, ok := volume.(map[string]interface{})["pvcRef"].(map[string]interface{})
					if !ok {
						Log.Warnf("Error: pvcRef data is not a map")
						continue
					}

					pvcName := pvcRef["name"].(string)
					if len(pvcName) == 0 {
						Log.Warnf("Error: pvcRef name is empty")
						continue
					}

					podUid, _ := podRef["uid"].(string)
					pvcNamespace, _ := pvcRef["namespace"].(string)

					metricItem := metricDataItem{}
					metricItem["CollectionTime"] = metricTime
					metricItem["Computer"] = hostName
					metricItem["Name"] = metricName
					metricItem["Value"] = volume.(map[string]interface{})[metricKey]
					metricItem["Origin"] = INSIGHTSMETRICS_TAGS_ORIGIN
					metricItem["Namespace"] = INSIGHTSMETRICS_TAGS_PV_NAMESPACE

					metricTags := make(map[string]string)
					metricTags[INSIGHTSMETRICS_TAGS_CLUSTERID] = clusterID
					metricTags[INSIGHTSMETRICS_TAGS_CLUSTERNAME] = clusterName
					metricTags[INSIGHTSMETRICS_TAGS_POD_UID] = podUid
					metricTags[INSIGHTSMETRICS_TAGS_POD_NAME] = podName
					metricTags[INSIGHTSMETRICS_TAGS_PVC_NAME] = pvcName
					metricTags[INSIGHTSMETRICS_TAGS_PVC_NAMESPACE] = pvcNamespace
					metricTags[INSIGHTSMETRICS_TAGS_VOLUME_NAME] = volume.(map[string]interface{})["name"].(string)
					metricTags[INSIGHTSMETRICS_TAGS_PV_CAPACITY_BYTES] = volume.(map[string]interface{})["capacityBytes"].(string)

					metricItem["Tags"] = metricTags

					metricItems = append(metricItems, metricItem)
				}
			}
		}
	}

	if telemetryTimeDifferenceInMinutes > TELEMETRY_FLUSH_INTERVAL_IN_MINUTES && pvKubeSystemCollectionMetricsEnabled == "true" {
		SendCustomEvent(PV_KUBE_SYSTEM_METRICS_ENABLED_EVENT, nil)
		telemetryPVKubeSystemMetricsTimeTracker = time.Now().Unix()
	}

	return metricItems
}

func ResetWinContainerIdCache() {
	for key := range winContainerIdCache {
		delete(winContainerIdCache, key)
	}
}

func ClearDeletedWinContainersFromCache() {
	var winCpuUsageNanoSecondsKeys []string
	for key := range winContainerCpuUsageNanoSecondsLast {
		winCpuUsageNanoSecondsKeys = append(winCpuUsageNanoSecondsKeys, key)
	}

	winContainersToBeCleared := []string{}
	for _, containerId := range winCpuUsageNanoSecondsKeys {
		if _, exists := winContainerIdCache[containerId]; !exists {
			winContainersToBeCleared = append(winContainersToBeCleared, containerId)
		}
	}

	if len(winContainersToBeCleared) > 0 {
		Log.Println("Stale containers found in cache, clearing...: %v", winContainersToBeCleared)
	}

	for _, containerId := range winContainersToBeCleared {
		delete(winContainerCpuUsageNanoSecondsLast, containerId)
		delete(winContainerCpuUsageNanoSecondsTimeLast, containerId)
	}
}
