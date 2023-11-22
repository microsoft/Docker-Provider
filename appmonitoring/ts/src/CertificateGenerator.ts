import * as k8s from '@kubernetes/client-node';
import { CertificateStoreName, NamespaceName, WebhookDNSEndpoint, WebhookName } from './Constants.js'
import forge from 'node-forge';
import { logger, RequestMetadata } from './LoggerWrapper.js';

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
    
    private static requestMetadata = new RequestMetadata(null, null);

    // Generate a random serial number for the Certificate
    private static randomHexSerialNumber() {
        return (1001).toString(16) + Math.ceil(Math.random()*100); //Just creates a placeholder hex and randomly increments it with a number between 1 and 100
    }

    private static async GenerateSelfSignedCertificate(operationId: string): Promise<WebhookCertData> {
        try {
            const caCert: forge.pki.Certificate = forge.pki.createCertificate();
            const keys = forge.pki.rsa.generateKeyPair(4096);
            caCert.serialNumber = CertificateManager.randomHexSerialNumber();
            caCert.publicKey = keys.publicKey;
            caCert.privateKey = keys.privateKey;
            const timeNowNum: number = Date.now()
            caCert.validity.notBefore = new Date(timeNowNum - (5 * 60 * 1000)); //5 Mins ago
            caCert.validity.notAfter = new Date(timeNowNum + (2 * 365 * 24 * 60 * 60 * 1000)); //2 Years from now

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
                value: WebhookDNSEndpoint
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
                altNames: [{ type: 2, value: WebhookDNSEndpoint }]
            }];

            const newHostCert = forge.pki.createCertificate();
            const hostKeys = forge.pki.rsa.generateKeyPair(4096);

            // Set the attributes for the new Host Certificate
            newHostCert.publicKey = hostKeys.publicKey;
            newHostCert.serialNumber = CertificateManager.randomHexSerialNumber();
            newHostCert.validity.notBefore = new Date(timeNowNum - (5 * 60 * 1000)); //5 Mins ago
            newHostCert.validity.notAfter = new Date(timeNowNum + (2 * 365 * 24 * 60 * 60 * 1000)); //2 Years from now
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
        } catch (error) {
            logger.error('Self Signed CA Cert generation failed!', operationId, this.requestMetadata);
            logger.error(JSON.stringify(error), operationId, this.requestMetadata);
            throw error;
        }
    }

    public static async PatchSecretStore(kubeConfig: k8s.KubeConfig, certificate: WebhookCertData, operationId: string) {
        try {
            const secretsApi = kubeConfig.makeApiClient(k8s.CoreV1Api);
            const secretStore = await secretsApi.readNamespacedSecret(CertificateStoreName, NamespaceName);
            const secretsObj: k8s.V1Secret = secretStore.body;

            secretsObj.data['ca.cert'] = btoa(certificate.caCert);
            secretsObj.data['tls.cert'] = btoa(certificate.tlsCert);
            secretsObj.data['tls.key'] = btoa(certificate.tlsKey);

            await secretsApi.patchNamespacedSecret(CertificateStoreName, NamespaceName, secretsObj, undefined, undefined, undefined, undefined, undefined, {
                headers: { 'Content-Type' : 'application/strategic-merge-patch+json' }
            });
        } catch (error) {
            logger.error('Failed to patch Secret Store!', operationId, this.requestMetadata);
            logger.error(JSON.stringify(error), operationId, this.requestMetadata);
            throw error;
        }
    }

    public static async PatchMutatingWebhook(kubeConfig: k8s.KubeConfig, certificate: WebhookCertData, operationId: string) {
        try {
            const webhookApi: k8s.AdmissionregistrationV1Api = kubeConfig.makeApiClient(k8s.AdmissionregistrationV1Api);
            const mutatingWebhook = await webhookApi.readMutatingWebhookConfiguration(WebhookName);
            const mutatingWebhookObject: k8s.V1MutatingWebhookConfiguration = mutatingWebhook.body;
            if (!mutatingWebhookObject 
                || !mutatingWebhookObject.webhooks 
                || mutatingWebhookObject.webhooks.length !== 1 || !mutatingWebhookObject.webhooks[0].clientConfig)
            {
                throw new Error("MutatingWebhookConfiguration not found or is malformed!");
            }
            mutatingWebhookObject.webhooks[0].clientConfig.caBundle = btoa(certificate.caCert);
    
            await webhookApi.patchMutatingWebhookConfiguration(WebhookName, mutatingWebhookObject, undefined, undefined, undefined, undefined, undefined, {
                headers: { 'Content-Type' : 'application/strategic-merge-patch+json' }
            });
        } catch (error) {
            logger.error('Failed to patch MutatingWebhookConfiguration!', operationId, this.requestMetadata);
            logger.error(JSON.stringify(error), operationId, this.requestMetadata);
            throw error;
        }
    }

    public static async CreateWebhookAndCertificates(operationId: string, clusterArmId: string, clusterArmRegion: string) {
        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        logger.info('Creating certificates...', operationId, this.requestMetadata);
        logger.SendEvent("CertificateCreating", operationId, null, clusterArmId, clusterArmRegion);
        const certificates: WebhookCertData = await CertificateManager.GenerateSelfSignedCertificate(operationId) as WebhookCertData;
        logger.info('Certificates created successfully', operationId, this.requestMetadata);
        logger.SendEvent("CertificateCreated", operationId, null, clusterArmId, clusterArmRegion);

        logger.info('Patching MutatingWebhookConfiguration...', operationId, this.requestMetadata);
        logger.SendEvent("CertificatePatchingMWHC", operationId, null, clusterArmId, clusterArmRegion);
        await CertificateManager.PatchMutatingWebhook(kc, certificates, operationId)
        logger.info('MutatingWebhookConfiguration patched successfully', operationId, this.requestMetadata);
        logger.SendEvent("CertificatePatchedMWHC", operationId, null, clusterArmId, clusterArmRegion);

        logger.info('Patching Secret Store...', operationId, this.requestMetadata);
        logger.SendEvent("CertificatePatchingSecretStore", operationId, null, clusterArmId, clusterArmRegion);
        await CertificateManager.PatchSecretStore(kc, certificates, operationId);
        logger.info('Secret Store patched successfully', operationId, this.requestMetadata);
        logger.SendEvent("CertificatePatchedSecretStore", operationId, null, clusterArmId, clusterArmRegion);
    }

}
