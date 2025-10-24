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
            ownerUid: "ownerUid"
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

        // Generate environment variables for each container with their actual names
        const container0Name = admissionReview.request.object.spec.template.spec.containers[0].name;
        const container1Name = admissionReview.request.object.spec.template.spec.containers[1].name;
        const newEnvironmentVariablesContainer0: object[] = Mutations.GenerateEnvironmentVariables(podInfo, container0Name, platforms, true, cr1.spec.destination.applicationInsightsConnectionString, clusterArmId, clusterArmRegion, clusterName, testOtelParams, undefined, platforms.includes(AutoInstrumentationPlatforms.Python));
        const newEnvironmentVariablesContainer1: object[] = Mutations.GenerateEnvironmentVariables(podInfo, container1Name, platforms, true, cr1.spec.destination.applicationInsightsConnectionString, clusterArmId, clusterArmRegion, clusterName, testOtelParams, undefined, platforms.includes(AutoInstrumentationPlatforms.Python));
        expect((<any>result[0]).value.spec.template.spec.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newEnvironmentVariablesContainer0.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        newEnvironmentVariablesContainer1.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));
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
            ownerUid: "ownerUid"
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

        // Generate environment variables for each container with their actual names
        const container0Name = admissionReview.request.object.spec.template.spec.containers[0].name;
        const container1Name = admissionReview.request.object.spec.template.spec.containers[1].name;
        const newEnvironmentVariablesContainer0: object[] = Mutations.GenerateEnvironmentVariables(podInfo, container0Name, cr1.spec.settings.autoInstrumentationPlatforms, true, cr1.spec.destination.applicationInsightsConnectionString, clusterArmId, clusterArmRegion, clusterName, testOtelParams, undefined, cr1.spec.settings.autoInstrumentationPlatforms.includes(AutoInstrumentationPlatforms.Python));
        const newEnvironmentVariablesContainer1: object[] = Mutations.GenerateEnvironmentVariables(podInfo, container1Name, cr1.spec.settings.autoInstrumentationPlatforms, true, cr1.spec.destination.applicationInsightsConnectionString, clusterArmId, clusterArmRegion, clusterName, testOtelParams, undefined, cr1.spec.settings.autoInstrumentationPlatforms.includes(AutoInstrumentationPlatforms.Python));
        expect((<any>result[0]).value.spec.template.spec.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newEnvironmentVariablesContainer0.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        newEnvironmentVariablesContainer1.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[0].env.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[1].env.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));
        (<any>result[0]).value.spec.template.spec.containers[0].env.forEach(env => expect(env.isPlatformSpecific).not.toBe(true));
        (<any>result[0]).value.spec.template.spec.containers[1].env.forEach(env => expect(env.isPlatformSpecific).not.toBe(true));
        expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(<IEnvironmentVariable>{ name: "OTEL_RESOURCE_ATTRIBUTES", value: "cloud.resource_id=/subscriptions/66010356-d8a5-42d3-8593-6aaa3aeb1c11/resourceGroups/rambhatt-rnd-v2/providers/Microsoft.ContainerService/managedClusters/aks-rambhatt-test,cloud.region=eastus,k8s.cluster.name=aks-rambhatt-test,k8s.namespace.name=$(POD_NAMESPACE),k8s.node.name=$(NODE_NAME),k8s.pod.name=$(POD_NAME),k8s.pod.uid=$(POD_UID),k8s.container.name=" + container0Name + ",cloud.provider=Azure,cloud.platform=azure_aks,k8s.deployment.name=deployment1,k8s.deployment.uid=ownerUid,service.name=deployment1,service.instance.id=$(POD_NAME)" });
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
        expect(metricsExporterEnv.value).toBe("otlp,azure_monitor");
    });

    it("OTEL environment variables - includes only logs variables when only logsEnabled is true", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid"
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
            ownerUid: "ownerUid"
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
        expect(metricsExporterEnv.value).toBe("otlp,azure_monitor");
    });

    it("OTEL environment variables - excludes all OTEL variables when both logsEnabled and metricsEnabled are false", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            ownerName: "deployment1",
            ownerKind: "Deployment",
            ownerUid: "ownerUid"
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

        it("should preserve user's OTEL_RESOURCE_ATTRIBUTES when they edit a mutated deployment via kubectl apply", () => {
            // SCENARIO:
            // 1. User deploys with OTEL_RESOURCE_ATTRIBUTES=mytag=myvalue1
            // 2. Deployment gets mutated
            // 3. User does kubectl apply to change OTEL_RESOURCE_ATTRIBUTES to mytag=myvalue2
            // 4. We need to verify the new value (myvalue2) is preserved and backed up correctly

            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            const platforms = [AutoInstrumentationPlatforms.Java];

            // STEP 1: Initial deployment with mytag=myvalue1
            const initialDeployment = JSON.parse(JSON.stringify(TestDeployment2.request.object));
            initialDeployment.spec.template.spec.containers[0].env = [{
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "mytag=myvalue1"
            }];

            // STEP 2: First mutation - deployment gets mutated
            const firstMutationResult: object[] = Patcher.PatchObject(
                JSON.parse(JSON.stringify(initialDeployment)), 
                cr1, 
                podInfo, 
                platforms, 
                clusterArmId, 
                clusterArmRegion, 
                clusterName, 
                testOtelParams
            );

            const firstMutatedDeployment: IObjectType = (<any>firstMutationResult[0]).value as IObjectType;
            
            // Verify first mutation has backup and merged attributes
            const firstMutatedEnv = firstMutatedDeployment.spec.template.spec.containers[0].env;
            const firstOtelAttr = firstMutatedEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const firstBackupAttr = firstMutatedEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES_BEFORE_AUTO_INSTRUMENTATION");
            
            expect(firstOtelAttr).toBeDefined();
            expect(firstOtelAttr!.value).toContain("mytag=myvalue1"); // user's original value
            expect(firstOtelAttr!.value).toContain("cloud.provider=Azure"); // our mutation
            expect(firstBackupAttr).toBeDefined();
            expect(firstBackupAttr!.value).toBe("mytag=myvalue1"); // backup of original

            // STEP 3: User edits via kubectl apply - changes mytag=myvalue1 to mytag=myvalue2
            // When kubectl apply happens, Kubernetes merges the user's new YAML with the live state
            // The webhook receives the merged result, which includes the user's new simple value
            // AND all the mutations that were previously applied (volumes, initContainers, annotations, etc.)
            const editedDeployment = JSON.parse(JSON.stringify(firstMutatedDeployment));
            
            // Simulate kubectl apply behavior: The user's YAML only contains OTEL_RESOURCE_ATTRIBUTES=mytag=myvalue2
            // Kubernetes merges this with the live state, so the webhook receives:
            // - The mutated deployment structure (volumes, initContainers, our env vars, etc.)
            // - BUT with the user's NEW value for OTEL_RESOURCE_ATTRIBUTES (just mytag=myvalue2, not the full mutated string)
            // This is because kubectl apply uses the user's manifest as the source of truth for fields they specified
            const editedOtelAttrIndex = editedDeployment.spec.template.spec.containers[0].env.findIndex(
                (env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES"
            );
            // Replace the fully mutated OTEL_RESOURCE_ATTRIBUTES with just the user's new value
            editedDeployment.spec.template.spec.containers[0].env[editedOtelAttrIndex].value = "mytag=myvalue2";

            // STEP 4: Second mutation - webhook processes the edited deployment
            const secondMutationResult: object[] = Patcher.PatchObject(
                editedDeployment,
                cr1,
                podInfo,
                platforms,
                clusterArmId,
                clusterArmRegion,
                clusterName,
                testOtelParams
            );

            const finalMutatedDeployment: IObjectType = (<any>secondMutationResult[0]).value as IObjectType;
            const finalEnv = finalMutatedDeployment.spec.template.spec.containers[0].env;
            const finalOtelAttr = finalEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const finalBackupAttr = finalEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES_BEFORE_AUTO_INSTRUMENTATION");

            // ASSERT: The final mutation should preserve the user's NEW value (myvalue2)
            expect(finalOtelAttr).toBeDefined();
            expect(finalOtelAttr!.value).toContain("mytag=myvalue2"); // user's NEW value must be preserved
            expect(finalOtelAttr!.value).not.toContain("mytag=myvalue1"); // old value should NOT be there
            expect(finalOtelAttr!.value).toContain("cloud.provider=Azure"); // our mutation attributes still present
            expect(finalOtelAttr!.value).toContain("k8s.cluster.name=" + clusterName); // our mutation attributes still present

            // ASSERT: The backup should contain the user's NEW value (myvalue2)
            expect(finalBackupAttr).toBeDefined();
            expect(finalBackupAttr!.value).toContain("mytag=myvalue2"); // backup must contain the NEW value
            expect(finalBackupAttr!.value).not.toContain("cloud.provider"); // backup should NOT contain our mutation attributes
        });

        it("should preserve user's OTEL_RESOURCE_ATTRIBUTES when kubectl rollout restart is executed on a mutated deployment", () => {
            // SCENARIO:
            // 1. User deploys with OTEL_RESOURCE_ATTRIBUTES=mytag=myvalue1
            // 2. Deployment gets mutated
            // 3. User runs kubectl rollout restart (triggers new pods without changing deployment spec)
            // 4. Webhook receives the FULLY mutated deployment (including all our env vars with merged attributes)
            // 5. We need to verify that the user's attribute (mytag=myvalue1) is still preserved after re-mutation

            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            const platforms = [AutoInstrumentationPlatforms.Java];

            // STEP 1: Initial deployment with mytag=myvalue1
            const initialDeployment = JSON.parse(JSON.stringify(TestDeployment2.request.object));
            initialDeployment.spec.template.spec.containers[0].env = [{
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "mytag=myvalue1"
            }];

            // STEP 2: First mutation - deployment gets mutated
            const firstMutationResult: object[] = Patcher.PatchObject(
                JSON.parse(JSON.stringify(initialDeployment)), 
                cr1, 
                podInfo, 
                platforms, 
                clusterArmId, 
                clusterArmRegion, 
                clusterName, 
                testOtelParams
            );

            const firstMutatedDeployment: IObjectType = (<any>firstMutationResult[0]).value as IObjectType;
            
            // Verify first mutation has backup and merged attributes
            const firstMutatedEnv = firstMutatedDeployment.spec.template.spec.containers[0].env;
            const firstOtelAttr = firstMutatedEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const firstBackupAttr = firstMutatedEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES_BEFORE_AUTO_INSTRUMENTATION");
            
            expect(firstOtelAttr).toBeDefined();
            expect(firstOtelAttr!.value).toContain("mytag=myvalue1"); // user's original value
            expect(firstOtelAttr!.value).toContain("cloud.provider=Azure"); // our mutation
            expect(firstBackupAttr).toBeDefined();
            expect(firstBackupAttr!.value).toBe("mytag=myvalue1"); // backup of original

            // STEP 3: kubectl rollout restart
            // When kubectl rollout restart happens, Kubernetes doesn't change the deployment spec
            // The webhook receives the FULLY MUTATED deployment exactly as it exists in the cluster
            // This includes all our mutations: volumes, initContainers, env vars with merged values, backup env vars, etc.
            // The webhook needs to handle this already-mutated deployment without losing user's custom attributes
            const rolloutRestartDeployment = JSON.parse(JSON.stringify(firstMutatedDeployment));
            
            // STEP 4: Second mutation - webhook processes the rollout restart
            // This simulates the webhook being called again on the same mutated deployment
            const secondMutationResult: object[] = Patcher.PatchObject(
                rolloutRestartDeployment,
                cr1,
                podInfo,
                platforms,
                clusterArmId,
                clusterArmRegion,
                clusterName,
                testOtelParams
            );

            const finalMutatedDeployment: IObjectType = (<any>secondMutationResult[0]).value as IObjectType;
            const finalEnv = finalMutatedDeployment.spec.template.spec.containers[0].env;
            const finalOtelAttr = finalEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const finalBackupAttr = finalEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES_BEFORE_AUTO_INSTRUMENTATION");

            // ASSERT: The user's original attribute should still be preserved
            expect(finalOtelAttr).toBeDefined();
            expect(finalOtelAttr!.value).toContain("mytag=myvalue1"); // user's original value must be preserved
            expect(finalOtelAttr!.value).toContain("cloud.provider=Azure"); // our mutation attributes still present
            expect(finalOtelAttr!.value).toContain("k8s.cluster.name=" + clusterName); // our mutation attributes still present

            // ASSERT: The backup should still contain the user's original value
            expect(finalBackupAttr).toBeDefined();
            expect(finalBackupAttr!.value).toBe("mytag=myvalue1"); // backup must contain the original value
        });

        it("should preserve user's service.name and service.instance.id during kubectl apply unpatch scenario", () => {
            // SCENARIO:
            // 1. User deploys with OTEL_RESOURCE_ATTRIBUTES containing service.name and service.instance.id
            // 2. Deployment gets mutated
            // 3. User does kubectl apply (which triggers unpatch to preserve user attributes)
            // 4. We need to verify that user's service.name and service.instance.id are preserved

            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            const platforms = [AutoInstrumentationPlatforms.Java];

            // STEP 1: Initial deployment with user-provided service.name and service.instance.id
            const initialDeployment = JSON.parse(JSON.stringify(TestDeployment2.request.object));
            initialDeployment.spec.template.spec.containers[0].env = [{
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "service.name=my-custom-service,service.instance.id=my-custom-instance,custom.attr=custom-value"
            }];

            // STEP 2: First mutation - deployment gets mutated
            const firstMutationResult: object[] = Patcher.PatchObject(
                JSON.parse(JSON.stringify(initialDeployment)), 
                cr1, 
                podInfo, 
                platforms, 
                clusterArmId, 
                clusterArmRegion, 
                clusterName, 
                testOtelParams
            );

            const firstMutatedDeployment: IObjectType = (<any>firstMutationResult[0]).value as IObjectType;
            
            // Verify first mutation preserved user's service.name and service.instance.id
            const firstMutatedEnv = firstMutatedDeployment.spec.template.spec.containers[0].env;
            const firstOtelAttr = firstMutatedEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const firstBackupAttr = firstMutatedEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES_BEFORE_AUTO_INSTRUMENTATION");
            
            expect(firstOtelAttr).toBeDefined();
            expect(firstOtelAttr!.value).toContain("service.name=my-custom-service"); // user's value preserved during merge
            expect(firstOtelAttr!.value).toContain("service.instance.id=my-custom-instance"); // user's value preserved during merge
            expect(firstOtelAttr!.value).not.toContain("service.name=deployment1"); // our default value should not be used
            expect(firstOtelAttr!.value).not.toContain("service.instance.id=$(POD_NAME)"); // our default value should not be used
            expect(firstOtelAttr!.value).toContain("custom.attr=custom-value"); // other user attributes preserved
            expect(firstOtelAttr!.value).toContain("cloud.provider=Azure"); // our mutation
            expect(firstBackupAttr).toBeDefined();
            expect(firstBackupAttr!.value).toBe("service.name=my-custom-service,service.instance.id=my-custom-instance,custom.attr=custom-value"); // backup of original

            // STEP 3: User edits via kubectl apply - changes custom.attr value
            // Kubernetes sends the merged deployment with user's new value
            const editedDeployment = JSON.parse(JSON.stringify(firstMutatedDeployment));
            const editedOtelAttrIndex = editedDeployment.spec.template.spec.containers[0].env.findIndex(
                (env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES"
            );
            // User's new YAML only has the custom attributes (service.name, service.instance.id, and updated custom.attr)
            editedDeployment.spec.template.spec.containers[0].env[editedOtelAttrIndex].value = 
                "service.name=my-custom-service,service.instance.id=my-custom-instance,custom.attr=new-value";

            // STEP 4: Second mutation - webhook processes the edited deployment
            const secondMutationResult: object[] = Patcher.PatchObject(
                editedDeployment,
                cr1,
                podInfo,
                platforms,
                clusterArmId,
                clusterArmRegion,
                clusterName,
                testOtelParams
            );

            const finalMutatedDeployment: IObjectType = (<any>secondMutationResult[0]).value as IObjectType;
            const finalEnv = finalMutatedDeployment.spec.template.spec.containers[0].env;
            const finalOtelAttr = finalEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const finalBackupAttr = finalEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES_BEFORE_AUTO_INSTRUMENTATION");

            // ASSERT: The final mutation should preserve user's service.name and service.instance.id
            expect(finalOtelAttr).toBeDefined();
            expect(finalOtelAttr!.value).toContain("service.name=my-custom-service"); // user's service.name preserved
            expect(finalOtelAttr!.value).toContain("service.instance.id=my-custom-instance"); // user's service.instance.id preserved
            expect(finalOtelAttr!.value).not.toContain("service.name=deployment1"); // our default should NOT be there
            expect(finalOtelAttr!.value).not.toContain("service.instance.id=$(POD_NAME)"); // our default should NOT be there
            expect(finalOtelAttr!.value).toContain("custom.attr=new-value"); // updated custom attribute
            expect(finalOtelAttr!.value).not.toContain("custom.attr=custom-value"); // old value should NOT be there
            expect(finalOtelAttr!.value).toContain("cloud.provider=Azure"); // our mutation attributes still present

            // ASSERT: The backup should contain the user's NEW values including service.name and service.instance.id
            expect(finalBackupAttr).toBeDefined();
            expect(finalBackupAttr!.value).toContain("service.name=my-custom-service");
            expect(finalBackupAttr!.value).toContain("service.instance.id=my-custom-instance");
            expect(finalBackupAttr!.value).toContain("custom.attr=new-value");
            expect(finalBackupAttr!.value).not.toContain("cloud.provider"); // backup should NOT contain our mutation attributes
        });

        it("should allow user to change service.name value via kubectl apply", () => {
            // SCENARIO:
            // 1. User deploys with service.name=original-service
            // 2. Deployment gets mutated (service.name preserved due to user priority)
            // 3. User does kubectl apply to change service.name to service.name=updated-service
            // 4. Webhook should preserve the NEW user value and update the backup

            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            const platforms = [AutoInstrumentationPlatforms.Java];

            // STEP 1: Initial deployment with user-provided service.name
            const initialDeployment = JSON.parse(JSON.stringify(TestDeployment2.request.object));
            initialDeployment.spec.template.spec.containers[0].env = [{
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "service.name=original-service,custom.tag=value1"
            }];

            // STEP 2: First mutation - deployment gets mutated
            const firstMutationResult: object[] = Patcher.PatchObject(
                JSON.parse(JSON.stringify(initialDeployment)), 
                cr1, 
                podInfo, 
                platforms, 
                clusterArmId, 
                clusterArmRegion, 
                clusterName, 
                testOtelParams
            );

            const firstMutatedDeployment: IObjectType = (<any>firstMutationResult[0]).value as IObjectType;
            
            // Verify first mutation preserved user's service.name
            const firstMutatedEnv = firstMutatedDeployment.spec.template.spec.containers[0].env;
            const firstOtelAttr = firstMutatedEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const firstBackupAttr = firstMutatedEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES_BEFORE_AUTO_INSTRUMENTATION");
            
            expect(firstOtelAttr).toBeDefined();
            expect(firstOtelAttr!.value).toContain("service.name=original-service"); // user's original service.name
            expect(firstOtelAttr!.value).not.toContain("service.name=test-app"); // our default should not be used
            expect(firstOtelAttr!.value).toContain("service.instance.id=$(POD_NAME)"); // our default for service.instance.id (user didn't provide it)
            expect(firstOtelAttr!.value).toContain("custom.tag=value1");
            expect(firstOtelAttr!.value).toContain("cloud.provider=Azure");
            expect(firstBackupAttr).toBeDefined();
            expect(firstBackupAttr!.value).toBe("service.name=original-service,custom.tag=value1");

            // STEP 3: User edits via kubectl apply - changes service.name to updated-service
            const editedDeployment = JSON.parse(JSON.stringify(firstMutatedDeployment));
            const editedOtelAttrIndex = editedDeployment.spec.template.spec.containers[0].env.findIndex(
                (env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES"
            );
            // User's new YAML has updated service.name
            editedDeployment.spec.template.spec.containers[0].env[editedOtelAttrIndex].value = 
                "service.name=updated-service,custom.tag=value1";

            // STEP 4: Second mutation - webhook processes the edited deployment
            const secondMutationResult: object[] = Patcher.PatchObject(
                editedDeployment,
                cr1,
                podInfo,
                platforms,
                clusterArmId,
                clusterArmRegion,
                clusterName,
                testOtelParams
            );

            const finalMutatedDeployment: IObjectType = (<any>secondMutationResult[0]).value as IObjectType;
            const finalEnv = finalMutatedDeployment.spec.template.spec.containers[0].env;
            const finalOtelAttr = finalEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const finalBackupAttr = finalEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES_BEFORE_AUTO_INSTRUMENTATION");

            // ASSERT: The final mutation should preserve the UPDATED service.name
            expect(finalOtelAttr).toBeDefined();
            expect(finalOtelAttr!.value).toContain("service.name=updated-service"); // user's NEW service.name
            expect(finalOtelAttr!.value).not.toContain("service.name=original-service"); // old service.name should NOT be there
            expect(finalOtelAttr!.value).not.toContain("service.name=test-app"); // our default should NOT be there
            expect(finalOtelAttr!.value).toContain("service.instance.id=$(POD_NAME)"); // our default for service.instance.id
            expect(finalOtelAttr!.value).toContain("custom.tag=value1"); // other attributes preserved
            expect(finalOtelAttr!.value).toContain("cloud.provider=Azure"); // our mutation attributes still present

            // ASSERT: The backup should contain the UPDATED service.name
            expect(finalBackupAttr).toBeDefined();
            expect(finalBackupAttr!.value).toContain("service.name=updated-service"); // backup has the NEW value
            expect(finalBackupAttr!.value).not.toContain("service.name=original-service"); // backup should NOT have old value
            expect(finalBackupAttr!.value).toContain("custom.tag=value1");
            expect(finalBackupAttr!.value).not.toContain("cloud.provider"); // backup should NOT contain our mutation attributes
        });

        it('should use correct container name in OTEL_RESOURCE_ATTRIBUTES for each container in full admission review', () => {
            // Use existing TestDeployment2 which has 2 containers: "ibm-open-liberty-spring" and "container2"
            const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
            const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
            
            const podInfo: PodInfo = <PodInfo>{
                namespace: "default",
                ownerName: "quieting-garfish-ibm-ope",
                ownerKind: "Deployment",
                ownerUid: "test-owner-uid"
            };

            admissionReview.request.object.metadata.namespace = cr1.metadata.namespace;
            const platforms = cr1.spec.settings.autoInstrumentationPlatforms;

            const result: object[] = Patcher.PatchObject(
                JSON.parse(JSON.stringify(admissionReview.request.object)),
                cr1,
                podInfo,
                platforms,
                clusterArmId,
                clusterArmRegion,
                clusterName,
                testOtelParams
            );

            expect((<[]>result).length).toBe(1);
            
            const mutatedDeployment: IObjectType = (<any>result[0]).value as IObjectType;
            
            // Verify we have 2 containers
            expect(mutatedDeployment.spec.template.spec.containers.length).toBe(2);

            // Extract environment variables for each container
            const firstContainerEnv = mutatedDeployment.spec.template.spec.containers[0].env;
            const secondContainerEnv = mutatedDeployment.spec.template.spec.containers[1].env;

            // Find OTEL_RESOURCE_ATTRIBUTES in each container
            const firstContainerOtelAttr = firstContainerEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            const secondContainerOtelAttr = secondContainerEnv.find((env: IEnvironmentVariable) => env.name === "OTEL_RESOURCE_ATTRIBUTES");

            // Verify OTEL_RESOURCE_ATTRIBUTES exists in all containers
            expect(firstContainerOtelAttr).toBeDefined();
            expect(secondContainerOtelAttr).toBeDefined();

            // CRITICAL ASSERTION: Each container should have its own correct container name
            // First container is "ibm-open-liberty-spring"
            expect(firstContainerOtelAttr!.value).toContain("k8s.container.name=ibm-open-liberty-spring");
            expect(firstContainerOtelAttr!.value).not.toContain("k8s.container.name=container2");
            expect(firstContainerOtelAttr!.value).not.toContain("k8s.container.name=null");

            // Second container is "container2"
            expect(secondContainerOtelAttr!.value).toContain("k8s.container.name=container2");
            expect(secondContainerOtelAttr!.value).not.toContain("k8s.container.name=ibm-open-liberty-spring");
            expect(secondContainerOtelAttr!.value).not.toContain("k8s.container.name=null");

            // Verify common attributes are present in all containers
            const commonAttributes = [
                "cloud.provider=Azure",
                "cloud.platform=azure_aks",
                `k8s.cluster.name=${clusterName}`,
                "k8s.namespace.name=$(POD_NAMESPACE)",
                "k8s.deployment.name=quieting-garfish-ibm-ope",
                `k8s.deployment.uid=test-owner-uid`
            ];

            commonAttributes.forEach(attr => {
                expect(firstContainerOtelAttr!.value).toContain(attr);
                expect(secondContainerOtelAttr!.value).toContain(attr);
            });

            // Verify original environment variables are preserved
            expect(firstContainerEnv.find((env: IEnvironmentVariable) => env.name === "WLP_LOGGING_CONSOLE_FORMAT")).toBeDefined();
            expect(secondContainerEnv.find((env: IEnvironmentVariable) => env.name === "ENV_VAR_1")).toBeDefined();
        });
    });
});
