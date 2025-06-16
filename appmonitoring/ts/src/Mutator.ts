import { Patcher } from "./Patcher.js";
import { logger, RequestMetadata, HeartbeatMetrics } from "./LoggerWrapper.js";
import { PodInfo, IAdmissionReview, InstrumentationCR, AutoInstrumentationPlatforms, DefaultInstrumentationCRName } from "./RequestDefinition.js";
import { AdmissionReviewValidator } from "./AdmissionReviewValidator.js";
import { InstrumentationCRsCollection } from "./InstrumentationCRsCollection.js";
import { Mutations } from "./Mutations.js"

export class Mutator {
    private readonly admissionReview: IAdmissionReview;
    private readonly crs: InstrumentationCRsCollection;
    private readonly clusterArmId: string;
    private readonly clusterArmRegion: string;
    private readonly operationId: string;
    private readonly requestMetadata: RequestMetadata;

    public constructor(admissionReview: IAdmissionReview, crs: InstrumentationCRsCollection, clusterArmId: string, clusterArmRegion: string, operationId: string) {
        this.admissionReview = admissionReview;
        this.crs = crs;
        this.clusterArmId = clusterArmId;
        this.clusterArmRegion = clusterArmRegion;
        this.operationId = operationId;
        this.requestMetadata = new RequestMetadata(this.admissionReview?.request?.uid, this.crs);
    }

    public async Mutate(): Promise<string> {
        const response = this.newResponse();

        try {
            if (!this.admissionReview) {
                throw `Admission review can't be null`;
            }

            if (!AdmissionReviewValidator.Validate(this.admissionReview, this.operationId, this.requestMetadata)) {
                logger.error(`Validation failed on original AdmissionReview: ${JSON.stringify(this.admissionReview)}`, this.operationId, this.requestMetadata);
                throw `Validation of the incoming AdmissionReview failed: ${JSON.stringify(this.admissionReview?.request?.uid)}`;
            } else {
                logger.info(`Validation passed on original AdmissionReview: ${JSON.stringify(this.admissionReview)}`, this.operationId, this.requestMetadata);
            }

            const patch: string = await this.mutateDeployment();
            response.response.patch = patch;

            return JSON.stringify(response);
        } catch (e) {
            const exceptionMessage = `Exception encountered: ${e}${e?.stack ?? ""}`;

            logger.addHeartbeatMetric(HeartbeatMetrics.AdmissionReviewFailedCount, 1, e?.mutationDetails != null ? JSON.stringify(e.mutationDetails) : "");
        
            logger.error(exceptionMessage, this.operationId, this.requestMetadata);
            
            response.response.patch = undefined;
            response.response.status.code = 400;
            response.response.status.message = exceptionMessage;

            return JSON.stringify(response);
        }
    }

