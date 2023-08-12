import * as k8s from "@kubernetes/client-node";
import forge from "node-forge";
import { logger } from "./LoggerWrapper.js";

class CACertData {
    certificate: string;
    serviceKey: string;
}

class WebhookCertData {
    caCert: string;
    tlsCert: string;
    tlsKey: string;
}

export class CertificateManager {
    
    // Generate a random serial number for the Certificate
    private static randomHexSerialNumber = () => {
        return (1001).toString(16) + Math.ceil(Math.random()*100);
    }

    private static async GenerateSelfSignedCertificate(): Promise<WebhookCertData> {
        const caCert: forge.pki.Certificate = forge.pki.createCertificate();
        const keys = forge.pki.rsa.generateKeyPair(4096);
        caCert.serialNumber = CertificateManager.randomHexSerialNumber();
        caCert.publicKey = keys.publicKey;
        caCert.privateKey = keys.privateKey;
        caCert.validity.notBefore = new Date(2023,6,20,0,0,0,0);
        caCert.validity.notAfter = new Date(2025,7,21,0,0,0,0);

        const attributes = [{
            shortName: 'CN',
            value: 'applicationinsights-ca'
        }];
        caCert.setSubject(attributes);
        caCert.setIssuer(attributes);
    
        const extensions = [{
            name: 'basicConstraints',
            cA: true
        },
        {
            name: 'subjectKeyIdentifier',
            keyIdentifier: caCert.generateSubjectKeyIdentifier().getBytes(),
        },
        {
            name: 'keyUsage',
            keyCertSign: true,
            cRLSign: true,
            digitalSignature: true,
            keyEncipherment: true,
        }];

        caCert.setExtensions(extensions);
        caCert.sign(caCert.privateKey,forge.md.sha256.create());

        const caCertResult: CACertData = {
            certificate: forge.pki.certificateToPem(caCert),
            serviceKey: forge.pki.privateKeyToPem(caCert.privateKey)
        }

        const host_attributes = [{
            shortName: 'CN',
            value: "app-monitoring-webhook-service.kube-system.svc"
        }];
    
        const host_extensions = [{
            name: 'basicConstraints',
            cA: false
        }, 
        {
            name: 'authorityKeyIdentifier',
            keyIdentifier: caCert.generateSubjectKeyIdentifier().getBytes(),
        }, 
        {
            name: 'keyUsage',
            digitalSignature: true,
            keyEncipherment: true
        },
        {
            name: 'extKeyUsage',
            serverAuth: true
        }, 
        {
            name: 'subjectAltName',
            altNames: [{ type: 2, value: "app-monitoring-webhook-service.kube-system.svc" }]
        }];

        const newHostCert = forge.pki.createCertificate();
        const hostKeys = forge.pki.rsa.generateKeyPair(4096);

        // Set the attributes for the new Host Certificate
        newHostCert.publicKey = hostKeys.publicKey;
        newHostCert.serialNumber = CertificateManager.randomHexSerialNumber();
        newHostCert.validity.notBefore = new Date(2023,6,20,0,0,0,0);
        newHostCert.validity.notAfter = new Date(2025,7,21,0,0,0,0);
        newHostCert.setSubject(host_attributes);
        newHostCert.setIssuer(caCert.subject.attributes);
        newHostCert.setExtensions(host_extensions);

        // Sign the new Host Certificate using the CA
        newHostCert.sign(caCert.privateKey, forge.md.sha256.create());

        // // Convert to PEM format
        const pemHostCert = forge.pki.certificateToPem(newHostCert);
        const pemHostKey = forge.pki.privateKeyToPem(hostKeys.privateKey);

        return {
            caCert: caCertResult.certificate,
            tlsCert: pemHostCert,
            tlsKey: pemHostKey
        } as WebhookCertData;
    }

    public static async PatchSecretStore(kubeConfig: k8s.KubeConfig, certificate: WebhookCertData) {
        const secretsApi = kubeConfig.makeApiClient(k8s.CoreV1Api);
        const secretStore = await secretsApi.readNamespacedSecret("app-monitoring-webhook-cert", "kube-system");
        const secretsObj: k8s.V1Secret = secretStore.body;

        secretsObj.data["ca.cert"] = btoa(certificate.caCert);
        secretsObj.data["tls.cert"] = btoa(certificate.tlsCert);
        secretsObj.data["tls.key"] = btoa(certificate.tlsKey);

        await secretsApi.patchNamespacedSecret("app-monitoring-webhook-cert", "kube-system", secretsObj, undefined, undefined, undefined, undefined, undefined, {
            headers: { "Content-Type" : "application/strategic-merge-patch+json" }
        });
    }

    public static async PatchMutatingWebhook(kubeConfig: k8s.KubeConfig, certificate: WebhookCertData) {
        const webhookApi: k8s.AdmissionregistrationV1Api = kubeConfig.makeApiClient(k8s.AdmissionregistrationV1Api);
        const mutatingWebhook = await webhookApi.readMutatingWebhookConfiguration("app-monitoring-webhook");
        const mutatingWebhookObject: k8s.V1MutatingWebhookConfiguration = mutatingWebhook.body;
        mutatingWebhookObject.webhooks[0].clientConfig.caBundle = btoa(certificate.caCert);

        await webhookApi.patchMutatingWebhookConfiguration("app-monitoring-webhook", mutatingWebhookObject, undefined, undefined, undefined, undefined, undefined, {
            headers: { "Content-Type" : "application/strategic-merge-patch+json" }
        });
    }

    
    public static async CreateWebhookAndCertificates() {
        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        logger.info("Creating certificates...");
        const certificates: WebhookCertData = await CertificateManager.GenerateSelfSignedCertificate().catch(error => {
            logger.error("Self Signed CA Cert generation failed!");
            logger.error(error);
        }) as WebhookCertData;
        logger.info("Certificates created successfully");
        logger.info("Patching MutatingWebhookConfiguration...");

        await CertificateManager.PatchMutatingWebhook(kc, certificates).catch(error => {
            logger.error("Failed to patch MutatingWebhookConfiguration!");
            logger.error(error);
        });
        logger.info("MutatingWebhookConfiguration patched successfully");
        logger.info("Patching Secret Store...");

        await CertificateManager.PatchSecretStore(kc, certificates).catch(error => {
            logger.error("Failed to patch Secret Store!");
            logger.error(error);
        });
        logger.info("Secret Store patched successfully");
    }

}
