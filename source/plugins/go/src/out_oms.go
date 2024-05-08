package main

import (
	"github.com/fluent/fluent-bit-go/output"
	"github.com/microsoft/ApplicationInsights-Go/appinsights"
)
import (
	"C"
	"os"
	"strings"
	"unsafe"
)

//export FLBPluginRegister
func FLBPluginRegister(ctx unsafe.Pointer) int {
	return output.FLBPluginRegister(ctx, "oms", "OMS GO!")
}

// (fluentbit will call this)
// ctx (context) pointer to fluentbit context (state/ c code)
//
//export FLBPluginInit
func FLBPluginInit(ctx unsafe.Pointer) int {
	Log("Initializing out_oms go plugin for fluentbit")
	agentVersion := os.Getenv("AGENT_VERSION")

	osType := os.Getenv("OS_TYPE")
	if strings.Compare(strings.ToLower(osType), "windows") == 0 {
		Log("Using %s for plugin config \n", WindowsContainerLogPluginConfFilePath)
		InitializePlugin(WindowsContainerLogPluginConfFilePath, agentVersion)
	} else {
		if strings.Compare(strings.ToLower(os.Getenv("CONTROLLER_TYPE")), "replicaset") == 0 {
			Log("Using %s for plugin config \n", ReplicaSetContainerLogPluginConfFilePath)
			InitializePlugin(ReplicaSetContainerLogPluginConfFilePath, agentVersion)
		} else {
			Log("Using %s for plugin config \n", DaemonSetContainerLogPluginConfFilePath)
			InitializePlugin(DaemonSetContainerLogPluginConfFilePath, agentVersion)
		}
	}

	enableTelemetry := output.FLBPluginConfigKey(ctx, "EnableTelemetry")
	if strings.Compare(strings.ToLower(enableTelemetry), "true") == 0 {
		telemetryPushInterval := output.FLBPluginConfigKey(ctx, "TelemetryPushIntervalSeconds")
		go SendContainerLogPluginMetrics(telemetryPushInterval)
		go SendTracesAsMetrics(telemetryPushInterval)
	} else {
		Log("Telemetry is not enabled for the plugin %s \n", output.FLBPluginConfigKey(ctx, "Name"))
		return output.FLB_OK
	}
	return output.FLB_OK
}

//export FLBPluginFlush
func FLBPluginFlush(data unsafe.Pointer, length C.int, tag *C.char) int {
	var ret int
	var record map[interface{}]interface{}
	var records []map[interface{}]interface{}

	// Create Fluent Bit decoder
	dec := output.NewDecoder(data, int(length))

	// Iterate Records
	for {
		// Extract Record
		ret, _, record = output.GetRecord(dec)
		if ret != 0 {
			break
		}
		records = append(records, record)
	}

	incomingTag := strings.ToLower(C.GoString(tag))
	switch {
	case strings.Contains(incomingTag, "oms.container.log.flbplugin"):
		// This will also include populating cache to be sent as for config events
		return PushToAppInsightsTraces(records, appinsights.Information, incomingTag)
	case strings.Contains(incomingTag, "oms.container.perf.telegraf"):
		return PostTelegrafMetricsToLA(records)
	case strings.Contains(incomingTag, "oms.container.oneagent.containerinsights"):
		return PostInputPluginRecords(records)
	default:
		return PostDataHelper(records)
	}
}

// FLBPluginExit exits the plugin
func FLBPluginExit() int {
	ContainerLogTelemetryTicker.Stop()
	ContainerImageNameRefreshTicker.Stop()
	return output.FLB_OK
}

func main() {
}
