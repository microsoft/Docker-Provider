import { expect, describe, it } from "@jest/globals";
import { Mutations } from "Mutations.js";
import { PodInfo, AutoInstrumentationPlatforms, OtelParams, IEnvironmentVariable } from "RequestDefinition.js";

describe("OTEL Resource Attributes Merging", () => {
    const podInfo = new PodInfo();
    podInfo.ownerKind = "Deployment";
    podInfo.ownerName = "test-app";
    podInfo.ownerUid = "uid-123";

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
            "main-container",
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
        expect(otelResourceAttributes!.value).toContain("service.name=my-service"); // user value preserved
        expect(otelResourceAttributes!.value).toContain("service.version=1.0.0");
        expect(otelResourceAttributes!.value).toContain("custom.attr=value");
        expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure");
        expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=test-cluster");
        expect(otelResourceAttributes!.value).toContain("k8s.container.name=main-container");
        expect(otelResourceAttributes!.value).toContain("service.instance.id=$(POD_NAME)"); // our value since user didn't set it
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
            "main-container",
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
        expect(otelResourceAttributes!.value).toContain("service.name=my-service"); // user value preserved for service.name
        expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure"); // our attribute wins
        expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=test-cluster"); // our attribute wins
        expect(otelResourceAttributes!.value).toContain("k8s.container.name=main-container");
        expect(otelResourceAttributes!.value).toContain("service.instance.id=$(POD_NAME)"); // our value since user didn't set it
    });

    it("should work without existing OTEL_RESOURCE_ATTRIBUTES", () => {
        const existingEnvironmentVariables: Record<string, IEnvironmentVariable> = {};

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "main-container",
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
        expect(otelResourceAttributes!.value).toContain("k8s.container.name=main-container");
        expect(otelResourceAttributes!.value).toContain("service.name=test-app"); // our value used when user doesn't set it
        expect(otelResourceAttributes!.value).toContain("service.instance.id=$(POD_NAME)"); // our value used when user doesn't set it
    });

    it("should work with undefined existing environment variables", () => {
        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "main-container",
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
        expect(otelResourceAttributes!.value).toContain("k8s.container.name=main-container");
        expect(otelResourceAttributes!.value).toContain("service.name=test-app"); // our value used when user doesn't set it
        expect(otelResourceAttributes!.value).toContain("service.instance.id=$(POD_NAME)"); // our value used when user doesn't set it
    });

    it("should use correct container name for each container in multi-container pod", () => {
        // First container
        const generatedEnvVars1 = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "app-container",
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParams,
            undefined
        );

        const otelResourceAttributes1 = generatedEnvVars1.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttributes1).toBeDefined();
        expect(otelResourceAttributes1!.value).toContain("k8s.container.name=app-container");
        expect(otelResourceAttributes1!.value).toContain("service.name=test-app");
        expect(otelResourceAttributes1!.value).toContain("service.instance.id=$(POD_NAME)");

        // Second container
        const generatedEnvVars2 = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "sidecar-container",
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParams,
            undefined
        );

        const otelResourceAttributes2 = generatedEnvVars2.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttributes2).toBeDefined();
        expect(otelResourceAttributes2!.value).toContain("k8s.container.name=sidecar-container");
        expect(otelResourceAttributes2!.value).toContain("service.name=test-app");
        expect(otelResourceAttributes2!.value).toContain("service.instance.id=$(POD_NAME)");
        
        // Make sure they are different
        expect(otelResourceAttributes1!.value).not.toBe(otelResourceAttributes2!.value);
    });

    it("should preserve user's service.name when provided", () => {
        const existingEnvironmentVariables: Record<string, IEnvironmentVariable> = {
            "OTEL_RESOURCE_ATTRIBUTES": {
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "service.name=user-custom-service"
            }
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "main-container",
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
        // User's service.name should be preserved
        expect(otelResourceAttributes!.value).toContain("service.name=user-custom-service");
        expect(otelResourceAttributes!.value).not.toContain("service.name=test-app");
        // Our service.instance.id should be added since user didn't provide it
        expect(otelResourceAttributes!.value).toContain("service.instance.id=$(POD_NAME)");
    });

    it("should preserve user's service.instance.id when provided", () => {
        const existingEnvironmentVariables: Record<string, IEnvironmentVariable> = {
            "OTEL_RESOURCE_ATTRIBUTES": {
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "service.instance.id=user-custom-instance"
            }
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "main-container",
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
        // User's service.instance.id should be preserved
        expect(otelResourceAttributes!.value).toContain("service.instance.id=user-custom-instance");
        expect(otelResourceAttributes!.value).not.toContain("service.instance.id=$(POD_NAME)");
        // Our service.name should be added since user didn't provide it
        expect(otelResourceAttributes!.value).toContain("service.name=test-app");
    });

    it("should preserve both user's service.name and service.instance.id when provided", () => {
        const existingEnvironmentVariables: Record<string, IEnvironmentVariable> = {
            "OTEL_RESOURCE_ATTRIBUTES": {
                name: "OTEL_RESOURCE_ATTRIBUTES",
                value: "service.name=user-service,service.instance.id=user-instance,custom.attr=value"
            }
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "main-container",
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
        // Both user values should be preserved
        expect(otelResourceAttributes!.value).toContain("service.name=user-service");
        expect(otelResourceAttributes!.value).toContain("service.instance.id=user-instance");
        expect(otelResourceAttributes!.value).not.toContain("service.name=test-app");
        expect(otelResourceAttributes!.value).not.toContain("service.instance.id=$(POD_NAME)");
        // User's custom attribute should also be preserved
        expect(otelResourceAttributes!.value).toContain("custom.attr=value");
        // Our other attributes should still be added
        expect(otelResourceAttributes!.value).toContain("cloud.provider=Azure");
        expect(otelResourceAttributes!.value).toContain("k8s.cluster.name=test-cluster");
    });

    it("should include service.name and service.instance.id when user doesn't provide them", () => {
        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "main-container",
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
        // service.name should be set to owner name (test-app)
        expect(otelResourceAttributes!.value).toContain("service.name=test-app");
        // service.instance.id should be set to $(POD_NAME)
        expect(otelResourceAttributes!.value).toContain("service.instance.id=$(POD_NAME)");
    });
});

describe("OTEL Metrics Exporter Environment Variable", () => {
    const podInfo = new PodInfo();
    podInfo.ownerKind = "Deployment";
    podInfo.ownerName = "test-app";
    podInfo.ownerUid = "uid-123";

    it("should include OTEL_METRICS_EXPORTER when metrics are enabled", () => {
        const testOtelParams: OtelParams = {
            logsEnabled: false,
            metricsEnabled: true,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "main-container",
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
        expect(otelMetricsExporter!.value).toBe("otlp");

        const otelMetricsTemporality = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE");
        expect(otelMetricsTemporality).toBeDefined();
        expect(otelMetricsTemporality!.value).toBe("delta");

        const otelMetricsHistogram = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_DEFAULT_HISTOGRAM_AGGREGATION");
        expect(otelMetricsHistogram).toBeDefined();
        expect(otelMetricsHistogram!.value).toBe("base2_exponential_bucket_histogram");
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
            "main-container",
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

        const otelMetricsTemporality = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE");
        expect(otelMetricsTemporality).toBeUndefined();

        const otelMetricsHistogram = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_DEFAULT_HISTOGRAM_AGGREGATION");
        expect(otelMetricsHistogram).toBeUndefined();
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
            "main-container",
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
        expect(otelMetricsExporter!.value).toBe("otlp");

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

        const otelMetricsTemporality = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE");
        expect(otelMetricsTemporality).toBeDefined();
        expect(otelMetricsTemporality!.value).toBe("delta");

        const otelMetricsHistogram = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_DEFAULT_HISTOGRAM_AGGREGATION");
        expect(otelMetricsHistogram).toBeDefined();
        expect(otelMetricsHistogram!.value).toBe("base2_exponential_bucket_histogram");
    });

    it("should use customer's values for OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE and OTEL_EXPORTER_OTLP_METRICS_DEFAULT_HISTOGRAM_AGGREGATION when they exist", () => {
        const testOtelParamsWithMetrics: OtelParams = {
            logsEnabled: false,
            metricsEnabled: true,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };

        const existingEnvironmentVariables: Record<string, IEnvironmentVariable> = {
            "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE": {
                name: "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE",
                value: "cumulative"
            },
            "OTEL_EXPORTER_OTLP_METRICS_DEFAULT_HISTOGRAM_AGGREGATION": {
                name: "OTEL_EXPORTER_OTLP_METRICS_DEFAULT_HISTOGRAM_AGGREGATION",
                value: "explicit_bucket_histogram"
            }
        };

        const generatedEnvVars = Mutations.GenerateEnvironmentVariables(
            podInfo,
            "main-container",
            [AutoInstrumentationPlatforms.Java],
            false,
            "InstrumentationKey=test-key",
            "/subscriptions/test/resourceGroups/test-rg",
            "eastus",
            "test-cluster",
            testOtelParamsWithMetrics,
            existingEnvironmentVariables
        );

        // Should use customer's value for temporality preference
        const otelMetricsTemporality = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE");
        expect(otelMetricsTemporality).toBeDefined();
        expect(otelMetricsTemporality!.value).toBe("cumulative"); // customer's value

        // Should use customer's value for histogram aggregation
        const otelMetricsHistogram = generatedEnvVars.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_DEFAULT_HISTOGRAM_AGGREGATION");
        expect(otelMetricsHistogram).toBeDefined();
        expect(otelMetricsHistogram!.value).toBe("explicit_bucket_histogram"); // customer's value
    });
});
