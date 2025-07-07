package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const IMDSTokenPathForWindows = "c:/etc/imds-access-token/token" // only used in windows
const AMCSAgentConfigAPIVersion = "2020-08-01-preview"
const AMCSIngestionTokenAPIVersion = "2020-04-01-preview"
const MaxRetries = 3

var IMDSToken string
var IMDSTokenExpiration int64

var ConfigurationId string
var ChannelId string

var IngestionAuthToken string
var IngestionAuthTokenExpiration int64
var AMCSRedirectedEndpoint string = ""

// Arc k8s MSI related
const ArcK8sClusterConfigCRDAPIVersion = "clusterconfig.azure.com/v1beta1"
const ArcK8sClusterIdentityResourceName = "container-insights-clusteridentityrequest"
const ArcK8sClusterIdentityResourceNameSpace = "azure-arc"
const ArcK8sMSITokenSecretNameSpace = "azure-arc"

type IMDSResponse struct {
	AccessToken  string `json:"access_token"`
	ClientID     string `json:"client_id"`
	ExpiresIn    string `json:"expires_in"`
	ExpiresOn    string `json:"expires_on"`
	ExtExpiresIn string `json:"ext_expires_in"`
	NotBefore    string `json:"not_before"`
	Resource     string `json:"resource"`
	TokenType    string `json:"token_type"`
}

type AgentConfiguration struct {
	Configurations []struct {
		Configurationid string `json:"configurationId"`
		Etag            string `json:"eTag"`
		Op              string `json:"op"`
		Content         struct {
			Datasources []struct {
				Configuration struct {
					Extensionname string `json:"extensionName"`
				} `json:"configuration"`
				ID      string `json:"id"`
				Kind    string `json:"kind"`
				Streams []struct {
					Stream                string `json:"stream"`
					Solution              string `json:"solution"`
					Extensionoutputstream string `json:"extensionOutputStream"`
				} `json:"streams"`
				Sendtochannels []string `json:"sendToChannels"`
			} `json:"dataSources"`
			Channels []struct {
				Endpoint string `json:"endpoint"`
				ID       string `json:"id"`
				Protocol string `json:"protocol"`
			} `json:"channels"`
			Extensionconfigurations struct {
				Containerinsights []struct {
					ID                string   `json:"id"`
					Originids         []string `json:"originIds"`
					Extensionsettings struct {
						DataCollectionSettings struct {
							Interval               string   `json:"interval"`
							NamespaceFilteringMode string   `json:"namespaceFilteringMode"`
							Namespaces             []string `json:"namespaces"`
							EnableContainerLogV2   bool     `json:"enableContainerLogV2"`
						} `json:"dataCollectionSettings"`
					} `json:"extensionSettings"`
					Outputstreams struct {
						LinuxPerfBlob                   string `json:"LINUX_PERF_BLOB"`
						ContainerInventoryBlob          string `json:"CONTAINER_INVENTORY_BLOB"`
						ContainerLogBlob                string `json:"CONTAINER_LOG_BLOB"`
						ContainerinsightsContainerlogv2 string `json:"CONTAINERINSIGHTS_CONTAINERLOGV2"`
						ContainerNodeInventoryBlob      string `json:"CONTAINER_NODE_INVENTORY_BLOB"`
						KubeEventsBlob                  string `json:"KUBE_EVENTS_BLOB"`
						KubeMonAgentEventsBlob          string `json:"KUBE_MON_AGENT_EVENTS_BLOB"`
						KubeNodeInventoryBlob           string `json:"KUBE_NODE_INVENTORY_BLOB"`
						KubePodInventoryBlob            string `json:"KUBE_POD_INVENTORY_BLOB"`
						KubePvInventoryBlob             string `json:"KUBE_PV_INVENTORY_BLOB"`
						KubeServicesBlob                string `json:"KUBE_SERVICES_BLOB"`
						InsightsMetricsBlob             string `json:"INSIGHTS_METRICS_BLOB"`
					} `json:"outputStreams"`
				} `json:"ContainerInsights"`
			} `json:"extensionConfigurations"`
		} `json:"content"`
	} `json:"configurations"`
}

