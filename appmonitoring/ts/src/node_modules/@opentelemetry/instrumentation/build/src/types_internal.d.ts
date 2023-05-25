import { TracerProvider, MeterProvider } from '@opentelemetry/api';
import { InstrumentationBase } from './platform';
import { Instrumentation } from './types';
export declare type InstrumentationOption = typeof InstrumentationBase | typeof InstrumentationBase[] | Instrumentation | Instrumentation[];
export interface AutoLoaderResult {
    instrumentations: Instrumentation[];
}
export interface AutoLoaderOptions {
    instrumentations?: InstrumentationOption[];
    tracerProvider?: TracerProvider;
    meterProvider?: MeterProvider;
}
//# sourceMappingURL=types_internal.d.ts.map