    /**
     * Mutates the incoming admission review to enable auto-attach features on its pods
     * @returns An AdmissionReview k8s object that represents a response from the webhook to the API server. Includes the JsonPatch mutation to the incoming AdmissionReview.
     */
    private async mutateDeployment(): Promise<string> {
        const podInfo: PodInfo = this.getPodInfo();
        
        const namespace: string = this.admissionReview.request.object.metadata.namespace;
        if (!namespace) {
            throw `Could not determine the namespace of the incoming object`;
        }

         // find an appropriate CR that dictates whether and how we should mutate
        const crNameToUse: string = this.pickCR();
        const cr: InstrumentationCR = this.crs.GetCR(namespace, crNameToUse);
        
        let clusterName = "";
        let platforms: AutoInstrumentationPlatforms[] = [];

        let mutationDetails: any = null;

        if (!cr) {
            // no relevant CR found, we still need to mutate to remove any prior mutations that may already be there
            logger.info(`No governing CR found (best guess was '${crNameToUse}', but it wasn't found), so we'll reverse mutation if any`, this.operationId, this.requestMetadata);            
        } else {
            const armIdMatches = /^\/subscriptions\/(?<SubscriptionId>[^/]+)\/resourceGroups\/(?<ResourceGroup>[^/]+)\/providers\/(?<Provider>[^/]+)\/(?<ResourceType>[^/]+)\/(?<ResourceName>[^/]+).*$/i.exec(this.clusterArmId);
            if (!armIdMatches || armIdMatches.length != 6) {
                throw `ARM ID is in a wrong format: ${this.clusterArmId}`;
            }

            clusterName = armIdMatches[5];

            platforms = this.pickInstrumentationPlatforms(cr);

            logger.info(`Governing CR for the object to be processed (namespace: ${namespace}, deploymentName: ${podInfo.ownerName}): ${JSON.stringify(cr)} with platforms: ${JSON.stringify(platforms)}`, this.operationId, this.requestMetadata);
            mutationDetails = {
                platforms: platforms,
                images: platforms.map(platform => Mutations.GenerateImagePath(platform))
            };
            logger.addHeartbeatMetric(HeartbeatMetrics.AdmissionReviewActionableCount, 1, JSON.stringify(mutationDetails));
        }

        try {
            const patchData: object[] = Patcher.PatchObject(
                this.admissionReview.request.object,
                cr, // null to unpatch
                podInfo as PodInfo,
                platforms,
                this.clusterArmId,
                this.clusterArmRegion,
                clusterName);

            const patchDataString: string = JSON.stringify(patchData);
            logger.info(`Mutated a deployment, returning: ${patchDataString}`, this.operationId, this.requestMetadata);

            return Buffer.from(patchDataString).toString("base64");
        } catch (e) {
            throw { e: e, mutationDetails: mutationDetails };
        }
    }           

    private newResponse() {
        const response = {
            apiVersion: "admission.k8s.io/v1",
            kind: "AdmissionReview",
            response: {
                allowed: true, // we only mutate, not admit, so this should always be true as we never want to block any of the customer's API calls
                patch: undefined, // JsonPatch document describing the mutation
                patchType: "JSONPatch",
                uid: "", // must match the uid of the incoming AdmissionReview,
                status: {
                    code: 200, // indicate the type of success/error to k8s
                    message: "OK"
                }
            },
        };

        response.apiVersion = this.admissionReview?.apiVersion;
        response.response.uid = this.admissionReview?.request?.uid;
        response.kind = this.admissionReview?.kind;

        return response;
    }

    private getPodInfo(): PodInfo {
        const podInfo: PodInfo = new PodInfo();

        podInfo.namespace = this.admissionReview.request.object.metadata.namespace;
        podInfo.onlyContainerName = this.admissionReview.request.object.spec.template.spec.containers?.length === 1 ? this.admissionReview.request.object.spec.template.spec.containers[0].name : null;
        podInfo.ownerKind = this.admissionReview.request.object.kind?.toLowerCase();
        podInfo.ownerName = this.admissionReview.request.object.metadata.name;
        podInfo.ownerUid = this.admissionReview.request.object.metadata.uid;
                
        return podInfo;
    }

