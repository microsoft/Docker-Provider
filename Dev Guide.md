# Dev Guide

More advanced information needed to develop or build the docker provider will live here

<!-- TODO: eventually move dev info from README.md to here-->

## Windows Telegraf dependency

`kubernetes/windows/setup.ps1` installs the official Telegraf 1.40.1 Windows AMD64
ZIP and verifies its pinned SHA256 before extraction. The package corresponds to
upstream commit `26b8f4478b676f4f5e5d8ce1622cdf4f6c273bda`. The existing Windows
pipeline continues to sign `C:\opt\telegraf\telegraf.exe` as an OSS dependency.

The official binary is built with Go 1.27.1 for `windows/amd64`, `GOAMD64=v1`.
Go's [Windows OS floor](https://go.dev/wiki/MinimumRequirements#windows) is Windows
10 or Windows Server 2016 and newer. Both repository image targets, LTSC2019 and
LTSC2022, meet that floor; this does not replace validation inside those images
or in installed-service mode.

The Windows entrypoint registers both Telegraf services through
`telegraf-windows-service.rb`, using the same already-installed `win32-service`
dispatcher as Fluentd. Telegraf 1.40's native service detection requires its
`services.exe` parent to be in session 0, which is not guaranteed in Windows containers.
The host runs the unchanged executable with `--console`, monitors child exit, and
forwards SCM stop through the child's private console/process group. Shutdown is
bounded; the host joins a kill-on-close job before spawning, so the child inherits
containment at creation, including if the host dies before `spawn` returns. The
non-inheritable job handle stays open until host process exit so console cleanup
does not kill the host before SCM shutdown completes. The service
PID is the Ruby host; the Telegraf PID is its child. Role-only host arguments keep
the existing procstat config-path filters selecting Telegraf rather than Ruby.
Per-role logs under `C:\opt\telegraf\logs` rotate at 5 MiB with two backups.
The native startup-boundary regression uses only local sleeping Ruby processes:
`ruby build/windows/installer/scripts/telegraf-windows-console_test.rb`.
It runs on Windows with the image's existing `ffi` dependency and skips on Linux.

