import { AutoInstrumentationPlatforms, IContainer, IEnvironmentVariable, IVolume, IVolumeMount, PodInfo } from "./RequestDefinition.js";

/**
 * Contains a collection of mutations necessary to add functionality to a Pod
 */
export class Mutations {
    // name of the init container
    private static initContainerNameDotNet = "azure-monitor-auto-instrumentation-dotnet";
    private static initContainerNameJava = "azure-monitor-auto-instrumentation-java";
    private static initContainerNameNodeJs = "azure-monitor-auto-instrumentation-nodejs";
    
    // agent image
    private static agentImageDotNet = "mcr.microsoft.com/applicationinsights/opentelemetry-auto-instrumentation/dotnet:1.0.0-beta3";
    private static agentImageJava = "mcr.microsoft.com/applicationinsights/auto-instrumentation/java:3.5.1-aks";
    private static agentImageNodeJs = "mcr.microsoft.com/applicationinsights/opentelemetry-auto-instrumentation/nodejs:3.0.0-beta.10";
    
    // path on agent image to copy from
    private static imagePathDotNet = "/dotnet-tracer-home/.";
    private static imagePathJava = "/agents/java/.";
    private static imagePathNodeJs = "/agents/nodejs/.";

    // agent volume (where init containers copy agent binaries to)
    private static agentVolumeDotNet = "azure-monitor-auto-instrumentation-volume-dotnet";
    private static agentVolumeJava = "azure-monitor-auto-instrumentation-volume-java";
    private static agentVolumeNodeJs = "azure-monitor-auto-instrumentation-volume-nodejs";

    // agent volume mount path (where customer app's runtime loads agents from)
    private static agentVolumeMountPathDotNet = "/azure-monitor-auto-instrumentation-dotnet";
    private static agentVolumeMountPathJava = "/azure-monitor-auto-instrumentation-java";
    private static agentVolumeMountPathNodeJs = "/azure-monitor-auto-instrumentation-nodejs";

    // agent logs volume (where agents dump runtime logs)
    private static agentLogsVolume = "azure-monitor-auto-instrumentation-volume-logs";
    
    // agent logs volume mount path
    private static agentLogsVolumeMountPath = "/var/log/applicationinsights"; // this is hardcoded in Java SDK and NodeJs SDK, can't change this
    
