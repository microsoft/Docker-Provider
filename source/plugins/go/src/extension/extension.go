package extension

import (
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"sync"

	uuid "github.com/google/uuid"
)

type Extension struct {
	datatypeStreamIdMap    map[string]string
	dataCollectionSettings map[string]string
	datatypeNamedPipeMap   map[string]string
}

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
		if extensionSettingsItr != nil && len(extensionSettingsItr) > 0 {
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
	if dataCollectionSettingsItr != nil && len(dataCollectionSettingsItr) > 0 {
		for k, v := range dataCollectionSettingsItr {
			lk := strings.ToLower(k)
			lv := strings.ToLower(fmt.Sprintf("%v", v))
			dataCollectionSettings[lk] = fmt.Sprintf("%v", lv)
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
