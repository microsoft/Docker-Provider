"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enable = exports.azureCoreTracing = exports.AzureMonitorSymbol = void 0;
var diagnostic_channel_1 = require("diagnostic-channel");
exports.AzureMonitorSymbol = "Azure_Monitor_Tracer";
var publisherName = "azure-coretracing";
var isPatched = false;
/**
 * By default, @azure/core-tracing default tracer is a NoopTracer.
 * This patching changes the default tracer to a patched BasicTracer
 * which emits ended spans as diag-channel events.
 *
 * The @opentelemetry/tracing package must be installed to use these patches
 * https://www.npmjs.com/package/@opentelemetry/tracing
 * @param coreTracing
 */
var azureCoreTracingPatchFunction = function (coreTracing) {
    if (isPatched) {
        // tracer is already cached -- noop
        return coreTracing;
    }
    try {
        var tracing = require("@opentelemetry/sdk-trace-base");
        var api = require("@opentelemetry/api");
        var defaultProvider = new tracing.BasicTracerProvider();
        var defaultTracer = defaultProvider.getTracer("applicationinsights tracer");
        // Patch Azure SDK setTracer, @azure/core-tracing <= 1.0.0-preview.12
        if (coreTracing.setTracer) {
            var setTracerOriginal_1 = coreTracing.setTracer;
            coreTracing.setTracer = function (tracer) {
                // Patch startSpan instead of using spanProcessor.onStart because parentSpan must be
                // set while the span is constructed
                var startSpanOriginal = tracer.startSpan;
                tracer.startSpan = function (name, options, context) {
                    var span = startSpanOriginal.call(this, name, options, context);
                    var originalEnd = span.end;
                    span.end = function () {
                        var result = originalEnd.apply(this, arguments);
                        diagnostic_channel_1.channel.publish(publisherName, span);
                        return result;
                    };
                    return span;
                };
                tracer[exports.AzureMonitorSymbol] = true;
                setTracerOriginal_1.call(this, tracer);
            };
            api.trace.getSpan(api.context.active()); // seed OpenTelemetryScopeManagerWrapper with "active" symbol
            coreTracing.setTracer(defaultTracer);
        }
        else { // Patch OpenTelemetry setGlobalTracerProvider  @azure/core-tracing > 1.0.0-preview.13
            var setGlobalTracerProviderOriginal_1 = api.trace.setGlobalTracerProvider;
            api.trace.setGlobalTracerProvider = function (tracerProvider) {
                var getTracerOriginal = tracerProvider.getTracer;
                tracerProvider.getTracer = function (tracerName, version) {
                    var tracer = getTracerOriginal.call(this, tracerName, version);
                    if (!tracer[exports.AzureMonitorSymbol]) { // Avoid patching multiple times
                        var startSpanOriginal_1 = tracer.startSpan;
                        tracer.startSpan = function (spanName, options, context) {
                            var span = startSpanOriginal_1.call(this, spanName, options, context);
                            var originalEnd = span.end;
                            span.end = function () {
                                var result = originalEnd.apply(this, arguments);
                                diagnostic_channel_1.channel.publish(publisherName, span);
                                return result;
                            };
                            return span;
                        };
                        tracer[exports.AzureMonitorSymbol] = true;
                    }
                    return tracer;
                };
                return setGlobalTracerProviderOriginal_1.call(this, tracerProvider);
            };
            defaultProvider.register();
            api.trace.getSpan(api.context.active()); // seed OpenTelemetryScopeManagerWrapper with "active" symbol
            // Register Azure SDK instrumentation
            var openTelemetryInstr = require("@opentelemetry/instrumentation");
            var azureSdkInstr = require("@azure/opentelemetry-instrumentation-azure-sdk");
            openTelemetryInstr.registerInstrumentations({
                instrumentations: [
                    azureSdkInstr.createAzureSdkInstrumentation()
                ]
            });
        }
        isPatched = true;
    }
    catch (e) { /* squash errors */ }
    return coreTracing;
};
exports.azureCoreTracing = {
    versionSpecifier: ">= 1.0.0 < 2.0.0",
    patch: azureCoreTracingPatchFunction,
    publisherName: publisherName
};
function enable() {
    diagnostic_channel_1.channel.registerMonkeyPatch("@azure/core-tracing", exports.azureCoreTracing);
}
exports.enable = enable;
//# sourceMappingURL=azure-coretracing.pub.js.map