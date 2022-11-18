package extension

import (
	"fmt"
	"log"
	"os"
	reflect "reflect"
	"testing"

	"github.com/golang/mock/gomock"
)

type FluentSocketWriterMock struct{}

func Test_getDataTypeToStreamIdMapping(t *testing.T) {

	type test_struct struct {
		testName     string
		mdsdResponse string
		fluentSocket FluentSocket
		output       map[string]string
		err          error
	}

	// This is a pretty useless unit test, but it demonstrates the concept (putting together a real test
	// would require some large json structs). If getDataTypeToStreamIdMapping() is ever updated, that
	// would be a good opertunity to add some real test cases.
	tests := []test_struct{
		{
			"basic test",
			"{}",
			FluentSocket{},
			map[string]string{},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.testName, func(t *testing.T) {
			mockCtrl := gomock.NewController(t)
			defer mockCtrl.Finish()
			mock := NewMockIFluentSocketWriter(mockCtrl)
			sock := &FluentSocket{}
			sock.sockAddress = "/var/run/mdsd-ci/default_fluent.socket"
			mock.EXPECT().writeAndRead(sock, gomock.Any()).Return([]byte(tt.mdsdResponse), nil).Times(1)
			mock.EXPECT().disconnect(sock).Return(nil).Times(1)

			// This is where calls to the normal socket writer calls are redirected to the mock.
			ActualFluentSocketWriter := FluentSocketWriter // save the old struct so that we can put it back later
			FluentSocketWriter = mock

			logfile, err := os.Create("logFile.txt")
			if err != nil {
				fmt.Println(err.Error())
			}

			// use an actual logger here. Using a real logger then cleaning up the log file later is easier than mocking the logger.
			GetInstance(log.New(logfile, "", 0), "ContainerType")
			defer os.Remove("logFile.txt")

			got, reterr := getDataTypeToStreamIdMapping()
			if reterr != nil {
				t.Errorf("got error")
				t.Errorf(err.Error())
			}
			if !reflect.DeepEqual(got, tt.output) {
				t.Errorf("getDataTypeToStreamIdMapping() = %v, want %v", got, tt.output)
			}

			// stop redirecting method calls to the mock
			FluentSocketWriter = ActualFluentSocketWriter
		})
	}
}
