package main

import (
	"encoding/json"
	"fmt"
	"net"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/fluent/fluent-bit-go/output"
	"github.com/google/uuid"
	"github.com/tinylib/msgp/msgp"
)

// Stream names for network flow logs
const (
	ContainerNetworkLogsStreamName  = "CONTAINER_NETWORK_LOGS"   // New stream name
	RetinaNetworkFlowLogsStreamName = "RETINA_NETWORK_FLOW_LOGS" // Legacy stream name
)

var (
	// retina networkflow logs stream tag name
	MdsdNetworkFlowLogsStreamTagName string
	// flag to check whether network flow logs is enabled or not
	IsNetworkFlowLogsEnabled bool
)

var (
	// networkflow telemetry
	NetworkFlowTelemetryMutex             = &sync.Mutex{}
	NetworkFlowLogsMDSDClientCreateErrors float64
	MdsdNetworkFlowClient                 net.Conn
	NetworkFlowTagRefreshTracker          time.Time
)

// NetworkFlowMsgPackEntry represents the object corresponding to a single messagepack event in the messagepack stream
type NetworkFlowMsgPackEntry struct {
	Time   int64                  `msg:"time"`
	Record map[string]interface{} `msg:"record"`
}

// PostNetworkFlowRecords sends data to the mdsd and amacoreagent
func PostNetworkFlowRecords(tailPluginRecords []map[interface{}]interface{}) int {
	if IsNetworkFlowLogsEnabled && IsAADMSIAuthMode {
		start := time.Now()
		var elapsed time.Duration
		var bts int
		var er error

		var dataMap map[string]interface{}
		var networkFlowLogsMsgPackEntries []NetworkFlowMsgPackEntry
		numNetworkLogRecords := 0

		for _, record := range tailPluginRecords {
			networkFlowLogRecordInterface, err := convertFluentBitRecord(record)
			if err != nil {
				Log("Error::networkflow:: failed to convert fluent-bit record: %v", err.Error())
				continue
			}
			networkFlowLogRecord, ok := networkFlowLogRecordInterface.(map[string]interface{})
			if !ok {
				Log("Error::networkflow:: failed to convert networkflow record to map[string]interface{}: %v", networkFlowLogRecordInterface)
				continue
			}
			dataMap = make(map[string]interface{})
			if err := mapNetworkFlowLogsToDataMap(dataMap, networkFlowLogRecord); err != nil {
				Log("Error::networkflow:: failed to map networkflow logs to data map: %v", err.Error())
				continue
			}
			var networkFlowLogsMsgPackEntry NetworkFlowMsgPackEntry
			networkFlowLogsMsgPackEntry = NetworkFlowMsgPackEntry{
				Time:   time.Now().Unix(),
				Record: dataMap,
			}
			networkFlowLogsMsgPackEntries = append(networkFlowLogsMsgPackEntries, networkFlowLogsMsgPackEntry)
		}

		if len(networkFlowLogsMsgPackEntries) > 0 {
			// Try getting the stream tag with the new name first
			MdsdNetworkFlowLogsStreamTagName = getOutputStreamIdTag(ContainerNetworkLogsStreamName, MdsdNetworkFlowLogsStreamTagName, &NetworkFlowTagRefreshTracker)
			if MdsdNetworkFlowLogsStreamTagName == "" {
				// If new stream name fails, try the legacy stream name
				MdsdNetworkFlowLogsStreamTagName = getOutputStreamIdTag(RetinaNetworkFlowLogsStreamName, MdsdNetworkFlowLogsStreamTagName, &NetworkFlowTagRefreshTracker)
				if MdsdNetworkFlowLogsStreamTagName == "" {
					Log("Error::mdsd::Failed to get stream tag for networkflow logs. Will retry ...")
					return output.FLB_RETRY
				}
			}
			if MdsdNetworkFlowClient == nil {
				Log("Error::mdsd::mdsd connection does not exist for networkflow mdsd client. re-connecting ...")
				CreateMDSDClient(NetworkFlowLogs, ContainerType)
				if MdsdNetworkFlowClient == nil {
					Log("Error::mdsd::Unable to create mdsd client for networkflow. Please check error log.")
					NetworkFlowTelemetryMutex.Lock()
					defer NetworkFlowTelemetryMutex.Unlock()
					NetworkFlowLogsMDSDClientCreateErrors += 1

					return output.FLB_RETRY
				}
			}

			bts, er = writeNetworkFlowMsgPackEntries(MdsdNetworkFlowClient, MdsdNetworkFlowLogsStreamTagName, networkFlowLogsMsgPackEntries)
			elapsed = time.Since(start)

			if er != nil {
				Log("Error::mdsd::Failed to write to mdsd %d records for networkflow logs after %s. Will retry ... error : %s", len(networkFlowLogsMsgPackEntries), elapsed, er.Error())
				if MdsdNetworkFlowClient != nil {
					MdsdNetworkFlowClient.Close()
					MdsdNetworkFlowClient = nil
				}

				NetworkFlowTelemetryMutex.Lock()
				defer NetworkFlowTelemetryMutex.Unlock()
				NetworkFlowLogsMDSDClientCreateErrors += 1

				return output.FLB_RETRY
			} else {
				numNetworkLogRecords = len(networkFlowLogsMsgPackEntries)
				Log("Success::mdsd::Successfully flushed %d networkflow log records that was %d bytes to mdsd in %s ", numNetworkLogRecords, bts, elapsed)
			}
		}

		NetworkFlowTelemetryMutex.Lock()
		defer NetworkFlowTelemetryMutex.Unlock()

		if numNetworkLogRecords > 0 {
			NetworkFlowLogsFlushedCount += float64(numNetworkLogRecords)
			NetworkFlowLogsFlushedSize += float64(bts)
			NetworkFlowLogsFlushedTimeTaken += float64(elapsed / time.Millisecond)
		}
	}
	return output.FLB_OK
}

