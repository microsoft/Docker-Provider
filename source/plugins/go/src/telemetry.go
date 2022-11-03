package main

import (
	"encoding/base64"
	"errors"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/fluent/fluent-bit-go/output"
	"github.com/microsoft/ApplicationInsights-Go/appinsights"
	"github.com/microsoft/ApplicationInsights-Go/appinsights/contracts"
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
	//Tracks the number of windows telegraf metrics count with Tags size 64KB or more between telemetry ticker periods (uses ContainerLogTelemetryTicker)
	WinTelegrafMetricsCountWithTagsSize64KBorMore float64
	//Tracks the number of telegraf metrics sent successfully between telemetry ticker periods (uses ContainerLogTelemetryTicker)
	TelegrafMetricsSentCount float64
	//Tracks the number of send errors between telemetry ticker periods (uses ContainerLogTelemetryTicker)
	TelegrafMetricsSendErrorCount float64
	//Tracks the number of 429 (throttle) errors between telemetry ticker periods (uses ContainerLogTelemetryTicker)
	TelegrafMetricsSend429ErrorCount float64
	//Tracks the number of write/send errors to mdsd for containerlogs (uses ContainerLogTelemetryTicker)
	ContainerLogsSendErrorsToMDSDFromFluent float64
	//Tracks the number of mdsd client create errors for containerlogs (uses ContainerLogTelemetryTicker)
	ContainerLogsMDSDClientCreateErrors float64
	//Tracks the number of mdsd client create errors for insightsmetrics (uses ContainerLogTelemetryTicker)
	InsightsMetricsMDSDClientCreateErrors float64
	//Tracks the number of mdsd client create errors for kubemonevents (uses ContainerLogTelemetryTicker)
	KubeMonEventsMDSDClientCreateErrors float64
	//Tracks the number of write/send errors to ADX for containerlogs (uses ContainerLogTelemetryTicker)
	ContainerLogsSendErrorsToADXFromFluent float64
	//Tracks the number of ADX client create errors for containerlogs (uses ContainerLogTelemetryTicker)
	ContainerLogsADXClientCreateErrors float64
	//Tracks the number of container log records with empty Timestamp (uses ContainerLogTelemetryTicker)
	ContainerLogRecordCountWithEmptyTimeStamp float64
	//Tracks the number of OSM namespaces and sent only from prometheus sidecar (uses ContainerLogTelemetryTicker)
	OSMNamespaceCount int
	//Tracks whether monitor kubernetes pods is set to true and sent only from prometheus sidecar (uses ContainerLogTelemetryTicker)
	PromMonitorPods string
	//Tracks the number of monitor kubernetes pods namespaces and sent only from prometheus sidecar (uses ContainerLogTelemetryTicker)
	PromMonitorPodsNamespaceLength int
	//Tracks the number of monitor kubernetes pods label selectors and sent only from prometheus sidecar (uses ContainerLogTelemetryTicker)
	PromMonitorPodsLabelSelectorLength int
	//Tracks the number of monitor kubernetes pods field selectors and sent only from prometheus sidecar (uses ContainerLogTelemetryTicker)
	PromMonitorPodsFieldSelectorLength int
)

