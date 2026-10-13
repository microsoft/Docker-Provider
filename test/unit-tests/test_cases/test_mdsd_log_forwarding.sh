#!/bin/bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${TEST_ROOT}/test_framework.sh"
source <(sed -n '/^startMdsdLogForwarding() {$/,/^}$/p' "${TEST_ROOT}/../../kubernetes/linux/main.sh")

TEST_DIR=$(mktemp -d)
forwarder_pid=""
cleanup() {
    if [ -n "${forwarder_pid}" ]; then
        kill "${forwarder_pid}"
        wait "${forwarder_pid}" || [ "$?" -eq 143 ]
    fi
    rm -f "${TEST_DIR}"/mdsd.* "${TEST_DIR}/stdout" "${TEST_DIR}/stderr"
    rmdir "${TEST_DIR}"
}
trap cleanup EXIT

wait_for_line() {
    local line="$1"
    local attempt
    for ((attempt = 0; attempt < 100; attempt++)); do
        if grep -Fxq "${line}" "${TEST_DIR}/stdout"; then
            return 0
        fi
        sleep 0.1
    done
    echo "ERROR: timed out waiting for stdout line: ${line}" >&2
    cat "${TEST_DIR}/stdout" "${TEST_DIR}/stderr" >&2
    return 1
}

# Prefer the image's tail implementation; CI can also run with the host's tail.
if command -v busybox > /dev/null 2>&1; then
    tail() {
        exec busybox tail "$@"
    }
else
    echo "BusyBox unavailable; testing with the host tail implementation."
fi

MDSD_LOG="${TEST_DIR}"
printf '%s\n' "startup error" > "${MDSD_LOG}/mdsd.err"
startMdsdLogForwarding > "${TEST_DIR}/stdout" 2> "${TEST_DIR}/stderr"
forwarder_pid=$!
wait_for_line "startup error"
assert_equals "startup error" "$(cat "${MDSD_LOG}/mdsd.err")" "(existing file retained)"
assert_equals "true" "$([ -f "${MDSD_LOG}/mdsd.warn" ] && echo true)" "(missing warning file created)"

printf '%s\n' "ongoing error" >> "${MDSD_LOG}/mdsd.err"
printf '%s\n' "ongoing warning" >> "${MDSD_LOG}/mdsd.warn"
printf '%s\n' "info stays private" > "${MDSD_LOG}/mdsd.info"
wait_for_line "ongoing error"
wait_for_line "ongoing warning"

# Leave the truncated file empty for a polling interval, as required to observe copytruncate.
cp "${MDSD_LOG}/mdsd.err" "${MDSD_LOG}/mdsd.err.1"
: > "${MDSD_LOG}/mdsd.err"
sleep 2
printf '%s\n' "error after copytruncate" >> "${MDSD_LOG}/mdsd.err"
wait_for_line "error after copytruncate"

mv "${MDSD_LOG}/mdsd.warn" "${MDSD_LOG}/mdsd.warn.1"
printf '%s\n' "warning after replacement" > "${MDSD_LOG}/mdsd.warn"
wait_for_line "warning after replacement"

for line in "startup error" "ongoing error" "ongoing warning" "error after copytruncate" "warning after replacement"; do
    assert_equals "1" "$(grep -Fxc "${line}" "${TEST_DIR}/stdout")" "(forwarded exactly once)"
done
assert_equals "0" "$(grep -c '^==>' "${TEST_DIR}/stdout" || true)" "(no filename headers)"
assert_equals "0" "$(grep -Fc "info stays private" "${TEST_DIR}/stdout" || true)" "(info not forwarded)"

kill "${forwarder_pid}"
wait "${forwarder_pid}" || [ "$?" -eq 143 ]
forwarder_pid=""
MDSD_LOG="${TEST_DIR}/missing-directory"
if startMdsdLogForwarding > "${TEST_DIR}/stdout" 2> "${TEST_DIR}/stderr"; then
    echo "ERROR: forwarding unexpectedly succeeded without a log directory" >&2
    exit 1
fi
assert_equals "1" "$(grep -c '^ERROR: unable to prepare mdsd logs' "${TEST_DIR}/stderr")" "(preparation failure surfaced)"

print_test_summary
