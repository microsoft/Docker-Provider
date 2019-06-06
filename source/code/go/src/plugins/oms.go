package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/fluent/fluent-bit-go/output"

	lumberjack "gopkg.in/natefinch/lumberjack.v2"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

// DataType for Container Log
const ContainerLogDataType = "CONTAINER_LOG_BLOB"

// DataType for Insights metric
const InsightsMetricsDataType = "INSIGHTS_METRICS_BLOB"

//env varibale which has ResourceId for LA
const ResourceIdEnv = "AKS_RESOURCE_ID"

//env variable which has ResourceName for NON-AKS
const ResourceNameEnv = "ACS_RESOURCE_NAME"

// Origin prefix for telegraf Metrics (used as prefix for origin field & prefix for azure monitor specific tags)
const TelegrafMetricOriginPrefix = "container.azm.ms"

// Origin suffix for telegraf Metrics (used as suffix for origin field)
const TelegrafMetricOriginSuffix = "telegraf"

// Namespace prefix for telegraf Metrics (used as prefix for Namespace field)
//const TelegrafMetricNamespacePrefix = "plugin"
// clusterName tag
const TelegrafTagClusterName = "clusterName"

// clusterId tag
const TelegrafTagClusterID = "clusterId"

// ContainerLogPluginConfFilePath --> config file path for container log plugin
const DaemonSetContainerLogPluginConfFilePath = "/etc/opt/microsoft/docker-cimprov/out_oms.conf"
const ReplicaSetContainerLogPluginConfFilePath = "/etc/opt/microsoft/docker-cimprov/out_oms.conf"

// IPName for Container Log
const IPName = "Containers"
const defaultContainerInventoryRefreshInterval = 60

// const defaultKubeSystemContainersRefreshInterval = 300
const defaultExcludeNamespacesContainersRefreshInterval = 300

var (
	// PluginConfiguration the plugins configuration
	PluginConfiguration map[string]string
	// HTTPClient for making POST requests to OMSEndpoint
	HTTPClient http.Client
	// OMSEndpoint ingestion endpoint
	OMSEndpoint string
	// Computer (Hostname) when ingesting into ContainerLog table
	Computer string
	// WorkspaceID log analytics workspace id
	WorkspaceID string
	// ResourceID for resource-centric log analytics data
	ResourceID string
	// Resource-centric flag (will be true if we determine if above RseourceID is non-empty - default is false)
	ResourceCentric bool
	//ResourceName
	ResourceName string
)

var (
	// ImageIDMap caches the container id to image mapping
	ImageIDMap map[string]string
	// NameIDMap caches the container it to Name mapping
	NameIDMap map[string]string
	// StdoutIgnoreIDSet set of  container Ids of excluded namespaces for stdout logs
	StdoutIgnoreIDSet map[string]bool
	// StderrIgnoreIDSet set of  container Ids of excluded namespaces for stderr logs
	StderrIgnoreIDSet map[string]bool
	// DataUpdateMutex read and write mutex access to the container id set
	DataUpdateMutex = &sync.Mutex{}
	// ContainerLogTelemetryMutex read and write mutex access to the Container Log Telemetry
	ContainerLogTelemetryMutex = &sync.Mutex{}
	// ClientSet for querying KubeAPIs
	ClientSet *kubernetes.Clientset
)

var (
	// ExcludeNamespacesContainersRefreshTicker updates the excludenamespace containers
	ExcludeNamespacesContainersRefreshTicker *time.Ticker
	// ContainerImageNameRefreshTicker updates the container image and names periodically
	ContainerImageNameRefreshTicker *time.Ticker
)

var (
	// FLBLogger stream
	FLBLogger = createLogger()
	// Log wrapper function
	Log = FLBLogger.Printf
)

// DataItem represents the object corresponding to the json that is sent by fluentbit tail plugin
type DataItem struct {
	LogEntry              string `json:"LogEntry"`
	LogEntrySource        string `json:"LogEntrySource"`
	LogEntryTimeStamp     string `json:"LogEntryTimeStamp"`
	LogEntryTimeOfCommand string `json:"TimeOfCommand"`
	ID                    string `json:"Id"`
	Image                 string `json:"Image"`
	Name                  string `json:"Name"`
	SourceSystem          string `json:"SourceSystem"`
	Computer              string `json:"Computer"`
}

