package lib

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func inventoryPodWithContainerIDs(statusField string, id interface{}) map[string]interface{} {
	return map[string]interface{}{
		"metadata": map[string]interface{}{"name": "pod", "namespace": "default", "creationTimestamp": "2026-01-01T00:00:00Z"},
		"spec": map[string]interface{}{
			"nodeName":       "node",
			"containers":     []interface{}{map[string]interface{}{"name": "good", "image": "repo/image:tag"}},
			"initContainers": []interface{}{map[string]interface{}{"name": "candidate", "image": "repo/image:tag"}},
		},
		"status": map[string]interface{}{
			statusField: []interface{}{
				map[string]interface{}{"name": "candidate", "containerID": id, "image": "repo/image:tag", "state": map[string]interface{}{"waiting": map[string]interface{}{}}},
				map[string]interface{}{"name": "good", "containerID": "containerd://good-id", "image": "repo/image:tag", "state": map[string]interface{}{"waiting": map[string]interface{}{}}},
			},
		},
	}
}

func TestCGroupMatcherRequiresCompleteContainerToken(t *testing.T) {
	id := strings.Repeat("0123456789abcdef", 4)
	matching := map[string][]string{
		id: {
			"12:memory:/kubepods/burstable/pod1234/" + id,
			"0::/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod12_34.slice/cri-containerd-" + id + ".scope",
			"0::/system.slice/docker-" + id + ".scope",
			"0::/../" + id,
		},
		"crio-" + id: {
			"0::/kubepods.slice/kubepods-pod12_34.slice/crio-" + id + ".scope",
		},
	}
	for containerID, lines := range matching {
		pattern := cgroupMatcher(containerID)
		if pattern == nil {
			t.Fatalf("Expected a matcher for %q", containerID)
		}
		for _, line := range lines {
			if !pattern.MatchString(line) {
				t.Errorf("Expected %q to match %q", containerID, line)
			}
		}
	}

	pattern := cgroupMatcher(id)
	for _, line := range []string{
		"0::/kubepods.slice/cri-containerd-" + id + "0.scope",
		"0::/kubepods.slice/cri-containerd-0" + id + ".scope",
		"0::/kubepods.slice/cri-containerd-" + id[:63] + ".scope",
		"0::/kubepods.slice/kubepods-burstable.slice",
		"0::/system.slice/containerd.service",
	} {
		if pattern.MatchString(line) {
			t.Errorf("Did not expect %q to match %q", id, line)
		}
	}
	if cgroupMatcher("crio-" + id).MatchString("0::/kubepods.slice/crio-conmon-" + id + ".scope") {
		t.Error("CRI-O matcher should not match conmon cgroup")
	}

	for _, containerID := range []string{
		"", "kubepods", "slice", "crio", "crio-", "good-id", id[:63], id + "0", "crio-" + id[:12],
		strings.Repeat("g", 64), strings.Repeat(".", 64), strings.Repeat("a", 63) + "*", "docker-" + id,
	} {
		if cgroupMatcher(containerID) != nil {
			t.Errorf("Expected no matcher for %q", containerID)
		}
		if env := obtainContainerEnvironmentVars(containerID); env != "" {
			t.Errorf("Expected no environment variables for %q, got %q", containerID, env)
		}
	}
}

func TestContainerInventoryRejectsInvalidIDs(t *testing.T) {
	for _, statusField := range []string{"containerStatuses", "initContainerStatuses"} {
		for _, collectEnv := range []string{"false", "true"} {
			t.Run(statusField+"/"+collectEnv, func(t *testing.T) {
				t.Setenv("TESTDIR", t.TempDir())
				t.Setenv("AZMON_CLUSTER_COLLECT_ENV_VAR", collectEnv)
				invalidIDs := []interface{}{
					"containerd://../../sentinel", "containerd:///tmp/sentinel", `containerd://..\sentinel`,
					"containerd:/../sentinel", "containerd://good//suffix", "containerd://", "://id",
					"no-delimiter", "containerd://id\n", "containerd://id\x00", "containerd://CON",
					42, false, map[string]interface{}{}, []interface{}{},
				}
				for _, id := range invalidIDs {
					pod := inventoryPodWithContainerIDs(statusField, id)
					ids, records := GetContainerInventoryHelper(map[string]interface{}{"items": []interface{}{pod}}, "", nil, "")
					if !reflect.DeepEqual(ids, []string{"good-id"}) || len(records) != 1 {
						t.Fatalf("Invalid ID %v affected neighboring records: %v, %v", id, ids, records)
					}
					files, err := os.ReadDir(os.Getenv("TESTDIR"))
					if err != nil || len(files) != 1 || files[0].Name() != "good-id" {
						t.Fatalf("Unexpected persisted state for %v: %v, %v", id, files, err)
					}
				}
			})
		}
	}
}

