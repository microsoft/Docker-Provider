import applicationInsights = require("applicationinsights");
import { MetricTelemetry, Telemetry } from "applicationinsights/out/Declarations/Contracts";
import { configure, getLogger, Logger } from "log4js";

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
            appenders: [/*"file"*/, "console"],
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

    private log: Logger = getLogger("default");
    private client: applicationInsights.TelemetryClient;

    public trace(message: any, uid: string, ...args: any[]) {
        this.log.trace(message, JSON.stringify(args, undefined, 2));
        this.fireEvent("TRACE", message, uid, args);
    }

    public debug(message: any, uid: string, ...args: any[]) {
        this.log.debug(message, JSON.stringify(args, undefined, 2));
        this.fireEvent("DEBUG", message, uid, args);
    }

    public info(message: any, uid: string, ...args: any[]) {
        this.log.info(message, JSON.stringify(args, undefined, 2));
        this.fireEvent("INFO", message, uid, args);
    }

    public warn(message: any, uid: string, ...args: any[]) {
        this.log.warn(message, JSON.stringify(args, undefined, 2));
        this.fireEvent("WARN", message, uid, args);
    }

    public error(message: any, uid: string, ...args: any[]) {
        this.log.error(message, JSON.stringify(args, undefined, 2));
        this.fireEvent("ERROR", message, uid, args);
    }

    public fatal(message: any, uid: string, ...args: any[]) {
        this.log.fatal(message, JSON.stringify(args, undefined, 2));
        this.fireEvent("FATAL", message, uid, args);
    }

    public mark(message: any, uid: string, ...args: any[]) {
        this.log.mark(message, args);
        this.fireEvent("MARK", message, uid, args);
    }

    public telemetry(metric: Metrics, value: number, uid: string) {
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

    private fireEvent(level: string, message: any, uid: string, ...args: any[]) {
        if (this.client == null) {
            this.client = new applicationInsights.TelemetryClient(this.getKey());
        }

        const event: any = {
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
