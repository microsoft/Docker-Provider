//go:build linux

package extension

import (
	"fmt"
	"github.com/ugorji/go/codec"
	"strings"
)

func getExtensionConfigResponse(jsonBytes []byte) ([]byte, error) {
	var data []byte
	enc := codec.NewEncoderBytes(&data, new(codec.MsgpackHandle))
	if err := enc.Encode(string(jsonBytes)); err != nil {
		return nil, err
	}

	fs := &FluentSocket{}
	fs.sockAddress = "/var/run/mdsd-ci/default_fluent.socket"
	if containerType != "" && strings.Compare(strings.ToLower(containerType), "prometheussidecar") == 0 {
		fs.sockAddress = fmt.Sprintf("/var/run/mdsd-%s/default_fluent.socket", containerType)
	}
	responseBytes, err := FluentSocketWriter.writeAndRead(fs, data)
	defer FluentSocketWriter.disconnect(fs)
	logger.Printf("Info::mdsd::Making call to FluentSocket: %s to write and read the config data", fs.sockAddress)
	if err != nil {
		logger.Printf("Error::mdsd::Failed to write and read the config data. Error message: %s", string(err.Error()))
		return nil, err
	}
	logger.Printf("extensionconfig::getExtensionConfigResponse:: getting extension config from fluent socket-end")

	return responseBytes, nil
}
