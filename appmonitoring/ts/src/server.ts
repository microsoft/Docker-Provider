import * as https from "https";
import { Mutator } from "./Mutator.js";
import { logger, Metrics } from "./LoggerWrapper.js";
import { AppMonitoringConfigCR, IAdmissionReview } from "./RequestDefinition.js";
import { K8sWatcher } from "./K8sWatcher.js";
import { AppMonitoringConfigCRsCollection } from "./AppMonitoringConfigCRsCollection.js"
import fs from "fs";
import { CertificateManager } from "./CertificateGenerator.js";

const containerMode = process.env.CONTAINER_MODE;

if ("secrets-manager".localeCompare(containerMode) === 0) {
    try {
        logger.info("Running in certificate manager mode...");
        await CertificateManager.CreateWebhookAndCertificates();
    } catch (error) {
        logger.error(JSON.stringify(error));
        logger.error("Failed to Install Certificates, Terminating...");
        throw error;
    }
    
    process.exit();
} 
const crs: AppMonitoringConfigCRsCollection = new AppMonitoringConfigCRsCollection();

logger.info("Running in server mode...");
// don't await, this runs an infinite loop
K8sWatcher.StartWatchingCRs((cr: AppMonitoringConfigCR, isRemoved: boolean) => {
    if (isRemoved) {
        crs.Remove(cr);
    } else {
        crs.Upsert(cr);
    }

    const items: AppMonitoringConfigCR[] = crs.ListCRs();
    let log = "CRs: [";
    for (let i = 0; i < items.length; i++) {
        log += `${items[i].metadata.namespace}/${items[i].metadata.name}, autoInstrumentationPlatforms=${items[i].spec.autoInstrumentationPlatforms}, aiConnectionString=${items[i].spec.aiConnectionString}}, deployments=${JSON.stringify(items[i].spec.deployments)}`;
    }

    log += "]"

    logger.info(log);
});

let options: https.ServerOptions;
try {
    options = {
        cert: fs.readFileSync("/mnt/webhook/tls.cert"),
        key: fs.readFileSync("/mnt/webhook/tls.key"),
    };

    logger.info(`Certs successfully loaded.`);
} catch (e) {
    logger.error(`Failed to load certs: ${e}`);
    throw e;
}

const port = process.env.port || 1337;
logger.info(`listening on port ${port}`);

https.createServer(options, (req, res) => {
    logger.info(`Received request with url: ${req.url}, method: ${req.method}, content-type: ${req.headers["content-type"]}`);
    logger.telemetry(Metrics.Request, 1, "");
    
    if (req.method === "POST" && req.headers["content-type"] === "application/json") {
        let body = "";

        req.on("data", (chunk) => {
            body += chunk.toString();
        });

        req.on("end", async () => {
            const begin = Date.now();

            try {
                const admissionReview: IAdmissionReview = JSON.parse(body);
                let uid: string;
                if (admissionReview?.request?.uid) {
                    uid = admissionReview.request.uid;
                } else {
                    throw `Unable to get request.uid from the incoming admission review: ${admissionReview}`
                }

                const mutatedPod: string = await Mutator.MutatePod(admissionReview, crs, process.env.ARM_ID, process.env.ARM_REGION);

                const end = Date.now();
                
                logger.info(`Done processing request in ${end - begin} ms for ${uid}`);
                logger.telemetry(Metrics.Success, 1, uid);

                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(mutatedPod);
            } catch (e) {
                logger.error(`Error while processing request: ${JSON.stringify(e)}. Incoming payload: ${body}`);
            }
        });
    } else {
        logger.error(`Unacceptable method, returning 404, method: ${req.method}`);
        logger.telemetry(Metrics.Error, 1, "");

        res.writeHead(404);
        res.end();
    }

}).listen(port);
