import { expect, describe, it } from "@jest/globals";
import { ContentProcessor } from "../ContentProcessor.js";
import { AddedTypes } from "../AddedTypes.js";
import { IRootObject, AppMonitoringConfigCR, PodInfo } from "../RequestDefinition.js";
import { TemplateValidator } from "../TemplateValidator.js";
import { DiffCalculator } from "../DiffCalculator.js";
import { AppMonitoringConfigCRsCollection } from "../AppMonitoringConfigCRsCollection.js";
import { TestObject, TestObject2, TestObject3, TestObject4 } from "../testConsts.js";

const cr: AppMonitoringConfigCR = {
    metadata: {
        name: "appmonitoringconfig",
        namespace: "default"
    },
    spec: {
        autoInstrumentationPlatforms: ["DotNet", "Java", "NodeJs"],
        aiConnectionString: "InstrumentationKey=823201eb-fdbf-468a-bc7b-e685639439b2;IngestionEndpoint=https://uaecentral-0.in.applicationinsights.azure.com/",
        deployments: []
    }
}

const crs: AppMonitoringConfigCRsCollection = new AppMonitoringConfigCRsCollection();
crs.Upsert(cr);

describe("ContentProcessor", () => {
    it("Null", async () => {
        expect(await ContentProcessor.TryUpdateConfig(null, crs)).toBe('{"apiVersion":"admission.k8s.io/v1","kind":"AdmissionReview","response":{"allowed":false,"patchType":"JSONPatch","uid":""}}');
    })

    it("Constructor", async () => {
        expect(await ContentProcessor.TryUpdateConfig("{}", crs)).toEqual('{"kind":"AdmissionReview","response":{"allowed":false,"patchType":"JSONPatch","uid":""}}');
    })

    it("InvalidJSON", async () => {
        const something = "dsasda";

        expect(await ContentProcessor.TryUpdateConfig(something, crs)).toEqual('{"apiVersion":"admission.k8s.io/v1","kind":"AdmissionReview","response":{"allowed":false,"patchType":"JSONPatch","uid":""}}');
    })

    it("ValidObject", async () => {
        const result = JSON.parse(await ContentProcessor.TryUpdateConfig(TestObject, crs));

        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(result.request.uid,);
    })

    it("ValidObject2", async () => {
        const result = JSON.parse(await ContentProcessor.TryUpdateConfig(TestObject2, crs));
        
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(result.request.uid);
    })

    it("ValidObject3", async () => {
        const result = JSON.parse(await ContentProcessor.TryUpdateConfig(TestObject3, crs));
       
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(result.request.uid);
    })

    it("ValidObject4", async () => {
        const result = JSON.parse(await ContentProcessor.TryUpdateConfig(TestObject4, crs));
        
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(result.request.uid);
    })

    it("ValidateNull", () => {
        expect(TemplateValidator.ValidateContent(null)).toBe(false);
    })

    it("ValidateMissingFields", () => {
        const testSubject: IRootObject = JSON.parse(TestObject2);
        testSubject.request = null

        expect(TemplateValidator.ValidateContent(testSubject)).toBe(false);
    })

    it("ValidateMissingFields2", () => {
        const testSubject: IRootObject = JSON.parse(TestObject2);
        testSubject.request.operation = null;

        expect(TemplateValidator.ValidateContent(testSubject)).toBe(false);
    })

    it("ValidateMissingFields3", () => {
        const testSubject: IRootObject = JSON.parse(TestObject2);
        testSubject.request.operation = "nope";

        expect(TemplateValidator.ValidateContent(testSubject)).toBe(false);
    })

    it("ValidateMissingFields4", () => {
        const testSubject: IRootObject = JSON.parse(TestObject2,);
        testSubject.kind = null;

        expect(TemplateValidator.ValidateContent(testSubject)).toBe(false);
    })

    it("ValidateMissingFields5", () => {
        const testSubject: IRootObject = JSON.parse(TestObject2);
        testSubject.kind = "nope";

        expect(TemplateValidator.ValidateContent(testSubject)).toBe(false);
    })

    it("ValidateMissingFields6", () => {
        const testSubject: IRootObject = JSON.parse(TestObject2);
        testSubject.request.object = null;

        expect(TemplateValidator.ValidateContent(testSubject)).toBe(false);
    })

    it("ValidateMissingFields7", () => {
        const testSubject: IRootObject = JSON.parse(TestObject2);
        testSubject.request.object.spec = null;
        expect(TemplateValidator.ValidateContent(testSubject)).toBe(false);
    })

    it("DiffCalculatorNull1", async () => {
        expect(await DiffCalculator.CalculateDiff(null, null, null, null, null, null, null)).toBeNull();
    })

    it("DiffCalculatorTestContent", async () => {
        const testSubject: IRootObject = JSON.parse(TestObject);
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
        const result = await DiffCalculator.CalculateDiff(testSubject, podInfo, platforms, "connection-string", "armId", "armRegion", "cluster1");

        expect((<[]>result).length).toBe(1);
        expect(result[0].op).toBe("replace");
        expect(result[0].path).toBe("/spec");
        expect(result[0].value).not.toBeNull();
        expect(result[0].value.template.spec.initContainers).toEqual(AddedTypes.init_containers(platforms));
        expect(result[0].value.template.spec.volumes).toEqual(AddedTypes.volumes(platforms));
    })
})