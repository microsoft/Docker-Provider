import { expect, describe, it } from "@jest/globals";
import { Mutator } from "../Mutator.js";
import { IAdmissionReview } from "../RequestDefinition.js";
import { TestObject2, TestObject3, TestObject4, crs, clusterArmId, clusterArmRegion } from "./testConsts.js";
import { logger } from "../LoggerWrapper.js"

beforeEach(() => {
    logger.setUnitTestMode(true);
});

afterEach(() => {
    jest.restoreAllMocks();
});

describe("Mutator", () => {
    it("Null", async () => {
        const result: string = await Mutator.MutatePod(null, crs, clusterArmId, clusterArmRegion, null);
        expect(result).toBe('{"apiVersion":"admission.k8s.io/v1","kind":"AdmissionReview","response":{"allowed":true,"patchType":"JSONPatch","uid":""}}');
    })

    it("Unsupported object", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        admissionReview.request.kind.kind = "Not a pod!"

        const result: string = await Mutator.MutatePod(admissionReview, crs, clusterArmId, clusterArmRegion, null);

        expect(result).toEqual(`{"apiVersion":"admission.k8s.io/v1","kind":"${admissionReview.kind}","response":{"allowed":true,"patchType":"JSONPatch","uid":"${admissionReview.request.uid}"}}`);
    })

    it("Unsupported operation", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        admissionReview.request.operation = "DELETE"

        const result: string = await Mutator.MutatePod(admissionReview, crs, clusterArmId, clusterArmRegion, null);
        expect(result).toEqual(`{"apiVersion":"admission.k8s.io/v1","kind":"${admissionReview.kind}","response":{"allowed":true,"patchType":"JSONPatch","uid":"${admissionReview.request.uid}"}}`);
    })
    
    it("Valid object 2", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        const result = JSON.parse(await Mutator.MutatePod(admissionReview, crs, clusterArmId, clusterArmRegion, null));
        
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
    })

    it("ValidObject3", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject3));
        const result = JSON.parse(await Mutator.MutatePod(admissionReview, crs, clusterArmId, clusterArmRegion, null));
       
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
    });

    it("ValidObject4", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));
        const result = JSON.parse(await Mutator.MutatePod(admissionReview, crs, clusterArmId, clusterArmRegion, null));
        
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
    });
});