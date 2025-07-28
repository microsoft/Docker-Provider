package tomlparser_prom_customconfig

import (
	"fmt"
	"strings"
)

// processReplicaSetTemplate processes the ReplicaSet Telegraf configuration template
func (p *Parser) processReplicaSetTemplate(fileName, interval string, fieldPass, fieldDrop, urls, kubernetesServices []string,
	monitorKubernetesPods bool, monitorKubernetesPodsNamespaces []string, kubernetesLabelSelectors, kubernetesFieldSelectors string) error {

	fmt.Println("config::Starting to substitute the placeholders in telegraf conf copy file for replicaset")

	// Read the template file
	content, err := p.ReadFile(fileName)
	if err != nil {
		return fmt.Errorf("failed to read template file: %w", err)
	}

	// Replace placeholders with actual values
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_INTERVAL", interval)

	fieldPassSetting := p.FormatStringArray(fieldPass)
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_FIELDPASS", fieldPassSetting)

	fieldDropSetting := p.FormatStringArray(fieldDrop)
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_FIELDDROP", fieldDropSetting)

	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_URLS", p.FormatStringArray(urls))
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_K8S_SERVICES", p.FormatStringArray(kubernetesServices))

	// Handle namespace filtering (legacy feature to be removed after phased rollout)
	if p.config.SidecarScrapingEnabled == "" || strings.ToLower(strings.TrimSpace(p.config.SidecarScrapingEnabled)) == "false" {
		monitorKubernetesPodsNSConfig := []string{}
		if monitorKubernetesPods && monitorKubernetesPodsNamespaces != nil && len(monitorKubernetesPodsNamespaces) > 0 {
			content = p.CreatePrometheusPluginsWithNamespaceSetting(monitorKubernetesPods, monitorKubernetesPodsNamespaces, content, interval, fieldPassSetting, fieldDropSetting, kubernetesLabelSelectors, kubernetesFieldSelectors)
			monitorKubernetesPodsNSConfig = monitorKubernetesPodsNamespaces
		} else {
			content = p.ReplaceDefaultMonitorPodSettings(content, monitorKubernetesPods, kubernetesLabelSelectors, kubernetesFieldSelectors)
		}

		// Calculate selector lengths for telemetry
		kubernetesLabelSelectorsLength := p.CountSelectorPairs(kubernetesLabelSelectors, "label")
		kubernetesFieldSelectorsLength := p.CountSelectorPairs(kubernetesFieldSelectors, "field")

		// Update telemetry config
		p.telemetryConfig.RSPromMonitorPods = monitorKubernetesPods
		p.telemetryConfig.RSPromMonitorPodsNSLength = len(monitorKubernetesPodsNSConfig)
		p.telemetryConfig.RSPromLabelSelectorLength = kubernetesLabelSelectorsLength
		p.telemetryConfig.RSPromFieldSelectorLength = kubernetesFieldSelectorsLength
	}

	// Write the modified content back to file
	err = p.WriteFile(fileName, content)
	if err != nil {
		return fmt.Errorf("failed to write template file: %w", err)
	}

	fmt.Println("config::Successfully substituted the placeholders in telegraf conf file for replicaset")

	// Update telemetry config
	p.telemetryConfig.RStelegrafDisabled = p.disableRSTelegraf
	p.telemetryConfig.RSPromInterval = interval
	p.telemetryConfig.RSPromFieldPassLength = len(fieldPass)
	p.telemetryConfig.RSPromFieldDropLength = len(fieldDrop)
	p.telemetryConfig.RSPromK8sServicesLength = len(kubernetesServices)
	p.telemetryConfig.RSPromURLsLength = len(urls)

	// Generate telemetry environment file
	return p.generateReplicaSetTelemetryFile()
}

