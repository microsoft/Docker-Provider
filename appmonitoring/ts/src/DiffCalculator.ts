import { isNullOrUndefined } from "util";
import { AddedTypes } from "./AddedTypes.js";
import { logger, Metrics } from "./LoggerWrapper.js";
import { DeployReplica, IRootObject } from "./RequestDefinition.js";

export class DiffCalculator {
    public static async CalculateDiff(content: IRootObject, extraData: DeployReplica): Promise<object> {

        if (isNullOrUndefined(content)) {
            logger.error(`Null content ${this.uid(content)}`);
            return null;
        }

        /* tslint:disable */
        logger.info(`Calculating diff ${this.uid(content)}, ${content}`);
        const updatedContent: IRootObject = JSON.parse(JSON.stringify(content));

        let updateTarget: object;

        try {
            updateTarget = updatedContent.request.object.spec.template.spec;
            logger.info(`Updating request.object.spec.template.spec ${this.uid(content)}, ${content}`);
        }
        catch (ex) {
            updateTarget = updatedContent.request.object.spec;
            logger.info(`Updating request.object.spec ${this.uid(content)}, ${content}`);
        }

        if (updateTarget["initContainers"]) {
            Array.prototype.push.apply(updateTarget["initContainers"], AddedTypes.init_containers());
        } else {
            updateTarget["initContainers"] = AddedTypes.init_containers();
        }

        if (updateTarget["volumes"]) {
            Array.prototype.push.apply(updateTarget["volumes"], AddedTypes.volumes());
        } else {
            updateTarget["volumes"] = AddedTypes.volumes();
        }

        const length = updateTarget["containers"].length;
        logger.telemetry(Metrics.CPContainers, length, this.uid(content));

        for (let i = 0; i < length; i++) {
            if (updateTarget["containers"][i].env) {
                Array.prototype.push.apply(updateTarget["containers"][i].env,await AddedTypes.env(extraData));
            } else {
                updateTarget["containers"][i].env = AddedTypes.env(extraData);
            }

            if (updateTarget["containers"][i].volumeMounts) {
                Array.prototype.push.apply(updateTarget["containers"][i].volumeMounts, AddedTypes.volume_mounts());
            } else {
                updateTarget["containers"][i].volumeMounts = AddedTypes.volume_mounts();
            }
        }

        const jsonDiff = [
            {
                op: "replace",
                path: "/spec",
                value: updatedContent.request.object.spec
            }];
        /* tslint:enable */
        logger.info(`Determined diff ${this.uid(content)}, ${jsonDiff}`);
        return jsonDiff;
    }

    private static uid(content: IRootObject): string {
        if (content && content.request && content.request.uid) {
            return content.request.uid;
        }
        return "";
    }
}
