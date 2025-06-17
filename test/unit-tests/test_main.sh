#!/bin/bash

# Main test runner for all unit tests

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directory where test cases are located
TEST_CASES_DIR="$(dirname "$0")/test_cases"

# Variables to track overall test results
TOTAL_TESTS_RUN=0
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0

# Find and run all test files
run_all_test_files() {
    echo -e "${BLUE}Running all unit tests...${NC}"
    echo "========================="

    # Track if any test suite failed
    local any_suite_failed=0

    # Find all test files in the test_cases directory
    for test_file in "$TEST_CASES_DIR"/test_*.sh; do
        if [ -f "$test_file" ]; then
            echo -e "\n${BLUE}Running tests from: $(basename "$test_file")${NC}"
            echo "----------------------------------------"

            # Make the test file executable
            chmod +x "$test_file"

            # Run the test file
            if "$test_file"; then
                echo -e "${BLUE}Completed tests from: $(basename "$test_file")${NC}"
            else
                any_suite_failed=1
                echo -e "${RED}Tests failed in: $(basename "$test_file")${NC}"
            fi
        fi
    done

    echo -e "\n${BLUE}All test suites completed.${NC}"
    return $any_suite_failed
}

# Main execution
main() {
    # Ensure the test cases directory exists
    if [ ! -d "$TEST_CASES_DIR" ]; then
        echo "Error: Test cases directory not found: $TEST_CASES_DIR"
        exit 1
    fi

    # Run all test files
    if run_all_test_files; then
        echo -e "\n${GREEN}All test suites passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some test suites failed.${NC}"
        exit 1
    fi
}

# Run main if the script is being executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