func TestContainerInventoryIDCompatibility(t *testing.T) {
	ids := []interface{}{
		nil, "", "docker://" + strings.Repeat("a", 64), "containerd://" + strings.Repeat("b", 64),
		"cri-o://" + strings.Repeat("c", 64), "containerd://a1b2-1234-5678-90ab", "other-runtime://runtime.id+v1_2-3",
	}
	for _, statusField := range []string{"containerStatuses", "initContainerStatuses"} {
		for _, isWindows := range []bool{false, true} {
			for _, id := range ids {
				t.Run(fmt.Sprintf("%s/windows=%t/%v", statusField, isWindows, id), func(t *testing.T) {
					t.Setenv("TESTDIR", t.TempDir())
					pod := inventoryPodWithContainerIDs(statusField, id)
					records := GetContainerInventoryRecords(pod, "", "false", isWindows)
					if len(records) != 2 {
						t.Fatalf("Compatible ID %v lost records: %v", id, records)
					}
					expectedID := ""
					if value, ok := id.(string); ok && value != "" {
						_, expectedID, _ = strings.Cut(value, "://")
					}
					if records[0]["InstanceID"] != expectedID || records[1]["InstanceID"] != "good-id" {
						t.Fatalf("Unexpected IDs: %v", records)
					}
					for _, record := range records {
						WriteContainerState(record)
					}
					if expectedID != "" {
						if _, err := os.Stat(filepath.Join(os.Getenv("TESTDIR"), expectedID)); err != nil {
							t.Fatalf("Valid container state was not persisted: %v", err)
						}
					}
				})
			}
		}
	}
}

func TestContainerInventoryStatesAndFiltering(t *testing.T) {
	states := map[string]map[string]interface{}{
		"Waiting": {"waiting": map[string]interface{}{}},
		"Running": {"running": map[string]interface{}{"startedAt": "2026-01-01T00:00:00Z"}},
		"Failed":  {"terminated": map[string]interface{}{"exitCode": float64(1), "startedAt": "2026-01-01T00:00:00Z", "finishedAt": "2026-01-01T00:01:00Z"}},
	}
	for expectedState, state := range states {
		for _, collectEnv := range []string{"false", "true"} {
			for _, isWindows := range []bool{false, true} {
				t.Run(fmt.Sprintf("%s/env=%s/windows=%t", expectedState, collectEnv, isWindows), func(t *testing.T) {
					t.Setenv("TESTDIR", t.TempDir())
					t.Setenv("AZMON_CLUSTER_COLLECT_ENV_VAR", collectEnv)
					pod := inventoryPodWithContainerIDs("containerStatuses", nil)
					for _, status := range pod["status"].(map[string]interface{})["containerStatuses"].([]interface{}) {
						status.(map[string]interface{})["state"] = state
					}
					records := GetContainerInventoryRecords(pod, "", collectEnv, isWindows)
					if len(records) != 2 {
						t.Fatalf("Waiting/terminated/missing-ID records lost: %v", records)
					}
					for _, record := range records {
						if record["State"] != expectedState {
							t.Fatalf("Container state changed: %v", record)
						}
						WriteContainerState(record)
					}
					podList := map[string]interface{}{"items": []interface{}{pod}}
					for _, mode := range []string{"include", "exclude"} {
						namespaces := []string{"other"}
						if mode == "exclude" {
							namespaces = []string{"default"}
						}
						ids, filtered := GetContainerInventoryHelper(podList, mode, namespaces, "")
						if len(ids) != 0 || len(filtered) != 0 {
							t.Fatalf("Namespace filtering changed: %v, %v", ids, filtered)
						}
					}
				})
			}
		}
	}
}

func Test_GetContainerInventoryHelper(t *testing.T) {
	inventoryDirectory = os.Getenv("TESTDIR")
	err := os.MkdirAll(inventoryDirectory, 0755)
	if err != nil {
		panic(err)
	}
	defer func() {
		err = os.RemoveAll(inventoryDirectory)
		inventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"
		if err != nil {
			panic(err)
		}
	}()
	podList := map[string]interface{}{}
	jsonData, err := ioutil.ReadFile("testdata/pods1.json")
	if err != nil {
		t.Fatalf("Failed to read pods1.json file: %v", err)
	}
	err = json.Unmarshal(jsonData, &podList)
	if err != nil {
		t.Fatalf("Failed to read pods1.json file: %v", err)
	}

	containerIds, containerInventory := GetContainerInventoryHelper(podList, "", nil, "")
	if containerIds == nil || containerInventory == nil {
		t.Fatalf("Failed to get dataItems")
	}

	jsonData, err = ioutil.ReadFile("testdata/pods2.json")
	if err != nil {
		t.Fatalf("Failed to read pods2.json file: %v", err)
	}
	err = json.Unmarshal(jsonData, &podList)
	if err != nil {
		t.Fatalf("Failed to read pods2.json file: %v", err)
	}
	containerIds, containerInventory = GetContainerInventoryHelper(podList, "", nil, "")
	if containerIds == nil || containerInventory == nil {
		t.Fatalf("Failed to get dataItems")
	}
}
