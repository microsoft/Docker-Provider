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

export interface IOwnerReference {
    kind: string;
    name: string;
    uid: string;
}

export interface IMetadata {
    name: string;
    namespace: string;
    creationTimestamp: string;
    labels: ILabels;
    annotations: object;
    generateName?: string;
    ownerReferences?: IOwnerReference[];
}

export interface IMatchLabels {
    app: string;
}

export interface ISelector {
    matchLabels: IMatchLabels;
}

export interface ILabels2 {
    app: string;
}

export interface IMetadata2 {
    creationTimestamp: string;
    labels: ILabels2;
}

export interface IPort {
    containerPort: number;
    protocol: string;
}

export interface ILimits {
    cpu: string;
}

export interface IRequests {
    cpu: string;
}

export interface IResources {
    limits: ILimits;
    requests: IRequests;
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
    volumeMounts?: object[];
}

export interface IVolume {
    name: string;
    emptyDir?: object;
}

export interface ISpec2 {
    containers: IContainer[];
    restartPolicy: string;
    terminationGracePeriodSeconds: number;
    dnsPolicy: string;
    nodeSelector: object;
    securityContext: object;
    schedulerName: string;
    initContainers?: object;
    volumes?: IVolume[];
}

export interface ITemplate {
    metadata: IMetadata2;
    spec: ISpec2;
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
    strategy: IStrategy;
    minReadySeconds: number;
    revisionHistoryLimit: number;
    progressDeadlineSeconds: number;
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
    name: string;
    deploymentName: string;
    onlyContainerName: string;
    ownerReference: IOwnerReference;
}

export class AppMonitoringConfigCR {
    metadata: {
        name: string,
        namespace: string
    };
    spec: {
        autoInstrumentationPlatforms: string[];
        aiConnectionString: string;
        deployments: string[]
    }
}

export class ListResponse {
    response: http.IncomingMessage;
    body: {
        metadata: {
            resourceVersion: string
        };
        items: AppMonitoringConfigCR[]
    }
}