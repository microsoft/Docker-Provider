package main

import (
	"bufio"
	"crypto/tls"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/Azure/azure-kusto-go/kusto"
	"github.com/Azure/azure-kusto-go/kusto/ingest"
	"github.com/Azure/go-autorest/autorest/azure/auth"
)

// ReadConfiguration reads a property file
func ReadConfiguration(filename string) (map[string]string, error) {
	config := map[string]string{}

	if len(filename) == 0 {
		return config, nil
	}

	file, err := os.Open(filename)
	if err != nil {
		SendException(err)
		time.Sleep(30 * time.Second)
		fmt.Printf("%s", err.Error())
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		currentLine := scanner.Text()
		if equalIndex := strings.Index(currentLine, "="); equalIndex >= 0 {
			if key := strings.TrimSpace(currentLine[:equalIndex]); len(key) > 0 {
				value := ""
				if len(currentLine) > equalIndex {
					value = strings.TrimSpace(currentLine[equalIndex+1:])
				}
				config[key] = value
			}
		}
	}

	if err := scanner.Err(); err != nil {
		SendException(err)
		time.Sleep(30 * time.Second)
		log.Fatalf("%s", err.Error())
		return nil, err
	}

	return config, nil
}

// CreateHTTPClient used to create the client for sending post requests to OMSEndpoint
func CreateHTTPClient() {
	cert, err := tls.LoadX509KeyPair(PluginConfiguration["cert_file_path"], PluginConfiguration["key_file_path"])
	if err != nil {
		message := fmt.Sprintf("Error when loading cert %s", err.Error())
		SendException(message)
		time.Sleep(30 * time.Second)
		Log(message)
		log.Fatalf("Error when loading cert %s", err.Error())
	}

	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{cert},
	}

	tlsConfig.BuildNameToCertificate()
	transport := &http.Transport{TLSClientConfig: tlsConfig}
	// set the proxy if the proxy configured
	if ProxyEndpoint != "" {
		proxyEndpointUrl, err := url.Parse(ProxyEndpoint)
		if err != nil {
			message := fmt.Sprintf("Error parsing Proxy endpoint %s", err.Error())
			SendException(message)
			// if we fail to read proxy secret, AI telemetry might not be working as well
			Log(message)
		} else {
			transport.Proxy = http.ProxyURL(proxyEndpointUrl)
		}
	}

	HTTPClient = http.Client{
		Transport: transport,
		Timeout:   30 * time.Second,
	}

	Log("Successfully created HTTP Client")
}

// ToString converts an interface into a string
func ToString(s interface{}) string {
	switch t := s.(type) {
	case []byte:
		// prevent encoding to base64
		return string(t)
	default:
		return ""
	}
}

//mdsdSocketClient to write msgp messages
func CreateMDSDClient() {
	if MdsdMsgpUnixSocketClient != nil {
		MdsdMsgpUnixSocketClient.Close()
		MdsdMsgpUnixSocketClient = nil
	}
	/*conn, err := fluent.New(fluent.Config{FluentNetwork:"unix",
	  FluentSocketPath:"/var/run/mdsd/default_fluent.socket",
	  WriteTimeout: 5 * time.Second,
	  RequestAck: true}) */
	conn, err := net.DialTimeout("unix",
		"/var/run/mdsd/default_fluent.socket", 10*time.Second)
	if err != nil {
		Log("Error::mdsd::Unable to open MDSD msgp socket connection %s", err.Error())
		//log.Fatalf("Unable to open MDSD msgp socket connection %s", err.Error())
	} else {
		Log("Successfully created MDSD msgp socket connection")
		MdsdMsgpUnixSocketClient = conn
	}
}

//ADX client to write to ADX
func CreateADXClient() {

	if ADXIngestor != nil {
		ADXIngestor = nil
	}

	authConfig := auth.NewClientCredentialsConfig(AdxClientID, AdxClientSecret, AdxTenantID)

	client, err := kusto.New(AdxClusterUri, kusto.Authorization{Config: authConfig})
	if err != nil {
		Log("Error::mdsd::Unable to create ADX client %s", err.Error())
		//log.Fatalf("Unable to create ADX connection %s", err.Error())
	} else {
		Log("Successfully created ADX Client. Creating Ingestor...")
		ingestor, ingestorErr := ingest.New(client, "containerinsights", "ContainerLogV2")
		if ingestorErr != nil {
			Log("Error::mdsd::Unable to create ADX ingestor %s", ingestorErr.Error())
		} else {
			ADXIngestor = ingestor
		}
	}
}

func ReadFileContents(fullPathToFileName string) (string, error) {
	fullPathToFileName = strings.TrimSpace(fullPathToFileName)
	if len(fullPathToFileName) == 0 {
		return "", errors.New("ReadFileContents::filename is empty")
	}
	content, err := ioutil.ReadFile(fullPathToFileName) //no need to close
	if err != nil {
		return "", errors.New("ReadFileContents::Unable to open file " + fullPathToFileName)
	} else {
		return strings.TrimSpace(string(content)), nil
	}
}

func isValidUrl(uri string) bool {
	uri = strings.TrimSpace(uri)
	if len(uri) == 0 {
		return false
	}
	u, err := url.Parse(uri)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return false
	}
	return true
}
