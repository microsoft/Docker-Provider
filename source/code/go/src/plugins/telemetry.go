package main

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/Microsoft/ApplicationInsights-Go/appinsights"
	"github.com/Microsoft/ApplicationInsights-Go/appinsights/contracts"
	"github.com/fluent/fluent-bit-go/output"
)

var (
	// FlushedRecordsCount indicates the number of flushed log records in the current period
	FlushedRecordsCount float64
	// FlushedRecordsSize indicates the size of the flushed records in the current period
	FlushedRecordsSize float64
	// FlushedRecordsTimeTaken indicates the cumulative time taken to flush the records for the current period
	FlushedRecordsTimeTaken float64
	// This is telemetry for how old/latent logs we are processing in milliseconds (max over a period of time)
	AgentLogProcessingMaxLatencyMs float64
	// This is telemetry for which container logs were latent (max over a period of time)
	AgentLogProcessingMaxLatencyMsContainer string
	// CommonProperties indicates the dimensions that are sent with every event/metric
	CommonProperties map[string]string
	// TelemetryClient is the client used to send the telemetry
	TelemetryClient appinsights.TelemetryClient
	// ContainerLogTelemetryTicker sends telemetry periodically
	ContainerLogTelemetryTicker *time.Ticker
	//Tracks the number of telegraf metrics sent successfully between telemetry ticker periods (uses ContainerLogTelemetryTicker)
	TelegrafMetricsSentCount float64
	//Tracks the number of send errors between telemetry ticker periods (uses ContainerLogTelemetryTicker)
	TelegrafMetricsSendErrorCount float64
)

const (
	clusterTypeACS                                    = "ACS"
	clusterTypeAKS                                    = "AKS"
	envAKSResourceID                                  = "AKS_RESOURCE_ID"
	envACSResourceName                                = "ACS_RESOURCE_NAME"
	envAppInsightsAuth                                = "APPLICATIONINSIGHTS_AUTH"
	envAppInsightsEndpoint                            = "APPLICATIONINSIGHTS_ENDPOINT"
	metricNameAvgFlushRate                            = "ContainerLogAvgRecordsFlushedPerSec"
	metricNameAvgLogGenerationRate                    = "ContainerLogsGeneratedPerSec"
	metricNameLogSize                                 = "ContainerLogsSize"
	metricNameAgentLogProcessingMaxLatencyMs          = "ContainerLogsAgentSideLatencyMs"
	metricNameNumberofTelegrafMetricsSentSuccessfully = "TelegrafMetricsSentCount"
	metricNameNumberofSendErrorsTelegrafMetrics       = "TelegrafMetricsSendErrorCount"

	defaultTelemetryPushIntervalSeconds = 300

	eventNameContainerLogInit   = "ContainerLogPluginInitialized"
	eventNameDaemonSetHeartbeat = "ContainerLogDaemonSetHeartbeatEvent"
)

// ErrorType to be used as enum
type ErrorType int

const (
	// ErrorType to be used as enum for ConfigError and ScrapingError
	ConfigError ErrorType = iota
	ScrapingError
)

