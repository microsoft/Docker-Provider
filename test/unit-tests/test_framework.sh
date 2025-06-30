#!/bin/bash

# Test framework utilities for shell script unit testing

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test environment setup
setup_test_env() {
    # Create temporary directory for test artifacts
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
}

# Test environment cleanup
cleanup_test_env() {
    # Remove temporary test directory
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Mock file creation helper
mock_file() {
    local file_path="$1"
    local content="$2"
    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
}

# Assertion helpers
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ Test passed${NC}: Expected '$expected', got '$actual' $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed${NC}: Expected '$expected', but got '$actual' $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Print test summary
print_test_summary() {
    echo ""
    echo "Test Summary:"
    echo "============"
    echo "Total tests: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Run before each test
setup() {
    # Create a fresh test environment
    setup_test_env

    # Create mock directories that tests might need
    mkdir -p "$TEST_DIR/etc/ama-logs-secret"
}

# Run after each test
teardown() {
    # Clean up test artifacts
    cleanup_test_env

    # Clear any environment variables set during tests
    unset CLUSTER_CLOUD_ENVIRONMENT
}
