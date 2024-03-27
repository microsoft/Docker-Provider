import { expect, describe, it } from "@jest/globals";
import { Mutations } from "../Mutations.js";
import { IAdmissionReview, PodInfo, IContainer, IVolume, AutoInstrumentationPlatforms, IEnvironmentVariable, IInstrumentationAnnotationValue } from "../RequestDefinition.js";
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
        const platforms = cr.spec.settings.autoInstrumentationPlatforms;
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

        const result: object[] = Patcher.PatchSpec(JSON.parse(JSON.stringify(admissionReview.request.object.spec.template.spec)), cr, podInfo, platforms, "connection-string", clusterArmId, clusterArmRegion, clusterName);

        expect((<[]>result).length).toBe(2);
        const annotationValue: IInstrumentationAnnotationValue = JSON.parse((<any>result[0]).value) as IInstrumentationAnnotationValue;
        expect(annotationValue.crName).toBe(cr.metadata.name);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]);        

        expect((<any>result[1]).op).toBe("replace");
        expect((<any>result[1]).path).toBe("/spec/template/spec");
        expect((<any>result[1]).value).not.toBeNull();
        
        const newInitContainers: IContainer[] = Mutations.GenerateInitContainers(platforms);
        expect((<any>result[1]).value.initContainers.length).toBe(admissionReview.request.object.spec.template.spec.initContainers.length + newInitContainers.length);
        newInitContainers.forEach(ic => expect((<any>result[1]).value.initContainers).toContainEqual(ic));
        admissionReview.request.object.spec.template.spec.initContainers.forEach(ic => expect((<any>result[1]).value.initContainers).toContainEqual(ic));

        const newVolumes: IVolume[] = Mutations.GenerateVolumes(platforms);
        expect((<any>result[1]).value.volumes.length).toBe(admissionReview.request.object.spec.template.spec.volumes.length + newVolumes.length);
        newVolumes.forEach(vol => expect((<any>result[1]).value.volumes).toContainEqual(vol));
        admissionReview.request.object.spec.template.spec.volumes.forEach(vol => expect((<any>result[1]).value.volumes).toContainEqual(vol));

        const newEnvironmentVariables: object[] = Mutations.GenerateEnvironmentVariables(podInfo, platforms, "connection-string", clusterArmId, clusterArmRegion, clusterName);
        expect((<any>result[1]).value.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newEnvironmentVariables.forEach(env => expect((<any>result[1]).value.containers[0].env).toContainEqual(env));
        newEnvironmentVariables.forEach(env => expect((<any>result[1]).value.containers[1].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[0].env.forEach(env => expect((<any>result[1]).value.containers[0].env).toContainEqual(env));
        admissionReview.request.object.spec.template.spec.containers[1].env.forEach(env => expect((<any>result[1]).value.containers[1].env).toContainEqual(env));

        const newVolumeMounts: object[] = Mutations.GenerateVolumeMounts(platforms);
        expect((<any>result[1]).value.containers.length).toBe(admissionReview.request.object.spec.template.spec.containers.length);
        newVolumeMounts.forEach(vm => expect((<any>result[1]).value.containers[0].volumeMounts).toContainEqual(vm));
        newVolumeMounts.forEach(vm => expect((<any>result[1]).value.containers[1].volumeMounts).toContainEqual(vm));
        admissionReview.request.object.spec.template.spec.containers[0].volumeMounts.forEach(vm => expect((<any>result[1]).value.containers[0].volumeMounts).toContainEqual(vm));
        admissionReview.request.object.spec.template.spec.containers[1].volumeMounts.forEach(vm => expect((<any>result[1]).value.containers[1].volumeMounts).toContainEqual(vm));
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

        const patchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchSpec(mutatedAdmissionReview.request.object.spec.template.spec, cr, podInfo, platforms, "connection-string", clusterArmId, clusterArmRegion, clusterName)));

        // ACT
        // unpatch since CR is empty
        const unpatchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchSpec(mutatedAdmissionReview.request.object.spec.template.spec, null, podInfo, [] as AutoInstrumentationPlatforms[], "connection-string", clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect(JSON.stringify(mutatedAdmissionReview)).toBe(JSON.stringify(initialAdmissionReview));

        expect(unpatchResult.length).toBe(3);

        expect((<any>unpatchResult[0]).op).toBe("add");
        expect((<any>unpatchResult[0]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
        expect((<any>unpatchResult[1]).value).toBeUndefined();

        expect((<any>unpatchResult[1]).op).toBe("remove");
        expect((<any>unpatchResult[1]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");

        expect((<any>unpatchResult[2]).op).toBe("replace");
        expect((<any>unpatchResult[2]).path).toBe("/spec/template/spec");
        expect(JSON.stringify((<any>unpatchResult[2]).value)).toBe(JSON.stringify(initialAdmissionReview.request.object.spec.template.spec));
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
        const patchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchSpec(mutatedAdmissionReview.request.object.spec.template.spec, null, podInfo, platforms, "connection-string", clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect(JSON.stringify(mutatedAdmissionReview)).toBe(JSON.stringify(initialAdmissionReview));

        expect(patchResult.length).toBe(3);

        expect((<any>patchResult[0]).op).toBe("add");
        expect((<any>patchResult[0]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
        expect((<any>patchResult[0]).value).toBeUndefined();

        expect((<any>patchResult[1]).op).toBe("remove");
        expect((<any>patchResult[1]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
        
        expect((<any>patchResult[2]).op).toBe("replace");
        expect((<any>patchResult[2]).path).toBe("/spec/template/spec");
        expect(JSON.stringify((<any>patchResult[2]).value)).toBe(JSON.stringify(initialAdmissionReview.request.object.spec.template.spec));
    });

    it("Does not patch if autoinstrumentation platform list is empty", async () => {
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
        const patchResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchSpec(mutatedAdmissionReview.request.object.spec.template.spec, cr, podInfo, [], "connection-string", clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        // we should still get the name of the governing CR in the annotation, but no mutation must have occured and the platform annotation should be empty
        expect(JSON.stringify(mutatedAdmissionReview)).toBe(JSON.stringify(initialAdmissionReview));

        expect(patchResult.length).toBe(3);

        expect((<any>patchResult[0]).op).toBe("add");
        expect((<any>patchResult[0]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
        expect((<any>patchResult[0]).value).toBeUndefined();

        expect((<any>patchResult[1]).op).toBe("remove");
        expect((<any>patchResult[1]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
        
        expect((<any>patchResult[2]).op).toBe("replace");
        expect((<any>patchResult[2]).path).toBe("/spec/template/spec");
        expect(JSON.stringify((<any>patchResult[2]).value)).toBe(JSON.stringify(initialAdmissionReview.request.object.spec.template.spec));
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
            }];

        // ACT
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchSpec(admissionReview.request.object.spec.template.spec, cr, podInfo, platforms, "connection-string", clusterArmId, clusterArmRegion, clusterName)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchSpec(admissionReview.request.object.spec.template.spec, null, podInfo, [] as AutoInstrumentationPlatforms[], "connection-string", clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect((<any>unpatchedResult[2]).value.containers[0].env.length).toBe(1);
        expect((<any>unpatchedResult[2]).value.containers[0].env.find((ev: IEnvironmentVariable) => ev.name === "NODE_NAME").value).toBe("original conflicting value for node name");
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
        const patchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchSpec(admissionReview.request.object.spec.template.spec, cr, podInfo, platforms, "connection-string", clusterArmId, clusterArmRegion, clusterName)));
        const unpatchedResult: object[] = JSON.parse(JSON.stringify(Patcher.PatchSpec(admissionReview.request.object.spec.template.spec, null, podInfo, [] as AutoInstrumentationPlatforms[], "connection-string", clusterArmId, clusterArmRegion, clusterName)));

        // ASSERT
        expect((<any>patchedResult[1]).value.containers[0].env.length).toBeGreaterThan(0);
        expect((<any>unpatchedResult[2]).value.containers[0].env.length).toBe(0);
    });
});