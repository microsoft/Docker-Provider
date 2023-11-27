import { expect, describe, it } from "@jest/globals";
import { IAdmissionReview } from "../RequestDefinition.js";
import { AdmissionReviewValidator } from "../AdmissionReviewValidator.js";
import { TestObject2 } from "./testConsts.js";
import { logger, RequestMetadata } from "../LoggerWrapper.js";

const requestMetadata = new RequestMetadata(null, null);

beforeEach(() => {
    logger.setUnitTestMode(true);
});

afterEach(() => {
    jest.restoreAllMocks();
});

describe("AdmissionReviewValidator", () => {
    it("ValidateNull", () => {
        expect(AdmissionReviewValidator.Validate(null, null, requestMetadata)).toBe(false);
    })

    it("ValidateMissingFields", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request = null

        expect(AdmissionReviewValidator.Validate(testSubject, null, requestMetadata)).toBe(false);
    })

    it("ValidateMissingFields2", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request.operation = null;

        expect(AdmissionReviewValidator.Validate(testSubject, null, requestMetadata)).toBe(false);
    })

    it("ValidateMissingFields3", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request.operation = "nope";

        expect(AdmissionReviewValidator.Validate(testSubject, null, requestMetadata)).toBe(false);
    })

    it("ValidateMissingFields4", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.kind = null;

        expect(AdmissionReviewValidator.Validate(testSubject, null, requestMetadata)).toBe(false);
    })

    it("ValidateMissingFields6", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request.object = null;

        expect(AdmissionReviewValidator.Validate(testSubject, null, requestMetadata)).toBe(false);
    })

    it("ValidateMissingFields7", () => {
        const testSubject: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        testSubject.request.object.spec = null;
        expect(AdmissionReviewValidator.Validate(testSubject, null, requestMetadata)).toBe(false);
    })
});