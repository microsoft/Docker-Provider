import { Mutations } from "./Mutations.js";
import { PodInfo, IContainer, ISpec, IVolume, IEnvironmentVariable, AutoInstrumentationPlatforms, IVolumeMount, InstrumentationAnnotationName, EnableApplicationLogsAnnotationName, InstrumentationCR, IInstrumentationState, IMetadata, IAnnotations, IObjectType, OtelParams } from "./RequestDefinition.js";
import * as Common from "./Common.js";


export class Patcher {

    private static readonly EnvironmentVariableBackupSuffix: string = "_BEFORE_AUTO_INSTRUMENTATION";

    /**
     * Calculates a JsonPatch string describing the difference between the old (incoming) and new (outgoing) spec
     * The spec is also patched in-place
    */
    public static PatchObject(obj: IObjectType, cr: InstrumentationCR, podInfo: PodInfo, platforms: AutoInstrumentationPlatforms[], armId: string, armRegion: string, clusterName: string, otelParams: OtelParams): object[] {
        if (!obj?.spec) {
            throw `Unable to parse request.object.spec in AdmissionReview: ${obj}`;
        }

        // remove all mutation (in case it is already mutated)
        this.unpatch(obj);

        // mutate
        this.patch(cr, platforms, obj, podInfo, armId, armRegion, clusterName, otelParams);

        const jsonPatch: object[] = [
            // replace the entire root section with the mutated one
            {
                op: "replace",
                path: "", // root, which is request.object of the admission review
                value: obj
            }];

        return jsonPatch;
    }

    private static patch(cr: InstrumentationCR, platforms: AutoInstrumentationPlatforms[], obj: IObjectType, podInfo: PodInfo, armId: string, armRegion: string, clusterName: string, otelParams: OtelParams) {
        if (cr) {
            const spec: ISpec = obj.spec;
            const podSpec: ISpec = spec.template.spec;
        
            // add deployment-level annotation describing current mutation
            obj.metadata = obj.metadata ?? <IMetadata>{};
            obj.metadata.annotations = obj.metadata.annotations ?? <IAnnotations>{};
            obj.metadata.annotations[InstrumentationAnnotationName] = JSON.stringify(<IInstrumentationState>{
                crName: cr.metadata.name,
                crResourceVersion: cr.metadata.resourceVersion,
                platforms: <string[]>platforms
            });

            // determine if application logs should be enabled as indicated by a pod spec annotation (specified by the customer)
            const enableApplicationLogsAnnotation = spec.template.metadata?.annotations?.[EnableApplicationLogsAnnotationName]; 
            const enableApplicationLogs: boolean = enableApplicationLogsAnnotation?.toLocaleLowerCase() === "true" || enableApplicationLogsAnnotation?.toLocaleLowerCase() === "1";
            
            // determine if Python is enabled (Python can only be enabled via private-preview annotation)
            const isPythonPrivatePreview: boolean = platforms.includes(AutoInstrumentationPlatforms.Python);
            
            // add new volumes (used to store agent binaries)
            const newVolumes: IVolume[] = Mutations.GenerateVolumes(platforms);
            podSpec.volumes = (podSpec.volumes ?? <IVolume[]>[]).concat(newVolumes);

            // add new initcontainers (used to copy agent binaries over to the pod)
            const newInitContainers: IContainer[] = Mutations.GenerateInitContainers(platforms);
            podSpec.initContainers = (podSpec.initContainers ?? <IContainer[]>[]).concat(newInitContainers);

            podSpec.containers?.forEach(container => {
                // hold all environment variables in a dictionary, both existing and new ones
                const allEnvironmentVariables: Record<string, IEnvironmentVariable> = {};

                // add existing environment variables to the dictionary
                container.env?.forEach(env => allEnvironmentVariables[env.name] = env);

                // Generate environment variables with knowledge of existing ones for OTEL_RESOURCE_ATTRIBUTES merging
                const newEnvironmentVariables: IEnvironmentVariable[] = Mutations.GenerateEnvironmentVariables(podInfo, container.name, platforms, !enableApplicationLogs, cr.spec?.destination?.applicationInsightsConnectionString, armId, armRegion, clusterName, otelParams, allEnvironmentVariables, isPythonPrivatePreview);

                /*
                    We could be receiving customer's original set of environment variables (e.g. in case of kubectl apply),
                    or we could be receiving a mutated version of environment variables (e.g. in case of kubectl rollout restart for an object that is already mutated).
    
                    For each instrumentation-related environment variable we will use a backup environment variable which has name of the format `${envVariableName}${Patcher.EnvironmentVariableBackupSuffix}`
                    and stores the original customer's value (if any). The backup environment variable only exists if there is an original value to store.
    
                    When reverting mutation, the deployment-level annotation will indicate if the deployment is mutated, and which platforms were used during mutation.
                    That annotation (or its absence) will tell us what to do with instrumentation-related environment variables that have no backup environment variable.
                */

                // add new environment variables to the dictionary
                newEnvironmentVariables.forEach(newEnv => {
                    if (!allEnvironmentVariables[newEnv.name]) {
                        // this mutation environment variable is not present in the container originally, so just add it unless it's not supposed to be set
                        if (!newEnv.doNotSet) {
                            allEnvironmentVariables[newEnv.name] = newEnv;
                        }
                    } else {
                        // we are overwriting an environment variable which already exists in the container
                        // save the original value into a backup environment variable
                        const backupName = `${newEnv.name}${Patcher.EnvironmentVariableBackupSuffix}`;
                        const backupEV: IEnvironmentVariable = JSON.parse(JSON.stringify(allEnvironmentVariables[newEnv.name])) as IEnvironmentVariable;
                        backupEV.name = backupName;
                        allEnvironmentVariables[backupName] = backupEV;

                        // if it's not supposed to be set - just keep the original value, otherwise set the new value
                        if (!newEnv.doNotSet) {
                            allEnvironmentVariables[newEnv.name] = newEnv;
                        }
                    }
                });

                // set all environment variables contained within the dictionary on the container
                container.env = <IEnvironmentVariable[]>[];
                for (const envVariableName in allEnvironmentVariables) {                    
                    container.env.push(allEnvironmentVariables[envVariableName]);
                }

                // add new volume mounts (used by customer's application runtimes to load agent binaries)
                const newVolumeMounts: IVolumeMount[] = Mutations.GenerateVolumeMounts(platforms);
                container.volumeMounts = (container.volumeMounts ?? <IVolumeMount[]>[]).concat(newVolumeMounts);
            });
        }
    }

