import { CertificateManager, WebhookCertData } from "CertificateManager.js";
import forge from "node-forge";
import { AdmissionregistrationV1Api, AppsV1Api, CoreV1Api, createConfiguration, KubeConfig, V1Deployment, V1DeploymentList, V1MutatingWebhook, V1MutatingWebhookConfiguration, V1ReplicaSet, V1Secret } from "@kubernetes/client-node";
import { logger } from "LoggerWrapper.js"

describe('CertificateManager', () => {
    let certManager: CertificateManager;

    beforeEach(() => {
        jest.clearAllMocks();
        jest.resetAllMocks();
        // Set up kubeConfig with necessary configurations

        certManager = new CertificateManager();

        logger.setUnitTestMode(true);

        jest.spyOn(logger, "SendEvent").mockResolvedValue();
    });

    afterEach(() => {
        jest.clearAllMocks();
        jest.resetAllMocks();
    });

    describe('CreateWebhookAndSecretStore', () => {
        it('should create and update webhook and certificates', async () => {
            const mockKubeConfig = new KubeConfig();
            const mockClusterArmId = 'clusterArmId';
            const mockClusterArmRegion = 'clusterArmRegion';
            jest.spyOn(KubeConfig.prototype, 'loadFromDefault').mockReturnValue(null);
            const createOrUpdateCertificates = jest.spyOn(certManager as any, 'CreateOrUpdateCertificates').mockReturnValue({
                caCert: 'mockCACert',
                caKey: 'mockCAKey',
                tlsKey: 'mockTLSKey',
                tlsCert: 'mockTLSCert',
            } as WebhookCertData);
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockResolvedValue(null);

            const operationId = 'operationId';
            await certManager.CreateWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);

            expect(createOrUpdateCertificates).toHaveBeenCalledWith(operationId);
            expect(updateWebhookAndCertificates).toHaveBeenCalledWith(operationId, mockKubeConfig, {
                caCert: 'mockCACert',
                caKey: 'mockCAKey',
                tlsKey: 'mockTLSKey',
                tlsCert: 'mockTLSCert',
            } as WebhookCertData, mockClusterArmId, mockClusterArmRegion);
        });
    });

    describe('ReconcileWebhookAndCertificates', () => {
        let mockKubeConfig: KubeConfig;
        let mockClusterArmId: string;
        let mockClusterArmRegion: string;
        let operationId: string;
        let certManager: CertificateManager;

        beforeEach(() => {
            mockKubeConfig = new KubeConfig();
            mockClusterArmId = 'clusterArmId';
            mockClusterArmRegion = 'clusterArmRegion';
            operationId = 'operationId';
            jest.spyOn(KubeConfig.prototype, 'loadFromDefault').mockReturnValue(null);

            certManager = new CertificateManager();
        });

        afterEach(() => {
            jest.resetAllMocks();
        });

        it('Should fail certificate validation if parameters are null', async () => {
            const IsValidCertificate = await certManager.IsValidCertificate('op-test', null, null, mockClusterArmId, mockClusterArmRegion);

            expect(IsValidCertificate).toBeFalsy();
        });

        it('Should pass certificate validation if caCert from MWHC is bad', async () => {
            const certs: WebhookCertData = await certManager.CreateOrUpdateCertificates('op-test');
            const IsValidCertificate = await certManager.IsValidCertificate('op-test', null, certs, mockClusterArmId, mockClusterArmRegion);

            expect(IsValidCertificate).toBeFalsy();
        });

        it('Should pass certificate validation if caCert in secret store is bad', async () => {
            const certs: WebhookCertData = await certManager.CreateOrUpdateCertificates('op-test');
            certs.caCert = 'bad-ca-cert';
            const IsValidCertificate = await certManager.IsValidCertificate('op-test', certs.caCert, certs, mockClusterArmId, mockClusterArmRegion);

            expect(IsValidCertificate).toBeFalsy();
        });

        it('Should pass certificate validation if caKey in secret store is bad', async () => {
            const certs: WebhookCertData = await certManager.CreateOrUpdateCertificates('op-test');
            certs.caKey = 'bad-ca-key';
            const IsValidCertificate = await certManager.IsValidCertificate('op-test', certs.caCert, certs, mockClusterArmId, mockClusterArmRegion);

            expect(IsValidCertificate).toBeFalsy();
        });

        it('Should pass certificate validation if tls cert in secret store is bad', async () => {
            const certs: WebhookCertData = await certManager.CreateOrUpdateCertificates('op-test');
            certs.tlsCert = 'bad-tls-cert';
            const IsValidCertificate = await certManager.IsValidCertificate('op-test', certs.caCert, certs, mockClusterArmId, mockClusterArmRegion);

            expect(IsValidCertificate).toBeFalsy();
        });

        it('Should pass certificate validation if tls key in secret store is bad', async () => {
            const certs: WebhookCertData = await certManager.CreateOrUpdateCertificates('op-test');
            certs.tlsKey = 'bad-tls-key';
            const IsValidCertificate = await certManager.IsValidCertificate('op-test', certs.caCert, certs, mockClusterArmId, mockClusterArmRegion);

            expect(IsValidCertificate).toBeFalsy();
        });

        it('Should pass certificate validation if parameters are good', async () => {
            const certs: WebhookCertData = await certManager.CreateOrUpdateCertificates('op-test');
            const IsValidCertificate = await certManager.IsValidCertificate('op-test', certs.caCert, certs, mockClusterArmId, mockClusterArmRegion);

            expect(IsValidCertificate).toBeTruthy();
        });

        it('should not do anything if it installer job has not finished', async () => {
            const checkCertificateJobStatus = jest.spyOn(certManager as any, 'IsCertificateInstallerJobRunning').mockResolvedValue(true);
            const getMutatingWebhookCABundle = jest.spyOn(certManager as any, 'GetMutatingWebhookCABundle').mockResolvedValue(null);
            const getSecretDetails = jest.spyOn(certManager as any, 'GetSecretDetails').mockResolvedValue(null);
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockResolvedValue(null);
            const restartWebhookDeployment = jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockResolvedValue(null);
            await certManager.ReconcileWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);

            expect(checkCertificateJobStatus).toHaveBeenCalled();
            expect(checkCertificateJobStatus).toHaveBeenCalledTimes(1);
            expect(getMutatingWebhookCABundle).not.toBeCalled();
            expect(getSecretDetails).not.toBeCalled();
            expect(updateWebhookAndCertificates).not.toBeCalled();
            expect(restartWebhookDeployment).not.toBeCalled();
        });

        it('should not proceed if it fails to get secret store', async () => {
            const checkCertificateJobStatus = jest.spyOn(certManager as any, 'IsCertificateInstallerJobRunning').mockResolvedValue(false);
            const getSecretDetails = jest.spyOn(certManager as any, 'GetSecretDetails').mockRejectedValue(new Error('Secret not found'));
            const getMutatingWebhookCABundle = jest.spyOn(certManager as any, 'GetMutatingWebhookCABundle').mockResolvedValue(null);
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockResolvedValue(null);
            const restartWebhookDeployment = jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockResolvedValue(null);
            await certManager.ReconcileWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);

            expect(checkCertificateJobStatus).toHaveBeenCalled();
            expect(checkCertificateJobStatus).toHaveBeenCalledTimes(1);
            expect(getSecretDetails).toHaveBeenCalled();
            expect(getSecretDetails).toHaveBeenCalledTimes(1);
            expect(getMutatingWebhookCABundle).not.toBeCalled();
            expect(updateWebhookAndCertificates).not.toBeCalled();
            expect(restartWebhookDeployment).not.toBeCalled();
        });

        it('should not proceed if it fails to get mutating webhook configuration ', async () => {
            const checkCertificateJobStatus = jest.spyOn(certManager as any, 'IsCertificateInstallerJobRunning').mockResolvedValue(false);
            const getSecretDetails = jest.spyOn(certManager as any, 'GetSecretDetails').mockResolvedValue(null);
            const getMutatingWebhookCABundle = jest.spyOn(certManager as any, 'GetMutatingWebhookCABundle').mockRejectedValue(new Error('Mutating webhook not found'));
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockResolvedValue(null);
            const restartWebhookDeployment = jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockResolvedValue(null);
            await certManager.ReconcileWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);

            expect(checkCertificateJobStatus).toHaveBeenCalled();
            expect(checkCertificateJobStatus).toHaveBeenCalledTimes(1);
            expect(getSecretDetails).toHaveBeenCalled();
            expect(getSecretDetails).toHaveBeenCalledTimes(1);
            expect(getMutatingWebhookCABundle).toBeCalled();
            expect(getMutatingWebhookCABundle).toBeCalledTimes(1);
            expect(updateWebhookAndCertificates).not.toBeCalled();
            expect(restartWebhookDeployment).not.toBeCalled();
        });

        it('should reconcile webhook and certificates - happy path', async () => {
            const secretObj: WebhookCertData = (certManager as any).CreateOrUpdateCertificates('test-operationId');
            const getSecretDetails = jest.spyOn(certManager as any, 'GetSecretDetails').mockResolvedValue(secretObj);
            const getMutatingWebhookCABundle = jest.spyOn(certManager as any, 'GetMutatingWebhookCABundle').mockResolvedValue(secretObj.caCert);
            jest.spyOn(certManager as any, 'isCertificateSignedByCA').mockReturnValue(true);
            const checkCertificateJobStatus = jest.spyOn(certManager as any, 'IsCertificateInstallerJobRunning').mockResolvedValue(false);
            const IsValidCertificate = jest.spyOn(certManager as any, 'IsValidCertificate').mockResolvedValue(true);
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockResolvedValue(null);
            const restartWebhookDeployment = jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockResolvedValue(null);
            await certManager.ReconcileWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);

            expect(checkCertificateJobStatus).toHaveBeenCalled();
            expect(checkCertificateJobStatus).toHaveBeenCalledTimes(1);
            expect(IsValidCertificate).toHaveBeenCalled();
            expect(IsValidCertificate).toHaveBeenCalledTimes(1);
            expect(getSecretDetails).toHaveBeenCalledTimes(1);
            expect(getSecretDetails).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion); // Ensure it was called with correct parameters
            expect(getMutatingWebhookCABundle).toHaveBeenCalledTimes(1);
            expect(getMutatingWebhookCABundle).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
            expect(updateWebhookAndCertificates).not.toBeCalled();
            expect(restartWebhookDeployment).not.toBeCalled();
        });

        it('should reconcile webhook and certificates - invalid certificate in secret store and/or mwhc', async () => {
            jest.spyOn(certManager as any, 'GetSecretDetails').mockResolvedValue(null);
            const getMutatingWebhookCABundle = jest.spyOn(certManager as any, 'GetMutatingWebhookCABundle').mockResolvedValue(null);
            const getSecretDetails =  jest.spyOn(certManager as any, 'GetSecretDetails').mockResolvedValue(null);
            jest.spyOn(certManager as any, 'isCertificateSignedByCA').mockReturnValue(false);
            const checkCertificateJobStatus = jest.spyOn(certManager as any, 'IsCertificateInstallerJobRunning').mockResolvedValue(false);
            const IsValidCertificate = jest.spyOn(certManager as any, 'IsValidCertificate').mockResolvedValue(false);
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockResolvedValue(null);
            const restartWebhookDeployment = jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockResolvedValue(null);
            const certGenCaller = jest.spyOn(certManager as any, 'CreateOrUpdateCertificates');
            await certManager.ReconcileWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);
            const generatedCertificate: WebhookCertData = certGenCaller.mock.results[0].value;

            expect(checkCertificateJobStatus).toHaveBeenCalled();
            expect(checkCertificateJobStatus).toHaveBeenCalledTimes(1);
            expect(IsValidCertificate).toBeCalled();
            expect(getMutatingWebhookCABundle).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
            expect(getSecretDetails).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
            expect(updateWebhookAndCertificates).toHaveBeenCalledTimes(1);
            expect(updateWebhookAndCertificates).toHaveBeenCalledWith(operationId, mockKubeConfig, generatedCertificate, mockClusterArmId, mockClusterArmRegion);
            expect(restartWebhookDeployment).toHaveBeenCalledTimes(1);
            expect(restartWebhookDeployment).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
        });

        it('should generate all new certs for host and CA if certs are corrupted or mismatched', async () => {
            const mockCertData: WebhookCertData = {
                caCert: 'mockCACert',
                caKey: 'mockCAKey',
                tlsCert: 'mockTLSCert',
                tlsKey: 'mockTLSKey'
            };
            const createOrUpdateCertificates = jest.spyOn(certManager as any, 'CreateOrUpdateCertificates').mockReturnValue({
                caCert: mockCertData.caCert,
                caKey: mockCertData.caKey,
                tlsKey: mockCertData.tlsKey,
                tlsCert: mockCertData.tlsCert
            } as WebhookCertData);
            jest.spyOn(certManager as any, 'GetSecretDetails').mockImplementation((operationId: string, kubeConfig: KubeConfig) => {
                if (!kubeConfig) {
                    throw new Error('Invalid KubeConfig');
                }
                return new Promise((resolve) => {
                    resolve(mockCertData);
                });
            });
            const getMutatingWebhookCABundle = jest.spyOn(certManager as any, 'GetMutatingWebhookCABundle').mockResolvedValue(mockCertData.caCert);
            jest.spyOn(certManager as any, 'isCertificateSignedByCA').mockReturnValue(false);
            const checkCertificateJobStatus = jest.spyOn(certManager as any, 'IsCertificateInstallerJobRunning').mockResolvedValue(false);
            const IsValidCertificate = jest.spyOn(certManager as any, 'IsValidCertificate').mockResolvedValue(true);
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockImplementation((_1: string, kc: KubeConfig, certificates: WebhookCertData, _2: string, _3: string) => {
                if (!(kc && certificates && certificates.caCert && certificates.caKey && certificates.tlsCert && certificates.tlsKey 
                        && mockCertData.caCert.localeCompare(certificates.caCert) === 0 && mockCertData.caKey.localeCompare(certificates.caKey) === 0 
                        && mockCertData.tlsCert.localeCompare(certificates.tlsCert) === 0 && mockCertData.tlsKey.localeCompare(certificates.tlsKey) === 0)) {
                        throw new Error('Invalid KubeConfig or Certificates');
                }
                return null;
            });
            const restartWebhookDeployment = jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockImplementation((_1: string, kc: KubeConfig, _2: string, _3: string) => {
                if (!kc) {
                    throw new Error('Invalid KubeConfig');
                }
                return null;
            });

            await certManager.ReconcileWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);

            //Assert
            expect(checkCertificateJobStatus).toHaveBeenCalled();
            expect(checkCertificateJobStatus).toHaveBeenCalledTimes(1);
            expect(IsValidCertificate).toBeCalled();
            expect(IsValidCertificate).toHaveBeenCalledTimes(1);
            expect(createOrUpdateCertificates).toHaveBeenLastCalledWith(operationId);
            expect(getMutatingWebhookCABundle).toHaveBeenCalledTimes(1);
            expect(getMutatingWebhookCABundle).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
            expect(updateWebhookAndCertificates).toHaveBeenCalledTimes(1);
            expect(updateWebhookAndCertificates).toHaveBeenCalledWith(operationId, mockKubeConfig, mockCertData, mockClusterArmId, mockClusterArmRegion);
            expect(restartWebhookDeployment).toHaveBeenCalledTimes(1);
            expect(restartWebhookDeployment).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
        });

        it('should handle only CA cert expiration', async () => {
            jest.spyOn(Date, 'now').mockReturnValueOnce(0).mockReturnValue(800 * 24 * 60 * 60 * 1000);
            const realCertObj: WebhookCertData = (certManager as any).CreateOrUpdateCertificates('test-operationId');
            const caCertDecoded: forge.pki.Certificate = forge.pki.certificateFromPem(realCertObj.caCert);
            const getSecretDetails =  jest.spyOn(certManager as any, 'GetSecretDetails').mockImplementation((operationId: string, kubeConfig: KubeConfig) => {
                if (!kubeConfig) {
                    throw new Error('Invalid KubeConfig');
                }
                return new Promise((resolve) => {
                    resolve(realCertObj);
                });
            });
            const getMutatingWebhookCABundle = jest.spyOn(certManager as any, 'GetMutatingWebhookCABundle').mockImplementation((operationId: string, kubeConfig: KubeConfig) => {
                if (!kubeConfig) {
                    throw new Error('Invalid KubeConfig');
                }
                return new Promise((resolve) => {
                    resolve(realCertObj.caCert);
                });
            });
            const generateCACertificate = jest.spyOn(certManager as any, 'GenerateCACertificate').mockImplementation((existingKeyPair?: forge.pki.rsa.KeyPair) => {
                if (existingKeyPair && existingKeyPair.privateKey && forge.pki.privateKeyToPem(existingKeyPair.privateKey) && existingKeyPair.publicKey && forge.pki.publicKeyToPem(existingKeyPair.publicKey)) {
                    return caCertDecoded;
                }
                throw new Error('Invalid CA Private Key and/or Public key');

            });
            jest.spyOn(certManager as any, 'isCertificateSignedByCA').mockReturnValue(true);
            const checkCertificateJobStatus = jest.spyOn(certManager as any, 'IsCertificateInstallerJobRunning').mockResolvedValue(false);
            const IsValidCertificate = jest.spyOn(certManager as any, 'IsValidCertificate').mockResolvedValue(true);
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockImplementation((_1: string, kc: KubeConfig, certificates: WebhookCertData, _2: string, _3: string) => {
                if (!(kc && certificates && certificates.caCert && certificates.caKey && certificates.tlsCert && certificates.tlsKey 
                        && forge.pki.certificateFromPem(certificates.caCert) && forge.pki.privateKeyFromPem(certificates.caKey) && forge.pki.certificateFromPem(certificates.tlsCert) && forge.pki.privateKeyFromPem(certificates.tlsKey))) {
                        throw new Error('Invalid KubeConfig or Certificates');
                }
                return null;
            });
            const restartWebhookDeployment = jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockResolvedValue(null);

            await certManager.ReconcileWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);

            expect(checkCertificateJobStatus).toHaveBeenCalled();
            expect(IsValidCertificate).toBeCalled();
            expect(getMutatingWebhookCABundle).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
            expect(getSecretDetails).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
            expect(generateCACertificate).toHaveBeenCalled();
            expect(updateWebhookAndCertificates).toHaveBeenCalled();
            expect(restartWebhookDeployment).not.toBeCalled();
        });

        it('should handle only Host cert expiration', async () => {
            const checkCertificateJobStatus = jest.spyOn(certManager as any, 'IsCertificateInstallerJobRunning').mockResolvedValue(false);
            const IsValidCertificate = jest.spyOn(certManager as any, 'IsValidCertificate').mockResolvedValue(true);
            jest.spyOn(Date, 'now').mockReturnValueOnce(800 * 24 * 60 * 60 * 1000).mockReturnValueOnce(0).mockReturnValue(800 * 24 * 60 * 60 * 1000);
            const realCertObj: WebhookCertData = (certManager as any).CreateOrUpdateCertificates('test-operationId');
            const hostCertDecoded: forge.pki.Certificate = forge.pki.certificateFromPem(realCertObj.tlsCert);
            realCertObj.caCert = null;
            hostCertDecoded.privateKey = forge.pki.privateKeyFromPem(realCertObj.tlsKey);
            const getSecretDetails =  jest.spyOn(certManager as any, 'GetSecretDetails').mockResolvedValue(realCertObj);
            const getMutatingWebhookCABundle = jest.spyOn(certManager as any, 'GetMutatingWebhookCABundle').mockImplementation((_: string, kubeConfig: KubeConfig) => {
                if (!kubeConfig) {
                    throw new Error('Invalid KubeConfig');
                }
                return new Promise((resolve) => {
                    resolve(realCertObj.caCert);
                });
            });
            const generateHostCertificate = jest.spyOn(certManager as any, 'GenerateHostCertificate').mockImplementation((caCert: forge.pki.Certificate) => {
                if (!(caCert && caCert.privateKey && forge.pki.privateKeyToPem(caCert.privateKey))) {
                    throw new Error('Invalid CA Certificate or CA Private Key');
                }
                return hostCertDecoded;
            });
            jest.spyOn(certManager as any, 'isCertificateSignedByCA').mockReturnValue(true);
            const updateWebhookAndCertificates = jest.spyOn(certManager as any, 'UpdateWebhookAndSecretStore').mockImplementation((_1: string, kc: KubeConfig, certificates: WebhookCertData, _2: string, _3: string) => {
                if (!(kc && certificates && certificates.caCert && certificates.caKey && certificates.tlsCert && certificates.tlsKey 
                        && forge.pki.certificateFromPem(certificates.caCert) && forge.pki.privateKeyFromPem(certificates.caKey) && forge.pki.certificateFromPem(certificates.tlsCert) && forge.pki.privateKeyFromPem(certificates.tlsKey))) {
                        throw new Error('Invalid KubeConfig or Certificates');
                }
                return null;
            }).mockResolvedValue(null);
            const restartWebhookDeployment = jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockResolvedValue(null);

            await certManager.ReconcileWebhookAndCertificates(operationId, mockClusterArmId, mockClusterArmRegion);

            expect(checkCertificateJobStatus).toHaveBeenCalled();
            expect(IsValidCertificate).toBeCalled(); 
            expect(getMutatingWebhookCABundle).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);
            expect(getSecretDetails).toHaveBeenCalledWith(operationId, mockKubeConfig, mockClusterArmId, mockClusterArmRegion);

            expect(generateHostCertificate).toHaveBeenCalled();
            expect(updateWebhookAndCertificates).toHaveBeenCalled();
            expect(restartWebhookDeployment).toBeCalled();
        });
    });

    describe('UpdateMutatingWebhook', () => {
        it('should update mutating webhook', async () => {
            // Arrange
            const operationId = 'operationId';
            const mockKubeConfig = new KubeConfig();
            const mockCertificate: WebhookCertData = {
                caCert: 'mockCACert',
                caKey: 'mockCAKey',
                tlsCert: 'mockTLSCert',
                tlsKey: 'mockTLSKey',
            };
            const mutatingWebhookObject = {
                body: {
                    webhooks: [
                        {
                            name: "app-monitoring-webhook",
                            clientConfig: {
                                caBundle: ''
                            }
                        } as V1MutatingWebhook
                    ]
                } as V1MutatingWebhookConfiguration,
                name: "app-monitoring-webhook"
            };
            const readMutatingWebhookConfiguration  = jest.spyOn(AdmissionregistrationV1Api.prototype, 'readMutatingWebhookConfiguration').mockResolvedValue(mutatingWebhookObject.body);
            const mutatingWebhookObjectCopy = JSON.parse(JSON.stringify(mutatingWebhookObject));
            const updateMutatingWebhookConfiguration  = jest.spyOn(AdmissionregistrationV1Api.prototype, 'replaceMutatingWebhookConfiguration').mockResolvedValue(null);
            mutatingWebhookObjectCopy.body.webhooks[0].clientConfig.caBundle = Buffer.from(mockCertificate.caCert, 'utf-8').toString('base64');
            jest.spyOn(KubeConfig.prototype, 'makeApiClient').mockReturnValue(new AdmissionregistrationV1Api(createConfiguration()));

            // Mock the methods in CertificateManager
            jest.spyOn(certManager, 'UpdateMutatingWebhook');
            
            // Act
            await certManager.UpdateMutatingWebhook(operationId, mockKubeConfig, mockCertificate);
            mutatingWebhookObject.body.webhooks[0].clientConfig.caBundle = Buffer.from(mockCertificate.caCert, 'utf-8').toString('base64');

            // Assert
            expect(readMutatingWebhookConfiguration).toHaveBeenCalledWith({ name: "app-monitoring-webhook" });
            expect(updateMutatingWebhookConfiguration).toHaveBeenCalledWith(mutatingWebhookObjectCopy);
        });
    });

    describe('UpdateWebhookAndSecretStore', () => {
        it('should update webhook and certificates', async () => {
            // Arrange
            const operationId = 'operationId';
            const mockKubeConfig = new KubeConfig();
            const mockCertificate: WebhookCertData = {
                caCert: 'mockCACert',
                caKey: 'mockCAKey',
                tlsCert: 'mockTLSCert',
                tlsKey: 'mockTLSKey',
            };
            const clusterArmId = 'clusterArmId';
            const clusterArmRegion = 'clusterArmRegion';
            const updateMutatingWebhook = jest.spyOn(certManager, 'UpdateMutatingWebhook').mockResolvedValue(null);
            const updateSecretStore = jest.spyOn(certManager, 'UpdateSecretStore').mockResolvedValue(null);
            jest.spyOn(certManager as any, 'RestartWebhookDeployment').mockResolvedValue(null);

            // Act
            await (certManager as any).UpdateWebhookAndSecretStore(operationId, mockKubeConfig, mockCertificate, clusterArmId, clusterArmRegion);

            // Assert
            expect(updateMutatingWebhook).toHaveBeenCalledWith(operationId, mockKubeConfig, mockCertificate);
            expect(updateSecretStore).toHaveBeenCalledWith(operationId, mockKubeConfig, mockCertificate);
        });
    });

    describe('UpdateSecretStore', () => {
        it('should update secret store', async () => {
            // Arrange
            const operationId = 'operationId';
            const mockKubeConfig = new KubeConfig();
            const mockCertificate: WebhookCertData = {
                caCert: 'mockCACert',
                caKey: 'mockCAKey',
                tlsCert: 'mockTLSCert',
                tlsKey: 'mockTLSKey',
            };
            const secretObject = {
                response: null,
                body: {
                    data: {
                        'ca.cert': '',
                        'ca.key': '',
                        'tls.cert': '',
                        'tls.key': ''
                    }
                } as V1Secret
            };
            const readNamespacedSecret = jest.spyOn(CoreV1Api.prototype, 'readNamespacedSecret').mockResolvedValue(secretObject.body);
            const updateNamespacedSecret = jest.spyOn(CoreV1Api.prototype, 'replaceNamespacedSecret').mockResolvedValue(null);
            jest.spyOn(KubeConfig.prototype, 'makeApiClient').mockReturnValue(new CoreV1Api(createConfiguration()));

            // Mock the methods in CertificateManager
            jest.spyOn(certManager, 'UpdateSecretStore');
            
            // Act
            await certManager.UpdateSecretStore(operationId, mockKubeConfig, mockCertificate);

            // Assert
            expect(readNamespacedSecret).toHaveBeenCalledWith({ name: "app-monitoring-webhook-cert", namespace: "kube-system" });
            expect(updateNamespacedSecret).toHaveBeenCalledWith({
                name: "app-monitoring-webhook-cert",
                namespace: "kube-system",
                body: {
                    data: {
                        'ca.cert': Buffer.from(mockCertificate.caCert, 'utf-8').toString('base64'),
                        'ca.key': Buffer.from(mockCertificate.caKey, 'utf-8').toString('base64'),
                        'tls.cert': Buffer.from(mockCertificate.tlsCert, 'utf-8').toString('base64'),
                        'tls.key': Buffer.from(mockCertificate.tlsKey, 'utf-8').toString('base64')
                    }
                }
            });
        });
    });

    describe('RestartWebhookDeployment', () => {
        it('should restart webhook replicaset', async () => {
            // Arrange
            const operationId = 'operationId';
            const clusterArmId = 'clusterArmId';
            const clusterArmRegion = 'clusterArmRegion';
            const mockKubeConfig = new KubeConfig();
            const deployment = {
                body: {
                    metadata: {
                        name: 'app-monitoring-webhook',
                        namespace: 'kube-system'
                    },
                    spec: {
                        selector: {
                            matchLabels: {
                                app: 'app-monitoring-webhook'
                            }
                        },
                        template: {
                            metadata: {
                                name: 'app-monitoring-webhook',
                                annotations: {
                                    'anno1': 'anno1'
                                }
                            }
                        }
                    }
                } as V1Deployment
            } as any;
            const updatedDeployment: V1ReplicaSet = JSON.parse(JSON.stringify(deployment.body));
            jest.spyOn(Date.prototype, 'toISOString').mockReturnValue('GivenDate');
            updatedDeployment.spec.template.metadata = {
                name: 'app-monitoring-webhook',
                annotations: {
                    'anno1': 'anno1',
                    'kubectl.kubernetes.io/restartedAt': 'GivenDate'
                }
            };
            const readNamespacedDeployment = jest.spyOn(AppsV1Api.prototype, 'readNamespacedDeployment').mockResolvedValue(deployment.body);
            const replaceNamespacedDeployment = jest.spyOn(AppsV1Api.prototype, 'replaceNamespacedDeployment').mockResolvedValue(null);
            jest.spyOn(KubeConfig.prototype, 'makeApiClient').mockReturnValue(new AppsV1Api(createConfiguration()));
            
            // Act
            const method = Reflect.get(certManager, "RestartWebhookDeployment").bind(certManager, operationId, mockKubeConfig, clusterArmId, clusterArmRegion);
            await method();
            
            // Assert
            expect(readNamespacedDeployment).toHaveBeenCalledWith({ name: "app-monitoring-webhook", namespace: "kube-system" });
            expect(replaceNamespacedDeployment).toHaveBeenCalledWith({ name: "app-monitoring-webhook", namespace: "kube-system", body: updatedDeployment });
        });
    });

    describe('GenerateCACertificate', () => {
        it('should generate a CA certificate', async () => {
            jest.spyOn(Date, 'now').mockReturnValue(0);
            const caCert: forge.pki.Certificate = (certManager as any).GenerateCACertificate();
            expect(caCert.subject.attributes[0].value).toStrictEqual('applicationinsights-ca');
            expect(caCert.subject.attributes[0].shortName).toStrictEqual('CN');
            expect(caCert.extensions[0].name).toStrictEqual('basicConstraints');
            expect(caCert.extensions[0].cA).toBeTruthy();
            expect(caCert.extensions[1].name).toStrictEqual('subjectKeyIdentifier');
            expect(caCert.extensions[2].name).toStrictEqual('keyUsage');
            expect(caCert.validity.notBefore).toStrictEqual(new Date(0 - (5 * 60 * 1000)));
            expect(caCert.validity.notAfter).toStrictEqual(new Date(2 * 365 * 24 * 60 * 60 * 1000));
        });
    });

    describe('GenerateHostCertificate', () => { 
        it('should generate a host certificate', async () => {
            jest.spyOn(Date, 'now').mockReturnValue(0);
            const caCert = (certManager as any).GenerateCACertificate();
            const hostCert: forge.pki.Certificate = (certManager as any).GenerateHostCertificate(caCert);
            expect(hostCert.subject.attributes[0].value).toStrictEqual('app-monitoring-webhook-service.kube-system.svc');
            expect(hostCert.subject.attributes[0].shortName).toStrictEqual('CN');
            expect(hostCert.extensions[0].name).toStrictEqual('basicConstraints');
            expect(hostCert.extensions[0].cA).toBeFalsy();
            expect(hostCert.extensions[1].name).toStrictEqual('authorityKeyIdentifier');
            expect(hostCert.extensions[2].name).toStrictEqual('keyUsage');
            expect(hostCert.extensions[3].name).toStrictEqual('extKeyUsage');
            expect(hostCert.extensions[4].name).toStrictEqual('subjectAltName');
            expect(hostCert.validity.notBefore).toStrictEqual(new Date(0 - (5 * 60 * 1000)));
            expect(hostCert.validity.notAfter).toStrictEqual(new Date(2 * 365 * 24 * 60 * 60 * 1000));
            expect(caCert.verify(hostCert)).toBeTruthy();
        });
    });
});

