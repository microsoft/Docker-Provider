import { PodInfo } from "./RequestDefinition.js";

export class AddedTypes {
    // name of the init container
    private static initContainerNameDotNet = "agent-init-dotnet";
    private static initContainerNameJava = "agent-init-java";
    private static initContainerNameNodeJs = "agent-init-nodejs";
    
    // agent image
    private static agentImageDotNet = "mcr.microsoft.com/applicationinsights/opentelemetry-auto-instrumentation/dotnet:1.0.0-beta1";
    private static agentImageJava = "mcr.microsoft.com/applicationinsights/auto-instrumentation/java:3.4.14";
    private static agentImageNodeJs = "mcr.microsoft.com/applicationinsights/opentelemetry-auto-instrumentation/nodejs:3.0.0-beta.6";
    
    // path on agent image to copy from
    private static imagePathDotNet = "/dotnet-tracer-home/.";
    private static imagePathJava = "/agents/java/.";
    private static imagePathNodeJs = "/agents/nodejs/.";

    // agent volume (where init containers copy agent binaries to)
    private static agentVolumeDotNet = "agent-volume-dotnet";
    private static agentVolumeJava = "agent-volume-java";
    private static agentVolumeNodeJs = "agent-volume-nodejs";

    // agent volume mount path
    private static agentVolumeMountPathDotNet = "/agent-dotnet";
    private static agentVolumeMountPathJava = "/agent-java";
    private static agentVolumeMountPathNodeJs = "/agent-nodejs";

    // agent logs volume (where agents dump runtime logs)
    private static agentLogsVolumeDotNet = "agent-volume-logs-dotnet";
    private static agentLogsVolumeJava = "agent-volume-logs-java";
    private static agentLogsVolumeNodeJs = "agent-volume-logs-nodejs";

    // agent logs volume mount path
    private static agentLogsVolumeMountPathDotNet = "/var/log/applicationinsights";
    private static agentLogsVolumeMountPathJava = "/var/log/applicationinsights"; // this is hardcoded in Java SDK, can't change this
    private static agentLogsVolumeMountPathNodeJs = "/var/log/applicationinsights"; // this is hardcoded in NodeJs SDK, can't change this
    
