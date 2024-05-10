package lib

import (
	"io/ioutil"
	"os"
	"strings"
)

var proxyCertPath = "/etc/ama-logs-secret/PROXYCERT.crt"

func getProxyEndpoint() (string, error) {
	amaLogsProxySecretPath := "/etc/ama-logs-secret/PROXY"
	proxyConfig, err := ioutil.ReadFile(amaLogsProxySecretPath)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(proxyConfig)), nil
}

func isProxyCACertConfigured() bool {
	_, err := os.Stat(proxyCertPath)
	return err == nil
}

func isIgnoreProxySettings() bool {
	return strings.ToLower(os.Getenv("IGNORE_PROXY_SETTINGS")) == "true"
}