// telegraf metric DataItem represents the object corresponding to the json that is sent by fluentbit tail plugin
type laTelegrafMetric struct {
	// 'golden' fields
	Origin    string  `json:"Origin"`
	Namespace string  `json:"Namespace"`
	Name      string  `json:"Name"`
	Value     float64 `json:"Value"`
	Tags      string  `json:"Tags"`
	// specific required fields for LA
	CollectionTime string `json:"CollectionTime"` //mapped to TimeGenerated
	Computer       string `json:"Computer"`
}

// ContainerLogBlob represents the object corresponding to the payload that is sent to the ODS end point
type InsightsMetricsBlob struct {
	DataType  string             `json:"DataType"`
	IPName    string             `json:"IPName"`
	DataItems []laTelegrafMetric `json:"DataItems"`
}

// ContainerLogBlob represents the object corresponding to the payload that is sent to the ODS end point
type ContainerLogBlob struct {
	DataType  string     `json:"DataType"`
	IPName    string     `json:"IPName"`
	DataItems []DataItem `json:"DataItems"`
}

func createLogger() *log.Logger {
	var logfile *os.File
	path := "/var/opt/microsoft/docker-cimprov/log/fluent-bit-out-oms-runtime.log"
	if _, err := os.Stat(path); err == nil {
		fmt.Printf("File Exists. Opening file in append mode...\n")
		logfile, err = os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			SendException(err.Error())
			fmt.Printf(err.Error())
		}
	}

	if _, err := os.Stat(path); os.IsNotExist(err) {
		fmt.Printf("File Doesnt Exist. Creating file...\n")
		logfile, err = os.Create(path)
		if err != nil {
			SendException(err.Error())
			fmt.Printf(err.Error())
		}
	}

	logger := log.New(logfile, "", 0)

	logger.SetOutput(&lumberjack.Logger{
		Filename:   path,
		MaxSize:    10, //megabytes
		MaxBackups: 1,
		MaxAge:     28,   //days
		Compress:   true, // false by default
	})

	logger.SetFlags(log.Ltime | log.Lshortfile | log.LstdFlags)
	return logger
}

func updateContainerImageNameMaps() {
	for ; true; <-ContainerImageNameRefreshTicker.C {
		Log("Updating ImageIDMap and NameIDMap")

		_imageIDMap := make(map[string]string)
		_nameIDMap := make(map[string]string)

		listOptions := metav1.ListOptions{}
		listOptions.FieldSelector = fmt.Sprintf("spec.nodeName=%s", Computer)
		pods, err := ClientSet.CoreV1().Pods("").List(listOptions)

		if err != nil {
			message := fmt.Sprintf("Error getting pods %s\nIt is ok to log here and continue, because the logs will be missing image and Name, but the logs will still have the containerID", err.Error())
			Log(message)
			SendException(message)
			continue
		}

		for _, pod := range pods.Items {
			for _, status := range pod.Status.ContainerStatuses {
				lastSlashIndex := strings.LastIndex(status.ContainerID, "/")
				containerID := status.ContainerID[lastSlashIndex+1 : len(status.ContainerID)]
				image := status.Image
				name := fmt.Sprintf("%s/%s", pod.UID, status.Name)
				if containerID != "" {
					_imageIDMap[containerID] = image
					_nameIDMap[containerID] = name
				}
			}
		}

		Log("Locking to update image and name maps")
		DataUpdateMutex.Lock()
		ImageIDMap = _imageIDMap
		NameIDMap = _nameIDMap
		DataUpdateMutex.Unlock()
		Log("Unlocking after updating image and name maps")
	}
}

