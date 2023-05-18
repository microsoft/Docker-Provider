import { config } from "chai";
import { isNullOrUndefined } from "util";
import { logger, Metrics } from "./LoggerWrapper";
import { IRootObject } from "./RequestDefinition";

export class TemplateValidator {
    public static ValidateContent(content: IRootObject) {
        let returnValue = true;
        logger.info(`validating content`, this.uid(content), content);

        if (isNullOrUndefined(content)) {
            logger.error("null content", this.uid(content));
            returnValue = false;
        } else if (isNullOrUndefined(content.request)
            || isNullOrUndefined(content.request.operation)
            || (content.request.operation !== "CREATE"
                && content.request.operation !== "UPDATE")) {

            logger.error("invalid incoming operation", this.uid(content));
            returnValue = false;
        } else if (isNullOrUndefined(content.kind)
            || (content.kind !== "AdmissionReview" && content.kind !== "Testing")) {

            logger.error("invalid incoming kind", this.uid(content), content.kind);
            returnValue = false;
        } else if (isNullOrUndefined(content.request.object)
            || isNullOrUndefined(content.request.object.spec)) {

            logger.error("missing spec in template", this.uid(content), content);
            returnValue = false;
        }

        logger.info(`succesfully validated content`, this.uid(content), content);
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
