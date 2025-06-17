#!/bin/bash

# Import test framework
source "$(dirname "$0")/../test_framework.sh"

# Source only the function we want to test
source "$(dirname "$0")/../test_functions/getClusterCloudEnvironment.sh"

# Test valid environment variable values
test_valid_environment_variables() {
    local test_cases=(
        "azurepubliccloud"
        "azurechinacloud"
        "azureusgovernmentcloud"
        "usnat"
        "ussec"
        "bleu"
    )

    for cloud in "${test_cases[@]}"; do
        setup
        export CLUSTER_CLOUD_ENVIRONMENT="$cloud"
        result=$(getClusterCloudEnvironment)
        assert_equals "$cloud" "$result" "(with CLUSTER_CLOUD_ENVIRONMENT=$cloud)"
        teardown
    done
}

# Test invalid environment variable value
test_invalid_environment_variable() {
    setup
    export CLUSTER_CLOUD_ENVIRONMENT="invalidcloud"
    result=$(getClusterCloudEnvironment)
    # Should fallback to default value which is "azurepubliccloud"
    # as the environment variable is not valid
    assert_equals "azurepubliccloud" "$result" "(with invalid CLUSTER_CLOUD_ENVIRONMENT)"
    teardown
}

# Test domain file fallback with valid values
test_domain_file_fallback() {
    local test_cases=(
        "opinsights.azure.com:azurepubliccloud"
        "opinsights.azure.cn:azurechinacloud"
        "opinsights.azure.us:azureusgovernmentcloud"
        "opinsights.azure.eaglex.ic.gov:usnat"
        "opinsights.azure.microsoft.scloud:ussec"
        "opinsights.sovcloud-api.fr:bleu"
    )

    for test_case in "${test_cases[@]}"; do
        setup
        local domain="${test_case%%:*}"
        local expected="${test_case#*:}"

        # Unset environment variable to test fallback
        unset CLUSTER_CLOUD_ENVIRONMENT

        # Create domain file
        mock_file "$TEST_DIR/etc/ama-logs-secret/DOMAIN" "$domain"

        result=$(getClusterCloudEnvironment)
        assert_equals "$expected" "$result" "(with domain=$domain)"
        teardown
    done
}

# Test with invalid domain file value
test_invalid_domain() {
    setup
    unset CLUSTER_CLOUD_ENVIRONMENT
    mock_file "$TEST_DIR/etc/ama-logs-secret/DOMAIN" "invalid.domain.com"

    result=$(getClusterCloudEnvironment)
    assert_equals "unknown" "$result" "(with invalid domain)"
    teardown
}

# Test with empty domain file
test_empty_domain() {
    setup
    unset CLUSTER_CLOUD_ENVIRONMENT
    mock_file "$TEST_DIR/etc/ama-logs-secret/DOMAIN" ""

    result=$(getClusterCloudEnvironment)
    assert_equals "unknown" "$result" "(with empty domain)"
    teardown
}

# Test with missing domain file
test_missing_domain_file() {
    setup
    unset CLUSTER_CLOUD_ENVIRONMENT
    # Don't create the domain file

    result=$(getClusterCloudEnvironment)
    assert_equals "azurepubliccloud" "$result" "(with missing domain file)"
    teardown
}

# Test environment variable precedence over domain file
test_env_precedence_over_domain() {
    setup
    export CLUSTER_CLOUD_ENVIRONMENT="azurepubliccloud"
    mock_file "$TEST_DIR/etc/ama-logs-secret/DOMAIN" "opinsights.azure.cn"

    result=$(getClusterCloudEnvironment)
    assert_equals "azurepubliccloud" "$result" "(env should take precedence over domain)"
    teardown
}

# Run all tests
run_all_tests() {
    echo "Running tests for getClusterCloudEnvironment..."
    echo "=============================================="

    test_valid_environment_variables
    test_invalid_environment_variable
    test_domain_file_fallback
    test_invalid_domain
    test_empty_domain
    test_missing_domain_file
    test_env_precedence_over_domain

    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
