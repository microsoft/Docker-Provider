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
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
import { diag, metrics, trace, } from '@opentelemetry/api';
import * as shimmer from 'shimmer';
/**
 * Base abstract internal class for instrumenting node and web plugins
 */
var InstrumentationAbstract = /** @class */ (function () {
    function InstrumentationAbstract(instrumentationName, instrumentationVersion, config) {
        if (config === void 0) { config = {}; }
        this.instrumentationName = instrumentationName;
        this.instrumentationVersion = instrumentationVersion;
        /* Api to wrap instrumented method */
        this._wrap = shimmer.wrap;
        /* Api to unwrap instrumented methods */
        this._unwrap = shimmer.unwrap;
        /* Api to mass wrap instrumented method */
        this._massWrap = shimmer.massWrap;
        /* Api to mass unwrap instrumented methods */
        this._massUnwrap = shimmer.massUnwrap;
        this._config = __assign({ enabled: true }, config);
        this._diag = diag.createComponentLogger({
            namespace: instrumentationName,
        });
        this._tracer = trace.getTracer(instrumentationName, instrumentationVersion);
        this._meter = metrics.getMeter(instrumentationName, instrumentationVersion);
        this._updateMetricInstruments();
    }
    Object.defineProperty(InstrumentationAbstract.prototype, "meter", {
        /* Returns meter */
        get: function () {
            return this._meter;
        },
        enumerable: false,
        configurable: true
    });
    /**
     * Sets MeterProvider to this plugin
     * @param meterProvider
     */
    InstrumentationAbstract.prototype.setMeterProvider = function (meterProvider) {
        this._meter = meterProvider.getMeter(this.instrumentationName, this.instrumentationVersion);
        this._updateMetricInstruments();
    };
    /**
     * Sets the new metric instruments with the current Meter.
     */
    InstrumentationAbstract.prototype._updateMetricInstruments = function () {
        return;
    };
    /* Returns InstrumentationConfig */
    InstrumentationAbstract.prototype.getConfig = function () {
        return this._config;
    };
    /**
     * Sets InstrumentationConfig to this plugin
     * @param InstrumentationConfig
     */
    InstrumentationAbstract.prototype.setConfig = function (config) {
        if (config === void 0) { config = {}; }
        this._config = Object.assign({}, config);
    };
    /**
     * Sets TraceProvider to this plugin
     * @param tracerProvider
     */
    InstrumentationAbstract.prototype.setTracerProvider = function (tracerProvider) {
        this._tracer = tracerProvider.getTracer(this.instrumentationName, this.instrumentationVersion);
    };
    Object.defineProperty(InstrumentationAbstract.prototype, "tracer", {
        /* Returns tracer */
        get: function () {
            return this._tracer;
        },
        enumerable: false,
        configurable: true
    });
    return InstrumentationAbstract;
}());
export { InstrumentationAbstract };
//# sourceMappingURL=instrumentation.js.map