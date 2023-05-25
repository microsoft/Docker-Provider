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
exports.ConsoleSpanExporter = void 0;
const core_1 = require("@opentelemetry/core");
/**
 * This is implementation of {@link SpanExporter} that prints spans to the
 * console. This class can be used for diagnostic purposes.
 */
/* eslint-disable no-console */
class ConsoleSpanExporter {
    /**
     * Export spans.
     * @param spans
     * @param resultCallback
     */
    export(spans, resultCallback) {
        return this._sendSpans(spans, resultCallback);
    }
    /**
     * Shutdown the exporter.
     */
    shutdown() {
        this._sendSpans([]);
        return Promise.resolve();
    }
    /**
     * converts span info into more readable format
     * @param span
     */
    _exportInfo(span) {
        var _a;
        return {
            traceId: span.spanContext().traceId,
            parentId: span.parentSpanId,
            traceState: (_a = span.spanContext().traceState) === null || _a === void 0 ? void 0 : _a.serialize(),
            name: span.name,
            id: span.spanContext().spanId,
            kind: span.kind,
            timestamp: (0, core_1.hrTimeToMicroseconds)(span.startTime),
            duration: (0, core_1.hrTimeToMicroseconds)(span.duration),
            attributes: span.attributes,
            status: span.status,
            events: span.events,
            links: span.links,
        };
    }
    /**
     * Showing spans in console
     * @param spans
     * @param done
     */
    _sendSpans(spans, done) {
        for (const span of spans) {
            console.dir(this._exportInfo(span), { depth: 3 });
        }
        if (done) {
            return done({ code: core_1.ExportResultCode.SUCCESS });
        }
    }
}
exports.ConsoleSpanExporter = ConsoleSpanExporter;
//# sourceMappingURL=ConsoleSpanExporter.js.map