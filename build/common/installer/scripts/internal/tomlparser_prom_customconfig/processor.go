package tomlparser_prom_customconfig

import (
	"fmt"
	"os"
	"strings"

	"dockerprovider-installer-scripts/pkg/types"
)

// ProcessConfiguration processes the Prometheus configuration based on controller type
func (p *Parser) ProcessConfiguration(config *types.PrometheusDataCollectionSettings) error {
	if p.config.ControllerType == "" {
		p.logger.LogError("Controller undefined while processing prometheus config, using defaults")
		return fmt.Errorf("controller type not defined")
	}

	if config == nil || config.PrometheusDataCollectionSettings == nil {
		fmt.Println("config::No configmap mounted for prometheus custom config, using defaults")
		return nil
	}

	prometheusConfig := config.PrometheusDataCollectionSettings

	// Check controller type and process accordingly
	controllerLower := strings.ToLower(p.config.ControllerType)

	if controllerLower == p.config.ReplicaSet && prometheusConfig.Cluster != nil {
		return p.processReplicaSetConfig(prometheusConfig.Cluster)
	} else if controllerLower == p.config.DaemonSet && p.isPrometheusSidecarOrWindowsWithSidecar() && prometheusConfig.Cluster != nil {
		return p.processPrometheusSidecarConfig(prometheusConfig.Cluster)
	} else if controllerLower == p.config.DaemonSet && prometheusConfig.Node != nil {
		return p.processDaemonSetConfig(prometheusConfig.Node)
	}

	return nil
}

// isPrometheusSidecarOrWindowsWithSidecar checks if this is a Prometheus sidecar or Windows with sidecar enabled
func (p *Parser) isPrometheusSidecarOrWindowsWithSidecar() bool {
	return (p.config.ContainerType != "" && strings.ToLower(p.config.ContainerType) == p.config.PromSideCar) ||
		(p.IsWindows() && p.config.SidecarScrapingEnabled != "" && strings.ToLower(strings.TrimSpace(p.config.SidecarScrapingEnabled)) == "true")
}

// processReplicaSetConfig processes ReplicaSet Prometheus configuration
func (p *Parser) processReplicaSetConfig(clusterConfig *types.ClusterPrometheusConfig) error {
	fmt.Println("config::Processing ReplicaSet Prometheus configuration")

	// Extract configuration values
	interval := p.getStringValue(clusterConfig.Interval, p.config.DefaultRsInterval)
	fieldPass := clusterConfig.FieldPass
	if fieldPass == nil {
		fieldPass = p.config.DefaultRsFieldPass
	}
	fieldDrop := clusterConfig.FieldDrop
	if fieldDrop == nil {
		fieldDrop = p.config.DefaultRsFieldDrop
	}
	urls := clusterConfig.URLs
	if urls == nil {
		urls = p.config.DefaultRsPromUrls
	}
	kubernetesServices := clusterConfig.KubernetesServices
	if kubernetesServices == nil {
		kubernetesServices = p.config.DefaultRsK8sServices
	}

	// Check if RS telegraf should be disabled
	if fieldPass == nil && fieldDrop == nil && urls == nil && kubernetesServices == nil {
		p.disableRSTelegraf = true
	}

	// Legacy settings (will be removed after phased rollout)
	monitorKubernetesPods := p.getBoolValue(clusterConfig.MonitorKubernetesPods, false)
	monitorKubernetesPodsNamespaces := clusterConfig.MonitorKubernetesPodsNamespaces
	kubernetesLabelSelectors := p.getStringValue(clusterConfig.KubernetesLabelSelector, p.config.DefaultCustomPrometheusLabelSelectors)
	kubernetesFieldSelectors := p.getStringValue(clusterConfig.KubernetesFieldSelector, p.config.DefaultCustomPrometheusFieldSelectors)

	// Validate types
	if !p.validateReplicaSetTypes(interval, fieldPass, fieldDrop, kubernetesServices, urls, kubernetesLabelSelectors, kubernetesFieldSelectors, monitorKubernetesPods) {
		p.logger.LogError("Typecheck failed for prometheus config settings for replicaset, using defaults, please use right types for all settings")
		return fmt.Errorf("type validation failed")
	}

	fmt.Println("config::Successfully passed typecheck for config settings for replicaset")

	// Process template
	fileName := "/opt/telegraf-test-rs.conf"
	err := p.CopyFile("/etc/opt/microsoft/docker-cimprov/telegraf-rs.conf", fileName)
	if err != nil {
		return fmt.Errorf("failed to copy telegraf config: %w", err)
	}

	return p.processReplicaSetTemplate(fileName, interval, fieldPass, fieldDrop, urls, kubernetesServices,
		monitorKubernetesPods, monitorKubernetesPodsNamespaces, kubernetesLabelSelectors, kubernetesFieldSelectors)
}

