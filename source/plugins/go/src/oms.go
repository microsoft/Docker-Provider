package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	_ "net/http/pprof"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/fluent/fluent-bit-go/output"
	"github.com/google/uuid"
	"github.com/tinylib/msgp/msgp"

	lumberjack "gopkg.in/natefinch/lumberjack.v2"

	"github.com/Azure/azure-kusto-go/kusto/ingest"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

// DataType for Container Log
const ContainerLogDataType = "CONTAINER_LOG_BLOB"

// DataType for Insights metric
const InsightsMetricsDataType = "INSIGHTS_METRICS_BLOB"

// DataType for ApplicationInsights AppRequests
const AppRequestsDataType = "APPLICATIONINSIGHTS_APPREQUESTS"

// DataType for ApplicationInsights AppDependencies
const AppDependenciesDataType = "APPLICATIONINSIGHTS_APPDEPENDENCIES"

// DataType for KubeMonAgentEvent
const KubeMonAgentEventDataType = "KUBE_MON_AGENT_EVENTS_BLOB"

//env varibale which has ResourceId for LA
const ResourceIdEnv = "AKS_RESOURCE_ID"

//env variable which has ResourceName for NON-AKS
const ResourceNameEnv = "ACS_RESOURCE_NAME"

//env variable which has container run time name
const ContainerRuntimeEnv = "CONTAINER_RUNTIME"

// Origin prefix for telegraf Metrics (used as prefix for origin field & prefix for azure monitor specific tags and also for custom-metrics telemetry )
const TelegrafMetricOriginPrefix = "container.azm.ms"

// Origin suffix for telegraf Metrics (used as suffix for origin field)
const TelegrafMetricOriginSuffix = "telegraf"

// clusterName tag
const TelegrafTagClusterName = "clusterName"

// clusterId tag
const TelegrafTagClusterID = "clusterId"

const ConfigErrorEventCategory = "container.azm.ms/configmap"

const PromScrapingErrorEventCategory = "container.azm.ms/promscraping"

const NoErrorEventCategory = "container.azm.ms/noerror"

const KubeMonAgentEventError = "Error"

const KubeMonAgentEventWarning = "Warning"

const KubeMonAgentEventInfo = "Info"

const KubeMonAgentEventsFlushedEvent = "KubeMonAgentEventsFlushed"

// ContainerLogPluginConfFilePath --> config file path for container log plugin
const DaemonSetContainerLogPluginConfFilePath = "/etc/opt/microsoft/docker-cimprov/out_oms.conf"
const ReplicaSetContainerLogPluginConfFilePath = "/etc/opt/microsoft/docker-cimprov/out_oms.conf"
const WindowsContainerLogPluginConfFilePath = "/etc/omsagentwindows/out_oms.conf"

// IPName for Container Log
const IPName = "Containers"
const defaultContainerInventoryRefreshInterval = 60

const kubeMonAgentConfigEventFlushInterval = 60

//Eventsource name in mdsd
const MdsdSourceName = "ContainerLogSource"

//container logs route - v2 (v2=flush to oneagent, adx= flush to adx ingestion, anything else flush to ODS[default])
const ContainerLogsV2Route = "v2"

const ContainerLogsADXRoute = "adx"

var (
	// PluginConfiguration the plugins configuration
	PluginConfiguration map[string]string
	// HTTPClient for making POST requests to OMSEndpoint
	HTTPClient http.Client
	// Client for MDSD msgp Unix socket
	MdsdMsgpUnixSocketClient net.Conn
	// Ingestor for ADX
	ADXIngestor *ingest.Ingestion
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
	//KubeMonAgentEvents skip first flush
	skipKubeMonEventsFlush bool
	// enrich container logs (when true this will add the fields - timeofcommand, containername & containerimage)
	enrichContainerLogs bool
	// container runtime engine configured on the kubelet
	containerRuntime string
	// Proxy endpoint in format http(s)://<user>:<pwd>@<proxyserver>:<port>
	ProxyEndpoint string
	// container log route for routing thru oneagent
	ContainerLogsRouteV2 bool
	// container log route for routing thru ADX
	ContainerLogsRouteADX bool
	//ADX Cluster URI
	AdxClusterUri string
	// ADX clientID
	AdxClientID string
	// ADX tenantID
	AdxTenantID string
	//ADX client secret
	AdxClientSecret string
)

var (
	// ImageIDMap caches the container id to image mapping
	ImageIDMap map[string]string
	// NameIDMap caches the container it to Name mapping
	NameIDMap map[string]string
	// StdoutIgnoreNamespaceSet set of  excluded K8S namespaces for stdout logs
	StdoutIgnoreNsSet map[string]bool
	// StderrIgnoreNamespaceSet set of  excluded K8S namespaces for stderr logs
	StderrIgnoreNsSet map[string]bool
	// DataUpdateMutex read and write mutex access to the container id set
	DataUpdateMutex = &sync.Mutex{}
	// ContainerLogTelemetryMutex read and write mutex access to the Container Log Telemetry
	ContainerLogTelemetryMutex = &sync.Mutex{}
	// ClientSet for querying KubeAPIs
	ClientSet *kubernetes.Clientset
	// Config error hash
	ConfigErrorEvent map[string]KubeMonAgentEventTags
	// Prometheus scraping error hash
	PromScrapeErrorEvent map[string]KubeMonAgentEventTags
	// EventHashUpdateMutex read and write mutex access to the event hash
	EventHashUpdateMutex = &sync.Mutex{}
	// parent context used by ADX uploader
	ParentContext = context.Background()
)

var (
	// ContainerImageNameRefreshTicker updates the container image and names periodically
	ContainerImageNameRefreshTicker *time.Ticker
	// KubeMonAgentConfigEventsSendTicker to send config events every hour
	KubeMonAgentConfigEventsSendTicker *time.Ticker
)

var (
	// FLBLogger stream
	FLBLogger = createLogger()
	// Log wrapper function
	Log = FLBLogger.Printf
)

