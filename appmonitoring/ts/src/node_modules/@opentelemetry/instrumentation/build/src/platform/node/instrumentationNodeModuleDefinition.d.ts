import { InstrumentationModuleDefinition, InstrumentationModuleFile } from './types';
export declare class InstrumentationNodeModuleDefinition<T> implements InstrumentationModuleDefinition<T> {
    name: string;
    supportedVersions: string[];
    patch?: ((exports: T, moduleVersion?: string | undefined) => T) | undefined;
    unpatch?: ((exports: T, moduleVersion?: string | undefined) => void) | undefined;
    files: InstrumentationModuleFile<T>[];
    constructor(name: string, supportedVersions: string[], patch?: ((exports: T, moduleVersion?: string | undefined) => T) | undefined, unpatch?: ((exports: T, moduleVersion?: string | undefined) => void) | undefined, files?: InstrumentationModuleFile<any>[]);
}
//# sourceMappingURL=instrumentationNodeModuleDefinition.d.ts.map