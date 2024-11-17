package extension

import (
	"net"
)

//go:generate mockgen -destination=socket_writer_mock.go -package=extension Docker-Provider/source/plugins/go/src/extension IFluentSocketWriter

// MaxRetries for trying to write data to the socket
const MaxRetries = 5

// ReadBufferSize for reading data from sockets
// Current CI extension config size is ~5KB which is singleton where as ContainerLogV2Extension can be many
// ContainerLogV2Extension DCR config size is ~2KB and for handling upto 500 DCRs, 2KB*500 => 1MB
const ReadBufferSize = 1024000

// FluentSocketWriter writes data to AMA's default fluent socket
type FluentSocket struct {
	socket      net.Conn
	sockAddress string
}

// begin mocking boilerplate
type IFluentSocketWriter interface {
	connect(fluentSocket *FluentSocket) error
	disconnect(fluentSocket *FluentSocket) error
	writeWithRetries(fluentSocket *FluentSocket, data []byte) (int, error)
	read(fluentSocket *FluentSocket) ([]byte, error)
	write(fluentSocket *FluentSocket, payload []byte) (int, error)
	writeAndRead(fluentSocket *FluentSocket, payload []byte) ([]byte, error)
}

type FluentSocketWriterImpl struct{}

// Methods in this file can by mocked by replacing FluentSocketWriter with a different struct. The methods
// in this file are all tied to the FluentSocketWriterImpl struct, but other structs could implement
// IFluentSocketWriter and be used instead
var FluentSocketWriter IFluentSocketWriter

func init() {
	FluentSocketWriter = FluentSocketWriterImpl{}
}

// end mocking boilerplate

func (FluentSocketWriterImpl) connect(fs *FluentSocket) error {
	c, err := net.Dial("unix", fs.sockAddress)
	if err != nil {
		return err
	}
	fs.socket = c
	return nil
}

func (FluentSocketWriterImpl) disconnect(fs *FluentSocket) error {
	if fs.socket != nil {
		fs.socket.Close()
		fs.socket = nil
	}
	return nil
}

func (FluentSocketWriterImpl) writeWithRetries(fs *FluentSocket, data []byte) (int, error) {
	var (
		err error
		n   int
	)
	for i := 0; i < MaxRetries; i++ {
		n, err = fs.socket.Write(data)
		if err == nil {
			return n, nil
		}
	}
	if err, ok := err.(net.Error); !ok || !err.Temporary() {
		// so that connect() is called next time if write fails
		// this happens when mdsd is restarted
		_ = fs.socket.Close() // no need to log the socket closing error
		fs.socket = nil
	}
	return 0, err
}

func (FluentSocketWriterImpl) read(fs *FluentSocket) ([]byte, error) {
	buf := make([]byte, ReadBufferSize)
	n, err := fs.socket.Read(buf)
	if err != nil {
		return nil, err
	}
	return buf[:n], nil

}

func (FluentSocketWriterImpl) write(fs *FluentSocket, payload []byte) (int, error) {
	if fs.socket == nil {
		// previous write failed with permanent error and socket was closed.
		if err := FluentSocketWriter.connect(fs); err != nil {
			return 0, err
		}
	}

	return FluentSocketWriter.writeWithRetries(fs, payload)
}

// writeAndRead writes data to the socket and sends the response back
func (FluentSocketWriterImpl) writeAndRead(fs *FluentSocket, payload []byte) ([]byte, error) {
	_, err := FluentSocketWriter.write(fs, payload)
	if err != nil {
		return nil, err
	}
	return FluentSocketWriter.read(fs)
}