type IngestionTokenResponse struct {
	Configurationid    string `json:"configurationId"`
	Ingestionauthtoken string `json:"ingestionAuthToken"`
}

type ContainerInsightsIdentityRequest struct {
	APIVersion string `json:"apiVersion"`
	Kind       string `json:"kind"`
	Metadata   struct {
		Annotations struct {
			MetaHelmShReleaseName      string `json:"meta.helm.sh/release-name"`
			MetaHelmShReleaseNamespace string `json:"meta.helm.sh/release-namespace"`
		} `json:"annotations"`
		CreationTimestamp time.Time `json:"creationTimestamp"`
		Generation        int       `json:"generation"`
		Labels            struct {
			AppKubernetesIoManagedBy string `json:"app.kubernetes.io/managed-by"`
		} `json:"labels"`
		Name            string `json:"name"`
		Namespace       string `json:"namespace"`
		ResourceVersion string `json:"resourceVersion"`
		SelfLink        string `json:"selfLink"`
		UID             string `json:"uid"`
	} `json:"metadata"`
	Spec struct {
		Audience   string `json:"audience"`
		ResourceID string `json:"resourceId"`
	} `json:"spec"`
	Status struct {
		ExpirationTime time.Time `json:"expirationTime"`
		TokenReference struct {
			DataName   string `json:"dataName"`
			SecretName string `json:"secretName"`
		} `json:"tokenReference"`
	} `json:"status"`
}

