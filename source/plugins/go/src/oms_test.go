package main

import (
	"encoding/json"
	"testing"
	"fmt"
	"reflect"
	"github.com/stretchr/testify/assert"
)

var kubernetesJSON = `{
	"pod_name":"test-publisher-ds-bssg6",
	"namespace_name":"kube-system",
	"pod_id":"93bf47d2-5c1a-42bc-test-481939a93a66",
	"labels":{
		"app":"test",
		"controller-revision-hash":"f48799794",
		"dsName":"defender-publisher-ds",
		"kubernetes.azure.com/managedby":"aks",
		"pod-template-generation":"2"
	},
	"annotations":{
		"kubernetes.io/config.seen":"2023-10-02T08:21:49.954540360Z",
		"kubernetes.io/config.source":"api"
	},
	"host":"test-agentpool-test-test000001",
	"container_name":"test-publisher",
	"docker_id":"test1234567890123213213123213213213213",
	"container_hash":"publisher@sha256:test1234567890123213213123213213213213",
	"container_image":"test-publisher:1.0.67"
}`

func toInterfaceMap(m map[string]interface{}) map[interface{}]interface{} {
	result := make(map[interface{}]interface{})
	for k, v := range m {
		result[k] = v
	}
	return result
}

// Test PostDataHelper KuberneteMetadata
func TestPostDataHelperKuberneteMetadata(t *testing.T) {
	var intermediateMap map[string]interface{}
    // Unmarshal JSON data into a map
    err := json.Unmarshal([]byte(kubernetesJSON), &intermediateMap)
    if err != nil {
        fmt.Println("Error unmarshalling JSON:", err)
        return
    }
	kubernetesMetadata := toInterfaceMap(intermediateMap)

	record := map[interface{}]interface{}{
		"filepath": "/var/log/containers/pod_xyz.log",
		"stream": "stdout",
		"kubernetes": kubernetesMetadata,
	}
	
	KubernetesMetadataIncludeList = []string{
		"podlabels", "podannotations", "poduid", "image", "imageid", "imagerepo", "imagetag",
	}
	KubernetesMetadataEnabled = true

	output := PostDataHelper([]map[interface{}]interface{}{record})

	assert.Greater(t, output, 0, "Expected output to be greater than 0 indicating processing occurred")
}

// Test PostDataHelper with empty tailPluginRecords
func TestPostDataHelperEmpty(t *testing.T) {
	tailPluginRecords := []map[interface{}]interface{}{}
	expectedOutput := 1
	output := PostDataHelper(tailPluginRecords)
	if output != expectedOutput {
		t.Errorf("Expected output to be %d, but got %d", expectedOutput, output)
	}
}

// Test PostDataHelper with multiple tailPluginRecords
func TestPostDataHelperMultiple(t *testing.T) {
	tailPluginRecords := []map[interface{}]interface{}{
		{
			"filepath": "/var/log/containers/pod_xyz.log",
			"stream":   "stdout",
			"kubernetes": map[interface{}]interface{}{
				"pod_name":        "test-publisher-ds-bssg6",
				"namespace_name":  "kube-system",
				"pod_id":          "93bf47d2-5c1a-42bc-test-481939a93a66",
				"labels": map[interface{}]interface{}{
					"app":                          "test",
					"controller-revision-hash":     "f48799794",
					"dsName":                       "defender-publisher-ds",
					"kubernetes.azure.com/managedby": "aks",
					"pod-template-generation":       "2",
				},
				"annotations": map[interface{}]interface{}{
					"kubernetes.io/config.seen":   "2023-10-02T08:21:49.954540360Z",
					"kubernetes.io/config.source": "api",
				},
				"host":             "test-agentpool-test-test000001",
				"container_name":   "test-publisher",
				"docker_id":        "test1234567890123213213123213213213213",
				"container_hash":   "publisher@sha256:test1234567890123213213123213213213213",
				"container_image":  "test-publisher:1.0.67",
			},
		},
		{
			"filepath": "/var/log/containers/pod_abc.log",
			"stream":   "stderr",
			"kubernetes": map[interface{}]interface{}{
				"pod_name":        "test-consumer-ds-abcde",
				"namespace_name":  "default",
				"pod_id":          "a1b2c3d4e5f6",
				"labels": map[interface{}]interface{}{
					"app":                          "test",
					"controller-revision-hash":     "f48799794",
					"dsName":                       "defender-consumer-ds",
					"kubernetes.azure.com/managedby": "aks",
					"pod-template-generation":       "1",
				},
				"annotations": map[interface{}]interface{}{
					"kubernetes.io/config.seen":   "2023-10-02T08:21:49.954540360Z",
					"kubernetes.io/config.source": "api",
				},
				"host":             "test-agentpool-test-test000002",
				"container_name":   "test-consumer",
				"docker_id":        "abcde12345",
				"container_hash":   "consumer@sha256:abcde12345",
				"container_image":  "test-consumer:2.0.12",
			},
		},
	}
	expectedOutput := 2
	output := PostDataHelper(tailPluginRecords)
	if output != expectedOutput {
		t.Errorf("Expected output to be %d, but got %d", expectedOutput, output)
	}
}

