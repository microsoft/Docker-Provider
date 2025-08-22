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