    /**
     * Based on the admission review's inject-* annotations and available CRs, picks a CR to be applied to the admission review
     */
    private pickCR(): string {
        const injectJavaAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/inject-java"];
        const injectNodeJsAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/inject-nodejs"];
        const injectPythonAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/private-preview-inject-python"];
        const injectDotNetAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/private-preview-inject-dotnet"];
        const injectConfigurationAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/inject-configuration"];

        const injectLanguageSpecificAnnotationValues: string[] = [injectJavaAnnotation, injectNodeJsAnnotation, injectPythonAnnotation, injectDotNetAnnotation];

        // if any of the annotations contain a value other than "true" or "false", that must be the same value for all annotations, we can't apply multiple CRs to the same pod
        const specificCRNamesFromLanguageSpecific: string[] = injectLanguageSpecificAnnotationValues.filter(value => value && value.toLowerCase() !== "true" && value.toLowerCase() !== "false");
        if(specificCRNamesFromLanguageSpecific.length > 0 && specificCRNamesFromLanguageSpecific.filter(value => value?.toLowerCase() === specificCRNamesFromLanguageSpecific[0].toLowerCase()).length != specificCRNamesFromLanguageSpecific.length) {
            throw `Multiple specific CR names specified in instrumentation.opentelemetry.io/inject-* annotations, that is not supported.`;
        }

        // remove this when we are ready to ship the inject-configuration annotation
        if(injectConfigurationAnnotation) {
            throw `inject-configuration annotation is not supported yet, please use language-specific inject-* annotations instead.`;
        }

        // if there's a inject-configuration annotation, no language-specific annotations are allowed
        if(injectConfigurationAnnotation && injectLanguageSpecificAnnotationValues.filter(value => value).length > 0) {
            throw `Mix of language-specific instrumentation.opentelemetry.io/inject-* annotations with instrumentation.opentelemetry.io/inject-configuration annotation, that is not supported.`;
        }

        const crNameFromConfiguration: string = (injectConfigurationAnnotation?.toLowerCase() !== "true" && injectConfigurationAnnotation?.toLowerCase() !== "false") ? injectConfigurationAnnotation : null;

        // specific CR name in language-specific injects
        if(specificCRNamesFromLanguageSpecific.length > 0) {
            return specificCRNamesFromLanguageSpecific[0];
        }
        
        // specific CR name in configuration inject
        if(crNameFromConfiguration) {
            return crNameFromConfiguration;
        }
        
        // at least one language-specific inject is set to true
        if(injectLanguageSpecificAnnotationValues.filter(value => value?.toLowerCase() === "true").length > 0) {
            return DefaultInstrumentationCRName;
        }

        // configuration inject set to true
        if(injectConfigurationAnnotation?.toLowerCase() === "true") {
            return DefaultInstrumentationCRName;
        }

        // no injects at all (language-specific or otherwise)
        if(injectLanguageSpecificAnnotationValues.filter(value => value).length === 0 && !injectConfigurationAnnotation) {
            return DefaultInstrumentationCRName;
        }
        
        // all injects are set to false, do not mutate
        return null;
    }

    /**
     * Based on a CR and inject- annotations, decides which instrumentation platforms to support during auto-instrumentation
     */
    private pickInstrumentationPlatforms(cr: InstrumentationCR): AutoInstrumentationPlatforms[] {
        if(!cr) {
            throw `CR is null.`
        }

        // assuming annotation set is valid
        // annotations are on the pod template spec
        const injectJavaAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/inject-java"];
        const injectNodeJsAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/inject-nodejs"];
        const injectPythonAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/private-preview-inject-python"];
        const injectDotNetAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/private-preview-inject-dotnet"];
        const injectConfigurationAnnotation: string = this.admissionReview.request.object.spec.template.metadata?.annotations?.["instrumentation.opentelemetry.io/inject-configuration"];

        const injectAnnotationValues: string[] = [injectJavaAnnotation, injectNodeJsAnnotation, injectPythonAnnotation, injectDotNetAnnotation, injectConfigurationAnnotation];

        if(injectAnnotationValues.filter(value => value).length == 0) {
            // no annotations specified, use platform list from the CR
            // this is only possible for the default CR (it was assumed in the absence of annotations)
            return cr.spec.settings.autoInstrumentationPlatforms;
        }

        const platforms: AutoInstrumentationPlatforms[] = [];

        if (injectJavaAnnotation && injectJavaAnnotation.toLowerCase() !== "false") {
            platforms.push(AutoInstrumentationPlatforms.Java);
        }

        if (injectNodeJsAnnotation && injectNodeJsAnnotation.toLowerCase() !== "false") {
            platforms.push(AutoInstrumentationPlatforms.NodeJs);
        }

        if (injectPythonAnnotation && injectPythonAnnotation.toLowerCase() !== "false") {
            platforms.push(AutoInstrumentationPlatforms.Python);
        }

        if (injectDotNetAnnotation && injectDotNetAnnotation.toLowerCase() !== "false") {
            platforms.push(AutoInstrumentationPlatforms.DotNet);
        }

        return platforms;
    }
}
