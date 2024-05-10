package lib

import (
	"encoding/base64"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"

	"github.com/microsoft/ApplicationInsights-Go/appinsights"
)

const (
	heartBeat       = "HeartBeatEvent"
	exception       = "ExceptionEvent"
	acsClusterType  = "ACS"
	aksClusterType  = "AKS"
	envAcsResource  = "ACS_RESOURCE_NAME"
	envAksRegion    = "AKS_REGION"
	envAgentVersion = "AGENT_VERSION"
	envAppInsights  = "APPLICATIONINSIGHTS_AUTH"
	envAppEndpoint  = "APPLICATIONINSIGHTS_ENDPOINT"
	envController   = "CONTROLLER_TYPE"
	envContainerRT  = "CONTAINER_RUNTIME"
	envAADMSIAuth   = "AAD_MSI_AUTH_MODE"
	envAddonResizer = "RS_ADDON-RESIZER_VPA_ENABLED"
)

var (
	isWindows        bool
	hostName         string
	customProperties map[string]string
	telemetryClient  appinsights.TelemetryClient
	proxyEndpoint    string
	aiLogger         *log.Logger
)

var controllerType = map[string]string{
	"daemonset":  "DS",
	"replicaset": "RS",
}

func init() {
	// Check if the OS is Windows
	osType := os.Getenv("OS_TYPE")
	hostName = os.Getenv("HOSTNAME")
	if strings.TrimSpace(strings.ToLower(osType)) == "windows" {
		isWindows = true
	} else {
		isWindows = false
	}
	var logPath string
	if isWindows {
		logPath = "/etc/amalogswindows/appinsights_error.log"
	} else {
		logPath = "/var/opt/microsoft/docker-cimprov/log/appinsights_error.log"
	}

	aiLogger = CreateLogger(logPath)
	// Initialize customProperties
	customProperties = make(map[string]string)
	if !isIgnoreProxySettings() {
		if isWindows {
			proxyEndpoint = os.Getenv("PROXY")

		} else {
			var err error
			proxyEndpoint, err = getProxyEndpoint()
			if err != nil {
				aiLogger.Printf("Error getting proxy endpoint: %s", err.Error())
			}
		}
	}

	// Retrieve environment variables
	resourceInfo := os.Getenv("AKS_RESOURCE_ID")
	if resourceInfo == "" {
		customProperties["ID"] = os.Getenv(envAcsResource)
		customProperties["Region"] = ""
	} else {
		customProperties["ID"] = resourceInfo
		customProperties["Region"] = os.Getenv(envAksRegion)
	}

	customProperties["WSID"] = os.Getenv("WSID")
	customProperties["Version"] = os.Getenv(envAgentVersion)
	customProperties["Controller"] = controllerType[strings.ToLower(os.Getenv(envController))]
	customProperties["Computer"] = hostName
	encodedAppInsightsKey := os.Getenv(envAppInsights)
	appInsightsEndpoint := os.Getenv(envAppEndpoint)
	customProperties["WSCloud"] = getWorkspaceCloud()
	customProperties["cri"] = os.Getenv(envContainerRT)
	isProxyConfigured := false
	if proxyEndpoint != "" {
		customProperties["Proxy"] = "true"
		isProxyConfigured = true
		if isProxyCACertConfigured() {
			customProperties["IsProxyCACertConfigured"] = "true"
		}
	} else {
		customProperties["Proxy"] = "false"
		isProxyConfigured = false
		if isIgnoreProxySettings() {
			customProperties["IsProxyConfigurationIgnored"] = "true"
		}
	}

	isMSI := os.Getenv(envAADMSIAuth)
	if isMSI != "" && strings.EqualFold(isMSI, "true") {
		customProperties["isMSI"] = "true"
	} else {
		customProperties["isMSI"] = "false"
	}

	addonResizerVPAEnabled := os.Getenv(envAddonResizer)
	if addonResizerVPAEnabled != "" && strings.EqualFold(addonResizerVPAEnabled, "true") {
		customProperties["addonResizerVPAEnabled"] = "true"
	}

	if encodedAppInsightsKey != "" {
		decodedAppInsightsKey, err := base64.StdEncoding.DecodeString(encodedAppInsightsKey)
		if err != nil {
			aiLogger.Printf("Error decoding Application Insights key: %s", err.Error())
		}

		telemetryClientConfig := appinsights.NewTelemetryConfiguration(string(decodedAppInsightsKey))

		if appInsightsEndpoint != "" {
			aiLogger.Printf("Setting Application Insights endpoint to %s", appInsightsEndpoint)
			telemetryClientConfig.EndpointUrl = appInsightsEndpoint
		}

		if isProxyConfigured {
			proxyEndpointUrl, err := url.Parse(proxyEndpoint)
			if err != nil {
				aiLogger.Printf("Error parsing proxy endpoint: %s", err.Error())
				telemetryClient = nil
				return
			}

			transport := &http.Transport{
				Proxy: http.ProxyURL(proxyEndpointUrl),
			}
			httpClient := &http.Client{
				Transport: transport,
			}
			telemetryClientConfig.Client = httpClient
		}
		telemetryClient = appinsights.NewTelemetryClientFromConfig(telemetryClientConfig)
	}

	telemetryOffStr := os.Getenv("DISABLE_TELEMETRY")
	if strings.EqualFold(telemetryOffStr, "true") {
		telemetryClient.SetIsEnabled(false)
	}

}

