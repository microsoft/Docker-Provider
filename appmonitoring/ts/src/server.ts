import fs = require("fs");
import https = require("https");
import request = require("request");
import { ContentProcessor } from "./ContentProcessor";
import { logger, Metrics } from "./LoggerWrapper";
import { IRootObject } from "./RequestDefinition";

let options;
const port = process.env.port || 1337;

logger.info(`listening on port ${port}`, "");
try {
    options = {
        cert: fs.readFileSync("/mnt/webhook/cert.pem"),
        key: fs.readFileSync("/mnt/webhook/key.pem"),
    };
    logger.info("loaded certificates from /mnt", "");
} catch {
    options = {
        cert: fs.readFileSync("./../../server-cert.pem"),
        key: fs.readFileSync("./../../server-key.pem"),
    };
    logger.info("loaded certs from local", "");
}

https.createServer(options, (req, res) => {
    logger.info(`received request with url: ${req.url}, method: ${req.method}, content-type: ${req.headers["content-type"]}`, "");
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
                logger.info("done processing request", uid);
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(updatedConfig);
                logger.telemetry(Metrics.Success, 1, uid);
            }).catch((error) => {
                logger.error(`error while processing request`, uid, error);
                logger.telemetry(Metrics.Fail, 1, uid);
            });
        });
    } else {
        logger.error("unaccepable method, returning 404", "", req.method);
        res.writeHead(404);
        res.end();
        logger.telemetry(Metrics.Error, 1, "");
    }

}).listen(port);
