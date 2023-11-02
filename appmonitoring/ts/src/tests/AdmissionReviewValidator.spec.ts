import { expect, describe, it } from "@jest/globals";
import { Mutator } from "../Mutator.js";
import { Mutations } from "../Mutations.js";
import { IAdmissionReview, AppMonitoringConfigCR, PodInfo } from "../RequestDefinition.js";
import { AdmissionReviewValidator } from "../AdmissionReviewValidator.js";
import { Patcher } from "../Patcher.js";
import { AppMonitoringConfigCRsCollection } from "../AppMonitoringConfigCRsCollection.js";
import { TestObject2, TestObject3, TestObject4 } from "./testConsts.js";
import { assert } from "console";

describe("AdmissionReviewValidator", () => {
    it("ValidateNull", () => {
        expect(AdmissionReviewValidator.Validate(null)).toBe(false);
    })

    it("ValidateMissingFields", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request = null

        expect(AdmissionReviewValidator.Validate(testSubject)).toBe(false);
    })

    it("ValidateMissingFields2", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request.operation = null;

        expect(AdmissionReviewValidator.Validate(testSubject)).toBe(false);
    })

    it("ValidateMissingFields3", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request.operation = "nope";

        expect(AdmissionReviewValidator.Validate(testSubject)).toBe(false);
    })

    it("ValidateMissingFields4", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.kind = null;

        expect(AdmissionReviewValidator.Validate(testSubject)).toBe(false);
    })

    it("ValidateMissingFields6", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request.object = null;

        expect(AdmissionReviewValidator.Validate(testSubject)).toBe(false);
    })

    it("ValidateMissingFields7", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request.object.spec = null;
        expect(AdmissionReviewValidator.Validate(testSubject)).toBe(false);
    })
});