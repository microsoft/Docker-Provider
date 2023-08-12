import { PodInfo } from "./RequestDefinition.js";

export class AddedTypes {
    // name of the init container
    private static initContainerNameDotNet = "agent-init-dotnet";
    private static initContainerNameJava = "agent-init-java";
    private static initContainerNameNodeJs = "agent-init-nodejs";
    
    // agent image
    private static agentImageDotNet = "mcr.microsoft.com/applicationinsights/opentelemetry-auto-instrumentation/dotnet:1.0.0-beta2";
    private static agentImageJava = "mcr.microsoft.com/applicationinsights/auto-instrumentation/java:3.4.15";
    private static agentImageNodeJs = "mcr.microsoft.com/applicationinsights/opentelemetry-auto-instrumentation/nodejs:3.0.0-beta.8";
    
    // path on agent image to copy from
    private static imagePathDotNet = "/dotnet-tracer-home/.";
    private static imagePathJava = "/agents/java/applicationinsights-agent-codeless.jar";
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
    private static agentLogsVolume = "agent-volume-logs";
    
    // agent logs volume mount path
    private static agentLogsVolumeMountPath = "/var/log/applicationinsights"; // this is hardcoded in Java SDK and NodeJs SDK, can't change this
    
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
        const ownerNameAttribute: string = podInfo.ownerReference ? `k8s.${podInfo.ownerReference.kind?.toLowerCase()}.name=${podInfo.ownerReference.name}` : null;
        const ownerUidAttribute: string = podInfo.ownerReference ? `k8s.${podInfo.ownerReference.kind?.toLowerCase()}.uid=${podInfo.ownerReference.uid}` : null;
        const deploymentNameAttribute: string = podInfo.deploymentName ? `k8s.deployment.name=${podInfo.deploymentName}` : null;
        const containerNameAttribute: string = podInfo.onlyContainerName ? `k8s.container.name=${podInfo.onlyContainerName}` : null;

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
${containerNameAttribute},\
cloud.provider=Azure,\
cloud.platform=azure_aks,\
${ownerNameAttribute},\
${deploymentNameAttribute},\
${ownerUidAttribute}`
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
                            value: AddedTypes.agentLogsVolumeMountPath
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
                            name: "JAVA_TOOL_OPTIONS",
                            value: `-javaagent:${AddedTypes.agentVolumeMountPathJava}/applicationinsights-agent-codeless.jar`
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
                    break;

                case "Java":
                    volumeMounts.push({
                        name: AddedTypes.agentVolumeJava,
                        mountPath: AddedTypes.agentVolumeMountPathJava
                    });
                    break;

                case "NodeJs":
                    volumeMounts.push({
                        name: AddedTypes.agentVolumeNodeJs,
                        mountPath: AddedTypes.agentVolumeMountPathNodeJs
                    });
                    break;

                case "OpenTelemetry":
                    throw `Not implemented`;
                    //break;

                default:
                    throw `Unsupported platform in volume_mounts(): ${platforms[i]}`;
            }
        }

        let logVolumeMounted = false;
        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i]) {
                case "DotNet":
                case "Java":
                case "NodeJs":
                    if(!logVolumeMounted) {
                        volumeMounts.push({
                            name: AddedTypes.agentLogsVolume,
                            mountPath: AddedTypes.agentLogsVolumeMountPath
                        });

                        logVolumeMounted = true;
                    }
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
                    break;

                case "Java":
                    volumes.push({
                        name: AddedTypes.agentVolumeJava,
                        emptyDir: {}
                    });
                    break;

                case "NodeJs":
                    volumes.push({
                        name: AddedTypes.agentVolumeNodeJs,
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

        let logVolumeAdded = false;
        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i]) {
                case "DotNet":
                case "Java":
                case "NodeJs":
                    if(!logVolumeAdded) {
                        volumes.push({
                            name: AddedTypes.agentLogsVolume,
                            emptyDir: {}
                        });

                        logVolumeAdded = true;
                    }
            }
        }       

        return volumes;
    }
}
