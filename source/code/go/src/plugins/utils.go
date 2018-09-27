package main

import (
	"bufio"
	"crypto/tls"
	"log"
	"net/http"
	"os"
	"strings"
)

// ReadConfiguration reads a property file
func ReadConfiguration(filename string) (map[string]string, error) {
	config := map[string]string{}

	if len(filename) == 0 {
		return config, nil
	}

	file, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
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
		log.Fatal(err)
		return nil, err
	}

	return config, nil
}

// CreateHTTPClient used to create the client for sending post requests to OMSEndpoint
func CreateHTTPClient() {

	cert, err := tls.LoadX509KeyPair(PluginConfiguration["cert_file_path"], PluginConfiguration["key_file_path"])
	if err != nil {
		Log("Error when loading cert %s", err.Error())
		log.Fatalf("Error when loading cert %s", err.Error())
	}

	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{cert},
	}

	tlsConfig.BuildNameToCertificate()
	transport := &http.Transport{TLSClientConfig: tlsConfig}

	HTTPClient = http.Client{Transport: transport}

	Log("Successfully created HTTP Client")
}
