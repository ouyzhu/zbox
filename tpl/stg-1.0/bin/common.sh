#!/bin/bash

# VARIABLES - defaults, might overwirte by definition in env.sh
CONF_STOP_WAIT_MAX=18
CONF_START_WAIT_MAX=8
CONF_START_RECORD_PID=true
FILE_PID="ZBOX_STG_FULLPATH/pidfile" 
FILE_LOG="ZBOX_STG_FULLPATH/logs/default.log"

# FUNCTIONS
func_param_check() {
	# NOT use desc/usage var name, so invoker could call 'func_param_check 2 "$@"' instead of 'func_param_check 2 "${desc}\n${usage}\n" "$@"'
	local s_usage="Usage: ${FUNCNAME[0]} <count> <string> ..."
	local s_desc="Desc: check if parameter number >= <count>, otherwise print error_msg and exit. If invoker defined var desc/usage, error_msg will be \${desc}\\\\n\${usage}\\\\n, ohterwise use default"
	local s_warn="Warn: (YOU SCRIPT HAS BUG) might be: \n\t1) NOT provide <count> or any <string> \n\t2) called ${FUNCNAME[0]} but actually not need to check" 

	# self parameter check. use -lt, so the exit status will not changed in legal condition
	[ $# -lt 1 ] && func_die "${s_warn}\n${s_desc}\n${s_usage}\n"	
	
	local count=$1
	shift

	# shellcheck disable=2015
	[[ "${count}" =~ ^[-]*[0-9]+$ ]] && (( count > 0 )) || func_die "ERROR: <count> of ${FUNCNAME[0]}, must be a positive number"

	# do NOT call func_is_str_blank here, which cause infinite loop and "Segmentation fault: 11"
	local error_msg="${desc}\n${usage}\n"
	[ -z "${error_msg//[[:blank:]\\n]}" ] && error_msg="ERROR: parameter counts less than expected (expect ${count}), and desc/usage NOT defined."

	# real parameter check
	[ $# -lt "${count}" ] && func_die "${error_msg}"
}

func_die() {
	local usage="Usage: ${FUNCNAME[0]} <error_info>" 
	local desc="Desc: echo error info to stderr and exit" 
	[ $# -lt 1 ] && echo -e "${desc}\n${usage}\n" && exit 1
	
	echo -e "$@" 1>&2
	exit 1 
	# ~signal@bash: -INT NOT suitable, as it actually only breaks from function
	#func_is_non_interactive && exit 1 || kill -INT $$
}

func_techo() {
	local usage="Usage: ${FUNCNAME[0]} <level> <msg>" 
	local desc="Desc: echo msg format: <TIME>: <level-in-uppercase>: <msg>"
	func_param_check 2 "$@"
	
	echo -e "$(date "+%Y-%m-%d %H:%M:%S") ${1^^}: ${2}"
}

func_is_str_blank() {
	local usage="Usage: ${FUNCNAME[0]} <string...>"
	local desc="Desc: check if string is blank (or not defined), return 0 if blank, otherwise 1" 
	func_param_check 1 "$@"
	
	# remove all space and use -z to check
	[ -z "${1//[[:blank:]]}" ] && return 0 || return 1
}

func_is_int() {
	local usage="Usage: ${FUNCNAME[0]} <param>"
	local desc="Desc: return 0 if the param is integer, otherwise will 1" 
	func_param_check 1 "$@"
	
	# NOTE: no quote on the pattern part!
	local num="${1}"
	[[ "${num}" =~ ^[-]?[0-9]+$ ]] && return 0 || return 1
}

func_is_int_in_range() {
	local usage="Usage: ${FUNCNAME[0]} <num> <start> <end>"
	local desc="Desc: return 0 if <num> is number and in range <start> ~ <end>, otherwise return 1" 
	func_param_check 3 "$@"

	local num="${1}"
	local start="${2}"
	local end="${3}"

	func_is_int "${num}" && (( num >= start )) && (( num <= end )) && return 0 || return 1
}

func_remove_pid() {
	if [ "${CONF_START_RECORD_PID}" = "true" ] ; then
		rm -f "${FILE_PID}"
	fi
}

func_record_pid() {
	if [ "${CONF_START_RECORD_PID}" = "true" ] ; then
		echo $! > "${FILE_PID}"
	fi
}

func_proc_info() {
	# Check via pidfile
	if [ -f "${FILE_PID}" ] ; then
		local pid="$(cat "${FILE_PID}")"
		ps -ef | grep "${pid}" | grep -v grep
		return 0
	fi

	if [ -n "${PROC_NAME}" ] ; then
		echo "NOTE: no pidfile found, try grep proc name: ${PROC_NAME}"
		ps -ef | grep "${PROC_NAME}" | grep -v grep
		return 0
	fi

	return 1
}

func_is_running() {
	# Check file existence
	if [ ! -f "${FILE_PID}" ] ; then
		return 1
	fi

	# Check pid not empty
	local pid="$(cat "${FILE_PID}")"
	if func_is_str_blank "${pid}" ; then
		return 1
	fi

	# POSIX way, better compatible on diff os
	ps -o pid= -p "${pid}" | grep -q "${pid}"
}

# Source tool's env
if [ ! -f ZBOX_STG_FULLPATH/bin/env.sh ] ; then
	func_die "ERROR: env.sh NOT exist, please check!"
fi
source ZBOX_STG_FULLPATH/bin/env.sh

# Check manditary vars
for v in CMD_START FILE_LOG ; do
	func_is_str_blank ${!v} && func_die "ERROR: manditary var (name: ${v}) NOT defined, pls check"
done

# Check vars types
func_is_int_in_range "${CONF_STOP_WAIT_MAX}" 0 100 || CONF_STOP_WAIT_MAX=10
func_is_int_in_range "${CONF_START_WAIT_MAX}" 0 100 || CONF_START_WAIT_MAX=1
