package main

import (
	"github.com/fluent/fluent-bit-go/output"
)
import (
	"C"
	"unsafe"
)

//export FLBPluginRegister
func FLBPluginRegister(ctx unsafe.Pointer) int {
	return output.FLBPluginRegister(ctx, "oms", "Stdout GO!")
}

//export FLBPluginInit
// (fluentbit will call this)
// ctx (context) pointer to fluentbit context (state/ c code)
func FLBPluginInit(ctx unsafe.Pointer) int {
	Log("Initializing out_oms go plugin for fluentbit")
	InitializePlugin(ContainerLogPluginConfFilePath)
	return output.FLB_OK
}

//export FLBPluginFlush
func FLBPluginFlush(data unsafe.Pointer, length C.int, tag *C.char) int {
	var count int
	var ret int
	var record map[interface{}]interface{}
	var records []map[interface{}]interface{}

	// Create Fluent Bit decoder
	dec := output.NewDecoder(data, int(length))

	// Iterate Records
	count = 0
	for {
		// Extract Record
		ret, _, record = output.GetRecord(dec)
		if ret != 0 {
			break
		}
		records = append(records, record)
		count++
	}
	return PostDataHelper(records)
}

// FLBPluginExit exits the plugin
func FLBPluginExit() int {
	KubeSystemContainersRefreshTicker.Stop()
	ContainerImageNameRefreshTicker.Stop()
	return output.FLB_OK
}

func main() {
}