const (
	clusterTypeACS                                              = "ACS"
	clusterTypeAKS                                              = "AKS"
	envAKSResourceID                                            = "AKS_RESOURCE_ID"
	envACSResourceName                                          = "ACS_RESOURCE_NAME"
	envAppInsightsAuth                                          = "APPLICATIONINSIGHTS_AUTH"
	envAppInsightsEndpoint                                      = "APPLICATIONINSIGHTS_ENDPOINT"
	metricNameAvgFlushRate                                      = "ContainerLogAvgRecordsFlushedPerSec"
	metricNameAvgLogGenerationRate                              = "ContainerLogsGeneratedPerSec"
	metricNameLogSize                                           = "ContainerLogsSize"
	metricNameAgentLogProcessingMaxLatencyMs                    = "ContainerLogsAgentSideLatencyMs"
	metricNameNumberofTelegrafMetricsSentSuccessfully           = "TelegrafMetricsSentCount"
	metricNameNumberofSendErrorsTelegrafMetrics                 = "TelegrafMetricsSendErrorCount"
	metricNameNumberofSend429ErrorsTelegrafMetrics              = "TelegrafMetricsSend429ErrorCount"
	metricNameNumberofWinTelegrafMetricsWithTagsSize64KBorMore  = "WinTelegrafMetricsCountWithTagsSize64KBorMore"
	metricNameErrorCountContainerLogsSendErrorsToMDSDFromFluent = "ContainerLogs2MdsdSendErrorCount"
	metricNameErrorCountContainerLogsMDSDClientCreateError      = "ContainerLogsMdsdClientCreateErrorCount"
	metricNameErrorCountInsightsMetricsMDSDClientCreateError    = "InsightsMetricsMDSDClientCreateErrorsCount"
	metricNameErrorCountKubeMonEventsMDSDClientCreateError      = "KubeMonEventsMDSDClientCreateErrorsCount"
	metricNameErrorCountContainerLogsSendErrorsToADXFromFluent  = "ContainerLogs2ADXSendErrorCount"
	metricNameErrorCountContainerLogsADXClientCreateError       = "ContainerLogsADXClientCreateErrorCount"
	metricNameContainerLogRecordCountWithEmptyTimeStamp         = "ContainerLogRecordCountWithEmptyTimeStamp"

	defaultTelemetryPushIntervalSeconds = 300

	eventNameContainerLogInit                 = "ContainerLogPluginInitialized"
	eventNameDaemonSetHeartbeat               = "ContainerLogDaemonSetHeartbeatEvent"
	eventNameCustomPrometheusSidecarHeartbeat = "CustomPrometheusSidecarHeartbeatEvent"
	eventNameWindowsFluentBitHeartbeat        = "WindowsFluentBitHeartbeatEvent"
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
		telegrafMetricsSend429ErrorCount := TelegrafMetricsSend429ErrorCount
		winTelegrafMetricsCountWithTagsSize64KBorMore := WinTelegrafMetricsCountWithTagsSize64KBorMore
		containerLogsSendErrorsToMDSDFromFluent := ContainerLogsSendErrorsToMDSDFromFluent
		containerLogsMDSDClientCreateErrors := ContainerLogsMDSDClientCreateErrors
		containerLogsSendErrorsToADXFromFluent := ContainerLogsSendErrorsToADXFromFluent
		containerLogsADXClientCreateErrors := ContainerLogsADXClientCreateErrors
		insightsMetricsMDSDClientCreateErrors := InsightsMetricsMDSDClientCreateErrors
		kubeMonEventsMDSDClientCreateErrors := KubeMonEventsMDSDClientCreateErrors
		osmNamespaceCount := OSMNamespaceCount
		promMonitorPods := PromMonitorPods
		promMonitorPodsNamespaceLength := PromMonitorPodsNamespaceLength
		promMonitorPodsLabelSelectorLength := PromMonitorPodsLabelSelectorLength
		promMonitorPodsFieldSelectorLength := PromMonitorPodsFieldSelectorLength
		containerLogRecordCountWithEmptyTimeStamp := ContainerLogRecordCountWithEmptyTimeStamp

		TelegrafMetricsSentCount = 0.0
		TelegrafMetricsSendErrorCount = 0.0
		TelegrafMetricsSend429ErrorCount = 0.0
		WinTelegrafMetricsCountWithTagsSize64KBorMore = 0.0
		FlushedRecordsCount = 0.0
		FlushedRecordsSize = 0.0
		FlushedRecordsTimeTaken = 0.0
		logLatencyMs := AgentLogProcessingMaxLatencyMs
		logLatencyMsContainer := AgentLogProcessingMaxLatencyMsContainer
		AgentLogProcessingMaxLatencyMs = 0
		AgentLogProcessingMaxLatencyMsContainer = ""
		ContainerLogsSendErrorsToMDSDFromFluent = 0.0
		ContainerLogsMDSDClientCreateErrors = 0.0
		ContainerLogsSendErrorsToADXFromFluent = 0.0
		ContainerLogsADXClientCreateErrors = 0.0
		InsightsMetricsMDSDClientCreateErrors = 0.0
		KubeMonEventsMDSDClientCreateErrors = 0.0
		ContainerLogRecordCountWithEmptyTimeStamp = 0.0
		ContainerLogTelemetryMutex.Unlock()

		if strings.Compare(strings.ToLower(os.Getenv("CONTROLLER_TYPE")), "daemonset") == 0 {
			telemetryDimensions := make(map[string]string)
			if strings.Compare(strings.ToLower(os.Getenv("CONTAINER_TYPE")), "prometheussidecar") == 0 {
				telemetryDimensions["CustomPromMonitorPods"] = promMonitorPods
				if promMonitorPodsNamespaceLength > 0 {
					telemetryDimensions["CustomPromMonitorPodsNamespaceLength"] = strconv.Itoa(promMonitorPodsNamespaceLength)
				}
				if promMonitorPodsLabelSelectorLength > 0 {
					telemetryDimensions["CustomPromMonitorPodsLabelSelectorLength"] = strconv.Itoa(promMonitorPodsLabelSelectorLength)
				}
				if promMonitorPodsFieldSelectorLength > 0 {
					telemetryDimensions["CustomPromMonitorPodsFieldSelectorLength"] = strconv.Itoa(promMonitorPodsFieldSelectorLength)
				}
				if osmNamespaceCount > 0 {
					telemetryDimensions["OsmNamespaceCount"] = strconv.Itoa(osmNamespaceCount)
				}

				telemetryDimensions["PromFbitChunkSize"] = os.Getenv("AZMON_SIDECAR_FBIT_CHUNK_SIZE")
				telemetryDimensions["PromFbitBufferSize"] = os.Getenv("AZMON_SIDECAR_FBIT_BUFFER_SIZE")
				telemetryDimensions["PromFbitMemBufLimit"] = os.Getenv("AZMON_SIDECAR_FBIT_MEM_BUF_LIMIT")

				SendEvent(eventNameCustomPrometheusSidecarHeartbeat, telemetryDimensions)

			} else {
				fbitFlushIntervalSecs := os.Getenv("FBIT_SERVICE_FLUSH_INTERVAL")
				if fbitFlushIntervalSecs != "" {
					telemetryDimensions["FbitServiceFlushIntervalSecs"] = fbitFlushIntervalSecs
				}
				fbitTailBufferChunkSizeMBs := os.Getenv("FBIT_TAIL_BUFFER_CHUNK_SIZE")
				if fbitTailBufferChunkSizeMBs != "" {
					telemetryDimensions["FbitBufferChunkSizeMBs"] = fbitTailBufferChunkSizeMBs
				}
				fbitTailBufferMaxSizeMBs := os.Getenv("FBIT_TAIL_BUFFER_MAX_SIZE")
				if fbitTailBufferMaxSizeMBs != "" {
					telemetryDimensions["FbitBufferMaxSizeMBs"] = fbitTailBufferMaxSizeMBs
				}
				fbitTailMemBufLimitMBs := os.Getenv("FBIT_TAIL_MEM_BUF_LIMIT")
				if fbitTailMemBufLimitMBs != "" {
					telemetryDimensions["FbitMemBufLimitSizeMBs"] = fbitTailMemBufLimitMBs
				}
				telemetryDimensions["PromFbitChunkSize"] = os.Getenv("AZMON_FBIT_CHUNK_SIZE")
				telemetryDimensions["PromFbitBufferSize"] = os.Getenv("AZMON_FBIT_BUFFER_SIZE")
				telemetryDimensions["PromFbitMemBufLimit"] = os.Getenv("AZMON_FBIT_MEM_BUF_LIMIT")

				SendEvent(eventNameDaemonSetHeartbeat, telemetryDimensions)
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
		}
		TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameNumberofTelegrafMetricsSentSuccessfully, telegrafMetricsSentCount))
		if telegrafMetricsSendErrorCount > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameNumberofSendErrorsTelegrafMetrics, telegrafMetricsSendErrorCount))
		}
		if telegrafMetricsSend429ErrorCount > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameNumberofSend429ErrorsTelegrafMetrics, telegrafMetricsSend429ErrorCount))
		}
		if containerLogsSendErrorsToMDSDFromFluent > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameErrorCountContainerLogsSendErrorsToMDSDFromFluent, containerLogsSendErrorsToMDSDFromFluent))
		}
		if containerLogsMDSDClientCreateErrors > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameErrorCountContainerLogsMDSDClientCreateError, containerLogsMDSDClientCreateErrors))
		}
		if containerLogsSendErrorsToADXFromFluent > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameErrorCountContainerLogsSendErrorsToADXFromFluent, containerLogsSendErrorsToADXFromFluent))
		}
		if containerLogsADXClientCreateErrors > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameErrorCountContainerLogsADXClientCreateError, containerLogsADXClientCreateErrors))
		}
		if insightsMetricsMDSDClientCreateErrors > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameErrorCountInsightsMetricsMDSDClientCreateError, insightsMetricsMDSDClientCreateErrors))
		}
		if kubeMonEventsMDSDClientCreateErrors > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameErrorCountKubeMonEventsMDSDClientCreateError, kubeMonEventsMDSDClientCreateErrors))
		}
		if winTelegrafMetricsCountWithTagsSize64KBorMore > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameNumberofWinTelegrafMetricsWithTagsSize64KBorMore, winTelegrafMetricsCountWithTagsSize64KBorMore))
		}
		if ContainerLogRecordCountWithEmptyTimeStamp > 0.0 {
			TelemetryClient.Track(appinsights.NewMetricTelemetry(metricNameContainerLogRecordCountWithEmptyTimeStamp, containerLogRecordCountWithEmptyTimeStamp))
		}

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
		telemetryClientConfig.EndpointUrl = appInsightsEndpoint
	}
	// if the proxy configured set the customized httpclient with proxy
	isProxyConfigured := false
	if ProxyEndpoint != "" {
		Log("Using proxy endpoint for telemetry client since proxy configured")
		proxyEndpointUrl, err := url.Parse(ProxyEndpoint)
		if err != nil {
			Log("Failed Parsing of Proxy endpoint %s", err.Error())
			return -1, err
		}
		//adding the proxy settings to the Transport object
		transport := &http.Transport{
			Proxy: http.ProxyURL(proxyEndpointUrl),
		}
		httpClient := &http.Client{
			Transport: transport,
		}
		telemetryClientConfig.Client = httpClient
		isProxyConfigured = true
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

	if isProxyConfigured == true {
		CommonProperties["IsProxyConfigured"] = "true"
	} else {
		CommonProperties["IsProxyConfigured"] = "false"
	}

	// Adding container type to telemetry
	if strings.Compare(strings.ToLower(os.Getenv("CONTROLLER_TYPE")), "daemonset") == 0 {
		if strings.Compare(strings.ToLower(os.Getenv("CONTAINER_TYPE")), "prometheussidecar") == 0 {
			CommonProperties["ContainerType"] = "prometheussidecar"
		}
	}

	TelemetryClient.Context().CommonProperties = CommonProperties

	// Getting the namespace count, monitor kubernetes pods values and namespace count once at start because it wont change unless the configmap is applied and the container is restarted

	OSMNamespaceCount = 0
	osmNsCount := os.Getenv("TELEMETRY_OSM_CONFIGURATION_NAMESPACES_COUNT")
	if osmNsCount != "" {
		OSMNamespaceCount, err = strconv.Atoi(osmNsCount)
		if err != nil {
			Log("OSM namespace count string to int conversion error %s", err.Error())
		}
	}

	PromMonitorPods = os.Getenv("TELEMETRY_CUSTOM_PROM_MONITOR_PODS")

	PromMonitorPodsNamespaceLength = 0
	promMonPodsNamespaceLength := os.Getenv("TELEMETRY_CUSTOM_PROM_MONITOR_PODS_NS_LENGTH")
	if promMonPodsNamespaceLength != "" {
		PromMonitorPodsNamespaceLength, err = strconv.Atoi(promMonPodsNamespaceLength)
		if err != nil {
			Log("Custom prometheus monitor kubernetes pods namespace count string to int conversion error %s", err.Error())
		}
	}

	PromMonitorPodsLabelSelectorLength = 0
	promLabelSelectorLength := os.Getenv("TELEMETRY_CUSTOM_PROM_LABEL_SELECTOR_LENGTH")
	if promLabelSelectorLength != "" {
		PromMonitorPodsLabelSelectorLength, err = strconv.Atoi(promLabelSelectorLength)
		if err != nil {
			Log("Custom prometheus label selector count string to int conversion error %s", err.Error())
		}
	}

	PromMonitorPodsFieldSelectorLength = 0
	promFieldSelectorLength := os.Getenv("TELEMETRY_CUSTOM_PROM_FIELD_SELECTOR_LENGTH")
	if promFieldSelectorLength != "" {
		PromMonitorPodsFieldSelectorLength, err = strconv.Atoi(promFieldSelectorLength)
		if err != nil {
			Log("Custom prometheus field selector count string to int conversion error %s", err.Error())
		}
	}

	return 0, nil
}

// PushToAppInsightsTraces sends the log lines as trace messages to the configured App Insights Instance
func PushToAppInsightsTraces(records []map[interface{}]interface{}, severityLevel contracts.SeverityLevel, tag string) int {
	var logLines []string
	for _, record := range records {
		// If record contains config error or prometheus scraping errors send it to KubeMonAgentEvents table
		var logEntry = ToString(record["log"])
		if strings.Contains(logEntry, "config::error") {
			populateKubeMonAgentEventHash(record, ConfigError)
		} else if strings.Contains(logEntry, "E! [inputs.prometheus]") {
			populateKubeMonAgentEventHash(record, PromScrapingError)
		} else {
			logLines = append(logLines, logEntry)
		}
	}

	traceEntry := strings.Join(logLines, "\n")
	traceTelemetryItem := appinsights.NewTraceTelemetry(traceEntry, severityLevel)
	traceTelemetryItem.Properties["tag"] = tag
	TelemetryClient.Track(traceTelemetryItem)
	return output.FLB_OK
}
