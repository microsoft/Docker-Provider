import { isNullOrUndefined } from "util";
import { logger, Metrics } from "./LoggerWrapper.js";
import { IAdmissionReview } from "./RequestDefinition.js";

export class AdmissionReviewValidator {
    public static Validate(content: IAdmissionReview) {
        let returnValue = true;
        logger.info(`Validating content ${this.uid(content)}, ${JSON.stringify(content)}`);

        if (isNullOrUndefined(content)) {
            logger.error(`Null content ${this.uid(content)}`);
            returnValue = false;
        } else if (isNullOrUndefined(content.request)
            || isNullOrUndefined(content.request.operation)) {
            logger.error(`Invalid incoming operation ${this.uid(content)}`);
            returnValue = false;
        } else if (isNullOrUndefined(content.kind)) {
            logger.error(`Invalid empty kind ${this.uid(content)}`);
            returnValue = false;
        } else if (isNullOrUndefined(content.request.object)
            || isNullOrUndefined(content.request.object.spec)) {
            logger.error(`Missing object or object.spec in template, DELETE operations are not supported ${this.uid(content)}, ${content}`);
            returnValue = false;
        } else if(content.request.kind.kind.toUpperCase() !== "POD") {
            logger.error(`Invalid incoming object kind, the webhook only supports Pods: ${content.request.kind.kind}`);
            returnValue = false;
        } else if(content.request.operation.toUpperCase() !== "CREATE" && content.request.operation.toUpperCase() !== "UPDATE") {
            logger.error(`Invalid operation, the webhook only supports CREATE and UPDATE: ${content.request}`);
            returnValue = false;
        } else if(content.kind !== "AdmissionReview" && content.kind !== "Testing") {
            logger.error(`Invalid kind of the incoming document, the webhook only supports AdmissionReview: ${content.kind}`);
            returnValue = false;
        }

        logger.info(`Successfully validated content ${this.uid(content)}, ${content}`);
        logger.telemetry(returnValue ? Metrics.CPValidationPass : Metrics.CPValidationFail, 1, this.uid(content));
        return returnValue;
    }

    private static uid(content: IAdmissionReview): string {
        if (content && content.request && content.request.uid) {
            return content.request.uid;
        }
        return "";
    }
}
