package main

import (
	"bytes"
	"encoding/json"
	"net"
	"testing"
	"time"

	"github.com/fluent/fluent-bit-go/output"
	"github.com/stretchr/testify/assert"
)

// MockConn implements net.Conn for testing
type MockConn struct {
	bytes.Buffer
}

func (m *MockConn) Read(b []byte) (n int, err error)   { return 0, nil }
func (m *MockConn) Write(b []byte) (n int, err error)  { return len(b), nil }
func (m *MockConn) Close() error                       { return nil }
func (m *MockConn) LocalAddr() net.Addr                { return nil }
func (m *MockConn) RemoteAddr() net.Addr               { return nil }
func (m *MockConn) SetDeadline(t time.Time) error      { return nil }
func (m *MockConn) SetReadDeadline(t time.Time) error  { return nil }
func (m *MockConn) SetWriteDeadline(t time.Time) error { return nil }

func TestPostNetworkFlowRecords(t *testing.T) {
	assert.Equal(t, output.FLB_OK, PostNetworkFlowRecords(nil), "Expected FLB_OK when input is nil or empty")

	MdsdNetworkFlowClient = &MockConn{}
	MdsdNetworkFlowLogsStreamTagName = "test-tag"

	rawJSONs := []string{
		`{"flow":{"time":"2025-04-16T18:49:59.450463857Z","uuid":"60e8fedd-6d98-49d8-b7f6-cb84455757ab","verdict":"FORWARDED","ethernet":{"source":"ce:38:1f:4b:21:dd","destination":"fa:ce:3c:de:8b:f8"},"IP":{"source":"10.0.1.13","destination":"10.0.1.178","ipVersion":"IPv4"},"l4":{"TCP":{"source_port":8080,"destination_port":60778,"flags":{"PSH":true,"ACK":true}}},"source":{"ID":1501,"identity":39459,"cluster_name":"longtestnetworkflowcni","namespace":"default","labels":["k8s:app=kapinger","k8s:server=good"],"pod_name":"kapinger-good-64cbf459c4-q4tr9","workloads":[{"name":"kapinger-good","kind":"Deployment"}]},"destination":{"ID":2273,"identity":17221,"cluster_name":"longtestnetworkflowcni","namespace":"default","labels":["k8s:app=kapinger","k8s:server=bad"],"pod_name":"kapinger-bad-6b5b787dc9-ds4j4","workloads":[{"name":"kapinger-bad","kind":"Deployment"}]},"Type":"L3_L4","node_name":"longtestnetworkflowcni/aks-nodepool1-27013129-vmss000000","reply":true,"event_type":{"type":4},"traffic_direction":"EGRESS","trace_observation_point":"TO_ENDPOINT","trace_reason":"REPLY","is_reply":true,"interface":{"index":98,"name":"lxc8308dc5301b3"},"Summary":"TCP Flags: ACK, PSH"}}`,
		`{"flow":{"time":"2025-04-16T18:49:59.450508431Z","uuid":"047846e8-5d33-4999-8a35-c01977527c0d","verdict":"FORWARDED","ethernet":{"source":"ce:38:1f:4b:21:dd","destination":"fa:ce:3c:de:8b:f8"},"IP":{"source":"10.0.1.13","destination":"10.0.1.178","ipVersion":"IPv4"},"l4":{"TCP":{"source_port":8080,"destination_port":60778,"flags":{"FIN":true,"ACK":true}}},"source":{"ID":1501,"identity":39459,"cluster_name":"longtestnetworkflowcni","namespace":"default","labels":["k8s:app=kapinger","k8s:server=good"],"pod_name":"kapinger-good-64cbf459c4-q4tr9","workloads":[{"name":"kapinger-good","kind":"Deployment"}]},"destination":{"ID":2273,"identity":17221,"cluster_name":"longtestnetworkflowcni","namespace":"default","labels":["k8s:app=kapinger","k8s:server=bad"],"pod_name":"kapinger-bad-6b5b787dc9-ds4j4","workloads":[{"name":"kapinger-bad","kind":"Deployment"}]},"Type":"L3_L4","node_name":"longtestnetworkflowcni/aks-nodepool1-27013129-vmss000000","reply":true,"event_type":{"type":4},"traffic_direction":"EGRESS","trace_observation_point":"TO_ENDPOINT","trace_reason":"REPLY","is_reply":true,"interface":{"index":98,"name":"lxc8308dc5301b3"},"Summary":"TCP Flags: ACK, FIN"}}`,
		`{"flow":{"time":"2025-04-16T18:49:59.450549905Z","uuid":"48895ac7-fe26-468c-806c-4bd52edcf74a","verdict":"FORWARDED","ethernet":{"source":"0a:24:da:3e:e2:b1","destination":"4a:13:29:8f:0f:37"},"IP":{"source":"10.0.1.178","destination":"10.0.1.13","ipVersion":"IPv4"},"l4":{"TCP":{"source_port":60778,"destination_port":8080,"flags":{"FIN":true,"ACK":true}}},"source":{"ID":2273,"identity":17221,"cluster_name":"longtestnetworkflowcni","namespace":"default","labels":["k8s:app=kapinger","k8s:server=bad"],"pod_name":"kapinger-bad-6b5b787dc9-ds4j4","workloads":[{"name":"kapinger-bad","kind":"Deployment"}]},"destination":{"ID":1501,"identity":39459,"cluster_name":"longtestnetworkflowcni","namespace":"default","labels":["k8s:app=kapinger","k8s:server=good"],"pod_name":"kapinger-good-64cbf459c4-q4tr9","workloads":[{"name":"kapinger-good","kind":"Deployment"}]},"Type":"L3_L4","node_name":"longtestnetworkflowcni/aks-nodepool1-27013129-vmss000000","event_type":{"type":4},"traffic_direction":"EGRESS","trace_observation_point":"TO_ENDPOINT","trace_reason":"ESTABLISHED","is_reply":false,"interface":{"index":94,"name":"lxcef45ee129456"},"Summary":"TCP Flags: ACK, FIN"}}`,
	}

	var records []map[interface{}]interface{}
	for _, rawJSON := range rawJSONs {
		var record map[string]interface{}
		err := json.Unmarshal([]byte(rawJSON), &record)
		assert.NoError(t, err)

		records = append(records, map[interface{}]interface{}{
			"flow": record["flow"],
		})
	}

	result := PostNetworkFlowRecords(records)
	assert.Equal(t, output.FLB_OK, result, "Expected FLB_OK for multiple valid records")
}

