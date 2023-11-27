import * as applicationInsights from "applicationinsights";
import { EventTelemetry, MetricTelemetry, TraceTelemetry } from "applicationinsights/out/Declarations/Contracts";
import { PodInfo } from "./RequestDefinition.js";

import log4js from "log4js";
import { AppMonitoringConfigCRsCollection } from "./AppMonitoringConfigCRsCollection.js";

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
    private crs: AppMonitoringConfigCRsCollection;

    public constructor(uid: string, crs: AppMonitoringConfigCRsCollection) {
        this.uid = uid;
        this.crs = crs;
    }
}

class ClusterMetadata {
    private clusterArmId: string;
    private clusterArmRegion: string;
    private podName: string;

    public constructor(clusterArmId: string, clusterArmRegion: string, podName: string) {
        this.clusterArmId = clusterArmId;
        this.clusterArmRegion = clusterArmRegion;
        this.podName = podName;
    }
}

export enum HeartbeatMetrics {
    CRCount = 0, // number of CRs that the cluster has
    InstrumentedNamespaceCount, // number of namespaces in the cluster that have at least one CR
    ApiServerCallCount, // number of API calls made
    ApiServerCallErrorCount, // number of failed API calls
    AdmissionReviewCount, // number of admission reviews submitted to the webhook
    AdmissionReviewActionableCount, // number of admission reviews that had a relevant CR and lead to actual mutation
    AdmissionReviewActionableFailedCount, // number of failed admission reviews that had a relevant CR and lead to actual mutation
    CertificateOperationCount, // number of certificate operations performed
    CertificateOperationFaailedCount, // number of failed certificated operations performed
}

export enum HeartbeatLogs {
    ApiServerTopExceptionsEncountered = 0, // top exceptions encountered by count when calling API server
    AdmissionReviewTopExceptionsEncountered, // top exceptions encountered during mutation by count
    CertificateOperations, // certificate operations
}

class HeartbeatAccumulator {
    // metric name => value
    public metrics : Map<HeartbeatMetrics, number> = new Map<HeartbeatMetrics, number>();

    // log name => (log message => count)
    public logs : Map<HeartbeatLogs, Map<string, number>> = new Map<HeartbeatLogs, Map<string, number>>();
}

class LocalLogger {
    public static Instance(clusterArmId: string, clusterArmRegion: string, podName: string) {
        if (!LocalLogger.instance) {
            LocalLogger.instance = new LocalLogger(clusterArmId, clusterArmRegion, podName);
        }

        return LocalLogger.instance;
    }

    public setUnitTestMode(isUnitTestMode: boolean) {
        this.isUnitTestMode = isUnitTestMode;
    }

    private static instance: LocalLogger;

    private isUnitTestMode = false;
    private log: log4js.Logger = getLogger("default");
    private client: applicationInsights.TelemetryClient;
    private clusterMetadata: ClusterMetadata;
    
    private heartbeatAccumulator: HeartbeatAccumulator = new HeartbeatAccumulator();

    private heartbeatRequestMetadata = new RequestMetadata(null, null);

