import { InstrumentationModuleFile } from './types';
export declare class InstrumentationNodeModuleFile<T> implements InstrumentationModuleFile<T> {
    supportedVersions: string[];
    patch: (moduleExports: T, moduleVersion?: string) => T;
    unpatch: (moduleExports?: T, moduleVersion?: string) => void;
    name: string;
    constructor(name: string, supportedVersions: string[], patch: (moduleExports: T, moduleVersion?: string) => T, unpatch: (moduleExports?: T, moduleVersion?: string) => void);
}
//# sourceMappingURL=instrumentationNodeModuleFile.d.ts.map