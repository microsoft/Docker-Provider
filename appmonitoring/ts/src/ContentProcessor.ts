import { isNullOrUndefined } from "util";
import { DiffCalculator } from "./DiffCalculator.js";
import { logger, Metrics } from "./LoggerWrapper.js";
import { PodInfo, IOwnerReference, IRootObject, AppMonitoringConfigCR } from "./RequestDefinition.js";
import { TemplateValidator } from "./TemplateValidator.js";
import { AppMonitoringConfigCRsCollection } from "./AppMonitoringConfigCRsCollection.js";

export class ContentProcessor {
    public static async TryUpdateConfig(message: string, crs: AppMonitoringConfigCRsCollection): Promise<string> {
        const response = {
            apiVersion: "admission.k8s.io/v1",
            kind: "AdmissionReview",
            request: undefined,
            response: {
                allowed: false, // when error it is ignored as per the config
                patch: undefined,
                patchType: "JSONPatch",
                uid: "",
            },
        };

        try {
            const instance: ContentProcessor = new ContentProcessor(message);

            logger.telemetry(Metrics.CPStart, 1, instance.uid);

            response.request = instance.content.request;
            response.apiVersion = instance.content.apiVersion;
            response.response.uid = instance.content.request.uid;
            response.kind = instance.content.kind;
            response.response.allowed = TemplateValidator.ValidateContent(instance.content);

            const podInfo: PodInfo = await instance.getPodInfo();
            logger.info(`Extracted PodInfo: ${JSON.stringify(podInfo)}`);

            const namespace: string = instance.content.request.object.metadata.namespace;
            if (!namespace) {
                throw `Could not determine the namespace of the incoming object: ${namespace}`;
            }

            if (response.response.allowed) {
                const cr: AppMonitoringConfigCR = crs.GetCR(namespace, podInfo.deploymentName);
                if (!cr) {
                    // no relevant CR found, do not mutate and return with no modifications
                    // do not block the request though, allowed should remain true
                    logger.info(`No governing CR found, will not mutate`);
                    response.response.patch = Buffer.from(JSON.stringify([])).toString("base64");
                } else {
                    const armIdMatches = /^\/subscriptions\/(?<SubscriptionId>[^/]+)\/resourceGroups\/(?<ResourceGroup>[^/]+)\/providers\/(?<Provider>[^/]+)\/(?<ResourceType>[^/]+)\/(?<ResourceName>[^/]+).*$/i.exec(process.env.ARM_ID);
                    if (!armIdMatches || armIdMatches.length != 6) {
                        throw `ARM ID is in a wrong format: ${process.env.ARM_ID}`;
                    }

                    const clusterName = armIdMatches[5];

                    logger.info(`Governing CR for the object to be processed (namespace: ${namespace}, deploymentName: ${podInfo.deploymentName}): ${JSON.stringify(cr)}`);
                    response.response.patch = Buffer.from(JSON.stringify(await DiffCalculator.CalculateDiff(
                        instance.content,
                        podInfo as PodInfo,
                        cr.spec.autoInstrumentationPlatforms,
                        cr.spec.aiConnectionString,
                        process.env.ARM_ID,
                        process.env.ARM_REGION,
                        clusterName))).toString("base64");

                    logger.telemetry(Metrics.CPSuccess, 1, instance.uid);
                }
            } else {
                logger.telemetry(Metrics.CPFail, 1, instance.uid);
            }

            const finalResult = JSON.stringify(response);
            logger.info(`Determined final response ${instance.uid}, ${finalResult}`);
            return finalResult;

        } catch (e) {
            logger.error(`Exception encountered: ${e}`);
            logger.telemetry(Metrics.CPError, 1, "");
            return JSON.stringify(response);
        }
    }

    public readonly content: IRootObject;

    private constructor(message: string) {

        if (message === "" || isNullOrUndefined(message)) {
            throw new RangeError("message");
        }

        try {
            this.content = JSON.parse(message);
            logger.info(`Parsed incoming message content, Initialized ContentProcessor. ${this.uid}, ${message}`);
        } catch (ex) {
            logger.error(`Exception encountered parsing input ${this.uid}, ${ex}, ${message}`);
            throw ex;
        }
    }

    public get uid() {
        if (this.content && this.content.request && this.content.request.uid) {
            return this.content.request.uid;
        }
        return "";
    }

    private async getPodInfo(): Promise<PodInfo> {
        logger.info(`Attempting to get owner info ${this.uid}`);

        const podInfo: PodInfo = new PodInfo();

        podInfo.namespace = this.content.request.namespace;
        podInfo.name = this.content.request.object.metadata.name;

        podInfo.onlyContainerName = this.content.request.object.spec.containers?.length == 1 ? this.content.request.object.spec.containers[0].name : null;

        const ownerReference: IOwnerReference | null = this.content.request.object.metadata?.ownerReferences[0];

        if(ownerReference?.kind) {
            podInfo.ownerReference = ownerReference;
            
            if(ownerReference.kind.localeCompare("ReplicaSet", undefined, { sensitivity: 'accent' }) === 0) {
                // the owner is a replica set, so we need to try to get to the deployment
                // while it is possible to name a bare ReplicaSet (not produced by a Deployment) in a way that will fool the regex, we are ignoring that corner case
                const matches = /^\b(?<!-)(?<role_name>[a-z0-9]+(?:-[a-z0-9]+)*?)(?:-([a-f0-9]{8-12}))?-([a-z0-9]+)$/i.exec(ownerReference.name);
                if(matches && matches.length > 0) {
                    podInfo.deploymentName = matches[1];
                } else {
                    podInfo.deploymentName = null;
                }                             
            }
        }
                
        return Promise.resolve(podInfo);
    }
}
