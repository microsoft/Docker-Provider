import { expect, describe, it } from "@jest/globals";
import { Mutations } from "../Mutations.js";
import { IAdmissionReview, PodInfo, IContainer, IVolume } from "../RequestDefinition.js";
import { Patcher } from "../Patcher.js";
import { TestObject2, cr, clusterArmId, clusterArmRegion, clusterName } from "./testConsts.js";
import { logger } from "../LoggerWrapper.js"

beforeEach(() => {
    logger.setUnitTestMode(true);
});

afterEach(() => {
    jest.restoreAllMocks();
});

describe("Patcher", () => {
    it("Patches a pod correctly", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        const platforms = cr.spec.autoInstrumentationPlatforms;
        const podInfo: PodInfo = <PodInfo>{
            namespace: "default",
            name: "pod1",
            deploymentName: "deployment1",
            onlyContainerName: "container1",
            ownerReference: {
                kind: "replicaset",
                name: "rs1",
                uid: "rs1-uid"
            }
        };
        const result: object[] = await Patcher.PatchPod(admissionReview, podInfo, platforms, "connection-string", clusterArmId, clusterArmRegion, clusterName);

        expect((<[]>result).length).toBe(1);
        expect((<any>result[0]).op).toBe("replace");
        expect((<any>result[0]).path).toBe("/spec");
        expect((<any>result[0]).value).not.toBeNull();
        
        const newInitContainers: IContainer[] = Mutations.GenerateInitContainers(platforms);
        expect((<any>result[0]).value.initContainers.length).toBe(admissionReview.request.object.spec.initContainers.length + newInitContainers.length);
        newInitContainers.forEach(ic => expect((<any>result[0]).value.initContainers).toContainEqual(ic));
        admissionReview.request.object.spec.initContainers.forEach(ic => expect((<any>result[0]).value.initContainers).toContainEqual(ic));

        const newVolumes: IVolume[] = Mutations.GenerateVolumes(platforms);
        expect((<any>result[0]).value.volumes.length).toBe(admissionReview.request.object.spec.volumes.length + newVolumes.length);
        newVolumes.forEach(vol => expect((<any>result[0]).value.volumes).toContainEqual(vol));
        admissionReview.request.object.spec.volumes.forEach(vol => expect((<any>result[0]).value.volumes).toContainEqual(vol));

        const newEnvironmentVariables: object[] = Mutations.GenerateEnvironmentVariables(podInfo, platforms, "connection-string", clusterArmId, clusterArmRegion, clusterName);
        expect((<any>result[0]).value.containers.length).toBe(admissionReview.request.object.spec.containers.length);
        newEnvironmentVariables.forEach(env => expect((<any>result[0]).value.containers[0].env).toContainEqual(env));
        newEnvironmentVariables.forEach(env => expect((<any>result[0]).value.containers[1].env).toContainEqual(env));
        admissionReview.request.object.spec.containers[0].env.forEach(env => expect((<any>result[0]).value.containers[0].env).toContainEqual(env));
        admissionReview.request.object.spec.containers[1].env.forEach(env => expect((<any>result[0]).value.containers[1].env).toContainEqual(env));

        const newVolumeMounts: object[] = Mutations.GenerateVolumeMounts(platforms);
        expect((<any>result[0]).value.containers.length).toBe(admissionReview.request.object.spec.containers.length);
        newVolumeMounts.forEach(vm => expect((<any>result[0]).value.containers[0].volumeMounts).toContainEqual(vm));
        newVolumeMounts.forEach(vm => expect((<any>result[0]).value.containers[1].volumeMounts).toContainEqual(vm));
        admissionReview.request.object.spec.containers[0].volumeMounts.forEach(vm => expect((<any>result[0]).value.containers[0].volumeMounts).toContainEqual(vm));
        admissionReview.request.object.spec.containers[1].volumeMounts.forEach(vm => expect((<any>result[0]).value.containers[1].volumeMounts).toContainEqual(vm));
    });
});