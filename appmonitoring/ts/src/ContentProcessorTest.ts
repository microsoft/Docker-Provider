// import assert = require("assert");
// import { AddedTypes } from "./AddedTypes.js";
// import { ContentProcessor } from "./ContentProcessor.js";
// import { DiffCalculator } from "./DiffCalculator.js";
// import { IRootObject } from "./RequestDefinition.js";
// import { TemplateValidator } from "./TemplateValidator.js";

// import * as Test from "./testConsts.js";
// import { AppMonitoringConfigCRsCollection } from "./AppMonitoringConfigCRsCollection.js";

// const crs: AppMonitoringConfigCRsCollection = new AppMonitoringConfigCRsCollection();

// describe("ContentProcessor", () => {
//     it("Null", async () => {
//         assert.deepEqual('{"apiVersion":"admission.k8s.io/v1beta1","kind":"AdmissionReview","response":{"allowed":false,"patchtype":"JSONPATCH","uid":""}}',
//             await ContentProcessor.TryUpdateConfig(null, crs));
//     });

//     it("Constructor", async () => {
//         assert.deepEqual('{"kind":"AdmissionReview","response":{"allowed":false,"patchtype":"JSONPATCH","uid":""}}',
//             await ContentProcessor.TryUpdateConfig("{}", crs),
//             "should return json");
//     });

//     it("InvalidJSON", async () => {
//         const something = "dsasda";
//         assert.deepEqual('{"apiVersion":"admission.k8s.io/v1beta1","kind":"AdmissionReview","response":{"allowed":false,"patchtype":"JSONPATCH","uid":""}}',
//             await ContentProcessor.TryUpdateConfig(something, crs),
//             "expect something");
//     });

//     it("ValidObject", async () => {
//         const result = JSON.parse(await ContentProcessor.TryUpdateConfig(Test.TestObject, crs));
//         assert.equal(true, result.response.allowed);
//         assert.equal("JSONPATCH", result.response.patchtype);
//         assert.equal(result.request.uid, result.response.uid);
//     });

//     it("ValidObject2", async () => {
//         const result = JSON.parse(await ContentProcessor.TryUpdateConfig(Test.TestObject2, crs));
//         assert.equal(true, result.response.allowed);
//         assert.equal("JSONPATCH", result.response.patchtype);
//         assert.equal(result.request.uid, result.response.uid);
//     });

//     it("ValidObject3", async () => {
//         const result = JSON.parse(await ContentProcessor.TryUpdateConfig(Test.TestObject3, crs));
//         assert.equal(true, result.response.allowed);
//         assert.equal("JSONPATCH", result.response.patchtype);
//         assert.equal(result.request.uid, result.response.uid);
//     });

//     it("ValidObject4", async () => {
//         const result = JSON.parse(await ContentProcessor.TryUpdateConfig(Test.TestObject4, crs));
//         assert.equal(true, result.response.allowed);
//         assert.equal("JSONPATCH", result.response.patchtype);
//         assert.equal(result.request.uid, result.response.uid);
//     });

//     it("ValidateNull", () => {
//         assert.equal(false, TemplateValidator.ValidateContent(null),
//             "should be false here");
//     });

//     it("ValidateMissingFields", () => {
//         const testSubject: IRootObject = JSON.parse(Test.TestObject2);
//         testSubject.request = null;
//         assert.equal(false, TemplateValidator.ValidateContent(testSubject),
//             "should be false here");
//     });

//     it("ValidateMissingFields2", () => {
//         const testSubject: IRootObject = JSON.parse(Test.TestObject2);
//         testSubject.request.operation = null;
//         assert.equal(false, TemplateValidator.ValidateContent(testSubject),
//             "should be false here");
//     });

//     it("ValidateMissingFields3", () => {
//         const testSubject: IRootObject = JSON.parse(Test.TestObject2);
//         testSubject.request.operation = "nope";
//         assert.equal(false, TemplateValidator.ValidateContent(testSubject),
//             "should be false here");
//     });

//     it("ValidateMissingFields4", () => {
//         const testSubject: IRootObject = JSON.parse(Test.TestObject2);
//         testSubject.kind = null;
//         assert.equal(false, TemplateValidator.ValidateContent(testSubject),
//             "should be false here");
//     });

//     it("ValidateMissingFields5", () => {
//         const testSubject: IRootObject = JSON.parse(Test.TestObject2);
//         testSubject.kind = "nope";
//         assert.equal(false, TemplateValidator.ValidateContent(testSubject),
//             "should be false here");
//     });

//     it("ValidateMissingFields6", () => {
//         const testSubject: IRootObject = JSON.parse(Test.TestObject2);
//         testSubject.request.object = null;
//         assert.equal(false, TemplateValidator.ValidateContent(testSubject),
//             "should be false here");
//     });

//     it("ValidateMissingFields7", () => {
//         const testSubject: IRootObject = JSON.parse(Test.TestObject2);
//         testSubject.request.object.spec = null;
//         assert.equal(false, TemplateValidator.ValidateContent(testSubject),
//             "should be false here");
//     });

//     it("DiffCalculatorNull1", async () => {
//         assert.equal(null, await DiffCalculator.CalculateDiff(null, null, [], null, null, null, null),
//             "should be null here");
//     });

//     it("DiffCalculatorTestContent", async () => {
//         const testSubject: IRootObject = JSON.parse(Test.TestObject);
//         const result = await DiffCalculator.CalculateDiff(testSubject, null, [], null, null, null, null);
//         assert.equal("replace", result[0].op);
//         assert.equal("/spec", result[0].path);
//         assert.notEqual(null, result[0].value);
//         assert.deepEqual(AddedTypes.init_containers([]), result[0].value.template.spec.initContainers,
//             "should match containers");
//         assert.deepEqual(AddedTypes.volumes([]), result[0].value.template.spec.volumes,
//             "should match volumes");
//     });

// });