func TestConvertKubernetesMetadata(t *testing.T) {
	kubernetesMetadataJson := map[interface{}]interface{}{
		"pod_name":       "test-pod",
		"namespace_name": "test-namespace",
		"labels": map[interface{}]interface{}{
			"app": "test-app",
		},
		"annotations": map[interface{}]interface{}{
			"annotation_key": "annotation_value",
		},
	}

	expectedResult := map[string]interface{}{
		"pod_name":       "test-pod",
		"namespace_name": "test-namespace",
		"labels": map[string]interface{}{
			"app": "test-app",
		},
		"annotations": map[string]interface{}{
			"annotation_key": "annotation_value",
		},
	}

	result, err := convertKubernetesMetadata(kubernetesMetadataJson)
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}

	if !reflect.DeepEqual(result, expectedResult) {
		t.Errorf("Expected result to be %v, but got %v", expectedResult, result)
	}
}

func TestProcessIncludes(t *testing.T) {
	kubernetesMetadataMap := map[string]interface{}{
		"pod_name":"test-publisher-ds-bssg6",
		"namespace_name":"kube-system",
		"pod_id":"93bf47d2-5c1a-42bc-test-481939a93a66",
		"labels": map[string]interface{}{
			"app":"test",
			"controller-revision-hash":"f48799794",
			"dsName":"defender-publisher-ds",
			"kubernetes.azure.com/managedby":"aks",
			"pod-template-generation":"2",
		},
		"annotations": map[string]interface{}{
			"test":"2023-10-02T08:21:49.954540360Z",
		},
		"host":"test-agentpool-test-test000001",
		"container_name":"test-publisher",
		"docker_id":"test1234567890123213213123213213213213",
		"container_hash":"publisher@sha256:test1234567890123213213123213213213213",
		"container_image":"docker.io/test-publisher:1.0.67",
	}

	includesList := []string{
		"poduid", "podlabels", "podannotations", "imageid", "imagerepo", //"imagetag", //"image",
	}

	expectedResult := map[string]interface{}{
		//"image": "test-publisher",
		"imageID": "sha256:test1234567890123213213123213213213213",
		"imageRepo": "docker.io",
		//"imageTag": "1.0.67",
		"podAnnotations": map[string]interface{}{
			"test": "2023-10-02T08:21:49.954540360Z",
		},
		"podLabels": map[string]interface{}{
			"app": "test",
			"controller-revision-hash": "f48799794",
			"dsName": "defender-publisher-ds",
			"kubernetes.azure.com/managedby": "aks",
			"pod-template-generation": "2",
		},
		"podUid": "93bf47d2-5c1a-42bc-test-481939a93a66",
	}

	result := processIncludes(kubernetesMetadataMap, includesList)

	if !reflect.DeepEqual(result, expectedResult) {
		t.Errorf("Expected result to be %v, but got %v", expectedResult, result)
	}
}

