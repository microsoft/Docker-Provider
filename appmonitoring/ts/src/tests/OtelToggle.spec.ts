import { expect, describe, it, beforeEach, afterEach } from "@jest/globals";
import { OtelParams } from "RequestDefinition.js";

// Function to simulate the OTEL parameters construction logic from server.ts
function createOtelParams(): OtelParams {
    const otelToggleEnabled = String(process.env.OTEL_TOGGLE).trim().toLowerCase() === "true";
    return {
        logsEnabled: otelToggleEnabled && String(process.env.OTEL_LOGS_ENABLED).trim().toLowerCase() === "true",
        metricsEnabled: otelToggleEnabled && String(process.env.OTEL_METRICS_ENABLED).trim().toLowerCase() === "true",
        logsPortHttpProtobuf: Number(process.env.OTEL_LOGS_PORT_HTTPPROTOBUF) || 28331,
        metricsPortHttpProtobuf: Number(process.env.OTEL_METRICS_PORT_HTTPPROTOBUF) || 28333
    };
}

describe("OTEL Toggle Behavior", () => {
    let originalEnv: NodeJS.ProcessEnv;

    beforeEach(() => {
        // Save original environment
        originalEnv = { ...process.env };
        // Clear OTEL-related environment variables
        delete process.env.OTEL_TOGGLE;
        delete process.env.OTEL_LOGS_ENABLED;
        delete process.env.OTEL_METRICS_ENABLED;
        delete process.env.OTEL_LOGS_PORT_HTTPPROTOBUF;
        delete process.env.OTEL_METRICS_PORT_HTTPPROTOBUF;
    });

    afterEach(() => {
        // Restore original environment
        process.env = originalEnv;
    });

    describe("when OTEL_TOGGLE is not set", () => {
        it("should disable both logs and metrics even if individual flags are true", () => {
            process.env.OTEL_LOGS_ENABLED = "true";
            process.env.OTEL_METRICS_ENABLED = "true";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(false);
            expect(otelParams.metricsEnabled).toBe(false);
        });

        it("should use default ports when OTEL_TOGGLE is not set", () => {
            const otelParams = createOtelParams();

            expect(otelParams.logsPortHttpProtobuf).toBe(28331);
            expect(otelParams.metricsPortHttpProtobuf).toBe(28333);
        });
    });

    describe("when OTEL_TOGGLE is set to empty string", () => {
        it("should disable both logs and metrics", () => {
            process.env.OTEL_TOGGLE = "";
            process.env.OTEL_LOGS_ENABLED = "true";
            process.env.OTEL_METRICS_ENABLED = "true";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(false);
            expect(otelParams.metricsEnabled).toBe(false);
        });
    });

    describe("when OTEL_TOGGLE is set to false", () => {
        it("should disable both logs and metrics", () => {
            process.env.OTEL_TOGGLE = "false";
            process.env.OTEL_LOGS_ENABLED = "true";
            process.env.OTEL_METRICS_ENABLED = "true";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(false);
            expect(otelParams.metricsEnabled).toBe(false);
        });
    });

    describe("when OTEL_TOGGLE is set to true (lowercase)", () => {
        beforeEach(() => {
            process.env.OTEL_TOGGLE = "true";
        });

        it("should enable logs when OTEL_LOGS_ENABLED is true", () => {
            process.env.OTEL_LOGS_ENABLED = "true";
            process.env.OTEL_METRICS_ENABLED = "false";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(true);
            expect(otelParams.metricsEnabled).toBe(false);
        });

        it("should enable metrics when OTEL_METRICS_ENABLED is true", () => {
            process.env.OTEL_LOGS_ENABLED = "false";
            process.env.OTEL_METRICS_ENABLED = "true";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(false);
            expect(otelParams.metricsEnabled).toBe(true);
        });

        it("should enable both when both individual flags are true", () => {
            process.env.OTEL_LOGS_ENABLED = "true";
            process.env.OTEL_METRICS_ENABLED = "true";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(true);
            expect(otelParams.metricsEnabled).toBe(true);
        });

        it("should disable both when both individual flags are false", () => {
            process.env.OTEL_LOGS_ENABLED = "false";
            process.env.OTEL_METRICS_ENABLED = "false";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(false);
            expect(otelParams.metricsEnabled).toBe(false);
        });

        it("should disable both when individual flags are not set", () => {
            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(false);
            expect(otelParams.metricsEnabled).toBe(false);
        });
    });

    describe("when OTEL_TOGGLE is set to TRUE (uppercase)", () => {
        it("should work case-insensitively", () => {
            process.env.OTEL_TOGGLE = "TRUE";
            process.env.OTEL_LOGS_ENABLED = "true";
            process.env.OTEL_METRICS_ENABLED = "true";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(true);
            expect(otelParams.metricsEnabled).toBe(true);
        });
    });

    describe("when OTEL_TOGGLE is set to True (mixed case)", () => {
        it("should work case-insensitively", () => {
            process.env.OTEL_TOGGLE = "True";
            process.env.OTEL_LOGS_ENABLED = "TRUE";
            process.env.OTEL_METRICS_ENABLED = "True";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(true);
            expect(otelParams.metricsEnabled).toBe(true);
        });
    });

    describe("when OTEL_TOGGLE has whitespace", () => {
        it("should handle leading and trailing whitespace", () => {
            process.env.OTEL_TOGGLE = "  true  ";
            process.env.OTEL_LOGS_ENABLED = "true";
            process.env.OTEL_METRICS_ENABLED = "true";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(true);
            expect(otelParams.metricsEnabled).toBe(true);
        });
    });

    describe("port configuration", () => {
        beforeEach(() => {
            process.env.OTEL_TOGGLE = "true";
        });

        it("should use custom ports when provided", () => {
            process.env.OTEL_LOGS_PORT_HTTPPROTOBUF = "9999";
            process.env.OTEL_METRICS_PORT_HTTPPROTOBUF = "8888";

            const otelParams = createOtelParams();

            expect(otelParams.logsPortHttpProtobuf).toBe(9999);
            expect(otelParams.metricsPortHttpProtobuf).toBe(8888);
        });

        it("should use default ports when custom ports are invalid", () => {
            process.env.OTEL_LOGS_PORT_HTTPPROTOBUF = "invalid";
            process.env.OTEL_METRICS_PORT_HTTPPROTOBUF = "also-invalid";

            const otelParams = createOtelParams();

            expect(otelParams.logsPortHttpProtobuf).toBe(28331);
            expect(otelParams.metricsPortHttpProtobuf).toBe(28333);
        });

        it("should handle zero ports correctly", () => {
            process.env.OTEL_LOGS_PORT_HTTPPROTOBUF = "0";
            process.env.OTEL_METRICS_PORT_HTTPPROTOBUF = "0";

            const otelParams = createOtelParams();

            expect(otelParams.logsPortHttpProtobuf).toBe(28331);
            expect(otelParams.metricsPortHttpProtobuf).toBe(28333);
        });
    });

    describe("edge cases", () => {
        it("should handle individual flags with whitespace", () => {
            process.env.OTEL_TOGGLE = "true";
            process.env.OTEL_LOGS_ENABLED = "  TRUE  ";
            process.env.OTEL_METRICS_ENABLED = "  false  ";

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(true);
            expect(otelParams.metricsEnabled).toBe(false);
        });

        it("should handle undefined individual flags when OTEL_TOGGLE is true", () => {
            process.env.OTEL_TOGGLE = "true";
            // Don't set OTEL_LOGS_ENABLED and OTEL_METRICS_ENABLED

            const otelParams = createOtelParams();

            expect(otelParams.logsEnabled).toBe(false);
            expect(otelParams.metricsEnabled).toBe(false);
        });
    });
});
