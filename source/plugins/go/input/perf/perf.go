package main

import (
	"Docker-Provider/source/plugins/go/input/lib"
	"Docker-Provider/source/plugins/go/src/extension"
	"context"
	"errors"
	"log"
	"math"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/calyptia/plugin"
)

// Plugin needs to be registered as an input type plugin in the initialisation phase
func init() {
	plugin.RegisterInput("perf", "fluent-bit input plugin for cadvisor perf", &perfPlugin{})
}

type perfPlugin struct {
	tag                string
	insightsmetricstag string
	runInterval        int
}

var (
	FLBLogger                 *log.Logger
	namespaceFilteringMode    = "off"
	namespaces                []string
	addonTokenAdapterImageTag = ""
	agentConfigRefreshTracker = time.Now().Unix()
	tag                       = "oneagent.containerInsights.LINUX_PERF_BLOB"
	insightsmetricstag        = "oneagent.containerInsights.INSIGHTS_METRICS_BLOB"
	runInterval               = 60
	containerType             = os.Getenv("CONTAINER_TYPE")
	hostName                  = ""
	isWindows                 = false
	telemetryTimeTracker      = time.Now().Unix()
	isFromCache               = false
)

// Init An instance of the configuration loader will be passed to the Init method so all the required
// configuration entries can be retrieved within the plugin context.
func (p *perfPlugin) Init(ctx context.Context, fbit *plugin.Fluentbit) error {
	if fbit.Conf.String("tag") == "" {
		p.tag = tag
	} else {
		p.tag = fbit.Conf.String("tag")
	}
	if fbit.Conf.String("run_interval") == "" {
		p.runInterval = runInterval
	} else {
		p.runInterval, _ = strconv.Atoi(fbit.Conf.String("run_interval"))
	}
	if fbit.Conf.String("insightsmetricstag") == "" {
		p.insightsmetricstag = insightsmetricstag
	} else {
		p.insightsmetricstag = fbit.Conf.String("insightsmetricstag")
	}

	osType := os.Getenv("OS_TYPE")
	if strings.EqualFold(osType, "windows") {
		FLBLogger = lib.CreateLogger("/etc/amalogswindows/fluent-bit-input.log")
	} else {
		FLBLogger = lib.CreateLogger("/var/opt/microsoft/docker-cimprov/log/fluent-bit-input.log")
	}
	return nil
}

// Collect this method will be invoked by the fluent-bit engine after the initialisation is successful
// this method can lock as each plugin its implemented in its own thread. Be aware that the main context
// can be cancelled at any given time, so handle the context properly within this method.
// The *ch* channel parameter, is a channel handled by the runtime that will receive messages from the plugin
// collection, make sure to validate channel closure and to follow the `plugin.Message` struct for messages
// generated by plugins.
func (p perfPlugin) Collect(ctx context.Context, ch chan<- plugin.Message) error {
	tick := time.NewTicker(time.Duration(p.runInterval) * time.Second)

	for {
		select {
		case <-ctx.Done():
			err := ctx.Err()
			if err != nil && !errors.Is(err, context.Canceled) {
				return err
			}

			return nil
		case <-tick.C:
			emitTime := time.Now()
			FLBLogger.Print("perf::enumerate.start @ ", time.Now().UTC().Format(time.RFC3339))
			perfmessages, insightsmetricsmessages := p.enumerate()
			FLBLogger.Print("perf::enumerate.end @ ", time.Now().UTC().Format(time.RFC3339))

			ch <- plugin.Message{
				Record: map[string]any{
					"tag":      tag,
					"messages": perfmessages,
				},
				Time: emitTime,
			}
			FLBLogger.Print("perf::emitted ", len(perfmessages), " perf records @ ", time.Now().UTC().Format(time.RFC3339))
			ch <- plugin.Message{
				Record: map[string]any{
					"tag":      insightsmetricstag,
					"messages": insightsmetricsmessages,
				},
				Time: emitTime,
			}

			FLBLogger.Print("perf::emitted ", len(insightsmetricsmessages), " insights metrics records @ ", time.Now().UTC().Format(time.RFC3339))

			timeDifference := int(math.Abs(float64(time.Now().Unix() - telemetryTimeTracker)))
			timeDifferenceInMinutes := timeDifference / 60

			if timeDifferenceInMinutes >= 5 {
				telemetryTimeTracker = time.Now().Unix()
				telemetryProperties := map[string]string{}
				telemetryProperties["Computer"] = hostName
				telemetryProperties["ContainerCount"] = strconv.Itoa(len(perfmessages))
				if addonTokenAdapterImageTag != "" {
					telemetryProperties["addonTokenAdapterImageTag"] = addonTokenAdapterImageTag
				}
				lib.SendTelemetry("Perf", telemetryProperties)
			}
		}
	}
}

