import * as applicationInsights from "applicationinsights";
import { EventTelemetry, MetricTelemetry } from "applicationinsights/out/Declarations/Contracts";

import log4js from "log4js";
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

class LocalLogger {
    public static Instance() {
        if (!LocalLogger.instance) {
            LocalLogger.instance = new LocalLogger();
        }

        return LocalLogger.instance;
    }

    private static instance: LocalLogger;

    private log: log4js.Logger = getLogger("default");
    private client: applicationInsights.TelemetryClient;

    public trace(message: string) {
        this.log.trace(message);
        this.fireEvent("TRACE", message);
    }

    public debug(message: string) {
        this.log.debug(message);
        this.fireEvent("DEBUG", message);
    }

    public info(message: string) {
        this.log.info(message);
        this.fireEvent("INFO", message);
    }

    public warn(message: string) {
        this.log.warn(message);
        this.fireEvent("WARN", message);
    }

    public error(message: string) {
        this.log.error(message);
        this.fireEvent("ERROR", message);
    }

    public fatal(message: string) {
        this.log.fatal(message);
        this.fireEvent("FATAL", message);
    }

    public mark(message: string) {
        this.log.mark(message);
        this.fireEvent("MARK", message);
    }

    public telemetry(metric: Metrics, value: number, uid = "") {
        if (metric == null) {
            this.log.error("invalid metric");
        }

        if (this.client == null) {
            this.client = new applicationInsights.TelemetryClient(this.getKey());
        }

        const telemetryItem: MetricTelemetry = {
            name: metric,
            value,
            count: 1,
            properties: {
                KUBERNETES_SERVICE_HOST: process.env.KUBERNETES_SERVICE_HOST,
                CLUSTER_RESOURCE_ID: process.env.CLUSTER_RESOURCE_ID,
                UID: uid,
            },
        };

        this.client.trackMetric(telemetryItem);
        this.client.flush();
    }

    private fireEvent(level: string, message: unknown, uid = "", ...args: unknown[]) {
        if (this.client == null) {
            this.client = new applicationInsights.TelemetryClient(this.getKey());
        }

        const event: EventTelemetry = {
            name: "AppplicationMonitoring",
            properties: {
                time: Date.now(),
                level,
                message,
                extra: JSON.stringify(args, undefined, 2),
                KUBERNETES_SERVICE_HOST: process.env.KUBERNETES_SERVICE_HOST,
                CLUSTER_RESOURCE_ID: process.env.CLUSTER_RESOURCE_ID,
                UID: uid,
            },
        };

        this.client.trackEvent(event);
        this.client.flush();
    }

    private getKey(): string {
        if (process.env.TELEMETRY_IKEY) {
            return process.env.TELEMETRY_IKEY;
        }
        if (process.env.TELEMETRY_CONN_STRING) {
            return process.env.TELEMETRY_CONN_STRING;
        }
        return "320dcf98-173f-429b-ab39-df8b4951fb94";
    }
}

export const logger = LocalLogger.Instance();

export enum Metrics {
    // namespace metrics
    Namespaces = "namespaces", // namespaces in cluster
    NamespaceError = "namespaceError", // namespace list error
    NamespacePatched = "namespacePatched", // patch operations
    NamespaceFail = "namespaceFail", // patch fail
    NamespaceSkipped = "namespaceSkipped", // patch skip operations
    // client request metrics
    Request = "request", // incoming request
    Success = "requestSuccess", // 200
    Fail = "requestFail", // 500
    Error = "requestError", // 404
    // content processor metrics
    CPSuccess = "cpSuccess",
    CPFail = "cpFail",
    CPError = "cpError",
    CPContainers = "cpContainers",
    CPStart = "cpStart",
    CPValidationFail = "cpValidationFail",
    CPValidationPass = "cpValidationPass",
}
