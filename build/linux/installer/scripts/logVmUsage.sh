#!/bin/bash

# Log file to store the output
LOG_FILE="/var/log/process_vm_usage.log"

# Function to log memory usage for each running process
log_vm_usage() {
  echo "Time: $(date)" >> "$LOG_FILE"
  for pid in $(ps -e -o pid | tail -n +2); do
    if [ -f "/proc/$pid/status" ]; then
      command=$(cat /proc/$pid/cmdline | tr '\0' ' ')
      vm_usage=$(cat /proc/$pid/status | grep Vm)
      echo "Command: $command" >> "$LOG_FILE"
      echo "Vm Usage: $vm_usage" >> "$LOG_FILE"
      printf "\n" >> "$LOG_FILE"
    fi
  done
  echo "------------------------" >> "$LOG_FILE"
}

# Infinite loop to log every 5 minutes
while true; do
  log_vm_usage
  sleep 300 # Wait for 5 minutes
done