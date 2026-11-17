#!/bin/bash

source "$(dirname "$0")/../test_framework.sh"

MAIN_SH="$(dirname "$0")/../../../kubernetes/linux/main.sh"
ENV_HELPER=$(sed -n '/^setGlobalEnvVar() {$/,/^}$/p' "$MAIN_SH")
RUNTIME_DETECTION=$(sed -n '/^      if \[ ! -z "\$podWithValidContainerId" \]; then$/,/^      export KUBELET_RUNTIME_OPERATIONS_TOTAL_METRIC=/p' "$MAIN_SH" | sed '$d')

if [ -z "$ENV_HELPER" ] || [ -z "$RUNTIME_DETECTION" ]; then
    echo "Could not extract kubelet environment startup code from $MAIN_SH"
    exit 1
fi

# Exercise the production helper without writing to the agent's /opt directory.
source <(printf '%s\n' "$ENV_HELPER" | sed 's|/opt/env_vars|"$TEST_DIR/env_vars"|g')

check_kubelet_environment() {
    local container_id="$1"
    local node_name="$2"
    local expected_runtime="$3"
    local expected_node="$4"
    local response="${5:-pod}"
    local original_dir="$PWD"

    setup
    local HOME="$TEST_DIR"
    export HOME
    cd "$TEST_DIR" || return 1
    touch env_vars glob_match
    printf 'source "%s/env_vars"\n' "$TEST_DIR" > "$HOME/.bashrc"

    local CONTAINER_RUNTIME="containerd"
    local NODE_NAME=""
    local HOSTNAME="original-host"
    export CONTAINER_RUNTIME NODE_NAME HOSTNAME
    local podWithValidContainerId
    if [ "$response" == "empty" ]; then
        podWithValidContainerId=""
    elif [ "$response" == "null" ]; then
        podWithValidContainerId="null"
    else
        podWithValidContainerId=$(jq -cn --arg id "$container_id" --arg node "$node_name" \
            '{status: {containerStatuses: [{containerID: $id}]}, spec: {nodeName: $node}}')
    fi

    source <(printf '%s\n' "$RUNTIME_DETECTION")
    assert_equals "$expected_runtime" "$CONTAINER_RUNTIME" "(runtime at startup)"
    assert_equals "$expected_node" "$NODE_NAME" "(node name at startup)"
    local expected_hostname="${expected_node:-original-host}"
    assert_equals "$expected_hostname" "$HOSTNAME" "(hostname at startup)"

    # Reload in fresh shells twice, as subsequent startup shells source .bashrc.
    local reload
    for reload in 1 2; do
        local actual_runtime actual_hostname
        actual_runtime=$(bash --noprofile --norc -c 'source "$HOME/.bashrc"; printf "%s" "$CONTAINER_RUNTIME"')
        actual_hostname=$(bash --noprofile --norc -c 'source "$HOME/.bashrc"; printf "%s" "$HOSTNAME"')
        assert_equals "$expected_runtime" "$actual_runtime" "(runtime reload $reload)"
        assert_equals "$expected_hostname" "$actual_hostname" "(hostname reload $reload)"
    done
    local marker_created=false
    if [ -e injection_marker ]; then
        marker_created=true
    fi
    assert_equals false "$marker_created" "(values must not execute shell commands)"

    cd "$original_dir" || return 1
    teardown
}

test_supported_runtimes() {
    local runtime
    for runtime in containerd docker cri-o; do
        check_kubelet_environment "$runtime://abc123" "aks-node-01" "$runtime" "aks-node-01"
    done
    check_kubelet_environment "CONTAINERD://abc123" "AKS-NODE-01" "containerd" "aks-node-01"
}

test_missing_kubelet_values() {
    check_kubelet_environment "" "" "containerd" ""
    check_kubelet_environment "null" "null" "containerd" ""
    check_kubelet_environment "" "" "containerd" "" "empty"
    check_kubelet_environment "" "" "containerd" "" "null"
}

test_kubelet_values_are_literal() {
    local value
    local values=(
        'value$(touch injection_marker)'
        'value`touch injection_marker`'
        'value; touch injection_marker; #'
        "value'; touch injection_marker; #"
        'value"; touch injection_marker; #'
        $'first\n$(touch injection_marker)\nlast'
        ' spaces * ? [glob] \n $HOME '
        '-n'
    )
    for value in "${values[@]}"; do
        local expected
        expected=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
        check_kubelet_environment "$value://abc123" "$value" "$expected" "$expected"
    done
}

test_supported_runtimes
test_missing_kubelet_values
test_kubelet_values_are_literal
print_test_summary
