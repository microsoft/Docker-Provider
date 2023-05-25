export interface InstrumentationModuleFile<T> {
    /** Name of file to be patched with relative path */
    name: string;
    moduleExports?: T;
    /** Supported version this file */
    supportedVersions: string[];
    /** Method to patch the instrumentation  */
    patch(moduleExports: T, moduleVersion?: string): T;
    /** Method to patch the instrumentation  */
    /** Method to unpatch the instrumentation  */
    unpatch(moduleExports?: T, moduleVersion?: string): void;
}
export interface InstrumentationModuleDefinition<T> {
    /** Module name or path  */
    name: string;
    moduleExports?: T;
    /** Instrumented module version */
    moduleVersion?: string;
    /** Supported version of module  */
    supportedVersions: string[];
    /** Module internal files to be patched  */
    files: InstrumentationModuleFile<any>[];
    /** If set to true, the includePrerelease check will be included when calling semver.satisfies */
    includePrerelease?: boolean;
    /** Method to patch the instrumentation  */
    patch?: (moduleExports: T, moduleVersion?: string) => T;
    /** Method to unpatch the instrumentation  */
    unpatch?: (moduleExports: T, moduleVersion?: string) => void;
}
//# sourceMappingURL=types.d.ts.map