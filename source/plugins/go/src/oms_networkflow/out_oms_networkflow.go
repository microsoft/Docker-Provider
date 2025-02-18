package main

import (
	"fmt"

	"github.com/fluent/fluent-bit-go/output"
)
import (
	"C"
	"unsafe"

	uuid "github.com/google/uuid"
)

//export FLBPluginRegister
func FLBPluginRegister(ctx unsafe.Pointer) int {
	return output.FLBPluginRegister(ctx, "oms_network_flow", "OMS GO!")
}

// (fluentbit will call this)
// ctx (context) pointer to fluentbit context (state/ c code)
//
//export FLBPluginInit
func FLBPluginInit(ctx unsafe.Pointer) int {
	// Log("Initializing out_oms go plugin for fluentbit")
	// agentVersion := os.Getenv("AGENT_VERSION")

	// osType := os.Getenv("OS_TYPE")
	// Log("Using %s for plugin config \n", DaemonSetContainerLogPluginConfFilePath)
	// InitializePlugin(DaemonSetContainerLogPluginConfFilePath, agentVersion)

	// enableTelemetry := output.FLBPluginConfigKey(ctx, "EnableTelemetry")
	// if strings.Compare(strings.ToLower(enableTelemetry), "true") == 0 {
	// 	telemetryPushInterval := output.FLBPluginConfigKey(ctx, "TelemetryPushIntervalSeconds")
	// 	go SendContainerLogPluginMetrics(telemetryPushInterval)
	// 	go SendTracesAsMetrics(telemetryPushInterval)
	// } else {
	// 	Log("Telemetry is not enabled for the plugin %s \n", output.FLBPluginConfigKey(ctx, "Name"))
	// 	return output.FLB_OK
	// }
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

	// incomingTag := strings.ToLower(C.GoString(tag))
	switch {
	// case strings.Contains(incomingTag, "oms.container.log.flbplugin"):
	// 	// This will also include populating cache to be sent as for config events
	// 	return PushToAppInsightsTraces(records, appinsights.Information, incomingTag)
	// case strings.Contains(incomingTag, "oms.container.perf.telegraf"):
	// 	return PostTelegrafMetricsToLA(records)
	// case strings.Contains(incomingTag, "oms.container.oneagent.containerinsights"):
	// 	return PostInputPluginRecords(records)
	default:
		return PostDataHelper(records)
	}
}

func PostDataHelper(records []map[interface{}]interface{}) int {
	return output.FLB_OK
}

// FLBPluginExit exits the plugin
func FLBPluginExit() int {
	// ContainerLogTelemetryTicker.Stop()
	// ContainerImageNameRefreshTicker.Stop()
	return output.FLB_OK
}

func main() {
}

type NetworkFlowLog struct {
	TimeGenerated          string `json:"TimeGenerated"`
	UUID                   string `json:"UUID"`
	Verdict                string `json:"Verdict"`
	DropReason             string `json:"DropReason"`
	IP                     string `json:"IP"`     // interface
	Layer4                 string `json:"Layer4"` // interface
	SourceIdentity         int    `json:"SourceIdentity"`
	SourceClusterName      string `json:"SourceClusterName"`
	SourceNamespace        string `json:"SourceNamespace"`
	SourcePodName          string `json:"SourcePodName"`
	SourceWorkloads        string `json:"SourceWorkloads"` // interface
	DestinationIdentity    int    `json:"DestinationIdentity"`
	DestinationClusterName string `json:"DestinationClusterName"`
	DestinationNamespace   string `json:"DestinationNamespace"`
	DestinationPodName     string `json:"DestinationPodName"`
	DestinationWorkloads   string `json:"DestinationWorkloads"` // interface
	FlowType               string `json:"FlowType"`
	NodeName               string `json:"NodeName"`
	Layer7                 string `json:"Layer7"` // interface
	Reply                  bool   `json:"Reply"`
	EventType              string `json:"EventType"` // interface
	Service                string `json:"Service"`   // interface
	TrafficDirection       string `json:"TrafficDirection"`
	TraceObservationPoint  string `json:"TraceObservationPoint"`
	PacketsSent            int    `json:"PacketsSent"`
	PacketsReceived        int    `json:"PacketsReceived"`
	Policies               string `json:"Policies"` // interface
	AdditionalFlowData     string `json:"AdditionalFlowData"`
}