    private constructor(clusterArmId: string, clusterArmRegion: string, podName: string) {
        this.client = new applicationInsights.TelemetryClient(this.getKey());

        this.clusterMetadata = new ClusterMetadata(clusterArmId, clusterArmRegion, podName);
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

    public setHeartbeatMetric(metricName: HeartbeatMetrics, value: number): void {
        if(!this.heartbeatAccumulator.metrics[metricName]) {
            this.heartbeatAccumulator.metrics[metricName] = 0;
        }

        this.heartbeatAccumulator.metrics[metricName] = value;
    }

    public addHeartbeatMetric(metricName: HeartbeatMetrics, valueToAdd: number): void {
        if(!this.heartbeatAccumulator.metrics[metricName]) {
            this.heartbeatAccumulator.metrics[metricName] = 0;
        }

        this.heartbeatAccumulator.metrics[metricName] += valueToAdd;
    }

    public appendHeartbeatLog(logName: HeartbeatLogs, log: string) {
        if(!this.heartbeatAccumulator.logs[logName]) {
            this.heartbeatAccumulator.logs[logName] = new Map<HeartbeatLogs, Map<string, number>>();
        }

        if(!this.heartbeatAccumulator.logs[logName][log]) {
            this.heartbeatAccumulator.logs[logName][log] = 0;
        }

        this.heartbeatAccumulator.logs[logName][log]++;
    }

    // periodically sends out accumulated heartbeat telemetry
    public async startHeartbeats(operationId: string): Promise<void> {
        while (true) { // eslint-disable-line
            try {
                this.info(`Sending heartbeat...`, operationId, this.heartbeatRequestMetadata);
                this.sendHeartbeat();
            } catch (e) {
                logger.error(`Failed to send out heartbeat: ${e}`, operationId, this.heartbeatRequestMetadata);
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

    private sendHeartbeat() {
        if (this.client == null) {
            this.client = new applicationInsights.TelemetryClient(this.getKey());
        }

        for(const metricName in this.heartbeatAccumulator.metrics) {
            const telemetryItem: MetricTelemetry = {
                name: HeartbeatMetrics[metricName],
                value: Number(this.heartbeatAccumulator.metrics[metricName]),
                count: 1,
                time: new Date(),
                properties: {
                    clusterMetadata: this.clusterMetadata
                }
            };

            this.client.trackMetric(telemetryItem);
            //this.client.flush();
        }

        this.heartbeatAccumulator.metrics.clear();

        for(const logName in this.heartbeatAccumulator.logs) {
            const logArray = Object.keys(this.heartbeatAccumulator.logs[logName]).map((key) => {
                return {
                  message: key,
                  count: this.heartbeatAccumulator.logs[logName][key]
                }
              });

            logArray.sort((one, two) => (one.count > two.count ? -1 : 1));

            // send top N logs by count of this type
            let i = 0;
            for(let j = 0; j < logArray.length; j++) {
                if(i++ >= 5) {
                    break;
                }

                const telemetryItem: TraceTelemetry = {
                    message: logArray[j].message,
                    time: new Date(),
                    properties: {
                        clusterMetadata: this.clusterMetadata
                    }
                };

                this.client.trackTrace(telemetryItem);
                //this.client.flush();
            }
        }

        this.heartbeatAccumulator.logs.clear();
    }

    // public telemetry(metric: Metrics, value: number, uid = "") {
    //     if (metric == null) {
    //         this.log.error("invalid metric");
    //     }

    //     if (this.client == null) {
    //         this.client = new applicationInsights.TelemetryClient(this.getKey());
    //     }

    //     const telemetryItem: MetricTelemetry = {
    //         name: metric,
    //         value,
    //         count: 1,
    //         properties: {
    //             KUBERNETES_SERVICE_HOST: process.env.KUBERNETES_SERVICE_HOST,
    //             CLUSTER_RESOURCE_ID: process.env.CLUSTER_RESOURCE_ID,
    //             UID: uid,
    //         },
    //     };

    //     this.client.trackMetric(telemetryItem);
    //     //this.client.flush();
    // }

    public SendEvent(eventName: string, operationId: string, uid: string, clusterArmId: string, clusterArmRegion: string, flush = false, ...args: unknown[]) {
        const event: EventTelemetry = {
            name: eventName,
            properties: {
                time: Date.now(),
                extra: JSON.stringify(args),
                operationId: operationId,
                clusterArmId: clusterArmId,
                clusterArmRegion: clusterArmRegion,
                uid: uid
            },
        };

        this.client.trackEvent(event);

        if(flush) {
            this.client.flush();
        }
    }

    private getKey(): string {
        if(this.isUnitTestMode) {
            return ""; // for unit tests this shouldn't go anywhere
        }

        if (process.env.TELEMETRY_SETUP_STRING) {
            return process.env.TELEMETRY_SETUP_STRING;
        }
        
        // global AI component collecting telemetry from all webhooks
        //!!!
        return "InstrumentationKey=a5e8ca94-9dbb-475d-a44f-bd5f778fcd1a;IngestionEndpoint=https://eastus2-3.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus2.livediagnostics.monitor.azure.com/";
    }
}

export const logger = LocalLogger.Instance(process.env.ARM_ID, process.env.ARM_REGION, process.env.POD_NAME);