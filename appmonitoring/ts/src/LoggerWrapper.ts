import telemetryClient from "./telemetryClient.cjs";
import * as applicationInsights from "applicationinsights";

import { PodInfo } from "./RequestDefinition.js";

import log4js from "log4js";
import { InstrumentationCRsCollection } from "./InstrumentationCRsCollection.js";

const { configure, getLogger } = log4js;

configure({
    appenders: {
        console: {
            layout: {
                type: "coloured",
            },
            type: "stdout",
        },
        file: {
            filename: "all-the-logs.log",
            layout: {
                type: "coloured",
            },
            type: "file",
        },
    },
    categories: {
        default: {
            appenders: [/*"file",*/ "console"],
            level: "debug",
        },
    },
});

export class RequestMetadata {
    private uid: string;
    private podInfo: PodInfo;
    private crs: InstrumentationCRsCollection;

    public constructor(uid: string, crs: InstrumentationCRsCollection) {
        this.uid = uid;
        this.crs = crs;
    }
}

class ClusterMetadata {
    private clusterArmId: string;
    private clusterArmRegion: string;
    private podName: string;
    private imageTag: string;

    public constructor(clusterArmId: string, clusterArmRegion: string, podName: string, imageTag: string) {
        this.clusterArmId = clusterArmId;
        this.clusterArmRegion = clusterArmRegion;
        this.podName = podName;
        this.imageTag = imageTag;
    }
}

export enum Watchdogs {
    SecondsSinceLastSuccessfulCRList = 0 // number of seconds elapsed since the last successful list CRs call
}

// the list is not exhaustive, use operationId to look for a complete event chain for a particular failure
export enum Events {
    ServerModeRun = 0, // the image is run as a webhook
    CertificateManagerModeRun, // the image is run as a certificate manager (initial certificate installation)
    CertificateManagerModeRunSuccess, // CertificateManagerModeRun succeeded
    CertificateManagerModeRunFailure, // CertificateManagerModeRun failed
    SecretsHouseKeeperModeRun, // the image is run as a secret housekeeper (periodic run to reconcile and rotate if necessary)
    SecretsHouseKeeperModeRunSuccess, // SecretsHouseKeeperModeRun succeeded
    SecretsHouseKeeperModeRunFailure, // SecretsHouseKeeperModeRun failed

    ArmIdIncorrect, // ARM ID of the cluster we have received is incorrect
    CertificateLoadFailure, // we have failed to load certificates
    WatchHung // watch.watch() has hung, so we had to use our own timeout
}

export enum HeartbeatMetrics {
    CRCount = 0, // number of CRs that the cluster has
    InstrumentedNamespaceCount, // number of namespaces in the cluster that have at least one CR
    CRsListCallSucceededCount, // number of successful list CR calls
    CRsListCallFailedCount, // number of failed list CR calls
    CRsWatchCallSucceededCount, // number of successful watch CR calls
    CRsWatchCallFailedCount, // number of failed watch CR calls
    AdmissionReviewCount, // number of admission reviews submitted to the webhook
    AdmissionReviewActionableCount, // number of admission reviews that had a relevant CR and lead to actual mutation
    AdmissionReviewFailedCount, // number of failed admission reviews
}

export enum HeartbeatLogs {
    ApiServerTopExceptionsEncountered = 0, // top exceptions encountered by count when calling API server
    AdmissionReviewTopExceptionsEncountered, // top exceptions encountered during mutation by count
}

class HeartbeatAccumulator {
    // metric name => (dim1 => value)
    public metrics : Map<HeartbeatMetrics, Map<string, number>> = new Map<HeartbeatMetrics, Map<string, number>>();

    // log name => (log message => count)
    public logs : Map<HeartbeatLogs, Map<string, number>> = new Map<HeartbeatLogs, Map<string, number>>();
}

class LocalLogger {
    public static Instance(clusterArmId: string, clusterArmRegion: string, podName: string, imageTag: string) {
        if (!LocalLogger.instance) {
            LocalLogger.instance = new LocalLogger(clusterArmId, clusterArmRegion, podName, imageTag);
        }

        return LocalLogger.instance;
    }

    public sanitizeException(e: any): any {
        if(e?.response?.request?.headers?.Authorization) {
            e.response.request.headers.Authorization = "<redacted>";
        }

        return e;
    }