func excludeContainerIDPopulator(excludeNamespaceList []string, logStream string) {
	var podsToExclude []*corev1.PodList
	listOptions := metav1.ListOptions{}
	listOptions.FieldSelector = fmt.Sprintf("spec.nodeName=%s", Computer)
	
	pods, err := ClientSet.CoreV1().Pods("").List(listOptions)
	if err != nil {
		message := fmt.Sprintf("Error getting pods %s - for node %s . All %s logs might be collected", err.Error(), Computer, logStream)
		SendException(message)
		Log(message)
		return
	}
	
	podsToExclude = append(podsToExclude, pods)
	ignoreNamespaceSet := make(map[string]bool)
	for _, ns := range excludeNamespaceList {
		ignoreNamespaceSet[strings.TrimSpace(ns)] = true
	}
	
	_ignoreIDSet := make(map[string]bool)
	for _, pod := range podsToExclude {
		for _, pod := range pod.Items {
			_, ok := ignoreNamespaceSet[pod.Namespace]
			if ok {
				Log ("Adding pod %s in namespace %s to %s exclusion list", pod.Name, pod.Namespace, logStream)
				for _, status := range pod.Status.ContainerStatuses {
						lastSlashIndex := strings.LastIndex(status.ContainerID, "/")
						_ignoreIDSet[status.ContainerID[lastSlashIndex+1:len(status.ContainerID)]] = true
				}
			}
		}
	}

	Log("Locking to update excluded container IDs for %s", logStream)
	DataUpdateMutex.Lock()
	if strings.Compare(logStream, "stdout") == 0 {
		StdoutIgnoreIDSet = _ignoreIDSet
	} else {
		StderrIgnoreIDSet = _ignoreIDSet
	}
	DataUpdateMutex.Unlock()
	Log("Unlocking after updating excluded container IDs for %s", logStream)
}

func updateExcludeStdoutContainerIDs() {
	for ; true; <-ExcludeNamespacesContainersRefreshTicker.C {
		collectStdoutLogs := os.Getenv("AZMON_COLLECT_STDOUT_LOGS")
		var stdoutNSExcludeList []string
		excludeList := os.Getenv("AZMON_STDOUT_EXCLUDED_NAMESPACES")
		if (strings.Compare(collectStdoutLogs, "true") == 0) && (len(excludeList) > 0) {
			stdoutNSExcludeList = strings.Split(excludeList, ",")
			excludeContainerIDPopulator(stdoutNSExcludeList, "stdout")
		}
	}
}

func updateExcludeStderrContainerIDs() {
	for ; true; <-ExcludeNamespacesContainersRefreshTicker.C {
		collectStderrLogs := os.Getenv("AZMON_COLLECT_STDERR_LOGS")
		var stderrNSExcludeList []string
		excludeList := os.Getenv("AZMON_STDERR_EXCLUDED_NAMESPACES")
		if (strings.Compare(collectStderrLogs, "true") == 0) && (len(excludeList) > 0) {
			stderrNSExcludeList = strings.Split(excludeList, ",")
			excludeContainerIDPopulator(stderrNSExcludeList, "stderr")
		}
	}
}

//Azure loganalytics metric values have to be numeric, so string values are dropped
func convert(in interface{}) (float64, bool) {
	switch v := in.(type) {
	case int64:
		return float64(v), true
	case uint64:
		return float64(v), true
	case float64:
		return v, true
	case bool:
		if v {
			return float64(1), true
		}
		return float64(0), true
	default:
		Log("returning 0 for %v ", in)
		return float64(0), false
	}
}