func convertFluentBitRecord(input interface{}) (interface{}, error) {
	switch v := input.(type) {
	case map[interface{}]interface{}:
		record := make(map[string]interface{})
		for key, value := range v {
			strKey, ok := key.(string)
			if !ok {
				strKey = fmt.Sprintf("%v", key)
			}
			convertedValue, err := convertFluentBitRecord(value)
			if err != nil {
				return nil, err
			}
			record[strKey] = convertedValue
		}
		return record, nil
	case []byte:
		return string(v), nil
	case []interface{}:
		records := make([]interface{}, len(v))
		for i, item := range v {
			convertedItem, err := convertFluentBitRecord(item)
			if err != nil {
				return nil, err
			}
			records[i] = convertedItem
		}
		return records, nil
	default:
		return v, nil
	}
}

func mapNetworkFlowLogsToDataMap(dataMap map[string]interface{}, record map[string]interface{}) error {
	defer func() {
		if r := recover(); r != nil {
			Log("Error::networkflow:: panic in mapNetworkFlowLogsToDataMap: %v", r)
		}
	}()

	flow, ok := record["flow"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("'flow' field not found or is not a map")
	}
	// TimeGenerated
	if timeGenerated := extractString(flow, "time"); timeGenerated != "" {
		dataMap["TimeGenerated"] = timeGenerated
	} else {
		Log("Error::networkflow:: critical field TimeGenerated is missing or empty")
	}
	// UUID
	if uuidVal := extractString(flow, "uuid"); uuidVal != "" {
		dataMap["UUID"] = uuidVal
	} else {
		dataMap["UUID"] = uuid.New().String()
	}
	// Verdict and DropReason
	if verdict := extractString(flow, "verdict"); verdict != "" {
		dataMap["Verdict"] = verdict
	}
	if dropReason := extractString(flow, "drop_reason_desc"); dropReason != "" {
		dataMap["DropReason"] = dropReason
	}
	// IP
	if ip, ok := flow["IP"].(map[string]interface{}); ok {
		dataMap["IP"] = serializeToJSON(ip)
	}
	// Layer4
	if l4, ok := flow["l4"].(map[string]interface{}); ok {
		dataMap["Layer4"] = serializeToJSON(l4)
	}
	// Source details
	if source, ok := flow["source"].(map[string]interface{}); ok {
		if identity := safeToInt(source["identity"]); identity != 0 {
			dataMap["SourceIdentity"] = identity
		}
		if clusterName := extractString(source, "cluster_name"); clusterName != "" {
			dataMap["SourceClusterName"] = clusterName
		}
		if namespace := extractString(source, "namespace"); namespace != "" {
			dataMap["SourceNamespace"] = namespace
		}
		if podName := extractString(source, "pod_name"); podName != "" {
			dataMap["SourcePodName"] = podName
		}
		if workloads, ok := source["workloads"].([]interface{}); ok && len(workloads) > 0 {
			dataMap["SourceWorkloads"] = serializeToJSON(workloads)
		}
	}
	// Destination details
	if dest, ok := flow["destination"].(map[string]interface{}); ok {
		if identity := safeToInt(dest["identity"]); identity != 0 {
			dataMap["DestinationIdentity"] = identity
		}
		if clusterName := extractString(dest, "cluster_name"); clusterName != "" {
			dataMap["DestinationClusterName"] = clusterName
		}
		if namespace := extractString(dest, "namespace"); namespace != "" {
			dataMap["DestinationNamespace"] = namespace
		}
		if podName := extractString(dest, "pod_name"); podName != "" {
			dataMap["DestinationPodName"] = podName
		}
		if workloads, ok := dest["workloads"].([]interface{}); ok && len(workloads) > 0 {
			dataMap["DestinationWorkloads"] = serializeToJSON(workloads)
		}
	}
	// FlowType
	if flowType := extractString(flow, "Type"); flowType != "" {
		dataMap["FlowType"] = flowType
	}
	// NodeName
	if nodeName := extractString(flow, "node_name"); nodeName != "" {
		parts := strings.SplitN(nodeName, "/", 2)
		if len(parts) == 2 {
			dataMap["NodeName"] = parts[1]
		} else {
			dataMap["NodeName"] = nodeName
		}
	}
	// Layer7
	if l7, ok := flow["l7"].(map[string]interface{}); ok {
		dataMap["Layer7"] = serializeToJSON(l7)
	}
	// Reply
	if isReply, ok := flow["is_reply"].(bool); ok {
		dataMap["Reply"] = isReply
	}
	// EventType
	if eventType, ok := flow["event_type"].(map[string]interface{}); ok {
		dataMap["EventType"] = serializeToJSON(eventType)
	}
	// Service
	serviceData := map[string]interface{}{}
	if sourceService, ok := flow["source_service"].(map[string]interface{}); ok {
		if serviceName, ok := sourceService["name"].(string); ok {
			serviceData["SourceService"] = serviceName
		}
		if serviceNS, ok := sourceService["namespace"].(string); ok {
			serviceData["SourceServiceNamespace"] = serviceNS
		}
	}
	if destinationService, ok := flow["destination_service"].(map[string]interface{}); ok {
		if serviceName, ok := destinationService["name"].(string); ok {
			serviceData["DestinationService"] = serviceName
		}
		if serviceNS, ok := destinationService["namespace"].(string); ok {
			serviceData["DestinationServiceNamespace"] = serviceNS
		}
	}
	if len(serviceData) > 0 {
		dataMap["Service"] = serializeToJSON(serviceData)
	}
	// TrafficDirection and TraceObservationPoint
	if trafficDirection := extractString(flow, "traffic_direction"); trafficDirection != "" {
		dataMap["TrafficDirection"] = trafficDirection
	}
	if traceObservationPoint := extractString(flow, "trace_observation_point"); traceObservationPoint != "" {
		dataMap["TraceObservationPoint"] = traceObservationPoint
	}
	// Flow counts from extensions
	if extensions, ok := flow["extensions"].(map[string]interface{}); ok {
		if ingressCount, ok := extensions["ingress_flow_count"]; ok {
			dataMap["IngressFlowCount"] = safeToInt(ingressCount)
		}
		if egressCount, ok := extensions["egress_flow_count"]; ok {
			dataMap["EgressFlowCount"] = safeToInt(egressCount)
		}
		if unknownCount, ok := extensions["unknown_direction_flow_count"]; ok {
			dataMap["UnknownDirectionFlowCount"] = safeToInt(unknownCount)
		}
	}
	// Policies
	policiesData := map[string]interface{}{}
	if val, ok := flow["egress_allowed_by"]; ok {
		policiesData["egress_allowed_by"] = serializeToJSON(val)
	}
	if val, ok := flow["ingress_allowed_by"]; ok {
		policiesData["ingress_allowed_by"] = serializeToJSON(val)
	}
	if val, ok := flow["egress_denied_by"]; ok {
		policiesData["egress_denied_by"] = serializeToJSON(val)
	}
	if val, ok := flow["ingress_denied_by"]; ok {
		policiesData["ingress_denied_by"] = serializeToJSON(val)
	}
	if len(policiesData) > 0 {
		dataMap["Policies"] = serializeToJSON(policiesData)
	}
	// AdditionalFlowData
	additionalData := map[string]interface{}{}
	if ethernet, ok := flow["ethernet"].(map[string]interface{}); ok {
		if source, ok := ethernet["source"].(string); ok {
			additionalData["EthernetSource"] = source
		}
		if destination, ok := ethernet["destination"].(string); ok {
			additionalData["EthernetDestination"] = destination
		}
	}
	if sourceLabels := extractLabels(flow["source"]); len(sourceLabels) > 0 {
		additionalData["SourceLabels"] = sourceLabels
	}
	if destinationLabels := extractLabels(flow["destination"]); len(destinationLabels) > 0 {
		additionalData["DestinationLabels"] = destinationLabels
	}
	if summary, ok := flow["Summary"]; ok {
		additionalData["Summary"] = summary
	}
	if extensions, ok := flow["extensions"].(map[string]interface{}); ok {
		// Create a new map without the flow count fields
		filteredExtensions := make(map[string]interface{})
		for k, v := range extensions {
			if k != "ingress_flow_count" && k != "egress_flow_count" && k != "unknown_direction_flow_count" {
				filteredExtensions[k] = v
			}
		}
		if len(filteredExtensions) > 0 {
			additionalData["Extensions"] = filteredExtensions
		}
	}
	if len(additionalData) > 0 {
		dataMap["AdditionalFlowData"] = serializeToJSON(additionalData)
	}
	return nil
}

