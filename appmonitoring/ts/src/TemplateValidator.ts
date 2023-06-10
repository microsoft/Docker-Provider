import { isNullOrUndefined } from "util";
import { logger, Metrics } from "./LoggerWrapper.js";
import { IRootObject } from "./RequestDefinition.js";

export class TemplateValidator {
    public static ValidateContent(content: IRootObject) {
        let returnValue = true;
        logger.info(`Validating content ${this.uid(content)}, ${content}`);

        if (isNullOrUndefined(content)) {
            logger.error(`Null content ${this.uid(content)}`);
            returnValue = false;
        } else if (isNullOrUndefined(content.request)
            || isNullOrUndefined(content.request.operation)
            || (content.request.operation !== "CREATE"
                && content.request.operation !== "UPDATE")) {

            logger.error(`Invalid incoming operation ${this.uid(content)}`);
            returnValue = false;
        } else if (isNullOrUndefined(content.kind)
            || (content.kind !== "AdmissionReview" && content.kind !== "Testing")) {

            logger.error(`Invalid incoming kind ${this.uid(content)}, ${content.kind}`);
            returnValue = false;
        } else if (isNullOrUndefined(content.request.object)
            || isNullOrUndefined(content.request.object.spec)) {

            logger.error(`Missing spec in template ${this.uid(content)}, ${content}`);
            returnValue = false;
        }

        logger.info(`Successfully validated content ${this.uid(content)}, ${content}`);
        logger.telemetry(returnValue ? Metrics.CPValidationPass : Metrics.CPValidationFail, 1, this.uid(content));
        return returnValue;
    }

    private static uid(content: IRootObject): string {
        if (content && content.request && content.request.uid) {
            return content.request.uid;
        }
        return "";
    }
}
