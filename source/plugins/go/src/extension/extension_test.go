//go:build linux

package extension

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"reflect"
	"sync"
	"testing"
	"time"
)

type FluentSocketWriterMock struct {
	FluentSocketWriterImpl
	response []byte
	err      error
	requests int
	started  chan struct{}
	release  chan struct{}
}

func (w *FluentSocketWriterMock) writeAndRead(_ *FluentSocket, _ []byte) ([]byte, error) {
	w.requests++
	if w.started != nil {
		close(w.started)
		<-w.release
	}
	return w.response, w.err
}

func (*FluentSocketWriterMock) disconnect(_ *FluentSocket) error {
	return nil
}

func schemaConfig(settings map[string]interface{}) TaggedData {
	return TaggedData{
		ExtensionName: ContainerInsightsExtension,
		ExtensionConfigs: []ExtensionConfig{{
			ExtensionSettings: map[string]map[string]interface{}{
				EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS: settings,
			},
		}},
	}
}

func extensionResponse(t *testing.T, config TaggedData) []byte {
	t.Helper()
	taggedData, err := json.Marshal(config)
	if err != nil {
		t.Fatal(err)
	}
	response, err := json.Marshal(AgentTaggedDataResponse{
		Success:    true,
		TaggedData: string(taggedData),
	})
	if err != nil {
		t.Fatal(err)
	}
	return response
}

func setupExtensionTest(t *testing.T, config TaggedData) (*Extension, *FluentSocketWriterMock) {
	t.Helper()
	GetInstance(log.New(io.Discard, "", 0), "ContainerType")
	writer := &FluentSocketWriterMock{response: extensionResponse(t, config)}
	previousWriter := FluentSocketWriter
	FluentSocketWriter = writer
	t.Cleanup(func() { FluentSocketWriter = previousWriter })
	return &Extension{}, writer
}

func Test_getDataTypeToStreamIdMappingFromCIExtension(t *testing.T) {
	config := schemaConfig(nil)
	config.ExtensionConfigs[0].OutputStreams = map[string]interface{}{"CONTAINER_LOG_BLOB": "stream"}
	config.OutputStreamDefinitions = map[string]StreamDefinition{"stream": {NamedPipe: "pipe"}}
	for _, tt := range []struct {
		name         string
		hasNamedPipe bool
		want         string
	}{
		{name: "stream ID", want: "stream"},
		{name: "named pipe", hasNamedPipe: true, want: "pipe"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			_, writer := setupExtensionTest(t, config)
			got, err := getDataTypeToStreamIdMappingFromCIExtension(tt.hasNamedPipe)
			if err != nil {
				t.Fatal(err)
			}
			want := map[string]string{"CONTAINER_LOG_BLOB": tt.want}
			if !reflect.DeepEqual(got, want) {
				t.Fatalf("got %v, want %v", got, want)
			}
			if writer.requests != 1 {
				t.Fatalf("got %d requests, want 1", writer.requests)
			}
		})
	}
}

func TestIsContainerLogV2(t *testing.T) {
	for _, tt := range []struct {
		name         string
		config       TaggedData
		cached       map[string]string
		useFromCache bool
		response     []byte
		requestErr   error
		want         bool
		wantErr      bool
		wantRequests int
	}{
		{name: "v2", config: schemaConfig(map[string]interface{}{"enableContainerLogV2": true}), want: true, wantRequests: 1},
		{name: "v1", config: schemaConfig(map[string]interface{}{"enableContainerLogV2": false}), wantRequests: 1},
		{name: "case insensitive", config: schemaConfig(map[string]interface{}{"EnableContainerLogV2": "TRUE"}), want: true, wantRequests: 1},
		{name: "cached v2", cached: map[string]string{"enablecontainerlogv2": "true"}, useFromCache: true, want: true},
		{name: "cached v1", cached: map[string]string{"enablecontainerlogv2": "false"}, useFromCache: true},
		{name: "uncached startup", config: schemaConfig(map[string]interface{}{"enableContainerLogV2": true}), useFromCache: true, want: true, wantRequests: 1},
		{name: "configured default v1", config: schemaConfig(nil), wantRequests: 1},
		{name: "removed setting replaces cached v2", config: schemaConfig(map[string]interface{}{"interval": "1m"}), cached: map[string]string{"enablecontainerlogv2": "true"}, wantRequests: 1},
		{name: "explicit v1 replaces cached v2", config: schemaConfig(map[string]interface{}{"enableContainerLogV2": false}), cached: map[string]string{"enablecontainerlogv2": "true"}, wantRequests: 1},
		{name: "unavailable configuration", wantErr: true, wantRequests: 1},
		{name: "unavailable configuration clears cached v2", cached: map[string]string{"enablecontainerlogv2": "true"}, wantErr: true, wantRequests: 1},
		{name: "transport failure", requestErr: errors.New("config request failed"), wantErr: true, wantRequests: 1},
		{name: "malformed response", response: []byte("{"), wantErr: true, wantRequests: 1},
		{name: "malformed tagged data", response: []byte(`{"Success":true,"TaggedData":"{"}`), wantErr: true, wantRequests: 1},
		{name: "invalid schema", config: schemaConfig(map[string]interface{}{"enableContainerLogV2": "invalid"}), cached: map[string]string{"enablecontainerlogv2": "true"}, wantErr: true, wantRequests: 1},
	} {
		t.Run(tt.name, func(t *testing.T) {
			instance, writer := setupExtensionTest(t, tt.config)
			instance.dataCollectionSettings = tt.cached
			writer.err = tt.requestErr
			if tt.response != nil {
				writer.response = tt.response
			}
			got, err := instance.IsContainerLogV2(tt.useFromCache)
			if got != tt.want || (err != nil) != tt.wantErr {
				t.Fatalf("got (%v, %v), want (%v, error=%v)", got, err, tt.want, tt.wantErr)
			}
			cachedV2, resolved := instance.GetCachedContainerLogV2()
			if resolved != !tt.wantErr || cachedV2 != tt.want {
				t.Fatalf("cached schema (%v, %v), want (%v, %v)", cachedV2, resolved, tt.want, !tt.wantErr)
			}
			if tt.wantErr {
				if len(instance.dataCollectionSettings) != 0 {
					t.Fatal("failed configuration lookup retained a stale schema")
				}
			} else {
				cached, cachedErr := instance.IsContainerLogV2(true)
				if cachedErr != nil || cached != tt.want {
					t.Fatalf("cached lookup got (%v, %v), want (%v, nil)", cached, cachedErr, tt.want)
				}
			}
			if writer.requests != tt.wantRequests {
				t.Fatalf("got %d requests, want %d", writer.requests, tt.wantRequests)
			}
		})
	}
}

