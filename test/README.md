# File Directory Structure
```
├── test                                            - e2e test suites to run on clusters. Unit tests are included alongside the golang files.
│   ├── README.md                                   - Info about setting up, writing, and running the tests.
│   ├── containerlog-scale-tests                    - Contains YAML files for log scale testing and scripts for deployment and cleanup.
│   │   ├── 400logspersec-2klogentrysize.yaml
│   │   ├── 400logspersec-5klogentrysize.yaml
│   │   ├── ci-log-scale-4kpersec-5klogline.yaml
│   │   ├── cleanup.sh
│   │   ├── containerlogv2/                         - Subdirectory for container log v2 specific tests.
│   │   ├── deploy.sh
│   │   ├── log-generator-job-app.yaml
│   ├── e2e                                         - End-to-end test configurations and source files for Azure ARC conformance testing.
│   │   ├── conformance.yaml                        - Configuration and image info for ARC conformance test.
│   │   ├── e2e-tests.yaml                          - Tests for conformance validation.
│   │   ├── src/                                    - Source code for e2e tests.
│   ├── fluent-bit-windows                          - Fluent Bit configuration for Windows.
│   │   ├── fluent-bit-windows.yaml
│   ├── ginkgo-e2e                                  - Ginkgo-based e2e test utilities and configurations.
│   │   ├── containerstatus/                        - Test container logs have no errors, containers are running, and all processes are running.
│   │   ├── livenessprobe/                          - Test that the pods detect and restart when a process is not running.
│   │   ├── querylogs/                              - Test that the data is flowing to log analytics workspace as expected.
│   │   ├── utils/                                  - Generalized utils functions for the test suites to use.
│   ├── onboarding-templates-legacy-auth            - Templates for onboarding with legacy authentication.
│   │   ├── existingClusterOnboarding.json
│   │   ├── existingClusterParam.json
│   ├── prometheus-scraping                         - Prometheus scraping configurations and reference apps.
│   │   ├── prom-service-for-rs-scraping.yaml
│   │   ├── prometheus-reference-app.yaml
│   │   ├── win-prometheus-ref-app-ltsc2019.yml
│   │   ├── win-prometheus-ref-app-ltsc2022.yml
│   ├── scenario                                    - Scenario-based test configurations and YAML files.
│   │   ├── log-app-win-ltsc2019.yml
│   │   ├── log-app-win-ltsc2022.yml
│   │   ├── log-generator-app.yaml
│   │   ├── multiline/                              - Subdirectory for multiline log tests.
│   │   ├── yamls/                                  - Subdirectory for additional YAML configurations.
│   ├── testkube                                    - Testkube-related configurations and scripts.
│   │   ├── api-server-permissions.yaml             - Permissions for the TestKube runner pods to call the API server.
│   │   ├── custom-job-template.yaml                - Custom job template which makes sure testkube executors runs only on linux nodes.
│   │   ├── executors.json                          - Testkube executors used for ginkgo in compact json format. The base64 encoded string of this will be used in testkube helm chart.
│   │   ├── helm-testkube-values.yaml               - Customized testkube helm chart values which pulls the data from MCR and schedule all the pods on linux nodes.
│   │   ├── install-and-execute-testkube-tests.sh   - The script used to install and execute testkube tests on a given cluster. This is used in .pipelines\azure_pipeline_testframework.yaml.
│   │   ├── testkube-teams-integration.yaml         - Teams webhook integration with testkube.
│   │   ├── testkube-test-crs.yaml                  - CRs for TestKube test suites and tests for AKS CI/CD clusters.
│   ├── unit-tests                                  - Unit test drivers and canned API responses.
│   │   ├── canned-api-responses/                   - Subdirectory for canned API responses.
│   │   ├── run_go_tests.sh
│   │   ├── run_ruby_tests.sh
│   │   ├── test_driver.rb
````

In this document, we will be covering ginkgo-e2e and testkube folders in detail. Support for more folders will be added soon.


# Ginkgo
Tests are run using the [Ginkgo](https://onsi.github.io/ginkgo/) test framework. This is built upon the regular go test framework. It's advantages are that it:
- Has an easily readable test structure using the `Behavior-Driven Development` model that's used in many languages and is applicable outside of GoLang. This model follows a `Given..., When..., Then...` structure. This is implemented in Ginkgo using the `Describe()`, `Context()`, and `It()`/`Specify()` functions. The Ginkgo documentation on [Writing Specs](https://onsi.github.io/ginkgo/#writing-specs) has many examples of this.
- Utilizes the [Gomega assertion package](https://onsi.github.io/gomega/) for easily understandable test failure errors with the goal that the output will tell you exactly what failed.
- Has good support for parallelization and structuring which tests should be run in series and which can be run at the same time to speed up the tests.
- Has extensive documentation and examples from OSS community.

Ginkgo can be used for any tests written in golang, whether they are unit, integration, or e2e tests.

## Bootstrap a Dev Cluster to Run Ginkgo Tests
- Follow [this](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-portal?tabs=azure-cli) to create a test cluster and connect to it.
- Install [Ginkgo](https://onsi.github.io/ginkgo/#getting-started).
- Navigate to any folder in ./ginkgo-e2e and run command `ginkgo` to trigger the tests on the running cluster.
- Please note that you don't need testkube to be installed on the cluster to trigger the tests locally on a cluster.
- You can customize which tests are run with `--label-filter`:
  - `--label-filter='!/./` is an expression that runs all tests that don't have a label.
  - `--label-filter='!/./ || LABELNAME` is an expression that runs all tests that don't have a label and tests that have the label `LABELNAME`.
  - `--label-filter='!(arc-extension,windows)'` is an expression that runs all tests, including those with labels, except for tests labeled `arc-extension` or `windows`.
