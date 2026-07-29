module Docker-Provider/source/plugins/go/input

go 1.26.5

require github.com/calyptia/plugin v1.4.4

require (
	code.cloudfoundry.org/clock v1.81.0 // indirect
	github.com/Microsoft/go-winio v0.6.2 // indirect
	github.com/calyptia/cmetrics-go v0.1.9 // indirect
	github.com/gofrs/uuid v4.4.0+incompatible // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/ugorji/go/codec v1.3.1 // indirect
	github.com/vmihailenco/msgpack/v5 v5.4.1 // indirect
	github.com/vmihailenco/tagparser/v2 v2.0.0 // indirect
	golang.org/x/sys v0.47.0 // indirect
)

require (
	Docker-Provider/source/plugins/go/src v0.0.0
	github.com/golang-jwt/jwt/v5 v5.3.1
	github.com/microsoft/ApplicationInsights-Go v0.4.4
	github.com/sirupsen/logrus v1.9.4
	gopkg.in/natefinch/lumberjack.v2 v2.2.1
)

replace Docker-Provider/source/plugins/go/src => ../src