func TestParseImageDetails(t *testing.T) {
	testCases := []struct {
		desc         string
		image        string
		expectedRepo string
		expectedName string
		expectedTag  string
	}{
		// --- no registry/host ---
		{
			desc:         "bare name",
			image:        "nginx",
			expectedRepo: "",
			expectedName: "nginx",
			expectedTag:  "latest",
		},
		{
			desc:         "name + tag",
			image:        "nginx:1.21",
			expectedRepo: "",
			expectedName: "nginx",
			expectedTag:  "1.21",
		},
		{
			desc:         "name + digest, no tag",
			image:        "nginx@sha256:abc123def456",
			expectedRepo: "",
			expectedName: "nginx",
			expectedTag:  "latest",
		},
		// --- namespace/name (no host) ---
		{
			desc:         "namespace/name",
			image:        "library/nginx",
			expectedRepo: "library",
			expectedName: "nginx",
			expectedTag:  "latest",
		},
		{
			desc:         "namespace/name + tag",
			image:        "library/nginx:1.21",
			expectedRepo: "library",
			expectedName: "nginx",
			expectedTag:  "1.21",
		},
		{
			desc:         "namespace/name + digest, no tag",
			image:        "library/nginx@sha256:abc123def456",
			expectedRepo: "library",
			expectedName: "nginx",
			expectedTag:  "latest",
		},
		// --- host/path ---
		{
			desc:         "host/name + tag",
			image:        "docker.io/library/nginx:1.21",
			expectedRepo: "docker.io",
			expectedName: "library/nginx",
			expectedTag:  "1.21",
		},
		{
			desc:         "host/multi-segment path + tag",
			image:        "mcr.microsoft.com/azuremonitor/containerinsights/cidev:3.1.34",
			expectedRepo: "mcr.microsoft.com",
			expectedName: "azuremonitor/containerinsights/cidev",
			expectedTag:  "3.1.34",
		},
		{
			desc:         "host/multi-segment path + digest, no tag",
			image:        "mcr.microsoft.com/azuremonitor/containerinsights/cidev@sha256:abc123",
			expectedRepo: "mcr.microsoft.com",
			expectedName: "azuremonitor/containerinsights/cidev",
			expectedTag:  "latest",
		},
		{
			// The crash that motivated the fix: digest-pinned, tagless image (ubiquitous on OpenShift).
			desc:         "host/name + digest, no tag (OpenShift) - previously panicked",
			image:        "quay.io/openshift-release-dev/ocp-release@sha256:ed3b2be8d2673f8669ba2a6d4951011b9b4d52eb4a28eb46ed87c05d175cc196",
			expectedRepo: "quay.io",
			expectedName: "openshift-release-dev/ocp-release",
			expectedTag:  "latest",
		},
		{
			desc:         "tag AND digest",
			image:        "repo/name:1.0@sha256:abc123",
			expectedRepo: "repo",
			expectedName: "name",
			expectedTag:  "1.0",
		},
		// --- known limitation: registry with an explicit :port is mis-split because the
		// parser treats the first colon as the tag delimiter. Documented here as the
		// current (non-panicking) behavior so any future change to it is intentional. ---
		{
			desc:         "host:port/name + tag (known quirk: port mistaken for tag)",
			image:        "myregistry.io:5000/team/app:1.0",
			expectedRepo: "",
			expectedName: "myregistry.io",
			expectedTag:  "5000/team/app:1.0",
		},
		{
			desc:         "host:port/name + digest (known quirk)",
			image:        "myregistry.io:5000/team/app@sha256:abc123",
			expectedRepo: "",
			expectedName: "myregistry.io",
			expectedTag:  "5000/team/app",
		},
		{
			desc:         "localhost:port/name (known quirk)",
			image:        "localhost:5000/app",
			expectedRepo: "",
			expectedName: "localhost",
			expectedTag:  "5000/app",
		},
		// --- edge case ---
		{
			desc:         "empty string",
			image:        "",
			expectedRepo: "",
			expectedName: "",
			expectedTag:  "latest",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.desc, func(t *testing.T) {
			repo, name, tag := parseImageDetails(tc.image)
			assert.Equal(t, tc.expectedRepo, repo, "repo mismatch for image %q", tc.image)
			assert.Equal(t, tc.expectedName, name, "name mismatch for image %q", tc.image)
			assert.Equal(t, tc.expectedTag, tag, "tag mismatch for image %q", tc.image)
		})
	}
}

func TestProcessIncludesDigestPinnedImage(t *testing.T) {
	// Reproduces the crash where a digest-pinned, tagless image (e.g. on OpenShift)
	// triggered a slice out-of-range panic in parseImageDetails via processIncludes.
	kubernetesMetadataMap := map[string]interface{}{
		"container_hash":  "ocp-release@sha256:ed3b2be8d2673f8669ba2a6d4951011b9b4d52eb4a28eb46ed87c05d175cc196",
		"container_image": "quay.io/openshift-release-dev/ocp-release@sha256:ed3b2be8d2673f8669ba2a6d4951011b9b4d52eb4a28eb46ed87c05d175cc196",
	}

	includesList := []string{"imagerepo", "image", "imagetag", "imageid"}

	expectedResult := map[string]interface{}{
		"imageRepo": "quay.io",
		"image":     "openshift-release-dev/ocp-release",
		"imageTag":  "latest",
		"imageID":   "sha256:ed3b2be8d2673f8669ba2a6d4951011b9b4d52eb4a28eb46ed87c05d175cc196",
	}

	result := processIncludes(kubernetesMetadataMap, includesList)

	if !reflect.DeepEqual(result, expectedResult) {
		t.Errorf("Expected result to be %v, but got %v", expectedResult, result)
	}
}
