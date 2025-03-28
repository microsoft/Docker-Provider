import { isNullOrUndefined } from "util";
import { logger, RequestMetadata } from "./LoggerWrapper.js";
import { IAdmissionReview } from "./RequestDefinition.js";

export interface IValidationResult {
    isValid: boolean;
    message?: string;
}

export class AdmissionReviewValidator {
    public static Validate(content: IAdmissionReview): IValidationResult { 

        if (isNullOrUndefined(content)) {
            return {
                message: `Empty request`,
                isValid: false
            };
        }

        if (isNullOrUndefined(content.kind)) {
            return {
                message: `Invalid empty request kind ${content.request?.uid}`,
                isValid: false
            };
        } 

        if(content.kind !== "AdmissionReview" && content.kind !== "Testing") {
            return {
                message: `Invalid kind of the incoming document, the webhook only supports AdmissionReview: ${content.kind} ${content.request?.uid}`,
                isValid: false
            };
        }
        
        if (isNullOrUndefined(content.request)
            || isNullOrUndefined(content.request.operation)) {
            return {
                message: `Invalid incoming operation ${content.request.uid}`,
                isValid: false
            };
        } 

        if (content.request.operation.toUpperCase() !== "CREATE" 
            && content.request.operation.toUpperCase() !== "UPDATE") {
            return {
                message: `Invalid operation, the webhook only supports CREATE and UPDATE: ${content.request.operation} ${content.request.uid}`,
                isValid: false
            };
        } 

        if (isNullOrUndefined(content.request.object)) {           
            return {
                message: `Missing config object in request, DELETE operations are not supported ${content.request.uid}, ${content}`,
                isValid: false
            };
        } 

        if (isNullOrUndefined(content.request.object.spec)
            || isNullOrUndefined(content.request.object.spec.template.spec)) {           
            return {
                message: `Missing object.spec or template.spec, DELETE operations are not supported ${content.request.uid}, ${content}`,
                isValid: false
            };
        } 

        if (isNullOrUndefined(content.request.object.metadata.namespace)){
            return {
                message: `Missing object.metadata.namespace ${content.request.uid}`,
                isValid: false
            };
        }
 
        if (content.request.resource?.resource?.toLowerCase() === "deployments") {
            return { 
                message: "deployments",
                isValid: true
            };
        } else {
            return {
                message: `Unsupported incoming resource type: ${content.request.resource.resource}`,
                isValid: false
            };
        }
    }
}
