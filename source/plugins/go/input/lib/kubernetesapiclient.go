package lib

import (
	"Docker-Provider/source/plugins/go/src/extension"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	ApiVersion          = "v1"
	ApiVersionApps      = "v1"
	ApiGroupApps        = "apps"
	ApiGroupHPA         = "autoscaling"
	ApiVersionHPA       = "v1"
	CaFile              = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
	TokenFileName       = "/var/run/secrets/kubernetes.io/serviceaccount/token"
	KubeSystemNamespace = "kube-system"
	WindowsLogPath      = "/etc/amalogswindows/"
	LinuxLogPath        = "/var/opt/microsoft/docker-cimprov/log/"
)

var (
	ClusterName                 = ""
	ClusterId                   = ""
	IsNodeMaster                = false
	IsAROV3Cluster              = false
	IsLinuxCluster              = false
	IsValidRunningNode          = false
	TokenStr                    = ""
	ResourceLimitsTelemetryHash map[string]interface{}
	LogPath                     string
	logger                      *log.Logger
	TokenExpiry                 int64
)

func init() {
	// Define log path
	isTestEnv := os.Getenv("GOUNITTEST") == "true"
	osType := os.Getenv("OS_TYPE")
	if osType != "" && osType == "windows" {
		LogPath = WindowsLogPath + "kubernetes_client_log.txt"
	} else {
		LogPath = LinuxLogPath + "kubernetes_client_log.txt"
	}

	if isTestEnv {
		LogPath = "./kubernetes_client_log.txt"
	}

	TokenExpiry = time.Now().Unix()

	// Define logger
	file, err := os.OpenFile(LogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		log.Fatalln("Failed to open log file :", err)
	}
	logger = log.New(file, "", log.LstdFlags)
}

func getKubeResourceInfo(resource string, api_group *string) (*http.Response, error) {
	logger.Println("Getting Kube resource: ", resource)

	resourceUri, err := getResourceUri(resource, api_group)
	if err != nil {
		logger.Println("getResourceUri failed: ", err)
		return nil, err
	}

	// Load CA cert
	caCert, err := ioutil.ReadFile(CaFile)
	if err != nil {
		logger.Println("Failed to read ca.crt: ", err)
		return nil, err
	}

	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCert)

	tlsConfig := &tls.Config{
		RootCAs: caCertPool,
	}

	// Setup HTTPS client
	tlsConfig.BuildNameToCertificate()
	transport := &http.Transport{TLSClientConfig: tlsConfig}
	client := &http.Client{Transport: transport, Timeout: time.Second * 40}

	req, _ := http.NewRequest("GET", resourceUri, nil)
	req.Header.Add("Authorization", "Bearer "+GetTokenStr())

	resp, err := client.Do(req)
	if err != nil {
		logger.Println("Failed to make request to Kube API: ", err)
		return nil, err
	}

	logger.Println("KubernetesAPIClient::getKubeResourceInfo : Got response of ", resp.StatusCode)

	return resp, nil
}

func getResourceUri(resource string, api_group *string) (string, error) {
	serviceHost, serviceHostExist := os.LookupEnv("KUBERNETES_SERVICE_HOST")
	servicePort, servicePortExist := os.LookupEnv("KUBERNETES_PORT_443_TCP_PORT")

	if serviceHostExist && servicePortExist {
		switch {
		case api_group == nil:
			return "https://" + serviceHost + ":" + servicePort + "/api/" + ApiVersion + "/" + resource, nil
		case *api_group == ApiGroupApps:
			return "https://" + serviceHost + ":" + servicePort + "/apis/apps/" + ApiVersionApps + "/" + resource, nil
		case *api_group == ApiGroupHPA:
			return "https://" + serviceHost + ":" + servicePort + "/apis/" + ApiGroupHPA + "/" + ApiVersionHPA + "/" + resource, nil
		default:
			return "", fmt.Errorf("unsupported API group: %s", *api_group)
		}
	} else {
		logger.Println("Kubernetes environment variable not set KUBERNETES_SERVICE_HOST: ", serviceHost, " KUBERNETES_PORT_443_TCP_PORT: ", servicePort, ". Unable to form resourceUri")
		return "", errors.New("environment variables not set")
	}
}

func GetTokenStr() string {
	if TokenStr == "" || math.Abs(float64(TokenExpiry-time.Now().Unix())) <= float64(SERVICE_ACCOUNT_TOKEN_REFRESH_INTERVAL_SECONDS) { // refresh token from token file if its near expiry
		if _, err := os.Stat(TokenFileName); err == nil {
			data, readErr := ioutil.ReadFile(TokenFileName)
			if readErr == nil {
				TokenStr = string(data)
				if token, _ := jwt.Parse(TokenStr, nil); token != nil {
					if claims, ok := token.Claims.(jwt.MapClaims); ok {
						if claims["exp"] != nil {
							TokenExpiry = int64(claims["exp"].(float64))
						} else {
							fmt.Println("exp not present in JWT")
							TokenExpiry = time.Now().Unix() + int64(LEGACY_SERVICE_ACCOUNT_TOKEN_EXPIRY_SECONDS)
						}
					}
				} else {
					fmt.Println("The token is not a JSON Web Token (JWT).")
					TokenExpiry = time.Now().Unix() + int64(LEGACY_SERVICE_ACCOUNT_TOKEN_EXPIRY_SECONDS)
				}

				if math.Abs(float64(TokenExpiry-time.Now().Unix())) > float64(LEGACY_SERVICE_ACCOUNT_TOKEN_EXPIRY_SECONDS) {
					TokenExpiry = time.Now().Unix() + int64(LEGACY_SERVICE_ACCOUNT_TOKEN_EXPIRY_SECONDS)
				}
			} else {
				logger.Printf("Unable to read token string from %s: %v\n", TokenFileName, readErr)
				TokenExpiry = time.Now().Unix()
				TokenStr = ""
			}
		}
	}
	return TokenStr
}

