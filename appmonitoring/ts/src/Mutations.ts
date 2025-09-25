import { AutoInstrumentationPlatforms, IContainer, IEnvironmentVariable, IVolume, IVolumeMount, PodInfo, OtelParams } from "./RequestDefinition.js";

/**
 * Contains a collection of mutations necessary to add functionality to a Pod
 */
export class Mutations {
    // name of the init container
    private static initContainerNameJava = "azure-monitor-auto-instrumentation-java";
    private static initContainerNameNodeJs = "azure-monitor-auto-instrumentation-nodejs";
    private static initContainerNamePython = "azure-monitor-auto-instrumentation-python";
    private static initContainerNameDotNet = "azure-monitor-auto-instrumentation-dotnet";
    
    // agent image
    private static agentImageCommonPrefix = "mcr.microsoft.com/applicationinsights";

    private static agentImageJava = {
        repositoryPath: "auto-instrumentation/java",
        imageTag: "3.7.2-aks" // https://mcr.microsoft.com/v2/applicationinsights/auto-instrumentation/java/tags/list
    };
    private static agentImageNodeJs = {
        repositoryPath: "opentelemetry-auto-instrumentation/nodejs",
        imageTag: "3.2.7" // https://mcr.microsoft.com/v2/applicationinsights/opentelemetry-auto-instrumentation/nodejs/tags/list
    };
    private static agentImagePython = {
        repositoryPath: "auto-instrumentation/python",
        imageTag: "1.0.0b26-aks" // https://mcr.microsoft.com/v2/applicationinsights/auto-instrumentation/python/tags/list
    };
    private static agentImageDotNet = {
        repositoryPath: "opentelemetry-auto-instrumentation/dotnet",
        imageTag: "1.0.0-beta5" // https://mcr.microsoft.com/v2/applicationinsights/opentelemetry-auto-instrumentation/dotnet/tags/list
    };
    
    // path on agent image to copy from
    private static imagePathJava = "/agents/java/.";
    private static imagePathNodeJs = "/agents/nodejs/.";
    private static imagePathPython = "/agents/python/.";
    private static imagePathDotNet = "/dotnet-tracer-home/.";

    // agent volume (where init containers copy agent binaries to)
    private static agentVolumeJava = "azure-monitor-auto-instrumentation-volume-java";
    private static agentVolumeNodeJs = "azure-monitor-auto-instrumentation-volume-nodejs";
    private static agentVolumePython = "azure-monitor-auto-instrumentation-volume-python";
    private static agentVolumeDotNet = "azure-monitor-auto-instrumentation-volume-dotnet";

    // agent volume mount path (where customer app's runtime loads agents from)
    private static agentVolumeMountPathJava = "/azure-monitor-auto-instrumentation-java";
    private static agentVolumeMountPathNodeJs = "/azure-monitor-auto-instrumentation-nodejs";
    private static agentVolumeMountPathPython = "/azure-monitor-auto-instrumentation-python";
    private static agentVolumeMountPathDotNet = "/azure-monitor-auto-instrumentation-dotnet";

    // agent logs volume (where agents dump runtime logs)
    private static agentLogsVolume = "azure-monitor-auto-instrumentation-volume-logs";
    
    // agent logs volume mount path
    private static agentLogsVolumeMountPath = "/var/log/applicationinsights"; // this is hardcoded in Java SDK and NodeJs SDK, can't change this
    
