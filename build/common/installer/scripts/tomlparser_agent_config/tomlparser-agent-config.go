package tomlparser_agent_config

import (
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"

	"github.com/pelletier/go-toml"
)

// Global variables matching Ruby script
var (
	osType                 = os.Getenv("OS_TYPE")
	configMapMountPath     = "/etc/config/settings/agent-settings"
	configSchemaVersion    = ""
	controllerType         = os.Getenv("CONTROLLER_TYPE")
	daemonset              = "daemonset"
	containerType          = os.Getenv("CONTAINER_TYPE")
	containerMemoryLimitInBytes = os.Getenv("CONTAINER_MEMORY_LIMIT_IN_BYTES")

	// Chunk sizes
	nodesChunkSize          = 250
	podsChunkSize           = 1000
	eventsChunkSize         = 4000
	deploymentsChunkSize    = 500
	hpaChunkSize            = 2000
	podsEmitStreamBatchSize = 200
	nodesEmitStreamBatchSize = 100

	// Chunk size limits
	nodesChunkSizeMin       = 100
	nodesChunkSizeMax       = 400
	podsChunkSizeMin        = 10
	podsChunkSizeMax        = 1500
	eventsChunkSizeMin      = 2000
	eventsChunkSizeMax      = 10000
	deploymentsChunkSizeMin = 500
	deploymentsChunkSizeMax = 1000
	hpaChunkSizeMin         = 500
	hpaChunkSizeMax         = 2000

	// Emit stream size limits
	podsEmitStreamBatchSizeMin  = 50
	nodesEmitStreamBatchSizeMin = 50

	// Fluent bit config
	enableFbitInternalMetrics   = false
	fbitFlushIntervalSecs       = 0
	fbitTailBufferChunkSizeMBs  = 0
	fbitTailBufferMaxSizeMBs    = 0
	fbitTailMemBufLimitMBs      = 0
	fbitTailIgnoreOlder         = ""
	storageTotalLimitSizeMB     = 200
	outputForwardWorkers        = 10
	outputForwardRetryLimit     interface{} = 30
	requireAckResponse          = "false"
	fbitStorageMaxChunksUp      = 0
	fbitStorageType             = ""
	enableFluentBitThreading    = false

	// MDSD config
	mdsdMonitoringMaxEventRate     = 0
	mdsdUploadMaxSizeInMB          = 0
	mdsdUploadFrequencyInSeconds   = 0
	mdsdBackPressureThresholdInMB  = 0
	mdsdCompressionLevel           = -1

	// Prometheus fluent bit config
	promFbitChunkSize           = 0
	promFbitBufferSize          = 0
	promFbitMemBufLimit         = 0
	promFbitChunkSizeDefault    = "32k"
	promFbitBufferSizeDefault   = "64k"
	promFbitMemBufLimitDefault  = "10m"

	// Proxy settings
	ignoreProxySettings = false

	// Multiline settings
	multilineEnabled = "false"

	// Network listener wait times
	waittimePort25226 = 45
	waittimePort25228 = 120
	waittimePort25229 = 45
	waittimePort13000 = 45
	waittimePort12563 = 45

	// Network flow logs throttling
	networkFlowLogsThrottleEnabled  = true
	networkFlowLogsThrottleRate     = 5000
	networkFlowLogsThrottleWindow   = 300
	networkFlowLogsThrottleInterval = "1s"
	networkFlowLogsThrottlePrint    = false
)

func isNumber(value string) bool {
	_, err := strconv.Atoi(value)
	return err == nil
}

func isValidNumber(value interface{}) bool {
	switch v := value.(type) {
	case string:
		if v == "" {
			return false
		}
		num, err := strconv.Atoi(v)
		return err == nil && num > 0
	case int64:
		return v > 0
	case int:
		return v > 0
	default:
		return false
	}
}

func isValidWaittime(value interface{}, defaultVal int) bool {
	switch v := value.(type) {
	case string:
		if v == "" {
			return false
		}
		num, err := strconv.Atoi(v)
		return err == nil && num >= defaultVal/2 && num <= 3*defaultVal
	case int64:
		return int(v) >= defaultVal/2 && int(v) <= 3*defaultVal
	case int:
		return v >= defaultVal/2 && v <= 3*defaultVal
	default:
		return false
	}
}

func getIntValue(value interface{}) int {
	switch v := value.(type) {
	case int64:
		return int(v)
	case int:
		return v
	case string:
		if num, err := strconv.Atoi(v); err == nil {
			return num
		}
	}
	return 0
}

func getBoolValue(value interface{}) bool {
	switch v := value.(type) {
	case bool:
		return v
	case string:
		return strings.ToLower(v) == "true"
	}
	return false
}