func IsExcludeResourceItem(resourceName, resourceNamespace, namespaceFilteringMode string, namespaces []string) bool {
	var isExclude bool

	if resourceName != "" && resourceNamespace != "" {
		if strings.HasPrefix(resourceName, "ama-logs") && resourceNamespace == "kube-system" {
			isExclude = false
		} else if len(namespaces) > 0 && namespaceFilteringMode != "" {
			if namespaceFilteringMode == "exclude" && contains(namespaces, resourceNamespace) {
				isExclude = true
			} else if namespaceFilteringMode == "include" && !contains(namespaces, resourceNamespace) {
				isExclude = true
			}
		}
	}

	return isExclude
}

func contains(slice []string, str string) bool {
	for _, v := range slice {
		if v == str {
			return true
		}
	}

	return false
}

func IsDCRStreamIdTag(tag string) bool {
	return tag != "" && strings.HasPrefix(tag, ExtensionOutputStreamIDTagPrefix)
}

func GetOutputStreamIdAndSource(e *extension.Extension, dataType, tag string, agentConfigRefreshTracker int64) (string, bool) {
	fromCache := true
	if !IsDCRStreamIdTag(tag) || time.Now().Unix()-agentConfigRefreshTracker >= AgentConfigRefreshIntervalSeconds {
		fromCache = false
	}
	tag = e.GetOutputStreamId(dataType, fromCache)

	return tag, fromCache
}

func GetClusterID() string {
	if ClusterId != "" {
		return ClusterId
	}

	// By default, initialize clusterID to the cluster name.
	// <TODO> In ACS/On-prem, we need to figure out how we can generate clusterID.
	// Dilipr: Spoof the subid by generating md5 hash of cluster name, and taking some constant parts of it.
	// e.g. md5 digest is 128 bits = 32 characters in hex. Get the first 16 to get a guid, and the next 16 to get the resource id.
	ClusterId = GetClusterName()

	// Try to retrieve the cluster ID from the AKS_RESOURCE_ID environment variable.
	aksResourceID := os.Getenv("AKS_RESOURCE_ID")
	if aksResourceID != "" {
		ClusterId = aksResourceID
	}

	return ClusterId
}

func GetClusterName() string {
	if ClusterName != "" {
		return ClusterName
	}
	ClusterName = "None"
	aksResourceID := os.Getenv("AKS_RESOURCE_ID")
	if aksResourceID != "" {
		parts := strings.Split(aksResourceID, "/")
		ClusterName = parts[len(parts)-1]
	} else {
		acsName := os.Getenv("ACS_RESOURCE_NAME")
		if acsName != "" {
			ClusterName = acsName
		} else {
			kubesystemResourceUri := "namespaces/" + KubeSystemNamespace + "/pods"
			logger.Printf("KubernetesApiClient::getClusterName : Getting pods from Kube API @ %v", time.Now().UTC().Format(time.RFC3339))

			response, err := getKubeResourceInfo(kubesystemResourceUri, nil)
			if err != nil {
				logger.Println("KubernetesApiClient::getClusterName : Error getting pods from Kube API: ", err.Error())
				return ClusterName
			}
			body, err := ioutil.ReadAll(response.Body)
			if err != nil {
				logger.Println("KubernetesApiClient::getClusterName : Error reading response body: ", err.Error())
				return ClusterName
			}
			var podInfo map[string]interface{}
			err = json.Unmarshal(body, &podInfo)
			if err != nil {
				logger.Println("KubernetesApiClient::getClusterName : Error unmarshalling response body: ", err.Error())
			}
			logger.Printf("KubernetesApiClient::getClusterName : Done getting pods from Kube API @ %v", time.Now().UTC().Format(time.RFC3339))

			items, ok := podInfo["items"].([]interface{})
			if !ok {
				logger.Println("Invalid JSON format: 'items' is not an array")
				return ClusterName
			}
			for _, item := range items {
				podInfo, ok := item.(map[string]interface{})
				if !ok {
					logger.Println("Invalid JSON format: 'item' is not an object")
					return ClusterName
				}

				metadata, ok := podInfo["metadata"].(map[string]interface{})
				if !ok {
					logger.Println("Invalid JSON format: 'metadata' is not an object")
					return ClusterName
				}
				podName, ok := metadata["name"].(string)
				if !ok {
					logger.Println("Invalid JSON format: 'name' is not a string")
					return ClusterName
				}

				if strings.Contains(podName, "kube-controller-manager") {
					spec, ok := podInfo["spec"].(map[string]interface{})
					if !ok {
						logger.Println("Invalid JSON format: 'spec' is not an object")
						return ClusterName
					}
					containers, ok := spec["containers"].([]interface{})
					if !ok {
						logger.Println("Invalid JSON format: 'containers' is not an array")
						return ClusterName
					}

					for _, container := range containers {
						containerInfo, ok := container.(map[string]interface{})
						if !ok {
							logger.Println("Invalid JSON format: 'container' is not an object")
							return ClusterName
						}

						commands, ok := containerInfo["command"].([]interface{})
						if !ok {
							logger.Println("Invalid JSON format: 'command' is not an array")
							return ClusterName
						}

						for _, command := range commands {
							commandStr, ok := command.(string)
							if !ok {
								logger.Println("Invalid JSON format: 'command' is not a string")
								return ClusterName
							}

							if strings.Contains(commandStr, "--cluster-name") {
								splits := strings.Split(commandStr, "=")
								if len(splits) >= 2 {
									ClusterName = splits[1]
								}
							}
						}
					}
				}
			}
		}
	}
	return ClusterName
}
