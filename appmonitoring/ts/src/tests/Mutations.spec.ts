import { expect, describe, it } from "@jest/globals";
import { Mutations } from "Mutations.js";
import { PodInfo, AutoInstrumentationPlatforms, OtelParams, IEnvironmentVariable } from "RequestDefinition.js";

describe("OTEL Resource Attributes Merging", () => {
    const podInfo = new PodInfo();
    podInfo.ownerKind = "Deployment";
    podInfo.ownerName = "test-app";
    podInfo.ownerUid = "uid-123";
    podInfo.onlyContainerName = "main-container";

    const testOtelParams: OtelParams = {
        logsEnabled: false,
        metricsEnabled: false,
        logsPortHttpProtobuf: 4318,
        metricsPortHttpProtobuf: 4318
    };

    it("should merge OTEL_RESOURCE_ATTRIBUTES with existing attributes", () => {
        // Simulate existing environment variables with OTEL_RESOURCE_ATTRIBUTES
        const existingEnvironmentVariables: Record<string, IEnvironmentVariable> = {
            "OTEL_RESOURCE_ATTRIBUTES": {
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "service.name=my-service,service.version=1.0.0,custom.attr=value"
            }
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo, 
            [AutoInstrumentationPlatforms.Java], 
            false, 
            "InstrumentationKey=test-key", 
            "/subscriptions/test/resourceGroups/test-rg", 
            "eastus", 
            "test-cluster", 
            testOtelParams,
            existingEnvironmentVariables
        );

        const otelResourceAttributes = generatedEnvVars.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttributes).toBeDefined();
        expect(otelResourceAttributes!.value).toContain("service.name=my-service");
        expect(otelResourceAttributes!.value).toContain("service.version=1.0.0");
        expect(otelResourceAttributes!.value).toContain("custom.attr=value");
        expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure");
        expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=test-cluster");
    });

    it("should handle conflicting attributes with our attributes winning", () => {
        const existingEnvironmentVariables: Record<string, IEnvironmentVariable> = {
            "OTEL_RESOURCE_ATTRIBUTES": {
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "cloud.provider=AWS,service.name=my-service,k8s.cluster.name=customer-cluster"
            }
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParams,
            existingEnvironmentVariables
        );

        const otelResourceAttributes = generatedEnvVars.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttributes).toBeDefined();
        expect(otelResourceAttributes!.value).toContain("service.name=my-service"); // customer's attribute preserved
        expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure"); // our attribute wins
        expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=test-cluster"); // our attribute wins
    });

    it("should work without existing OTEL_RESOURCE_ATTRIBUTES", () => {
        const existingEnvironmentVariables: Record<string, IEnvironmentVariable> = {};

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParams,
            existingEnvironmentVariables
        );

        const otelResourceAttributes = generatedEnvVars.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttributes).toBeDefined();
        expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure");
        expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=test-cluster");
    });

    it("should work with undefined existing environment variables", () => {
        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParams,
            undefined
        );

        const otelResourceAttributes = generatedEnvVars.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttributes).toBeDefined();
        expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure");
        expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=test-cluster");
    });
});

describe("OTEL Metrics Exporter Environment Variable", () => {
    const podInfo = new PodInfo();
    podInfo.ownerKind = "Deployment";
    podInfo.ownerName = "test-app";
    podInfo.ownerUid = "uid-123";
    podInfo.onlyContainerName = "main-container";

    it("should include OTEL_METRICS_EXPORTER when metrics are enabled", () => {
        const testOtelParams: OtelParams = {
            logsEnabled: false,
            metricsEnabled: true,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParams,
            undefined
        );

        const otelMetricsExporter = generatedEnvVars.find(env => env.name === "OTEL_METRICS_EXPORTER");
        expect(otelMetricsExporter).toBeDefined();
        expect(otelMetricsExporter!.value).toBe("otlp,azure_monitor");
    });

    it("should not include OTEL_METRICS_EXPORTER when metrics are disabled", () => {
        const testOtelParams: OtelParams = {
            logsEnabled: true,
            metricsEnabled: false,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParams,
            undefined
        );

        const otelMetricsExporter = generatedEnvVars.find(env => env.name === "OTEL_METRICS_EXPORTER");
        expect(otelMetricsExporter).toBeUndefined();
    });

    it("should include OTEL_METRICS_EXPORTER with other metrics environment variables when both logs and metrics are enabled", () => {
        const testOtelParams: OtelParams = {
            logsEnabled: true,
            metricsEnabled: true,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParams,
            undefined
        );

        // Should have OTEL_METRICS_EXPORTER
        const otelMetricsExporter = generatedEnvVars.find(env => env.name === "OTEL_METRICS_EXPORTER");
        expect(otelMetricsExporter).toBeDefined();
        expect(otelMetricsExporter!.value).toBe("otlp,azure_monitor");

        // Should also have other metrics-related variables
        const otelMetricsEndpoint = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
        expect(otelMetricsEndpoint).toBeDefined();
        expect(otelMetricsEndpoint!.value).toBe("http://$(OTEL_ENDPOINT_NODE_IP):4319/v1/metrics");

        const otelMetricsProtocol = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL");
        expect(otelMetricsProtocol).toBeDefined();
        expect(otelMetricsProtocol!.value).toBe("http/protobuf");

        const otelMetricsInsecure = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_INSECURE");
        expect(otelMetricsInsecure).toBeDefined();
        expect(otelMetricsInsecure!.value).toBe("true");
    });
});