func logError(message string) {
	// In Ruby this calls ConfigParseErrorLogger.logError
	// For now, we'll just print to stderr
	fmt.Fprintf(os.Stderr, "config::error:%s\n", message)
}

func parseConfigMap() (*toml.Tree, error) {
	if _, err := os.Stat(configMapMountPath); err == nil {
		fmt.Println("config::configmap container-azm-ms-agentconfig for agent settings mounted, parsing values")
		parsedConfig, err := toml.LoadFile(configMapMountPath)
		if err != nil {
			logError(fmt.Sprintf("Exception while parsing config map for agent settings : %v, using defaults, please check config map for errors", err))
			return nil, err
		}
		fmt.Println("config::Successfully parsed mounted config map")
		return parsedConfig, nil
	} else {
		fmt.Println("config::configmap container-azm-ms-agentconfig for agent settings not mounted, using defaults")
		return nil, nil
	}
}

func populateSettingValuesFromConfigMap(parsedConfig *toml.Tree) {
	if parsedConfig == nil {
		return
	}

	agentSettings := parsedConfig.Get("agent_settings")
	if agentSettings == nil {
		return
	}

	settings, ok := agentSettings.(*toml.Tree)
	if !ok {
		return
	}

	// Chunk config
	if chunkConfig := settings.Get("chunk_config"); chunkConfig != nil {
		if chunk, ok := chunkConfig.(*toml.Tree); ok {
			// Nodes chunk size
			if v := chunk.Get("NODES_CHUNK_SIZE"); v != nil {
				val := getIntValue(v)
				if val >= nodesChunkSizeMin && val <= nodesChunkSizeMax {
					nodesChunkSize = val
					fmt.Printf("Using config map value: NODES_CHUNK_SIZE = %d\n", nodesChunkSize)
				}
			}

			// Pods chunk size
			if v := chunk.Get("PODS_CHUNK_SIZE"); v != nil {
				val := getIntValue(v)
				if val >= podsChunkSizeMin && val <= podsChunkSizeMax {
					podsChunkSize = val
					fmt.Printf("Using config map value: PODS_CHUNK_SIZE = %d\n", podsChunkSize)
				}
			}

			// Events chunk size
			if v := chunk.Get("EVENTS_CHUNK_SIZE"); v != nil {
				val := getIntValue(v)
				if val >= eventsChunkSizeMin && val <= eventsChunkSizeMax {
					eventsChunkSize = val
					fmt.Printf("Using config map value: EVENTS_CHUNK_SIZE = %d\n", eventsChunkSize)
				}
			}

			// Deployments chunk size
			if v := chunk.Get("DEPLOYMENTS_CHUNK_SIZE"); v != nil {
				val := getIntValue(v)
				if val >= deploymentsChunkSizeMin && val <= deploymentsChunkSizeMax {
					deploymentsChunkSize = val
					fmt.Printf("Using config map value: DEPLOYMENTS_CHUNK_SIZE = %d\n", deploymentsChunkSize)
				}
			}

			// HPA chunk size
			if v := chunk.Get("HPA_CHUNK_SIZE"); v != nil {
				val := getIntValue(v)
				if val >= hpaChunkSizeMin && val <= hpaChunkSizeMax {
					hpaChunkSize = val
					fmt.Printf("Using config map value: HPA_CHUNK_SIZE = %d\n", hpaChunkSize)
				}
			}

			// Pods emit stream batch size
			if v := chunk.Get("PODS_EMIT_STREAM_BATCH_SIZE"); v != nil {
				val := getIntValue(v)
				if val <= podsChunkSize && val >= podsEmitStreamBatchSizeMin {
					podsEmitStreamBatchSize = val
					fmt.Printf("Using config map value: PODS_EMIT_STREAM_BATCH_SIZE = %d\n", podsEmitStreamBatchSize)
				}
			}

			// Nodes emit stream batch size
			if v := chunk.Get("NODES_EMIT_STREAM_BATCH_SIZE"); v != nil {
				val := getIntValue(v)
				if val <= nodesChunkSize && val >= nodesEmitStreamBatchSizeMin {
					nodesEmitStreamBatchSize = val
					fmt.Printf("Using config map value: NODES_EMIT_STREAM_BATCH_SIZE = %d\n", nodesEmitStreamBatchSize)
				}
			}
		}
	}

	// Network flow logs config
	if networkflowLogsConfig := settings.Get("networkflow_logs_config"); networkflowLogsConfig != nil {
		if nfConfig, ok := networkflowLogsConfig.(*toml.Tree); ok {
			if v := nfConfig.Get("throttle_enabled"); v != nil {
				networkFlowLogsThrottleEnabled = getBoolValue(v)
				fmt.Printf("Using config map value: networkflow logs throttle_enabled = %v\n", networkFlowLogsThrottleEnabled)
			}

			if networkFlowLogsThrottleEnabled {
				if v := nfConfig.Get("throttle_rate"); v != nil && isValidNumber(v) {
					val := getIntValue(v)
					if val >= 1 && val <= 25000 {
						networkFlowLogsThrottleRate = val
						fmt.Printf("Using config map value: networkflow logs throttle_rate = %d\n", networkFlowLogsThrottleRate)
					} else {
						fmt.Printf("config::warn: provided networkflow logs throttle_rate value is not valid, using default value %d\n", networkFlowLogsThrottleRate)
					}
				}

				if v := nfConfig.Get("throttle_window"); v != nil && isValidNumber(v) {
					val := getIntValue(v)
					if val >= 1 {
						networkFlowLogsThrottleWindow = val
						fmt.Printf("Using config map value: networkflow logsthrottle_window = %d\n", networkFlowLogsThrottleWindow)
					} else {
						fmt.Printf("config::warn: provided networkflow logs throttle_window value is not valid, using default value %d\n", networkFlowLogsThrottleWindow)
					}
				}

				if v := nfConfig.Get("throttle_interval"); v != nil {
					if strVal, ok := v.(string); ok && strVal != "" {
						re := regexp.MustCompile(`^\d+(\.\d+)?[smh]$`)
						if re.MatchString(strVal) {
							networkFlowLogsThrottleInterval = strVal
							fmt.Printf("Using config map value: networkflow logs throttle_interval = %s\n", networkFlowLogsThrottleInterval)
						} else {
							fmt.Printf("config::warn: provided networkflow logs throttle_interval value '%s' is not valid, using default value %s\n", strVal, networkFlowLogsThrottleInterval)
						}
					}
				}

				if v := nfConfig.Get("throttle_print"); v != nil {
					networkFlowLogsThrottlePrint = getBoolValue(v)
					fmt.Printf("Using config map value: networkflow logs throttle_print = %v\n", networkFlowLogsThrottlePrint)
				}
			}
		}
	}

	// Fluent bit config
	if fbitConfig := settings.Get("fbit_config"); fbitConfig != nil {
		if fbit, ok := fbitConfig.(*toml.Tree); ok {
			if v := fbit.Get("log_flush_interval_secs"); v != nil && isValidNumber(v) {
				fbitFlushIntervalSecs = getIntValue(v)
				fmt.Printf("Using config map value: log_flush_interval_secs = %d\n", fbitFlushIntervalSecs)
			}

			if v := fbit.Get("tail_buf_chunksize_megabytes"); v != nil && isValidNumber(v) {
				fbitTailBufferChunkSizeMBs = getIntValue(v)
				fmt.Printf("Using config map value: tail_buf_chunksize_megabytes  = %d\n", fbitTailBufferChunkSizeMBs)
			}

			if v := fbit.Get("tail_buf_maxsize_megabytes"); v != nil && isValidNumber(v) {
				val := getIntValue(v)
				if val >= fbitTailBufferChunkSizeMBs {
					fbitTailBufferMaxSizeMBs = val
					fmt.Printf("Using config map value: tail_buf_maxsize_megabytes = %d\n", fbitTailBufferMaxSizeMBs)
				} else {
					fbitTailBufferMaxSizeMBs = fbitTailBufferChunkSizeMBs
					fmt.Printf("config::warn: tail_buf_maxsize_megabytes must be greater or equal to value of tail_buf_chunksize_megabytes. Using tail_buf_maxsize_megabytes = %d since provided config value not valid\n", fbitTailBufferMaxSizeMBs)
				}
			}

			// Handle scenario where chunk size is provided but not max size
			if fbitTailBufferChunkSizeMBs > 0 && fbitTailBufferMaxSizeMBs == 0 {
				fbitTailBufferMaxSizeMBs = fbitTailBufferChunkSizeMBs
				fmt.Printf("config::warn: since tail_buf_maxsize_megabytes not provided hence using tail_buf_maxsize_megabytes=%d which is same as the value of tail_buf_chunksize_megabytes\n", fbitTailBufferMaxSizeMBs)
			}

			if v := fbit.Get("tail_mem_buf_limit_megabytes"); v != nil && isValidNumber(v) {
				fbitTailMemBufLimitMBs = getIntValue(v)
				fmt.Printf("Using config map value: tail_mem_buf_limit_megabytes  = %d\n", fbitTailMemBufLimitMBs)
			}

			if v := fbit.Get("tail_ignore_older"); v != nil {
				if strVal, ok := v.(string); ok && strVal != "" {
					re := regexp.MustCompile(`^[0-9]+[mhd]$`)
					if re.MatchString(strVal) {
						fbitTailIgnoreOlder = strVal
						fmt.Printf("Using config map value: tail_ignore_older  = %s\n", fbitTailIgnoreOlder)
					} else {
						fmt.Println("config:warn: provided tail_ignore_older value is not valid hence using default value")
					}
				}
			}

			if v := fbit.Get("enable_internal_metrics"); v != nil {
				if strVal, ok := v.(string); ok && strings.ToLower(strVal) == "true" {
					enableFbitInternalMetrics = true
					fmt.Printf("Using config map value: enable_internal_metrics = %v\n", enableFbitInternalMetrics)
				}
			}

			if v := fbit.Get("storage_max_chunks_up"); v != nil && isValidNumber(v) {
				fbitStorageMaxChunksUp = getIntValue(v)
				fmt.Printf("Using config map value: fbitStorageMaxChunksUp  = %d\n", fbitStorageMaxChunksUp)
			}

			if v := fbit.Get("storage_type"); v != nil {
				if strVal, ok := v.(string); ok && strVal != "" {
					if strVal == "memory" || strVal == "filesystem" {
						fbitStorageType = strVal
						fmt.Printf("Using config map value: fbitStorageType  = %s\n", fbitStorageType)
					}
				}
			}

			if v := fbit.Get("enable_threading"); v != nil {
				if strVal, ok := v.(string); ok && strings.ToLower(strings.TrimSpace(strVal)) == "true" {
					enableFluentBitThreading = true
					fmt.Printf("Using config map value: enableFluentBitThreading  = %v\n", enableFluentBitThreading)
				}
			}
		}
	}

	// Geneva tenant fluent bit settings
	if genevaConfig := settings.Get("geneva_tenant_fbit_settings"); genevaConfig != nil {
		if geneva, ok := genevaConfig.(*toml.Tree); ok {
			if v := geneva.Get("storage_total_limit_size_mb"); v != nil && isValidNumber(v) {
				storageTotalLimitSizeMB = getIntValue(v)
				fmt.Printf("Using config map value: storage_total_limit_size_mb = %d\n", storageTotalLimitSizeMB)
			}

			if v := geneva.Get("output_forward_workers"); v != nil && isValidNumber(v) {
				outputForwardWorkers = getIntValue(v)
				fmt.Printf("Using config map value: output_forward_workers = %d\n", outputForwardWorkers)
			}

			if v := geneva.Get("output_forward_retry_limit"); v != nil {
				switch val := v.(type) {
				case string:
					if isNumber(val) {
						num, _ := strconv.Atoi(val)
						if num > 0 {
							outputForwardRetryLimit = num
							fmt.Printf("Using config map value: output_forward_retry_limit = %d\n", num)
						}
					} else if val == "False" || val == "no_limits" || val == "no_retries" {
						outputForwardRetryLimit = val
						fmt.Printf("Using config map value: output_forward_retry_limit = %s\n", val)
					}
				case int64:
					if val > 0 {
						outputForwardRetryLimit = int(val)
						fmt.Printf("Using config map value: output_forward_retry_limit = %d\n", int(val))
					}
				}
			}

			if v := geneva.Get("require_ack_response"); v != nil {
				if strVal, ok := v.(string); ok && strings.ToLower(strVal) == "true" {
					requireAckResponse = strVal
					fmt.Printf("Using config map value: require_ack_response = %s\n", requireAckResponse)
				}
			}
		}
	}

	// MDSD config
	if mdsdConfig := settings.Get("mdsd_config"); mdsdConfig != nil {
		if mdsd, ok := mdsdConfig.(*toml.Tree); ok {
			// Only for daemonset and not prometheus sidecar
			if controllerType != "" && strings.EqualFold(strings.TrimSpace(controllerType), daemonset) && containerType == "" {
				if v := mdsd.Get("monitoring_max_event_rate"); v != nil && isValidNumber(v) {
					mdsdMonitoringMaxEventRate = getIntValue(v)
					fmt.Printf("Using config map value: monitoring_max_event_rate  = %d\n", mdsdMonitoringMaxEventRate)
				}

				if v := mdsd.Get("upload_max_size_in_mb"); v != nil && isValidNumber(v) {
					mdsdUploadMaxSizeInMB = getIntValue(v)
					fmt.Printf("Using config map value: upload_max_size_in_mb  = %d\n", mdsdUploadMaxSizeInMB)
				}

				if v := mdsd.Get("upload_frequency_seconds"); v != nil && isValidNumber(v) {
					mdsdUploadFrequencyInSeconds = getIntValue(v)
					fmt.Printf("Using config map value: upload_frequency_seconds  = %d\n", mdsdUploadFrequencyInSeconds)
				}

				if v := mdsd.Get("compression_level"); v != nil {
					val := getIntValue(v)
					if val >= 0 && val < 10 {
						mdsdCompressionLevel = val
						fmt.Printf("Using config map value: mdsdCompressionLevel = %d\n", mdsdCompressionLevel)
					} else {
						fmt.Println("Ignoring mdsd compression_level level since its not supported level. Check input values for correctness.")
					}
				}
			}

			if v := mdsd.Get("backpressure_memory_threshold_in_mb"); v != nil && isValidNumber(v) {
				val := getIntValue(v)
				containerLimitBytes, _ := strconv.Atoi(containerMemoryLimitInBytes)
				if containerLimitBytes > 0 && val < (containerLimitBytes/1048576) && val > 100 {
					mdsdBackPressureThresholdInMB = val
					fmt.Printf("Using config map value: backpressure_memory_threshold_in_mb  = %d\n", mdsdBackPressureThresholdInMB)
				} else {
					fmt.Printf("Ignoring mdsd backpressure limit. Check input values for correctness. Configmap value in mb: %d, container limit in bytes: %s\n", val, containerMemoryLimitInBytes)
				}
			}
		}
	}

	// Prometheus fluent bit config
	var promFbitConfig *toml.Tree
	if controllerType != "" && strings.EqualFold(strings.TrimSpace(controllerType), daemonset) && containerType == "" {
		promFbitConfig = settings.Get("node_prometheus_fbit_settings").(*toml.Tree)
	} else if controllerType != "" && !strings.EqualFold(strings.TrimSpace(controllerType), daemonset) {
		promFbitConfig = settings.Get("cluster_prometheus_fbit_settings").(*toml.Tree)
	}

	if promFbitConfig != nil {
		if v := promFbitConfig.Get("tcp_listener_chunk_size"); v != nil && isValidNumber(v) {
			promFbitChunkSize = getIntValue(v)
			fmt.Printf("Using config map value: AZMON_FBIT_CHUNK_SIZE = %sm\n", strconv.Itoa(promFbitChunkSize))
		}

		if v := promFbitConfig.Get("tcp_listener_buffer_size"); v != nil && isValidNumber(v) {
			promFbitBufferSize = getIntValue(v)
			fmt.Printf("Using config map value: AZMON_FBIT_BUFFER_SIZE = %sm\n", strconv.Itoa(promFbitBufferSize))
			if promFbitBufferSize < promFbitChunkSize {
				promFbitBufferSize = promFbitChunkSize
				fmt.Printf("Setting Fbit buffer size equal to chunk size since it is set to less than chunk size - AZMON_FBIT_BUFFER_SIZE = %sm\n", strconv.Itoa(promFbitBufferSize))
			}
		}

		if v := promFbitConfig.Get("tcp_listener_mem_buf_limit"); v != nil && isValidNumber(v) {
			promFbitMemBufLimit = getIntValue(v)
			fmt.Printf("Using config map value: AZMON_FBIT_MEM_BUF_LIMIT = %sm\n", strconv.Itoa(promFbitMemBufLimit))
		}
	}

	// Proxy config
	if proxyConfig := settings.Get("proxy_config"); proxyConfig != nil {
		if proxy, ok := proxyConfig.(*toml.Tree); ok {
			if v := proxy.Get("ignore_proxy_settings"); v != nil {
				if strVal, ok := v.(string); ok && strings.ToLower(strVal) == "true" {
					ignoreProxySettings = true
					fmt.Printf("Using config map value: ignoreProxySettings = %v\n", ignoreProxySettings)
				}
			}
		}
	}

	// Multiline config
	if multilineConfig := settings.Get("multiline"); multilineConfig != nil {
		if multiline, ok := multilineConfig.(*toml.Tree); ok {
			if v := multiline.Get("enabled"); v != nil {
				if strVal, ok := v.(string); ok {
					multilineEnabled = strVal
					fmt.Printf("Using config map value: AZMON_MULTILINE_ENABLED = %s\n", multilineEnabled)
				}
			}
		}
	}

	// Network listener wait time config
	if networkListenerConfig := settings.Get("network_listener_waittime"); networkListenerConfig != nil {
		if netListener, ok := networkListenerConfig.(*toml.Tree); ok {
			if v := netListener.Get("tcp_port_25226"); v != nil && isValidWaittime(v, waittimePort25226) {
				waittimePort25226 = getIntValue(v)
				fmt.Printf("Using config map value: WAITTIME_PORT_25226 = %d\n", waittimePort25226)
			}

			if v := netListener.Get("tcp_port_25228"); v != nil && isValidWaittime(v, waittimePort25228) {
				waittimePort25228 = getIntValue(v)
				fmt.Printf("Using config map value: WAITTIME_PORT_25228 = %d\n", waittimePort25228)
			}

			if v := netListener.Get("tcp_port_25229"); v != nil && isValidWaittime(v, waittimePort25229) {
				waittimePort25229 = getIntValue(v)
				fmt.Printf("Using config map value: WAITTIME_PORT_25229 = %d\n", waittimePort25229)
			}

			if v := netListener.Get("tcp_port_13000"); v != nil && isValidWaittime(v, waittimePort13000) {
				waittimePort13000 = getIntValue(v)
				fmt.Printf("Using config map value: WAITTIME_PORT_13000 = %d\n", waittimePort13000)
			}

			if v := netListener.Get("tcp_port_12563"); v != nil && isValidWaittime(v, waittimePort12563) {
				waittimePort12563 = getIntValue(v)
				fmt.Printf("Using config map value: WAITTIME_PORT_12563 = %d\n", waittimePort12563)
			}
		}
	}
}