- To run only one package of tests, add the path to the tests in the command. For example, to only run the livenessprobe tests on your cluster:
  ```
  ginkgo -p -r --keep-going ./livenessprobe
  ```
- For more uses of the Ginkgo CLI, refer to the [docs](https://onsi.github.io/ginkgo/#ginkgo-cli-overview).


#### Packages
- [k8s.io/client-go/kubernetes](https://pkg.go.dev/k8s.io/client-go/kubernetes)
- [k8s.io/api/core/v1](https://pkg.go.dev/k8s.io/api/core/v1)
- [azure-sdk-for-go](https://github.com/Azure/azure-sdk-for-go)

# TestKube
[Testkube](https://docs.testkube.io/) is an OSS runner framework for running the tests inside a Kubernetes cluster. It is deployed as a helm chart on the cluster. Ginkgo is included as one of the out-of-the-box executors supported.

Behind the scenes, tests and executors are custom resources. Running a test starts a job that deploys the test executor pod which runs the Ginkgo tests (or a different framework setup).

Some highlights are that:
- Includes test history, pass rate, and execution times.
- Friendly user interface and easy Golang integration with out-of-the-box Ginkgo runner.
- A [Teams channel notification](https://docs.testkube.io/articles/webhooks#microsoft-teams) can integrated with testkube for notifying if a test failed. These tests can be run after every merge to main or scheduled to be run on an interval.
- Test suites can be created out of tests with a dependency flowchart that can be set up for if some tests should run at the same time or after others, or only run if one succeeds.
- There are many other test framework integrations including curl and postman for testing Kubernetes services and their APIs. There is also a k6 and jmeter integration for performance testing Kubernetes services.


## Getting Started
- Install the CLI on linux/WSL:
  ```bash
    wget -qO - https://repo.testkube.io/key.pub | sudo apt-key add -
    echo "deb https://repo.testkube.io/linux linux main" | sudo tee -a /etc/apt/sources.list
    sudo apt-get update
    sudo apt-get install -y testkube
  ```
  Other OS installation instructions are [here](https://docs.testkube.io/articles/install-cli/).
- Install the [helm chart](https://docs.testkube.io/articles/helm-chart/) on your cluster:
  ```bash
    cd ./testkube
    helm repo add kubeshop https://kubeshop.github.io/helm-charts
    helm repo update
    helm upgrade --install --create-namespace testkube kubeshop/testkube -n testkube -f ./helm-testkube-values.yaml
  ```
- The helm chart will install in the namespace `testkube`.
- To uninstall testkube:
  ```bash
    helm uninstall testkube -n testkube
  ```
- Create a test connected to the Github repository and branch. Tests are a custom resource behind the scenes and can be created with the CLI, or applying a CR. Create testkube tests/suites on the cluster:
  ```bash
    cd ./testkube
    kubectl apply -f testkube-test-crs.yaml
- Apply the yaml [api-server-permissions.yaml](./testkube/api-server-permissions.yaml) to update the permissions needed for the Ginkgo executor to be able to make calls to the API server:
  ```bash
    cd ./testkube
    kubectl apply -f api-server-permissions.yaml
  ```
- Run the tests on the cluster using testkube:
  ```bash
    cd ./testkube
    kubectl testkube run testsuite <test suite name> --job-template ./custom-job-template.yaml --verbose
  ```
  To run querylogs, update tenant id and client id of managed identity which has "Log Analytics Reader" permission in testkube-test-crs.yaml and re-apply it to the cluster.
  The above commend will return exectuion id of the running tests/suite. You can watch the tests running or get the logs once the job is completed using:
  ```bash
    kubectl testkube watch testsuiteexecution $execution_id

    kubectl testkube get testsuiteexecution $execution_id
  ```

## Issues and fixes for CICD clusters:
This section is specific to CICD clusters setup for testing. Testkube installation was failing on CICD clusters due to following issues:
1. Azure policy applied on the cluster only allows the images to be pulled from MCR or ACR.
   - [Fix]: Pulled all the images used in testkube (get the list from helm chart values) and uploaded to ACR which internally syncs to MCR. Changed the image's registry and repository to pull the images from MCR.
   - You would notice that some images have a tag in the format of image_tag i.e. mongodb_6.0.5-debian-11-r64, which means mongodb image with tag 6.0.5-debian-11-r64 was pulled from original repo and pushed to ACR, while the others are in the format similar to testkube-api-server which means the latest testkube-api-server image was pulled and pushed to ACR. This is decided based on the tag which was used in the helm chart values to pull the image from original repository (i.e docker).
2. Testkube pods were getting scheduled on Windows node.
   - [Fix]: Testkube doesn't supprt windows node. Used nodeSelector setting to ensure the pods were scheduling on linux node always. Notice that 'nats' has a different format to ensure the pod was getting scheduled on linux nodes.
3. Testkube executors getting scheduled on Windows node.
   - [Fix]: Create a json of all the executors required i.e. init-executor and ginkgo-executor from [supported executors](https://github.com/kubeshop/helm-charts/blob/ed3bf1ca91e7c50f582c8528c2b0531ec3a5e9ef/charts/testkube-api/templates/_executors.json.tpl). Create a base64-encoded string out of it and replace the value of "executors" attribute in the helm chart values.


## Upgrading
### Upgrade Testkube version
1. Connect to the CI/CD cluster to have your kubeconfig pointing to it in your terminal.
2. Have the lasted version of the [TestKube CLI](https://docs.testkube.io/articles/install/cli) installed in your terminal.
3. Export the latest helm chart values file, check out the [documentation](https://docs.testkube.io/articles/install/install-with-helm#installing).
4. Pull all the images locally with tag mentioned in the values file and push it to MCR.
5. Update helm chart values to pull the images from MCR.

### Upgrade Golang Version
1. The required Golang version in the `go.mod` files in the `ginkgo-e2e` directory will always need to be `<=` the Golang version of the TestKube Ginkgo runner.  
2. Check the Golang version of the TestKube Ginkgo runner in the [Dockerfile](https://github.com/kubeshop/testkube/blob/main/contrib/executor/ginkgo/build/agent/Dockerfile) of the TestKube repo.
3. Update the version in the `go.mod` files.


## Creating a New Test or Test Suite
- Follow [Ginkgo](https://onsi.github.io/ginkgo/#getting-started) to write a new test/suite.
- Any test added inside a test suite will automatically be picked up to run after merging to main.
- Any test suite added should be included in [testkube-test-crs.yaml](./testkube/testkube-test-crs.yaml) that will be applied on the CI/CD clusters.
- Any additional permissions needed for access to the API server should be added to [api-server-permissions.yaml](./testkube/api-server-permissions.yaml).