"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.InstrumentationAbstract = void 0;
const api_1 = require("@opentelemetry/api");
const shimmer = require("shimmer");
/**
 * Base abstract internal class for instrumenting node and web plugins
 */
class InstrumentationAbstract {
    constructor(instrumentationName, instrumentationVersion, config = {}) {
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
        this._config = Object.assign({ enabled: true }, config);
        this._diag = api_1.diag.createComponentLogger({
            namespace: instrumentationName,
        });
        this._tracer = api_1.trace.getTracer(instrumentationName, instrumentationVersion);
        this._meter = api_1.metrics.getMeter(instrumentationName, instrumentationVersion);
        this._updateMetricInstruments();
    }
    /* Returns meter */
    get meter() {
        return this._meter;
    }
    /**
     * Sets MeterProvider to this plugin
     * @param meterProvider
     */
    setMeterProvider(meterProvider) {
        this._meter = meterProvider.getMeter(this.instrumentationName, this.instrumentationVersion);
        this._updateMetricInstruments();
    }
    /**
     * Sets the new metric instruments with the current Meter.
     */
    _updateMetricInstruments() {
        return;
    }
    /* Returns InstrumentationConfig */
    getConfig() {
        return this._config;
    }
    /**
     * Sets InstrumentationConfig to this plugin
     * @param InstrumentationConfig
     */
    setConfig(config = {}) {
        this._config = Object.assign({}, config);
    }
    /**
     * Sets TraceProvider to this plugin
     * @param tracerProvider
     */
    setTracerProvider(tracerProvider) {
        this._tracer = tracerProvider.getTracer(this.instrumentationName, this.instrumentationVersion);
    }
    /* Returns tracer */
    get tracer() {
        return this._tracer;
    }
}
exports.InstrumentationAbstract = InstrumentationAbstract;
//# sourceMappingURL=instrumentation.js.map