var sampleLog1 = NetworkFlowLog{
	TimeGenerated:          "2025-01-27T19:30:14.716397550Z",
	UUID:                   uuid.New().String(),
	Verdict:                "FORWARDED",
	DropReason:             "",
	IP:                     `{"source": "10.0.190.166", "destination": "192.168.0.213", "ipVersion": "IPv4"}`,
	Layer4:                 `{"TCP": {"source_port": 8080, "destination_port": 60072, "flags": {"ACK": true}}}`,
	SourceIdentity:         2,
	SourceClusterName:      "default",
	SourceNamespace:        "default",
	SourcePodName:          "kapinger-good-8468b88556-d75x8",
	SourceWorkloads:        `["reserved:world"]`,
	DestinationIdentity:    56017,
	DestinationClusterName: "default",
	DestinationNamespace:   "default",
	DestinationPodName:     "kapinger-good-8468b88556-d75x8",
	DestinationWorkloads:   `["k8s:server=good", "k8s:app=kapinger"]`,
	FlowType:               "L3_L4",
	NodeName:               "",
	Layer7:                 "",
	Reply:                  false,
	EventType:              `{"type": 4}`,
	Service:                `{"name": "kapinger-service", "namespace": "default"}`,
	TrafficDirection:       "EGRESS",
	TraceObservationPoint:  "TO_ENDPOINT",
	PacketsSent:            0,
	PacketsReceived:        0,
	Policies:               "",
	AdditionalFlowData:     `{"bytes": 66}`,
}

var sampleLog2 = NetworkFlowLog{
	TimeGenerated:          "2025-01-27T19:30:14.716362549Z",
	UUID:                   uuid.New().String(),
	Verdict:                "FORWARDED",
	DropReason:             "",
	IP:                     `{"source": "192.168.0.213", "destination": "192.168.0.60", "ipVersion": "IPv4"}`,
	Layer4:                 `{"TCP": {"source_port": 60072, "destination_port": 8080, "flags": {"FIN": true, "ACK": true}}}`,
	SourceIdentity:         56017,
	SourceClusterName:      "default",
	SourceNamespace:        "default",
	SourcePodName:          "kapinger-good-8468b88556-d75x8",
	SourceWorkloads:        `["k8s:server=good", "k8s:app=kapinger"]`,
	DestinationIdentity:    56017,
	DestinationClusterName: "default",
	DestinationNamespace:   "default",
	DestinationPodName:     "kapinger-good-8468b88556-86vlw",
	DestinationWorkloads:   `["k8s:server=good", "k8s:app=kapinger"]`,
	FlowType:               "L3_L4",
	NodeName:               "",
	Layer7:                 "",
	Reply:                  true,
	EventType:              `{"type": 4}`,
	Service:                "",
	TrafficDirection:       "INGRESS",
	TraceObservationPoint:  "TO_ENDPOINT",
	PacketsSent:            0,
	PacketsReceived:        0,
	Policies:               "",
	AdditionalFlowData:     `{"bytes": 66}`,
}

var sampleLog3 = NetworkFlowLog{
	TimeGenerated:          "2025-01-27T19:30:14.719762911Z",
	UUID:                   uuid.New().String(),
	Verdict:                "FORWARDED",
	DropReason:             "",
	IP:                     `{"source": "192.168.0.168", "destination": "10.0.190.166", "ipVersion": "IPv4"}`,
	Layer4:                 `{"TCP": {"source_port": 56846, "destination_port": 8080, "flags": {"SYN": true}}}`,
	SourceIdentity:         56017,
	SourceClusterName:      "default",
	SourceNamespace:        "default",
	SourcePodName:          "kapinger-good-8468b88556-brggs",
	SourceWorkloads:        `["k8s:server=good", "k8s:app=kapinger"]`,
	DestinationIdentity:    2,
	DestinationClusterName: "default",
	DestinationNamespace:   "",
	DestinationPodName:     "",
	DestinationWorkloads:   `["reserved:world"]`,
	FlowType:               "L3_L4",
	NodeName:               "",
	Layer7:                 "",
	Reply:                  true,
	EventType:              `{"type": 4, "sub_type": 3}`,
	Service:                `{"name": "kapinger-service", "namespace": "default"}`,
	TrafficDirection:       "EGRESS",
	TraceObservationPoint:  "TO_STACK",
	PacketsSent:            0,
	PacketsReceived:        0,
	Policies:               "",
	AdditionalFlowData:     `{"bytes": 74}`,
}

var sampleLog4 = NetworkFlowLog{
	TimeGenerated:          "2025-01-27T19:30:14.721849748Z",
	UUID:                   uuid.New().String(),
	Verdict:                "DROPPED",
	DropReason:             "Policy denied",
	IP:                     `{"source": "192.168.0.0", "destination": "10.0.190.166", "ipVersion": "IPv4"}`,
	Layer4:                 `{"TCP": {"source_port": 34308, "destination_port": 8080, "flags": {"SYN": true}}}`,
	SourceIdentity:         2118,
	SourceClusterName:      "default",
	SourceNamespace:        "default",
	SourcePodName:          "kapinger-bad-7778f55bf8-f5xhd",
	SourceWorkloads:        `["k8s:server=bad", "k8s:app=kapinger"]`,
	DestinationIdentity:    2,
	DestinationClusterName: "default",
	DestinationNamespace:   "",
	DestinationPodName:     "",
	DestinationWorkloads:   `["reserved:world"]`,
	FlowType:               "L3_L4",
	NodeName:               "",
	Layer7:                 "",
	Reply:                  false,
	EventType:              `{"type": 4, "sub_type": 3}`,
	Service:                `{"name": "kapinger-service", "namespace": "default"}`,
	TrafficDirection:       "EGRESS",
	TraceObservationPoint:  "TO_STACK",
	PacketsSent:            0,
	PacketsReceived:        0,
	Policies:               "",
	AdditionalFlowData:     `{"bytes": 74}`,
}