func TestContainerLogSchemaRecovery(t *testing.T) {
	instance, writer := setupExtensionTest(t, schemaConfig(map[string]interface{}{"enableContainerLogV2": true}))
	if v2, resolved := instance.GetCachedContainerLogV2(); v2 || resolved {
		t.Fatalf("startup schema got (%v, %v), want unresolved", v2, resolved)
	}
	if _, err := instance.IsContainerLogV2(false); err != nil {
		t.Fatal(err)
	}
	writer.err = errors.New("temporary config read failure")
	if _, err := instance.IsContainerLogV2(false); err == nil {
		t.Fatal("expected config read error")
	}
	if v2, resolved := instance.GetCachedContainerLogV2(); v2 || resolved {
		t.Fatalf("failed schema got (%v, %v), want unresolved", v2, resolved)
	}
	writer.err = nil
	writer.response = extensionResponse(t, schemaConfig(map[string]interface{}{"enableContainerLogV2": false}))
	if v2, err := instance.IsContainerLogV2(true); v2 || err != nil {
		t.Fatalf("recovered schema got (%v, %v), want (false, nil)", v2, err)
	}
	if v2, resolved := instance.GetCachedContainerLogV2(); v2 || !resolved {
		t.Fatalf("recovered snapshot got (%v, %v), want (false, true)", v2, resolved)
	}
	if writer.requests != 3 {
		t.Fatalf("got %d requests, want 3", writer.requests)
	}
}

func TestContainerLogSchemaSnapshotDoesNotBlock(t *testing.T) {
	instance, writer := setupExtensionTest(t, schemaConfig(map[string]interface{}{"enableContainerLogV2": true}))
	writer.started = make(chan struct{})
	writer.release = make(chan struct{})
	release := sync.OnceFunc(func() { close(writer.release) })
	defer release()
	lookup := make(chan error, 1)
	go func() {
		_, err := instance.IsContainerLogV2(false)
		lookup <- err
	}()
	<-writer.started
	snapshot := make(chan [2]bool, 1)
	go func() {
		v2, resolved := instance.GetCachedContainerLogV2()
		snapshot <- [2]bool{v2, resolved}
	}()
	select {
	case got := <-snapshot:
		if got != [2]bool{false, false} {
			t.Errorf("snapshot got %v, want unresolved", got)
		}
	case <-time.After(time.Second):
		t.Error("schema snapshot blocked behind an AMA config request")
	}
	release()
	if err := <-lookup; err != nil {
		t.Fatal(err)
	}
}

func TestContainerLogSchemaConcurrentAccess(t *testing.T) {
	instance, _ := setupExtensionTest(t, schemaConfig(map[string]interface{}{"enableContainerLogV2": true}))
	var workers sync.WaitGroup
	for i := 0; i < 8; i++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for j := 0; j < 50; j++ {
				GetInstance(log.New(io.Discard, "", 0), "ContainerType")
				v2, err := instance.IsContainerLogV2(j%2 == 0)
				if err != nil || !v2 {
					t.Errorf("concurrent lookup got (%v, %v), want (true, nil)", v2, err)
					return
				}
				if v2, resolved := instance.GetCachedContainerLogV2(); !v2 || !resolved {
					t.Errorf("concurrent snapshot got (%v, %v), want (true, true)", v2, resolved)
					return
				}
			}
		}()
	}
	workers.Wait()
}
