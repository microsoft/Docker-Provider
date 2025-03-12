import { expect, describe, it } from "@jest/globals";
import { logger, HeartbeatMetrics, HeartbeatLogs, Watchdogs } from "../LoggerWrapper.js";
import * as applicationInsights from "applicationinsights";

beforeEach(() => {
    logger.setUnitTestMode(true);
});

afterEach(() => {
    jest.restoreAllMocks();
});

describe("Heartbeats", () => {
    it("Sends logs", async () => {
        for(let i = 0; i < 10; i++) {
            logger.appendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-10");
        }

        for(let i = 0; i < 100; i++) {
            logger.appendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-100");
        }

        for(let i = 0; i < 25; i++) {
            logger.appendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-25");
        }

        for(let i = 0; i < 5; i++) {
            logger.appendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-5");
        }

        for(let i = 0; i < 120; i++) {
            logger.appendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-120");
        }

        for(let i = 0; i < 75; i++) {
            logger.appendHeartbeatLog(HeartbeatLogs.CertificateOperations, "blah-blah-blah-75");
        }
        
        const tracesSent = <applicationInsights.Contracts.TraceTelemetry[]>[];

        jest.spyOn(applicationInsights.TelemetryClient.prototype, "trackTrace").mockImplementation((telemetry: applicationInsights.Contracts.TraceTelemetry) => {
            tracesSent.push(telemetry);
        });

        await logger.startHeartbeats(null);
       
        expect(tracesSent.length).toBe(5);
        expect(tracesSent[0].message).toBe("blah-blah-blah-120");
        expect(tracesSent[1].message).toBe("blah-blah-blah-100");
        expect(tracesSent[2].message).toBe("blah-blah-blah-75");
        expect(tracesSent[3].message).toBe("blah-blah-blah-25");
        expect(tracesSent[4].message).toBe("blah-blah-blah-10");
    });

    it("Sends metrics", async () => {
        logger.addHeartbeatMetric(HeartbeatMetrics.CRCount, 2);
        logger.addHeartbeatMetric(HeartbeatMetrics.CRCount, 3);

        logger.addHeartbeatMetric(HeartbeatMetrics.InstrumentedNamespaceCount, 2);
        logger.setHeartbeatMetric(HeartbeatMetrics.InstrumentedNamespaceCount, 1);
        
        const metricsSent = <applicationInsights.Contracts.MetricTelemetry & applicationInsights.Contracts.MetricPointTelemetry[]>[];

        jest.spyOn(applicationInsights.TelemetryClient.prototype, "trackMetric").mockImplementation((telemetry: applicationInsights.Contracts.MetricTelemetry & applicationInsights.Contracts.MetricPointTelemetry) => {
            metricsSent.push(telemetry);
        });

        await logger.startHeartbeats(null);
        
        expect(metricsSent.length).toBe(2);

        expect(metricsSent[0].name).toBe(HeartbeatMetrics[HeartbeatMetrics.CRCount]);
        expect(metricsSent[0].value).toBe(5);
        expect(metricsSent[0].count).toBe(1);

        expect(metricsSent[1].name).toBe(HeartbeatMetrics[HeartbeatMetrics.InstrumentedNamespaceCount]);
        expect(metricsSent[1].value).toBe(1);
        expect(metricsSent[1].count).toBe(1);
    });

    it("Sends metrics with dimensions", async () => {
        logger.addHeartbeatMetric(HeartbeatMetrics.CRsListCallFailedCount, 2, "405");
        logger.addHeartbeatMetric(HeartbeatMetrics.CRsListCallFailedCount, 3, "405");

        logger.addHeartbeatMetric(HeartbeatMetrics.CRsListCallFailedCount, 3, "407");
        logger.addHeartbeatMetric(HeartbeatMetrics.CRsListCallFailedCount, 4, "407");

        logger.addHeartbeatMetric(HeartbeatMetrics.CRsWatchCallFailedCount, 2, "403");
        logger.setHeartbeatMetric(HeartbeatMetrics.CRsWatchCallFailedCount, 3, "403");
        
        const metricsSent = <applicationInsights.Contracts.MetricTelemetry & applicationInsights.Contracts.MetricPointTelemetry[]>[];

        jest.spyOn(applicationInsights.TelemetryClient.prototype, "trackMetric").mockImplementation((telemetry: applicationInsights.Contracts.MetricTelemetry & applicationInsights.Contracts.MetricPointTelemetry) => {
            metricsSent.push(telemetry);
        });

        await logger.startHeartbeats(null);
        
        expect(metricsSent.length).toBe(3);

        expect(metricsSent[0].name).toBe(HeartbeatMetrics[HeartbeatMetrics.CRsListCallFailedCount]);
        expect((<applicationInsights.Contracts.Telemetry>metricsSent[0]).properties["dimension1"]).toBe("405");
        expect(metricsSent[0].value).toBe(5);
        expect(metricsSent[0].count).toBe(1);

        expect(metricsSent[1].name).toBe(HeartbeatMetrics[HeartbeatMetrics.CRsListCallFailedCount]);
        expect((<applicationInsights.Contracts.Telemetry>metricsSent[1]).properties["dimension1"]).toBe("407");
        expect(metricsSent[1].value).toBe(7);
        expect(metricsSent[1].count).toBe(1);

        expect(metricsSent[2].name).toBe(HeartbeatMetrics[HeartbeatMetrics.CRsWatchCallFailedCount]);
        expect((<applicationInsights.Contracts.Telemetry>metricsSent[2]).properties["dimension1"]).toBe("403");
        expect(metricsSent[2].value).toBe(3);
        expect(metricsSent[2].count).toBe(1);
    });

    it("Sends watchgdogs", async () => {
        let watchdogReport = 1024.3;

        logger.registerWatchdog(Watchdogs.SecondsSinceLastSuccessfulCRList, () => watchdogReport);
        
        const metricsSent = <applicationInsights.Contracts.MetricTelemetry & applicationInsights.Contracts.MetricPointTelemetry[]>[];
        
        jest.spyOn(applicationInsights.TelemetryClient.prototype, "trackMetric").mockImplementation((telemetry: applicationInsights.Contracts.MetricTelemetry & applicationInsights.Contracts.MetricPointTelemetry) => {
            metricsSent.push(telemetry);
        });

        await logger.startHeartbeats(null);

        watchdogReport = 1025.2;
        await logger.startHeartbeats(null);
        
        expect(metricsSent.length).toBe(2);

        expect(metricsSent[0].name).toBe(Watchdogs[Watchdogs.SecondsSinceLastSuccessfulCRList]);
        expect(metricsSent[0].value).toBe(1024.3);
        expect(metricsSent[0].count).toBe(1);
        
        expect(metricsSent[1].name).toBe(Watchdogs[Watchdogs.SecondsSinceLastSuccessfulCRList]);
        expect(metricsSent[1].value).toBe(1025.2);
        expect(metricsSent[1].count).toBe(1);    
    });
});