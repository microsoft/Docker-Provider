package main

import (
	"encoding/json"
	"fmt"
	"reflect"
	"testing"

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
		"filepath":   "/var/log/containers/pod_xyz.log",
		"stream":     "stdout",
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
				"pod_name":       "test-publisher-ds-bssg6",
				"namespace_name": "kube-system",
				"pod_id":         "93bf47d2-5c1a-42bc-test-481939a93a66",
				"labels": map[interface{}]interface{}{
					"app":                            "test",
					"controller-revision-hash":       "f48799794",
					"dsName":                         "defender-publisher-ds",
					"kubernetes.azure.com/managedby": "aks",
					"pod-template-generation":        "2",
				},
				"annotations": map[interface{}]interface{}{
					"kubernetes.io/config.seen":   "2023-10-02T08:21:49.954540360Z",
					"kubernetes.io/config.source": "api",
				},
				"host":            "test-agentpool-test-test000001",
				"container_name":  "test-publisher",
				"docker_id":       "test1234567890123213213123213213213213",
				"container_hash":  "publisher@sha256:test1234567890123213213123213213213213",
				"container_image": "test-publisher:1.0.67",
			},
		},
		{
			"filepath": "/var/log/containers/pod_abc.log",
			"stream":   "stderr",
			"kubernetes": map[interface{}]interface{}{
				"pod_name":       "test-consumer-ds-abcde",
				"namespace_name": "default",
				"pod_id":         "a1b2c3d4e5f6",
				"labels": map[interface{}]interface{}{
					"app":                            "test",
					"controller-revision-hash":       "f48799794",
					"dsName":                         "defender-consumer-ds",
					"kubernetes.azure.com/managedby": "aks",
					"pod-template-generation":        "1",
				},
				"annotations": map[interface{}]interface{}{
					"kubernetes.io/config.seen":   "2023-10-02T08:21:49.954540360Z",
					"kubernetes.io/config.source": "api",
				},
				"host":            "test-agentpool-test-test000002",
				"container_name":  "test-consumer",
				"docker_id":       "abcde12345",
				"container_hash":  "consumer@sha256:abcde12345",
				"container_image": "test-consumer:2.0.12",
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

func TestParseImageDetails(t *testing.T) {
	tests := []struct {
		name         string
		image        string
		expectedRepo string
		expectedName string
		expectedTag  string
	}{
		{
			name:         "ACR image with tag",
			image:        "cradhahgwnpddc301containerimgregistry.azurecr.io/adha-b2b-clamav-container:1.13.0",
			expectedRepo: "cradhahgwnpddc301containerimgregistry.azurecr.io",
			expectedName: "adha-b2b-clamav-container",
			expectedTag:  "1.13.0",
		},
		{
			name:         "OpenShift registry with port and digest",
			image:        "image-registry.openshift-image-registry.svc:5000/openshift/nginx@sha256:994f124566a0b6e8e1feeef40c6e9aa075185cfafde9b657afd06c38711d10fa",
			expectedRepo: "image-registry.openshift-image-registry.svc:5000/openshift",
			expectedName: "nginx",
			expectedTag:  "latest",
		},
		{
			name:         "Docker.io image with digest",
			image:        "docker.io/library/redis@sha256:bfb12425ee0f266763621d49b44d07a50c387c3d2e24feca982193ceb1abfbe4",
			expectedRepo: "docker.io/library",
			expectedName: "redis",
			expectedTag:  "latest",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo, name, tag := parseImageDetails(tt.image)
			assert.Equal(t, tt.expectedRepo, repo, "repo mismatch")
			assert.Equal(t, tt.expectedName, name, "name mismatch")
			assert.Equal(t, tt.expectedTag, tag, "tag mismatch")
		})
	}
}

func TestProcessIncludes(t *testing.T) {
	kubernetesMetadataMap := map[string]interface{}{
		"pod_name":       "test-publisher-ds-bssg6",
		"namespace_name": "kube-system",
		"pod_id":         "93bf47d2-5c1a-42bc-test-481939a93a66",
		"labels": map[string]interface{}{
			"app":                            "test",
			"controller-revision-hash":       "f48799794",
			"dsName":                         "defender-publisher-ds",
			"kubernetes.azure.com/managedby": "aks",
			"pod-template-generation":        "2",
		},
		"annotations": map[string]interface{}{
			"test": "2023-10-02T08:21:49.954540360Z",
		},
		"host":            "test-agentpool-test-test000001",
		"container_name":  "test-publisher",
		"docker_id":       "test1234567890123213213123213213213213",
		"container_hash":  "publisher@sha256:test1234567890123213213123213213213213",
		"container_image": "docker.io/test-publisher:1.0.67",
	}

	includesList := []string{
		"poduid", "podlabels", "podannotations", "imageid", "imagerepo", //"imagetag", //"image",
	}

	expectedResult := map[string]interface{}{
		//"image": "test-publisher",
		"imageID":   "sha256:test1234567890123213213123213213213213",
		"imageRepo": "docker.io",
		//"imageTag": "1.0.67",
		"podAnnotations": map[string]interface{}{
			"test": "2023-10-02T08:21:49.954540360Z",
		},
		"podLabels": map[string]interface{}{
			"app":                            "test",
			"controller-revision-hash":       "f48799794",
			"dsName":                         "defender-publisher-ds",
			"kubernetes.azure.com/managedby": "aks",
			"pod-template-generation":        "2",
		},
		"podUid": "93bf47d2-5c1a-42bc-test-481939a93a66",
	}

	result := processIncludes(kubernetesMetadataMap, includesList)

	if !reflect.DeepEqual(result, expectedResult) {
		t.Errorf("Expected result to be %v, but got %v", expectedResult, result)
	}
}
