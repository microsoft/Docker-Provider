#!/bin/bash

source "$(dirname "$0")/../test_framework.sh"

# Load only the configuration function, not the agent startup script.
main_script="$(dirname "$0")/../../../kubernetes/linux/main.sh"
eval "$(sed -n '/^setCloudSpecificApplicationInsightsConfig() {$/,/^}$/p' "$main_script")"
declare -F setCloudSpecificApplicationInsightsConfig >/dev/null || exit 1

setup_test_env
trap cleanup_test_env EXIT
export HOME="$TEST_DIR"
touch "$HOME/.bashrc"

setCloudSpecificApplicationInsightsConfig azuredeloscloud
assert_equals "f2a4e81f-3974-d7b0-a1bb-4f360bb27e7c" "$(printf '%s' "$APPLICATIONINSIGHTS_AUTH" | base64 -d)" "Delos key"
assert_equals "https://deloscloudgermanycentral-0.in.applicationinsights.sovcloud-api.de/v2/track" "$APPLICATIONINSIGHTS_ENDPOINT" "Delos endpoint"
assert_equals "$APPLICATIONINSIGHTS_AUTH" "$(bash -c 'source "$HOME/.bashrc"; printf "%s" "$APPLICATIONINSIGHTS_AUTH"')" "key exported to child processes"

setCloudSpecificApplicationInsightsConfig azurebleucloud
assert_equals "560bc2b7-2cf8-b7d4-b8a2-c3caba857133" "$(printf '%s' "$APPLICATIONINSIGHTS_AUTH" | base64 -d)" "Bleu key unchanged"
assert_equals "https://bleufrancecentral-0.in.applicationinsights.sovcloud-api.fr/v2/track" "$APPLICATIONINSIGHTS_ENDPOINT" "Bleu endpoint unchanged"

print_test_summary
