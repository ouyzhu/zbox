#!/bin/bash

# Source Env
source ZBOX_STG_FULLPATH/bin/common.sh

if func_is_running ; then
	func_techo INFO "Running: $(func_proc_info)"
else
	func_techo INFO "Not running."
fi

