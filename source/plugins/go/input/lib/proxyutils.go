package lib

import (
	"io/ioutil"
	"os"
	"strings"
)

var proxyCertPath = "/etc/ama-logs-secret/PROXYCERT.crt"

func GetProxyEndpoint() (string, error) {
	amaLogsProxySecretPath := "/etc/ama-logs-secret/PROXY"
	proxyConfig, err := ioutil.ReadFile(amaLogsProxySecretPath)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(proxyConfig)), nil
}

func IsProxyCACertConfigured() bool {
	_, err := os.Stat(proxyCertPath)
	return err == nil
}

func IsIgnoreProxySettings() bool {
	return strings.ToLower(os.Getenv("IGNORE_PROXY_SETTINGS")) == "true"
}
