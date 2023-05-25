import { TracerProvider, MeterProvider } from '@opentelemetry/api';
/** Interface Instrumentation to apply patch. */
export interface Instrumentation {
    /** Instrumentation Name  */
    instrumentationName: string;
    /** Instrumentation Version  */
    instrumentationVersion: string;
    /**
     * Instrumentation Description - please describe all useful information
     * as Instrumentation might patch different version of different modules,
     * or support different browsers etc.
     */
    instrumentationDescription?: string;
    /** Method to disable the instrumentation  */
    disable(): void;
    /** Method to enable the instrumentation  */
    enable(): void;
    /** Method to set tracer provider  */
    setTracerProvider(tracerProvider: TracerProvider): void;
    /** Method to set meter provider  */
    setMeterProvider(meterProvider: MeterProvider): void;
    /** Method to set instrumentation config  */
    setConfig(config: InstrumentationConfig): void;
    /** Method to get instrumentation config  */
    getConfig(): InstrumentationConfig;
    /**
     * Contains all supported versions.
     * All versions must be compatible with [semver](https://semver.org/spec/v2.0.0.html) format.
     * If the version is not supported, we won't apply instrumentation patch (see `enable` method).
     * If omitted, all versions of the module will be patched.
     */
    supportedVersions?: string[];
}
export interface InstrumentationConfig {
    /**
     * Whether to enable the plugin.
     * @default true
     */
    enabled?: boolean;
}
/**
 * This interface defines the params that are be added to the wrapped function
 * using the "shimmer.wrap"
 */
export interface ShimWrapped extends Function {
    __wrapped: boolean;
    __unwrap: Function;
    __original: Function;
}
//# sourceMappingURL=types.d.ts.map