func TestConvertFluentBitRecord(t *testing.T) {
	input := map[interface{}]interface{}{
		"flow": map[interface{}]interface{}{
			"time":    []byte("2025-04-16T18:49:59.450549905Z"),
			"uuid":    []byte("48895ac7-fe26-468c-806c-4bd52edcf74a"),
			"verdict": []byte("FORWARDED"),
		},
	}

	expected := map[string]interface{}{
		"flow": map[string]interface{}{
			"time":    "2025-04-16T18:49:59.450549905Z",
			"uuid":    "48895ac7-fe26-468c-806c-4bd52edcf74a",
			"verdict": "FORWARDED",
		},
	}

	result, err := convertFluentBitRecord(input)
	assert.NoError(t, err)
	assert.Equal(t, expected, result)
}

func TestMapNetworkFlowLogsToDataMap(t *testing.T) {
	rawRecord := map[string]interface{}{
		"flow": map[string]interface{}{
			"time":    "2025-04-16T18:49:59.450549905Z",
			"uuid":    "48895ac7-fe26-468c-806c-4bd52edcf74a",
			"verdict": "FORWARDED",
			"ethernet": map[string]interface{}{
				"source":      "0a:24:da:3e:e2:b1",
				"destination": "4a:13:29:8f:0f:37",
			},
			"IP": map[string]interface{}{
				"source":      "10.0.1.178",
				"destination": "10.0.1.13",
				"ipVersion":   "IPv4",
			},
			"l4": map[string]interface{}{
				"TCP": map[string]interface{}{
					"source_port":      60778,
					"destination_port": 8080,
					"flags": map[string]interface{}{
						"FIN": true,
						"ACK": true,
					},
				},
			},
			"source": map[string]interface{}{
				"identity":  17221,
				"pod_name":  "kapinger-bad-6b5b787dc9-ds4j4",
				"namespace": "default",
			},
			"destination": map[string]interface{}{
				"identity":  39459,
				"pod_name":  "kapinger-good-64cbf459c4-q4tr9",
				"namespace": "default",
			},
			"is_reply":                false,
			"Type":                    "L3_L4",
			"traffic_direction":       "EGRESS",
			"trace_observation_point": "TO_ENDPOINT",
			"Summary":                 "TCP Flags: ACK, FIN",
		},
	}

	dataMap := make(map[string]interface{})
	err := mapNetworkFlowLogsToDataMap(dataMap, rawRecord)
	assert.NoError(t, err)
	assert.Equal(t, "2025-04-16T18:49:59.450549905Z", dataMap["TimeGenerated"])
	assert.Equal(t, "48895ac7-fe26-468c-806c-4bd52edcf74a", dataMap["UUID"])
	assert.Equal(t, "kapinger-bad-6b5b787dc9-ds4j4", dataMap["SourcePodName"])
	assert.Equal(t, "kapinger-good-64cbf459c4-q4tr9", dataMap["DestinationPodName"])
	assert.Equal(t, "FORWARDED", dataMap["Verdict"])
	assert.Equal(t, "EGRESS", dataMap["TrafficDirection"])
}

