import { isNullOrUndefined } from "util";
import { AddedTypes } from "./AddedTypes.js";
import { logger, Metrics } from "./LoggerWrapper.js";
import { PodInfo, IRootObject } from "./RequestDefinition.js";

export class DiffCalculator {
    public static async CalculateDiff(content: IRootObject, podInfo: PodInfo, platforms: string[], connectionString: string, armId: string, armRegion: string, clusterName: string): Promise<object> {

        if (isNullOrUndefined(content)) {
            logger.error(`Null content ${this.uid(content)}`);
            return null;
        }

        logger.info(`Calculating diff ${this.uid(content)}, ${JSON.stringify(content)}`);
        const updatedContent: IRootObject = JSON.parse(JSON.stringify(content));

        let updateTarget: object;

        try {
            updateTarget = updatedContent.request.object.spec.template.spec;
            logger.info(`Updating request.object.spec.template.spec ${this.uid(content)}, ${JSON.stringify(content)}`);
        }
        catch (ex) {
            updateTarget = updatedContent.request.object.spec;
            logger.info(`Updating request.object.spec ${this.uid(content)}, ${JSON.stringify(content)}`);
        }

        const initContainers = AddedTypes.init_containers(platforms);
        if (updateTarget["initContainers"]) {
            Array.prototype.push.apply(updateTarget["initContainers"], initContainers);
        } else {
            updateTarget["initContainers"] = initContainers;
        }

        const volumes = AddedTypes.volumes(platforms);
        if (updateTarget["volumes"]) {
            Array.prototype.push.apply(updateTarget["volumes"], volumes);
        } else {
            updateTarget["volumes"] = volumes;
        }

        const length = updateTarget["containers"].length;
        logger.telemetry(Metrics.CPContainers, length, this.uid(content));

        const env: object = AddedTypes.env(podInfo, platforms, connectionString, armId, armRegion, clusterName);
        for (let i = 0; i < length; i++) {
            if (updateTarget["containers"][i].env) {
                Array.prototype.push.apply(updateTarget["containers"][i].env, env);
            } else {
                updateTarget["containers"][i].env = env;
            }

            const volumeMounts: object = AddedTypes.volume_mounts(platforms);
            if (updateTarget["containers"][i].volumeMounts) {
                Array.prototype.push.apply(updateTarget["containers"][i].volumeMounts, volumeMounts);
            } else {
                updateTarget["containers"][i].volumeMounts = volumeMounts;
            }
        }

        const jsonDiff = [
            {
                op: "replace",
                path: "/spec",
                value: updatedContent.request.object.spec
            }];
        
        logger.info(`Determined diff ${this.uid(content)}, ${JSON.stringify(jsonDiff)}`);

        return jsonDiff;
    }

    private static uid(content: IRootObject): string {
        if (content && content.request && content.request.uid) {
            return content.request.uid;
        }
        return "";
    }
}
