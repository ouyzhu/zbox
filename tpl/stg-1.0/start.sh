#!/bin/bash

# Source Env
source ZBOX_STG_FULLPATH/bin/common.sh

# Check is Running
if func_is_running ; then
	func_techo INFO "Already running, skip starting action"
	func_techo INFO "process info: $(func_proc_info)"
	exit 0
fi

# Start and record pid
func_techo INFO "Starting ..."
${CMD_START} >> "${FILE_LOG}" 2>&1 &
func_record_pid $!

# Check start result
sleep ${CONF_START_WAIT}
if func_is_running ; then
	func_techo INFO "Success"
	func_techo INFO "process info: $(func_proc_info)"
else
	func_techo ERROR "Failed, please check!"
fi
