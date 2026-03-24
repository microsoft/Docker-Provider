#!/bin/bash
# setup-procstat.sh
# Renames binaries and optionally injects procstat config for process monitoring.
#
# Usage: setup-procstat.sh <prefix> [inject-procstat]
#   prefix:           ama-logs | ama-logs-rs | ama-logs-prom
#   inject-procstat:  "true" to append procstat blocks to telegraf.conf (DS only)

set -e

PREFIX="$1"
INJECT_PROCSTAT="${2:-false}"

# --- Rename binaries so procstat can distinguish processes across containers ---
cp /usr/sbin/mdsd "/usr/sbin/${PREFIX}-mdsd"
sed -i "s|mdsd \${MDSD_AAD_MSI_AUTH_ARGS}|${PREFIX}-mdsd \${MDSD_AAD_MSI_AUTH_ARGS}|g" /opt/main.sh

cp /usr/bin/fluent-bit "/usr/bin/${PREFIX}-fluent-bit"
sed -i "s|fluent-bit -c|${PREFIX}-fluent-bit -c|g" /opt/main.sh

cp /opt/telegraf "/opt/${PREFIX}-telegraf"
sed -i "s|/opt/telegraf --config|/opt/${PREFIX}-telegraf --config|g" /opt/main.sh

# --- Inject procstat config blocks into telegraf.conf (only for DS container) ---
if [ "$INJECT_PROCSTAT" = "true" ]; then
  TELEGRAF_CONF="/etc/opt/microsoft/docker-cimprov/telegraf.conf"

  PROCS="ama-logs-fluent-bit ama-logs-mdsd ama-logs-telegraf"
  PROCS="$PROCS ama-logs-rs-fluent-bit ama-logs-rs-mdsd ama-logs-rs-telegraf"
  PROCS="$PROCS ama-logs-prom-mdsd ama-logs-prom-fluent-bit ama-logs-prom-telegraf"
  PROCS="$PROCS ruby crond inotifywait mdsd"

  for proc in $PROCS; do
    cat >> "$TELEGRAF_CONF" <<PROCSTAT_EOF

[[inputs.procstat]]
  name_prefix = "t.azm.ms/"
  exe = "$proc"
  interval = "60s"
  pid_finder = "native"
  pid_tag = true
  name_override = "agent_telemetry"
  fieldpass = ["cpu_usage", "memory_rss", "memory_swap", "memory_vms", "memory_stack"]
  [inputs.procstat.tags]
    Computer = "\$NODE_NAME"
    AgentVersion = "\$AGENT_VERSION"
    ControllerType = "\$CONTROLLER_TYPE"
    AKS_RESOURCE_ID = "\$TELEMETRY_AKS_RESOURCE_ID"
    ACSResourceName = "\$TELEMETRY_ACS_RESOURCE_NAME"
    Region = "\$TELEMETRY_AKS_REGION"
PROCSTAT_EOF
  done
fi

exec /opt/main.sh
