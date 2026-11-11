package utils

import (
	"strings"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/monitor/azquery"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestContainerInventoryImageTags(t *testing.T) {
	digest := "sha256:" + strings.Repeat("a", 64)
	tests := []struct {
		name        string
		image       string
		tag         any
		init        bool
		inventoryID string
		wantError   string
	}{
		{name: "digest-only image", image: "registry.example/app@" + digest, tag: ""},
		{name: "digest-only init container", image: "registry.example/init@" + digest, tag: nil, init: true},
		{name: "explicit tag", image: "registry.example/app:1.2", tag: "1.2"},
		{name: "tag and digest", image: "registry.example/app:1.2@" + digest, tag: "1.2"},
		{name: "missing tag despite digest", image: "registry.example/app:1.2@" + digest, tag: "", wantError: `expected ImageTag "1.2"`},
		{name: "incorrect explicit tag", image: "registry.example/app:1.2", tag: "latest", wantError: `expected ImageTag "1.2"`},
		{name: "implicit latest with registry port", image: "registry.example:5000/app", tag: "latest"},
		{name: "missing implicit latest", image: "registry.example:5000/app", tag: "", wantError: `expected ImageTag "latest"`},
		{name: "digest with registry port", image: "registry.example:5000/app@" + digest, tag: ""},
		{name: "unknown empty tag is not exempt", image: "registry.example/app@" + digest, tag: "", inventoryID: "previous-container", wantError: "no matching Kubernetes image reference"},
		{name: "old tagged record retains nonempty check", image: "registry.example/app:1.2", tag: "1.1", inventoryID: "previous-container"},
		{name: "invalid original image", image: "registry.example/app@not-a-digest", tag: "", wantError: "invalid image reference"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pod := corev1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "app-pod", Namespace: "default"}}
			containers := []corev1.Container{{Name: "app", Image: tt.image}}
			statuses := []corev1.ContainerStatus{{Name: "app", ContainerID: "containerd://container-id"}}
			if tt.init {
				pod.Spec.InitContainers = containers
				pod.Status.InitContainerStatuses = statuses
			} else {
				pod.Spec.Containers = containers
				pod.Status.ContainerStatuses = statuses
			}
			id := tt.inventoryID
			if id == "" {
				id = "container-id"
			}
			tables := []*azquery.Table{{Rows: []azquery.Row{{id, pod.Name, tt.tag}}}}
			err := validateContainerInventoryImageTags([]corev1.Pod{pod}, tables)
			if tt.wantError == "" {
				if err != nil {
					t.Fatal(err)
				}
			} else if err == nil || !strings.Contains(err.Error(), tt.wantError) {
				t.Fatalf("expected error containing %q, got %v", tt.wantError, err)
			}
		})
	}
}

func TestContainerInventoryImageTagsRejectMissingData(t *testing.T) {
	pod := corev1.Pod{
		Spec:   corev1.PodSpec{Containers: []corev1.Container{{Name: "app", Image: "app:1.2"}}},
		Status: corev1.PodStatus{ContainerStatuses: []corev1.ContainerStatus{{Name: "app", ContainerID: "containerd://id"}}},
	}
	for _, tables := range [][]*azquery.Table{
		nil,
		{{Rows: nil}},
		{{Rows: []azquery.Row{{"id", "pod"}}}},
		{{Rows: []azquery.Row{{"id", "pod", 123}}}},
	} {
		if err := validateContainerInventoryImageTags([]corev1.Pod{pod}, tables); err == nil {
			t.Fatalf("expected malformed or absent inventory data to fail: %v", tables)
		}
	}
}

func TestAgentTelemetryQueryWindows(t *testing.T) {
	now := time.Date(2026, 11, 11, 9, 42, 47, 0, time.UTC)
	start := "2026-11-11T00:58:00-08:00"
	resourceID := "/subscriptions/test/resourceGroups/test/providers/Microsoft.ContainerService/managedClusters/test"
	for _, source := range []string{"traces", "customMetrics", "heartbeat"} {
		t.Run(source, func(t *testing.T) {
			query, err := BuildAgentTelemetryQuery(source, resourceID, "3.10.0-test", start, now)
			if err != nil {
				t.Fatal(err)
			}
			if source == "traces" {
				// A trace at 08:59 must still be covered when the suite runs at 09:42.
				if !strings.Contains(query, "timestamp between (datetime(2026-11-11T08:58:00Z) .. datetime(2026-11-11T09:42:47Z))") || strings.Contains(query, "ago(30m)") {
					t.Fatalf("startup window must remain anchored to deployment:\n%s", query)
				}
			} else if !strings.Contains(query, "timestamp > ago(30m)") {
				t.Fatalf("periodic health signals must retain the recent window:\n%s", query)
			}
			for _, filter := range []string{
				`ClusterId =~ "` + resourceID + `"`,
				`in ("3.10.0-test", "win-3.10.0-test")`,
				`Computer = tolower(tostring(customDimensions.Computer))`,
			} {
				if !strings.Contains(query, filter) {
					t.Fatalf("query lost coverage filter %q:\n%s", filter, query)
				}
			}
			if source == "heartbeat" && !strings.Contains(query, `name == "ContainerLogDaemonSetHeartbeatEvent"`) {
				t.Fatalf("heartbeat query must select the DaemonSet heartbeat:\n%s", query)
			}
		})
	}
}

func TestAgentTelemetryQueryRejectsInvalidConfiguration(t *testing.T) {
	now := time.Date(2026, 11, 11, 9, 42, 47, 0, time.UTC)
	for _, start := range []string{"", "$(agentDeploymentStartTime)", "2026-11-11", "2026-11-11T10:00:00Z", "0001-01-01T00:00:00Z"} {
		if _, err := BuildAgentTelemetryQuery("traces", "cluster", "version", start, now); err == nil {
			t.Errorf("expected invalid deployment timestamp %q to fail", start)
		}
	}
	for _, input := range []struct{ source, resourceID, version string }{
		{"traces", "", "version"},
		{"traces", "cluster", ""},
		{"unsupported", "cluster", "version"},
	} {
		if _, err := BuildAgentTelemetryQuery(input.source, input.resourceID, input.version, "2026-11-11T08:58:00Z", now); err == nil {
			t.Errorf("expected invalid telemetry configuration to fail: %+v", input)
		}
	}
}