    /**
     * Removes all mutations from a spec in-place
     */
    private static unpatch(obj: IObjectType): void {
        const spec: ISpec = obj?.spec;
        const podSpec: ISpec = spec?.template?.spec;
        
        if (!spec || !podSpec) {
            throw `Unable to parse spec from AdmissionReview: ${JSON.stringify(obj)}`;
        }

        const instrumentationState: IInstrumentationState = obj.metadata?.annotations?.[InstrumentationAnnotationName] ? JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) : null;

        // remove deployment annotations
        obj.metadata = obj.metadata ?? <IMetadata>{};
        if (obj.metadata.annotations) {
            delete obj.metadata.annotations[InstrumentationAnnotationName];
        }

        // we are removing all mutations (regardless of whether only some mutations are applied based on the platforms used)
        const allPlatforms: AutoInstrumentationPlatforms[] = [];
        Object.keys(AutoInstrumentationPlatforms).forEach(key => allPlatforms.push(AutoInstrumentationPlatforms[key]));
        
        // remove volumes by name
        const volumesToRemove: IVolume[] = Mutations.GenerateVolumes(allPlatforms);
        podSpec.volumes = podSpec.volumes?.filter(volume => !volumesToRemove.find(vtr => volume.name === vtr.name));
        
        // remove init containers by name
        const initContainersToRemove: IContainer[] = Mutations.GenerateInitContainers(allPlatforms);
        podSpec.initContainers = podSpec.initContainers?.filter(ic => !initContainersToRemove.find(ictr => ic.name === ictr.name));

        // remove environment variables and volume mounts from all containers by name
        // we don't care about values of environment variables here, we just need all names, so set parameters to get all of them
        const otelParams: OtelParams = { logsEnabled: true, metricsEnabled: true, logsPortHttpProtobuf: 0, metricsPortHttpProtobuf: 0 };
        const environmentVariablesToRemove: IEnvironmentVariable[] = Mutations.GenerateEnvironmentVariables(new PodInfo(), "dummy-container", allPlatforms, true, "", "", "", "", otelParams, undefined, false);
        const volumeMountsToRemove: IVolumeMount[] = Mutations.GenerateVolumeMounts(allPlatforms);

