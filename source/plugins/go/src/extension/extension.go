package extension

import (
	"encoding/json"
	"fmt"
	"log"
	"regexp"
	"strconv"
	"strings"
	"sync"

	uuid "github.com/google/uuid"
)

type Extension struct {
	datatypeStreamIdMap    map[string]string
	dataCollectionSettings map[string]string
	datatypeNamedPipeMap   map[string]string
}

const (
	EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_INTERVAL                 = "interval"
	EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_INTERVAL_MIN             = 1
	EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_INTERVAL_MAX             = 30
	EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_NAMESPACES               = "namespaces"
	EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_NAMESPACE_FILTERING_MODE = "namespacefilteringmode"
)

var singleton *Extension
var once sync.Once
var extensionconfiglock sync.Mutex
var logger *log.Logger
var containerType string

func GetInstance(flbLogger *log.Logger, containertype string) *Extension {
	once.Do(func() {
		singleton = &Extension{
			datatypeStreamIdMap:    make(map[string]string),
			dataCollectionSettings: make(map[string]string),
			datatypeNamedPipeMap:   make(map[string]string),
		}
		flbLogger.Println("Extension Instance created")
	})
	logger = flbLogger
	containerType = containertype
	return singleton
}

func getExtensionData() (TaggedData, error) {
	guid := uuid.New()
	var extensionData TaggedData
	taggedData := map[string]interface{}{"Request": "AgentTaggedData", "RequestId": guid.String(), "Tag": "ContainerInsights", "Version": "1"}
	jsonBytes, err := json.Marshal(taggedData)
	if err != nil {
		logger.Printf("Error::mdsd/ama::Failed to marshal taggedData data. Error message: %s", string(err.Error()))
		return extensionData, err
	}

	responseBytes, err := getExtensionConfigResponse(jsonBytes)
	if err != nil {
		logger.Printf("Error::mdsd/ama::Failed to get config response data. Error message: %s", string(err.Error()))
		return extensionData, err
	}
	var responseObject AgentTaggedDataResponse
	err = json.Unmarshal(responseBytes, &responseObject)
	if err != nil {
		logger.Printf("Error::mdsd/ama::Failed to unmarshal config response data. Error message: %s", string(err.Error()))
		return extensionData, err
	}

	err = json.Unmarshal([]byte(responseObject.TaggedData), &extensionData)

	return extensionData, err
}

func getExtensionConfigs() ([]ExtensionConfig, error) {
	extensionData, err := getExtensionData()
	if err != nil {
		return nil, err
	}
	return extensionData.ExtensionConfigs, nil
}

func getExtensionSettings() (map[string]map[string]interface{}, error) {
	extensionSettings := make(map[string]map[string]interface{})

	extensionConfigs, err := getExtensionConfigs()
	if err != nil {
		return extensionSettings, err
	}
	for _, extensionConfig := range extensionConfigs {
		extensionSettingsItr := extensionConfig.ExtensionSettings
		if len(extensionSettingsItr) > 0 {
			extensionSettings = extensionSettingsItr
		}
	}

	return extensionSettings, nil
}

func getDataCollectionSettings() (map[string]string, error) {
	dataCollectionSettings := make(map[string]string)

	extensionSettings, err := getExtensionSettings()
	if err != nil {
		return dataCollectionSettings, err
	}
	dataCollectionSettingsItr := extensionSettings["dataCollectionSettings"]
	if len(dataCollectionSettingsItr) > 0 {
		for k, v := range dataCollectionSettingsItr {
			lk := strings.ToLower(k)
			lv := strings.ToLower(fmt.Sprintf("%v", v))
			dataCollectionSettings[lk] = fmt.Sprintf("%v", lv)
		}
	}
	return dataCollectionSettings, nil
}