func getAccessTokenFromIMDS() (string, int64, error) {
	Log("Info getAccessTokenFromIMDS: start")
	useIMDSTokenProxyEndPoint := os.Getenv("USE_IMDS_TOKEN_PROXY_END_POINT")
	imdsAccessToken := ""
	var expiration int64
	var responseBytes []byte
	var err error

	if useIMDSTokenProxyEndPoint != "" && strings.Compare(strings.ToLower(useIMDSTokenProxyEndPoint), "true") == 0 {
		Log("Info Reading IMDS Access Token from IMDS Token proxy endpoint")
		mcsEndpoint := os.Getenv("MCS_ENDPOINT")
		msi_endpoint_string := fmt.Sprintf("http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=%s", mcsEndpoint)
		var msi_endpoint *url.URL
		msi_endpoint, err := url.Parse(msi_endpoint_string)
		if err != nil {
			Log("getAccessTokenFromIMDS: Error creating IMDS endpoint URL: %s", err.Error())
			return imdsAccessToken, expiration, err
		}
		req, err := http.NewRequest("GET", msi_endpoint.String(), nil)
		if err != nil {
			Log("getAccessTokenFromIMDS: Error creating HTTP request: %s", err.Error())
			return imdsAccessToken, expiration, err
		}
		req.Header.Add("Metadata", "true")

		//IMDS endpoint nonroutable endpoint and requests doesnt go through proxy hence using dedicated http client
		httpClient := &http.Client{Timeout: 30 * time.Second}

		// Call managed services for Azure resources token endpoint
		var resp *http.Response = nil
		IsSuccess := false
		for retryCount := 0; retryCount < MaxRetries; retryCount++ {
			resp, err = httpClient.Do(req)
			if err != nil {
				message := fmt.Sprintf("getAccessTokenFromIMDS: Error calling token endpoint: %s, retryCount: %d", err.Error(), retryCount)
				Log(message)
				SendException(message)
				continue
			}

			if resp != nil && resp.Body != nil {
				defer resp.Body.Close()
			}

			Log("getAccessTokenFromIMDS: IMDS Response Status: %d, retryCount: %d", resp.StatusCode, retryCount)
			if IsRetriableError(resp.StatusCode) {
				message := fmt.Sprintf("getAccessTokenFromIMDS: IMDS Request failed with an error code: %d, retryCount: %d", resp.StatusCode, retryCount)
				Log(message)
				retryDelay := time.Duration((retryCount+1)*100) * time.Millisecond
				if resp.StatusCode == 429 {
					if resp != nil && resp.Header.Get("Retry-After") != "" {
						after, err := strconv.ParseInt(resp.Header.Get("Retry-After"), 10, 64)
						if err != nil && after > 0 {
							retryDelay = time.Duration(after) * time.Second
						}
					}
				}
				time.Sleep(retryDelay)
				continue
			} else if resp.StatusCode != 200 {
				message := fmt.Sprintf("getAccessTokenFromIMDS: IMDS Request failed with nonretryable error code: %d, retryCount: %d", resp.StatusCode, retryCount)
				Log(message)
				SendException(message)
				return imdsAccessToken, expiration, err
			}
			IsSuccess = true
			break // call succeeded, don't retry any more
		}
		if !IsSuccess || resp == nil || resp.Body == nil {
			Log("getAccessTokenFromIMDS: IMDS Request ran out of retries")
			return imdsAccessToken, expiration, err
		}

		// Pull out response body
		responseBytes, err = ioutil.ReadAll(resp.Body)
		if err != nil {
			Log("getAccessTokenFromIMDS: Error reading response body: %s", err.Error())
			return imdsAccessToken, expiration, err
		}

	} else {
		resourceId := os.Getenv("AKS_RESOURCE_ID")
		if resourceId != "" && strings.Contains(strings.ToLower(resourceId), strings.ToLower("Microsoft.ContainerService/managedClusters")) {
			Log("Info Reading IMDS Access Token from file : %s", IMDSTokenPathForWindows)
			if _, err = os.Stat(IMDSTokenPathForWindows); os.IsNotExist(err) {
				Log("getAccessTokenFromIMDS: IMDS token file doesnt exist: %s", err.Error())
				return imdsAccessToken, expiration, err
			}
			//adding retries incase if we ended up reading the token file while the token file being written
			for retryCount := 0; retryCount < MaxRetries; retryCount++ {
				responseBytes, err = ioutil.ReadFile(IMDSTokenPathForWindows)
				if err != nil {
					Log("getAccessTokenFromIMDS: Could not read IMDS token from file: %s, retryCount: %d", err.Error(), retryCount)
					time.Sleep(time.Duration((retryCount+1)*100) * time.Millisecond)
					continue
				}
				break
			}
		} else {
			Log("getAccessTokenFromIMDS: Info Getting MSI Access Token reference from CRD and token from secret for Azure Arc K8s cluster")
			var crdResponseBytes []byte
			var errorMessage string
			for retryCount := 0; retryCount < MaxRetries; retryCount++ {
				crd_request_endpoint := fmt.Sprintf("/apis/%s/namespaces/%s/azureclusteridentityrequests/%s", ArcK8sClusterConfigCRDAPIVersion, ArcK8sClusterIdentityResourceNameSpace, ArcK8sClusterIdentityResourceName)
				crdResponseBytes, err = ClientSet.RESTClient().Get().AbsPath(crd_request_endpoint).DoRaw(context.TODO())
				if err != nil {
					Log("getAccessTokenFromIMDS: Failed to get the CRD: %s in namespace: %s, retryCount: %d", ArcK8sClusterIdentityResourceName, ArcK8sClusterIdentityResourceNameSpace, err.Error(), retryCount)
					time.Sleep(time.Duration((retryCount+1)*100) * time.Millisecond)
					continue
				}
				break
			}
			if crdResponseBytes != nil {
				var ciCRDRequest ContainerInsightsIdentityRequest
				err = json.Unmarshal(crdResponseBytes, &ciCRDRequest)
				if err != nil {
					errorMessage = fmt.Sprintf("getAccessTokenFromIMDS: Error unmarshalling the crdResponseBytes: %s", err.Error())
					Log(errorMessage)
					return imdsAccessToken, expiration, errors.New(errorMessage)
				} else {
					status := ciCRDRequest.Status
					tokenReference := status.TokenReference
					dataFieldName := tokenReference.DataName
					secretName := tokenReference.SecretName
					expirationTime := status.ExpirationTime
					if dataFieldName == "" || secretName == "" || expirationTime.IsZero() {
						errorMessage = "getAccessTokenFromIMDS: Either dataName or SecretName or ExpirationTime values empty which indicates token not refreshed"
						Log(errorMessage)
						Log("getAccessTokenFromIMDS: dataName: %s, secretName: %s, expirationTime: %s", dataFieldName, secretName, expirationTime)
						return imdsAccessToken, expiration, errors.New(errorMessage)
					} else {
						var secret *v1.Secret
						for retryCount := 0; retryCount < MaxRetries; retryCount++ {
							secret, err = ClientSet.CoreV1().Secrets(ArcK8sMSITokenSecretNameSpace).Get(context.TODO(), secretName, metav1.GetOptions{})
							if err != nil {
								Log("getAccessTokenFromIMDS: Failed to read the secret: %s in namespace: %s, error: %s, retryCount: %d", secretName, ArcK8sMSITokenSecretNameSpace, err.Error(), retryCount)
								time.Sleep(time.Duration((retryCount+1)*100) * time.Millisecond)
								continue
							}
							break
						}
						if secret == nil {
							errorMessage = fmt.Sprintf("getAccessTokenFromIMDS: value of secret: %s in nil in namespace: %s", secretName, ArcK8sMSITokenSecretNameSpace)
							return imdsAccessToken, expiration, errors.New(errorMessage)
						}
						imdsAccessToken = string(secret.Data[dataFieldName])
						expiration = expirationTime.Unix()
						return imdsAccessToken, expiration, nil
					}
				}
			} else {
				errorMessage = fmt.Sprintf("getAccessTokenFromIMDS: faled to get the CRD: %s in namespace: %s", ArcK8sClusterIdentityResourceName, ArcK8sClusterIdentityResourceNameSpace)
				return imdsAccessToken, expiration, errors.New(errorMessage)
			}
		}
	}

	if responseBytes == nil {
		Log("getAccessTokenFromIMDS: Error responseBytes is nil")
		return imdsAccessToken, expiration, err
	}

	// Unmarshall response body into struct
	var imdsResponse IMDSResponse
	err = json.Unmarshal(responseBytes, &imdsResponse)
	if err != nil {
		Log("getAccessTokenFromIMDS: Error unmarshalling the response: %s", err.Error())
		return imdsAccessToken, expiration, err
	}
	imdsAccessToken = imdsResponse.AccessToken

	expiration, err = strconv.ParseInt(imdsResponse.ExpiresOn, 10, 64)
	if err != nil {
		Log("getAccessTokenFromIMDS: Error parsing ExpiresOn field from IMDS response: %s", err.Error())
		return imdsAccessToken, expiration, err
	}
	Log("Info getAccessTokenFromIMDS: end")
	return imdsAccessToken, expiration, nil
}