    public static init_containers(platforms: string[]) {
        const containers: object[] = [];

        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i]) {
                case "DotNet":
                    containers.push({
                        name: AddedTypes.initContainerNameDotNet,
                        image: AddedTypes.agentImageDotNet,
                        command: ["cp"],
                        args: ["-a", AddedTypes.imagePathDotNet, AddedTypes.agentVolumeMountPathDotNet], // cp -a <source> <destination>
                        volumeMounts: [{
                            name: AddedTypes.agentVolumeDotNet,
                            mountPath: AddedTypes.agentVolumeMountPathDotNet
                        }]
                    });
                    break;

                case "Java":
                    containers.push({
                        name: AddedTypes.initContainerNameJava,
                        image: AddedTypes.agentImageJava,
                        command: ["cp"],
                        args: ["-a", AddedTypes.imagePathJava, AddedTypes.agentVolumeMountPathJava], // cp -a <source> <destination>
                        volumeMounts: [{
                            name: AddedTypes.agentVolumeJava,
                            mountPath: AddedTypes.agentVolumeMountPathJava
                        }]
                    });
                    break;

                case "NodeJs":
                    containers.push({
                        name: AddedTypes.initContainerNameNodeJs,
                        image: AddedTypes.agentImageNodeJs,
                        command: ["cp"],
                        args: ["-a", AddedTypes.imagePathNodeJs, AddedTypes.agentVolumeMountPathNodeJs], // cp -a <source> <destination>
                        volumeMounts: [{
                            name: AddedTypes.agentVolumeNodeJs,
                            mountPath: AddedTypes.agentVolumeMountPathNodeJs
                        }]
                    });
                    break;

                case "OpenTelemetry":
                    throw `Not implemented`;
                    //break;

                default:
                    throw `Unsupported platform in init_containers(): ${platforms[i]}`;
            }
        }

        return containers;
    }

    public static env(podInfo: PodInfo, platforms: string[], connectionString: string, armId: string, armRegion: string, clusterName: string): object {
        const ownerName: string = podInfo.ownerReference ?
            podInfo.deploymentName ? `k8s.deployment.name=${podInfo.deploymentName},` : `k8s.${podInfo.ownerReference.kind}.name=${podInfo.ownerReference.name},`
            : null;

        const ownerUid: string = podInfo.ownerReference ? `k8s.${podInfo.ownerReference.kind}.uid=${podInfo.ownerReference.uid},` : null;


        const returnValue = [
            // Downward API environment variables must come first as they are referenced later
            {
                name: "NODE_NAME",
                valueFrom: {
                    fieldRef: {
                        fieldPath: "spec.nodeName"
                    }
                }
            },
            {
                name: "POD_NAMESPACE",
                valueFrom: {
                    fieldRef: {
                        fieldPath: "metadata.namespace"
                    }
                }
            },
            {
                name: "POD_NAME",
                valueFrom: {
                    fieldRef: {
                        fieldPath: "metadata.name"
                    }
                }
            },
            {
                name: "POD_UID",
                valueFrom: {
                    fieldRef: {
                        fieldPath: "metadata.uid"
                    }
                }
            },

            // now we can reference Downward API values from environment variables above
            {
                name: "OTEL_RESOURCE_ATTRIBUTES",
                //!!! 
                value: `cloud.resource_id=${armId},\
cloud.region=${armRegion},\
k8s.cluster.name=${clusterName},\
k8s.pod.namespace=$(POD_NAMESPACE),\
k8s.node.name=$(NODE_NAME),\
k8s.pod.name=$(POD_NAME),\
k8s.pod.uid=$(POD_UID),\
${podInfo.onlyContainerName ? `k8s.container.name=${podInfo.onlyContainerName},` : null}\
cloud.provider=Azure,\
cloud.platform=azure_aks,\
${ownerName}\
${ownerUid}`
            },
            {
                name: "APPLICATIONINSIGHTS_CONNECTION_STRING",
                value: connectionString
            },
        ];

        // platform-specific environment variables
        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i]) {
                case "DotNet":
                    returnValue.push(...[
                        {
                            name: "OTEL_DOTNET_AUTO_LOG_DIRECTORY",
                            value: AddedTypes.agentLogsVolumeMountPathDotNet
                        },
                        {
                            name: "DOTNET_STARTUP_HOOKS",
                            value: `${AddedTypes.agentVolumeMountPathDotNet}/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll`
                        },
                        {
                            name: "ASPNETCORE_HOSTINGSTARTUPASSEMBLIES",
                            value: "OpenTelemetry.AutoInstrumentation.AspNetCoreBootstrapper"
                        },
                        {
                            name: "DOTNET_ADDITIONAL_DEPS",
                            value: `${AddedTypes.agentVolumeMountPathDotNet}/AdditionalDeps`
                        },
                        {
                            name: "DOTNET_SHARED_STORE",
                            value: `${AddedTypes.agentVolumeMountPathDotNet}/store`
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_HOME",
                            value: `${AddedTypes.agentVolumeMountPathDotNet}/`
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_TRACES_CONSOLE_EXPORTER_ENABLED",
                            value: "true"
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_LOGS_CONSOLE_EXPORTER_ENABLED",
                            value: "true"
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_METRICS_CONSOLE_EXPORTER_ENABLED",
                            value: "true"
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_PLUGINS",
                            value: "Azure.Monitor.OpenTelemetry.AutoInstrumentation.AzureMonitorPlugin, Azure.Monitor.OpenTelemetry.AutoInstrumentation, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null"
                        },
                        {
                            name: "OTEL_SERVICE_NAME",
                            value: "StartupHook.Self-hosted"
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_LOGS_INCLUDE_FORMATTED_MESSAGE",
                            value: "true"
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_METRICS_ADDITIONAL_SOURCES",
                            value: ""
                        }]
                    );
                    break;

                case "Java":
                    {
                        returnValue.push(...[{
                            name: "JAVA_OPTIONS",
                            value: `-javaagent:${AddedTypes.agentLogsVolumeMountPathJava}/applicationinsights-agent-codeless.jar`
                        }]);
                    }
                    break;

                case "NodeJs":
                    returnValue.push(...[
                        {
                            name: "NODE_OPTIONS",
                            value: `--require ${AddedTypes.agentVolumeMountPathNodeJs}/aks.js`
                        }]);
                    break;

                case "OpenTelemetry":
                    throw `Not implemented`;
                    //break;

                default:
                    throw `Unsupported platform in env(): ${platforms[i]}`;
            }
        }

        return returnValue;
    }

    public static volume_mounts(platforms: string[]) {
        const volumeMounts: object[] = [];

        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i]) {
                case "DotNet":
                    volumeMounts.push({
                        name: AddedTypes.agentVolumeDotNet,
                        mountPath: AddedTypes.agentVolumeMountPathDotNet
                    });

                    volumeMounts.push({
                        name: AddedTypes.agentLogsVolumeDotNet,
                        mountPath: AddedTypes.agentLogsVolumeMountPathDotNet
                    });
                    break;

                case "Java":
                    volumeMounts.push({
                        name: AddedTypes.agentVolumeJava,
                        mountPath: AddedTypes.agentVolumeMountPathJava
                    });

                    volumeMounts.push({
                        name: AddedTypes.agentLogsVolumeJava,
                        mountPath: AddedTypes.agentLogsVolumeMountPathJava
                    });
                    break;

                case "NodeJs":
                    volumeMounts.push({
                        name: AddedTypes.agentVolumeNodeJs,
                        mountPath: AddedTypes.agentVolumeMountPathNodeJs
                    });

                    volumeMounts.push({
                        name: AddedTypes.agentLogsVolumeNodeJs,
                        mountPath: AddedTypes.agentLogsVolumeMountPathNodeJs
                    });
                    break;

                case "OpenTelemetry":
                    throw `Not implemented`;
                    //break;

                default:
                    throw `Unsupported platform in volume_mounts(): ${platforms[i]}`;
            }
        }

        return volumeMounts;
    }

    public static volumes(platforms: string[]) {
        const volumes: object[] = [];

        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i]) {
                case "DotNet":
                    volumes.push({
                        name: AddedTypes.agentVolumeDotNet,
                        emptyDir: {}
                    });

                    volumes.push({
                        name: AddedTypes.agentLogsVolumeDotNet,
                        emptyDir: {}
                    });
                    break;

                case "Java":
                    volumes.push({
                        name: AddedTypes.agentVolumeJava,
                        emptyDir: {}
                    });

                    volumes.push({
                        name: AddedTypes.agentLogsVolumeJava,
                        emptyDir: {}
                    });
                    break;

                case "NodeJs":
                    volumes.push({
                        name: AddedTypes.agentVolumeNodeJs,
                        emptyDir: {}
                    });

                    volumes.push({
                        name: AddedTypes.agentLogsVolumeNodeJs,
                        emptyDir: {}
                    });
                    break;

                case "OpenTelemetry":
                    throw `Not implemented`;
                    //break;

                default:
                    throw `Unsupported platform in volumes(): ${platforms[i]}`;
            }
        }

        return volumes;
    }
}
