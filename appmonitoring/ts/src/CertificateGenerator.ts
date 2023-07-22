import { logger } from "./LoggerWrapper.js";
import * as k8s from "@kubernetes/client-node";
import forge from "node-forge";
import pem from "pem";


class CSRKeyPair {
    csr: string;
    key: string;
}

class WebhookCertData {
    caCert: string;
    tlsCert: string;
    tlsKey: string;
}

export class CertificateGenerator {

    private static async GenerateSelfSignedCertificate(): Promise<WebhookCertData> {

        let caCert: forge.pki.Certificate = forge.pki.createCertificate();
        let keys = forge.pki.rsa.generateKeyPair(4096);
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
        // cert1.setSubject([{name: "applicationinsights-ca" }])
        caCert.sign(caCert.privateKey,forge.md.sha512.create());
        // console.log(forge.pki.certificateToPem(cert1));


        // const caCertPromise: Promise<pem.CertificateCreationResult> = new Promise<pem.CertificateCreationResult>((resolve, reject) =>  {
        //     pem.createCertificate({
        //         // commonName: "applicationinsights-ca",
        //         extFile: "config_ssl1.cnf",
        //         days: 730,
        //         selfSigned: true,
        //     },(error, result) => {

        //         if (error){
        //             reject(error)
        //         }
        //         resolve(result);
        //     })
            
        // })

        const caCertResult: pem.CertificateCreationResult = {
            certificate: forge.pki.certificateToPem(caCert),
            serviceKey: forge.pki.privateKeyToPem(caCert.privateKey),
            csr: undefined,
            clientKey: undefined
            
        }



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
        newHostCert.validity.notBefore = new Date(2023,6,20,0,0,0,0);
        newHostCert.validity.notAfter = new Date(2025,7,21,0,0,0,0);
        newHostCert.setSubject(host_attributes);
        newHostCert.setIssuer(caCert.subject.attributes);
        newHostCert.setExtensions(host_extensions);

        // Sign the new Host Certificate using the CA
        newHostCert.sign(caCert.privateKey, forge.md.sha512.create());

        // // Convert to PEM format
        let pemHostCert = forge.pki.certificateToPem(newHostCert);
        let pemHostKey = forge.pki.privateKeyToPem(hostKeys.privateKey);

        console.log(pemHostCert);


        const serverCertResult: pem.CertificateCreationResult = {
            certificate: pemHostCert,
            clientKey: pemHostKey,
            csr: undefined,
            serviceKey: undefined
        };

        // const serverCertResult: pem.CertificateCreationResult = {
        //     certificate: undefined,
        //     clientKey: undefined,
        //     csr: undefined,
        //     serviceKey: undefined
        // };
        // console.log(caCertResult.certificate);

        // const csrPromise: Promise<CSRKeyPair> = new Promise<CSRKeyPair>((resolve, reject) =>  {
        //     pem.createCSR({
        //         clientKey: caCertResult.clientKey,
        //     },(error, result) => {
    
        //         const cSRKeyPair: CSRKeyPair = {
        //             csr: result.csr,
        //             key: result.clientKey
        //         }

        //         resolve(cSRKeyPair);
        //     })
        // })

        // const csrResult: CSRKeyPair = await csrPromise;
        // // console.log(csrResult.csr);

        // const serverCertPromise: Promise<pem.CertificateCreationResult> = new Promise<pem.CertificateCreationResult>((resolve, reject) =>  {
        //     pem.createCertificate({
        //         // csr: csrResult.csr,
        //         commonName: "app-monitoring-webhook-service.kube-system.svc",
        //         altNames: ["app-monitoring-webhook-service.kube-system.svc"],
        //         days: 730,
        //         serviceKey: caCertResult.serviceKey,
        //         serviceCertificate: caCertResult.certificate,
                
        //     },(error, result) => {

        //         resolve(result);
        //     })
        // })

        // const serverCertResult: pem.CertificateCreationResult = await serverCertPromise;
        // console.log(serverCertResult.certificate);


        return {
            caCert: caCertResult.certificate,
            tlsCert: serverCertResult.certificate,
            tlsKey: serverCertResult.clientKey
        } as WebhookCertData;
    }

    public static async PatchWebhookAndSecrets() {

        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        const certificate: WebhookCertData = await CertificateGenerator.GenerateSelfSignedCertificate()
        console.log("We be loading up!");
        
        // get secret
        const k8sSecretsApi = kc.makeApiClient(k8s.CoreV1Api);
        await k8sSecretsApi.readNamespacedSecret("app-monitoring-webhook-cert", "kube-system").then(async secretObj => {

            const secret: k8s.V1Secret = secretObj.body;
            secret.data["ca.cert"] = btoa(certificate.caCert);
            secret.data["tls.cert"] = btoa(certificate.tlsCert);
            secret.data["tls.key"] = btoa(certificate.tlsKey);
            
            console.log(secret);

            //patch secret
            await k8sSecretsApi.patchNamespacedSecret("app-monitoring-webhook-cert", "kube-system", secret, undefined, undefined, undefined, undefined, undefined, {
                headers: { "Content-Type" : "application/strategic-merge-patch+json" }
            });
        }).catch(rejected => {
            console.log(rejected)
        });

        console.log("Secrets successfully updated!");

        //get webhook configuration
        const k8sWebhookApi = kc.makeApiClient(k8s.AdmissionregistrationV1Api);
        k8sWebhookApi.readMutatingWebhookConfiguration("app-monitoring-webhook").then(async webhookConfigObj => {

            const webhookConfig: k8s.V1MutatingWebhookConfiguration = webhookConfigObj.body;
            webhookConfig.webhooks[0].clientConfig.caBundle = btoa(certificate.caCert);
            webhookConfig.webhooks[0].failurePolicy = "Fail";
            console.log(webhookConfig);

            await k8sWebhookApi.patchMutatingWebhookConfiguration("app-monitoring-webhook", webhookConfig, undefined, undefined, undefined, undefined, undefined, {
                headers: { "Content-Type" : "application/strategic-merge-patch+json" }
            });

        }).catch(rejected => {
            console.log(rejected);
        })
    
        
    }


}