func getDataCollectionSettingsInterface() (map[string]interface{}, error) {
	dataCollectionSettings := make(map[string]interface{})

	extensionSettings, err := getExtensionSettings()
	if err != nil {
		return dataCollectionSettings, err
	}

	dataCollectionSettingsItr, ok := extensionSettings["dataCollectionSettings"]
	if ok && len(dataCollectionSettingsItr) > 0 {
		for k, v := range dataCollectionSettingsItr {
			lk := strings.ToLower(k)
			dataCollectionSettings[lk] = v
		}
	}

	return dataCollectionSettings, nil
}

func getDataTypeToStreamIdMapping(hasNamedPipe bool) (map[string]string, error) {
	datatypeOutputStreamMap := make(map[string]string)

	extensionConfigs, err := getExtensionConfigs()
	if err != nil {
		return datatypeOutputStreamMap, err
	}
	outputStreamDefinitions := make(map[string]StreamDefinition)
	if hasNamedPipe == true {
		extensionData, err := getExtensionData()
		if err != nil {
			return datatypeOutputStreamMap, err
		}
		outputStreamDefinitions = extensionData.OutputStreamDefinitions
	}
	for _, extensionConfig := range extensionConfigs {
		outputStreams := extensionConfig.OutputStreams
		for dataType, outputStreamID := range outputStreams {
			if hasNamedPipe {
				datatypeOutputStreamMap[dataType] = outputStreamDefinitions[outputStreamID.(string)].NamedPipe
			} else {
				datatypeOutputStreamMap[dataType] = outputStreamID.(string)
			}
		}
	}
	return datatypeOutputStreamMap, nil
}

func (e *Extension) IsContainerLogV2(useFromCache bool) bool {
	extensionconfiglock.Lock()
	defer extensionconfiglock.Unlock()
	if useFromCache && len(e.dataCollectionSettings) > 0 && e.dataCollectionSettings["enablecontainerlogv2"] != "" {
		return e.dataCollectionSettings["enablecontainerlogv2"] == "true"
	}
	var err error
	e.dataCollectionSettings, err = getDataCollectionSettings()
	if err != nil {
		message := fmt.Sprintf("Error getting isContainerLogV2: %s", err.Error())
		logger.Printf(message)
	}
	return e.dataCollectionSettings["enablecontainerlogv2"] == "true"
}

func (e *Extension) GetOutputStreamId(datatype string, useFromCache bool) string {
	extensionconfiglock.Lock()
	defer extensionconfiglock.Unlock()
	if useFromCache && len(e.datatypeStreamIdMap) > 0 && e.datatypeStreamIdMap[datatype] != "" {
		return e.datatypeStreamIdMap[datatype]
	}
	var err error
	e.datatypeStreamIdMap, err = getDataTypeToStreamIdMapping(false)
	if err != nil {
		message := fmt.Sprintf("Error getting datatype to streamid mapping: %s", err.Error())
		logger.Printf(message)
	}
	return e.datatypeStreamIdMap[datatype]
}

func (e *Extension) GetOutputNamedPipe(datatype string, useFromCache bool) string {
	extensionconfiglock.Lock()
	defer extensionconfiglock.Unlock()
	if useFromCache && len(e.datatypeNamedPipeMap) > 0 && e.datatypeNamedPipeMap[datatype] != "" {
		return e.datatypeNamedPipeMap[datatype]
	}
	var err error
	e.datatypeNamedPipeMap, err = getDataTypeToStreamIdMapping(true)
	if err != nil {
		message := fmt.Sprintf("Error getting datatype to named pipe mapping: %s", err.Error())
		logger.Printf(message)
	}
	return e.datatypeNamedPipeMap[datatype]
}

func (e *Extension) IsDataCollectionSettingsConfigured() bool {
	var err error
	dataCollectionSettings, err := getDataCollectionSettingsInterface()
	if err != nil {
		message := fmt.Sprintf("Error getting dataCollectionSettings: %s", err.Error())
		logger.Printf(message)
		return false
	}
	return len(dataCollectionSettings) > 0
}

