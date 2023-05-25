import { IModulePatcher, IModulePatchMap } from "./patchRequire";
export { PatchFunction, IModulePatcher, makePatchingRequire } from "./patchRequire";
export interface ISpanContext {
    traceId: string;
    spanId: string;
    traceFlags?: string;
    tracestate?: string;
}
declare type ScopeManager = any;
export interface IStandardEvent<T> {
    timestamp: number;
    data: T;
}
export declare type ISubscriber<T> = (event: IStandardEvent<T>) => void;
export declare type IFilter = (publishing: boolean) => boolean;
export declare type IPatchedCallback = (moduleName: string, version: string) => void;
interface IPatchedModule {
    name: string;
    version: string;
}
export interface IChannel {
    shouldPublish(name: string): boolean;
    publish<T>(name: string, event: T): void;
    subscribe<T>(name: string, listener: ISubscriber<T>, filter?: IFilter, patchCallback?: IPatchedCallback): void;
    unsubscribe<T>(name: string, listener: ISubscriber<T>, filter?: IFilter): void;
    bindToContext<T extends Function>(cb: T): T;
    addContextPreservation<T extends Function>(preserver: (cb: T) => T): void;
    registerMonkeyPatch(packageName: string, patcher: IModulePatcher): void;
    getPatchesObject(): IModulePatchMap;
    addPatchedModule(moduleName: string, version: string): void;
}
export declare const trueFilter: (publishing: boolean) => boolean;
export declare class ContextPreservingEventEmitter implements IChannel {
    version: string;
    spanContextPropagator: ScopeManager;
    private subscribers;
    private contextPreservationFunction;
    private knownPatches;
    modulesPatched: IPatchedModule[];
    private currentlyPublishing;
    shouldPublish(name: string): boolean;
    publish<T>(name: string, event: T): void;
    subscribe<T>(name: string, listener: ISubscriber<T>, filter?: IFilter, patchCallback?: IPatchedCallback): void;
    unsubscribe<T>(name: string, listener: ISubscriber<T>, filter?: IFilter): boolean;
    reset(): void;
    bindToContext<T extends Function>(cb: T): T;
    addContextPreservation<T extends Function>(preserver: (cb: T) => T): void;
    registerMonkeyPatch(packageName: string, patcher: IModulePatcher): void;
    getPatchesObject(): IModulePatchMap;
    addPatchedModule(name: string, version: string): void;
    private checkIfModuleIsAlreadyPatched;
}
export declare const channel: IChannel;
