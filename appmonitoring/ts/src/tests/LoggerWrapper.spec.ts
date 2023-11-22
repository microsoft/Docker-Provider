import { expect, describe, it } from "@jest/globals";
import { logger, HeartbeatMetrics, HeartbeatLogs } from "../LoggerWrapper.js";
import { TelemetryClient } from "applicationinsights";
import { MetricTelemetry, TraceTelemetry } from "applicationinsights/out/Declarations/Contracts";

afterEach(() => {
    jest.restoreAllMocks();
});

describe("Heartbeats", () => {
    it("Sends logs", async () => {
        for(let i = 0; i < 10; i++) {
            logger.AppendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-10");
        }

        for(let i = 0; i < 100; i++) {
            logger.AppendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-100");
        }

        for(let i = 0; i < 25; i++) {
            logger.AppendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-25");
        }

        for(let i = 0; i < 5; i++) {
            logger.AppendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-5");
        }

        for(let i = 0; i < 120; i++) {
            logger.AppendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-120");
        }

        for(let i = 0; i < 75; i++) {
            logger.AppendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-75");
        }
        
        const tracesSent = <TraceTelemetry[]>[];

        jest.spyOn(TelemetryClient.prototype, "trackTrace").mockImplementation((telemetry: TraceTelemetry) => {
            tracesSent.push(telemetry);
        });

        await logger.StartHeartbeats(null, { isCancelled: true });
       
        expect(tracesSent.length).toBe(5);
        expect(tracesSent[0].message).toBe("blah-blah-blah-120");
        expect(tracesSent[1].message).toBe("blah-blah-blah-100");
        expect(tracesSent[2].message).toBe("blah-blah-blah-75");
        expect(tracesSent[3].message).toBe("blah-blah-blah-25");
        expect(tracesSent[4].message).toBe("blah-blah-blah-10");
    });

    it("Sends metrics", async () => {
        logger.AddHeartbeatMetric(HeartbeatMetrics.CRCount, 2);
        logger.AddHeartbeatMetric(HeartbeatMetrics.CRCount, 3);
        
        const metricsSent = <MetricTelemetry[]>[];

        jest.spyOn(TelemetryClient.prototype, "trackMetric").mockImplementation((telemetry: MetricTelemetry) => {
            metricsSent.push(telemetry);
        });

        await logger.StartHeartbeats(null, { isCancelled: true });
        
        expect(metricsSent.length).toBe(1);
        expect(metricsSent[0].name).toBe(HeartbeatMetrics[HeartbeatMetrics.CRCount]);
    });
});