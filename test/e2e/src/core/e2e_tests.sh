#!/bin/sh

results_dir="${RESULTS_DIR:-/tmp/results}"

# saveResults prepares the results for handoff to the Sonobuoy worker.
# See: https://github.com/vmware-tanzu/sonobuoy/blob/master/docs/plugins.md
saveResults() {
    cd ${results_dir}

    # Sonobuoy worker expects a tar file.
	tar czf results.tar.gz *

	# Signal to the worker that we are done and where to find the results.
	printf ${results_dir}/results.tar.gz > ${results_dir}/done
}

# Ensure that we tell the Sonobuoy worker we are done regardless of results.
trap saveResults EXIT

# The variable 'TEST_LIST' should be provided if we want to run specific tests. If not provided, all tests are run

NUM_PROCESS=$(pytest /e2etests/ --collect-only  -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST" | grep "<Function\|<Class" -c)

export NUM_TESTS="$NUM_PROCESS"

pytest /e2etests/ --junitxml=/tmp/results/results.xml -d --tx "$NUM_PROCESS"*popen -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST"
