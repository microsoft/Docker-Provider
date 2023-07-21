import { logger } from "./LoggerWrapper.js";
import * as k8s from "@kubernetes/client-node";
import { error } from "console";
import pem from "pem"


class CSRKeyPair {
    csr: string;
    key: string;
}

class WebhookCertificateData {
    ServerCertificate: string;
    ServerPrivateKey: string;
    CaCertificate: string;
}

export class CertificateGenerator {

    public static async GenerateSelfSignedCertificate(): Promise<WebhookCertificateData> {

        let csrPromise: Promise<CSRKeyPair> = new Promise<CSRKeyPair>((resolve, reject) =>  {
            pem.createCSR({
                commonName: 'applicationinsights-ca'
            },(error, result) => {
    
                let cSRKeyPair: CSRKeyPair = {
                    csr: result.csr,
                    key: result.clientKey
                }

                resolve(cSRKeyPair);
            })
        })

        let csrResult: CSRKeyPair = await csrPromise;

        let certPromise: Promise<pem.CertificateCreationResult> = new Promise<pem.CertificateCreationResult>((resolve, reject) =>  {
            pem.createCertificate({
                csr: csrResult.csr,
                days: 365,
                commonName: "app-monitoring-webhook-service.kube-system.svc",
                clientKey: csrResult.key,
            },(error, result) => {

                resolve(result);
            })
        })

        let certificateResponse: pem.CertificateCreationResult = await certPromise;

        let certificate: WebhookCertificateData = {
            ServerCertificate: certificateResponse.certificate,
            CaCertificate: certificateResponse.csr,
            ServerPrivateKey: certificateResponse.serviceKey
        };


        console.log(certificateResponse);


        return certificate;
    }

    public static async PatchWebhookAndSecrets() {


        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        let certificate: WebhookCertificateData = await CertificateGenerator.GenerateSelfSignedCertificate()


        // get secret
        const k8sSecretsApi = kc.makeApiClient(k8s.CoreV1Api);
        await k8sSecretsApi.readNamespacedSecret("app-monitoring-webhook-cert", "kube-system").then(async secretObj => {

            let secret: k8s.V1Secret = secretObj.body;
            secret.data["ca.cert"] = certificate.CaCertificate;
            secret.data["tls.cert"] = certificate.ServerCertificate;
            secret.data["tls.key"] = certificate.ServerPrivateKey;

            //patch secret
            await k8sSecretsApi.patchNamespacedSecret("app-monitoring-webhook-cert", "kube-system", secret);
        })

        //get webhook configuration
        const k8sWebhookApi = kc.makeApiClient(k8s.AdmissionregistrationV1Api);
        k8sWebhookApi.readMutatingWebhookConfiguration("app-monitoring-webhook").then(async webhookConfigObj => {

            let webhookConfig: k8s.V1MutatingWebhookConfiguration = webhookConfigObj.body;
            webhookConfig.webhooks[0].clientConfig.caBundle = certificate.CaCertificate;

            await k8sWebhookApi.patchMutatingWebhookConfiguration("app-monitoring-webhook", webhookConfig);

        })

    }


}
