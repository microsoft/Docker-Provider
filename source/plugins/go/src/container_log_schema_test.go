package main

import (
	"encoding/json"
	"io"
	"net/http"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/fluent/fluent-bit-go/output"
)

func TestContainerLogSchemaLocalConfig(t *testing.T) {
	originalMode := containerLogSchemaMode.Load()
	t.Cleanup(func() {
		containerLogSchemaMode.Store(originalMode)
	})
	for _, tt := range []struct {
		name     string
		configV2 bool
		msi      bool
		geneva   bool
		adx      bool
		wantV2   bool
		wantDCR  bool
	}{
		{name: "legacy v1"},
		{name: "legacy v2", configV2: true, wantV2: true},
		{name: "MSI ConfigMap override", configV2: true, msi: true, wantV2: true},
		{name: "MSI DCR schema", msi: true, wantDCR: true},
		{name: "Geneva v1", msi: true, geneva: true},
		{name: "Geneva v2", configV2: true, msi: true, geneva: true, wantV2: true},
		{name: "ADX ignores v2 ConfigMap", configV2: true, adx: true},
	} {
		t.Run(tt.name, func(t *testing.T) {
			initializeContainerLogSchemaMode(tt.configV2, tt.msi, tt.geneva, tt.adx)
			if got := isContainerLogSchemaDCRControlled(); got != tt.wantDCR {
				t.Fatalf("DCR controlled = %v, want %v", got, tt.wantDCR)
			}
			if tt.wantDCR {
				return
			}
			for _, useFromCache := range []bool{false, true} {
				got, err := getContainerLogSchemaV2(useFromCache)
				if err != nil || got != tt.wantV2 {
					t.Fatalf("schema got (%v, %v), want (%v, nil)", got, err, tt.wantV2)
				}
			}
			got, resolved := getContainerLogSchemaV2ForTelemetry()
			if !resolved || got != tt.wantV2 {
				t.Fatalf("telemetry schema got (%v, %v), want (%v, true)", got, resolved, tt.wantV2)
			}
		})
	}
}

func TestContainerLogSchemaUninitialized(t *testing.T) {
	originalMode := containerLogSchemaMode.Load()
	t.Cleanup(func() { containerLogSchemaMode.Store(originalMode) })
	containerLogSchemaMode.Store(containerLogSchemaModeUnknown)
	if _, err := getContainerLogSchemaV2(true); err == nil {
		t.Fatal("expected unresolved schema before policy initialization")
	}
	if v2, resolved := getContainerLogSchemaV2ForTelemetry(); v2 || resolved {
		t.Fatalf("uninitialized telemetry got (%v, %v), want unresolved", v2, resolved)
	}
}

func TestContainerLogSchemaConcurrentInitialization(t *testing.T) {
	originalMode := containerLogSchemaMode.Load()
	originalMSI := IsAADMSIAuthMode
	t.Cleanup(func() {
		containerLogSchemaMode.Store(originalMode)
		IsAADMSIAuthMode = originalMSI
	})
	IsAADMSIAuthMode = true
	initializeContainerLogSchemaMode(false, true, false, false)
	wantV2, wantResolved := getContainerLogSchemaV2ForTelemetry()
	var workers sync.WaitGroup
	workers.Add(1)
	go func() {
		defer workers.Done()
		for i := 0; i < 100; i++ {
			IsAADMSIAuthMode = false
			IsAADMSIAuthMode = true
			initializeContainerLogSchemaMode(false, true, false, false)
		}
	}()
	for i := 0; i < 4; i++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for j := 0; j < 100; j++ {
				if !isContainerLogSchemaDCRControlled() {
					t.Error("plugin initialization exposed a transient non-DCR schema policy")
					return
				}
				v2, resolved := getContainerLogSchemaV2ForTelemetry()
				if v2 != wantV2 || resolved != wantResolved {
					t.Errorf("telemetry got (%v, %v), want (%v, %v)", v2, resolved, wantV2, wantResolved)
					return
				}
			}
		}()
	}
	workers.Wait()
}

func TestContainerLogSchemaTelemetryDimension(t *testing.T) {
	for _, tt := range []struct {
		name     string
		v2       bool
		resolved bool
		want     string
	}{
		{name: "startup unknown"},
		{name: "failed lookup unknown", v2: true},
		{name: "resolved v1", resolved: true, want: "false"},
		{name: "resolved v2", v2: true, resolved: true, want: "true"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			dimensions := map[string]string{"other": "preserved", "containerLogVer": "stale"}
			addContainerLogSchemaTelemetryDimension(dimensions, tt.v2, tt.resolved)
			want := map[string]string{"other": "preserved"}
			if tt.want != "" {
				want["containerLogVer"] = tt.want
			}
			if !reflect.DeepEqual(dimensions, want) {
				t.Fatalf("got %v, want %v", dimensions, want)
			}
		})
	}
}