Upgrade the two configurations in `build/windows/installer/conf/` and
`tomlparser-prom-customconfig.rb` together with the binary. Windows uses `timeout`
to preserve the overall 15-second metric-scrape limit; upstream's
[1.40 documentation](https://github.com/influxdata/telegraf/blob/e9017dc3266369d6fa185e0e130af1d1d4021ce9/plugins/inputs/prometheus/README.md#L152-L157)
explains that `response_timeout` now covers headers only, unlike the
[1.24.2 client timeout](https://github.com/influxdata/telegraf/blob/9550e7a533dd00632e14435e87ed3eb4b04832c6/plugins/inputs/prometheus/prometheus.go#L254-L261).
Procstat uses `tag_with = ["pid"]` to retain PID tags. Both OSes render
`fieldinclude`/`fieldexclude` instead of the deprecated `fieldpass`/`fielddrop`
Telegraf options. The public ConfigMap keys remain `fieldpass`/`fielddrop` for
backward compatibility; the shared parser maps them to the current Telegraf names.
Run `ruby build/common/installer/scripts/tomlparser-prom-customconfig_test.rb`
for rendering coverage with and without namespace filters. On Windows, set
`TELEGRAF_WINDOWS_BINARY` to the extracted `telegraf.exe` to also load the generated
configs with that binary in bounded `--test` mode, without Kubernetes access or
running output plugins.

This stock upgrade is a partial mitigation: node discovery rereads the token file
on retries after a failed poll, without relying on file modification time. The
[1.40.0 discovery code](https://github.com/influxdata/telegraf/blob/e9017dc3266369d6fa185e0e130af1d1d4021ce9/plugins/inputs/prometheus/kubernetes.go)
still omits response cleanup on non-200 status codes and lacks an explicit
discovery request timeout. The metric-scrape `timeout` does not bound that path.
HTTP/2 negotiation is not a substitute for fixing those remaining issues.

## Testing
Last updated 8/18/2021

To run all unit tests run the commands `test/unit-tests/run_go_tests.sh` and `test/unit-tests/run_ruby_tests.sh`

#### Conventions:
1. Unit tests should go in their own file, but in the same folder as the source code their testing. For example, the tests for `in_kube_nodes.rb` are in `in_kube_nodes_test.rb`. Both files are in the folder `source/plugin/ruby`.

### Ruby
Sample tests are provided in [in_kube_nodes_test.rb](source/plugin/ruby/in_kube_nodes_test.rb). They are meant to demo the tooling used for unit tests (as opposed to being comprehensive tests). Basic techniques like mocking are demonstrated there.

#### Conventions:
1. When modifying a fluentd plugin for unit testing, any mocked classes (like KubernetesApiClient, applicationInsightsUtility, env, etc.) should be passed in as optional arguments of initialize. For example:
```
    def initialize
      super
```
would be turned into
```
    def initialize (kubernetesApiClient=nil, applicationInsightsUtility=nil, extensionUtils=nil, env=nil)
      super()
```

2. Having end-to-end tests of all fluentd plugins is a longshot. We care more about unit testing smaller blocks of functionality (like all the helper functions in KubeNodeInventory.rb). Unit tests for fluentd plugins are not expected.

### Golang

Since golang is statically compiled, mocking requires a lot more work than in ruby. Sample tests are provided in [utils_test.go](source/plugin/go/src/utils_test.go) and [extension_test.go](source/plugin/go/src/extension/extension_test.go). Again, they are meant to demo the tooling used for unit tests (as opposed to being comprehensive tests). Basic techniques like mocking are demonstrated there.

#### Mocking:
Mocks are generated with gomock (mockgen). 
* Mock files should be called *_mock.go (socket_writer.go => socket_writer_mock.go)
* Mocks should not be checked in to git. (they have been added to the .gitignore)
* The command to generate mock files should go in a `//go:generate` comment at the top of the mocked file (see [socket_writer.go](source/plugin/go/src/extension/socket_writer.go) for an example). This way mocks can be generated by the unit test script.
* Mocks also go in the same folder as the mocked files. This is unfortunate, but necessary to avoid circular package dependencies (anyone else feel free to figure out how to move mocks to a separate folder)

Using mocks is also a little tricky. In order to mock functions in a package with gomock, they must be converted to reciever methods of a struct. This way the struct can be swapped out at runtime to change which implementaions of a method are called. See the example below:

```
// declare all functions to be mocked in this interface
type registrationPreCheckerInterface interface {
	FUT(string) bool
}

// Create a struct which implements the above interface
type regPreCheck struct{}

func (r regPreCheck) FUT(email string) bool {
	fmt.Println("real FUT() called")
	return true
}

// Create a global variable and assign it to the struct
var regPreCondVar registrationPreCheckerInterface

func init() {
	regPreCondVar = regPreCheck{}
}
```

Now any code wishing to call FUT() will call `regPreCondVar.FUT("")`

A unit test can substitute its own implementaion of FUT() like so

```
// This will hold the mock of FUT we want to substitute
var FUTMock func(email string) bool

// create a new struct which implements the earlier interface
type regPreCheckMock struct{}

func (u regPreCheckMock) FUT(email string) bool {
	return FUTMock(email)
}
```

Everything is set up. Now a unit test can substitute in a mock like so:

```
func someUnitTest() {
    // This will call the actual implementaion of FUT()
	regPreCondVar.FUT("")

    // Now the test creates another struct to substitue. After this like all calls to FUT() will be diverted
	regPreCondVar = regPreCheckMock{}

    // substute another function to run instead of FUT()
	FUTMock = func(email string) bool {
		fmt.Println("FUT 1 called")
		return false
	}
    // This will call the function defined right above
	regPreCondVar.FUT("")

    // We can substitue another implementation
	FUTMock = func(email string) bool {
		fmt.Println("FUT 2 called")
		return false
	}
	regPreCondVar.FUT("")

    // put the old behavior back
	regPreCondVar = regPreCheck{}
    // this will call the actual implementation of FUT()
	regPreCondVar.FUT("")

}
```

A concrete example of this can be found in [socket_writer.go](source/plugin/go/src/extension/socket_writer.go) and [extension_test.go](source/plugin/go/src/extension/extension_test.go). Again, if anybody has a better way feel free to update this guide.



A simpler way to test a specific function is to write wrapper functions. Test code calls the inner function (ReadFileContentsImpl) and product code calls the wrapper function (ReadFileContents). The wrapper function provides any outside state which a unit test would want to control (like a function to read a file). This option makes product code more verbose, but probably easier to read too. Either way is acceptable.
```
func ReadFileContents(fullPathToFileName string) (string, error) {
	return ReadFileContentsImpl(fullPathToFileName, ioutil.ReadFile)
}
```