// SendContainerLogPluginMetrics is a go-routine that flushes the data periodically (every 5 mins to App Insights)
func SendContainerLogPluginMetrics(telemetryPushIntervalProperty string) {
	telemetryPushInterval, err := strconv.Atoi(telemetryPushIntervalProperty)
	if err != nil {
		Log("Error Converting telemetryPushIntervalProperty %s. Using Default Interval... %d \n", telemetryPushIntervalProperty, defaultTelemetryPushIntervalSeconds)
		telemetryPushInterval = defaultTelemetryPushIntervalSeconds
	}

	ContainerLogTelemetryTicker = time.NewTicker(time.Second * time.Duration(telemetryPushInterval))

	start := time.Now()
	SendEvent(eventNameContainerLogInit, make(map[string]string))

	for ; true; <-ContainerLogTelemetryTicker.C {
		elapsed := time.Since(start)

		ContainerLogTelemetryMutex.Lock()
		flushRate := FlushedRecordsCount / FlushedRecordsTimeTaken * 1000
		logRate := FlushedRecordsCount / float64(elapsed/time.Second)
		logSizeRate := FlushedRecordsSize / float64(elapsed/time.Second)
		telegrafMetricsSentCount := TelegrafMetricsSentCount
		telegrafMetricsSendErrorCount := TelegrafMetricsSendErrorCount
		TelegrafMetricsSentCount = 0.0
		TelegrafMetricsSendErrorCount = 0.0
		FlushedRecordsCount = 0.0
		FlushedRecordsSize = 0.0
		FlushedRecordsTimeTaken = 0.0
		logLatencyMs := AgentLogProcessingMaxLatencyMs
		logLatencyMsContainer := AgentLogProcessingMaxLatencyMsContainer
		AgentLogProcessingMaxLatencyMs = 0
		AgentLogProcessingMaxLatencyMsContainer = ""
		ContainerLogTelemetryMutex.Unlock()

		if strings.Compare(strings.ToLower(os.Getenv("CONTROLLER_TYPE")), "daemonset") == 0 {
			SendEvent(eventNameDaemonSetHeartbeat, make(map[string]string))
			flushRateMetric := appinsights.NewMetricTelemetry(metricNameAvgFlushRate, flushRate)
			TelemetryClient.Track(flushRateMetric)
			logRateMetric := appinsights.NewMetricTelemetry(metricNameAvgLogGenerationRate, logRate)
			logSizeMetric := appinsights.NewMetricTelemetry(metricNameLogSize, logSizeRate)
			TelemetryClient.Track(logRateMetric)
			Log("Log Size Rate: %f\n", logSizeRate)
			TelemetryClient.Track(logSizeMetric)
			logLatencyMetric := appinsights.NewMetricTelemetry(metricNameAgentLogProcessingMaxLatencyMs, logLatencyMs)
			logLatencyMetric.Properties["Container"] = logLatencyMsContainer
			TelemetryClient.Track(logLatencyMetric)
		}
		TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameNumberofTelegrafMetricsSentSuccessfully, telegrafMetricsSentCount))
		TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameNumberofSendErrorsTelegrafMetrics, telegrafMetricsSendErrorCount))
		start = time.Now()
	}
}

// SendEvent sends an event to App Insights
func SendEvent(eventName string, dimensions map[string]string) {
	Log("Sending Event : %s\n", eventName)
	event := appinsights.NewEventTelemetry(eventName)

	// add any extra Properties
	for k, v := range dimensions {
		event.Properties[k] = v
	}

	TelemetryClient.Track(event)
}

// SendException  send an event to the configured app insights instance
func SendException(err interface{}) {
	if TelemetryClient != nil {
		TelemetryClient.TrackException(err)
	}
}

// InitializeTelemetryClient sets up the telemetry client to send telemetry to the App Insights instance
func InitializeTelemetryClient(agentVersion string) (int, error) {
	encodedIkey := os.Getenv(envAppInsightsAuth)
	if encodedIkey == "" {
		Log("Environment Variable Missing \n")
		return -1, errors.New("Missing Environment Variable")
	}

	decIkey, err := base64.StdEncoding.DecodeString(encodedIkey)
	if err != nil {
		Log("Decoding Error %s", err.Error())
		return -1, err
	}

	appInsightsEndpoint := os.Getenv(envAppInsightsEndpoint)
	telemetryClientConfig := appinsights.NewTelemetryConfiguration(string(decIkey))
	// endpoint override required only for sovereign clouds
	if appInsightsEndpoint != "" {
		Log("Overriding the default AppInsights EndpointUrl with %s", appInsightsEndpoint)
		telemetryClientConfig.EndpointUrl = envAppInsightsEndpoint
	}
	TelemetryClient = appinsights.NewTelemetryClientFromConfig(telemetryClientConfig)

	telemetryOffSwitch := os.Getenv("DISABLE_TELEMETRY")
	if strings.Compare(strings.ToLower(telemetryOffSwitch), "true") == 0 {
		Log("Appinsights telemetry is disabled \n")
		TelemetryClient.SetIsEnabled(false)
	}

	CommonProperties = make(map[string]string)
	CommonProperties["Computer"] = Computer
	CommonProperties["WorkspaceID"] = WorkspaceID
	CommonProperties["ControllerType"] = os.Getenv("CONTROLLER_TYPE")
	CommonProperties["AgentVersion"] = agentVersion

	aksResourceID := os.Getenv(envAKSResourceID)
	// if the aks resource id is not defined, it is most likely an ACS Cluster
	if aksResourceID == "" {
		CommonProperties["ACSResourceName"] = os.Getenv(envACSResourceName)
		CommonProperties["ClusterType"] = clusterTypeACS

		CommonProperties["SubscriptionID"] = ""
		CommonProperties["ResourceGroupName"] = ""
		CommonProperties["ClusterName"] = ""
		CommonProperties["Region"] = ""
		CommonProperties["AKS_RESOURCE_ID"] = ""

	} else {
		CommonProperties["ACSResourceName"] = ""
		CommonProperties["AKS_RESOURCE_ID"] = aksResourceID
		splitStrings := strings.Split(aksResourceID, "/")
		if len(splitStrings) > 0 && len(splitStrings) < 10 {
			CommonProperties["SubscriptionID"] = splitStrings[2]
			CommonProperties["ResourceGroupName"] = splitStrings[4]
			CommonProperties["ClusterName"] = splitStrings[8]
		}
		CommonProperties["ClusterType"] = clusterTypeAKS

		region := os.Getenv("AKS_REGION")
		CommonProperties["Region"] = region
	}

	TelemetryClient.Context().CommonProperties = CommonProperties
	return 0, nil
}