var sampleLog5 = NetworkFlowLog{
	TimeGenerated:          "2025-01-27T19:30:14.723849748Z",
	UUID:                   uuid.New().String(),
	Verdict:                "FORWARDED",
	DropReason:             "",
	IP:                     `{"source": "192.168.0.2", "destination": "10.0.190.168", "ipVersion": "IPv4"}`,
	Layer4:                 `{"TCP": {"source_port": 54321, "destination_port": 443, "flags": {"SYN": true}}}`,
	SourceIdentity:         4321,
	SourceClusterName:      "default",
	SourceNamespace:        "default",
	SourcePodName:          "layer7-pod",
	SourceWorkloads:        `["k8s:server=layer7", "k8s:app=layer7"]`,
	DestinationIdentity:    8765,
	DestinationClusterName: "default",
	DestinationNamespace:   "default",
	DestinationPodName:     "layer7-pod",
	DestinationWorkloads:   `["k8s:server=layer7", "k8s:app=layer7"]`,
	FlowType:               "L7",
	NodeName:               "",
	Layer7:                 `{"HTTP": {"method": "GET", "url": "http://example.com"}}`,
	Reply:                  false,
	EventType:              `{"type": 4, "sub_type": 3}`,
	Service:                `{"name": "layer7-service", "namespace": "default"}`,
	TrafficDirection:       "EGRESS",
	TraceObservationPoint:  "TO_STACK",
	PacketsSent:            0,
	PacketsReceived:        0,
	Policies:               "",
	AdditionalFlowData:     `{"bytes": 74}`,
}

func writeMsgPackEntries() {
	stringMap := make(map[string]string)
	populateStringMapFromNetworkFlowLog(stringMap, sampleLog1)
}

func populateStringMapFromNetworkFlowLog(stringMap map[string]string, networkFlowLog NetworkFlowLog) {
	stringMap["TimeGenerated"] = networkFlowLog.TimeGenerated
	stringMap["UUID"] = networkFlowLog.UUID
	stringMap["Verdict"] = networkFlowLog.Verdict
	stringMap["DropReason"] = networkFlowLog.DropReason
	stringMap["SourceClusterName"] = networkFlowLog.SourceClusterName
	stringMap["SourceNamespace"] = networkFlowLog.SourceNamespace
	stringMap["SourcePodName"] = networkFlowLog.SourcePodName
	stringMap["DestinationClusterName"] = networkFlowLog.DestinationClusterName
	stringMap["DestinationNamespace"] = networkFlowLog.DestinationNamespace
	stringMap["DestinationPodName"] = networkFlowLog.DestinationPodName
	stringMap["FlowType"] = networkFlowLog.FlowType
	stringMap["NodeName"] = networkFlowLog.NodeName
	stringMap["TrafficDirection"] = networkFlowLog.TrafficDirection
	stringMap["TraceObservationPoint"] = networkFlowLog.TraceObservationPoint

	if networkFlowLog.IP != "" {
		stringMap["IP"] = networkFlowLog.IP
	}

	if networkFlowLog.Layer4 != "" {
		stringMap["Layer4"] = networkFlowLog.Layer4
	}

	if networkFlowLog.SourceWorkloads != "" {
		stringMap["SourceWorkloads"] = networkFlowLog.SourceWorkloads
	}

	if networkFlowLog.DestinationWorkloads != "" {
		stringMap["DestinationWorkloads"] = networkFlowLog.DestinationWorkloads
	}

	if networkFlowLog.Layer7 != "" {
		stringMap["Layer7"] = networkFlowLog.Layer7
	}

	if networkFlowLog.EventType != "" {
		stringMap["EventType"] = networkFlowLog.EventType
	}

	if networkFlowLog.Service != "" {
		stringMap["Service"] = networkFlowLog.Service
	}

	if networkFlowLog.Policies != "" {
		stringMap["Policies"] = networkFlowLog.Policies
	}

	if networkFlowLog.AdditionalFlowData != "" {
		stringMap["AdditionalFlowData"] = networkFlowLog.AdditionalFlowData
	}

	stringMap["SourceIdentity"] = fmt.Sprintf("%d", networkFlowLog.SourceIdentity)
	stringMap["DestinationIdentity"] = fmt.Sprintf("%d", networkFlowLog.DestinationIdentity)
	stringMap["Reply"] = fmt.Sprintf("%t", networkFlowLog.Reply)
	stringMap["PacketsSent"] = fmt.Sprintf("%d", networkFlowLog.PacketsSent)
	stringMap["PacketsReceived"] = fmt.Sprintf("%d", networkFlowLog.PacketsReceived)
}
