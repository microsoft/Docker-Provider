import * as k8s from '@kubernetes/client-node';
import { CertificateStoreName, KubeSystemNamespaceName, WebhookDNSEndpoint, WebhookName } from './Constants.js'
import forge from 'node-forge';
import { HeartbeatMetrics, logger, RequestMetadata } from './LoggerWrapper.js';

export class WebhookCertData {
    caCert: string;
    caKey: string;
    tlsCert: string;
    tlsKey: string;
}

export class CertificateManager {
    
    private requestMetadata = new RequestMetadata(null, null);

    // Generate a random serial number for the Certificate
    private randomHexSerialNumber() {
        return (1001).toString(16) + Math.ceil(Math.random()*100); //Just creates a placeholder hex and randomly increments it with a number between 1 and 100
    }

    private GenerateCACertificate(existingKeyPair?: forge.pki.rsa.KeyPair): forge.pki.Certificate {
        const currentTime: number = Date.now();
        const caCert = forge.pki.createCertificate();
        const keys = existingKeyPair || forge.pki.rsa.generateKeyPair();
        caCert.serialNumber = this.randomHexSerialNumber();
        caCert.publicKey = keys.publicKey;
        caCert.privateKey = keys.privateKey;
        caCert.validity.notBefore = new Date(currentTime - (5 * 60 * 1000)); //5 Mins ago
        caCert.validity.notAfter = new Date(currentTime + (2 * 365 * 24 * 60 * 60 * 1000)); //2 Years from now

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
        logger.addHeartbeatMetric(HeartbeatMetrics.CACertificateGenerationCount, 1);

        return caCert;
    }

    private GenerateHostCertificate(caCert: forge.pki.Certificate): forge.pki.Certificate {
        const currentTime: number = Date.now();
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
        newHostCert.privateKey = hostKeys.privateKey;
        newHostCert.serialNumber = this.randomHexSerialNumber();
        newHostCert.validity.notBefore = new Date(currentTime - (5 * 60 * 1000)); //5 Mins ago
        newHostCert.validity.notAfter = new Date(currentTime + (2 * 365 * 24 * 60 * 60 * 1000)); //2 Years from now
        newHostCert.setSubject(host_attributes);
        newHostCert.setIssuer(caCert.subject.attributes);
        newHostCert.setExtensions(host_extensions);

        // Sign the new Host Certificate using the CA
        newHostCert.sign(caCert.privateKey, forge.md.sha256.create());

        logger.addHeartbeatMetric(HeartbeatMetrics.HostCertificateGenerationCount, 1);

        // // Convert to PEM format
        return newHostCert;
    }

    private CreateOrUpdateCertificates(operationId: string, currentCACert?: forge.pki.Certificate): WebhookCertData {
        try {
            let caCertResult: forge.pki.Certificate = currentCACert;

            if (!caCertResult) {
                caCertResult = this.GenerateCACertificate()
            }

            const hostCertificate = this.GenerateHostCertificate(caCertResult);

            return {
                caCert: forge.pki.certificateToPem(caCertResult),
                caKey: forge.pki.privateKeyToPem(caCertResult.privateKey),
                tlsCert: forge.pki.certificateToPem(hostCertificate),
                tlsKey: forge.pki.privateKeyToPem(hostCertificate.privateKey)
            } as WebhookCertData;
            
        } catch (error) {
            logger.error('Self Signed CA Cert generation failed!', operationId, this.requestMetadata);
            logger.error(JSON.stringify(error), operationId, this.requestMetadata);
            throw error;
        }
    }

