import { expect, describe, it } from "@jest/globals";
import { Mutations } from "Mutations.js";
import { IAdmissionReview, PodInfo, IContainer, IVolume, AutoInstrumentationPlatforms, IEnvironmentVariable, InstrumentationCR, IInstrumentationState, IObjectType, InstrumentationAnnotationName, EnableApplicationLogsAnnotationName, OtelParams } from "RequestDefinition.js";
import { Patcher } from "Patcher.js";
import { cr, clusterArmId, clusterArmRegion, clusterName, TestDeployment2 } from "tests/testConsts.js";
import { logger } from "LoggerWrapper.js"

const testOtelParams: OtelParams = {
    logsEnabled: true,
    metricsEnabled: true,
    logsPortHttpProtobuf: 0,
    metricsPortHttpProtobuf: 0
};

beforeEach(() => {
    logger.setUnitTestMode(true);
});

afterEach(() => {
    jest.restoreAllMocks();
});

describe("Patcher", () => {
    it("Patches a deployment correctly", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));

        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        const platforms = cr1.spec.settings.autoInstrumentationPlatforms;
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { 
            preExistingAnnotationName: "preExistingAnnotationValue",
        };

        admissionReview.request.object.spec.template.metadata.annotations[EnableApplicationLogsAnnotationName] = "false"

        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

        expect((<[]>result).length).toBe(1);
        
        const obj: IObjectType = (<any>result[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;
        expect(annotationValue.crName).toBe(cr1.metadata.name);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]);

        expect((<any>result[0]).op).toBe("replace");
        expect((<any>result[0]).path).toBe("");
        expect((<any>result[0]).value).not.toBeNull();
        
        const newInitContainers: IContainer[] = Mutations.GenerateInitContainers(platforms);
        expect((<any>result[0]).value.spec.template.spec.initContainers.length).toBe(admissionReview.request.object.spec.template.spec.initContainers.length + newInitContainers.length);
        newInitContainers.forEach(ic => expect((<any>result[0]).value.spec.template.spec.initContainers).toContainEqual(ic));
        admissionReview.request.object.spec.template.spec.initContainers.forEach(ic => expect((<any>result[0]).value.spec.template.spec.initContainers).toContainEqual(ic));

        const newVolumes: IVolume[] = Mutations.GenerateVolumes(platforms);
        expect((<any>result[0]).value.spec.template.spec.volumes.length).toBe(admissionReview.request.object.spec.template.spec.volumes.length + newVolumes.length);
        newVolumes.forEach(vol => expect((<any>result[0]).value.spec.template.spec.volumes).toContainEqual(vol));
        admissionReview.request.object.spec.template.spec.volumes.forEach(vol => expect((<any>result[0]).value.spec.template.spec.volumes).toContainEqual(vol));

        const newEnvironmentVariables: object[] = Mutations.GenerateEnvironmentVariables(podInfo, platforms, true, cr1.spec.destination.applicationInsightsConnectionString, clusterArmId, clusterArmRegion, clusterName, testOtelParams);
        expect((<any>result[0]).value.spec.template.spec.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newEnvironmentVariables.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        newEnvironmentVariables.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[0].env.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[1].env.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));

        const newVolumeMounts: object[] = Mutations.GenerateVolumeMounts(platforms);
        expect((<any>result[0]).value.spec.template.spec.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newVolumeMounts.forEach(vm => expect((<any>result[0]).value.spec.template.spec.containers[0].volumeMounts).toContainEqual(vm));
        newVolumeMounts.forEach(vm => expect((<any>result[0]).value.spec.template.spec.containers[1].volumeMounts).toContainEqual(vm));
        admissionReview.request.object.spec.template.spec.containers[0].volumeMounts.forEach(vm => expect((<any>result[0]).value.spec.template.spec.containers[0].volumeMounts).toContainEqual(vm));
        admissionReview.request.object.spec.template.spec.containers[1].volumeMounts.forEach(vm => expect((<any>result[0]).value.spec.template.spec.containers[1].volumeMounts).toContainEqual(vm));
    });

    it("Patches a deployment if no auto-instrumentation is specified", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));

        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        cr1.spec.settings.autoInstrumentationPlatforms = [];
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { 
            preExistingAnnotationName: "preExistingAnnotationValue"
        };

        admissionReview.request.object.spec.template.metadata.annotations[EnableApplicationLogsAnnotationName] = "false"

        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, cr1.spec.settings.autoInstrumentationPlatforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

        expect((<[]>result).length).toBe(1);

        const obj: IObjectType = (<any>result[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;

        expect(annotationValue.crName).toBe(cr1.metadata.name);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([]);        

        expect((<any>result[0]).op).toBe("replace");
        expect((<any>result[0]).path).toBe("");
        expect((<any>result[0]).value).not.toBeNull();
        
        const newInitContainers: IContainer[] = Mutations.GenerateInitContainers(cr1.spec.settings.autoInstrumentationPlatforms);
        expect((<any>result[0]).value.spec.template.spec.initContainers.length).toBe(admissionReview.request.object.spec.template.spec.initContainers.length + newInitContainers.length);
        newInitContainers.forEach(ic => expect((<any>result[0]).value.template.spec.initContainers).toContainEqual(ic));
        admissionReview.request.object.spec.template.spec.initContainers.forEach(ic => expect((<any>result[0]).value.spec.template.spec.initContainers).toContainEqual(ic));

        const newVolumes: IVolume[] = Mutations.GenerateVolumes(cr1.spec.settings.autoInstrumentationPlatforms);
        expect((<any>result[0]).value.spec.template.spec.volumes.length).toBe(admissionReview.request.object.spec.template.spec.volumes.length + newVolumes.length);
        newVolumes.forEach(vol => expect((<any>result[0]).value.spec.template.spec.volumes).toContainEqual(vol));
        admissionReview.request.object.spec.template.spec.volumes.forEach(vol => expect((<any>result[0]).value.spec.template.spec.volumes).toContainEqual(vol));

        const newEnvironmentVariables: object[] = Mutations.GenerateEnvironmentVariables(podInfo, cr1.spec.settings.autoInstrumentationPlatforms, true, cr1.spec.destination.applicationInsightsConnectionString, clusterArmId, clusterArmRegion, clusterName, testOtelParams);
        expect((<any>result[0]).value.spec.template.spec.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newEnvironmentVariables.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        newEnvironmentVariables.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[0].env.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[1].env.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));
        (<any>result[0]).value.spec.template.spec.containers[0].env.forEach(env => expect(env.isPlatformSpecific).not.toBe(true));
        (<any>result[0]).value.spec.template.spec.containers[1].env.forEach(env => expect(env.isPlatformSpecific).not.toBe(true));
        expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(<IEnvironmentVariable>{ name: "OTEL_RESOURCE_ATTRIBUTES", value: "cloud.resource_id=/subscriptions/66010356-d8a5-42d3-8593-6aaa3aeb1c11/resourceGroups/rambhatt-rnd-v2/providers/Microsoft.ContainerService/managedClusters/aks-rambhatt-test,cloud.region=eastus,k8s.cluster.name=aks-rambhatt-test,k8s.namespace.name=$(POD_NAMESPACE),k8s.node.name=$(NODE_NAME),k8s.pod.name=$(POD_NAME),k8s.pod.uid=$(POD_UID),k8s.container.name=container1,cloud.provider=Azure,cloud.platform=azure_aks,k8s.deployment.name=deployment1,k8s.deployment.uid=ownerUid" });
        expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(<IEnvironmentVariable>{ name: "APPLICATIONINSIGHTS_CONNECTION_STRING", value: cr1.spec.destination.applicationInsightsConnectionString });


        const newVolumeMounts: object[] = Mutations.GenerateVolumeMounts(cr1.spec.settings.autoInstrumentationPlatforms);
        expect((<any>result[0]).value.spec.template.spec.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newVolumeMounts.forEach(vm => expect((<any>result[0]).value.spec.template.spec.containers[0].volumeMounts).toContainEqual(vm));
        newVolumeMounts.forEach(vm => expect((<any>result[0]).value.spec.template.spec.containers[1].volumeMounts).toContainEqual(vm));
        admissionReview.request.object.spec.template.spec.containers[0].volumeMounts.forEach(vm => expect((<any>result[0]).value.spec.template.spec.containers[0].volumeMounts).toContainEqual(vm));
        admissionReview.request.object.spec.template.spec.containers[1].volumeMounts.forEach(vm => expect((<any>result[0]).value.spec.template.spec.containers[1].volumeMounts).toContainEqual(vm));
    });

    it("Unpatches a deployment correctly", async () => {
        // ASSUME
        const initialAdmissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        initialAdmissionReview.request.object.metadata.namespace = "ns1";
        initialAdmissionReview.request.object.metadata.annotations = { 
            preExistingAnnotationName: "preExistingAnnotationValue"
        };

        const mutatedAdmissionReview: IAdmissionReview = JSON.parse(JSON.stringify(initialAdmissionReview));

        const patchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, cr, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ACT
        // unpatch since CR is empty
        const unpatchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect(JSON.stringify(mutatedAdmissionReview)).toBe(JSON.stringify(initialAdmissionReview));

        expect(unpatchResult.length).toBe(1);

        const obj: IObjectType = (<any>unpatchResult[0]).value as IObjectType;
        expect(obj.metadata?.annotations?.[InstrumentationAnnotationName]).toBeUndefined();

        expect((<any>unpatchResult[0]).op).toBe("replace");
        expect((<any>unpatchResult[0]).path).toBe("");
        expect(JSON.stringify((<any>unpatchResult[0]).value.spec.template.spec)).toBe(JSON.stringify(initialAdmissionReview.request.object.spec.template.spec));
    });

    it("Unpatches a deployment that is not patched", async () => {
        // ASSUME
        const initialAdmissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        initialAdmissionReview.request.object.metadata.namespace = "ns1";
        initialAdmissionReview.request.object.metadata.annotations = { 
            preExistingAnnotationName: "preExistingAnnotationValue"
        };

        const mutatedAdmissionReview: IAdmissionReview = JSON.parse(JSON.stringify(initialAdmissionReview));

        // ACT
        // unpatch (since CR is null) a non-mutated deployment
        const unpatchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect(JSON.stringify(mutatedAdmissionReview)).toBe(JSON.stringify(initialAdmissionReview));

        expect(unpatchResult.length).toBe(1);

        const obj: IObjectType = (<any>unpatchResult[0]).value as IObjectType;
        expect(obj.metadata?.annotations?.[InstrumentationAnnotationName]).toBeUndefined();

        expect((<any>unpatchResult[0]).op).toBe("replace");
        expect((<any>unpatchResult[0]).path).toBe("");
        expect(JSON.stringify((<any>unpatchResult[0]).value.spec.template.spec)).toBe(JSON.stringify(initialAdmissionReview.request.object.spec.template.spec));
    });

    it("Unpatches a deployment that is not patched and has no annotations", async () => {
        // ASSUME
        const initialAdmissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        initialAdmissionReview.request.object.metadata.namespace = "ns1";
        initialAdmissionReview.request.object.metadata.annotations = null;

        const mutatedAdmissionReview: IAdmissionReview = JSON.parse(JSON.stringify(initialAdmissionReview));

        // ACT
        // unpatch (since CR is null) a non-mutated deployment
        const unpatchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect(JSON.stringify(mutatedAdmissionReview)).toBe(JSON.stringify(initialAdmissionReview));

        expect(unpatchResult.length).toBe(1);

        const obj: IObjectType = (<any>unpatchResult[0]).value as IObjectType;
        expect(obj.metadata?.annotations?.[InstrumentationAnnotationName]).toBeUndefined();

        expect((<any>unpatchResult[0]).op).toBe("replace");
        expect((<any>unpatchResult[0]).path).toBe("");
        expect(JSON.stringify((<any>unpatchResult[0]).value.spec.template.spec)).toBe(JSON.stringify(initialAdmissionReview.request.object.spec.template.spec));
    });

    it("Does not patch if no CR", async () => {
        // ASSUME
        const initialAdmissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        initialAdmissionReview.request.object.metadata.namespace = "ns1";
        initialAdmissionReview.request.object.metadata.annotations = { 
            preExistingAnnotationName: "preExistingAnnotationValue"
        };

        const mutatedAdmissionReview: IAdmissionReview = JSON.parse(JSON.stringify(initialAdmissionReview));

        // ACT
        const patchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, null, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect(JSON.stringify(mutatedAdmissionReview)).toBe(JSON.stringify(initialAdmissionReview));

        expect(patchResult.length).toBe(1);

        const obj: IObjectType = (<any>patchResult[0]).value as IObjectType;
        expect(obj.metadata?.annotations?.[InstrumentationAnnotationName]).toBeUndefined();
        
        expect((<any>patchResult[0]).op).toBe("replace");
        expect((<any>patchResult[0]).path).toBe("");
        expect(JSON.stringify((<any>patchResult[0]).value.spec.template.spec)).toBe(JSON.stringify(initialAdmissionReview.request.object.spec.template.spec));
    });

    it("Restores conflicting environment variables during unpatch", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr.metadata.namespace;

        // conflicting environment variable
        admissionReview.request.object.spec.template.spec.containers[0].env = [
            {
                "name": "NODE_NAME",
                "value": "original conflicting value for node name"
            },
            {
                "name": "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED",
                "value": "original conflicting value for Java logging enabled"
            },
            {
                "name": "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT",
                "value": "original conflicting value for NodeJs configuration content"
            }
        ];

        // ACT
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(3);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe("original conflicting value for NodeJs configuration content");
    });

    it("Restores conflicting environment variables during unpatch when patch was not with all platforms", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        cr1.spec.settings.autoInstrumentationPlatforms = [AutoInstrumentationPlatforms.Java];
        const platforms = cr1.spec.settings.autoInstrumentationPlatforms;

        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        // conflicting environment variable
        admissionReview.request.object.spec.template.spec.containers[0].env = [
            {
                "name": "NODE_NAME",
                "value": "original conflicting value for node name"
            },
            {
                "name": "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED",
                "value": "original conflicting value for Java logging enabled"
            },
            {
                "name": "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT",
                "value": "original conflicting value for NodeJs configuration content"
            }
        ];

        // ACT
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(3);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe("original conflicting value for NodeJs configuration content");
    });

    it("Handles empty environment variable list", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr.metadata.namespace;

        // no environment variables
        admissionReview.request.object.spec.template.spec.containers[0].env = [];

        // ACT
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.length).toBeGreaterThan(0);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(0);
    });

    it("Disables app logs by default correctly", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr.metadata.namespace;

        // conflicting environment variable
        admissionReview.request.object.spec.template.spec.containers[0].env = [
            {
                "name": "NODE_NAME",
                "value": "original conflicting value for node name"
            },
            {
                "name": "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED",
                "value": "original conflicting value for Java logging enabled"
            },
            // {
            //     "name": "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT",
            //     "value": "original conflicting value for NodeJs configuration content"
            // }
        ];

        // ACT
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").valueFrom.fieldRef.fieldPath).toBe("spec.nodeName");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("false");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe(`{"instrumentationOptions":{"console": { "enabled": false }, "bunyan": { "enabled": false },"winston": { "enabled": false }}}`);

        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for node name");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT_BEFORE_AUTO_INSTRUMENTATION")?.value).toBeUndefined();

        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(2);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT")?.value).toBeUndefined();
    });

    it("Leaves app logs enabled when app logs are enabled by customer via annotation", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));

        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        admissionReview.request.object.spec.template.metadata.annotations[EnableApplicationLogsAnnotationName] = "true"

        // conflicting environment variable
        admissionReview.request.object.spec.template.spec.containers[0].env = [
            {
                "name": "NODE_NAME",
                "value": "original conflicting value for node name"
            },
            {
                "name": "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED",
                "value": "original conflicting value for Java logging enabled"
            },
            {
                "name": "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT",
                "value": "original conflicting value for NodeJs configuration content"
            }
        ];

        // ACT
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").valueFrom.fieldRef.fieldPath).toBe("spec.nodeName");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe("original conflicting value for NodeJs configuration content");

        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for node name");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for NodeJs configuration content");

        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(3);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe("original conflicting value for NodeJs configuration content");
    });

    it("Disables app logs when app logs are disabled by customer via annotation", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));

        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        admissionReview.request.object.spec.template.metadata.annotations[EnableApplicationLogsAnnotationName] = "false"

        // conflicting environment variable
        admissionReview.request.object.spec.template.spec.containers[0].env = [
            {
                "name": "NODE_NAME",
                "value": "original conflicting value for node name"
            },
            {
                "name": "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED",
                "value": "original conflicting value for Java logging enabled"
            },
            // {
            //     "name": "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT",
            //     "value": "original conflicting value for NodeJs configuration content"
            // }
        ];

        // ACT
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName, testOtelParams)));

        // ASSERT
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").valueFrom.fieldRef.fieldPath).toBe("spec.nodeName");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("false");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe(`{"instrumentationOptions":{"console": { "enabled": false }, "bunyan": { "enabled": false },"winston": { "enabled": false }}}`);

        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for node name");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT_BEFORE_AUTO_INSTRUMENTATION")?.value).toBeUndefined();

        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(2);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT")?.value).toBeUndefined();
    });

    it("Attribute microsoft.applicationId - set when ApplicationID is present in connection string", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        // Set connection string with ApplicationID
        cr1.spec.destination.applicationInsightsConnectionString = "InstrumentationKey=test-key;ApplicationID=test-app-id;IngestionEndpoint=https://test.endpoint/";
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment", 
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        // Test with platforms
        const platforms = [AutoInstrumentationPlatforms.Java];
        
        // ACT
        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

        // ASSERT
        expect((<[]>result).length).toBe(1);
        
        const otelResourceAttrsEnv = (<any>result[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv).toBeDefined();
        expect(otelResourceAttrsEnv.value).toContain("microsoft.applicationId=test-app-id");
    });

    it("Attribute microsoft.applicationId - set when ApplicationID is present and platforms array is empty", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        // Set connection string with ApplicationID and empty platforms
        cr1.spec.destination.applicationInsightsConnectionString = "InstrumentationKey=test-key;ApplicationID=test-app-id-empty;IngestionEndpoint=https://test.endpoint/";
        cr1.spec.settings.autoInstrumentationPlatforms = [];
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;
        
        // ACT
        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, cr1.spec.settings.autoInstrumentationPlatforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

        // ASSERT
        expect((<[]>result).length).toBe(1);
        
        const otelResourceAttrsEnv = (<any>result[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv).toBeDefined();
        expect(otelResourceAttrsEnv.value).toContain("microsoft.applicationId=test-app-id-empty");
    });

    it("Attribute microsoft.applicationId - not set when ApplicationID is not present in connection string", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        // Set connection string without ApplicationID
        cr1.spec.destination.applicationInsightsConnectionString = "InstrumentationKey=test-key;IngestionEndpoint=https://test.endpoint/";
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default", 
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        // Test with platforms
        const platforms = [AutoInstrumentationPlatforms.Java];
        
        // ACT
        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

        // ASSERT
        expect((<[]>result).length).toBe(1);
        
        const otelResourceAttrsEnv = (<any>result[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv).toBeDefined();
        expect(otelResourceAttrsEnv.value).not.toContain("microsoft.applicationId");
    });

    it("Attribute microsoft.applicationId - not set when ApplicationID is not present and platforms array is empty", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        // Set connection string without ApplicationID and empty platforms
        cr1.spec.destination.applicationInsightsConnectionString = "InstrumentationKey=test-key;IngestionEndpoint=https://test.endpoint/";
        cr1.spec.settings.autoInstrumentationPlatforms = [];
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1", 
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;
        
        // ACT
        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, cr1.spec.settings.autoInstrumentationPlatforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

        // ASSERT
        expect((<[]>result).length).toBe(1);
        
        const otelResourceAttrsEnv = (<any>result[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv).toBeDefined();
        expect(otelResourceAttrsEnv.value).not.toContain("microsoft.applicationId");
    });

    it("OTEL environment variables - includes all OTEL variables when both logsEnabled and metricsEnabled are true", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        const otelParamsEnabled: OtelParams = {
            logsEnabled: true,
            metricsEnabled: true,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };
        
        // ACT
        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, [AutoInstrumentationPlatforms.Java], clusterArmId, clusterArmRegion, clusterName, otelParamsEnabled);

        // ASSERT
        expect((<[]>result).length).toBe(1);
        
        const containerEnv = (<any>result[0]).value.spec.template.spec.containers[0].env;
        
        // Should include OTEL_ENDPOINT_NODE_IP (required for both logs and metrics)
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_ENDPOINT_NODE_IP")).toBeDefined();
        
        // Should include logs-related variables
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_INSECURE")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_INSECURE")).toBeDefined();
        
        // Should include metrics-related variables
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_INSECURE")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_METRICS_EXPORTER")).toBeDefined();

        // Verify correct port values
        const tracesEndpointEnv = containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
        expect(tracesEndpointEnv.value).toBe("http://$(OTEL_ENDPOINT_NODE_IP):4318/v1/traces");
        
        const logsEndpointEnv = containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT");
        expect(logsEndpointEnv.value).toBe("http://$(OTEL_ENDPOINT_NODE_IP):4318/v1/logs");
        
        const metricsEndpointEnv = containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
        expect(metricsEndpointEnv.value).toBe("http://$(OTEL_ENDPOINT_NODE_IP):4319/v1/metrics");

        const metricsExporterEnv = containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_METRICS_EXPORTER");
        expect(metricsExporterEnv.value).toBe("otlp");
    });

    it("OTEL environment variables - includes only logs variables when only logsEnabled is true", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        const otelParamsLogsOnly: OtelParams = {
            logsEnabled: true,
            metricsEnabled: false,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };
        
        // ACT
        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, [AutoInstrumentationPlatforms.Java], clusterArmId, clusterArmRegion, clusterName, otelParamsLogsOnly);

        // ASSERT
        expect((<[]>result).length).toBe(1);
        
        const containerEnv = (<any>result[0]).value.spec.template.spec.containers[0].env;
        
        // Should include OTEL_ENDPOINT_NODE_IP (required for logs)
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_ENDPOINT_NODE_IP")).toBeDefined();
        
        // Should include logs-related variables
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_INSECURE")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_INSECURE")).toBeDefined();
        
        // Should NOT include metrics-related variables
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_INSECURE")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_METRICS_EXPORTER")).toBeUndefined();
    });

    it("OTEL environment variables - includes only metrics variables when only metricsEnabled is true", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        const otelParamsMetricsOnly: OtelParams = {
            logsEnabled: false,
            metricsEnabled: true,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };
        
        // ACT
        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, [AutoInstrumentationPlatforms.Java], clusterArmId, clusterArmRegion, clusterName, otelParamsMetricsOnly);

        // ASSERT
        expect((<[]>result).length).toBe(1);
        
        const containerEnv = (<any>result[0]).value.spec.template.spec.containers[0].env;
        
        // Should include OTEL_ENDPOINT_NODE_IP (required for metrics)
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_ENDPOINT_NODE_IP")).toBeDefined();
        
        // Should NOT include logs-related variables
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_INSECURE")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_INSECURE")).toBeUndefined();
        
        // Should include metrics-related variables
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_INSECURE")).toBeDefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_METRICS_EXPORTER")).toBeDefined();

        const metricsExporterEnv = containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_METRICS_EXPORTER");
        expect(metricsExporterEnv.value).toBe("otlp");
    });

    it("OTEL environment variables - excludes all OTEL variables when both logsEnabled and metricsEnabled are false", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid",
            onlyContainerName: "container1"
        };

        admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;

        const otelParamsDisabled: OtelParams = {
            logsEnabled: false,
            metricsEnabled: false,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };
        
        // ACT
        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, [AutoInstrumentationPlatforms.Java], clusterArmId, clusterArmRegion, clusterName, otelParamsDisabled);

        // ASSERT
        expect((<[]>result).length).toBe(1);
        
        const containerEnv = (<any>result[0]).value.spec.template.spec.containers[0].env;
        
        // Should NOT include OTEL_ENDPOINT_NODE_IP (not needed when both are disabled)
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_ENDPOINT_NODE_IP")).toBeUndefined();
        
        // Should NOT include any OTEL exporter variables
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_TRACES_INSECURE")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_LOGS_INSECURE")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_EXPORTER_OTLP_METRICS_INSECURE")).toBeUndefined();
        expect(containerEnv.find((ev: IEnvironmentVariable) => ev.name === "OTEL_METRICS_EXPORTER")).toBeUndefined();
    });

    describe("OTEL Resource Attributes Merging", () => {
        const podInfo = new PodInfo();
        podInfo.ownerKind = "Deployment";
        podInfo.ownerName = "test-app";
        podInfo.ownerUid = "uid-123";
        podInfo.onlyContainerName = "main-container";

        const testOtelParams: OtelParams = {
            logsEnabled: false,
            metricsEnabled: false,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4318
        };

        it("should merge OTEL_RESOURCE_ATTRIBUTES with existing attributes", () => {
            // Create a test deployment with existing OTEL_RESOURCE_ATTRIBUTES
            const testDeployment = JSON.parse(JSON.stringify(TestDeployment2.request.object));
            testDeployment.spec.template.spec.containers[0].env = [{
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "service.name=my-service,service.version=1.0.0,custom.attr=value"
            }];

            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            const platforms = [AutoInstrumentationPlatforms.Java];

            const result: object[] = Patcher.PatchObject(testDeployment, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

            const obj: IObjectType = (<any>result[0]).value as IObjectType;
            const containerEnv = obj.spec.template.spec.containers[0].env;
            const otelResourceAttributes = containerEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            
            expect(otelResourceAttributes).toBeDefined();
            expect(otelResourceAttributes!.value).toContain("service.name=my-service");
            expect(otelResourceAttributes!.value).toContain("service.version=1.0.0");
            expect(otelResourceAttributes!.value).toContain("custom.attr=value");
            expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure");
            expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=" + clusterName);
        });

        it("should handle conflicting attributes with our attributes winning", () => {
            // Create a test deployment with conflicting OTEL_RESOURCE_ATTRIBUTES
            const testDeployment = JSON.parse(JSON.stringify(TestDeployment2.request.object));
            testDeployment.spec.template.spec.containers[0].env = [{
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "cloud.provider=AWS,service.name=my-service,k8s.cluster.name=customer-cluster"
            }];

            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            const platforms = [AutoInstrumentationPlatforms.Java];

            const result: object[] = Patcher.PatchObject(testDeployment, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

            const obj: IObjectType = (<any>result[0]).value as IObjectType;
            const containerEnv = obj.spec.template.spec.containers[0].env;
            const otelResourceAttributes = containerEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            
            expect(otelResourceAttributes).toBeDefined();
            expect(otelResourceAttributes!.value).toContain("service.name=my-service"); // customer's attribute preserved
            expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure"); // our attribute wins
            expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=" + clusterName); // our attribute wins
        });

        it("should work without existing OTEL_RESOURCE_ATTRIBUTES", () => {
            // Create a test deployment without OTEL_RESOURCE_ATTRIBUTES
            const testDeployment = JSON.parse(JSON.stringify(TestDeployment2.request.object));
            testDeployment.spec.template.spec.containers[0].env = [];

            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            const platforms = [AutoInstrumentationPlatforms.Java];

            const result: object[] = Patcher.PatchObject(testDeployment, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

            const obj: IObjectType = (<any>result[0]).value as IObjectType;
            const containerEnv = obj.spec.template.spec.containers[0].env;
            const otelResourceAttributes = containerEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            
            expect(otelResourceAttributes).toBeDefined();
            expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure");
            expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=" + clusterName);
        });

        it("should work when no existing environment variables are present", () => {
            // Create a test deployment with no env array
            const testDeployment = JSON.parse(JSON.stringify(TestDeployment2.request.object));
            delete testDeployment.spec.template.spec.containers[0].env;

            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            const platforms = [AutoInstrumentationPlatforms.Java];

            const result: object[] = Patcher.PatchObject(testDeployment, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName, testOtelParams);

            const obj: IObjectType = (<any>result[0]).value as IObjectType;
            const containerEnv = obj.spec.template.spec.containers[0].env;
            const otelResourceAttributes = containerEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            
            expect(otelResourceAttributes).toBeDefined();
            expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure");
            expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=" + clusterName);
        });
    });
});