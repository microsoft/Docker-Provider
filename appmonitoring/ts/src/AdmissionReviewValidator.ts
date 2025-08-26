import { logger, RequestMetadata } from "./LoggerWrapper.js";
import { IAdmissionReview } from "./RequestDefinition.js";

export class AdmissionReviewValidator {
    public static Validate(content: IAdmissionReview, operationId: string, requestMetadata: RequestMetadata) {
        let returnValue = true;
        logger.info(`Validating content ${this.uid(content)}, ${JSON.stringify(content)}`, operationId, requestMetadata);

        if (content == null) {
            logger.error(`Null content`, operationId, requestMetadata);
            returnValue = false;
        } else if (content.request == null
            || content.request.operation == null) {
            logger.error(`Invalid incoming operation ${this.uid(content)}`, operationId, requestMetadata);
            returnValue = false;
        } else if (content.kind == null) {
            logger.error(`Invalid empty kind ${this.uid(content)}`, operationId, requestMetadata);
            returnValue = false;
        } else if (content.request.object == null
            || content.request.object?.spec == null
            || content.request.object?.spec?.template?.spec == null) {
            logger.error(`Missing object or object.spec in template, DELETE operations are not supported ${this.uid(content)}, ${content}`, operationId, requestMetadata);
            returnValue = false;
        } else if(content.request.resource?.resource?.toLowerCase() !== "deployments") {
            logger.error(`Invalid incoming resource type: ${content.request.resource.resource}`, operationId, requestMetadata);
            returnValue = false;
        } else if(content.request?.operation?.toUpperCase() !== "CREATE" && content.request?.operation?.toUpperCase() !== "UPDATE") {
            logger.error(`Invalid operation, the webhook only supports CREATE and UPDATE: ${content.request}`, operationId, requestMetadata);
            returnValue = false;
        } else if(content.kind !== "AdmissionReview" && content.kind !== "Testing") {
            logger.error(`Invalid kind of the incoming document, the webhook only supports AdmissionReview: ${content.kind}`, operationId, requestMetadata);
            returnValue = false;
        }

        return returnValue;
    }

    private static uid(content: IAdmissionReview): string {
        if (content && content.request && content.request.uid) {
            return content.request.uid;
        }
        return "";
    }
}