//Translates telegraf time series to one or more Azure loganalytics metric(s)
func translateTelegrafMetrics(m map[interface{}]interface{}) ([]*laTelegrafMetric, error) {

	var laMetrics []*laTelegrafMetric
	var tags map[interface{}]interface{}
	tags = m["tags"].(map[interface{}]interface{})
	tagMap := make(map[string]string)
	for k, v := range tags {
		key := fmt.Sprintf("%s", k)
		if key == "" {
			continue
		}
		tagMap[key] = fmt.Sprintf("%s", v)
	}

	//add azure monitor tags
	tagMap[fmt.Sprintf("%s/%s", TelegrafMetricOriginPrefix, TelegrafTagClusterID)] = ResourceID
	tagMap[fmt.Sprintf("%s/%s", TelegrafMetricOriginPrefix, TelegrafTagClusterName)] = ResourceName

	var fieldMap map[interface{}]interface{}
	fieldMap = m["fields"].(map[interface{}]interface{})

	tagJson, err := json.Marshal(&tagMap)

	if err != nil {
		return nil, err
	}

	for k, v := range fieldMap {
		fv, ok := convert(v)
		if !ok {
			continue
		}
		i := m["timestamp"].(uint64)
		laMetric := laTelegrafMetric{
			Origin: fmt.Sprintf("%s/%s", TelegrafMetricOriginPrefix, TelegrafMetricOriginSuffix),
			//Namespace:  	fmt.Sprintf("%s/%s", TelegrafMetricNamespacePrefix, m["name"]),
			Namespace:      fmt.Sprintf("%s", m["name"]),
			Name:           fmt.Sprintf("%s", k),
			Value:          fv,
			Tags:           fmt.Sprintf("%s", tagJson),
			CollectionTime: time.Unix(int64(i), 0).Format(time.RFC3339),
			Computer:       Computer, //this is the collection agent's computer name, not necessarily to which computer the metric applies to
		}

		//Log ("la metric:%v", laMetric)
		laMetrics = append(laMetrics, &laMetric)
	}
	return laMetrics, nil
}

//send metrics from Telegraf to LA. 1) Translate telegraf timeseries to LA metric(s) 2) Send it to LA as 'InsightsMetrics' fixed type
func PostTelegrafMetricsToLA(telegrafRecords []map[interface{}]interface{}) int {
	var laMetrics []*laTelegrafMetric

	if (telegrafRecords == nil) || !(len(telegrafRecords) > 0) {
		Log("PostTelegrafMetricsToLA::Error:no timeseries to derive")
		return output.FLB_OK
	}

	for _, record := range telegrafRecords {
		translatedMetrics, err := translateTelegrafMetrics(record)
		if err != nil {
			message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:when translating telegraf metric to log analytics metric %q", err)
			Log(message)
			//SendException(message) //This will be too noisy
		}
		laMetrics = append(laMetrics, translatedMetrics...)
	}

	if (laMetrics == nil) || !(len(laMetrics) > 0) {
		Log("PostTelegrafMetricsToLA::Info:no metrics derived from timeseries data")
		return output.FLB_OK
	} else {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Info:derived %v metrics from %v timeseries", len(laMetrics), len(telegrafRecords))
		Log(message)
	}

	var metrics []laTelegrafMetric
	var i int

	for i = 0; i < len(laMetrics); i++ {
		metrics = append(metrics, *laMetrics[i])
	}

	laTelegrafMetrics := InsightsMetricsBlob{
		DataType:  InsightsMetricsDataType,
		IPName:    IPName,
		DataItems: metrics}

	jsonBytes, err := json.Marshal(laTelegrafMetrics)

	if err != nil {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:when marshalling json %q", err)
		Log(message)
		SendException(message)
		return output.FLB_OK
	}

	//Post metrics data to LA
	req, _ := http.NewRequest("POST", OMSEndpoint, bytes.NewBuffer(jsonBytes))

	//req.URL.Query().Add("api-version","2016-04-01")

	//set headers
	req.Header.Set("x-ms-date", time.Now().Format(time.RFC3339))

	//expensive to do string len for every request, so use a flag
	if ResourceCentric == true {
		req.Header.Set("x-ms-AzureResourceId", ResourceID)
	}

	start := time.Now()
	resp, err := HTTPClient.Do(req)
	elapsed := time.Since(start)

	if err != nil {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:(retriable) when sending %v metrics. duration:%v err:%q \n", len(laMetrics), elapsed, err.Error())
		Log(message)
		SendException(message)
		UpdateNumTelegrafMetricsSentTelemetry(0, 1)
		return output.FLB_RETRY
	}

	if resp == nil || resp.StatusCode != 200 {
		if resp != nil {
			Log("PostTelegrafMetricsToLA::Error:(retriable) Response Status %v Status Code %v", resp.Status, resp.StatusCode)
		}
		UpdateNumTelegrafMetricsSentTelemetry(0, 1)
		return output.FLB_RETRY
	}

	defer resp.Body.Close()

	numMetrics := len(laMetrics)
	UpdateNumTelegrafMetricsSentTelemetry(numMetrics, 0)
	Log("PostTelegrafMetricsToLA::Info:Successfully flushed %v records in %v", numMetrics, elapsed)

	return output.FLB_OK
}

