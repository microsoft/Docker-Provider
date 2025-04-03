package main

import (
	"Docker-Provider/source/plugins/go/input/lib"
	"context"
	"errors"
	"log"
	"math"
	"os"
	"strconv"
	"time"

	"github.com/calyptia/plugin"
)

func init() {
	plugin.RegisterInput("disk-test", "fluent-bit input plugin for disk data", &diskPlugin{})
}

type diskPlugin struct {
	tag         string
	runInterval int
}

var (
	FLBLogger            *log.Logger
	tag                  = "oneagent.containerInsights.DISK_BLOB"
	runInterval          = 60
	diskTelemetryTracker = time.Now().Unix()
	osType               = os.Getenv("OS_TYPE")
)

func (p *diskPlugin) Init(ctx context.Context, fbit *plugin.Fluentbit) error {
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

	logPath := "/var/opt/microsoft/docker-cimprov/log/fluent-bit-disk.log"
	isTestEnv := os.Getenv("GOUNITTEST") == "true"
	if isTestEnv {
		logPath = "./fluent-bit-disk-test.log"
	}

	FLBLogger = lib.CreateLogger(logPath)
	return nil
}

func (p diskPlugin) Collect(ctx context.Context, ch chan<- plugin.Message) error {
	tick := time.NewTicker(time.Duration(p.runInterval) * time.Second)

	for {
		select {
		case <-ctx.Done():
			if err := ctx.Err(); err != nil && !errors.Is(err, context.Canceled) {
				return err
			}
			return nil
		case <-tick.C:
			emitTime := time.Now()
			FLBLogger.Print("disk::collect.start @ ", time.Now().UTC().Format(time.RFC3339))
			diskData, err := lib.GetDiskUsage([]string{}, []string{}, []string{})
			if err != nil {
				FLBLogger.Print("disk::error @ ", err)
				continue
			}

			for _, data := range diskData {
				FLBLogger.Printf("disk::data: %v", data)
			}

			ch <- plugin.Message{
				Record: map[string]any{
					"tag":      p.tag,
					"messages": diskData,
				},
				Time: emitTime,
			}

			FLBLogger.Print("disk::emitted ", len(diskData), " disk records @ ", time.Now().UTC().Format(time.RFC3339))

			timeDifference := int(math.Abs(float64(time.Now().Unix() - diskTelemetryTracker)))
			if timeDifference >= 300 {
				diskTelemetryTracker = time.Now().Unix()
				telemetryProperties := map[string]string{
					"DiskRecordCount": strconv.Itoa(len(diskData)),
				}
				lib.SendTelemetry("Disk", telemetryProperties)
			}
		}
	}
}

func main() {}