func writeLinuxConfigFile() error {
	file, err := os.Create("agent_config_env_var")
	if err != nil {
		fmt.Println("Exception while opening file for writing config environment variables")
		return err
	}
	defer file.Close()

	// Write all environment variables
	fmt.Fprintf(file, "export NODES_CHUNK_SIZE=%d\n", nodesChunkSize)
	fmt.Fprintf(file, "export PODS_CHUNK_SIZE=%d\n", podsChunkSize)
	fmt.Fprintf(file, "export EVENTS_CHUNK_SIZE=%d\n", eventsChunkSize)
	fmt.Fprintf(file, "export DEPLOYMENTS_CHUNK_SIZE=%d\n", deploymentsChunkSize)
	fmt.Fprintf(file, "export HPA_CHUNK_SIZE=%d\n", hpaChunkSize)
	fmt.Fprintf(file, "export PODS_EMIT_STREAM_BATCH_SIZE=%d\n", podsEmitStreamBatchSize)
	fmt.Fprintf(file, "export NODES_EMIT_STREAM_BATCH_SIZE=%d\n", nodesEmitStreamBatchSize)

	// Network flow logs settings
	fmt.Fprintf(file, "export NETWORKFLOW_LOGS_THROTTLE_ENABLED=%v\n", networkFlowLogsThrottleEnabled)
	if networkFlowLogsThrottleEnabled {
		fmt.Fprintf(file, "export NETWORKFLOW_LOGS_THROTTLE_RATE=%d\n", networkFlowLogsThrottleRate)
		fmt.Fprintf(file, "export NETWORKFLOW_LOGS_THROTTLE_WINDOW=%d\n", networkFlowLogsThrottleWindow)
		fmt.Fprintf(file, "export NETWORKFLOW_LOGS_THROTTLE_INTERVAL=%s\n", networkFlowLogsThrottleInterval)
		fmt.Fprintf(file, "export NETWORKFLOW_LOGS_THROTTLE_PRINT=%v\n", networkFlowLogsThrottlePrint)
	}

	// Fluent bit settings
	fmt.Fprintf(file, "export ENABLE_FBIT_INTERNAL_METRICS=%v\n", enableFbitInternalMetrics)
	if fbitFlushIntervalSecs > 0 {
		fmt.Fprintf(file, "export FBIT_SERVICE_FLUSH_INTERVAL=%d\n", fbitFlushIntervalSecs)
	}
	if fbitTailBufferChunkSizeMBs > 0 {
		fmt.Fprintf(file, "export FBIT_TAIL_BUFFER_CHUNK_SIZE=%d\n", fbitTailBufferChunkSizeMBs)
	}
	if fbitTailBufferMaxSizeMBs > 0 {
		fmt.Fprintf(file, "export FBIT_TAIL_BUFFER_MAX_SIZE=%d\n", fbitTailBufferMaxSizeMBs)
	}
	if fbitTailMemBufLimitMBs > 0 {
		fmt.Fprintf(file, "export FBIT_TAIL_MEM_BUF_LIMIT=%d\n", fbitTailMemBufLimitMBs)
	}
	if fbitTailIgnoreOlder != "" {
		fmt.Fprintf(file, "export FBIT_TAIL_IGNORE_OLDER=%s\n", fbitTailIgnoreOlder)
	}
	if fbitStorageMaxChunksUp > 0 {
		fmt.Fprintf(file, "export FBIT_STORAGE_MAX_CHUNKS_UP=%d\n", fbitStorageMaxChunksUp)
	}
	if fbitStorageType != "" {
		fmt.Fprintf(file, "export FBIT_STORAGE_TYPE=%s\n", fbitStorageType)
	}
	if enableFluentBitThreading {
		fmt.Fprintf(file, "export ENABLE_FBIT_THREADING=%v\n", enableFluentBitThreading)
	}

	// Geneva settings
	if storageTotalLimitSizeMB > 0 {
		fmt.Fprintf(file, "export STORAGE_TOTAL_LIMIT_SIZE_MB=%dM\n", storageTotalLimitSizeMB)
	}
	if outputForwardWorkers > 0 {
		fmt.Fprintf(file, "export OUTPUT_FORWARD_WORKERS_COUNT=%d\n", outputForwardWorkers)
	}
	fmt.Fprintf(file, "export OUTPUT_FORWARD_RETRY_LIMIT=%v\n", outputForwardRetryLimit)
	fmt.Fprintf(file, "export REQUIRE_ACK_RESPONSE=%s\n", requireAckResponse)

	// MDSD settings
	if mdsdMonitoringMaxEventRate > 0 {
		fmt.Fprintf(file, "export MONITORING_MAX_EVENT_RATE=%d\n", mdsdMonitoringMaxEventRate)
	}
	if mdsdUploadMaxSizeInMB > 0 {
		fmt.Fprintf(file, "export MDSD_ODS_UPLOAD_CHUNKING_SIZE_IN_MB=%d\n", mdsdUploadMaxSizeInMB)
	}
	if mdsdUploadFrequencyInSeconds > 0 {
		fmt.Fprintf(file, "export AMA_MAX_PUBLISH_LATENCY=%d\n", mdsdUploadFrequencyInSeconds)
		fmt.Fprintf(file, "export AMA_LOAD_TEST_LATENCY=true\n")
	}
	if mdsdBackPressureThresholdInMB > 0 {
		fmt.Fprintf(file, "export BACKPRESSURE_THRESHOLD_IN_MB=%d\n", mdsdBackPressureThresholdInMB)
	}
	if mdsdCompressionLevel >= 0 {
		fmt.Fprintf(file, "export MDSD_ODS_COMPRESSION_LEVEL=%d\n", mdsdCompressionLevel)
	}

	// Prometheus fluent bit settings
	if promFbitChunkSize > 0 {
		fmt.Fprintf(file, "export AZMON_FBIT_CHUNK_SIZE=%dm\n", promFbitChunkSize)
	} else {
		fmt.Fprintf(file, "export AZMON_FBIT_CHUNK_SIZE=%s\n", promFbitChunkSizeDefault)
	}
	if promFbitBufferSize > 0 {
		fmt.Fprintf(file, "export AZMON_FBIT_BUFFER_SIZE=%dm\n", promFbitBufferSize)
	} else {
		fmt.Fprintf(file, "export AZMON_FBIT_BUFFER_SIZE=%s\n", promFbitBufferSizeDefault)
	}
	if promFbitMemBufLimit > 0 {
		fmt.Fprintf(file, "export AZMON_FBIT_MEM_BUF_LIMIT=%dm\n", promFbitMemBufLimit)
	} else {
		fmt.Fprintf(file, "export AZMON_FBIT_MEM_BUF_LIMIT=%s\n", promFbitMemBufLimitDefault)
	}

	// Proxy and multiline settings
	if ignoreProxySettings {
		fmt.Fprintf(file, "export IGNORE_PROXY_SETTINGS=%v\n", ignoreProxySettings)
	}
	if strings.ToLower(strings.TrimSpace(multilineEnabled)) == "true" {
		fmt.Fprintf(file, "export AZMON_MULTILINE_ENABLED=%s\n", multilineEnabled)
	}

	// Network listener wait times
	fmt.Fprintf(file, "export WAITTIME_PORT_25226=%d\n", waittimePort25226)
	fmt.Fprintf(file, "export WAITTIME_PORT_25228=%d\n", waittimePort25228)
	fmt.Fprintf(file, "export WAITTIME_PORT_25229=%d\n", waittimePort25229)
	fmt.Fprintf(file, "export WAITTIME_PORT_13000=%d\n", waittimePort13000)
	fmt.Fprintf(file, "export WAITTIME_PORT_12563=%d\n", waittimePort12563)

	return nil
}

