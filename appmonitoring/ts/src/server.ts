import * as http from "http";
import * as https from "https";
import { Mutator } from "./Mutator.js";
import { Events, HeartbeatMetrics, HeartbeatLogs, logger, RequestMetadata } from "./LoggerWrapper.js";
import { InstrumentationCR, IAdmissionReview, OtelParams } from "./RequestDefinition.js";
import { K8sWatcher } from "./K8sWatcher.js";
import { InstrumentationCRsCollection } from "./InstrumentationCRsCollection.js"
import fs from "fs";
import { CertificateManager } from "./CertificateManager.js";
import { randomUUID } from 'crypto';

const containerMode = process.env.CONTAINER_MODE;
const clusterArmId = process.env.ARM_ID;
const clusterArmRegion = process.env.ARM_REGION;
const otelParams: OtelParams = {
    logsEnabled: String(process.env.OTEL_LOGS_ENABLED).trim().toLowerCase() === "true",
    metricsEnabled: String(process.env.OTEL_METRICS_ENABLED).trim().toLowerCase() === "true",
    logsPortHttpProtobuf: Number(process.env.OTEL_LOGS_PORT_HTTPPROTOBUF) || 28331,
    metricsPortHttpProtobuf: Number(process.env.OTEL_METRICS_PORT_HTTPPROTOBUF) || 28333
};

let operationId = randomUUID();

if ("secrets-manager".localeCompare(containerMode) === 0) {
    try {
        logger.info("Running in certificate manager mode...", operationId, null);
        await logger.SendEvent(Events[Events.CertificateManagerModeRun], operationId, null, true);
        await new CertificateManager().CreateWebhookAndCertificates(operationId);
        logger.info("Certificate manager mode is done", operationId, null);
        await logger.SendEvent(Events[Events.CertificateManagerModeRunSuccess], operationId, null, true);
    } catch (error) {
        logger.error(`Certificate manager mode failed: ${JSON.stringify(error)}`, operationId, null);
        await logger.SendEvent(Events[Events.CertificateManagerModeRunFailure], operationId, null, true, error);
        throw error;
    }

    process.exit();
} else if ("secrets-housekeeper".localeCompare(containerMode) === 0) {
    try {
        logger.info("Running in certificate housekeeper mode...", operationId, null);
        await logger.SendEvent(Events[Events.SecretsHouseKeeperModeRun], operationId, null, true);
        await new CertificateManager().ReconcileWebhookAndCertificates(operationId);
        logger.info("Certificate housekeeper mode is done", operationId, null);
        await logger.SendEvent(Events[Events.SecretsHouseKeeperModeRunSuccess], operationId, null, true);
    } catch (error) {
        logger.error(`Failed to update certificates, terminating...\n${JSON.stringify(error)}`, operationId, null);
        await logger.SendEvent(Events[Events.SecretsHouseKeeperModeRunFailure], operationId, null, true, error);
        throw error;
    }

    process.exit();
}

const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();

logger.info("Running in server mode...", operationId, null);
await logger.SendEvent(Events[Events.ServerModeRun], operationId, null, true);

const armIdMatches = /^\/subscriptions\/(?<SubscriptionId>[^/]+)\/resourceGroups\/(?<ResourceGroup>[^/]+)\/providers\/(?<Provider>[^/]+)\/(?<ResourceType>[^/]+)\/(?<ResourceName>[^/]+).*$/i.exec(clusterArmId);
if (!armIdMatches || armIdMatches.length != 6) {
    logger.error(`Cluster ARM ID is in a wrong format: ${clusterArmId}`, operationId, null);
    await logger.SendEvent(Events[Events.ArmIdIncorrect], operationId, null, true);
    throw `Cluster ARM ID is in a wrong format: ${clusterArmId}`;
}

// don't await, this runs an infinite loop in the background
logger.startHeartbeats(operationId);

// don't await, this runs an infinite loop
K8sWatcher.StartWatchingCRs(crs,
    (cr: InstrumentationCR, isRemoved: boolean) => {
        if (isRemoved) {
            crs.Remove(cr);
        } else {
            crs.Upsert(cr);
        }

        logCRs(crs);
    },
    (crsToResetWith: InstrumentationCR[]) => {
        crs.Reset(crsToResetWith);

        logCRs(crs);
    },
    operationId);

let options: https.ServerOptions;
try {
    options = {
        cert: fs.readFileSync("/mnt/webhook/tls.cert"),
        key: fs.readFileSync("/mnt/webhook/tls.key"),
    };

    logger.info(`Certs successfully loaded`, operationId, null);
} catch (e) {
    logger.error(`Failed to load certs: ${e}`, operationId, null);
    await logger.SendEvent(Events[Events.CertificateLoadFailure], operationId, null, true, e);
    throw e;
}