func (e *Extension) GetDataCollectionIntervalSeconds() int {
	collectionIntervalSeconds := 60

	dataCollectionSettings, err := getDataCollectionSettingsInterface()
	if err != nil {
		message := fmt.Sprintf("Error getting dataCollectionSettings: %s", err.Error())
		logger.Printf(message)
	}

	if len(dataCollectionSettings) > 0 {
		interval, found := dataCollectionSettings[EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_INTERVAL].(string)
		if found {
			re := regexp.MustCompile(`^[0-9]+[m]$`)
			if re.MatchString(interval) {
				intervalMinutes, err := toMinutes(interval)
				if err != nil {
					message := fmt.Sprintf("Error getting interval: %s", err.Error())
					logger.Printf(message)

				}
				if intervalMinutes >= EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_INTERVAL_MIN && intervalMinutes <= EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_INTERVAL_MAX {
					collectionIntervalSeconds = intervalMinutes * 60
				} else {
					message := fmt.Sprintf("getDataCollectionIntervalSeconds: interval value not in the range 1m to 30m hence using default, 60s: %s", interval)
					logger.Printf(message)
				}
			} else {
				message := fmt.Sprintf("getDataCollectionIntervalSeconds: interval value is invalid hence using default, 60s: %s", interval)
				logger.Printf(message)
			}
		}
	}

	return collectionIntervalSeconds
}

func (e *Extension) GetNamespacesForDataCollection() []string {
	var namespaces []string

	dataCollectionSettings, err := getDataCollectionSettingsInterface()
	if err != nil {
		message := fmt.Sprintf("Error getting dataCollectionSettings: %s", err.Error())
		logger.Printf(message)
	}

	if len(dataCollectionSettings) > 0 {
		namespacesSetting, found := dataCollectionSettings[EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_NAMESPACES].([]interface{})
		if found {
			if len(namespacesSetting) > 0 {
				// Remove duplicates from the namespacesSetting slice
				uniqueNamespaces := make(map[string]bool)
				for _, ns := range namespacesSetting {
					str, ok := ns.(string)
					if !ok {
						logger.Println("ExtensionUtils::getNamespacesForDataCollection: namespace:", ns, "not valid hence skipping")
						continue
					}
					uniqueNamespaces[strings.ToLower(str)] = true
				}

				// Convert the map keys to a new slice
				for ns := range uniqueNamespaces {
					namespaces = append(namespaces, ns)
				}

			} else {
				logger.Println("ExtensionUtils::getNamespacesForDataCollection: namespaces:", namespacesSetting, "not valid hence using default")
			}
		}
	}

	return namespaces
}

func (e *Extension) GetNamespaceFilteringModeForDataCollection() string {
	namespaceFilteringMode := "off"
	extensionSettingsDataCollectionSettingsNamespaceFilteringModes := []string{"off", "include", "exclude"}

	dataCollectionSettings, err := getDataCollectionSettingsInterface()
	if err != nil {
		message := fmt.Sprintf("Error getting dataCollectionSettings: %s", err.Error())
		logger.Printf(message)
	}

	if len(dataCollectionSettings) > 0 {
		mode, found := dataCollectionSettings[EXTENSION_SETTINGS_DATA_COLLECTION_SETTINGS_NAMESPACE_FILTERING_MODE].(string)
		if found {
			if mode != "" {
				lowerMode := strings.ToLower(mode)
				if contains(extensionSettingsDataCollectionSettingsNamespaceFilteringModes, lowerMode) {
					return lowerMode
				} else {
					fmt.Println("ExtensionUtils::getNamespaceFilteringModeForDataCollection: namespaceFilteringMode:", mode, "not supported hence using default")
				}
			}
		}
	}

	return namespaceFilteringMode
}

func toMinutes(interval string) (int, error) {
	// Trim the trailing "m" from the interval string
	trimmedInterval := strings.TrimSuffix(interval, "m")

	// Convert the trimmed interval string to an integer
	intervalMinutes, err := strconv.Atoi(trimmedInterval)
	if err != nil {
		return 0, err
	}

	return intervalMinutes, nil
}

func contains(slice []string, search string) bool {
	for _, item := range slice {
		if item == search {
			return true
		}
	}
	return false
}