type schemaRoundTripFunc func(*http.Request) (*http.Response, error)

func (f schemaRoundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return f(request)
}

func TestPostDataHelperSchemaBatch(t *testing.T) {
	originalMode := containerLogSchemaMode.Load()
	originalMSI := IsAADMSIAuthMode
	originalGeneva := IsGenevaLogsIntegrationEnabled
	originalADX := ContainerLogsRouteADX
	originalRouteV2 := ContainerLogsRouteV2
	originalMetadata := KubernetesMetadataEnabled
	originalIgnore := StdoutIgnoreNsSet
	originalClient := HTTPClient
	originalEndpoint := OMSEndpoint
	originalCount, originalSize, originalTime := FlushedRecordsCount, FlushedRecordsSize, FlushedRecordsTimeTaken
	originalLatency, originalLatencyContainer := AgentLogProcessingMaxLatencyMs, AgentLogProcessingMaxLatencyMsContainer
	t.Cleanup(func() {
		containerLogSchemaMode.Store(originalMode)
		IsAADMSIAuthMode = originalMSI
		IsGenevaLogsIntegrationEnabled = originalGeneva
		ContainerLogsRouteADX = originalADX
		ContainerLogsRouteV2 = originalRouteV2
		KubernetesMetadataEnabled = originalMetadata
		StdoutIgnoreNsSet = originalIgnore
		HTTPClient = originalClient
		OMSEndpoint = originalEndpoint
		FlushedRecordsCount, FlushedRecordsSize, FlushedRecordsTimeTaken = originalCount, originalSize, originalTime
		AgentLogProcessingMaxLatencyMs, AgentLogProcessingMaxLatencyMsContainer = originalLatency, originalLatencyContainer
	})
	IsAADMSIAuthMode = false
	IsGenevaLogsIntegrationEnabled = false
	ContainerLogsRouteADX = false
	ContainerLogsRouteV2 = false
	KubernetesMetadataEnabled = false
	StdoutIgnoreNsSet = nil
	OMSEndpoint = "https://workspace.invalid/OperationalData.svc/PostJsonDataItems"
	for _, schemaV2 := range []bool{false, true} {
		name := "v1"
		if schemaV2 {
			name = "v2"
		}
		t.Run(name, func(t *testing.T) {
			initializeContainerLogSchemaMode(schemaV2, false, false, false)
			requests := 0
			HTTPClient = http.Client{Transport: schemaRoundTripFunc(func(request *http.Request) (*http.Response, error) {
				defer request.Body.Close()
				requests++
				var payload struct {
					DataType  string
					DataItems []map[string]interface{}
				}
				if err := json.NewDecoder(request.Body).Decode(&payload); err != nil {
					t.Fatal(err)
				}
				wantType := ContainerLogDataType
				wantField := "LogEntry"
				otherField := "LogMessage"
				if schemaV2 {
					wantType = ContainerLogV2DataType
					wantField, otherField = otherField, wantField
				}
				if payload.DataType != wantType || len(payload.DataItems) != 2 {
					t.Fatalf("got type %q and %d records, want %q and 2 records", payload.DataType, len(payload.DataItems), wantType)
				}
				for _, record := range payload.DataItems {
					if record[wantField] != "message" {
						t.Errorf("missing %s in record %v", wantField, record)
					}
					if _, found := record[otherField]; found {
						t.Errorf("mixed schema field %s in record %v", otherField, record)
					}
				}
				return &http.Response{StatusCode: http.StatusOK, Body: io.NopCloser(strings.NewReader("")), Header: make(http.Header)}, nil
			})}
			record := map[interface{}]interface{}{
				"filepath": []byte("/var/log/containers/pod_default_app-" + strings.Repeat("a", 64) + ".log"),
				"stream":   []byte("stdout"),
				"log":      []byte("message"),
				"time":     []byte(time.Now().UTC().Format(time.RFC3339)),
			}
			if got := PostDataHelper([]map[interface{}]interface{}{record, record}); got != output.FLB_OK {
				t.Fatalf("flush returned %d, want %d", got, output.FLB_OK)
			}
			if requests != 1 {
				t.Fatalf("got %d requests, want 1", requests)
			}
		})
	}
}