func extractString(m map[string]interface{}, key string) string {
	if val, ok := m[key].(string); ok {
		return val
	}
	return ""
}

func serializeToJSON(v interface{}) string {
	bytes, err := json.Marshal(v)
	if err != nil {
		return ""
	}
	return string(bytes)
}

func safeToInt(value interface{}) int {
	switch v := value.(type) {
	case float64:
		return int(v)
	case int:
		return v
	case int64:
		return int(v)
	case uint64:
		return int(v)
	case string:
		if intVal, err := strconv.Atoi(v); err == nil {
			return intVal
		}
	default:
		Log(fmt.Sprintf("Error: safeToInt: unsupported type %T", value))
	}
	return 0
}

func extractLabels(source interface{}) []string {
	if src, ok := source.(map[string]interface{}); ok {
		if labels, ok := src["labels"].([]interface{}); ok {
			var labelStrs []string
			for _, label := range labels {
				if labelStr, ok := label.(string); ok {
					labelStrs = append(labelStrs, labelStr)
				}
			}
			return labelStrs
		}
	}
	return nil
}

func writeNetworkFlowMsgPackEntries(connection net.Conn, fluentForwardTag string, networkFlowLogsMsgPackEntries []NetworkFlowMsgPackEntry) (totalBytes int, err error) {
	var bts int
	var er error
	msgpBytes := convertNetworkFlowMsgPackEntriesToMsgpBytes(fluentForwardTag, networkFlowLogsMsgPackEntries)
	deadline := 10 * time.Second
	connection.SetWriteDeadline(time.Now().Add(deadline))
	bts, er = connection.Write(msgpBytes)
	if er != nil {
		Log("Error::mdsd::Failed to write to mdsd %d bytes for networkflow logs. Error : %s", bts, er.Error())
		return bts, er
	}
	return bts, er
}

