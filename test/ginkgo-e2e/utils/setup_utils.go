package utils

import (
	"encoding/json"
	"flag"
	"path/filepath"

	"k8s.io/client-go/rest"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"

	"io/ioutil"

	"github.com/ghodss/yaml"
)

/*
 * Returns the Kubernetes API client and cluster configuration.
 * The function will first check if a kubeconfig file is present in the user's home directory, for running the tests locally.
 * If the file is not found, it will assume the tests are running in a Kubernetes cluster and use the in-cluster configuration.
 */
func SetupKubernetesClient() (*kubernetes.Clientset, *rest.Config, error) {
	var kubeconfig *string
	if home := homedir.HomeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
	}
	flag.Parse()

	cfg, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		cfg, err = rest.InClusterConfig()
		if err != nil {
			return nil, nil, err
		}
	}

	client, err := kubernetes.NewForConfig(cfg)
	if err != nil {
		return nil, nil, err
	}

	return client, cfg, nil
}

func ReadFileContent(filename string) ([]byte, error) {
	content, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	return content, nil
}

func ParseK8sYaml(yamlBytes []byte) (corev1.ConfigMap, error) {
	// convert the yaml to json
	jsonBytes, err := yaml.YAMLToJSON(yamlBytes)
	if err != nil {
		return corev1.ConfigMap{}, err
	}
	// unmarshal the json into the kube struct
	var configmap = corev1.ConfigMap{}
	err = json.Unmarshal(jsonBytes, &configmap)
	if err != nil {
		return corev1.ConfigMap{}, err
	}

	return configmap, nil
}
