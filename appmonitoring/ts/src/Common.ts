//All Values below are also defined in _omsagent.yaml in AKS RP and must always match the values there
export const WebhookDNSEndpoint = 'app-monitoring-webhook-service.kube-system.svc'; 
export const CertificateStoreName = 'app-monitoring-webhook-cert'; 
export const WebhookDeploymentName = 'app-monitoring-webhook';
export const MutatingWebhookConfigurationName = 'app-monitoring-webhook';
export const KubeSystemNamespaceName = 'kube-system';
export const CertificateInstallerJobName = "app-monitoring-secrets-installer";

// parses "key1=value1,key2=value2=extra" into { key1: "value1", key2: "value2=extra" }
export function parseOtelAttributes(attributesString: string): Record<string, string> {
    const attributes: Record<string, string> = {};
    
    if (!attributesString) {
        return attributes;
    }

    const pairs = attributesString.split(',');
    for (const pair of pairs) {
        const trimmedPair = pair.trim();
        const equalIndex = trimmedPair.indexOf('=');
        
        if (equalIndex > 0) {
            const key = trimmedPair.substring(0, equalIndex);
            const value = trimmedPair.substring(equalIndex + 1);
            attributes[key] = value;
        }
    }
    
    return attributes;
}