func getAgentConfiguration(imdsAccessToken string) (configurationId string, channelId string, err error) {
	Log("Info getAgentConfiguration: start")
	configurationId = ""
	channelId = ""
	var amcs_endpoint *url.URL
	var AmcsEndpoint string
	osType := os.Getenv("OS_TYPE")
	resourceId := os.Getenv("AKS_RESOURCE_ID")
	resourceRegion := os.Getenv("AKS_REGION")
	AmcsEndpoint = os.Getenv("MCS_GLOBAL_ENDPOINT")

	if AMCSRedirectedEndpoint != "" {
		AmcsEndpoint = AMCSRedirectedEndpoint
	}
	amcs_endpoint_string := fmt.Sprintf("%s%s/agentConfigurations?operatingLocation=%s&platform=%s&api-version=%s", AmcsEndpoint, resourceId, resourceRegion, osType, AMCSAgentConfigAPIVersion)

	amcs_endpoint, err = url.Parse(amcs_endpoint_string)
	if err != nil {
		Log("getAgentConfiguration: Error creating AMCS endpoint URL: %s", err.Error())
		return configurationId, channelId, err
	}

	var bearer = "Bearer " + imdsAccessToken
	// Create a new request using http
	req, err := http.NewRequest("GET", amcs_endpoint.String(), nil)
	if err != nil {
		message := fmt.Sprintf("getAgentConfiguration: Error creating HTTP request for AMCS endpoint: %s", err.Error())
		Log(message)
		return configurationId, channelId, err
	}
	req.Header.Set("Authorization", bearer)

	var resp *http.Response = nil
	IsSuccess := false
	for retryCount := 0; retryCount < MaxRetries; retryCount++ {
		resp, err = HTTPClient.Do(req)
		if err != nil {
			message := fmt.Sprintf("getAgentConfiguration: Error calling AMCS endpoint: %s", err.Error())
			Log(message)
			SendException(message)
			continue
		}
		if resp != nil && resp.Body != nil {
			defer resp.Body.Close()
		}
		Log("getAgentConfiguration Response Status: %d", resp.StatusCode)
		if resp.StatusCode == 421 { // AMCS returns redirected endpoint incase of private link
			agentConfigEndpoint := resp.Header.Get("x-ms-agent-config-endpoint")
			Log("getAgentConfiguration x-ms-agent-config-endpoint: %s", agentConfigEndpoint)
			if agentConfigEndpoint != "" {
				AMCSRedirectedEndpoint = agentConfigEndpoint
				// reconstruct request with redirected endpoint
				var err error
				redirected_amcs_endpoint_string := fmt.Sprintf("%s%s/agentConfigurations?operatingLocation=%s&platform=%s&api-version=%s", AMCSRedirectedEndpoint, resourceId, resourceRegion, osType, AMCSAgentConfigAPIVersion)
				var bearer = "Bearer " + imdsAccessToken
				req, err = http.NewRequest("GET", redirected_amcs_endpoint_string, nil)
				if err != nil {
					message := fmt.Sprintf("getAgentConfiguration: Error creating HTTP request for AMCS endpoint: %s", err.Error())
					Log(message)
					return configurationId, channelId, err
				}
				req.Header.Set("Authorization", bearer)
				continue
			}
		}
		if IsRetriableError(resp.StatusCode) {
			message := fmt.Sprintf("getAgentConfiguration: Request failed with an error code: %d, retryCount: %d", resp.StatusCode, retryCount)
			Log(message)
			retryDelay := time.Duration((retryCount+1)*100) * time.Millisecond
			if resp.StatusCode == 429 {
				if resp != nil && resp.Header.Get("Retry-After") != "" {
					after, err := strconv.ParseInt(resp.Header.Get("Retry-After"), 10, 64)
					if err != nil && after > 0 {
						retryDelay = time.Duration(after) * time.Second
					}
				}
			}
			time.Sleep(retryDelay)
			continue
		} else if resp.StatusCode != 200 {
			message := fmt.Sprintf("getAgentConfiguration: Request failed with nonretryable error code: %d, retryCount: %d", resp.StatusCode, retryCount)
			Log(message)
			SendException(message)
			return configurationId, channelId, err
		}
		IsSuccess = true
		break // call succeeded, don't retry any more
	}
	if !IsSuccess || resp == nil || resp.Body == nil {
		message := fmt.Sprintf("getAgentConfiguration Request ran out of retries")
		Log(message)
		SendException(message)
		return configurationId, channelId, err
	}
	responseBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		Log("getAgentConfiguration: Error reading response body from AMCS API call: %s", err.Error())
		return configurationId, channelId, err
	}

	// Unmarshall response body into struct
	var agentConfiguration AgentConfiguration
	err = json.Unmarshal(responseBytes, &agentConfiguration)
	if err != nil {
		message := fmt.Sprintf("getAgentConfiguration: Error unmarshalling the response: %s", err.Error())
		Log(message)
		SendException(message)
		return configurationId, channelId, err
	}

	if len(agentConfiguration.Configurations) == 0 {
		message := "getAgentConfiguration: Received empty agentConfiguration.Configurations array"
		Log(message)
		SendException(message)
		return configurationId, channelId, err
	}

	for _, config := range agentConfiguration.Configurations {
		if len(config.Content.Channels) == 0 {
			// this is expected because AMCS will return agent config based on OS Type. For example, syslog is not supported on windows hence config will not have channels and data sources
			message := "getAgentConfiguration: Received empty config.Content.Channels"
			Log(message)
			continue
		}

		configurationId = config.Configurationid
		for _, channel := range config.Content.Channels {
			if channel.ID != "" {
				channelId = channel.ID
				break
			}
		}

		if !ContainerLogV2ConfigMap && len(config.Content.Extensionconfigurations.Containerinsights) > 0 {
			for _, ciExtensionInstance := range config.Content.Extensionconfigurations.Containerinsights {
				ContainerLogSchemaV2 = ciExtensionInstance.Extensionsettings.DataCollectionSettings.EnableContainerLogV2
			}
		}
		break
	}

	if configurationId == "" || channelId == "" {
		message := "getAgentConfiguration: Failed to obtain configurationId or channelId"
		Log(message)
		SendException(message)
		return configurationId, channelId, errors.New(message)
	}
	Log("getAgentConfiguration: obtained configurationId: %s, channelId: %s", configurationId, channelId)
	Log("Info getAgentConfiguration: end")

	return configurationId, channelId, nil
}