func (p perfPlugin) enumerate() ([]map[string]interface{}, []map[string]interface{}) {
	currentTime := time.Now()
	batchTime := currentTime.UTC().Format(time.RFC3339)
	hostName = ""
	namespaceFilteringMode = "off"
	namespaces = []string{}
	eventStream := []map[string]interface{}{}
	insightsMetricsEventStream := []map[string]interface{}{}
	osType := strings.TrimSpace(os.Getenv("OS_TYPE"))
	if strings.EqualFold(osType, "windows") {
		isWindows = true
	}
	tag = p.tag
	insightsmetricstag = p.insightsmetricstag

	FLBLogger.Printf("perf::enumerate : Begin processing @ %s", time.Now().UTC().Format(time.RFC3339))

	if lib.IsAADMSIAuthMode() {
		FLBLogger.Print("perf::enumerate: AAD AUTH MSI MODE")
		e := extension.GetInstance(FLBLogger, containerType)

		tag, isFromCache = lib.GetOutputStreamIdAndSource(e, lib.PerfDataType, tag, agentConfigRefreshTracker)
		if !isFromCache {
			agentConfigRefreshTracker = time.Now().Unix()
		}
		insightsmetricstag, _ = lib.GetOutputStreamIdAndSource(e, lib.InsightsMetricsDataType, insightsmetricstag, agentConfigRefreshTracker)

		if !lib.IsDCRStreamIdTag(tag) {
			FLBLogger.Print("WARN::perf::enumerate: skipping Microsoft-Perf stream since its opted-out @", time.Now().UTC().Format(time.RFC3339))
		}

		if !lib.IsDCRStreamIdTag(insightsmetricstag) {
			FLBLogger.Print("WARN::perf::enumerate: skipping Microsoft-InsightsMetrics stream since its opted-out @", time.Now().UTC().Format(time.RFC3339))
		}

		if e.IsDataCollectionSettingsConfigured() {
			runInterval := e.GetDataCollectionIntervalSeconds()
			FLBLogger.Print("perf::enumerate: using data collection interval(seconds):", runInterval, "@", time.Now().UTC().Format(time.RFC3339))

			namespaces := e.GetNamespacesForDataCollection()
			FLBLogger.Print("perf::enumerate: using data collection namespaces:", namespaces, "@", time.Now().UTC().Format(time.RFC3339))

			namespaceFilteringMode := e.GetNamespaceFilteringModeForDataCollection()
			FLBLogger.Print("perf::enumerate: using data collection filtering mode for namespaces:", namespaceFilteringMode, "@", time.Now().UTC().Format(time.RFC3339))
		}
	}

	metricData := lib.GetMetrics(nil, namespaceFilteringMode, namespaces, batchTime)
	for _, metricDataItem := range metricData {
		eventStream = append(eventStream, metricDataItem)
	}

	isTestVar := os.Getenv("ISTEST")
	if strings.ToLower(isTestVar) == "true" && len(eventStream) > 0 {
		FLBLogger.Printf("perf::enumerate: cAdvisorPerfEmitStreamSuccess @ %s", time.Now().UTC().Format(time.RFC3339))
	}

	if !isWindows {
		containerGPUusageInsightsMetricsDataItems := lib.GetInsightsMetrics(nil, namespaceFilteringMode, namespaces, batchTime)
		for _, containerGPUusageInsightsMetricsDataItem := range containerGPUusageInsightsMetricsDataItems {
			insightsMetricsEventStream = append(insightsMetricsEventStream, containerGPUusageInsightsMetricsDataItem)
		}
		if strings.ToLower(isTestVar) == "true" && len(eventStream) > 0 {
			FLBLogger.Printf("perf::enumerate: cAdvisorInsightsMetricsEmitStreamSuccess @ %s", time.Now().UTC().Format(time.RFC3339))
		}
	}

	return eventStream, insightsMetricsEventStream
}

func main() {}