func TestExtractString(t *testing.T) {
	m := map[string]interface{}{
		"time": "2025-04-16T18:49:59.450549905Z",
		"uuid": "48895ac7-fe26-468c-806c-4bd52edcf74a",
	}
	assert.Equal(t, "2025-04-16T18:49:59.450549905Z", extractString(m, "time"))
	assert.Equal(t, "", extractString(m, "nonexistent"))
}

func TestSerializeToJSON(t *testing.T) {
	input := map[string]interface{}{
		"source":      "10.0.1.178",
		"destination": "10.0.1.13",
		"ipVersion":   "IPv4",
	}
	expected := `{"destination":"10.0.1.13","ipVersion":"IPv4","source":"10.0.1.178"}`
	assert.JSONEq(t, expected, serializeToJSON(input))
}

func TestSafeToInt(t *testing.T) {
	assert.Equal(t, 17221, safeToInt(17221))
	assert.Equal(t, 39459, safeToInt("39459"))
	assert.Equal(t, 0, safeToInt("invalid"))
}

func TestExtractLabels(t *testing.T) {
	source := map[string]interface{}{
		"labels": []interface{}{"k8s:app=kapinger", "k8s:server=bad"},
	}
	expected := []string{"k8s:app=kapinger", "k8s:server=bad"}
	assert.Equal(t, expected, extractLabels(source))
}

func TestConvertNetworkFlowMsgPackEntriesToMsgpBytes(t *testing.T) {
	entry := NetworkFlowMsgPackEntry{
		Time: 1713293399,
		Record: map[string]interface{}{
			"TimeGenerated":         "2025-04-16T18:49:59.450549905Z",
			"UUID":                  "48895ac7-fe26-468c-806c-4bd52edcf74a",
			"Verdict":               "FORWARDED",
			"SourcePodName":         "kapinger-bad-6b5b787dc9-ds4j4",
			"DestinationPodName":    "kapinger-good-64cbf459c4-q4tr9",
			"FlowType":              "L3_L4",
			"TrafficDirection":      "EGRESS",
			"TraceObservationPoint": "TO_ENDPOINT",
			"Summary":               "TCP Flags: ACK, FIN",
		},
	}

	bytes := convertNetworkFlowMsgPackEntriesToMsgpBytes("test-tag", []NetworkFlowMsgPackEntry{entry})
	assert.NotEmpty(t, bytes)
}
