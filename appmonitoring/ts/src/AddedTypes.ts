import { DeployReplica } from "./RequestDefinition.js";

export class AddedTypes {
    public static init_containers() {
        return [{
            args: ["-a", "/agents/.", "/agentfiles"],
            command: ["cp"],
            image: process.env.AGENTS_IMAGE || "ERROR",
            name: "agent-init",
            volumeMounts: [{
                mountPath: "/agentfiles",
                name: "agent-volume",
            }],
        },
        ];
    }

    public static async env(extraData: DeployReplica) {
        const returnValue = [
            {
                name: "JAVA_TOOL_OPTIONS",
                value: "-javaagent:/agentfiles/applicationinsights-agent-3.4.1-BETA-SNAPSHOT.jar  -Dsite.logdir=/var/log",
            },
            {
                name: "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT",
                valueFrom: {
                    configMapKeyRef: {
                        name: "otlp",
                        key: "otlpMetricsEndpoint",
                    },
                },
            },
            // {
            //     name: "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
            //     valueFrom: {
            //         configMapKeyRef: {
            //             name: "otlp",
            //             key: "otlpTracesEndpoint",
            //         }
            //     }
            // },
            {
                name: "NODE_OPTIONS",
                value: "--require /agentfiles/telemetry/node/ai-telemetry.js --require /agentfiles/node/build/src/Loader.js",
            },
            {
                name: "APPLICATIONINSIGHTS_CONNECTION_STRING",
                valueFrom: {
                    configMapKeyRef: {
                        name: "otlp",
                        key: "connectionString",
                    },
                },
            },
            {
                name: "TELEMETRY_IKEY",
                value: process.env.TELEMETRY_IKEY,
            },
            {
                name: "TELEMETRY_CONN_STRING",
                value: process.env.TELEMETRY_CONN_STRING,
            },
            /*{
                name: "APPLICATIONINSIGHTS_CONNECTION_STRING",
                valueFrom: {
                    configMapKeyRef: {
                        key: "connectionString",
                        name: "attach-config",
                    },
                },
            },*/
        ];

        if (extraData && extraData.deploymentName) {
            returnValue.push({
                name: "APPLICATIONINSIGHTS_ROLE_NAME",
                value: extraData.deploymentName,
            });
            returnValue.push({
                name: "WEBSITE_HOSTNAME",
                value: extraData.deploymentName,
            });

        }

        if (extraData && extraData.podName) {
            returnValue.push({
                name: "APPLICATIONINSIGHTS_ROLE_INSTANCE",
                value: extraData.podName,
            });
        }

        return returnValue;
    }

    public static volume_mounts() {
        return [{
            mountPath: "/agentfiles",
            name: "agent-volume",
        }];
    }

    public static volumes() {
        return [{
            emptyDir: {},
            name: "agent-volume",
        }];
    }
}