// processPrometheusSidecarConfig processes Prometheus sidecar configuration
func (p *Parser) processPrometheusSidecarConfig(clusterConfig *types.ClusterPrometheusConfig) error {
	fmt.Println("config::Processing Prometheus Sidecar configuration")

	// Extract configuration values
	interval := p.getStringValue(clusterConfig.Interval, p.config.DefaultCustomPrometheusInterval)
	fieldPass := clusterConfig.FieldPass
	if fieldPass == nil {
		fieldPass = p.config.DefaultCustomPrometheusFieldPass
	}
	fieldDrop := clusterConfig.FieldDrop
	if fieldDrop == nil {
		fieldDrop = p.config.DefaultCustomPrometheusFieldDrop
	}
	monitorKubernetesPods := p.getBoolValue(clusterConfig.MonitorKubernetesPods, p.config.DefaultCustomPrometheusMonitorPods)
	monitorKubernetesPodsNamespaces := clusterConfig.MonitorKubernetesPodsNamespaces
	kubernetesLabelSelectors := p.getStringValue(clusterConfig.KubernetesLabelSelector, p.config.DefaultCustomPrometheusLabelSelectors)
	kubernetesFieldSelectors := p.getStringValue(clusterConfig.KubernetesFieldSelector, p.config.DefaultCustomPrometheusFieldSelectors)

	// Validate types
	if !p.validateSidecarTypes(interval, kubernetesLabelSelectors, kubernetesFieldSelectors, fieldPass, fieldDrop, monitorKubernetesPods) {
		p.logger.LogError("Typecheck failed for prometheus config settings for prometheus side car, using defaults, please use right types for all settings")
		return fmt.Errorf("type validation failed")
	}

	fmt.Println("config::Successfully passed typecheck for config settings for custom prometheus scraping")

	// Determine file name based on OS
	var fileName string
	if p.IsWindows() {
		fileName = "/etc/telegraf/telegraf.conf"
	} else {
		fileName = "/opt/telegraf-test-prom-side-car.conf"
		err := p.CopyFile("/etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf", fileName)
		if err != nil {
			return fmt.Errorf("failed to copy telegraf config: %w", err)
		}
	}

	return p.processSidecarTemplate(fileName, interval, fieldPass, fieldDrop, monitorKubernetesPods,
		monitorKubernetesPodsNamespaces, kubernetesLabelSelectors, kubernetesFieldSelectors)
}

// processDaemonSetConfig processes DaemonSet Prometheus configuration
func (p *Parser) processDaemonSetConfig(nodeConfig *types.NodePrometheusConfig) error {
	fmt.Println("config::Processing DaemonSet Prometheus configuration")

	// Extract configuration values
	interval := p.getStringValue(nodeConfig.Interval, p.config.DefaultDsInterval)
	fieldPass := nodeConfig.FieldPass
	if fieldPass == nil {
		fieldPass = p.config.DefaultDsFieldPass
	}
	fieldDrop := nodeConfig.FieldDrop
	if fieldDrop == nil {
		fieldDrop = p.config.DefaultDsFieldDrop
	}
	urls := nodeConfig.URLs
	if urls == nil {
		urls = p.config.DefaultDsPromUrls
	}

	// Validate types
	if !p.validateDaemonSetTypes(interval, fieldPass, fieldDrop, urls) {
		p.logger.LogError("Typecheck failed for prometheus config settings for daemonset, using defaults, please use right types for all settings")
		return fmt.Errorf("type validation failed")
	}

	fmt.Println("config::Successfully passed typecheck for config settings for daemonset")

	// Process template
	fileName := "/opt/telegraf-test.conf"
	err := p.CopyFile("/etc/opt/microsoft/docker-cimprov/telegraf.conf", fileName)
	if err != nil {
		return fmt.Errorf("failed to copy telegraf config: %w", err)
	}

	return p.processDaemonSetTemplate(fileName, interval, fieldPass, fieldDrop, urls)
}

// Helper methods for type validation
func (p *Parser) validateReplicaSetTypes(interval string, fieldPass, fieldDrop, kubernetesServices, urls []string, kubernetesLabelSelectors, kubernetesFieldSelectors string, monitorKubernetesPods bool) bool {
	return p.CheckForType(interval, "string") &&
		p.CheckForTypeArray(fieldPass, "string") &&
		p.CheckForTypeArray(fieldDrop, "string") &&
		p.CheckForTypeArray(kubernetesServices, "string") &&
		p.CheckForTypeArray(urls, "string") &&
		p.CheckForType(kubernetesLabelSelectors, "string") &&
		p.CheckForType(kubernetesFieldSelectors, "string") &&
		p.CheckForType(monitorKubernetesPods, "bool")
}

func (p *Parser) validateSidecarTypes(interval, kubernetesLabelSelectors, kubernetesFieldSelectors string, fieldPass, fieldDrop []string, monitorKubernetesPods bool) bool {
	return p.CheckForType(interval, "string") &&
		p.CheckForType(kubernetesLabelSelectors, "string") &&
		p.CheckForType(kubernetesFieldSelectors, "string") &&
		p.CheckForTypeArray(fieldPass, "string") &&
		p.CheckForTypeArray(fieldDrop, "string") &&
		p.CheckForType(monitorKubernetesPods, "bool")
}

func (p *Parser) validateDaemonSetTypes(interval string, fieldPass, fieldDrop, urls []string) bool {
	return p.CheckForType(interval, "string") &&
		p.CheckForTypeArray(fieldPass, "string") &&
		p.CheckForTypeArray(fieldDrop, "string") &&
		p.CheckForTypeArray(urls, "string")
}

// Helper methods for value extraction
func (p *Parser) getStringValue(ptr *string, defaultValue string) string {
	if ptr != nil {
		return *ptr
	}
	return defaultValue
}

func (p *Parser) getBoolValue(ptr *bool, defaultValue bool) bool {
	if ptr != nil {
		return *ptr
	}
	return defaultValue
}

// CheckSchemaVersion validates the configuration schema version
func (p *Parser) CheckSchemaVersion() bool {
	configSchemaVersion := os.Getenv("AZMON_AGENT_CFG_SCHEMA_VERSION")
	return configSchemaVersion != "" && strings.ToLower(strings.TrimSpace(configSchemaVersion)) == "v1"
}