func writeWindowsConfigFile() error {
	file, err := os.Create("setagentenv.txt")
	if err != nil {
		fmt.Println("Exception while opening file for writing config environment variables for WINDOWS LOG")
		return err
	}
	defer file.Close()

	// Write environment variables for Windows
	fmt.Fprintf(file, "ENABLE_FBIT_INTERNAL_METRICS=%v\n", enableFbitInternalMetrics)
	if fbitFlushIntervalSecs > 0 {
		fmt.Fprintf(file, "FBIT_SERVICE_FLUSH_INTERVAL=%d\n", fbitFlushIntervalSecs)
	}
	if fbitTailBufferChunkSizeMBs > 0 {
		fmt.Fprintf(file, "FBIT_TAIL_BUFFER_CHUNK_SIZE=%d\n", fbitTailBufferChunkSizeMBs)
	}
	if fbitTailBufferMaxSizeMBs > 0 {
		fmt.Fprintf(file, "FBIT_TAIL_BUFFER_MAX_SIZE=%d\n", fbitTailBufferMaxSizeMBs)
	}
	if fbitTailMemBufLimitMBs > 0 {
		fmt.Fprintf(file, "FBIT_TAIL_MEM_BUF_LIMIT=%d\n", fbitTailMemBufLimitMBs)
	}
	if fbitTailIgnoreOlder != "" {
		fmt.Fprintf(file, "FBIT_TAIL_IGNORE_OLDER=%s\n", fbitTailIgnoreOlder)
	}
	if fbitStorageMaxChunksUp > 0 {
		fmt.Fprintf(file, "FBIT_STORAGE_MAX_CHUNKS_UP=%d\n", fbitStorageMaxChunksUp)
	}
	if fbitStorageType != "" {
		fmt.Fprintf(file, "FBIT_STORAGE_TYPE=%s\n", fbitStorageType)
	}
	if enableFluentBitThreading {
		fmt.Fprintf(file, "ENABLE_FBIT_THREADING=%v\n", enableFluentBitThreading)
	}

	// Prometheus fluent bit settings
	if promFbitChunkSize > 0 {
		fmt.Fprintf(file, "AZMON_FBIT_CHUNK_SIZE=%dm\n", promFbitChunkSize)
	} else {
		fmt.Fprintf(file, "AZMON_FBIT_CHUNK_SIZE=%s\n", promFbitChunkSizeDefault)
	}
	if promFbitBufferSize > 0 {
		fmt.Fprintf(file, "AZMON_FBIT_BUFFER_SIZE=%dm\n", promFbitBufferSize)
	} else {
		fmt.Fprintf(file, "AZMON_FBIT_BUFFER_SIZE=%s\n", promFbitBufferSizeDefault)
	}
	if promFbitMemBufLimit > 0 {
		fmt.Fprintf(file, "AZMON_FBIT_MEM_BUF_LIMIT=%dm\n", promFbitMemBufLimit)
	} else {
		fmt.Fprintf(file, "AZMON_FBIT_MEM_BUF_LIMIT=%s\n", promFbitMemBufLimitDefault)
	}

	// Geneva settings
	if storageTotalLimitSizeMB > 0 {
		fmt.Fprintf(file, "STORAGE_TOTAL_LIMIT_SIZE_MB=%dM\n", storageTotalLimitSizeMB)
	}
	if outputForwardWorkers > 0 {
		fmt.Fprintf(file, "OUTPUT_FORWARD_WORKERS_COUNT=%d\n", outputForwardWorkers)
	}
	fmt.Fprintf(file, "OUTPUT_FORWARD_RETRY_LIMIT=%v\n", outputForwardRetryLimit)
	fmt.Fprintf(file, "REQUIRE_ACK_RESPONSE=%s\n", requireAckResponse)

	// Proxy and multiline settings
	if ignoreProxySettings {
		fmt.Fprintf(file, "IGNORE_PROXY_SETTINGS=%v\n", ignoreProxySettings)
	}
	if strings.ToLower(strings.TrimSpace(multilineEnabled)) == "true" {
		fmt.Fprintf(file, "AZMON_MULTILINE_ENABLED=%s\n", multilineEnabled)
	}

	// Network listener wait time (only port 25229 for Windows based on Ruby script)
	fmt.Fprintf(file, "WAITTIME_PORT_25229=%d\n", waittimePort25229)

	return nil
}

func main() {
	configSchemaVersion = os.Getenv("AZMON_AGENT_CFG_SCHEMA_VERSION")
	fmt.Println("****************Start Config Processing********************")

	if configSchemaVersion != "" && strings.EqualFold(strings.TrimSpace(configSchemaVersion), "v1") {
		configMapSettings, err := parseConfigMap()
		if err == nil && configMapSettings != nil {
			populateSettingValuesFromConfigMap(configMapSettings)
		}
	} else {
		if _, err := os.Stat(configMapMountPath); err == nil {
			logError(fmt.Sprintf("config::unsupported/missing config schema version - '%s' , using defaults, please use supported schema version", configSchemaVersion))
		}
	}

	// Write configuration to files
	err := writeLinuxConfigFile()
	if err == nil {
		fmt.Println("****************End Config Processing********************")
	}

	// Also write Windows config if on Windows
	if osType != "" && strings.EqualFold(strings.TrimSpace(osType), "windows") {
		err = writeWindowsConfigFile()
		if err == nil {
			fmt.Println("****************End Config Processing********************")
		}
	}
}