func UpdateNumTelegrafMetricsSentTelemetry(numMetricsSent int, numSendErrors int) {
	ContainerLogTelemetryMutex.Lock()
	TelegrafMetricsSentCount += float64(numMetricsSent)
	TelegrafMetricsSendErrorCount += float64(numSendErrors)
	ContainerLogTelemetryMutex.Unlock()
}

// PostDataHelper sends data to the OMS endpoint
func PostDataHelper(tailPluginRecords []map[interface{}]interface{}) int {
	start := time.Now()
	var dataItems []DataItem

	var maxLatency float64
	var maxLatencyContainer string

	stdoutIgnoreIDSet := make(map[string]bool)
	stderrIgnoreIDSet := make(map[string]bool)
	imageIDMap := make(map[string]string)
	nameIDMap := make(map[string]string)

	DataUpdateMutex.Lock()
	for k, v := range StdoutIgnoreIDSet {
		stdoutIgnoreIDSet[k] = v
	}
	for k, v := range StderrIgnoreIDSet {
		stderrIgnoreIDSet[k] = v
	}
	for k, v := range ImageIDMap {
		imageIDMap[k] = v
	}
	for k, v := range NameIDMap {
		nameIDMap[k] = v
	}
	DataUpdateMutex.Unlock()

	for _, record := range tailPluginRecords {
		containerID := GetContainerIDFromFilePath(ToString(record["filepath"]))
		logEntrySource := ToString(record["stream"])

		if strings.EqualFold(logEntrySource, "stdout") {
			if containerID == "" || containsKey(stdoutIgnoreIDSet, containerID) {
				continue
			}
		} else if strings.EqualFold(logEntrySource, "stderr") {
			if containerID == "" || containsKey(stderrIgnoreIDSet, containerID) {
				continue
			}
		}

		stringMap := make(map[string]string)

		stringMap["LogEntry"] = ToString(record["log"])
		stringMap["LogEntrySource"] = logEntrySource
		stringMap["LogEntryTimeStamp"] = ToString(record["time"])
		stringMap["SourceSystem"] = "Containers"
		stringMap["Id"] = containerID

		if val, ok := imageIDMap[containerID]; ok {
			stringMap["Image"] = val
		}

		if val, ok := nameIDMap[containerID]; ok {
			stringMap["Name"] = val
		}

		dataItem := DataItem{
			ID:                    stringMap["Id"],
			LogEntry:              stringMap["LogEntry"],
			LogEntrySource:        stringMap["LogEntrySource"],
			LogEntryTimeStamp:     stringMap["LogEntryTimeStamp"],
			LogEntryTimeOfCommand: start.Format(time.RFC3339),
			SourceSystem:          stringMap["SourceSystem"],
			Computer:              Computer,
			Image:                 stringMap["Image"],
			Name:                  stringMap["Name"],
		}

		dataItems = append(dataItems, dataItem)
		loggedTime, e := time.Parse(time.RFC3339, dataItem.LogEntryTimeStamp)
		if e != nil {
			message := fmt.Sprintf("Error while converting LogEntryTimeStamp for telemetry purposes: %s", e.Error())
			Log(message)
			SendException(message)
		} else {
			ltncy := float64(start.Sub(loggedTime) / time.Millisecond)
			if ltncy >= maxLatency {
				maxLatency = ltncy
				maxLatencyContainer = dataItem.Name + "=" + dataItem.ID
			}
		}
	}

	if len(dataItems) > 0 {
		logEntry := ContainerLogBlob{
			DataType:  ContainerLogDataType,
			IPName:    IPName,
			DataItems: dataItems}

		marshalled, err := json.Marshal(logEntry)
		if err != nil {
			message := fmt.Sprintf("Error while Marshalling log Entry: %s", err.Error())
			Log(message)
			SendException(message)
			return output.FLB_OK
		}
		req, _ := http.NewRequest("POST", OMSEndpoint, bytes.NewBuffer(marshalled))
		req.Header.Set("Content-Type", "application/json")
		//expensive to do string len for every request, so use a flag
		if ResourceCentric == true {
			req.Header.Set("x-ms-AzureResourceId", ResourceID)
		}

		resp, err := HTTPClient.Do(req)
		elapsed := time.Since(start)

		if err != nil {
			message := fmt.Sprintf("Error when sending request %s \n", err.Error())
			Log(message)
			SendException(message)
			Log("Failed to flush %d records after %s", len(dataItems), elapsed)

			return output.FLB_RETRY
		}

		if resp == nil || resp.StatusCode != 200 {
			if resp != nil {
				Log("Status %s Status Code %d", resp.Status, resp.StatusCode)
			}
			return output.FLB_RETRY
		}

		defer resp.Body.Close()
		numRecords := len(dataItems)
		Log("Successfully flushed %d records in %s", numRecords, elapsed)
		ContainerLogTelemetryMutex.Lock()
		FlushedRecordsCount += float64(numRecords)
		FlushedRecordsTimeTaken += float64(elapsed / time.Millisecond)

		if maxLatency >= AgentLogProcessingMaxLatencyMs {
			AgentLogProcessingMaxLatencyMs = maxLatency
			AgentLogProcessingMaxLatencyMsContainer = maxLatencyContainer
		}

		ContainerLogTelemetryMutex.Unlock()
	}

	return output.FLB_OK
}

