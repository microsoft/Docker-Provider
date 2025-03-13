package main

import (
	"fmt"
	"net"
	"sync"
	"time"
	"strconv"
	"encoding/json"

	"github.com/fluent/fluent-bit-go/output"
	"github.com/tinylib/msgp/msgp"
	"github.com/google/uuid"
)

// Stream name for retina networkflow logs
const RetinaNetworkFlowLogsStreamName = "RETINA_NETWORK_FLOW_LOGS"

var (
	// retina networkflow logs stream tag name
	MdsdNetworkFlowLogsStreamTagName string
	// flag to check whether the network flow logs are enabled
	IsNetworkFlowLogsEnabled bool
)

var (
	// networkflow telemetry
    NetworkFlowTelemetryMutex = &sync.Mutex{}
    NetworkFlowLogsMDSDClientCreateErrors float64
    MdsdNetworkFlowClient net.Conn
    NetworkFlowTagRefreshTracker time.Time
)

// NetworkFlowMsgPackEntry represents the object corresponding to a single messagepack event in the messagepack stream
type NetworkFlowMsgPackEntry struct {
	Time   int64                  `msg:"time"`
	Record map[string]interface{} `msg:"record"`
}

// PostNetworkFlowRecords sends data to the mdsd and amacoreagent
func PostNetworkFlowRecords(tailPluginRecords []map[interface{}]interface{}) int {
	if IsNetworkFlowLogsEnabled {
		Log(fmt.Sprintf("Debug: PostNetworkFlowRecords starting"))
		start := time.Now()
		var elapsed time.Duration

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
			if IsAADMSIAuthMode == true {
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

			bts, er := writeNetworkFlowMsgPackEntries(MdsdNetworkFlowClient, MdsdNetworkFlowLogsStreamTagName, networkFlowLogsMsgPackEntries)
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

		//TODO Telemetry
		// NetworkFlowTelemetryMutex.Lock()
		// defer NetworkFlowTelemetryMutex.Unlock()

		// if numNetworkLogRecords > 0 {
		// 	FlushedRecordsCount += float64(numNetworkLogRecords)
		// 	FlushedRecordsTimeTaken += float64(elapsed / time.Millisecond)

		// 	if maxLatency >= AgentLogProcessingMaxLatencyMs {
		// 		AgentLogProcessingMaxLatencyMs = maxLatency
		// 	}
		// }
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
	flow, ok := record["flow"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("'flow' field not found or is not a map")
	}
	// TimeGenerated
	dataMap["TimeGenerated"] = extractString(flow, "time")
	// UUID
	if uuidVal := extractString(record, "UUID"); uuidVal != "" {
		dataMap["UUID"] = uuidVal
	} else {
		dataMap["UUID"] = uuid.New().String()
	}
	// Verdict and DropReason
	dataMap["Verdict"] = extractString(flow, "verdict")
	dataMap["DropReason"] = extractString(flow, "drop_reason_desc")
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
		dataMap["SourceIdentity"] = safeToInt(source["identity"])
		dataMap["SourceClusterName"] = extractString(source, "cluster_name")
		dataMap["SourceNamespace"] = extractString(source, "namespace")
		dataMap["SourcePodName"] = extractString(source, "pod_name")
		if workloads, ok := source["workloads"].([]interface{}); ok {
			dataMap["SourceWorkloads"] = serializeToJSON(workloads)
		}
	}
	// Destination details
	if dest, ok := flow["destination"].(map[string]interface{}); ok {
		dataMap["DestinationIdentity"] = safeToInt(dest["identity"])
		dataMap["DestinationClusterName"] = extractString(dest, "cluster_name")
		dataMap["DestinationNamespace"] = extractString(dest, "namespace")
		dataMap["DestinationPodName"] = extractString(dest, "pod_name")
		if workloads, ok := dest["workloads"].([]interface{}); ok {
			dataMap["DestinationWorkloads"] = serializeToJSON(workloads)
		}
	}
	// FlowType
	dataMap["FlowType"] = extractString(flow, "Type")
	// NodeName
	dataMap["NodeName"] = extractString(flow, "node_name")
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
	serviceData := map[string]interface{}{
		"SourceService":               extractString(flow, "source_service.name"),
		"SourceServiceNamespace":      extractString(flow, "source_service.namespace"),
		"DestinationService":          extractString(flow, "destination_service.name"),
		"DestinationServiceNamespace": extractString(flow, "destination_service.namespace"),
	}
	dataMap["Service"] = serializeToJSON(serviceData)
	// TrafficDirection and TraceObservationPoint
	dataMap["TrafficDirection"] = extractString(flow, "traffic_direction")
	dataMap["TraceObservationPoint"] = extractString(flow, "trace_observation_point")

	// aggregation support needed
	// // FlowState
	// dataMap["FlowState"] = extractString(flow, "flow_state")
	// Packets and Bytes
	if packetsSent, ok := flow["packets_sent"]; ok {
		dataMap["PacketsSent"] = safeToInt(packetsSent)
	}
	if packetsReceived, ok := flow["packets_received"]; ok {
		dataMap["PacketsReceived"] = safeToInt(packetsReceived)
	}
	// dataMap["BytesSent"] = safeToInt(flow["bytes_sent"])
	// dataMap["BytesReceived"] = safeToInt(flow["bytes_received"])

	// Policies (combined from multiple fields)
	policiesData := map[string]interface{}{
		"egress_allowed_by":  flow["egress_allowed_by"],
		"ingress_allowed_by": flow["ingress_allowed_by"],
		"egress_denied_by":   flow["egress_denied_by"],
		"ingress_denied_by":  flow["ingress_denied_by"],
	}
	dataMap["Policies"] = serializeToJSON(policiesData)
	// AdditionalFlowData
	additionalData := map[string]interface{}{
		"EthernetSource":      extractString(flow, "ethernet.source"),
		"EthernetDestination": extractString(flow, "ethernet.destination"),
		"SourceLabels":        extractLabels(flow["source"]),
		"DestinationLabels":   extractLabels(flow["destination"]),
		"Summary":             flow["Summary"],
		"Extensions":          flow["extensions"],
	}
	dataMap["AdditionalFlowData"] = serializeToJSON(additionalData)
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
