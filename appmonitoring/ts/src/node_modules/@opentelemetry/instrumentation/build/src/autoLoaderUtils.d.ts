import { TracerProvider, MeterProvider } from '@opentelemetry/api';
import { Instrumentation } from './types';
import { AutoLoaderResult, InstrumentationOption } from './types_internal';
/**
 * Parses the options and returns instrumentations, node plugins and
 *   web plugins
 * @param options
 */
export declare function parseInstrumentationOptions(options?: InstrumentationOption[]): AutoLoaderResult;
/**
 * Enable instrumentations
 * @param instrumentations
 * @param tracerProvider
 * @param meterProvider
 */
export declare function enableInstrumentations(instrumentations: Instrumentation[], tracerProvider?: TracerProvider, meterProvider?: MeterProvider): void;
/**
 * Disable instrumentations
 * @param instrumentations
 */
export declare function disableInstrumentations(instrumentations: Instrumentation[]): void;
//# sourceMappingURL=autoLoaderUtils.d.ts.map