func sendHeartBeatEvent(pluginName string) {
	eventName := pluginName + heartBeat
	if telemetryClient != nil {
		event := appinsights.NewEventTelemetry(eventName)
		event.Properties = customProperties
		telemetryClient.Track(event)
		aiLogger.Printf("AppInsights Heartbeat Telemetry put successfully into the queue")
	}
}

func sendLastProcessedContainerInventoryCountMetric(pluginName string, properties map[string]string) {
	if telemetryClient != nil {
		containerCount, _ := strconv.ParseFloat(properties["ContainerCount"], 64)
		metric := appinsights.NewMetricTelemetry("LastProcessedContainerInventoryCount", containerCount)
		metric.Properties = customProperties
		telemetryClient.Track(metric)
		aiLogger.Printf("AppInsights Container Count Telemetry put successfully into the queue")
	}
}

func SendCustomEvent(eventName string, properties map[string]string) {
	telemetryProps := make(map[string]string)

	// add common dimensions
	for k, v := range customProperties {
		telemetryProps[k] = v
	}

	// add passed-in dimensions if any
	for k, v := range properties {
		telemetryProps[k] = v
	}

	if telemetryClient != nil {
		event := appinsights.NewEventTelemetry(eventName)
		event.Properties = telemetryProps
		telemetryClient.Track(event)
		aiLogger.Printf("AppInsights Custom Event %s sent successfully\n", eventName)
	}
}

func SendExceptionTelemetry(errorStr string, properties map[string]string) {
	telemetryProps := make(map[string]string)

	// add common dimensions
	for k, v := range customProperties {
		telemetryProps[k] = v
	}

	// add passed-in dimensions if any
	for k, v := range properties {
		telemetryProps[k] = v
	}

	if telemetryClient != nil {
		exception := appinsights.NewExceptionTelemetry(errorStr)
		exception.Properties = telemetryProps
		telemetryClient.Track(exception)
		aiLogger.Printf("AppInsights Exception Telemetry put successfully into the queue")
	}
}

func SendTelemetry(pluginName string, properties map[string]string) {
	customProperties["Computer"] = properties["Computer"]
	if v, ok := properties["addonTokenAdapterImageTag"]; ok && v != "" {
		customProperties["addonTokenAdapterImageTag"] = v
	}

	sendHeartBeatEvent(pluginName)
	sendLastProcessedContainerInventoryCountMetric(pluginName, properties)
}

func SendMetricTelemetry(metricName string, metricValue float64, properties map[string]string) {
	if metricName == "" {
		log.Println("SendMetricTelemetry: metricName is missing")
		return
	}

	telemetryProps := make(map[string]string)

	// add common dimensions
	for k, v := range customProperties {
		telemetryProps[k] = v
	}

	// add passed-in dimensions if any
	for k, v := range properties {
		telemetryProps[k] = v
	}

	if telemetryClient != nil {
		metric := appinsights.NewMetricTelemetry(metricName, metricValue)
		metric.Properties = telemetryProps
		telemetryClient.Track(metric)
		aiLogger.Printf("AppInsights metric Telemetry %s put successfully into the queue\n", metricName)
	}
}

func SendException(err interface{}) {
	if telemetryClient != nil {
		telemetryClient.TrackException(err)
	}
}

func getWorkspaceCloud() string {
	workspaceDomain := os.Getenv("DOMAIN")
	workspaceCloud := "AzureCloud"
	switch strings.ToLower(workspaceDomain) {
	case "opinsights.azure.com":
		workspaceCloud = "AzureCloud"
	case "opinsights.azure.cn":
		workspaceCloud = "AzureChinaCloud"
	case "opinsights.azure.us":
		workspaceCloud = "AzureUSGovernment"
	case "opinsights.azure.de":
		workspaceCloud = "AzureGermanCloud"
	default:
		workspaceCloud = "Unknown"
	}
	return workspaceCloud
}
