import { expect, describe, it } from "@jest/globals";
import { Mutations } from "../Mutations.js";
import { IAdmissionReview, PodInfo, IContainer, IVolume, AutoInstrumentationPlatforms, IEnvironmentVariable, InstrumentationCR, IInstrumentationState, IObjectType, InstrumentationAnnotationName, EnableApplicationLogsAnnotationName } from "../RequestDefinition.js";
import { Patcher } from "../Patcher.js";
import { cr, clusterArmId, clusterArmRegion, clusterName, TestDeployment2 } from "./testConsts.js";
import { logger } from "../LoggerWrapper.js"

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

        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName);

        expect((<[]>result).length).toBe(1);
        
        const obj: IObjectType = (<any>result[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;
        expect(annotationValue.crName).toBe(cr1.metadata.name);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]);        

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

        const newEnvironmentVariables: object[] = Mutations.GenerateEnvironmentVariables(podInfo, platforms, true, cr1.spec.destination.applicationInsightsConnectionString, clusterArmId, clusterArmRegion, clusterName);
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


        const result: object[] = Patcher.PatchObject(JSON.parse(JSON.stringify(admissionReview.request.object)), cr1, podInfo, cr1.spec.settings.autoInstrumentationPlatforms, clusterArmId, clusterArmRegion, clusterName);

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

        const newEnvironmentVariables: object[] = Mutations.GenerateEnvironmentVariables(podInfo, cr1.spec.settings.autoInstrumentationPlatforms, true, cr1.spec.destination.applicationInsightsConnectionString, clusterArmId, clusterArmRegion, clusterName);
        expect((<any>result[0]).value.spec.template.spec.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newEnvironmentVariables.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        newEnvironmentVariables.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[0].env.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[0].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[1].env.forEach(env => expect((<any>result[0]).value.spec.template.spec.containers[1].env).toContainEqual(env));

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

        const patchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, cr, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName)));

        // ACT
        // unpatch since CR is empty
        const unpatchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

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
        const unpatchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

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
        const unpatchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

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
        const patchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(mutatedAdmissionReview.request.object, null, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName)));

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
                "name": "OTEL_DOTNET_AUTO_LOGS_ENABLED",
                "value": "original conflicting value for dotnet auto logs enabled"
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
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(4);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED").value).toBe("original conflicting value for dotnet auto logs enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe("original conflicting value for NodeJs configuration content");
    });

    it("Restores conflicting environment variables during unpatch when patch was not with all platforms", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestDeployment2));
        
        const cr1: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        cr1.spec.settings.autoInstrumentationPlatforms = [AutoInstrumentationPlatforms.DotNet];
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
                "name": "OTEL_DOTNET_AUTO_LOGS_ENABLED",
                "value": "original conflicting value for dotnet auto logs enabled"
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
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(4);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED").value).toBe("original conflicting value for dotnet auto logs enabled");
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
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

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
                "name": "OTEL_DOTNET_AUTO_LOGS_ENABLED",
                "value": "original conflicting value for dotnet auto logs enabled"
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
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").valueFrom.fieldRef.fieldPath).toBe("spec.nodeName");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED").value).toBe("false");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("false");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe(`{"instrumentationOptions":{"console": { "enabled": false }, "bunyan": { "enabled": false },"winston": { "enabled": false }}}`);

        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for node name");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for dotnet auto logs enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT_BEFORE_AUTO_INSTRUMENTATION")?.value).toBeUndefined();

        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(3);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED").value).toBe("original conflicting value for dotnet auto logs enabled");
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
                "name": "OTEL_DOTNET_AUTO_LOGS_ENABLED",
                "value": "original conflicting value for dotnet auto logs enabled"
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
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").valueFrom.fieldRef.fieldPath).toBe("spec.nodeName");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED").value).toBe("original conflicting value for dotnet auto logs enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe("original conflicting value for NodeJs configuration content");

        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for node name");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for dotnet auto logs enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for NodeJs configuration content");

        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(4);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED").value).toBe("original conflicting value for dotnet auto logs enabled");
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
                "name": "OTEL_DOTNET_AUTO_LOGS_ENABLED",
                "value": "original conflicting value for dotnet auto logs enabled"
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
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, cr1, podInfo, platforms, clusterArmId, clusterArmRegion, clusterName)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchObject(admissionReview.request.object, null, podInfo, [] as AutoInstrumentationPlatforms[], clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").valueFrom.fieldRef.fieldPath).toBe("spec.nodeName");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED").value).toBe("false");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("false");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT").value).toBe(`{"instrumentationOptions":{"console": { "enabled": false }, "bunyan": { "enabled": false },"winston": { "enabled": false }}}`);

        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for node name");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for dotnet auto logs enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED_BEFORE_AUTO_INSTRUMENTATION").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>patchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT_BEFORE_AUTO_INSTRUMENTATION")?.value).toBeUndefined();

        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.length).toBe(3);
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "OTEL_DOTNET_AUTO_LOGS_ENABLED").value).toBe("original conflicting value for dotnet auto logs enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED").value).toBe("original conflicting value for Java logging enabled");
        expect((<any>unpatchedResult[0]).value.spec.template.spec.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT")?.value).toBeUndefined();
    });
});