import { logger } from "./LoggerWrapper.js";
import * as k8s from "@kubernetes/client-node";
import forge from "node-forge";
import pem from "pem";

class WebhookCertData {
    caCert: string;
    tlsCert: string;
    tlsKey: string;
}

const hostname = process.env.HOSTNAME;

export class CertificateManager {

    private static makeNumberPositive = (hexString) => {
        let mostSignificativeHexDigitAsInt = parseInt(hexString[0], 16);
    
        if (mostSignificativeHexDigitAsInt < 8) return hexString;
    
        mostSignificativeHexDigitAsInt -= 8
        return mostSignificativeHexDigitAsInt.toString() + hexString.substring(1)
    }
    
    // Generate a random serial number for the Certificate
    private static randomSerialNumber = () => {
        return CertificateManager.makeNumberPositive(forge.util.bytesToHex(forge.random.getBytesSync(20)));
    }

    private static async GenerateSelfSignedCertificate(): Promise<WebhookCertData> {

        let caCert: forge.pki.Certificate = forge.pki.createCertificate();
        let keys = forge.pki.rsa.generateKeyPair(4096);
        caCert.serialNumber = CertificateManager.randomSerialNumber();
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
        },{
            name: 'subjectKeyIdentifier',
            keyIdentifier: caCert.generateSubjectKeyIdentifier().getBytes(),
        },{
            name: 'keyUsage',
            keyCertSign: true,
            cRLSign: true,
            digitalSignature: true,
            keyEncipherment: true,
        }];

        caCert.setExtensions(extensions);
        caCert.sign(caCert.privateKey,forge.md.sha256.create());

        const caCertResult: pem.CertificateCreationResult = {
            certificate: forge.pki.certificateToPem(caCert),
            serviceKey: forge.pki.privateKeyToPem(caCert.privateKey),
            csr: undefined,
            clientKey: undefined
            
        }

        // console.log(caCertResult.certificate);

        const host_attributes = [{
            shortName: 'CN',
            value: "app-monitoring-webhook-service.kube-system.svc"
        }];
    
        const host_extensions = [{
            name: 'basicConstraints',
            cA: false
        }, {
            name: 'authorityKeyIdentifier',
            keyIdentifier: caCert.generateSubjectKeyIdentifier().getBytes(),
        }, {
            name: 'keyUsage',
            digitalSignature: true,
            keyEncipherment: true
        }, {
            name: 'extKeyUsage',
            serverAuth: true
        }, {
            name: 'subjectAltName',
            altNames: [{ type: 2, value: "app-monitoring-webhook-service.kube-system.svc" }]
        }];

        let newHostCert = forge.pki.createCertificate();
        const hostKeys = forge.pki.rsa.generateKeyPair(4096);

        // Set the attributes for the new Host Certificate
        newHostCert.publicKey = hostKeys.publicKey;
        newHostCert.serialNumber = CertificateManager.randomSerialNumber();
        newHostCert.validity.notBefore = new Date(2023,6,20,0,0,0,0);
        newHostCert.validity.notAfter = new Date(2025,7,21,0,0,0,0);
        newHostCert.setSubject(host_attributes);
        newHostCert.setIssuer(caCert.subject.attributes);
        newHostCert.setExtensions(host_extensions);

        // Sign the new Host Certificate using the CA
        newHostCert.sign(caCert.privateKey, forge.md.sha256.create());

        // // Convert to PEM format
        let pemHostCert = forge.pki.certificateToPem(newHostCert);
        let pemHostKey = forge.pki.privateKeyToPem(hostKeys.privateKey);

        // console.log(pemHostCert);

        return {
            caCert: caCertResult.certificate,
            tlsCert: pemHostCert,
            tlsKey: pemHostKey
        } as WebhookCertData;
    }

    public static async CreateSecretStore(kubeConfig: k8s.KubeConfig, certificate: WebhookCertData) {

        const secretsApi = kubeConfig.makeApiClient(k8s.CoreV1Api);
        const secretStore: k8s.V1Secret = {
            apiVersion: "v1",
            kind: "Secret",
            metadata: {
                name: "app-monitoring-webhook-cert",
                namespace: "kube-system"
            },
            type: "Opaque",
            data: {
                "ca.cert": btoa(certificate.caCert),
                "tls.cert": btoa(certificate.tlsCert),
                "tls.key": btoa(certificate.tlsKey)
            }
        } 

        await secretsApi.createNamespacedSecret("kube-system", secretStore);
    }

    public static async CreateMutatingWebhook(kubeConfig: k8s.KubeConfig, certificate: WebhookCertData) {

        const webhookApi: k8s.AdmissionregistrationV1Api = kubeConfig.makeApiClient(k8s.AdmissionregistrationV1Api);
        const mutatingWebhook: k8s.V1MutatingWebhookConfiguration = {

            kind: "MutatingWebhookConfiguration",
            apiVersion: "admissionregistration.k8s.io/v1",
            metadata: {
                name: "app-monitoring-webhook",
                namespace: "kube-system",
                labels: {
                    "component": "ama-logs-appinsights"
                }
            },
            webhooks: [{
                name: "app-monitoring-webhook-service.kube-system.svc",
                clientConfig: {
                    service: {
                        name: "app-monitoring-webhook-service",
                        namespace: "kube-system",
                        path: "/"
                    },
                    caBundle: btoa(certificate.caCert)
                },
                rules: [{
                    operations: ["CREATE", "UPDATE"],
                    apiGroups: ["*"],
                    apiVersions: ["*"],
                    resources: ["pods"]
                }],
                admissionReviewVersions: ["v1"],
                sideEffects: "None",
                failurePolicy: "Fail"
            }]
        }
        await webhookApi.createMutatingWebhookConfiguration(mutatingWebhook);
    }

    public static async CreateWebhookAndCertificates() {

        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        const results = new Promise<void>(async resolve => {

            console.log("Creating certificates...");
            const certificates: WebhookCertData = await CertificateManager.GenerateSelfSignedCertificate();
            console.log("Certificates created successfully");
            
            console.log("Creating MutatingWebhookConfiguration...");
            await CertificateManager.CreateMutatingWebhook(kc, certificates);
            console.log("MutatingWebhookConfiguration created successfully");

            console.log("Creating Secret Store...");
            await CertificateManager.CreateSecretStore(kc, certificates);
            console.log("Secret Store created successfully");
            resolve();
        })

        await results.catch(error => {
            console.log(error);
        })
    }

    public static async DeleteWebhookAndCertificates() {

        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        const results = new Promise<void>(async resolve => {

            console.log("Deleting MutatingWebhookConfiguration...");
            const webhookApi: k8s.AdmissionregistrationV1Api = kc.makeApiClient(k8s.AdmissionregistrationV1Api);
            webhookApi.deleteMutatingWebhookConfiguration("app-monitoring-webhook");
            console.log("MutatingWebhookConfiguration Deleted...");

            console.log("Deleting Secret Store...");
            const secretsApi: k8s.CoreV1Api = kc.makeApiClient(k8s.CoreV1Api);
            secretsApi.deleteNamespacedSecret("app-monitoring-webhook-cert", "kube-system");
            console.log("Secret Store Deleted...");
            resolve();
        })

        await results.catch(error => {
            console.log(error);
        })
    }

}