func getIngestionAuthToken(imdsAccessToken string, configurationId string, channelId string) (ingestionAuthToken string, refreshInterval int64, err error) {
	Log("Info getIngestionAuthToken: start")
	ingestionAuthToken = ""
	refreshInterval = 0
	var amcs_endpoint *url.URL
	var AmcsEndpoint string
	osType := os.Getenv("OS_TYPE")
	resourceId := os.Getenv("AKS_RESOURCE_ID")
	resourceRegion := os.Getenv("AKS_REGION")
	AmcsEndpoint = os.Getenv("MCS_GLOBAL_ENDPOINT")

	if AMCSRedirectedEndpoint != "" {
		AmcsEndpoint = AMCSRedirectedEndpoint
	}

	amcs_endpoint_string := fmt.Sprintf("%s%s/agentConfigurations/%s/channels/%s/issueIngestionToken?operatingLocation=%s&platform=%s&api-version=%s", AmcsEndpoint, resourceId, configurationId, channelId, resourceRegion, osType, AMCSIngestionTokenAPIVersion)
	amcs_endpoint, err = url.Parse(amcs_endpoint_string)
	if err != nil {
		Log("getIngestionAuthToken: Error creating AMCS endpoint URL: %s", err.Error())
		return ingestionAuthToken, refreshInterval, err
	}

	var bearer = "Bearer " + imdsAccessToken
	// Create a new request using http
	req, err := http.NewRequest("GET", amcs_endpoint.String(), nil)
	if err != nil {
		Log("getIngestionAuthToken: Error creating HTTP request for AMCS endpoint: %s", err.Error())
		return ingestionAuthToken, refreshInterval, err
	}

	// add authorization header to the req
	req.Header.Add("Authorization", bearer)

	var resp *http.Response = nil
	IsSuccess := false
	for retryCount := 0; retryCount < MaxRetries; retryCount++ {
		// Call managed services for Azure resources token endpoint
		resp, err = HTTPClient.Do(req)
		if err != nil {
			message := fmt.Sprintf("getIngestionAuthToken: Error calling AMCS endpoint for ingestion auth token: %s", err.Error())
			Log(message)
			SendException(message)
			resp = nil
			continue
		}

		if resp != nil && resp.Body != nil {
			defer resp.Body.Close()
		}

		Log("getIngestionAuthToken Response Status: %d", resp.StatusCode)
		if resp.StatusCode == 421 { // AMCS returns redirected endpoint incase of private link
			agentConfigEndpoint := resp.Header.Get("x-ms-agent-config-endpoint")
			Log("getIngestionAuthToken x-ms-agent-config-endpoint: %s", agentConfigEndpoint)
			if agentConfigEndpoint != "" {
				AMCSRedirectedEndpoint = agentConfigEndpoint
				// reconstruct request with redirected endpoint
				var err error
				redirected_amcs_endpoint_string := fmt.Sprintf("%s%s/agentConfigurations/%s/channels/%s/issueIngestionToken?operatingLocation=%s&platform=%s&api-version=%s", AMCSRedirectedEndpoint, resourceId, configurationId, channelId, resourceRegion, osType, AMCSIngestionTokenAPIVersion)
				var bearer = "Bearer " + imdsAccessToken
				req, err = http.NewRequest("GET", redirected_amcs_endpoint_string, nil)
				if err != nil {
					message := fmt.Sprintf("getIngestionAuthToken: Error creating HTTP request for AMCS endpoint: %s", err.Error())
					Log(message)
					return ingestionAuthToken, refreshInterval, err
				}
				req.Header.Set("Authorization", bearer)
				continue
			}
		}
		if IsRetriableError(resp.StatusCode) {
			message := fmt.Sprintf("getIngestionAuthToken: Request failed with an error code: %d, retryCount: %d", resp.StatusCode, retryCount)
			Log(message)
			retryDelay := time.Duration((retryCount+1)*100) * time.Millisecond
			if resp.StatusCode == 429 {
				if resp != nil && resp.Header.Get("Retry-After") != "" {
					after, err := strconv.ParseInt(resp.Header.Get("Retry-After"), 10, 64)
					if err != nil && after > 0 {
						retryDelay = time.Duration(after) * time.Second
					}
				}
			}
			time.Sleep(retryDelay)
			continue
		} else if resp.StatusCode != 200 {
			message := fmt.Sprintf("getIngestionAuthToken: Request failed with nonretryable error code: %d, retryCount: %d", resp.StatusCode, retryCount)
			Log(message)
			SendException(message)
			return ingestionAuthToken, refreshInterval, err
		}
		IsSuccess = true
		break
	}

	if !IsSuccess || resp == nil || resp.Body == nil {
		message := "getIngestionAuthToken: ran out of retries calling AMCS for ingestion token"
		Log(message)
		SendException(message)
		return ingestionAuthToken, refreshInterval, err
	}

	// Pull out response body
	responseBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		Log("getIngestionAuthToken: Error reading response body from AMCS Ingestion API call : %s", err.Error())
		return ingestionAuthToken, refreshInterval, err
	}

	// Unmarshall response body into struct
	var ingestionTokenResponse IngestionTokenResponse
	err = json.Unmarshal(responseBytes, &ingestionTokenResponse)
	if err != nil {
		Log("getIngestionAuthToken: Error unmarshalling the response: %s", err.Error())
		return ingestionAuthToken, refreshInterval, err
	}

	ingestionAuthToken = ingestionTokenResponse.Ingestionauthtoken

	refreshInterval, err = getTokenRefreshIntervalFromAmcsResponse(resp.Header)
	if err != nil {
		Log("getIngestionAuthToken: Error failed to parse max-age response header")
		return ingestionAuthToken, refreshInterval, err
	}
	Log("getIngestionAuthToken: refresh interval %d seconds", refreshInterval)

	Log("Info getIngestionAuthToken: end")
	return ingestionAuthToken, refreshInterval, nil
}

