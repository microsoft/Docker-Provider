import { DiagLogger, Meter, MeterProvider, Tracer, TracerProvider } from '@opentelemetry/api';
import { InstrumentationModuleDefinition } from './platform/node';
import * as types from './types';
/**
 * Base abstract internal class for instrumenting node and web plugins
 */
export declare abstract class InstrumentationAbstract<T = any> implements types.Instrumentation {
    readonly instrumentationName: string;
    readonly instrumentationVersion: string;
    protected _config: types.InstrumentationConfig;
    private _tracer;
    private _meter;
    protected _diag: DiagLogger;
    constructor(instrumentationName: string, instrumentationVersion: string, config?: types.InstrumentationConfig);
    protected _wrap: <Nodule extends object, FieldName extends keyof Nodule>(nodule: Nodule, name: FieldName, wrapper: (original: Nodule[FieldName]) => Nodule[FieldName]) => void;
    protected _unwrap: <Nodule extends object>(nodule: Nodule, name: keyof Nodule) => void;
    protected _massWrap: <Nodule extends object, FieldName extends keyof Nodule>(nodules: Nodule[], names: FieldName[], wrapper: (original: Nodule[FieldName]) => Nodule[FieldName]) => void;
    protected _massUnwrap: <Nodule extends object>(nodules: Nodule[], names: (keyof Nodule)[]) => void;
    protected get meter(): Meter;
    /**
     * Sets MeterProvider to this plugin
     * @param meterProvider
     */
    setMeterProvider(meterProvider: MeterProvider): void;
    /**
     * Sets the new metric instruments with the current Meter.
     */
    protected _updateMetricInstruments(): void;
    getConfig(): types.InstrumentationConfig;
    /**
     * Sets InstrumentationConfig to this plugin
     * @param InstrumentationConfig
     */
    setConfig(config?: types.InstrumentationConfig): void;
    /**
     * Sets TraceProvider to this plugin
     * @param tracerProvider
     */
    setTracerProvider(tracerProvider: TracerProvider): void;
    protected get tracer(): Tracer;
    abstract enable(): void;
    abstract disable(): void;
    /**
     * Init method in which plugin should define _modules and patches for
     * methods
     */
    protected abstract init(): InstrumentationModuleDefinition<T> | InstrumentationModuleDefinition<T>[] | void;
}
//# sourceMappingURL=instrumentation.d.ts.map