    public setUnitTestMode(isUnitTestMode: boolean) {
        this.isUnitTestMode = isUnitTestMode;

        if(isUnitTestMode) {
            this.client = new applicationInsights.TelemetryClient("InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/"); // goes nowhere, empty GUID
        }
    }

    private static instance: LocalLogger = null;

    private isUnitTestMode = false;
    private log: log4js.Logger = getLogger("default");
    private client: applicationInsights.TelemetryClient;
    private clusterMetadata: ClusterMetadata;
    
    private heartbeatAccumulator: HeartbeatAccumulator = new HeartbeatAccumulator();
    private watchdogs: Map<Watchdogs, () => number> = new Map<Watchdogs, () => number>();

    private heartbeatRequestMetadata = new RequestMetadata(null, null);

    private constructor(clusterArmId: string, clusterArmRegion: string, podName: string, imageTag: string) {
        this.client = telemetryClient.telemetryClient;

        this.clusterMetadata = new ClusterMetadata(clusterArmId, clusterArmRegion, podName, imageTag);

        this.log.info(`Application Insights has been set up and started. Default telemetry client is: ${this.client}, cluster metadata: ${JSON.stringify(this.clusterMetadata)}`);
    }

    public trace(message: string, operationId: string, requestMetadata: RequestMetadata) {
        if(requestMetadata) {
            this.log.trace(message, operationId, this.clusterMetadata, requestMetadata);
        } else {
            this.log.trace(message, operationId, this.clusterMetadata);
        }
    }

    public debug(message: string, operationId: string, requestMetadata: RequestMetadata) {
        if(requestMetadata) {
            this.log.debug(message, operationId, this.clusterMetadata, requestMetadata);
        } else {
            this.log.debug(message, operationId, this.clusterMetadata);
        }
    }

    public info(message: string, operationId: string, requestMetadata: RequestMetadata) {
        if(requestMetadata) {
            this.log.info(message, operationId, this.clusterMetadata, JSON.stringify(requestMetadata));
        } else {
            this.log.info(message, operationId, this.clusterMetadata);
        }
    }

    public warn(message: string, operationId: string, requestMetadata: RequestMetadata) {
        if(requestMetadata) {
            this.log.warn(message, operationId, this.clusterMetadata, requestMetadata);
        } else {
            this.log.warn(message, operationId, this.clusterMetadata);
        }
    }

    public error(message: string, operationId: string, requestMetadata: RequestMetadata) {
        if(requestMetadata) {
            this.log.error(message, operationId, this.clusterMetadata, requestMetadata);
        } else {
            this.log.error(message, operationId, this.clusterMetadata);
        }
    }

    public fatal(message: string, operationId: string, requestMetadata: RequestMetadata) {
        if(requestMetadata) {
            this.log.fatal(message, operationId, this.clusterMetadata, requestMetadata);
        } else {
            this.log.fatal(message, operationId, this.clusterMetadata);
        }
    }

    public mark(message: string, operationId: string, requestMetadata: RequestMetadata) {
        if(requestMetadata) {
            this.log.mark(message, operationId, this.clusterMetadata, requestMetadata);
        } else {
            this.log.mark(message, operationId, this.clusterMetadata);
        }
    }

    public setHeartbeatMetric(metricName: HeartbeatMetrics, value: number, dim1 = ""): void {
        if(!this.heartbeatAccumulator.metrics.get(metricName)) {
            this.heartbeatAccumulator.metrics.set(metricName, new Map<string, number>());
        }

        this.heartbeatAccumulator.metrics.get(metricName).set(dim1, value);
    }

    public addHeartbeatMetric(metricName: HeartbeatMetrics, valueToAdd: number, dim1 = ""): void {
        if(!this.heartbeatAccumulator.metrics.get(metricName)) {
            this.heartbeatAccumulator.metrics.set(metricName, new Map<string, number>());
            this.heartbeatAccumulator.metrics.get(metricName).set(dim1, 0);
        }

        if(!this.heartbeatAccumulator.metrics.get(metricName).get(dim1)) {
            this.heartbeatAccumulator.metrics.get(metricName).set(dim1, 0);
        }

        this.heartbeatAccumulator.metrics.get(metricName).set(dim1, this.heartbeatAccumulator.metrics.get(metricName).get(dim1) + valueToAdd);
    }