    public async PatchSecretStore(operationId: string, kubeConfig: k8s.KubeConfig, certificate: WebhookCertData) {
        try {
            const secretsApi = kubeConfig.makeApiClient(k8s.CoreV1Api);
            const secretStore = await secretsApi.readNamespacedSecret(CertificateStoreName, KubeSystemNamespaceName);
            const secretsObj: k8s.V1Secret = secretStore.body;

            secretsObj.data['ca.cert'] = Buffer.from(certificate.caCert, 'utf-8').toString('base64');
            secretsObj.data['ca.key'] = Buffer.from(certificate.caKey, 'utf-8').toString('base64');
            secretsObj.data['tls.cert'] = Buffer.from(certificate.tlsCert, 'utf-8').toString('base64');
            secretsObj.data['tls.key'] = Buffer.from(certificate.tlsKey, 'utf-8').toString('base64');

            await secretsApi.patchNamespacedSecret(CertificateStoreName, KubeSystemNamespaceName, secretsObj, undefined, undefined, undefined, undefined, undefined, {
                headers: { 'Content-Type' : 'application/strategic-merge-patch+json' }
            });
            logger.addHeartbeatMetric(HeartbeatMetrics.SecretStoreUpdatedCount, 1);
        } catch (error) {
            logger.error('Failed to patch Secret Store!', operationId, this.requestMetadata);
            logger.error(JSON.stringify(error), operationId, this.requestMetadata);
            logger.addHeartbeatMetric(HeartbeatMetrics.SecretStoreUpdateFailedCount, 1);
            throw error;
        }
    }

    public async GetSecretDetails(operationId: string, kubeConfig: k8s.KubeConfig): Promise<WebhookCertData> {
        try {
            const k8sApi = kubeConfig.makeApiClient(k8s.CoreV1Api);
            const secretStore = await k8sApi.readNamespacedSecret(CertificateStoreName, KubeSystemNamespaceName)
            const secretsObj = secretStore.body;
            if (secretsObj.data) {
                const certificate: WebhookCertData = {
                    caCert: Buffer.from(secretsObj.data['ca.cert'], 'base64').toString('utf-8'),
                    caKey: Buffer.from(secretsObj.data['ca.key'], 'base64').toString('utf-8'),
                    tlsCert: Buffer.from(secretsObj.data['tls.cert'], 'base64').toString('utf-8'),
                    tlsKey: Buffer.from(secretsObj.data['tls.key'], 'base64').toString('utf-8')
                };

                return certificate;
            }
        } catch (error) {
            logger.error(JSON.stringify(error), operationId, this.requestMetadata);
            throw error;
        }
    }

