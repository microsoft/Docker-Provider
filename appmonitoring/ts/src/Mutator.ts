import { Patcher } from "./Patcher.js";
import { logger, RequestMetadata, HeartbeatMetrics } from "./LoggerWrapper.js";
import { PodInfo, IOwnerReference, IAdmissionReview, AppMonitoringConfigCR } from "./RequestDefinition.js";
import { AdmissionReviewValidator } from "./AdmissionReviewValidator.js";
import { AppMonitoringConfigCRsCollection } from "./AppMonitoringConfigCRsCollection.js";

export class Mutator {
    /**
     * Mutates the incoming AdmissionReview of a Pod to enable autoattach features on it
     * @returns An AdmissionReview k8s object that represents a response from the webhook to the API server. Includes the JsonPatch mutation to the incoming AdmissionReview.
     */
    public static async MutatePod(admissionReview: IAdmissionReview, crs: AppMonitoringConfigCRsCollection, clusterArmId: string, clusterArmRegion: string, operationId: string): Promise<string> {
        // this is what we need to return to k8s API server
        const response = {
            apiVersion: "admission.k8s.io/v1",
            kind: "AdmissionReview",
            response: {
                allowed: true, // we only mutate, not admit, so this should always be true as we never want to block any of the customer's API calls
                patch: undefined, // JsonPatch document describing the mutation
                patchType: "JSONPatch",
                uid: "" // must match the uid of the incoming AdmissionReview
            },
        };

        let requestMetadata = new RequestMetadata(null, crs);

        try {
            const mutator: Mutator = new Mutator(admissionReview);
            logger.info(`Original AdmissionReview: ${JSON.stringify(admissionReview)}`, operationId, requestMetadata);

            response.apiVersion = mutator.AdmissionReview.apiVersion;
            response.response.uid = mutator.AdmissionReview.request.uid;
            response.kind = mutator.AdmissionReview.kind;

            requestMetadata = new RequestMetadata(mutator.AdmissionReview.request.uid, crs);
            
            if(!AdmissionReviewValidator.Validate(mutator.AdmissionReview, operationId, requestMetadata)) {
                throw `Validation of the incoming AdmissionReview failed`;
            }

            const podInfo: PodInfo = await mutator.getPodInfo();
            
            const namespace: string = mutator.AdmissionReview.request.object.metadata.namespace;
            if (!namespace) {
                throw `Could not determine the namespace of the incoming object: ${mutator.AdmissionReview}`;
            }

            // find an appropriate CR that dictates whether and how we should mutate
            const cr: AppMonitoringConfigCR = crs.GetCR(namespace, podInfo.deploymentName);
            if (!cr) {
                // no relevant CR found, do not mutate and return with no modifications
                logger.info(`No governing CR found, will not mutate`, operationId, requestMetadata);
                response.response.patch = Buffer.from(JSON.stringify([])).toString("base64");
            } else {
                const armIdMatches = /^\/subscriptions\/(?<SubscriptionId>[^/]+)\/resourceGroups\/(?<ResourceGroup>[^/]+)\/providers\/(?<Provider>[^/]+)\/(?<ResourceType>[^/]+)\/(?<ResourceName>[^/]+).*$/i.exec(clusterArmId);
                if (!armIdMatches || armIdMatches.length != 6) {
                    throw `ARM ID is in a wrong format: ${clusterArmId}`;
                }

                const clusterName = armIdMatches[5];

                logger.info(`Governing CR for the object to be processed (namespace: ${namespace}, deploymentName: ${podInfo.deploymentName}): ${JSON.stringify(cr)}`, operationId, requestMetadata);

                const patchData: object[] = await Patcher.PatchPod(
                    mutator.AdmissionReview,
                    podInfo as PodInfo,
                    cr.spec.autoInstrumentationPlatforms,
                    cr.spec.aiConnectionString,
                    clusterArmId,
                    clusterArmRegion,
                    clusterName);

                response.response.patch = Buffer.from(JSON.stringify(patchData)).toString("base64");

                logger.addHeartbeatMetric(HeartbeatMetrics.AdmissionReviewActionableCount, 1);
            }

            const result = JSON.stringify(response);
            logger.info(`Determined final response ${mutator.uid}, ${result}`, operationId, requestMetadata);
        
            return result;
        } catch (e) {
            logger.addHeartbeatMetric(HeartbeatMetrics.AdmissionReviewActionableFailedCount, 1);
        
            logger.error(`Exception encountered: ${e}`, operationId, requestMetadata);
            
            response.response.patch = undefined;
            return JSON.stringify(response);
        }
    }

    public readonly AdmissionReview: IAdmissionReview;

    private constructor(message: IAdmissionReview) {
        if(!message) {
            throw `Admission review can't be null`;
        }

        this.AdmissionReview = message;
    }

    public get uid() {
        if (this.AdmissionReview && this.AdmissionReview.request && this.AdmissionReview.request.uid) {
            return this.AdmissionReview.request.uid;
        }
        return "";
    }

    private async getPodInfo(): Promise<PodInfo> {
        const podInfo: PodInfo = new PodInfo();

        podInfo.namespace = this.AdmissionReview.request.namespace;
        podInfo.name = this.AdmissionReview.request.object.metadata.name;

        podInfo.onlyContainerName = this.AdmissionReview.request.object.spec.containers?.length == 1 ? this.AdmissionReview.request.object.spec.containers[0].name : null;

        const ownerReference: IOwnerReference | null = this.AdmissionReview.request.object.metadata?.ownerReferences[0];

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
