#!/bin/bash

#test to exit non zero value
(ps -ef | grep omsagent | grep -v "grep") && (ps -ef | grep td-agent-bit | grep -v "grep")
if [ $? -eq 0 ] && [ ! -s "inotifyoutput.txt" ]
then
  # inotifyoutput file is empty and the grep commands for omsagent and td-agent-bit succeeded
  exit 0
else
  if [ -s "inotifyoutput.txt" ]
  then
    # inotifyoutput file has data(config map was applied)
    echo "config changed" > /dev/termination-log
    exit 1
  else
    # grep commands for omsagent or td-agent-bit failed
    echo "agent or fluentbit not running" > /dev/termination-log
    exit 1
  fi
fi