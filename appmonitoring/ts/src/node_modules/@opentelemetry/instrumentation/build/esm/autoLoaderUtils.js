/*
 * Copyright The OpenTelemetry Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/**
 * Parses the options and returns instrumentations, node plugins and
 *   web plugins
 * @param options
 */
export function parseInstrumentationOptions(options) {
    if (options === void 0) { options = []; }
    var instrumentations = [];
    for (var i = 0, j = options.length; i < j; i++) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        var option = options[i];
        if (Array.isArray(option)) {
            var results = parseInstrumentationOptions(option);
            instrumentations = instrumentations.concat(results.instrumentations);
        }
        else if (typeof option === 'function') {
            instrumentations.push(new option());
        }
        else if (option.instrumentationName) {
            instrumentations.push(option);
        }
    }
    return { instrumentations: instrumentations };
}
/**
 * Enable instrumentations
 * @param instrumentations
 * @param tracerProvider
 * @param meterProvider
 */
export function enableInstrumentations(instrumentations, tracerProvider, meterProvider) {
    for (var i = 0, j = instrumentations.length; i < j; i++) {
        var instrumentation = instrumentations[i];
        if (tracerProvider) {
            instrumentation.setTracerProvider(tracerProvider);
        }
        if (meterProvider) {
            instrumentation.setMeterProvider(meterProvider);
        }
        // instrumentations have been already enabled during creation
        // so enable only if user prevented that by setting enabled to false
        // this is to prevent double enabling but when calling register all
        // instrumentations should be now enabled
        if (!instrumentation.getConfig().enabled) {
            instrumentation.enable();
        }
    }
}
/**
 * Disable instrumentations
 * @param instrumentations
 */
export function disableInstrumentations(instrumentations) {
    instrumentations.forEach(function (instrumentation) { return instrumentation.disable(); });
}
//# sourceMappingURL=autoLoaderUtils.js.map