//import * as fs from "fs";
import * as https from "https";
import { ContentProcessor } from "./ContentProcessor.js";
import { logger, Metrics } from "./LoggerWrapper.js";
import { IRootObject } from "./RequestDefinition.js";
import { K8sWatcher } from "./K8sWatcher.js";

// don't await, this runs an infinite loop
K8sWatcher.StartWatchingCRs();

/*let options: https.ServerOptions;
try {
    options = {
        cert: fs.readFileSync("/mnt/webhook/tls.cert"),
        key: fs.readFileSync("/mnt/webhook/tls.key"),
    };
} catch (e) {
    logger.error(`Failed to load certs: ${e}`);
}*/

const port = process.env.port || 1337;
logger.info(`listening on port ${port}`);

https.createServer(/*options*/null, (req, res) => {
    logger.info(`Received request with url: ${req.url}, method: ${req.method}, content-type: ${req.headers["content-type"]}`);
    logger.telemetry(Metrics.Request, 1, "");
    if (req.method === "POST" && req.headers["content-type"] === "application/json") {
        let body = "";
        req.on("data", (chunk) => {
            body += chunk.toString(); // convert Buffer to string
        });
        req.on("end", () => {
            let uid = "";
            try {
                const message: IRootObject = JSON.parse(body);
                if (message && message.request && message.request.uid) {
                    uid = message.request.uid;
                }
            } catch (ex) {
                // swallow
            }
            ContentProcessor.TryUpdateConfig(body).then((updatedConfig) => {
                logger.info(`Done processing request ${uid}`);
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(updatedConfig);
                logger.telemetry(Metrics.Success, 1, uid);
            }).catch((error) => {
                logger.error(`Error while processing request: ${uid}, ${error}`);
                logger.telemetry(Metrics.Fail, 1, uid);
            });
        });
    } else {
        logger.error(`Unacceptable method, returning 404, method: ${req.method}`);
        res.writeHead(404);
        res.end();
        logger.telemetry(Metrics.Error, 1, "");
    }

}).listen(port);