        podSpec.containers?.forEach(container => {
            environmentVariablesToRemove.forEach(evtr => {
                // find the environment variable in the container
                const evIndex = container.env?.findIndex(ev => ev.name === evtr.name);

                if(evIndex === -1 || evIndex === undefined) {
                    // container doesn't have this environment variable, continue
                    return;
                }

                // container contains this environment variable

                // special handling for OTEL_RESOURCE_ATTRIBUTES - preserve certain attributes during unpatch
                // we need to preserve two kinds of attributes:
                // - attributes that are completely unknown to us (never injected by mutation)
                // - certain user-priority attributes (e.g. service.name, service.instance.id) that are injected by mutations, but the user-provided value takes precedence during mutation (unlike all other attributes)
                if(evtr.name === "OTEL_RESOURCE_ATTRIBUTES" && instrumentationState?.crName) {
                    const currentValue = container.env[evIndex].value;
                    
                    // check if there's a backup to determine user-provided values
                    const backupEvName = `${evtr.name}${Patcher.EnvironmentVariableBackupSuffix}`;
                    const backupEv: IEnvironmentVariable = container.env?.find(e => e.name === backupEvName);
                    
                    const userAttributes: string = this.extractUserOtelResourceAttributes(currentValue, backupEv?.value);
                    
                    if(userAttributes) {
                        // user has custom attributes, preserve them
                        container.env[evIndex].value = userAttributes;
                        return; // don't remove or restore from backup
                    }
                    // if no user attributes, fall through to normal removal logic
                }

                // is there a backup environment variable that we created during mutation to hold the original value?
                const backupEvName = `${evtr.name}${Patcher.EnvironmentVariableBackupSuffix}`;
                const backupEv: IEnvironmentVariable = container.env?.find(e => e.name === backupEvName);
                if(backupEv) {
                    // there is, restore its value into the primary environment variable, and remove the backup one

                    // make the backup one into the primary
                    backupEv.name = backupEv.name.replace(Patcher.EnvironmentVariableBackupSuffix, "");

                    // remove the old primary one
                    container.env?.splice(evIndex, 1);
                } else {
                    // there is not, so this is either the original, never mutated, object, or a mutated object where the original didn't have this environment variable specified
                    if(instrumentationState?.crName) {
                        // this is a mutated object
                        if(!evtr.platformSpecific || instrumentationState.platforms.includes(evtr.platformSpecific)) {
                            // the variable is either not platform-specific, or it is platform-specific and that platform was selected during the mutation
                            // that means it was created by the mutation, and since there is no backup - it wasn't in the original
                            // we must remove it now that we are unpatching
                            container.env?.splice(evIndex, 1);
                        } else {
                            // the variable is platform-specific, but the mutation did not include this variable's platform
                            // that means it was not created by the mutation, so it was in the original
                            // keep the variable as-is, do nothing
                        }
                    } else {
                        // this is an original, never mutated object, so keep this environment variable as-is
                        // do nothing
                    }
                }
            });
     
            container.volumeMounts = container.volumeMounts?.filter(vm => !volumeMountsToRemove.find(vmtr => vm.name === vmtr.name));
        });
    }

    /**
     * Extracts user-provided and user-priority OTEL_RESOURCE_ATTRIBUTES by filtering out mutation-injected attributes
     * Those are the attributes we need to keep during unpatch as they are needed during patching
     * Returns null if no such attributes exist, otherwise returns a comma-separated string
     * NOTE: This function assumes the deployment is mutated (has instrumentation annotation)
     * @param currentValue - The current value of OTEL_RESOURCE_ATTRIBUTES (potentially mutated)
     * @param backupValue - The backup value if it exists (user's original value before mutation)
     */
    private static extractUserOtelResourceAttributes(currentValue: string, backupValue?: string): string | null {
        if (!currentValue) {
            return null;
        }

        // get the attribute keys that our mutation injects - these should be removed during unpatch
        const mutationAttributeKeys = Mutations.GetMutationOtelResourceAttributeKeys();

        // Parse backup attributes to identify user-provided and user-priority attributes
        const backupAttributes = Common.parseOtelAttributes(backupValue || '');

        // Parse current attributes
        const userAttributes: Record<string, string> = {};
        const currentAttributes = Common.parseOtelAttributes(currentValue);
        
        for (const [trimmedKey, trimmedValue] of Object.entries(currentAttributes) as [string, string][]) {
            // we can't simply discard user-priority attributes, we need to keep them since they will impact mutation
            if (Mutations.GetUserPriorityOtelResourceAttributeKeys().has(trimmedKey)) {
                // if there's a backup and these attributes exist in it, they were user-provided, so preserve them
                if (backupValue && backupAttributes[trimmedKey]) {
                    userAttributes[trimmedKey] = trimmedValue;
                }
                // otherwise, they were injected by mutation, so don't preserve them
            } else if (!mutationAttributeKeys.has(trimmedKey)) {
                // for all other attributes, keep only those that aren't mutation-injected
                userAttributes[trimmedKey] = trimmedValue;
            }
        }

        // if no user attributes remain, return null
        if (Object.keys(userAttributes).length === 0) {
            return null;
        }

        // convert back to string
        return Object.entries(userAttributes)
            .map(([key, value]) => `${key}=${value}`)
            .join(',');
    }
}