    public async GetMutatingWebhookCABundle(operationId: string, kubeConfig: k8s.KubeConfig): Promise<string> {
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

            return Buffer.from(mutatingWebhookObject.webhooks[0].clientConfig.caBundle, 'base64').toString('utf-8');
        } catch (error) {
            logger.error(`Failed to get MutatingWebhookConfiguration! ${JSON.stringify(error)}`, operationId, this.requestMetadata);
            throw error;
        }
    }

    public async PatchMutatingWebhook(operationId: string, kubeConfig: k8s.KubeConfig, certificate: WebhookCertData) {
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
            mutatingWebhookObject.webhooks[0].clientConfig.caBundle = Buffer.from(certificate.caCert, 'utf-8').toString('base64');
            await webhookApi.patchMutatingWebhookConfiguration(WebhookName, mutatingWebhookObject, undefined, undefined, undefined, undefined, undefined, {
                headers: { 'Content-Type' : 'application/strategic-merge-patch+json' }
            });
            logger.addHeartbeatMetric(HeartbeatMetrics.MutatingWebhookConfigurationUpdatedCount, 1);
        } catch (error) {
            logger.error('Failed to patch MutatingWebhookConfiguration!', operationId, this.requestMetadata);
            logger.error(JSON.stringify(error), operationId, this.requestMetadata);
            logger.addHeartbeatMetric(HeartbeatMetrics.MutatingWebhookConfigurationUpdateFailedCount, 1);
            throw error;
        }
    }

    private isCertificateSignedByCA(pemCertificate: string, pemCACertificate: string): boolean {
        if (!pemCertificate || !pemCACertificate) {
            return false;
        }

        const certificate: forge.pki.Certificate = forge.pki.certificateFromPem(pemCertificate);
        const caCertificate: forge.pki.Certificate = forge.pki.certificateFromPem(pemCACertificate);
        // Verify the signature on the certificate
        return caCertificate.verify(certificate);
    }

    private IsValidCertificate(operationId: string, mwhcCaBundle: string, webhookCertData: WebhookCertData, clusterArmId: string, clusterArmRegion: string): boolean {
        try {
            forge.pki.certificateFromPem(mwhcCaBundle);
            forge.pki.certificateFromPem(webhookCertData.caCert);
            forge.pki.certificateFromPem(webhookCertData.tlsCert);
            forge.pki.privateKeyFromPem(webhookCertData.tlsKey);
            return true;
        } catch (error) {
            logger.error('Error occured while trying to validate certificates!', operationId, this.requestMetadata);
            logger.error(JSON.stringify(error), operationId, this.requestMetadata);
            logger.SendEvent("CertificateValidationFailed", operationId, null, clusterArmId, clusterArmRegion, true, error);
            return false;
        }
    }

    /**
     * This method checks if a specific Kubernetes job has finished. It does this by reading the status of a job
     * named `app-monitoring-cert-manager-hook-install` in a specific namespace. If the job status indicates completion,
     * it returns true. If the job is not yet complete, it returns a false value.
     * If there is an error in getting the job status, it throws the error.
     * @param kubeConfig - The Kubernetes configuration.
     * @param operationId - The operation ID.
     * @param clusterArmId - The ARM ID of the cluster.
     * @param clusterArmRegion - The ARM region of the cluster.
     * @returns A promise that resolves to a boolean indicating whether the job has finished.
     */
    private async HasCertificateInstallerJobFinished(kubeConfig: k8s.KubeConfig, operationId: string, clusterArmId: string, clusterArmRegion: string): Promise<boolean> {
        const k8sApi = kubeConfig.makeApiClient(k8s.BatchV1Api);
        const requestMetadata = this.requestMetadata;
        const jobName = 'app-monitoring-secrets-installer';
        const namespace = KubeSystemNamespaceName;

        try {
            const res = await k8sApi.readNamespacedJobStatus(jobName, namespace);
            const jobStatus = res.body.status;
            
            if (jobStatus.conditions) {
                for (const condition of jobStatus.conditions) {
                    if (condition.type === 'Complete' && condition.status === 'True') {
                        logger.info(`Job ${jobName} has completed.`, operationId, requestMetadata);
                        logger.SendEvent("CertificateJobCompleted", operationId, null, clusterArmId, clusterArmRegion);
                        return true;
                    }
                }
            }
            logger.info(`Job ${jobName} has not completed yet.`, operationId, requestMetadata);
            logger.SendEvent("CertificateJobNotCompleted", operationId, null, clusterArmId, clusterArmRegion);
            return false;
        } catch (err) {
            logger.error(`Failed to get job status: ${JSON.stringify(err)}`, operationId, requestMetadata);
            logger.SendEvent("CertificateJobStatusFailed", operationId, null, clusterArmId, clusterArmRegion, true, err);
            throw err;
        }
    }

    /**
     * This method creates a webhook and certificates for a secret store in AKS.
     * @param operationId - The operation ID.
     * @param clusterArmId - The ARM ID of the cluster.
     * @param clusterArmRegion - The ARM region of the cluster.
     */
    public async CreateWebhookAndCertificates(operationId: string, clusterArmId: string, clusterArmRegion: string) {
        /**
         * The code block above creates and updates certificates for a webhook. 
         * It starts by creating a new instance of the Kubernetes configuration and loading it from the default location. 
         * Then, it logs a message and sends an event to indicate that the certificate creation process has started. 
         * The CreateOrUpdateCertificates method is called to generate the certificates, and the result is stored in the certificates variable. 
         * Another log message and event are generated to indicate that the certificates have been created successfully. 
         * Finally, the PatchWebhookAndSecretStore method is called to patch the webhook and certificates using the Kubernetes configuration, 
         * the certificates variable, and other parameters.
         */
        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        logger.info('Creating certificates...', operationId, this.requestMetadata);
        logger.SendEvent("CertificateCreating", operationId, null, clusterArmId, clusterArmRegion);
        const certificates: WebhookCertData = this.CreateOrUpdateCertificates(operationId) as WebhookCertData;
        logger.info('Certificates created successfully', operationId, this.requestMetadata);
        logger.SendEvent("CertificateCreated", operationId, null, clusterArmId, clusterArmRegion);

        await this.PatchWebhookAndSecretStore(operationId, kc, certificates, clusterArmId, clusterArmRegion);
    }

    /**
     * This method reconciles the webhook ca bundle and certificates in the AKS secret store. It does this by checking if the certificate installer job has
     * finished, getting the secret details, getting the mutating webhook CA bundle, and then checking if the certificates
     * are valid or not or if they are close to expiry. If either certificate is regenerated, it patches the webhook and certificates and
     * restarts the webhook deployment so it picks up the new certificates.
     * @param operationId - The operation ID.
     * @param clusterArmId - The ARM ID of the cluster.
     * @param clusterArmRegion - The ARM region of the cluster.
     * @returns - A promise that resolves when the reconciliation is complete.
     */
    public async ReconcileWebhookAndCertificates(operationId: string, clusterArmId: string, clusterArmRegion: string): Promise<void> {
        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        let certificates: WebhookCertData = null;
        let webhookCertData: WebhookCertData = null;
        let mwhcCaBundle: string = null;
        
        /**
         * The try block contains the main logic of the reconciliation. It first checks if the certificate installer job
         * has finished. If the job has finished, it gets the secret details and the mutating webhook CA bundle. It then
         * checks if the certificates are valid. If the certificates are not valid, it creates new certificates, patches
         * the webhook and certificates, and restarts the webhook deployment. If the certificates are valid, it checks if
         * the CA certificate is close to expiration and regenerates it if necessary. It then checks if the host certificate
         * is close to expiration and regenerates it if necessary. If either certificate is regenerated, it patches the
         * webhook and certificates and restarts the webhook deployment. If no certificates need to be regenerated, it logs
         * that nothing needs to be done.
         * If the job cannot be found, the secret cannot be found, or the mutating webhook CA bundle cannot be found, the
         * catch block logs the error and sends an event.
         * If the job has completed, the catch block logs that the certificates installer has completed and sends an event.
         * If an error occurs at any point in the try block, the catch block logs the error and sends an event.
         */

        try {
            // get the cert installer job
            const isInstallerJobCompleted: boolean = await this.HasCertificateInstallerJobFinished(kc, operationId, clusterArmId, clusterArmRegion);
            if (isInstallerJobCompleted) {
                logger.info('Certificates Installer has completed, continue validation...', operationId, this.requestMetadata);
            } else {
                logger.info('Certificates Installer has not completed yet, reconciliation is not needed at this time...', operationId, this.requestMetadata);
                logger.SendEvent("CertificateInstallerNotCompleteYet", operationId, null, clusterArmId, clusterArmRegion, true);
                return;
            }
        } catch (error) {
            logger.error(`Error occurred while trying to get Installer Job\n${JSON.stringify(error)}`, operationId, this.requestMetadata);
            return;
        }

        try {
            // get the secret
            webhookCertData = await this.GetSecretDetails(operationId, kc);
        } catch (error) {
            logger.error(`Error occurred while trying to get Secret Store\n${JSON.stringify(error)}`, operationId, this.requestMetadata);
            return;
        }

        try {
            // get mutating webhook configuration's CA bundle
            mwhcCaBundle = await this.GetMutatingWebhookCABundle(operationId, kc);
        } catch (error) {
            logger.error(`Error occurred while trying to get MutatingWebhookConfiguration\n${JSON.stringify(error)}`, operationId, this.requestMetadata);
            return;
        }

        /**
         * This block of code is responsible for validating certificates used in a certificate generation process. 
         * The first line checks if the certificates are valid by calling the `IsValidCertificate` method, which takes in several parameters including 
         * CA bundle, webhook certificate data etc. The next line checks if the CA bundle, webhook certificate, and CA certificate
         * match by comparing their values. Then, it checks if the webhook certificate is signed by the CA certificate using the `isCertificateSignedByCA` method. 
         * Each step in the validation process is assigned to a boolean variable to track the result.
         */
        const validCerts: boolean = this.IsValidCertificate(operationId, mwhcCaBundle, webhookCertData, clusterArmId, clusterArmRegion);
        const matchValidation: boolean = validCerts && mwhcCaBundle && webhookCertData && mwhcCaBundle.localeCompare(webhookCertData.caCert) === 0;
        const certSignedByGivenCA: boolean = matchValidation && this.isCertificateSignedByCA(webhookCertData.tlsCert, mwhcCaBundle);

        if (!certSignedByGivenCA)
        {
            logger.info('Creating certificates...', operationId, this.requestMetadata);
            logger.SendEvent("CertificateCreating", operationId, null, clusterArmId, clusterArmRegion);
            certificates = this.CreateOrUpdateCertificates(operationId) as WebhookCertData;
            logger.info('Certificates created successfully', operationId, this.requestMetadata);
            logger.SendEvent("CertificateCreated", operationId, null, clusterArmId, clusterArmRegion);
            await this.PatchWebhookAndSecretStore(operationId, kc, certificates, clusterArmId, clusterArmRegion);
            await this.RestartWebhookDeployment(operationId, kc, clusterArmId, clusterArmRegion);
            return;
        }

        const timeNow: number = Date.now();
        const dayVal: number = 24 * 60 * 60 * 1000;
        let shouldUpdate = false;
        let shouldRestartDeployment = false;
        let caPublicCertificate: forge.pki.Certificate = forge.pki.certificateFromPem(webhookCertData.caCert);

        /**
         * Here, there is a check to determine if the CA (Certificate Authority) certificate is close to expiration. 
         * If the certificate has less than 90 days until expiration, the code proceeds to regenerate the CA certificate. 
         * It sets a flag `shouldUpdate` to true and generates a new CA certificate using the `GenerateCACertificate` function. 
         * This function takes an optional existing key pair as a parameter, and if not provided, it generates a new key pair. 
         * The generated CA certificate is then converted to PEM format and assigned to the `caCert` property of the `webhookCertData` object.
         */
        let daysToExpiry = (caPublicCertificate.validity.notAfter.valueOf() - timeNow)/dayVal;
        if (daysToExpiry < 90) {
            logger.info('CA Certificate is close to expiration, regenerating CA Certificate...', operationId, this.requestMetadata);
            shouldUpdate = true;
            const caKeyPair: forge.pki.rsa.KeyPair = {
                privateKey: forge.pki.privateKeyFromPem(webhookCertData.caKey),
                publicKey: caPublicCertificate.publicKey as forge.pki.rsa.PublicKey
            }
            caPublicCertificate = this.GenerateCACertificate(caKeyPair);
            webhookCertData.caCert = forge.pki.certificateToPem(caPublicCertificate);
        }

        // Check if Host Cert is relatively close to expiration, similar to above
        const hostCertificate: forge.pki.Certificate = forge.pki.certificateFromPem(webhookCertData.tlsCert);
        daysToExpiry = (hostCertificate.validity.notAfter.valueOf() - timeNow)/dayVal;
        if (daysToExpiry < 90) {
            logger.info('Host Certificate is close to expiration, regenerating Host Certificate...', operationId, this.requestMetadata);
            shouldUpdate = true;
            shouldRestartDeployment = true;
            caPublicCertificate.privateKey = forge.pki.privateKeyFromPem(webhookCertData.caKey);
            const newHostCert: forge.pki.Certificate = this.GenerateHostCertificate(caPublicCertificate);
            webhookCertData.tlsCert = forge.pki.certificateToPem(newHostCert);
            webhookCertData.tlsKey = forge.pki.privateKeyToPem(newHostCert.privateKey);
        }

        /**
         * If either the CA certificate or the host certificate is regenerated, the webhook and certificates are patched
         * and the webhook deployment is restarted. If neither certificate is regenerated, the reconciliation is complete.
         */
        if (shouldUpdate) {
            await this.PatchWebhookAndSecretStore(operationId, kc, webhookCertData, clusterArmId, clusterArmRegion);
            if (shouldRestartDeployment) {
                logger.info('Restarting webhook deployment so the pods pick up new certificates...', operationId, this.requestMetadata);
                await this.RestartWebhookDeployment(operationId, kc, clusterArmId, clusterArmRegion);
            }
        }
        else {
            logger.info('Nothing to do. All is good. Ending this run...', operationId, this.requestMetadata);
        }
    }

    /**
     * This method restarts the webhook deployment. 
     * @param operationId - The operation ID.
     * @param kc - The Kubernetes configuration.
     * @param clusterArmId - The ARM ID of the cluster.
     * @param clusterArmRegion - The ARM region of the cluster.
     */
    private async RestartWebhookDeployment(operationId: string, kc: k8s.KubeConfig, clusterArmId: string, clusterArmRegion: string): Promise<void> {
        let name = null;
    
        /**
         * The try block contains the logic to restart the webhook deployment. It first gets the webhook deployment by
         * its selector. If there is no deployment or more than one deployment with the selector, it throws an error. If
         * there is exactly one deployment with the selector, it restarts the deployment by updating the annotations with
         * the current time.
         */
        try {
            const k8sApi = kc.makeApiClient(k8s.AppsV1Api);
            const selector = "app-monitoring-webhook"
            const deployments: k8s.V1DeploymentList = (await k8sApi.listNamespacedDeployment(KubeSystemNamespaceName)).body;

            if (!deployments)
            {
                throw new Error(`No Deployments found in ${KubeSystemNamespaceName} namespace!`);
            }
            const matchingDeployments: k8s.V1Deployment[] = deployments.items.filter(deployment => selector.localeCompare(deployment.spec.selector?.matchLabels?.app) === 0);

            if (matchingDeployments.length != 1) {
                throw new Error(`Expected 1 Deployment with selector ${selector}, but found ${matchingDeployments.length}`);
            }

            const deployment: k8s.V1Deployment = matchingDeployments[0];
            const annotations = deployment.spec.template.metadata.annotations ?? {};
            annotations["kubectl.kubernetes.io/restartedAt"] = new Date().toISOString();
            deployment.spec.template.metadata.annotations = annotations;

            name = deployment.metadata.name;

            logger.info(`Restarting deployment ${name}...`, operationId, this.requestMetadata);
            logger.SendEvent("DeploymentRestarting", operationId, null, clusterArmId, clusterArmRegion);
            await k8sApi.replaceNamespacedDeployment(name, KubeSystemNamespaceName, deployment);
            console.log(`Successfully restarted Deployment ${name}`);
            logger.SendEvent("DeploymentRestarted", operationId, null, clusterArmId, clusterArmRegion);
        } catch (err) {
            logger.error(`Failed to restart Deployment ${name}: ${err}`, operationId, this.requestMetadata);
            logger.SendEvent("DeploymentRestartFailed", operationId, null, clusterArmId, clusterArmRegion, true, err);
            throw err;
        }
    }

    private async PatchWebhookAndSecretStore(operationId: string, kc: k8s.KubeConfig, certificates: WebhookCertData, clusterArmId: string, clusterArmRegion: string) {
        logger.info('Patching Secret Store...', operationId, this.requestMetadata);
        logger.SendEvent("CertificatePatchingSecretStore", operationId, null, clusterArmId, clusterArmRegion);
        await this.PatchSecretStore(operationId, kc, certificates);
        logger.info('Secret Store patched successfully', operationId, this.requestMetadata);

        logger.info('Patching MutatingWebhookConfiguration...', operationId, this.requestMetadata);
        logger.SendEvent("CertificatePatchingMWHC", operationId, null, clusterArmId, clusterArmRegion);
        await this.PatchMutatingWebhook(operationId, kc, certificates);
        logger.info('MutatingWebhookConfiguration patched successfully', operationId, this.requestMetadata);
        logger.SendEvent("CertificatePatchedMWHC", operationId, null, clusterArmId, clusterArmRegion);
    }
}