    /**
     * Creates init containers that are used to copy agent binaries onto a Pod. These containers download the agent image, copy agent binaries from inside of the image, and finish.
     */
    public static GenerateInitContainers(platforms: AutoInstrumentationPlatforms[], imageRepoPath: string = null): IContainer[] {
        const containers: IContainer[] = [];

        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.Java:
                    containers.push({
                        name: Mutations.initContainerNameJava,
                        image: Mutations.GenerateImagePath(platforms[i], imageRepoPath),
                        command: ["cp"],
                        args: ["-r", Mutations.imagePathJava, Mutations.agentVolumeMountPathJava], // cp -r <source> <destination> 
                        volumeMounts: [{
                            name: Mutations.agentVolumeJava,
                            mountPath: Mutations.agentVolumeMountPathJava
                        }],
                        resources: {
                            requests: {
                                cpu: "100m",
                                memory: "128Mi"
                            },
                            limits: {
                                cpu: "2",
                                memory: "1Gi"
                            }
                        }
                    });
                    break;

                case AutoInstrumentationPlatforms.NodeJs:
                    containers.push({
                        name: Mutations.initContainerNameNodeJs,
                        image: Mutations.GenerateImagePath(platforms[i], imageRepoPath),
                        command: ["cp"],
                        args: ["-r", Mutations.imagePathNodeJs, Mutations.agentVolumeMountPathNodeJs], // cp -r <source> <destination>
                        volumeMounts: [{
                            name: Mutations.agentVolumeNodeJs,
                            mountPath: Mutations.agentVolumeMountPathNodeJs
                        }],
                        resources: {
                            requests: {
                                cpu: "100m",
                                memory: "128Mi"
                            },
                            limits: {
                                cpu: "2",
                                memory: "1Gi"
                            }
                        }
                    });
                    break;

                case AutoInstrumentationPlatforms.Python:
                    containers.push({
                        name: Mutations.initContainerNamePython,
                        image: Mutations.GenerateImagePath(platforms[i], imageRepoPath),
                        command: ["cp"],
                        args: ["-r", Mutations.imagePathPython, Mutations.agentVolumeMountPathPython], // cp -r <source> <destination>
                        volumeMounts: [{
                            name: Mutations.agentVolumePython,
                            mountPath: Mutations.agentVolumeMountPathPython
                        }],
                        resources: {
                            requests: {
                                cpu: "100m",
                                memory: "128Mi"
                            },
                            limits: {
                                cpu: "2",
                                memory: "1Gi"
                            }
                        }
                    });
                    break;

                case AutoInstrumentationPlatforms.DotNet:
                    containers.push({
                        name: Mutations.initContainerNameDotNet,
                        image: Mutations.GenerateImagePath(platforms[i], imageRepoPath),
                        command: ["cp"],
                        args: ["-r", Mutations.imagePathDotNet, Mutations.agentVolumeMountPathDotNet], // cp -r <source> <destination>
                        volumeMounts: [{
                            name: Mutations.agentVolumeDotNet,
                            mountPath: Mutations.agentVolumeMountPathDotNet
                        }],
                        resources: {
                            requests: {
                                cpu: "100m",
                                memory: "128Mi"
                            },
                            limits: {
                                cpu: "2",
                                memory: "1Gi"
                            }
                        }
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
    public static GenerateEnvironmentVariables(podInfo: PodInfo, platforms: AutoInstrumentationPlatforms[], disableAppLogs: boolean, connectionString: string, armId: string, armRegion: string, clusterName: string, otelParams: OtelParams, existingEnvironmentVariables?: Record<string, IEnvironmentVariable>): IEnvironmentVariable[] {
        const ownerNameAttribute = `k8s.${podInfo.ownerKind?.toLowerCase()}.name=${podInfo.ownerName}`;
        const ownerUidAttribute = `k8s.${podInfo.ownerKind?.toLowerCase()}.uid=${podInfo.ownerUid}`;
        const containerNameAttribute = `k8s.container.name=${podInfo.onlyContainerName}`;
        const applicationId = Mutations.parseApplicationIdFromConnectionString(connectionString);
        
        // Build our OTEL resource attributes
        const otelResourceAttributesList = [
            `cloud.resource_id=${armId}`,
            `cloud.region=${armRegion}`,
            `k8s.cluster.name=${clusterName}`,
            `k8s.namespace.name=$(POD_NAMESPACE)`,
            `k8s.node.name=$(NODE_NAME)`,
            `k8s.pod.name=$(POD_NAME)`,
            `k8s.pod.uid=$(POD_UID)`,
            containerNameAttribute,
            `cloud.provider=Azure`,
            `cloud.platform=azure_aks`,
            ownerNameAttribute,
            ownerUidAttribute
        ];
        
        if (applicationId) {
            otelResourceAttributesList.push(`microsoft.applicationId=${applicationId}`);
        }
        
        const otelResourceAttributes = otelResourceAttributesList.join(',');

        // Check if there's an existing OTEL_RESOURCE_ATTRIBUTES and merge if needed
        const existingOtelResourceAttributes = existingEnvironmentVariables?.["OTEL_RESOURCE_ATTRIBUTES"]?.value;
        const mergedOtelResourceAttributes = Mutations.mergeOtelResourceAttributes(existingOtelResourceAttributes, otelResourceAttributes);
        
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
                value: mergedOtelResourceAttributes
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

        // OTEL environment variables

        if (otelParams.logsEnabled || otelParams.metricsEnabled) {
            returnValue.push(
                {
                    name: "OTEL_ENDPOINT_NODE_IP",
                    valueFrom: {
                        fieldRef: {
                            fieldPath: "status.hostIP"
                        }
                    }
                }
            );
        }

        if (otelParams.logsEnabled) {
            returnValue.push(
                // not setting this to ensure Microsoft distros don't send OTLP traces. For OSS SDKs this defaults to "otlp" anyway, so no impact
                // {
                //     name: "OTEL_TRACES_EXPORTER",
                //     value: `otlp`
                // },
                {
                    name: "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", //!!! http -> https
                    value: `http://$(OTEL_ENDPOINT_NODE_IP):${otelParams.logsPortHttpProtobuf}/v1/traces`
                },
                {
                    name: "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL",
                    value: "http/protobuf"
                },
                {
                    name: "OTEL_EXPORTER_OTLP_TRACES_INSECURE", //!!!
                    value: "true"
                },

                // not setting this to ensure Microsoft distros don't send OTLP logs. For OSS SDKs this defaults to "otlp" anyway, so no impact
                // {
                //     name: "OTEL_LOGS_EXPORTER",
                //     value: `otlp`
                // },
                {
                    name: "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT", //!!! http -> https
                    value: `http://$(OTEL_ENDPOINT_NODE_IP):${otelParams.logsPortHttpProtobuf}/v1/logs`
                },
                {
                    name: "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL",
                    value: "http/protobuf"
                },
                {
                    name: "OTEL_EXPORTER_OTLP_LOGS_INSECURE", //!!!
                    value: "true"
                },
            );
        }

        if (otelParams.metricsEnabled) {
            returnValue.push(
                // setting this to ensure Microsoft distros do send OTLP metrics (forked, sent to Breeze and OTLP endpoint). For OSS SDKs this defaults to "otlp" anyway, so no impact
                {
                    name: "OTEL_METRICS_EXPORTER",
                    value: `otlp,azure_monitor`
                },
                {
                    name: "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", //!!! http -> https
                    value: `http://$(OTEL_ENDPOINT_NODE_IP):${otelParams.metricsPortHttpProtobuf}/v1/metrics`
                },
                {
                    name: "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL",
                    value: "http/protobuf"
                },
                {
                    name: "OTEL_EXPORTER_OTLP_METRICS_INSECURE", //!!!
                    value: "true"
                },
            );
        }

        // platform-specific environment variables
        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.Java:
                    {
                        returnValue.push(...[{
                            name: "JAVA_TOOL_OPTIONS",
                            value: `-javaagent:${Mutations.agentVolumeMountPathJava}/applicationinsights-agent-codeless.jar`,
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED",
                            value: "false",
                            platformSpecific: platforms[i],
                            doNotSet: !disableAppLogs
                        }]);
                    }
                    break;

                case AutoInstrumentationPlatforms.NodeJs:
                    returnValue.push(...[
                        {
                            name: "NODE_OPTIONS",
                            value: `--require ${Mutations.agentVolumeMountPathNodeJs}/aks.js`,
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT",
                            value: `{"instrumentationOptions":{"console": { "enabled": false }, "bunyan": { "enabled": false },"winston": { "enabled": false }}}`,
                            platformSpecific: platforms[i],
                            doNotSet: !disableAppLogs
                        }]);
                    break;

                case AutoInstrumentationPlatforms.Python:
                    returnValue.push(...[
                        {
                            name: "PYTHONPATH",
                            value: `${Mutations.agentVolumeMountPathPython}`,
                            platformSpecific: platforms[i]
                        }]);
                    break;

                case AutoInstrumentationPlatforms.DotNet:
                    returnValue.push(...[
                        {
                            name: "OTEL_DOTNET_AUTO_LOG_DIRECTORY",
                            value: Mutations.agentLogsVolumeMountPath,
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "DOTNET_STARTUP_HOOKS",
                            value: `${Mutations.agentVolumeMountPathDotNet}/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll`,
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "ASPNETCORE_HOSTINGSTARTUPASSEMBLIES",
                            value: "OpenTelemetry.AutoInstrumentation.AspNetCoreBootstrapper",
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "DOTNET_ADDITIONAL_DEPS",
                            value: `${Mutations.agentVolumeMountPathDotNet}/AdditionalDeps`,
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "DOTNET_SHARED_STORE",
                            value: `${Mutations.agentVolumeMountPathDotNet}/store`,
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_HOME",
                            value: `${Mutations.agentVolumeMountPathDotNet}/`,
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_PLUGINS",
                            value: "Azure.Monitor.OpenTelemetry.AutoInstrumentation.AzureMonitorPlugin, Azure.Monitor.OpenTelemetry.AutoInstrumentation, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null",
                            platformSpecific: platforms[i]
                        },
                        {
                            name: "OTEL_DOTNET_AUTO_LOGS_ENABLED",
                            value: "false",
                            platformSpecific: platforms[i],
                            doNotSet: !disableAppLogs
                        }]
                    );
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

                case AutoInstrumentationPlatforms.Python:
                    volumeMounts.push({
                        name: Mutations.agentVolumePython,
                        mountPath: Mutations.agentVolumeMountPathPython
                    });
                    break;

                case AutoInstrumentationPlatforms.DotNet:
                    volumeMounts.push({
                        name: Mutations.agentVolumeDotNet,
                        mountPath: Mutations.agentVolumeMountPathDotNet
                    });
                    break;

                default:
                    throw `Unsupported platform in volume_mounts(): ${platforms[i]}`;
            }
        }

        let logVolumeMounted = false;
        for (let i = 0; i < platforms.length; i++) {
            switch (platforms[i] as AutoInstrumentationPlatforms) {
                case AutoInstrumentationPlatforms.Java:
                case AutoInstrumentationPlatforms.NodeJs:
                case AutoInstrumentationPlatforms.Python:
                case AutoInstrumentationPlatforms.DotNet:
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

                case AutoInstrumentationPlatforms.Python:
                    volumes.push({
                        name: Mutations.agentVolumePython,
                        emptyDir: {}
                    });
                    break;

                case AutoInstrumentationPlatforms.DotNet:
                    volumes.push({
                        name: Mutations.agentVolumeDotNet,
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
                case AutoInstrumentationPlatforms.Java:
                case AutoInstrumentationPlatforms.NodeJs:
                case AutoInstrumentationPlatforms.Python:
                case AutoInstrumentationPlatforms.DotNet:
                    if(!logVolumeAdded) {
                        volumes.push({
                            name: Mutations.agentLogsVolume,
                            emptyDir: {
                                sizeLimit: "100Mi"
                            }
                        });

                        logVolumeAdded = true;
                    }
            }
        }       

        return volumes;
    }

    public static GenerateImagePath(platform: AutoInstrumentationPlatforms, imagePath: string = null): string {
        while(imagePath?.length > 1 && imagePath.endsWith("/")) {
            imagePath = imagePath.slice(0, imagePath.length - 1);
        }
        
        switch (platform as AutoInstrumentationPlatforms) {
            case AutoInstrumentationPlatforms.Java:
                return `${imagePath ?? Mutations.agentImageCommonPrefix}/${Mutations.agentImageJava.repositoryPath}:${Mutations.agentImageJava.imageTag}`;
            case AutoInstrumentationPlatforms.NodeJs:
                return `${imagePath ?? Mutations.agentImageCommonPrefix}/${Mutations.agentImageNodeJs.repositoryPath}:${Mutations.agentImageNodeJs.imageTag}`;
            case AutoInstrumentationPlatforms.Python:
                return `${imagePath ?? Mutations.agentImageCommonPrefix}/${Mutations.agentImagePython.repositoryPath}:${Mutations.agentImagePython.imageTag}`;
            case AutoInstrumentationPlatforms.DotNet:
                return `${imagePath ?? Mutations.agentImageCommonPrefix}/${Mutations.agentImageDotNet.repositoryPath}:${Mutations.agentImageDotNet.imageTag}`;
            default:
                throw `Unsupported platform in generateImagePath(): ${platform}`;
        }
    }

    private static parseApplicationIdFromConnectionString(connectionString: string): string | null {
        if (!connectionString) {
            return null;
        }

        // Split the connection string by semicolons to get individual key-value pairs
        const parts = connectionString.split(';');

        for (const part of parts) {
            const trimmedPart = part.trim();
            if (trimmedPart.toLowerCase().startsWith('applicationid=')) {
                const applicationId = trimmedPart.substring('applicationid='.length).trim();
                return applicationId || null;
            }
        }

        return null;
    }

    /**
     * Merges OTEL resource attributes, with our attributes taking precedence over existing ones
     */
    private static mergeOtelResourceAttributes(existingValue: string, newAttributes: string): string {
        if (!existingValue) {
            return newAttributes;
        }
        
        // Parse existing attributes into a map
        const existingAttributes: Record<string, string> = {};
        const existingPairs = existingValue.split(',');
        
        for (const pair of existingPairs) {
            const trimmedPair = pair.trim();
            if (trimmedPair) {
                const [key, ...valueParts] = trimmedPair.split('=');
                if (key && valueParts.length > 0) {
                    existingAttributes[key.trim()] = valueParts.join('=').trim();
                }
            }
        }
        
        // Parse new attributes into a map
        const newAttributesMap: Record<string, string> = {};
        const newPairs = newAttributes.split(',');
        
        for (const pair of newPairs) {
            const trimmedPair = pair.trim();
            if (trimmedPair) {
                const [key, ...valueParts] = trimmedPair.split('=');
                if (key && valueParts.length > 0) {
                    newAttributesMap[key.trim()] = valueParts.join('=').trim();
                }
            }
        }
        
        // Merge attributes with our attributes taking precedence
        const mergedAttributes = { ...existingAttributes, ...newAttributesMap };
        
        // Convert back to string
        return Object.entries(mergedAttributes)
            .map(([key, value]) => `${key}=${value}`)
            .join(',');
    }
}