var (
	dockerCimprovVersion = "9.0.0.0"
	agentName            = "ContainerAgent"
	userAgent            = ""
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

type DataItemADX struct {
	TimeGenerated string `json:"TimeGenerated"`
	Computer      string `json:"Computer"`
	ContainerID   string `json:"ContainerID"`
	ContainerName string `json:"ContainerName"`
	PodName       string `json:"PodName"`
	PodNamespace  string `json:"PodNamespace"`
	LogMessage    string `json:"LogMessage"`
	LogSource     string `json:"LogSource"`
	//PodLabels			  string `json:"PodLabels"`
	AzureResourceId string `json:"AzureResourceId"`
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

type appMapOsmRequestMetric struct {
	time                  string  `json:"time"`
	Id                    string  `json:"Id"`
	Source                string  `json:"Source"`
	Name                  string  `json:"Name"`
	Url                   string  `json:"Url"`
	Success               bool    `json:"Success"`
	ResultCode            string  `json:"ResultCode"`
	DurationMs            float64 `json:"DurationMs"`
	PerformanceBucket     string  `json:"PerformanceBucket"`
	Properties            string  `json:"Properties"`
	Measurements          string  `json:"Measurements"`
	OperationName         string  `json:"OperationName"`
	OperationId           string  `json:"OperationId"`
	ParentId              string  `json:"ParentId"`
	SyntheticSource       string  `json:"SyntheticSource"`
	SessionId             string  `json:"SessionId"`
	UserId                string  `json:"UserId"`
	UserAuthenticatedId   string  `json:"UserAuthenticatedId"`
	UserAccountId         string  `json:"UserAccountId"`
	AppVersion            string  `json:"AppVersion"`
	AppRoleName           string  `json:"AppRoleName"`
	AppRoleInstance       string  `json:"AppRoleInstance"`
	ClientType            string  `json:"ClientType"`
	ClientModel           string  `json:"ClientModel"`
	ClientOS              string  `json:"ClientOS"`
	ClientIP              string  `json:"ClientIP"`
	ClientCity            string  `json:"ClientCity"`
	ClientStateOrProvince string  `json:"ClientStateOrProvince"`
	ClientCountryOrRegion string  `json:"ClientCountryOrRegion"`
	ClientBrowser         string  `json:"ClientBrowser"`
	ResourceGUID          string  `json:"ResourceGUID"`
	IKey                  string  `json:"IKey"`
	SDKVersion            string  `json:"SDKVersion"`
	ItemCount             int64   `json:"ItemCount"`
	ReferencedItemId      string  `json:"ReferencedItemId"`
	ReferencedType        string  `json:"ReferencedType"`
}

type appMapOsmDependencyMetric struct {
	time                  string  `json:"time"`
	Id                    string  `json:"Id"`
	Target                string  `json:"Target"`
	DependencyType        string  `json:"DependencyType"`
	Name                  string  `json:"Name"`
	Data                  string  `json:"Data"`
	Success               bool    `json:"Success"`
	ResultCode            string  `json:"ResultCode"`
	DurationMs            float64 `json:"DurationMs"`
	PerformanceBucket     string  `json:"PerformanceBucket"`
	Properties            string  `json:"Properties"`
	Measurements          string  `json:"Measurements"`
	OperationName         string  `json:"OperationName"`
	OperationId           string  `json:"OperationId"`
	ParentId              string  `json:"ParentId"`
	SyntheticSource       string  `json:"SyntheticSource"`
	SessionId             string  `json:"SessionId"`
	UserId                string  `json:"UserId"`
	UserAuthenticatedId   string  `json:"UserAuthenticatedId"`
	UserAccountId         string  `json:"UserAccountId"`
	AppVersion            string  `json:"AppVersion"`
	AppRoleName           string  `json:"AppRoleName"`
	AppRoleInstance       string  `json:"AppRoleInstance"`
	ClientType            string  `json:"ClientType"`
	ClientModel           string  `json:"ClientModel"`
	ClientOS              string  `json:"ClientOS"`
	ClientIP              string  `json:"ClientIP"`
	ClientCity            string  `json:"ClientCity"`
	ClientStateOrProvince string  `json:"ClientStateOrProvince"`
	ClientCountryOrRegion string  `json:"ClientCountryOrRegion"`
	ClientBrowser         string  `json:"ClientBrowser"`
	ResourceGUID          string  `json:"ResourceGUID"`
	IKey                  string  `json:"IKey"`
	SDKVersion            string  `json:"SDKVersion"`
	ItemCount             int64   `json:"ItemCount"`
	ReferencedItemId      string  `json:"ReferencedItemId"`
	ReferencedType        string  `json:"ReferencedType"`
}

// ContainerLogBlob represents the object corresponding to the payload that is sent to the ODS end point
type InsightsMetricsBlob struct {
	DataType  string             `json:"DataType"`
	IPName    string             `json:"IPName"`
	DataItems []laTelegrafMetric `json:"DataItems"`
}

type AppMapOsmRequestBlob struct {
	DataType  string                   `json:"DataType"`
	IPName    string                   `json:"IPName"`
	DataItems []appMapOsmRequestMetric `json:"DataItems"`
}

type AppMapOsmDependencyBlob struct {
	DataType  string                      `json:"DataType"`
	IPName    string                      `json:"IPName"`
	DataItems []appMapOsmDependencyMetric `json:"DataItems"`
}

// ContainerLogBlob represents the object corresponding to the payload that is sent to the ODS end point
type ContainerLogBlob struct {
	DataType  string     `json:"DataType"`
	IPName    string     `json:"IPName"`
	DataItems []DataItem `json:"DataItems"`
}

// MsgPackEntry represents the object corresponding to a single messagepack event in the messagepack stream
type MsgPackEntry struct {
	Time   int64             `msg:"time"`
	Record map[string]string `msg:"record"`
}

//MsgPackForward represents a series of messagepack events in Forward Mode
type MsgPackForward struct {
	Tag     string         `msg:"tag"`
	Entries []MsgPackEntry `msg:"entries"`
	//Option  interface{}  //intentionally commented out as we do not have any optional keys
}

// Config Error message to be sent to Log Analytics
type laKubeMonAgentEvents struct {
	Computer       string `json:"Computer"`
	CollectionTime string `json:"CollectionTime"` //mapped to TimeGenerated
	Category       string `json:"Category"`
	Level          string `json:"Level"`
	ClusterId      string `json:"ClusterId"`
	ClusterName    string `json:"ClusterName"`
	Message        string `json:"Message"`
	Tags           string `json:"Tags"`
}

type KubeMonAgentEventTags struct {
	PodName         string
	ContainerId     string
	FirstOccurrence string
	LastOccurrence  string
	Count           int
}

type KubeMonAgentEventBlob struct {
	DataType  string                 `json:"DataType"`
	IPName    string                 `json:"IPName"`
	DataItems []laKubeMonAgentEvents `json:"DataItems"`
}

// KubeMonAgentEventType to be used as enum
type KubeMonAgentEventType int

const (
	// KubeMonAgentEventType to be used as enum for ConfigError and ScrapingError
	ConfigError KubeMonAgentEventType = iota
	PromScrapingError
)

func createLogger() *log.Logger {
	var logfile *os.File

	osType := os.Getenv("OS_TYPE")

	var logPath string

	if strings.Compare(strings.ToLower(osType), "windows") != 0 {
		logPath = "/var/opt/microsoft/docker-cimprov/log/fluent-bit-out-oms-runtime.log"
	} else {
		logPath = "/etc/omsagentwindows/fluent-bit-out-oms-runtime.log"
	}

	if _, err := os.Stat(logPath); err == nil {
		fmt.Printf("File Exists. Opening file in append mode...\n")
		logfile, err = os.OpenFile(logPath, os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			SendException(err.Error())
			fmt.Printf(err.Error())
		}
	}

	if _, err := os.Stat(logPath); os.IsNotExist(err) {
		fmt.Printf("File Doesnt Exist. Creating file...\n")
		logfile, err = os.Create(logPath)
		if err != nil {
			SendException(err.Error())
			fmt.Printf(err.Error())
		}
	}

	logger := log.New(logfile, "", 0)

	logger.SetOutput(&lumberjack.Logger{
		Filename:   logPath,
		MaxSize:    10, //megabytes
		MaxBackups: 1,
		MaxAge:     28,   //days
		Compress:   true, // false by default
	})

	logger.SetFlags(log.Ltime | log.Lshortfile | log.LstdFlags)
	return logger
}

// newUUID generates a random UUID according to RFC 4122
// func newUUID() (string, error) {
// 	uuid := make([]byte, 16)
// 	n, err := io.ReadFull(rand.Reader, uuid)
// 	if n != len(uuid) || err != nil {
// 		return "", err
// 	}
// 	// variant bits; see section 4.1.1
// 	uuid[8] = uuid[8]&^0xc0 | 0x80
// 	// version 4 (pseudo-random); see section 4.1.3
// 	uuid[6] = uuid[6]&^0xf0 | 0x40
// 	return fmt.Sprintf("%x-%x-%x-%x-%x", uuid[0:4], uuid[4:6], uuid[6:8], uuid[8:10], uuid[10:]), nil
// }

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
			continue
		}

		for _, pod := range pods.Items {
			podContainerStatuses := pod.Status.ContainerStatuses

			// Doing this to include init container logs as well
			podInitContainerStatuses := pod.Status.InitContainerStatuses
			if (podInitContainerStatuses != nil) && (len(podInitContainerStatuses) > 0) {
				podContainerStatuses = append(podContainerStatuses, podInitContainerStatuses...)
			}
			for _, status := range podContainerStatuses {
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

func populateExcludedStdoutNamespaces() {
	collectStdoutLogs := os.Getenv("AZMON_COLLECT_STDOUT_LOGS")
	var stdoutNSExcludeList []string
	excludeList := os.Getenv("AZMON_STDOUT_EXCLUDED_NAMESPACES")
	if (strings.Compare(collectStdoutLogs, "true") == 0) && (len(excludeList) > 0) {
		stdoutNSExcludeList = strings.Split(excludeList, ",")
		for _, ns := range stdoutNSExcludeList {
			Log("Excluding namespace %s for stdout log collection", ns)
			StdoutIgnoreNsSet[strings.TrimSpace(ns)] = true
		}
	}
}

func populateExcludedStderrNamespaces() {
	collectStderrLogs := os.Getenv("AZMON_COLLECT_STDERR_LOGS")
	var stderrNSExcludeList []string
	excludeList := os.Getenv("AZMON_STDERR_EXCLUDED_NAMESPACES")
	if (strings.Compare(collectStderrLogs, "true") == 0) && (len(excludeList) > 0) {
		stderrNSExcludeList = strings.Split(excludeList, ",")
		for _, ns := range stderrNSExcludeList {
			Log("Excluding namespace %s for stderr log collection", ns)
			StderrIgnoreNsSet[strings.TrimSpace(ns)] = true
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

// PostConfigErrorstoLA sends config/prometheus scraping error log lines to LA
func populateKubeMonAgentEventHash(record map[interface{}]interface{}, errType KubeMonAgentEventType) {
	var logRecordString = ToString(record["log"])
	var eventTimeStamp = ToString(record["time"])
	containerID, _, podName, _ := GetContainerIDK8sNamespacePodNameFromFileName(ToString(record["filepath"]))

	Log("Locked EventHashUpdateMutex for updating hash \n ")
	EventHashUpdateMutex.Lock()
	switch errType {
	case ConfigError:
		// Doing this since the error logger library is adding quotes around the string and a newline to the end because
		// we are converting string to json to log lines in different lines as one record
		logRecordString = strings.TrimSuffix(logRecordString, "\n")
		logRecordString = logRecordString[1 : len(logRecordString)-1]

		if val, ok := ConfigErrorEvent[logRecordString]; ok {
			Log("In config error existing hash update\n")
			eventCount := val.Count
			eventFirstOccurrence := val.FirstOccurrence

			ConfigErrorEvent[logRecordString] = KubeMonAgentEventTags{
				PodName:         podName,
				ContainerId:     containerID,
				FirstOccurrence: eventFirstOccurrence,
				LastOccurrence:  eventTimeStamp,
				Count:           eventCount + 1,
			}
		} else {
			ConfigErrorEvent[logRecordString] = KubeMonAgentEventTags{
				PodName:         podName,
				ContainerId:     containerID,
				FirstOccurrence: eventTimeStamp,
				LastOccurrence:  eventTimeStamp,
				Count:           1,
			}
		}

	case PromScrapingError:
		// Splitting this based on the string 'E! [inputs.prometheus]: ' since the log entry has timestamp and we want to remove that before building the hash
		var scrapingSplitString = strings.Split(logRecordString, "E! [inputs.prometheus]: ")
		if scrapingSplitString != nil && len(scrapingSplitString) == 2 {
			var splitString = scrapingSplitString[1]
			// Trimming the newline character at the end since this is being added as the key
			splitString = strings.TrimSuffix(splitString, "\n")
			if splitString != "" {
				if val, ok := PromScrapeErrorEvent[splitString]; ok {
					Log("In config error existing hash update\n")
					eventCount := val.Count
					eventFirstOccurrence := val.FirstOccurrence

					PromScrapeErrorEvent[splitString] = KubeMonAgentEventTags{
						PodName:         podName,
						ContainerId:     containerID,
						FirstOccurrence: eventFirstOccurrence,
						LastOccurrence:  eventTimeStamp,
						Count:           eventCount + 1,
					}
				} else {
					PromScrapeErrorEvent[splitString] = KubeMonAgentEventTags{
						PodName:         podName,
						ContainerId:     containerID,
						FirstOccurrence: eventTimeStamp,
						LastOccurrence:  eventTimeStamp,
						Count:           1,
					}
				}
			}
		}
	}
	EventHashUpdateMutex.Unlock()
	Log("Unlocked EventHashUpdateMutex after updating hash \n ")
}

// Function to get config error log records after iterating through the two hashes
func flushKubeMonAgentEventRecords() {
	for ; true; <-KubeMonAgentConfigEventsSendTicker.C {
		if skipKubeMonEventsFlush != true {
			Log("In flushConfigErrorRecords\n")
			start := time.Now()
			var elapsed time.Duration
			var laKubeMonAgentEventsRecords []laKubeMonAgentEvents
			telemetryDimensions := make(map[string]string)

			telemetryDimensions["ConfigErrorEventCount"] = strconv.Itoa(len(ConfigErrorEvent))
			telemetryDimensions["PromScrapeErrorEventCount"] = strconv.Itoa(len(PromScrapeErrorEvent))

			if (len(ConfigErrorEvent) > 0) || (len(PromScrapeErrorEvent) > 0) {
				EventHashUpdateMutex.Lock()
				Log("Locked EventHashUpdateMutex for reading hashes\n")
				for k, v := range ConfigErrorEvent {
					tagJson, err := json.Marshal(v)

					if err != nil {
						message := fmt.Sprintf("Error while Marshalling config error event tags: %s", err.Error())
						Log(message)
						SendException(message)
					} else {
						laKubeMonAgentEventsRecord := laKubeMonAgentEvents{
							Computer:       Computer,
							CollectionTime: start.Format(time.RFC3339),
							Category:       ConfigErrorEventCategory,
							Level:          KubeMonAgentEventError,
							ClusterId:      ResourceID,
							ClusterName:    ResourceName,
							Message:        k,
							Tags:           fmt.Sprintf("%s", tagJson),
						}
						laKubeMonAgentEventsRecords = append(laKubeMonAgentEventsRecords, laKubeMonAgentEventsRecord)
					}
				}

				for k, v := range PromScrapeErrorEvent {
					tagJson, err := json.Marshal(v)
					if err != nil {
						message := fmt.Sprintf("Error while Marshalling prom scrape error event tags: %s", err.Error())
						Log(message)
						SendException(message)
					} else {
						laKubeMonAgentEventsRecord := laKubeMonAgentEvents{
							Computer:       Computer,
							CollectionTime: start.Format(time.RFC3339),
							Category:       PromScrapingErrorEventCategory,
							Level:          KubeMonAgentEventWarning,
							ClusterId:      ResourceID,
							ClusterName:    ResourceName,
							Message:        k,
							Tags:           fmt.Sprintf("%s", tagJson),
						}
						laKubeMonAgentEventsRecords = append(laKubeMonAgentEventsRecords, laKubeMonAgentEventsRecord)
					}
				}

				//Clearing out the prometheus scrape hash so that it can be rebuilt with the errors in the next hour
				for k := range PromScrapeErrorEvent {
					delete(PromScrapeErrorEvent, k)
				}
				Log("PromScrapeErrorEvent cache cleared\n")
				EventHashUpdateMutex.Unlock()
				Log("Unlocked EventHashUpdateMutex for reading hashes\n")
			} else {
				//Sending a record in case there are no errors to be able to differentiate between no data vs no errors
				tagsValue := KubeMonAgentEventTags{}

				tagJson, err := json.Marshal(tagsValue)
				if err != nil {
					message := fmt.Sprintf("Error while Marshalling no error tags: %s", err.Error())
					Log(message)
					SendException(message)
				} else {
					laKubeMonAgentEventsRecord := laKubeMonAgentEvents{
						Computer:       Computer,
						CollectionTime: start.Format(time.RFC3339),
						Category:       NoErrorEventCategory,
						Level:          KubeMonAgentEventInfo,
						ClusterId:      ResourceID,
						ClusterName:    ResourceName,
						Message:        "No errors",
						Tags:           fmt.Sprintf("%s", tagJson),
					}
					laKubeMonAgentEventsRecords = append(laKubeMonAgentEventsRecords, laKubeMonAgentEventsRecord)
				}
			}

			if len(laKubeMonAgentEventsRecords) > 0 {
				kubeMonAgentEventEntry := KubeMonAgentEventBlob{
					DataType:  KubeMonAgentEventDataType,
					IPName:    IPName,
					DataItems: laKubeMonAgentEventsRecords}

				marshalled, err := json.Marshal(kubeMonAgentEventEntry)

				if err != nil {
					message := fmt.Sprintf("Error while marshalling kubemonagentevent entry: %s", err.Error())
					Log(message)
					SendException(message)
				} else {
					req, _ := http.NewRequest("POST", OMSEndpoint, bytes.NewBuffer(marshalled))
					req.Header.Set("Content-Type", "application/json")
					req.Header.Set("User-Agent", userAgent)
					reqId := uuid.New().String()
					req.Header.Set("X-Request-ID", reqId)
					//expensive to do string len for every request, so use a flag
					if ResourceCentric == true {
						req.Header.Set("x-ms-AzureResourceId", ResourceID)
					}

					resp, err := HTTPClient.Do(req)
					elapsed = time.Since(start)

					if err != nil {
						message := fmt.Sprintf("Error when sending kubemonagentevent request %s \n", err.Error())
						Log(message)
						Log("Failed to flush %d records after %s", len(laKubeMonAgentEventsRecords), elapsed)
					} else if resp == nil || resp.StatusCode != 200 {
						if resp != nil {
							Log("flushKubeMonAgentEventRecords: RequestId %s Status %s Status Code %d", reqId, resp.Status, resp.StatusCode)
						}
						Log("Failed to flush %d records after %s", len(laKubeMonAgentEventsRecords), elapsed)
					} else {
						numRecords := len(laKubeMonAgentEventsRecords)
						Log("FlushKubeMonAgentEventRecords::Info::Successfully flushed %d records in %s", numRecords, elapsed)

						// Send telemetry to AppInsights resource
						SendEvent(KubeMonAgentEventsFlushedEvent, telemetryDimensions)

					}
					if resp != nil && resp.Body != nil {
						defer resp.Body.Close()
					}
				}
			}
		} else {
			// Setting this to false to allow for subsequent flushes after the first hour
			skipKubeMonEventsFlush = false
		}
	}
}

//Translates telegraf time series to one or more Azure loganalytics metric(s)
func translateTelegrafMetrics(m map[interface{}]interface{}) ([]*laTelegrafMetric, []*appMapOsmRequestMetric, []*appMapOsmDependencyMetric, error) {
	var laMetrics []*laTelegrafMetric
	var appMapOsmRequestMetrics []*appMapOsmRequestMetric
	var appMapOsmDependencyMetrics []*appMapOsmDependencyMetric
	var tags map[interface{}]interface{}
	// string appName
	// string destinationAppName
	// string id
	// string operationId
	tags = m["tags"].(map[interface{}]interface{})
	tagMap := make(map[string]string)
	metricNamespace := fmt.Sprintf("%s", m["name"])
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
		return nil, nil, nil, err
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

		// OSM metric population for AppMap
		metricName := fmt.Sprintf("%s", k)
		propertyMap := make(map[string]string)
		propertyMap[fmt.Sprintf("DeploymentId")] = "523a92fea186461581efca83b7b66a0d"
		propertyMap[fmt.Sprintf("Stamp")] = "Breeze-INT-SCUS"
		propertiesJson, err := json.Marshal(&propertyMap)

		if err != nil {
			return nil, nil, nil, err
		}

		measurementsMap := make(map[string]string)
		measurementsMap[fmt.Sprintf("AvailableMemory")] = "423"
		measurementsJson, err := json.Marshal(&measurementsMap)

		if err != nil {
			return nil, nil, nil, err
		}

		if (metricName == "envoy_cluster_upstream_rq_active") && (strings.HasPrefix(metricNamespace, "container.azm.ms.osm")) {
			if fv > 0 {
				appName := tagMap["app"]
				destinationAppName := tagMap["envoy_cluster_name"]
				itemCount := int64(1)
				success := true
				// durationMs := float64(1.0)
				operationId := uuid.New().String()
				// if err != nil {
				// 	Log("translateTelegrafMetrics::error while generating operationId GUID: %v\n", err)
				// }
				// Log("translateTelegrafMetrics::%s\n", operationId)

				id := uuid.New().String()
				// if err != nil {
				// 	Log("translateTelegrafMetrics::error while generating id GUID: %v\n", err)
				// }
				Log("translateTelegrafMetrics::%s\n", id)
				collectionTimeValue := m["timestamp"].(uint64)
				osmRequestMetric := appMapOsmRequestMetric{
					// Absolutely needed metrics for topology generation for AppMap
					time:        time.Unix(int64(collectionTimeValue), 0).Format(time.RFC3339),
					OperationId: fmt.Sprintf("%s", operationId),
					ParentId:    fmt.Sprintf("%s", id),
					AppRoleName: fmt.Sprintf("%s", destinationAppName),
					DurationMs:  898.42,
					Success:     success,
					ItemCount:   42,
					//metrics to get ingestion working
					Id:                    fmt.Sprintf("%s", "8be927b9-0bde-4357-87ee-73c13b6f6a05"),
					Source:                fmt.Sprintf("%s", "Application"),
					Name:                  fmt.Sprintf("%s", "TestData-Request-DataGen"),
					Url:                   fmt.Sprintf("%s", "https://portal.azure.com"),
					ResultCode:            fmt.Sprintf("%s", "200"),
					PerformanceBucket:     fmt.Sprintf("%s", "500ms-1sec"),
					Properties:            fmt.Sprintf("%s", propertiesJson),
					Measurements:          fmt.Sprintf("%s", measurementsJson),
					OperationName:         fmt.Sprintf("%s", "POST /v2/passthrough"),
					SyntheticSource:       fmt.Sprintf("%s", "Windows"),
					SessionId:             fmt.Sprintf("%s", "e357297720214cdc818565f89cfad359"),
					UserId:                fmt.Sprintf("%s", "5bfb5187ff9742fbaec5b19dd7217f40"),
					UserAuthenticatedId:   fmt.Sprintf("%s", "somebody@microsoft.com"),
					UserAccountId:         fmt.Sprintf("%s", "e357297720214cdc818565f89cfad359"),
					AppVersion:            fmt.Sprintf("%s", "4.2-alpha"),
					AppRoleInstance:       fmt.Sprintf("%s", "Breeze_IN_42"),
					ClientType:            fmt.Sprintf("%s", "PC"),
					ClientModel:           fmt.Sprintf("%s", "Other"),
					ClientOS:              fmt.Sprintf("%s", "Windows 7"),
					ClientIP:              fmt.Sprintf("%s", "0.0.0.0"),
					ClientCity:            fmt.Sprintf("%s", "Sydney"),
					ClientStateOrProvince: fmt.Sprintf("%s", "New South Wales"),
					ClientCountryOrRegion: fmt.Sprintf("%s", "Australia"),
					ClientBrowser:         fmt.Sprintf("%s", "Internet Explorer 9.0"),
					ResourceGUID:          fmt.Sprintf("%s", "d4e6868c-02e8-41d2-a09d-bbb5ae35af5c"),
					IKey:                  fmt.Sprintf("%s", "0539013c-a321-46fd-b831-1cc16729b449"),
					SDKVersion:            fmt.Sprintf("%s", "dotnet:2.2.0-54037"),
					ReferencedItemId:      fmt.Sprintf("%s", "905812ce-48c3-44ee-ab93-33e8768f59f9"),
					ReferencedType:        fmt.Sprintf("%s", "IoTRequests"),
					// Computer:       Computer, //this is the collection agent's computer name, not necessarily to which computer the metric applies to
				}

				Log("osm request metric:%v", osmRequestMetric)
				appMapOsmRequestMetrics = append(appMapOsmRequestMetrics, &osmRequestMetric)

				osmDependencyMetric := appMapOsmDependencyMetric{
					// Absolutely needed metrics for topology generation for AppMap
					time:        time.Unix(int64(collectionTimeValue), 0).Format(time.RFC3339),
					Id:          fmt.Sprintf("%s", id),
					Target:      fmt.Sprintf("%s", destinationAppName),
					Success:     success,
					DurationMs:  898.42,
					OperationId: fmt.Sprintf("%s", operationId),
					AppRoleName: fmt.Sprintf("%s", appName),
					ItemCount:   itemCount,
					//metrics to get ingestion working
					DependencyType:        fmt.Sprintf("%s", "Ajax"),
					Name:                  fmt.Sprintf("%s", "TestData-Request-DataGen"),
					Data:                  fmt.Sprintf("%s", "GET https://n9440-fpj.gmbeelopm.com/HhjmlogpEhiLLL/ECO//GhoppnaBeAelhaekm/3944-40-42J92:22:19.750D/MehgKepmpnlegoDboghnMaedd"),
					ResultCode:            fmt.Sprintf("%s", "200"),
					PerformanceBucket:     fmt.Sprintf("%s", "500ms-1sec"),
					Properties:            fmt.Sprintf("%s", propertiesJson),
					Measurements:          fmt.Sprintf("%s", measurementsJson),
					OperationName:         fmt.Sprintf("%s", "POST /v2/passthrough"),
					ParentId:              fmt.Sprintf("%s", "b1bb1e27-4204-096e-9e89-1f1dfac718fc"),
					SyntheticSource:       fmt.Sprintf("%s", "Windows"),
					SessionId:             fmt.Sprintf("%s", "e357297720214cdc818565f89cfad359"),
					UserId:                fmt.Sprintf("%s", "5bfb5187ff9742fbaec5b19dd7217f40"),
					UserAuthenticatedId:   fmt.Sprintf("%s", "somebody@microsoft.com"),
					UserAccountId:         fmt.Sprintf("%s", "e357297720214cdc818565f89cfad359"),
					AppVersion:            fmt.Sprintf("%s", "4.2-alpha"),
					AppRoleInstance:       fmt.Sprintf("%s", "Breeze_IN_42"),
					ClientType:            fmt.Sprintf("%s", "PC"),
					ClientModel:           fmt.Sprintf("%s", "Other"),
					ClientOS:              fmt.Sprintf("%s", "Windows 7"),
					ClientIP:              fmt.Sprintf("%s", "0.0.0.0"),
					ClientCity:            fmt.Sprintf("%s", "Sydney"),
					ClientStateOrProvince: fmt.Sprintf("%s", "New South Wales"),
					ClientCountryOrRegion: fmt.Sprintf("%s", "Australia"),
					ClientBrowser:         fmt.Sprintf("%s", "Internet Explorer 9.0"),
					ResourceGUID:          fmt.Sprintf("%s", "d4e6868c-02e8-41d2-a09d-bbb5ae35af5c"),
					IKey:                  fmt.Sprintf("%s", "0539013c-a321-46fd-b831-1cc16729b449"),
					SDKVersion:            fmt.Sprintf("%s", "dotnet:2.2.0-54037"),
					ReferencedItemId:      fmt.Sprintf("%s", "905812ce-48c3-44ee-ab93-33e8768f59f9"),
					ReferencedType:        fmt.Sprintf("%s", "IoTRequests"),
				}

				Log("osm dependency metric:%v", osmDependencyMetric)
				appMapOsmDependencyMetrics = append(appMapOsmDependencyMetrics, &osmDependencyMetric)
			}
		}
	}
	return laMetrics, appMapOsmRequestMetrics, appMapOsmDependencyMetrics, nil
}

// send metrics from Telegraf to LA. 1) Translate telegraf timeseries to LA metric(s) 2) Send it to LA as 'InsightsMetrics' fixed type
func PostTelegrafMetricsToLA(telegrafRecords []map[interface{}]interface{}) int {
	var laMetrics []*laTelegrafMetric
	var appMapOsmRequestMetrics []*appMapOsmRequestMetric
	var appMapOsmDependencyMetrics []*appMapOsmDependencyMetric

	if (telegrafRecords == nil) || !(len(telegrafRecords) > 0) {
		Log("PostTelegrafMetricsToLA::Error:no timeseries to derive")
		return output.FLB_OK
	}

	for _, record := range telegrafRecords {
		translatedMetrics, osmRequestMetrics, osmDependencyMetrics, err := translateTelegrafMetrics(record)
		if err != nil {
			message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:when translating telegraf metric to log analytics metric %q", err)
			Log(message)
			//SendException(message) //This will be too noisy
		}
		laMetrics = append(laMetrics, translatedMetrics...)
		appMapOsmRequestMetrics = append(appMapOsmRequestMetrics, osmRequestMetrics...)
		appMapOsmDependencyMetrics = append(appMapOsmDependencyMetrics, osmDependencyMetrics...)
	}

	if (laMetrics == nil) || !(len(laMetrics) > 0) {
		Log("PostTelegrafMetricsToLA::Info:no metrics derived from timeseries data")
		return output.FLB_OK
	} else {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Info:derived %v metrics from %v timeseries", len(laMetrics), len(telegrafRecords))
		Log(message)
	}

	if (appMapOsmRequestMetrics == nil) || !(len(appMapOsmRequestMetrics) > 0) {
		Log("PostTelegrafMetricsToLA::Info:no OSM request metrics derived from timeseries data")
		return output.FLB_OK
	} else {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Info:derived osm request %v metrics from %v timeseries", len(appMapOsmRequestMetrics), len(telegrafRecords))
		Log(message)
	}

	if (appMapOsmDependencyMetrics == nil) || !(len(appMapOsmDependencyMetrics) > 0) {
		Log("PostTelegrafMetricsToLA::Info:no OSM dependency metrics derived from timeseries data")
		return output.FLB_OK
	} else {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Info:derived osm dependency %v metrics from %v timeseries", len(appMapOsmDependencyMetrics), len(telegrafRecords))
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
	//Log("laTelegrafMetrics-json:%v", laTelegrafMetrics)

	if err != nil {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:when marshalling json %q", err)
		Log(message)
		SendException(message)
		return output.FLB_OK
	}

	//Post metrics data to LA
	req, _ := http.NewRequest("POST", OMSEndpoint, bytes.NewBuffer(jsonBytes))
	//Log("LA request json bytes: %v", jsonBytes)
	//req.URL.Query().Add("api-version","2016-04-01")

	//set headers
	req.Header.Set("x-ms-date", time.Now().Format(time.RFC3339))
	req.Header.Set("User-Agent", userAgent)
	reqID := uuid.New().String()
	req.Header.Set("X-Request-ID", reqID)

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
		UpdateNumTelegrafMetricsSentTelemetry(0, 1, 0)
		return output.FLB_RETRY
	}

	if resp == nil || resp.StatusCode != 200 {
		if resp != nil {
			Log("PostTelegrafMetricsToLA::Error:(retriable) RequestID %s Response Status %v Status Code %v", reqID, resp.Status, resp.StatusCode)
		}
		if resp != nil && resp.StatusCode == 429 {
			UpdateNumTelegrafMetricsSentTelemetry(0, 1, 1)
		}
		return output.FLB_RETRY
	}

	defer resp.Body.Close()

	numMetrics := len(laMetrics)
	UpdateNumTelegrafMetricsSentTelemetry(numMetrics, 0, 0)
	Log("PostTelegrafMetricsToLA::Info:LArequests:Http Request: %v", req)
	Log("PostTelegrafMetricsToLA::Info:Successfully flushed %v records in %v", numMetrics, elapsed)

	// AppMap Requests
	var requestMetrics []appMapOsmRequestMetric
	var j int

	for j = 0; j < len(appMapOsmRequestMetrics); j++ {
		requestMetrics = append(requestMetrics, *appMapOsmRequestMetrics[j])
	}

	osmRequestMetrics := AppMapOsmRequestBlob{
		DataType:  AppRequestsDataType,
		IPName:    "LogManagement",
		DataItems: requestMetrics}

	requestJsonBytes, err := json.Marshal(osmRequestMetrics)
	//Log("app request json bytes: %v", requestJsonBytes)

	if err != nil {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:when marshalling app requests json %q", err)
		Log(message)
		SendException(message)
		return output.FLB_OK
	}
	Log("AppMapOSMRequestMetrics-json:%v", osmRequestMetrics)

	//Post metrics data to LA
	appRequestReq, _ := http.NewRequest("POST", OMSEndpoint, bytes.NewBuffer(requestJsonBytes))
	// appRequestReq, _ := http.NewRequest("POST", OMSEndpoint+"?api-version=2016-04-01", bytes.NewBuffer(requestJsonBytes))
	//appRequestReq, _ := http.NewRequest("POST", "https://dd513101-45ad-4dc0-b6dd-42d88361399e.ods.opinsights.azure.com/collector?api-version=2018-05-01", bytes.NewBuffer(requestJsonBytes))

	//appRequestReq.URL.Query().Add("api-version", "2016-04-01")

	//set headers
	appRequestReq.Header.Set("x-ms-date", time.Now().Format(time.RFC3339))
	appRequestReq.Header.Set("User-Agent", userAgent)
	//appRequestReq.Header.Set("Log-Type", AppRequestsDataType)
	appRequestReq.Header.Set("ocp-workspace-id", WorkspaceID)
	appRequestReq.Header.Set("ocp-is-dynamic-data-type", "False")
	appRequestReq.Header.Set("ocp-intelligence-pack-name", "Azure")
	appRequestReq.Header.Set("ocp-json-nesting-resolution", "records")
	appRequestReq.Header.Set("time-generated-field", time.Now().Format(time.RFC3339))
	appRequestReq.Header.Set("data-available-time", time.Now().Format(time.RFC3339))
	appRequestReq.Header.Set("x-ms-OboLocation", "North Europe")
	appRequestReq.Header.Set("x-ms-ServiceIdentity", "ApplicationInsights")
	appRequestReq.Header.Set("Content-Type", "application/json")
	// appRequestReq.Header.Set("Content-Encoding", "gzip")

	// appRequestReq.Header.Set("x-ms-ResourceLocation", "records")

	appRequestReqID := uuid.New().String()
	appRequestReq.Header.Set("X-Request-ID", appRequestReqID)

	//expensive to do string len for every request, so use a flag
	if ResourceCentric == true {
		appRequestReq.Header.Set("x-ms-AzureResourceId", ResourceID)
	}

	reqStart := time.Now()
	appRequestResp, err := HTTPClient.Do(appRequestReq)
	reqElapsed := time.Since(reqStart)

	if err != nil {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:(retriable) when sending apprequest %v metrics. duration:%v err:%q \n", len(appMapOsmRequestMetrics), reqElapsed, err.Error())
		Log(message)
		UpdateNumTelegrafMetricsSentTelemetry(0, 1, 0)
		return output.FLB_RETRY
	}

	if appRequestResp == nil || appRequestResp.StatusCode != 200 {
		if appRequestResp != nil {
			Log("PostTelegrafMetricsToLA::Error:(retriable) app requests RequestID %s Response Status %v Status Code %v", appRequestReqID, appRequestResp.Status, appRequestResp.StatusCode)
		}
		if appRequestResp != nil && appRequestResp.StatusCode == 429 {
			UpdateNumTelegrafMetricsSentTelemetry(0, 1, 1)
		}
		return output.FLB_RETRY
	}

	defer appRequestResp.Body.Close()

	appRequestNumMetrics := len(appMapOsmRequestMetrics)
	UpdateNumTelegrafMetricsSentTelemetry(appRequestNumMetrics, 0, 0)
	Log("PostTelegrafMetricsToLA::Info:AppRequests:Http Request: %v", appRequestReq)
	Log("PostTelegrafMetricsToLA::Info:AppRequests:Successfully flushed %v records in %v with status code %v", appRequestNumMetrics, reqElapsed, appRequestResp.StatusCode)

	// AppMap Dependencies
	var dependencyMetrics []appMapOsmDependencyMetric
	var myint int

	for myint = 0; myint < len(appMapOsmDependencyMetrics); myint++ {
		dependencyMetrics = append(dependencyMetrics, *appMapOsmDependencyMetrics[myint])
	}

	osmDependencyMetrics := AppMapOsmDependencyBlob{
		DataType:  AppDependenciesDataType,
		IPName:    "LogManagement",
		DataItems: dependencyMetrics}

	dependencyJsonBytes, err := json.Marshal(osmDependencyMetrics)
	Log("AppMapOSMDependencyMetrics-json:%v", osmDependencyMetrics)
	//Log("app dependency json bytes: %v", dependencyJsonBytes)

	if err != nil {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:when marshalling app dependencies json %q", err)
		Log(message)
		SendException(message)
		return output.FLB_OK
	}

	//Post metrics data to LA
	appDependencyReq, _ := http.NewRequest("POST", OMSEndpoint, bytes.NewBuffer(dependencyJsonBytes))

	//req.URL.Query().Add("api-version","2016-04-01")

	//set headers
	appDependencyReq.Header.Set("x-ms-date", time.Now().Format(time.RFC3339))
	appDependencyReq.Header.Set("User-Agent", userAgent)
	//appDependencyReq.Header.Set("Log-Type", AppDependenciesDataType)
	appDependencyReq.Header.Set("ocp-workspace-id", WorkspaceID)
	appDependencyReq.Header.Set("ocp-is-dynamic-data-type", "False")
	appDependencyReq.Header.Set("ocp-intelligence-pack-name", "Azure")
	appDependencyReq.Header.Set("ocp-json-nesting-resolution", "records")
	appDependencyReq.Header.Set("time-generated-field", time.Now().Format(time.RFC3339))
	appDependencyReq.Header.Set("data-available-time", time.Now().Format(time.RFC3339))
	appDependencyReq.Header.Set("x-ms-OboLocation", "North Europe")
	appDependencyReq.Header.Set("x-ms-ServiceIdentity", "ApplicationInsights")
	appDependencyReq.Header.Set("Content-Type", "application/json")
	appDependencyReqID := uuid.New().String()
	appDependencyReq.Header.Set("X-Request-ID", appDependencyReqID)

	//expensive to do string len for every request, so use a flag
	if ResourceCentric == true {
		appDependencyReq.Header.Set("x-ms-AzureResourceId", ResourceID)
	}

	depStart := time.Now()
	appDependencyResp, err := HTTPClient.Do(appDependencyReq)
	depElapsed := time.Since(depStart)

	if err != nil {
		message := fmt.Sprintf("PostTelegrafMetricsToLA::Error:(retriable) when sending appdependency %v metrics. duration:%v err:%q \n", len(appMapOsmDependencyMetrics), elapsed, err.Error())
		Log(message)
		UpdateNumTelegrafMetricsSentTelemetry(0, 1, 0)
		return output.FLB_RETRY
	}

	if appDependencyResp == nil || appDependencyResp.StatusCode != 200 {
		if appDependencyResp != nil {
			Log("PostTelegrafMetricsToLA::Error:(retriable) app dependency RequestID %s Response Status %v Status Code %v", appDependencyReqID, appDependencyResp.Status, appDependencyResp.StatusCode)
		}
		if appDependencyResp != nil && appDependencyResp.StatusCode == 429 {
			UpdateNumTelegrafMetricsSentTelemetry(0, 1, 1)
		}
		return output.FLB_RETRY
	}

	defer appDependencyResp.Body.Close()

	appDependencyNumMetrics := len(appMapOsmDependencyMetrics)
	UpdateNumTelegrafMetricsSentTelemetry(appDependencyNumMetrics, 0, 0)
	Log("PostTelegrafMetricsToLA::Info:AppDependency:Http Request: %v", appDependencyReq)
	Log("PostTelegrafMetricsToLA::Info:AppDependency:Successfully flushed %v records in %v with status code - %v", appDependencyNumMetrics, depElapsed, appDependencyResp.StatusCode)

	return output.FLB_OK
}

func UpdateNumTelegrafMetricsSentTelemetry(numMetricsSent int, numSendErrors int, numSend429Errors int) {
	ContainerLogTelemetryMutex.Lock()
	TelegrafMetricsSentCount += float64(numMetricsSent)
	TelegrafMetricsSendErrorCount += float64(numSendErrors)
	TelegrafMetricsSend429ErrorCount += float64(numSend429Errors)
	ContainerLogTelemetryMutex.Unlock()
}

// PostDataHelper sends data to the ODS endpoint or oneagent or ADX
func PostDataHelper(tailPluginRecords []map[interface{}]interface{}) int {
	start := time.Now()
	var dataItems []DataItem
	var dataItemsADX []DataItemADX

	var msgPackEntries []MsgPackEntry
	var stringMap map[string]string
	var elapsed time.Duration

	var maxLatency float64
	var maxLatencyContainer string

	imageIDMap := make(map[string]string)
	nameIDMap := make(map[string]string)

	DataUpdateMutex.Lock()

	for k, v := range ImageIDMap {
		imageIDMap[k] = v
	}
	for k, v := range NameIDMap {
		nameIDMap[k] = v
	}
	DataUpdateMutex.Unlock()

	for _, record := range tailPluginRecords {
		containerID, k8sNamespace, k8sPodName, containerName := GetContainerIDK8sNamespacePodNameFromFileName(ToString(record["filepath"]))
		logEntrySource := ToString(record["stream"])

		if strings.EqualFold(logEntrySource, "stdout") {
			if containerID == "" || containsKey(StdoutIgnoreNsSet, k8sNamespace) {
				continue
			}
		} else if strings.EqualFold(logEntrySource, "stderr") {
			if containerID == "" || containsKey(StderrIgnoreNsSet, k8sNamespace) {
				continue
			}
		}

		stringMap = make(map[string]string)

		logEntry := ToString(record["log"])
		logEntryTimeStamp := ToString(record["time"])
		stringMap["LogEntry"] = logEntry
		stringMap["LogEntrySource"] = logEntrySource
		stringMap["LogEntryTimeStamp"] = logEntryTimeStamp
		stringMap["SourceSystem"] = "Containers"
		stringMap["Id"] = containerID

		if val, ok := imageIDMap[containerID]; ok {
			stringMap["Image"] = val
		}

		if val, ok := nameIDMap[containerID]; ok {
			stringMap["Name"] = val
		}

		stringMap["TimeOfCommand"] = start.Format(time.RFC3339)
		stringMap["Computer"] = Computer
		var dataItem DataItem
		var dataItemADX DataItemADX
		var msgPackEntry MsgPackEntry

		FlushedRecordsSize += float64(len(stringMap["LogEntry"]))

		if ContainerLogsRouteV2 == true {
			msgPackEntry = MsgPackEntry{
				// this below time is what mdsd uses in its buffer/expiry calculations. better to be as close to flushtime as possible, so its filled just before flushing for each entry
				//Time: start.Unix(),
				//Time: time.Now().Unix(),
				Record: stringMap,
			}
			msgPackEntries = append(msgPackEntries, msgPackEntry)
		} else if ContainerLogsRouteADX == true {
			if ResourceCentric == true {
				stringMap["AzureResourceId"] = ResourceID
			}
			stringMap["PodName"] = k8sPodName
			stringMap["PodNamespace"] = k8sNamespace
			stringMap["ContainerName"] = containerName
			dataItemADX = DataItemADX{
				TimeGenerated:   stringMap["LogEntryTimeStamp"],
				Computer:        stringMap["Computer"],
				ContainerID:     stringMap["Id"],
				ContainerName:   stringMap["ContainerName"],
				PodName:         stringMap["PodName"],
				PodNamespace:    stringMap["PodNamespace"],
				LogMessage:      stringMap["LogEntry"],
				LogSource:       stringMap["LogEntrySource"],
				AzureResourceId: stringMap["AzureResourceId"],
			}
			//ADX
			dataItemsADX = append(dataItemsADX, dataItemADX)
		} else {
			dataItem = DataItem{
				ID:                    stringMap["Id"],
				LogEntry:              stringMap["LogEntry"],
				LogEntrySource:        stringMap["LogEntrySource"],
				LogEntryTimeStamp:     stringMap["LogEntryTimeStamp"],
				LogEntryTimeOfCommand: stringMap["TimeOfCommand"],
				SourceSystem:          stringMap["SourceSystem"],
				Computer:              stringMap["Computer"],
				Image:                 stringMap["Image"],
				Name:                  stringMap["Name"],
			}
			//ODS
			dataItems = append(dataItems, dataItem)
		}

		if stringMap["LogEntryTimeStamp"] != "" {
			loggedTime, e := time.Parse(time.RFC3339, stringMap["LogEntryTimeStamp"])
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
	}

	numContainerLogRecords := 0

	if len(msgPackEntries) > 0 && ContainerLogsRouteV2 == true {
		//flush to mdsd
		fluentForward := MsgPackForward{
			Tag:     MdsdSourceName,
			Entries: msgPackEntries,
		}

		//determine the size of msgp message
		msgpSize := 1 + msgp.StringPrefixSize + len(fluentForward.Tag) + msgp.ArrayHeaderSize
		for i := range fluentForward.Entries {
			msgpSize += 1 + msgp.Int64Size + msgp.GuessSize(fluentForward.Entries[i].Record)
		}

		//allocate buffer for msgp message
		var msgpBytes []byte
		msgpBytes = msgp.Require(nil, msgpSize)

		//construct the stream
		msgpBytes = append(msgpBytes, 0x92)
		msgpBytes = msgp.AppendString(msgpBytes, fluentForward.Tag)
		msgpBytes = msgp.AppendArrayHeader(msgpBytes, uint32(len(fluentForward.Entries)))
		batchTime := time.Now().Unix()
		for entry := range fluentForward.Entries {
			msgpBytes = append(msgpBytes, 0x92)
			msgpBytes = msgp.AppendInt64(msgpBytes, batchTime)
			msgpBytes = msgp.AppendMapStrStr(msgpBytes, fluentForward.Entries[entry].Record)
		}

		if MdsdMsgpUnixSocketClient == nil {
			Log("Error::mdsd::mdsd connection does not exist. re-connecting ...")
			CreateMDSDClient()
			if MdsdMsgpUnixSocketClient == nil {
				Log("Error::mdsd::Unable to create mdsd client. Please check error log.")

				ContainerLogTelemetryMutex.Lock()
				defer ContainerLogTelemetryMutex.Unlock()
				ContainerLogsMDSDClientCreateErrors += 1

				return output.FLB_RETRY
			}
		}

		deadline := 10 * time.Second
		MdsdMsgpUnixSocketClient.SetWriteDeadline(time.Now().Add(deadline)) //this is based of clock time, so cannot reuse

		bts, er := MdsdMsgpUnixSocketClient.Write(msgpBytes)

		elapsed = time.Since(start)

		if er != nil {
			Log("Error::mdsd::Failed to write to mdsd %d records after %s. Will retry ... error : %s", len(dataItems), elapsed, er.Error())
			if MdsdMsgpUnixSocketClient != nil {
				MdsdMsgpUnixSocketClient.Close()
				MdsdMsgpUnixSocketClient = nil
			}

			ContainerLogTelemetryMutex.Lock()
			defer ContainerLogTelemetryMutex.Unlock()
			ContainerLogsSendErrorsToMDSDFromFluent += 1

			return output.FLB_RETRY
		} else {
			numContainerLogRecords = len(msgPackEntries)
			Log("Success::mdsd::Successfully flushed %d container log records that was %d bytes to mdsd in %s ", numContainerLogRecords, bts, elapsed)
		}
	} else if ContainerLogsRouteADX == true && len(dataItemsADX) > 0 {
		// Route to ADX
		r, w := io.Pipe()
		defer r.Close()
		enc := json.NewEncoder(w)
		go func() {
			defer w.Close()
			for _, data := range dataItemsADX {
				if encError := enc.Encode(data); encError != nil {
					message := fmt.Sprintf("Error::ADX Encoding data for ADX %s", encError)
					Log(message)
					//SendException(message) //use for testing/debugging only as this can generate a lot of exceptions
					//continue and move on, so one poisoned message does not impact the whole batch
				}
			}
		}()

		if ADXIngestor == nil {
			Log("Error::ADX::ADXIngestor does not exist. re-creating ...")
			CreateADXClient()
			if ADXIngestor == nil {
				Log("Error::ADX::Unable to create ADX client. Please check error log.")

				ContainerLogTelemetryMutex.Lock()
				defer ContainerLogTelemetryMutex.Unlock()
				ContainerLogsADXClientCreateErrors += 1

				return output.FLB_RETRY
			}
		}

		// Setup a maximum time for completion to be 15 Seconds.
		ctx, cancel := context.WithTimeout(ParentContext, 30*time.Second)
		defer cancel()

		//ADXFlushMutex.Lock()
		//defer ADXFlushMutex.Unlock()
		//MultiJSON support is not there yet
		if ingestionErr := ADXIngestor.FromReader(ctx, r, ingest.IngestionMappingRef("ContainerLogv2Mapping", ingest.JSON), ingest.FileFormat(ingest.JSON)); ingestionErr != nil {
			Log("Error when streaming to ADX Ingestion: %s", ingestionErr.Error())
			//ADXIngestor = nil  //not required as per ADX team. Will keep it to indicate that we tried this approach

			ContainerLogTelemetryMutex.Lock()
			defer ContainerLogTelemetryMutex.Unlock()
			ContainerLogsSendErrorsToADXFromFluent += 1

			return output.FLB_RETRY
		}

		elapsed = time.Since(start)
		numContainerLogRecords = len(dataItemsADX)
		Log("Success::ADX::Successfully wrote %d container log records to ADX in %s", numContainerLogRecords, elapsed)

	} else {
		//flush to ODS
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
			req.Header.Set("User-Agent", userAgent)
			reqId := uuid.New().String()
			req.Header.Set("X-Request-ID", reqId)
			//expensive to do string len for every request, so use a flag
			if ResourceCentric == true {
				req.Header.Set("x-ms-AzureResourceId", ResourceID)
			}

			resp, err := HTTPClient.Do(req)
			elapsed = time.Since(start)

			if err != nil {
				message := fmt.Sprintf("Error when sending request %s \n", err.Error())
				Log(message)
				// Commenting this out for now. TODO - Add better telemetry for ods errors using aggregation
				//SendException(message)
				Log("Failed to flush %d records after %s", len(dataItems), elapsed)

				return output.FLB_RETRY
			}

			if resp == nil || resp.StatusCode != 200 {
				if resp != nil {
					Log("RequestId %s Status %s Status Code %d", reqId, resp.Status, resp.StatusCode)
				}
				return output.FLB_RETRY
			}

			defer resp.Body.Close()
			numContainerLogRecords = len(dataItems)
			Log("PostDataHelper::Info::Successfully flushed %d container log records to ODS in %s", numContainerLogRecords, elapsed)

		}
	}

	ContainerLogTelemetryMutex.Lock()
	defer ContainerLogTelemetryMutex.Unlock()

	if numContainerLogRecords > 0 {
		FlushedRecordsCount += float64(numContainerLogRecords)
		FlushedRecordsTimeTaken += float64(elapsed / time.Millisecond)

		if maxLatency >= AgentLogProcessingMaxLatencyMs {
			AgentLogProcessingMaxLatencyMs = maxLatency
			AgentLogProcessingMaxLatencyMsContainer = maxLatencyContainer
		}
	}

	return output.FLB_OK
}

func containsKey(currentMap map[string]bool, key string) bool {
	_, c := currentMap[key]
	return c
}

// GetContainerIDK8sNamespacePodNameFromFileName Gets the container ID, k8s namespace, pod name and containername From the file Name
// sample filename kube-proxy-dgcx7_kube-system_kube-proxy-8df7e49e9028b60b5b0d0547f409c455a9567946cf763267b7e6fa053ab8c182.log
func GetContainerIDK8sNamespacePodNameFromFileName(filename string) (string, string, string, string) {
	id := ""
	ns := ""
	podName := ""
	containerName := ""

	start := strings.LastIndex(filename, "-")
	end := strings.LastIndex(filename, ".")

	if start >= end || start == -1 || end == -1 {
		id = ""
	} else {
		id = filename[start+1 : end]
	}

	start = strings.Index(filename, "_")
	end = strings.LastIndex(filename, "_")

	if start >= end || start == -1 || end == -1 {
		ns = ""
	} else {
		ns = filename[start+1 : end]
	}

	start = strings.LastIndex(filename, "_")
	end = strings.LastIndex(filename, "-")

	if start >= end || start == -1 || end == -1 {
		containerName = ""
	} else {
		containerName = filename[start+1 : end]
	}

	start = strings.Index(filename, "/containers/")
	end = strings.Index(filename, "_")

	if start >= end || start == -1 || end == -1 {
		podName = ""
	} else {
		podName = filename[(start + len("/containers/")):end]
	}

	return id, ns, podName, containerName
}

// InitializePlugin reads and populates plugin configuration
func InitializePlugin(pluginConfPath string, agentVersion string) {

	go func() {
		isTest := os.Getenv("ISTEST")
		if strings.Compare(strings.ToLower(strings.TrimSpace(isTest)), "true") == 0 {
			e1 := http.ListenAndServe("localhost:6060", nil)
			if e1 != nil {
				Log("HTTP Listen Error: %s \n", e1.Error())
			}
		}
	}()
	StdoutIgnoreNsSet = make(map[string]bool)
	StderrIgnoreNsSet = make(map[string]bool)
	ImageIDMap = make(map[string]string)
	NameIDMap = make(map[string]string)
	// Keeping the two error hashes separate since we need to keep the config error hash for the lifetime of the container
	// whereas the prometheus scrape error hash needs to be refreshed every hour
	ConfigErrorEvent = make(map[string]KubeMonAgentEventTags)
	PromScrapeErrorEvent = make(map[string]KubeMonAgentEventTags)
	// Initializing this to true to skip the first kubemonagentevent flush since the errors are not populated at this time
	skipKubeMonEventsFlush = true

	enrichContainerLogsSetting := os.Getenv("AZMON_CLUSTER_CONTAINER_LOG_ENRICH")
	if strings.Compare(enrichContainerLogsSetting, "true") == 0 {
		enrichContainerLogs = true
		Log("ContainerLogEnrichment=true \n")
	} else {
		enrichContainerLogs = false
		Log("ContainerLogEnrichment=false \n")
	}

	pluginConfig, err := ReadConfiguration(pluginConfPath)
	if err != nil {
		message := fmt.Sprintf("Error Reading plugin config path : %s \n", err.Error())
		Log(message)
		SendException(message)
		time.Sleep(30 * time.Second)
		log.Fatalln(message)
	}

	osType := os.Getenv("OS_TYPE")

	// Linux
	if strings.Compare(strings.ToLower(osType), "windows") != 0 {
		Log("Reading configuration for Linux from %s", pluginConfPath)
		omsadminConf, err := ReadConfiguration(pluginConfig["omsadmin_conf_path"])
		if err != nil {
			message := fmt.Sprintf("Error Reading omsadmin configuration %s\n", err.Error())
			Log(message)
			SendException(message)
			time.Sleep(30 * time.Second)
			log.Fatalln(message)
		}
		OMSEndpoint = omsadminConf["OMS_ENDPOINT"]
		WorkspaceID = omsadminConf["WORKSPACE_ID"]
		// Populate Computer field
		containerHostName, err1 := ioutil.ReadFile(pluginConfig["container_host_file_path"])
		if err1 != nil {
			// It is ok to log here and continue, because only the Computer column will be missing,
			// which can be deduced from a combination of containerId, and docker logs on the node
			message := fmt.Sprintf("Error when reading containerHostName file %s.\n It is ok to log here and continue, because only the Computer column will be missing, which can be deduced from a combination of containerId, and docker logs on the nodes\n", err.Error())
			Log(message)
			SendException(message)
		} else {
			Computer = strings.TrimSuffix(ToString(containerHostName), "\n")
		}
		// read proxyendpoint if proxy configured
		ProxyEndpoint = ""
		proxySecretPath := pluginConfig["omsproxy_secret_path"]
		if _, err := os.Stat(proxySecretPath); err == nil {
			Log("Reading proxy configuration for Linux from %s", proxySecretPath)
			proxyConfig, err := ioutil.ReadFile(proxySecretPath)
			if err != nil {
				message := fmt.Sprintf("Error Reading omsproxy configuration %s\n", err.Error())
				Log(message)
				// if we fail to read proxy secret, AI telemetry might not be working as well
				SendException(message)
			} else {
				ProxyEndpoint = strings.TrimSpace(string(proxyConfig))
			}
		}
	} else {
		// windows
		Computer = os.Getenv("HOSTNAME")
		WorkspaceID = os.Getenv("WSID")
		logAnalyticsDomain := os.Getenv("DOMAIN")
		ProxyEndpoint = os.Getenv("PROXY")
		OMSEndpoint = "https://" + WorkspaceID + ".ods." + logAnalyticsDomain + "/OperationalData.svc/PostJsonDataItems"
	}

	Log("OMSEndpoint %s", OMSEndpoint)
	ResourceID = os.Getenv(envAKSResourceID)

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

	// log runtime info for debug purpose
	containerRuntime = os.Getenv(ContainerRuntimeEnv)
	Log("Container Runtime engine %s", containerRuntime)

	// set useragent to be used by ingestion
	dockerCimprovVersionEnv := strings.TrimSpace(os.Getenv("DOCKER_CIMPROV_VERSION"))
	if len(dockerCimprovVersionEnv) > 0 {
		dockerCimprovVersion = dockerCimprovVersionEnv
	}

	userAgent = fmt.Sprintf("%s/%s", agentName, dockerCimprovVersion)

	Log("Usage-Agent = %s \n", userAgent)

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

	Log("kubeMonAgentConfigEventFlushInterval = %d \n", kubeMonAgentConfigEventFlushInterval)
	KubeMonAgentConfigEventsSendTicker = time.NewTicker(time.Minute * time.Duration(kubeMonAgentConfigEventFlushInterval))

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

	ContainerLogsRoute := strings.TrimSpace(strings.ToLower(os.Getenv("AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE")))
	Log("AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE:%s", ContainerLogsRoute)

	ContainerLogsRouteV2 = false  //default is ODS
	ContainerLogsRouteADX = false //default is LA

	if strings.Compare(ContainerLogsRoute, ContainerLogsV2Route) == 0 && strings.Compare(strings.ToLower(osType), "windows") != 0 {
		ContainerLogsRouteV2 = true
		Log("Routing container logs thru %s route...", ContainerLogsV2Route)
		fmt.Fprintf(os.Stdout, "Routing container logs thru %s route... \n", ContainerLogsV2Route)
	} else if strings.Compare(ContainerLogsRoute, ContainerLogsADXRoute) == 0 {
		//check if adx clusteruri, clientid & secret are set
		var err error
		AdxClusterUri, err = ReadFileContents(PluginConfiguration["adx_cluster_uri_path"])
		if err != nil {
			Log("Error when reading AdxClusterUri %s", err)
		}
		if !isValidUrl(AdxClusterUri) {
			Log("Invalid AdxClusterUri %s", AdxClusterUri)
			AdxClusterUri = ""
		}
		AdxClientID, err = ReadFileContents(PluginConfiguration["adx_client_id_path"])
		if err != nil {
			Log("Error when reading AdxClientID %s", err)
		}

		AdxTenantID, err = ReadFileContents(PluginConfiguration["adx_tenant_id_path"])
		if err != nil {
			Log("Error when reading AdxTenantID %s", err)
		}

		AdxClientSecret, err = ReadFileContents(PluginConfiguration["adx_client_secret_path"])
		if err != nil {
			Log("Error when reading AdxClientSecret %s", err)
		}

		if len(AdxClusterUri) > 0 && len(AdxClientID) > 0 && len(AdxClientSecret) > 0 && len(AdxTenantID) > 0 {
			ContainerLogsRouteADX = true
			Log("Routing container logs thru %s route...", ContainerLogsADXRoute)
			fmt.Fprintf(os.Stdout, "Routing container logs thru %s route...\n", ContainerLogsADXRoute)
		}
	}

	if ContainerLogsRouteV2 == true {
		CreateMDSDClient()
	} else if ContainerLogsRouteADX == true {
		CreateADXClient()
	}

	if strings.Compare(strings.ToLower(os.Getenv("CONTROLLER_TYPE")), "daemonset") == 0 {
		populateExcludedStdoutNamespaces()
		populateExcludedStderrNamespaces()
		if enrichContainerLogs == true && ContainerLogsRouteADX != true {
			Log("ContainerLogEnrichment=true; starting goroutine to update containerimagenamemaps \n")
			go updateContainerImageNameMaps()
		} else {
			Log("ContainerLogEnrichment=false \n")
		}

		// Flush config error records every hour
		go flushKubeMonAgentEventRecords()
	} else {
		Log("Running in replicaset. Disabling container enrichment caching & updates \n")
	}

}