    public appendHeartbeatLog(logName: HeartbeatLogs, log: string) {
        if(!this.heartbeatAccumulator.logs.get(logName)) {
            this.heartbeatAccumulator.logs.set(logName, new Map<string, number>());
        }

        if(!this.heartbeatAccumulator.logs.get(logName).get(log)) {
            this.heartbeatAccumulator.logs.get(logName).set(log, 0);
        }

        this.heartbeatAccumulator.logs.get(logName).set(log, this.heartbeatAccumulator.logs.get(logName).get(log) + 1);
    }

    public registerWatchdog(name: Watchdogs, onReport: () => number) {
        this.watchdogs.set(name, onReport);
    }

    // periodically sends out accumulated heartbeat telemetry
    public async startHeartbeats(operationId: string): Promise<void> {
        while (true) { // eslint-disable-line
            try {
                logger.info(`Sending heartbeat...`, operationId, this.heartbeatRequestMetadata);
                await this.sendHeartbeat(operationId);
            } catch (e) {
                logger.error(`Failed to send out heartbeat: ${JSON.stringify(logger.sanitizeException(e))}`, operationId, this.heartbeatRequestMetadata);
            } finally {
                // pause until the next heartbeat
                if(!this.isUnitTestMode) {
                    await new Promise(r => setTimeout(r, 5 * 60 * 1000)); // in ms
                }
            }

            // unit tests only
            if (this.isUnitTestMode) {
                break;
            }
        }
    }

    private async sendHeartbeat(operationId: string, flush = false) {
        for(const [metricName, metric] of this.heartbeatAccumulator.metrics) {
            for(const [dim1, value] of metric) {
                const telemetryItem: applicationInsights.Contracts.MetricPointTelemetry & applicationInsights.Contracts.MetricTelemetry = {
                    name: HeartbeatMetrics[metricName],
                    value: value,
                    count: 1,
                    properties: {
                        dimension1: dim1,
                        operationId: operationId,
                        clusterMetadata: JSON.stringify(this.clusterMetadata)
                    }
                };

                this.client.trackMetric(telemetryItem);
            }
        }

        this.heartbeatAccumulator.metrics.clear();

        for(const [logName, logMap] of this.heartbeatAccumulator.logs) {
            const logArray = Array.from(logMap, ([key, value]) => ({ message: key, count: value }));
            
            logArray.sort((one, two) => (one.count > two.count ? -1 : 1));

            // send top N logs by count of this type
            let i = 0;
            for(let j = 0; j < logArray.length; j++) {
                if(i++ >= 5) {
                    break;
                }

                const telemetryItem: applicationInsights.Contracts.TraceTelemetry  = {
                    message: logArray[j].message,
                    properties: {
                        logName: HeartbeatLogs[logName],
                        operationId: operationId,
                        clusterMetadata: JSON.stringify(this.clusterMetadata)
                    }
                };

                this.client.trackTrace(telemetryItem);
            }
        }

        this.heartbeatAccumulator.logs.clear();

        for(const [watchdog, onReport] of this.watchdogs) {
            const telemetryItem: applicationInsights.Contracts.MetricPointTelemetry & applicationInsights.Contracts.MetricTelemetry = {
                name: Watchdogs[watchdog],
                value: onReport(),
                count: 1,
                properties: {
                    operationId: operationId,
                    clusterMetadata: JSON.stringify(this.clusterMetadata)
                }
            };

            this.client.trackMetric(telemetryItem);
        }

        if (flush) {
            await this.client.flush();
        }
    }

    public async SendEvent(eventName: string, operationId: string, uid: string, clusterArmId: string, clusterArmRegion: string, flush = false, ...args: unknown[]): Promise<void> {
        try {
            const event: applicationInsights.Contracts.EventTelemetry = {
                name: eventName,
                properties: {
                    extra: JSON.stringify(args),
                    operationId: operationId,
                    clusterArmId: clusterArmId,
                    clusterArmRegion: clusterArmRegion,
                    clusterMetadata: JSON.stringify(this.clusterMetadata),
                    uid: uid
                }
            };

            this.client.trackEvent(event);

            if (flush) {
                await this.client.flush();
            }
        } catch (e) {
            try {
                logger.error(`Failed to send out an event: ${JSON.stringify(logger.sanitizeException(e))}`, operationId, this.heartbeatRequestMetadata);
            } catch (e) {
                // swallow, no recourse
            }
        }
    }
}

export const logger = LocalLogger.Instance(process.env.ARM_ID, process.env.ARM_REGION, process.env.POD_NAME, process.env.IMAGE_TAG);