func convertNetworkFlowMsgPackEntriesToMsgpBytes(fluentForwardTag string, msgPackEntries []NetworkFlowMsgPackEntry) []byte {
	fluentForward := struct {
		Tag     string                    `msg:"tag"`
		Entries []NetworkFlowMsgPackEntry `msg:"entries"`
	}{
		Tag:     fluentForwardTag,
		Entries: msgPackEntries,
	}

	var msgpBytes []byte
	msgpBytes = append(msgpBytes, 0x92)
	msgpBytes = msgp.AppendString(msgpBytes, fluentForward.Tag)
	msgpBytes = msgp.AppendArrayHeader(msgpBytes, uint32(len(fluentForward.Entries)))

	batchTime := time.Now().Unix()
	for _, entry := range fluentForward.Entries {
		msgpBytes = append(msgpBytes, 0x92)
		msgpBytes = msgp.AppendInt64(msgpBytes, batchTime)

		msgpBytes = msgp.AppendMapHeader(msgpBytes, uint32(len(entry.Record)))
		for key, value := range entry.Record {
			msgpBytes = msgp.AppendString(msgpBytes, key)

			switch v := value.(type) {
			case string:
				msgpBytes = msgp.AppendString(msgpBytes, v)
			case int:
				msgpBytes = msgp.AppendInt64(msgpBytes, int64(v))
			case bool:
				msgpBytes = msgp.AppendBool(msgpBytes, v)
			case float64:
				msgpBytes = msgp.AppendFloat64(msgpBytes, v)
			default:
				msgpBytes = msgp.AppendString(msgpBytes, fmt.Sprintf("%v", v))
			}
		}
	}
	return msgpBytes
}