// telegraf metric DataItem represents the object corresponding to the json that is sent by fluentbit tail plugin
type laConfigError struct {
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

// PostConfigErrorstoLA sends config/prometheus scraping error log lines to LA
func PostConfigErrorstoLA(record map[interface{}]interface{}, errType ErrorType) {
	configErrorHash := make(map[string]struct{})
	promScrapeErrorHash := make(map[string]struct{})

	// Log("Iterating\n")
	// for k, v := range record {
	// 	Log("key[%s] value[%s]\n", k, v)
	// }
	// Log("Done Iterating\n")
	var logRecordString = ToString(record["log"])

	switch errType {
	case ConfigError:
		Log("configErrorHash\n")
		configErrorHash[logRecordString] = struct{}{}
		for k, v := range configErrorHash {
			Log("key[%s] value[%s]\n", k, v)
		}
		// Log(logRecordString)
		Log("\n")

	case ScrapingError:
		// Splitting this based on the string 'E! [inputs.prometheus]: ' since the log entry has timestamp and we want to remove that before building the hash
		var scrapingSplitString = strings.Split(logRecordString, "E! [inputs.prometheus]: ")
		if scrapingSplitString != nil && len(scrapingSplitString) == 2 {
			var splitString = scrapingSplitString[1]
			if splitString != "" {
				promScrapeErrorHash[splitString] = struct{}{}
				Log("promScrapeErrorHash\n")
				for k, v := range promScrapeErrorHash {
					Log("key[%s] value[%s]\n", k, v)
				}
				// Log(splitString1)
				Log("\n")
			}
		}

		Log("Posting custom log type to LA\n")
		var laConfigErrorDataItems []*laConfigError
		configError := laConfigError{
			Origin:         "myOrigin",
			Namespace:      "myNamespace",
			Name:           "myName",
			Value:          3.14,
			Tags:           "myTags",
			CollectionTime: "2019-09-16T10:00:00.625Z",
			Computer:       "myComputer",
		}

		//Log ("la metric:%v", laMetric)
		laConfigErrorDataItems = append(laConfigErrorDataItems, &configError)
		jsonBytes, err := json.Marshal(laConfigErrorDataItems)

		var uri = "https://17052a42-0cf3-4954-bbf1-30ef85e918a2.ods.opinsights.azure.com/api/logs?api-version=2016-04-01"
		req, _ := http.NewRequest("POST", uri, jsonBytes)
		req.Header.Set("x-ms-date", time.Now().Format(time.RFC3339))
		req.Header.Set("Authorization", "SharedKey 17052a42-0cf3-4954-bbf1-30ef85e918a2:s3mrYKEufENFit8ANb7BitrDbZ9Y26xhxHwa877q9co=")
		req.Header.Set("Log-Type", "MyRecordType")
		req.Header.Set("time-generated-field", "2019-09-16T14:00:00.625Z")
		req.Header.Set("Accept", "application/json")

		resp, err := HTTPClient.Do(req)
		if err != nil {
			Log("Error:")
			Log(err)
			Log("\n")
		} else {
			Log("response:")
			Log(resp)
			Log("\n")
		}
	}
}

// PushToAppInsightsTraces sends the log lines as trace messages to the configured App Insights Instance
func PushToAppInsightsTraces(records []map[interface{}]interface{}, severityLevel contracts.SeverityLevel, tag string) int {
	var logLines []string
	for _, record := range records {
		logLines = append(logLines, ToString(record["log"]))
		// If record contains config error or prometheus scraping errors send it to ****** table
		var logEntry = ToString(record["log"])
		if strings.Contains(logEntry, "config::error") {
			PostConfigErrorstoLA(record, ConfigError)
		} else if strings.Contains(logEntry, "E! [inputs.prometheus]") {
			PostConfigErrorstoLA(record, ScrapingError)
		}
	}

	traceEntry := strings.Join(logLines, "\n")
	traceTelemetryItem := appinsights.NewTraceTelemetry(traceEntry, severityLevel)
	traceTelemetryItem.Properties["tag"] = tag
	TelemetryClient.Track(traceTelemetryItem)
	return output.FLB_OK
}