func containsKey(currentMap map[string]bool, key string) bool {
	_, c := currentMap[key]
	return c
}

// GetContainerIDFromFilePath Gets the container ID From the file Path
func GetContainerIDFromFilePath(filepath string) string {
	start := strings.LastIndex(filepath, "-")
	end := strings.LastIndex(filepath, ".")
	if start >= end || start == -1 || end == -1 {
		// This means the file is not a managed Kubernetes docker log file.
		// Drop all records from the file
		Log("File %s is not a Kubernetes managed docker log file. Dropping all records from the file", filepath)
		return ""
	}
	return filepath[start+1 : end]
}

// InitializePlugin reads and populates plugin configuration
func InitializePlugin(pluginConfPath string, agentVersion string) {

	StdoutIgnoreIDSet = make(map[string]bool)
	StderrIgnoreIDSet = make(map[string]bool)
	ImageIDMap = make(map[string]string)
	NameIDMap = make(map[string]string)

	pluginConfig, err := ReadConfiguration(pluginConfPath)
	if err != nil {
		message := fmt.Sprintf("Error Reading plugin config path : %s \n", err.Error())
		Log(message)
		SendException(message)
		time.Sleep(30 * time.Second)
		log.Fatalln(message)
	}

	omsadminConf, err := ReadConfiguration(pluginConfig["omsadmin_conf_path"])
	if err != nil {
		message := fmt.Sprintf("Error Reading omsadmin configuration %s\n", err.Error())
		Log(message)
		SendException(message)
		time.Sleep(30 * time.Second)
		log.Fatalln(message)
	}
	OMSEndpoint = omsadminConf["OMS_ENDPOINT"]
	Log("OMSEndpoint %s", OMSEndpoint)

	WorkspaceID = omsadminConf["WORKSPACE_ID"]
	ResourceID = os.Getenv("customResourceId")

	if len(ResourceID) > 0 {
		//AKS Scenario
		ResourceCentric = true
		splitted := strings.Split(ResourceID, "/")
		ResourceName = splitted[len(splitted)-1]
		Log("ResourceCentric: True")
		Log("ResourceID=%s", ResourceID)
		Log("ResourceName=%s", ResourceID)
	}

	if ResourceCentric == false {
		//AKS-Engine/hybrid scenario
		ResourceName = os.Getenv(ResourceNameEnv)
		ResourceID = ResourceName
		Log("ResourceCentric: False")
		Log("ResourceID=%s", ResourceID)
		Log("ResourceName=%s", ResourceName)
	}

	// Initialize image,name map refresh ticker
	containerInventoryRefreshInterval, err := strconv.Atoi(pluginConfig["container_inventory_refresh_interval"])
	if err != nil {
		message := fmt.Sprintf("Error Reading Container Inventory Refresh Interval %s", err.Error())
		Log(message)
		SendException(message)
		Log("Using Default Refresh Interval of %d s\n", defaultContainerInventoryRefreshInterval)
		containerInventoryRefreshInterval = defaultContainerInventoryRefreshInterval
	}
	Log("containerInventoryRefreshInterval = %d \n", containerInventoryRefreshInterval)
	ContainerImageNameRefreshTicker = time.NewTicker(time.Second * time.Duration(containerInventoryRefreshInterval))

	excludeNamespacesContainersRefreshInterval, err := strconv.Atoi(pluginConfig["exclude_namespaces_containers_refresh_interval"])
	if err != nil {
		message := fmt.Sprintf("Error Reading exclude namespaces Container Ids Refresh Interval %s", err.Error())
		Log(message)
		SendException(message)
		Log("Using Default Refresh Interval of %d s\n", defaultExcludeNamespacesContainersRefreshInterval)
		excludeNamespacesContainersRefreshInterval = defaultExcludeNamespacesContainersRefreshInterval
	}
	Log("excludeNamespacesContainersRefreshInterval = %d \n", excludeNamespacesContainersRefreshInterval)
	ExcludeNamespacesContainersRefreshTicker = time.NewTicker(time.Second * time.Duration(excludeNamespacesContainersRefreshInterval))

	// Populate Computer field
	containerHostName, err := ioutil.ReadFile(pluginConfig["container_host_file_path"])
	if err != nil {
		// It is ok to log here and continue, because only the Computer column will be missing,
		// which can be deduced from a combination of containerId, and docker logs on the node
		message := fmt.Sprintf("Error when reading containerHostName file %s.\n It is ok to log here and continue, because only the Computer column will be missing, which can be deduced from a combination of containerId, and docker logs on the nodes\n", err.Error())
		Log(message)
		SendException(message)
	}
	Computer = strings.TrimSuffix(ToString(containerHostName), "\n")
	Log("Computer == %s \n", Computer)

	ret, err := InitializeTelemetryClient(agentVersion)
	if ret != 0 || err != nil {
		message := fmt.Sprintf("Error During Telemetry Initialization :%s", err.Error())
		fmt.Printf(message)
		Log(message)
	}

	// Initialize KubeAPI Client
	config, err := rest.InClusterConfig()
	if err != nil {
		message := fmt.Sprintf("Error getting config %s.\nIt is ok to log here and continue, because the logs will be missing image and Name, but the logs will still have the containerID", err.Error())
		Log(message)
		SendException(message)
	}

	ClientSet, err = kubernetes.NewForConfig(config)
	if err != nil {
		message := fmt.Sprintf("Error getting clientset %s.\nIt is ok to log here and continue, because the logs will be missing image and Name, but the logs will still have the containerID", err.Error())
		SendException(message)
		Log(message)
	}

	PluginConfiguration = pluginConfig

	CreateHTTPClient()

  if strings.Compare(strings.ToLower(os.Getenv("CONTROLLER_TYPE")), "daemonset") == 0 {
    defaultExcludePath := os.Getenv("AZMON_CLUSTER_LOG_TAIL_EXCLUDE_PATH")
    //further optimization for clusters with default settings. need this cache only when log collection config is overridden with custom config
    if ( (strings.Compare(defaultExcludePath, "*_kube-system_*.log") != 0) ) {
      go updateExcludeStdoutContainerIDs()
      go updateExcludeStderrContainerIDs()
    }
    go updateContainerImageNameMaps()
  } else {
		Log("Running in replicaset. Disabling kube-system container cache collection & updates \n")
	}
}