// processSidecarTemplate processes the Prometheus sidecar Telegraf configuration template
func (p *Parser) processSidecarTemplate(fileName, interval string, fieldPass, fieldDrop []string, monitorKubernetesPods bool,
	monitorKubernetesPodsNamespaces []string, kubernetesLabelSelectors, kubernetesFieldSelectors string) error {

	fmt.Println("config::Starting to substitute the placeholders in telegraf conf copy file for linux or conf file for windows for custom prometheus scraping")

	// Read the template file
	content, err := p.ReadFile(fileName)
	if err != nil {
		return fmt.Errorf("failed to read template file: %w", err)
	}

	// Replace placeholders with actual values
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_INTERVAL", interval)

	fieldPassSetting := p.FormatStringArray(fieldPass)
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_FIELDPASS", fieldPassSetting)

	fieldDropSetting := p.FormatStringArray(fieldDrop)
	content = strings.ReplaceAll(content, "$AZMON_TELEGRAF_CUSTOM_PROM_FIELDDROP", fieldDropSetting)

	// Handle namespace filtering
	monitorKubernetesPodsNSConfig := []string{}
	if monitorKubernetesPods && monitorKubernetesPodsNamespaces != nil && len(monitorKubernetesPodsNamespaces) > 0 {
		content = p.CreatePrometheusPluginsWithNamespaceSetting(monitorKubernetesPods, monitorKubernetesPodsNamespaces, content, interval, fieldPassSetting, fieldDropSetting, kubernetesLabelSelectors, kubernetesFieldSelectors)
		monitorKubernetesPodsNSConfig = monitorKubernetesPodsNamespaces
	} else {
		content = p.ReplaceDefaultMonitorPodSettings(content, monitorKubernetesPods, kubernetesLabelSelectors, kubernetesFieldSelectors)
	}

	// Calculate selector lengths for telemetry
	kubernetesLabelSelectorsLength := p.CountSelectorPairs(kubernetesLabelSelectors, "label")
	kubernetesFieldSelectorsLength := p.CountSelectorPairs(kubernetesFieldSelectors, "field")

	// Write the modified content back to file
	err = p.WriteFile(fileName, content)
	if err != nil {
		return fmt.Errorf("failed to write template file: %w", err)
	}

	fmt.Println("config::Successfully substituted the placeholders in telegraf conf file for custom prometheus scraping")

	// Update telemetry config
	p.telemetryConfig.CustomPromMonitorPods = monitorKubernetesPods
	p.telemetryConfig.CustomPromMonitorPodsNSLength = len(monitorKubernetesPodsNSConfig)
	p.telemetryConfig.CustomPromLabelSelectorLength = kubernetesLabelSelectorsLength
	p.telemetryConfig.CustomPromFieldSelectorLength = kubernetesFieldSelectorsLength

	// Generate environment files based on container type
	if p.config.ContainerType != "" && strings.ToLower(p.config.ContainerType) == p.config.PromSideCar {
		return p.generateSidecarTelemetryFile()
	} else if p.IsWindows() {
		return p.generateWindowsTelemetryFile(monitorKubernetesPods)
	}

	return nil
}

// processDaemonSetTemplate processes the DaemonSet Telegraf configuration template
func (p *Parser) processDaemonSetTemplate(fileName, interval string, fieldPass, fieldDrop, urls []string) error {
	fmt.Println("config::Starting to substitute the placeholders in telegraf conf copy file for daemonset")

	// Read the template file
	content, err := p.ReadFile(fileName)
	if err != nil {
		return fmt.Errorf("failed to read template file: %w", err)
	}

	// Replace placeholders with actual values
	content = strings.ReplaceAll(content, "$AZMON_DS_PROM_INTERVAL", interval)
	content = strings.ReplaceAll(content, "$AZMON_DS_PROM_FIELDPASS", p.FormatStringArray(fieldPass))
	content = strings.ReplaceAll(content, "$AZMON_DS_PROM_FIELDDROP", p.FormatStringArray(fieldDrop))
	content = strings.ReplaceAll(content, "$AZMON_DS_PROM_URLS", p.FormatStringArray(urls))

	// Write the modified content back to file
	err = p.WriteFile(fileName, content)
	if err != nil {
		return fmt.Errorf("failed to write template file: %w", err)
	}

	fmt.Println("config::Successfully substituted the placeholders in telegraf conf file for daemonset")

	// Update telemetry config
	p.telemetryConfig.DSPromInterval = interval
	p.telemetryConfig.DSPromFieldPassLength = len(fieldPass)
	p.telemetryConfig.DSPromFieldDropLength = len(fieldDrop)
	p.telemetryConfig.DSPromURLsLength = len(urls)

	// Generate telemetry environment file
	return p.generateDaemonSetTelemetryFile()
}

