import * as fs from "fs";
import * as https from "https";
import { ContentProcessor } from "./ContentProcessor.js";
import { logger, Metrics } from "./LoggerWrapper.js";
import { AppMonitoringConfigCR, IRootObject } from "./RequestDefinition.js";
import { K8sWatcher } from "./K8sWatcher.js";
import { AppMonitoringConfigCRsCollection } from "./AppMonitoringConfigCRsCollection.js"

const crs: AppMonitoringConfigCRsCollection = new AppMonitoringConfigCRsCollection();

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

    logger.info(`Certs successfully loaded. Cert: ${options.cert}`);
} catch (e) {
    logger.error(`Failed to load certs: ${e}`);
}

const port = process.env.port || 1337;
logger.info(`listening on port ${port}`);

https.createServer(options, (req, res) => {
    logger.info(`Received request with url: ${req.url}, method: ${req.method}, content-type: ${req.headers["content-type"]}`);
    logger.telemetry(Metrics.Request, 1, "");
    
    if (req.method === "POST" && req.headers["content-type"] === "application/json") {
        let body = "";

        req.on("data", (chunk) => {
            body += chunk.toString(); // convert Buffer to string
        });

        req.on("end", async () => {
            let uid = "";
            try {
                const message: IRootObject = JSON.parse(body);
                if (message?.request?.uid) {
                    uid = message.request.uid;
                }
            } catch (e) {
                // swallow
                logger.error(JSON.stringify(e));
            }

            try {
                const updatedConfig: string = await ContentProcessor.TryUpdateConfig(body, crs);
                
                logger.info(`Done processing request ${uid}`);
                logger.telemetry(Metrics.Success, 1, uid);

                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(updatedConfig);
            } catch (e) {
                logger.error(`Error while processing request: ${uid}, ${JSON.stringify(e)}`);
                logger.telemetry(Metrics.Fail, 1, uid);
            }
        });
    } else {
        logger.error(`Unacceptable method, returning 404, method: ${req.method}`);
        logger.telemetry(Metrics.Error, 1, "");

        res.writeHead(404);
        res.end();
    }

}).listen(port);
