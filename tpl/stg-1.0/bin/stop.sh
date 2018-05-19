#!/bin/bash

# Source Env
source ZBOX_STG_FULLPATH/bin/common.sh

# Check proc existence
if ! func_is_running ; then
	func_techo ERROR "process NOT running, nothing to stop"
	exit 0
fi

# Check pid
if [ -z "${pid}" ] ; then
	func_techo ERROR "pid is empty, can NOT stop anything, pls check!"
	exit 1
fi

# Stop 
pid="$(cat "${FILE_PID}")"
func_techo INFO "Stopping pid (${pid})..."
if func_is_str_blank "${CMD_STOP}" ; then
	kill "${pid}"
else
	${CMD_STOP} >> "${FILE_LOG}" 2>&1 &
fi

# Check stop result and remove pid
for f in $(seq 1 ${CONF_STOP_WAIT_MAX}) ; do
	if func_is_running ; then
		func_techo INFO "waiting process to shutdown (${f}s)"
		sleep 1
		continue
	fi
	func_techo INFO "Stop success, process info: $(func_proc_info)"
	func_remove_pid
	exit
done

func_techo ERROR "Stop failed, waited ${CONF_STOP_WAIT_MAX} seconds and proc still there. PID: ${pid}, process info: $(func_proc_info)"