const promPort = process.env.PROM_PORT;
logger.info(`Prom endpoint is available on port ${promPort}`, operationId, null);
const promServer = http.createServer(async (req, res) => {
    if (req.method === "GET" && (req.url === "/metrics" || req.url === "/metrics/") && logger?.Register) {
        try {
            res.writeHead(200, { "Content-Type": logger.Register.contentType });
            res.end(await logger.Register.metrics());
        } catch (e) {
            res.writeHead(500, { "Content-Type": "application/json" });
            res.end(JSON.stringify(e));
        }
    } else {
        res.writeHead(404);
        res.end('Not Found');
    }
}).listen(promPort);

const port = process.env.WEBHOOK_PORT;
logger.info(`Webhook is listening on port ${port}`, operationId, null);

const server = https.createServer(options, (req, res) => {
    logger.info(`Received request with url: ${req.url}, method: ${req.method}, content-type: ${req.headers["content-type"]}`, operationId, null);
    
    logger.addHeartbeatMetric(HeartbeatMetrics.AdmissionReviewCount, 1);

    if (req.method === "POST" && req.headers["content-type"] === "application/json") {
        let body = "";

        req.on("data", (chunk) => {
            body += chunk.toString();
        });

        req.on("end", async () => {
            const begin = Date.now();

            let requestMetadata = new RequestMetadata(null, crs);
            operationId = randomUUID();

            try {
                const admissionReview: IAdmissionReview = JSON.parse(body);

                let uid: string;
                if (admissionReview?.request?.uid) {
                    uid = admissionReview.request.uid;
                    requestMetadata = new RequestMetadata(uid, crs);
                } else {
                    throw `Unable to get request.uid from the incoming admission review`;
                }

                const mutator: Mutator = new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, operationId, otelParams);
                const mutatedObject: string = await mutator.Mutate();

                const end = Date.now();
                
                logger.info(`Done processing request in ${end - begin} ms for ${uid}. ${JSON.stringify(mutatedObject)}`, operationId, requestMetadata);
                
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(mutatedObject);
            } catch (e) {
                const ex = logger.sanitizeException(e);

                // e must not contain any customer content for privacy reasons, this exception is logged to a Microsoft-owned resource
                logger.appendHeartbeatLog(HeartbeatLogs.AdmissionReviewTopExceptionsEncountered, JSON.stringify(ex));

                logger.error(`Error while processing request: ${JSON.stringify(e)}. Incoming payload: ${body}`, operationId, requestMetadata);

                res.writeHead(500, { "Content-Type": "application/json" });
                res.end(JSON.stringify(ex));
            }
        });
    } else {
        logger.error(`Unacceptable method, returning 404, method: ${req.method}`, operationId, null);
        
        res.writeHead(404);
        res.end();
    }
}).listen(port);

logger.info(`Server created on port ${port}`, null, null);

function shutdownServers() {
    promServer.close((err) => {
        if (err) {
            logger.error(`Error shutting down prom server: ${err}`, operationId, null);
        } else {
            logger.info("Prom server has shut down gracefully", operationId, null);
        }
    });

    server.close((err) => {
        if (err) {
            logger.error(`Error shutting down server: ${err}`, operationId, null);
            process.exit(1);
        } else {
            logger.info("Server has shut down gracefully", operationId, null);
            process.exit(0);
        }
    });
}
  
// listen for process termination signals
process.on("SIGINT", shutdownServers);
process.on("SIGTERM", shutdownServers);

const keepAlive = new Promise<void>((resolve) => {
    process.on('SIGINT', resolve);
    process.on('SIGTERM', resolve);
});
  
// keep the event loop alive
await keepAlive;
  
logger.info("Server shut down, exiting now", operationId, null);

function logCRs(crs: InstrumentationCRsCollection) {
    const items: InstrumentationCR[] = crs.ListCRs();
    logger.setHeartbeatMetric(HeartbeatMetrics.CRCount, items.length);
    logger.CRCountSummary.observe(items.length);

    const uniqueNamespaces = new Set<string>(items.map(cr => cr.metadata.namespace, this));
    logger.setHeartbeatMetric(HeartbeatMetrics.InstrumentedNamespaceCount, uniqueNamespaces.size);
    logger.InstrumentedNamespaceCountSummary.observe(uniqueNamespaces.size);

    let log = "CRs: [";
    for (let i = 0; i < items.length; i++) {
        log += `${items[i].metadata.namespace}/${items[i].metadata.name}, autoInstrumentationPlatforms=${items[i].spec.settings.autoInstrumentationPlatforms}, applicationInsightsConnectionString=${items[i].spec.destination.applicationInsightsConnectionString}}`;
    }

    log += "]";

    logger.info(log, operationId, null);
}
