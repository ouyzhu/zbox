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
for f in $(seq 1 ${CONF_START_WAIT_MAX}) ; do
	if ! func_is_running ; then
		func_techo INFO "waiting process to start (${f}s)"
		sleep 1
		continue
	fi

	func_techo INFO "Start success, process info: $(func_proc_info)"
	exit
done

func_techo ERROR "Start failed, waited ${CONF_START_WAIT_MAX} seconds and proc still NOT up, please check!"
