//All Values below are also defined in _omsagent.yaml in AKS RP and must always match the values there
export const WebhookDNSEndpoint = 'app-monitoring-webhook-service.kube-system.svc'; 
export const CertificateStoreName = 'app-monitoring-webhook-cert'; 
export const WebhookDeploymentName = 'app-monitoring-webhook';
export const MutatingWebhookConfigurationName = 'app-monitoring-webhook';
export const KubeSystemNamespaceName = 'kube-system';
export const CertificateInstallerJobName = "app-monitoring-secrets-installer";