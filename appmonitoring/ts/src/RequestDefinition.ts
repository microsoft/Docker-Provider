import * as http from "http"

export interface IKind {
    group: string;
    version: string;
    kind: string;
}

export interface IResource {
    group: string;
    version: string;
    resource: string;
}

export interface IUserInfo {
    username: string;
    groups: string[];
}

export interface ILabels {
    app: string;
}

export interface IInstrumentationState {
    crName: string;
    crResourceVersion: string;
    platforms: string[];
}

export const InstrumentationAnnotationName = "monitor.azure.com/instrumentation";
export const FluentBitIoExcludeAnnotationName = "fluentbit.io/exclude";
export const FluentBitIoExcludeBeforeMutationAnnotationName = "monitor.azure.com/fluentbit.io-exclude-before-auto-instrumentation";
export interface IAnnotations {
    "instrumentation.opentelemetry.io/inject-dotnet"?: string;
    "instrumentation.opentelemetry.io/inject-java"?: string;
    "instrumentation.opentelemetry.io/inject-nodejs"?: string;

    [key: string]: string;
}

export interface IOwnerReference {
    kind: string;
    name: string;
    uid: string;
}

export interface IMetadata {
    name: string;
    namespace: string;
    uid: string;
    labels?: ILabels;
    annotations?: IAnnotations;
    ownerReferences?: IOwnerReference[];
}

export interface IMatchLabels {
    app: string;
}

export interface ISelector {
    matchLabels: IMatchLabels;
}

export interface IPort {
    containerPort: number;
    protocol: string;
}

export interface ILimits {
    cpu: string;
    memory: string;
}

export interface IRequests {
    cpu: string;
    memory: string;
}

export interface IResources {
    requests: IRequests;
    limits: ILimits;
}

export interface IContainer {
    name: string;
    image: string;
    command?: string[];
    args?: string[];
    ports?: IPort[];
    resources?: IResources;
    terminationMessagePath?: string;
    terminationMessagePolicy?: string;
    imagePullPolicy?: string;
    env?: IEnvironmentVariable[];
    volumeMounts?: IVolumeMount[];
}

export interface IVolume {
    name: string;
    emptyDir?: object;
}

export interface IVolumeMount {
    name: string;
    mountPath: string;
}

export interface ITemplate {
    metadata: IMetadata;
    spec: ISpec;
}

export interface IRollingUpdate {
    maxUnavailable: number;
    maxSurge: number;
}

export interface IStrategy {
    type: string;
    rollingUpdate: IRollingUpdate;
}

export interface ISpec {
    replicas: number;
    selector: ISelector;
    template: ITemplate;
    strategy?: IStrategy;
    minReadySeconds?: number;
    revisionHistoryLimit?: number;
    progressDeadlineSeconds?: number;
    initContainers?: IContainer[];
    volumes?: IVolume[];
    containers?: IContainer[];
}

export interface IObjectType {
    kind: string;
    apiVersion: string;
    metadata: IMetadata;
    spec: ISpec;
    status: object;
}

export interface IEnvironmentVariable {
    name: string;
    value?: string;
    valueFrom?: object;
    doNotSet?: boolean; // indicates we shouldn't set this environment variable during mutation
    platformSpecific?: AutoInstrumentationPlatforms; // indicates this environment is platform-specific
}

export interface IRequest {
    uid: string;
    kind: IKind;
    resource: IResource;
    namespace: string;
    operation: string;
    userInfo: IUserInfo;
    object: IObjectType;
    oldObject: string;
    dryRun: string;
}

export interface IAdmissionReview {
    kind: string;
    apiVersion: string;
    request: IRequest;
    response?: object;
}

export class PodInfo {
    namespace: string;
    ownerKind: string;
    ownerUid: string;
    ownerName: string;
    onlyContainerName: string;
}

export enum AutoInstrumentationPlatforms {
    DotNet = "DotNet",
    Java = "Java",
    NodeJs = "NodeJs"
}

export const DefaultInstrumentationCRName = "default";

export class InstrumentationCR {
    metadata: {
        name: string,
        namespace: string,
        resourceVersion?: string
    };
    spec: {
        settings: {
            autoInstrumentationPlatforms: AutoInstrumentationPlatforms[];
            logCollectionSettings?: {
                disableAppLogs?: boolean;
                disableContainerLogs?: boolean;
            }
        },
        destination: {
            applicationInsightsConnectionString: string;
        }
    }
}

export class ListResponse {
    response: http.IncomingMessage;
    body: {
        metadata: {
            resourceVersion: string
        };
        items: InstrumentationCR[]
    }
}