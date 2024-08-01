module Docker-Provider/source/plugins/go/input

go 1.21.0

toolchain go1.22.5

require github.com/calyptia/plugin v1.0.2

require (
	code.cloudfoundry.org/clock v1.1.0 // indirect
	github.com/Microsoft/go-winio v0.6.1 // indirect
	github.com/calyptia/cmetrics-go v0.1.7 // indirect
	github.com/docker/docker v25.0.6+incompatible // indirect
	github.com/docker/go-units v0.5.0 // indirect
	github.com/gofrs/uuid v4.4.0+incompatible // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/ugorji/go/codec v1.2.12 // indirect
	golang.org/x/mod v0.17.0 // indirect
	golang.org/x/sync v0.7.0 // indirect
	golang.org/x/sys v0.21.0 // indirect
	golang.org/x/tools v0.21.1-0.20240508182429-e35e4ccd0d2d // indirect
)

require (
	Docker-Provider/source/plugins/go/src v0.0.0
	github.com/golang-jwt/jwt/v5 v5.2.1
	github.com/microsoft/ApplicationInsights-Go v0.4.4
	github.com/sirupsen/logrus v1.9.3
	gopkg.in/natefinch/lumberjack.v2 v2.2.1
)

replace Docker-Provider/source/plugins/go/src => ../src