// generateReplicaSetTelemetryFile generates telemetry environment file for ReplicaSet
func (p *Parser) generateReplicaSetTelemetryFile() error {
	content := fmt.Sprintf(`export TELEMETRY_RS_TELEGRAF_DISABLED="%t"
export TELEMETRY_RS_PROM_INTERVAL="%s"
export TELEMETRY_RS_PROM_FIELDPASS_LENGTH="%d"
export TELEMETRY_RS_PROM_FIELDDROP_LENGTH="%d"
export TELEMETRY_RS_PROM_K8S_SERVICES_LENGTH=%d
export TELEMETRY_RS_PROM_URLS_LENGTH=%d
`,
		p.telemetryConfig.RStelegrafDisabled,
		p.telemetryConfig.RSPromInterval,
		p.telemetryConfig.RSPromFieldPassLength,
		p.telemetryConfig.RSPromFieldDropLength,
		p.telemetryConfig.RSPromK8sServicesLength,
		p.telemetryConfig.RSPromURLsLength)

	// Add legacy telemetry if sidecar scraping is disabled
	if p.config.SidecarScrapingEnabled == "" || strings.ToLower(strings.TrimSpace(p.config.SidecarScrapingEnabled)) == "false" {
		content += fmt.Sprintf(`export TELEMETRY_RS_PROM_MONITOR_PODS="%t"
export TELEMETRY_RS_PROM_MONITOR_PODS_NS_LENGTH="%d"
export TELEMETRY_RS_PROM_LABEL_SELECTOR_LENGTH="%d"
export TELEMETRY_RS_PROM_FIELD_SELECTOR_LENGTH="%d"
`,
			p.telemetryConfig.RSPromMonitorPods,
			p.telemetryConfig.RSPromMonitorPodsNSLength,
			p.telemetryConfig.RSPromLabelSelectorLength,
			p.telemetryConfig.RSPromFieldSelectorLength)
	}

	err := p.WriteFile("telemetry_prom_config_env_var", content)
	if err != nil {
		return fmt.Errorf("failed to write telemetry file: %w", err)
	}

	fmt.Println("config::Successfully created telemetry file for replicaset")
	return nil
}

// generateSidecarTelemetryFile generates telemetry environment file for Prometheus sidecar
func (p *Parser) generateSidecarTelemetryFile() error {
	content := fmt.Sprintf(`export TELEMETRY_CUSTOM_PROM_MONITOR_PODS="%t"
export TELEMETRY_CUSTOM_PROM_MONITOR_PODS_NS_LENGTH="%d"
export TELEMETRY_CUSTOM_PROM_LABEL_SELECTOR_LENGTH="%d"
export TELEMETRY_CUSTOM_PROM_FIELD_SELECTOR_LENGTH="%d"
`,
		p.telemetryConfig.CustomPromMonitorPods,
		p.telemetryConfig.CustomPromMonitorPodsNSLength,
		p.telemetryConfig.CustomPromLabelSelectorLength,
		p.telemetryConfig.CustomPromFieldSelectorLength)

	err := p.WriteFile("telemetry_prom_config_env_var", content)
	if err != nil {
		return fmt.Errorf("failed to write telemetry file: %w", err)
	}

	fmt.Println("config::Successfully created telemetry file for prometheus sidecar")
	return nil
}

// generateWindowsTelemetryFile generates environment file for Windows
func (p *Parser) generateWindowsTelemetryFile(monitorKubernetesPods bool) error {
	content := p.GetCommandWindows("TELEMETRY_CUSTOM_PROM_MONITOR_PODS", fmt.Sprintf("%t", monitorKubernetesPods))

	err := p.WriteFile("setpromenv.txt", content)
	if err != nil {
		return fmt.Errorf("failed to write Windows environment file: %w", err)
	}

	return nil
}

// generateDaemonSetTelemetryFile generates telemetry environment file for DaemonSet
func (p *Parser) generateDaemonSetTelemetryFile() error {
	content := fmt.Sprintf(`export TELEMETRY_DS_PROM_INTERVAL="%s"
export TELEMETRY_DS_PROM_FIELDPASS_LENGTH="%d"
export TELEMETRY_DS_PROM_FIELDDROP_LENGTH="%d"
export TELEMETRY_DS_PROM_URLS_LENGTH=%d
`,
		p.telemetryConfig.DSPromInterval,
		p.telemetryConfig.DSPromFieldPassLength,
		p.telemetryConfig.DSPromFieldDropLength,
		p.telemetryConfig.DSPromURLsLength)

	err := p.WriteFile("telemetry_prom_config_env_var", content)
	if err != nil {
		return fmt.Errorf("failed to write telemetry file: %w", err)
	}

	fmt.Println("config::Successfully created telemetry file for daemonset")
	return nil
}
