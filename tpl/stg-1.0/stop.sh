#!/bin/bash

# Source Env
source ZBOX_STG_FULLPATH/bin/common.sh

# Stop 
func_techo INFO "Stopping ..."
pid="$(cat "${FILE_PID}")"
if func_is_str_blank "${CMD_STOP}" ; then
	kill "${pid}"
else
	${CMD_STOP} >> "${FILE_LOG}" 2>&1 &
fi

# Check stop result and remove pid
if func_is_running ; then
	func_techo ERROR "Failed, please check pid (${pid})"
	func_techo INFO "process info: $(func_proc_info)"
else
	func_techo INFO "Success, killed pid (${pid})"
	func_remove_pid
fi