var cacheControlHeaderRegex = regexp.MustCompile(`max-age=([0-9]+)`)

func getTokenRefreshIntervalFromAmcsResponse(header http.Header) (refreshInterval int64, err error) {
	cacheControlHeader, valueInMap := header["Cache-Control"]
	if !valueInMap {
		return 0, errors.New("getTokenRefreshIntervalFromAmcsResponse: Cache-Control not in passed header")
	}

	for _, entry := range cacheControlHeader {
		match := cacheControlHeaderRegex.FindStringSubmatch(entry)
		if len(match) == 2 {
			interval := 0
			interval, err = strconv.Atoi(match[1])
			if err != nil {
				Log("getTokenRefreshIntervalFromAmcsResponse: error getting timeout from auth token. Header: " + strings.Join(cacheControlHeader, ","))
				return 0, err
			}
			refreshInterval = int64(interval)
			return refreshInterval, nil
		}
	}

	return 0, errors.New("getTokenRefreshIntervalFromAmcsResponse: didn't find max-age in response header")
}

func refreshIngestionAuthToken() {
	for ; true; <-IngestionAuthTokenRefreshTicker.C {
		if IMDSToken == "" || IMDSTokenExpiration <= (time.Now().Unix()+60*60) { // token valid 24 hrs and refresh token 1 hr before expiry
			imdsToken, imdsTokenExpiry, err := getAccessTokenFromIMDS()
			if err != nil {
				message := fmt.Sprintf("refreshIngestionAuthToken: Error on getAccessTokenFromIMDS  %s \n", err.Error())
				Log(message)
				SendException(message)
			} else {
				IMDSToken = imdsToken
				IMDSTokenExpiration = imdsTokenExpiry
			}
		}
		if IMDSToken == "" {
			message := "refreshIngestionAuthToken: IMDSToken is empty"
			Log(message)
			SendException(message)
			continue
		}
		var err error
		// ignore agent configuration expiring, the configuration and channel IDs will never change (without creating an agent restart)
		if ConfigurationId == "" || ChannelId == "" {
			ConfigurationId, ChannelId, err = getAgentConfiguration(IMDSToken)
			if err != nil {
				message := fmt.Sprintf("refreshIngestionAuthToken: Error getAgentConfiguration %s \n", err.Error())
				Log(message)
				SendException(message)
				continue
			}
		}
		if IMDSToken == "" || ConfigurationId == "" || ChannelId == "" {
			message := "refreshIngestionAuthToken: IMDSToken or ConfigurationId or ChannelId empty"
			Log(message)
			SendException(message)
			continue
		}
		ingestionAuthToken, refreshIntervalInSeconds, err := getIngestionAuthToken(IMDSToken, ConfigurationId, ChannelId)
		if err != nil {
			message := fmt.Sprintf("refreshIngestionAuthToken: Error getIngestionAuthToken %s \n", err.Error())
			Log(message)
			SendException(message)
			continue
		}
		IngestionAuthTokenUpdateMutex.Lock()
		ODSIngestionAuthToken = ingestionAuthToken
		IngestionAuthTokenUpdateMutex.Unlock()
		if refreshIntervalInSeconds > 0 && refreshIntervalInSeconds != defaultIngestionAuthTokenRefreshIntervalSeconds {
			//TODO - use Reset which is better when go version upgraded to 1.15 or up rather Stop() and NewTicker
			//IngestionAuthTokenRefreshTicker.Reset(time.Second * time.Duration(refreshIntervalInSeconds))
			IngestionAuthTokenRefreshTicker.Stop()
			IngestionAuthTokenRefreshTicker = time.NewTicker(time.Second * time.Duration(refreshIntervalInSeconds))
		}
	}
}

// true if httpStatusCode is retriable; otherwise, false.
func IsRetriableError(httpStatusCode int) bool {
	retryableStatusCodes := [6]int{408, 429, 500, 502, 503, 504}
	for _, code := range retryableStatusCodes {
		if code == httpStatusCode {
			return true
		}
	}
	return false
}

// true if httpStatusCode was in the range 200-299; otherwise, false.
func IsSuccessStatusCode(httpStatusCode int) bool {
	return (httpStatusCode >= 200 && httpStatusCode < 300)
}