    /**
     * Creates init containers that are used to copy agent binaries onto a Pod. These containers download the agent image, copy agent binaries from inside of the image, and finish.
     */
    public static GenerateInitContainers(platforms: AutoInstrumentationPlatforms[]): IContainer[] {
        const containers: IContainer[] = [];

        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.DotNet:
                    containers.push({
                        name: Mutations.initContainerNameDotNet,
                        image: Mutations.agentImageDotNet,
                        command: ["cp"],
                        args: ["-a", Mutations.imagePathDotNet, Mutations.agentVolumeMountPathDotNet], // cp -a <source> <destination>
                        volumeMounts: [{
                            name: Mutations.agentVolumeDotNet,
                            mountPath: Mutations.agentVolumeMountPathDotNet
                        }]
                    });
                    break;

                case AutoInstrumentationPlatforms.Java:
                    containers.push({
                        name: Mutations.initContainerNameJava,
                        image: Mutations.agentImageJava,
                        command: ["cp"],
                        args: ["-a", Mutations.imagePathJava, Mutations.agentVolumeMountPathJava], // cp -a <source> <destination> 
                        volumeMounts: [{
                            name: Mutations.agentVolumeJava,
                            mountPath: Mutations.agentVolumeMountPathJava
                        }]
                    });
                    break;

                case AutoInstrumentationPlatforms.NodeJs:
                    containers.push({
                        name: Mutations.initContainerNameNodeJs,
                        image: Mutations.agentImageNodeJs,
                        command: ["cp"],
                        args: ["-a", Mutations.imagePathNodeJs, Mutations.agentVolumeMountPathNodeJs], // cp -a <source> <destination>
                        volumeMounts: [{
                            name: Mutations.agentVolumeNodeJs,
                            mountPath: Mutations.agentVolumeMountPathNodeJs
                        }]
                    });
                    break;

                default:
                    throw `Unsupported platform in init_containers(): ${platforms[i]}`;
            }
        }

        return containers;
    }

    /**
     * Generates environment variables necessary to configure agents. Agents take configuration from these environment variables once they run.
     */
    public static GenerateEnvironmentVariables(podInfo: PodInfo, platforms: AutoInstrumentationPlatforms[], connectionString: string, armId: string, armRegion: string, clusterName: string): IEnvironmentVariable[] {
        const ownerNameAttribute = `k8s.${podInfo.ownerKind?.toLowerCase()}.name=${podInfo.ownerName}`;
        const ownerUidAttribute = `k8s.${podInfo.ownerKind?.toLowerCase()}.uid=${podInfo.ownerUid}`;
        const containerNameAttribute = `k8s.container.name=${podInfo.onlyContainerName}`;

        const returnValue: IEnvironmentVariable[] = [
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
                value: `cloud.resource_id=${armId},\
cloud.region=${armRegion},\
k8s.cluster.name=${clusterName},\
k8s.namespace.name=$(POD_NAMESPACE),\
k8s.node.name=$(NODE_NAME),\
k8s.pod.name=$(POD_NAME),\
k8s.pod.uid=$(POD_UID),\
${containerNameAttribute},\
cloud.provider=Azure,\
cloud.platform=azure_aks,\
${ownerNameAttribute},\
${ownerUidAttribute}`
            },
            {
                name: "AKS_ARM_NAMESPACE_ID",
                value: `${armId}/$(POD_NAMESPACE)`
            },
            {
                name: "APPLICATIONINSIGHTS_CONNECTION_STRING",
                value: connectionString
            },
        ];

        // platform-specific environment variables
        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.DotNet:
                    returnValue.push(...[
                        {
                            name: "OTEL_DOTNET_AUTO_LOG_DIRECTORY",
                            value: Mutations.agentLogsVolumeMountPath
                        },
                        {
                            name: "DOTNET_STARTUP_HOOKS",
                            value: `${Mutations.agentVolumeMountPathDotNet}/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll`
                        },
                        {
                            name: "ASPNETCORE_HOSTINGSTARTUPASSEMBLIES",
                            value: "OpenTelemetry.AutoInstrumentation.AspNetCoreBootstrapper"
                        },
                        {
                            name: "DOTNET_ADDITIONAL_DEPS",
                            value: `${Mutations.agentVolumeMountPathDotNet}/AdditionalDeps`
                        },
                        {
                            name: "DOTNET_SHARED_STORE",
                            value: `${Mutations.agentVolumeMountPathDotNet}/store`
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_HOME",
                            value: `${Mutations.agentVolumeMountPathDotNet}/`
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_PLUGINS",
                            value: "Azure.Monitor.OpenTelemetry.AutoInstrumentation.AzureMonitorPlugin, Azure.Monitor.OpenTelemetry.AutoInstrumentation, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null"
                        }]
                    );
                    break;

                case AutoInstrumentationPlatforms.Java:
                    {
                        returnValue.push(...[{
                            name: "JAVA_TOOL_OPTIONS",
                            value: `-javaagent:${Mutations.agentVolumeMountPathJava}/applicationinsights-agent-codeless.jar`
                        }]);
                    }
                    break;

                case AutoInstrumentationPlatforms.NodeJs:
                    returnValue.push(...[
                        {
                            name: "NODE_OPTIONS",
                            value: `--require ${Mutations.agentVolumeMountPathNodeJs}/aks.js`
                        }]);
                    break;

                default:
                    throw `Unsupported platform in env(): ${platforms[i]}`;
            }
        }

        return returnValue;
    }

    /**
     * Generates volume mounts necessary for customer app's runtimes to load agent binaries.
     * Also generates volume mounts necessary for the agents to dump runtime logs.
     */
    public static GenerateVolumeMounts(platforms: AutoInstrumentationPlatforms[]): IVolumeMount[] {
        const volumeMounts: IVolumeMount[] = [];

        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.DotNet:
                    volumeMounts.push({
                        name: Mutations.agentVolumeDotNet,
                        mountPath: Mutations.agentVolumeMountPathDotNet
                    });
                    break;

                case AutoInstrumentationPlatforms.Java:
                    volumeMounts.push({
                        name: Mutations.agentVolumeJava,
                        mountPath: Mutations.agentVolumeMountPathJava
                    });
                    break;

                case AutoInstrumentationPlatforms.NodeJs:
                    volumeMounts.push({
                        name: Mutations.agentVolumeNodeJs,
                        mountPath: Mutations.agentVolumeMountPathNodeJs
                    });
                    break;

                default:
                    throw `Unsupported platform in volume_mounts(): ${platforms[i]}`;
            }
        }

        let logVolumeMounted = false;
        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.DotNet:
                case AutoInstrumentationPlatforms.Java:
                case AutoInstrumentationPlatforms.NodeJs:
                    if(!logVolumeMounted) {
                        volumeMounts.push({
                            name: Mutations.agentLogsVolume,
                            mountPath: Mutations.agentLogsVolumeMountPath
                        });

                        logVolumeMounted = true;
                    }
            }
        }       

        return volumeMounts;
    }

    /**
     * Generates volumes to place agent binaries, and also volumes for agents to dump runtime logs.
     */
    public static GenerateVolumes(platforms: AutoInstrumentationPlatforms[]) : IVolume[] {
        const volumes: IVolume[] = [];

        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.DotNet:
                    volumes.push({
                        name: Mutations.agentVolumeDotNet,
                        emptyDir: {}
                    });
                    break;

                case AutoInstrumentationPlatforms.Java:
                    volumes.push({
                        name: Mutations.agentVolumeJava,
                        emptyDir: {}
                    });
                    break;

                case AutoInstrumentationPlatforms.NodeJs:
                    volumes.push({
                        name: Mutations.agentVolumeNodeJs,
                        emptyDir: {}
                    });
                    break;

                default:
                    throw `Unsupported platform in volumes(): ${platforms[i]}`;
            }
        }

        let logVolumeAdded = false;
        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.DotNet:
                case AutoInstrumentationPlatforms.Java:
                case AutoInstrumentationPlatforms.NodeJs:
                    if(!logVolumeAdded) {
                        volumes.push({
                            name: Mutations.agentLogsVolume,
                            emptyDir: {}
                        });

                        logVolumeAdded = true;
                    }
            }
        }       

        return volumes;
    }
}
