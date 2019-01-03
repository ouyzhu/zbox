#!/bin/bash

# source ${HOME}/.myenv/myenv_lib.sh || eval "$(wget -q -O - "https://raw.github.com/stico/myenv/master/.myenv/myenv_lib.sh")" || exit 1

################################################################################
# Misc: functions
################################################################################
func_date() { date "+%Y-%m-%d";				}
func_time() { date "+%H-%M-%S";				}
func_dati() { date "+%Y-%m-%d_%H-%M-%S";		}
func_nanosec()  { date +%s%N;				}
func_millisec() { echo $(($(date +%s%N)/1000000));	}

func_die() {
	local usage="Usage: ${FUNCNAME[0]} <error_info>" 
	local desc="Desc: echo error info to stderr and exit" 
	[ $# -lt 1 ] && echo -e "${desc}\n${usage}\n" && exit 1
	
	echo -e "$@" 1>&2
	exit 1 
	# ~signal@bash: -INT NOT suitable, as it actually only breaks from function
	#func_is_non_interactive && exit 1 || kill -INT $$
}

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

func_download() {
	local usage="Usage: ${FUNCNAME[0]} <url> <target>"
	local desc="Desc: download from url to local target" 
	func_param_check 2 "$@"
	
	[ -z "${1}" ] && func_die "ERROR: url is null or empty, download failed"
	[ -f "${2}" ] && echo "INFO: file (${2}) already exist, skip download" && return 0

	# TODO: curl has a feature --metalink <addr> (if target site support), which could make use of mirrors (e.g. for failover)
	case "${1}" in
		*)		func_download_wget "$@"	;;
		#http://*)	func_download_wget "$@" ;;
		#https://*)	func_download_wget "$@" ;;
	esac
}

func_download_wget() {
	local usage="Usage: ${FUNCNAME[0]} <url> <target_dir>"
	local desc="Desc: download using wget" 
	func_param_check 2 "$@"

	# if the target exist is an file, just return
	local dl_fullpath="${2}/${1##*/}"
	[ -f "${dl_fullpath}" ] && echo "INFO: file (${dl_fullpath}) already exist, skip download" && return 0

	func_mkdir_cd "${2}" 
	echo "INFO: start download, url=${1} target=${dl_fullpath}"

	# TODO: add control to unsecure options?

	wget --progress=dot --no-check-certificate "${1}" 2>&1 | grep --line-buffered "%" | sed -u -e "s,\.,,g" 

	# Note, some awk version NOT works friendly
	# Command line explain: [Showing File Download Progress Using Wget](http://fitnr.com/showing-file-download-progress-using-wget.html)
	#wget --progress=dot --no-check-certificate ${1}	2>&1 | grep --line-buffered "%" | sed -u -e "s,\.,,g" | awk 'BEGIN{printf("INFO: Download progress:  0%")}{printf("\b\b\b\b%4s", $2)}'

	echo "" # next line should in new line
	[ -f "${dl_fullpath}" ] || func_die "ERROR: ${dl_fullpath} not found, seems download faild!"
	"cd" - &> /dev/null || func_die "ERROR: failed to cd back to previous dir"
}

# shellcheck disable=2155,2012
func_uncompress() {
	# TODO 1: gz file might be replaced and NOT in the target dir

	local usage="Usage: ${FUNCNAME[0]} <source> <target_dir>"
	local desc="Desc: uncompress file, based on filename extension, <target_dir> will be the top level dir for uncompressed content" 
	func_param_check 1 "$@"
	func_validate_path_exist "${1}"

	# use readlink to avoid relative path
	local source_file="$(readlink -f "${1}")"
	local target_dir="${source_file%.*}"

	[ -n "${2}" ] && target_dir="$(readlink -f "${2}")"
	[ -z "${target_dir}" ] && target_dir="${2}"		# NOTE: readlink -f on mac seems gets empty str, if more than last 2 level path inexist, so need "backup" here
	func_complain_path_exist "${target_dir}" && return	# seem NOT need exit, just complain is enough?

	echo "INFO: uncompress file, from: ${source_file} to: ${target_dir}"
	func_mkdir_cd "${2}"
	case "$source_file" in
		*.jar | *.arr | *.zip)
				func_complain_cmd_not_exist unzip \
				&& (sudo apt-get install unzip \
				    || sudo port install unzip) ;			# try intall
				unzip "$source_file" &> /dev/null       	;;

		*.tar.xz)	tar -Jxvf "$source_file" &> /dev/null		;;
		*.tar.gz)	tar -zxvf "$source_file" &> /dev/null		;;	# NOTE, should before "*.gz)"
		*.tar.bz2)	tar -jxvf "$source_file" &> /dev/null		;;	# NOTE, should before "*.bz2)"
		*.bz2)		bunzip2 "$source_file" &> /dev/null		;;
		*.gz)		gunzip "$source_file" &> /dev/null		;;
		*.tar)		tar -xvf "$source_file" &> /dev/null		;;
		*.xz)		tar -Jxvf "$source_file" &> /dev/null		;;
		*.tgz)		tar -zxvf "$source_file" &> /dev/null		;;
		*.tbz2)		tar -jxvf "$source_file" &> /dev/null		;;
		*.Z)		uncompress "$source_file"			;;

		*.7z)		func_complain_cmd_not_exist 7z \
				&& (sudo apt-get install p7zip \
				    || sudo port install p7zip) ;			# try intall
				7z e "$source_file" &> /dev/null		;;	# use "-e" will fail, "e" is extract, "x" is extract with full path

		*.rar)		func_complain_cmd_not_exist unrar \
				&& (sudo apt-get install unrar \
				    || sudo port install unrar);			# try intall
				unrar e "$source_file" &> /dev/null		;;	# another candidate is: 7z e "$source_file"

		*)		echo "ERROR: unknow format: ${source_file}"	;;
	esac

	func_validate_dir_not_empty "${target_dir}"

	# try to move dir level up, there might be only 1 file/dir in the uncompressed 
	if [ "$(ls -A "${target_dir}" | wc -l)" = 1 ] ; then
		mv -f "${target_dir}"/**/* "${target_dir}"/**/.* "${target_dir}"/ &> /dev/null 
		rmdir "${target_dir}"/**/ &> /dev/null 
	fi

	"cd" - &> /dev/null || func_die "ERROR: failed to cd back to previous dir"
}

func_vcs_update() {
	local usage="Usage: ${FUNCNAME[0]} <src_type> <src_addr> <target_dir>"
	local desc="Desc: init or update vcs like hg/git/svn"
	func_param_check 3 "$@"

	local src_type="${1}"
	local src_addr="${2}"
	local target_dir="${3}"
	echo "INFO: init/update source, type: ${src_type}, addr: ${src_addr}, target: ${target_dir}"
	case "${src_type}" in
		hg)	local cmd="hg"  ; local cmd_init="hg clone"     ; local cmd_update="hg pull"	;;
		git)	local cmd="git" ; local cmd_init="git clone"    ; local cmd_update="git pull"	;;
		svn)	local cmd="svn" ; local cmd_init="svn checkout" ; local cmd_update="svn update"	;;
		*)	func_die "ERROR: Can not handle src_type (${src_type})"	;;
	esac

	func_validate_cmd_exist ${cmd}
	
	if [ -e "${target_dir}" ] ; then
		pushd "${target_dir}" &> /dev/null
		${cmd_update} || func_die "ERROR: ${cmd_update} failed"
		popd &> /dev/null
	else
		mkdir -p "$(dirname "${target_dir}")"
		${cmd_init} "${src_addr}" "${target_dir}" || func_die "ERROR: ${cmd_init} failed"
	fi
}

################################################################################
# Utility: output
################################################################################
# TODO: good reference: https://github.com/Offirmo/offirmo-shell-lib/blob/master/bin/osl_lib_output.sh

################################################################################
# Utility: process
################################################################################

func_pids_of_descendants() {
	local usage="Usage: ${FUNCNAME[0]} <need_sudo> <pid>" 
	local desc="Desc: return pid list of all descendants (including self), or empty if none" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1

	func_validate_cmd_exist pstree

	local pid_num="${1}"
	if pstree --version 2>&1 | grep -q "thp.uni-due.de" ; then
		pstree -w "${pid_num}" | grep -o '\-+= \([0-9]\+\)' | grep -o '[0-9]\+' | tr '\n' ' '
	elif pstree --version 2>&1 | grep -q "PSmisc" ; then
		pstree -p "${pid_num}" | grep -o '([0-9]\+)' | grep -o '[0-9]\+' | tr '\n' ' '
	fi
}

# shellcheck disable=2009
func_pids_of_direct_child() {
	local usage="Usage: ${FUNCNAME[0]} <need_sudo> <pid>" 
	local desc="Desc: return pid list of direct childs (including self), or empty if none" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1

	local pid_num="${1}"
	if ! func_is_pid_running "${pid_num}" ; then
		return 0
	fi

	local pid_tmp
	local pid_list=""
	local regex="[ ]*([0-9]+)[ ]+${pid_num}" 
	for pid_tmp in $(ps ax -o "pid= ppid=" | grep -E "${regex}" | sed -E "s/${regex}/\1/g"); do
		pid_list="${pid_list} ${pid_tmp}"
	done
	echo "${pid_list} ${pid_num}"
}

# shellcheck disable=2009,2155,2086
func_kill_self_and_descendants() {
	local usage="Usage: ${FUNCNAME[0]} <need_sudo> <pid>" 
	local desc="Desc: kill <pid> and all its child process, return 0 if killed or not need to kill, return 1 failed to kill" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1

	local need_sudo="${1}"
	local sudo_cmd=""
	if [ "${need_sudo}" = 'true' ] ; then
		sudo_cmd="sudo"
	fi

	local pid_num="${2}"
	if ! func_is_pid_running "${pid_num}" ; then
		echo "INFO: process ${pid_num} NOT running, just return"
		return 0
	fi

	local pid_list="$(func_pids_of_descendants "${pid_num}")"
	echo "INFO: kill pid_list: ${sudo_cmd} kill -9 ${pid_list}"

	# no quote on ${sudo_cmd}, otherwise gets "cmd not found" error when empty
	${sudo_cmd} kill -9 ${pid_list}

	sleep 0.5
	local pid_tmp
	local pid_fail=''
	for pid_tmp in ${pid_list} ; do
		if func_is_pid_running "${pid_tmp}" ; then
			pid_fail="${pid_fail} ${pid_tmp}"
		fi
	done
	if [ -n "${pid_fail}" ] ; then
		echo "ERROR: failed to kill, pid_fail: ${pid_fail}"
	fi
}

func_kill_self_and_direct_child() {

	# TODO: copied from stackoverflow, but NOT verified yet
	echo "ERROR: this function is NOT ready yet!" 1>&2
	return 1

	# candidate 1: some times failed to kill, and makes child's parent pid becomes 1, because pkill NOT stable?
	# NOTE 1: pkill only sends signal to child process, grandchild WILL NOT receive the signal
	# NOTE 2: if need support multiple pid, use -P <pid1> -P <pid2> ...
	# NOTE 3: parent process might already finished, so no error output for 'kill' cmd
	# NOTE 4: why sleep 1? seems some times kill works before pkill, which cause pkill can NOT find child (since parent killed and child's parent becomes pid 1)
	#if [ "${need_sudo}" = 'true' ] ; then
	#	echo "INFO: kill cmd: sudo pkill -TERM -P ${pid_num} && sleep 1 && sudo kill -TERM ${pid_num} >/dev/null 2>&1"
	#	sudo pkill -TERM -P "${pid_num}" && sleep 1 && sudo kill -TERM "${pid_num}" >/dev/null 2>&1
	#else
	#	echo "INFO: kill cmd: pkill -TERM -P ${pid_num} && sleep 1 && kill -TERM ${pid_num} >/dev/null 2>&1"
	#	pkill -TERM -P "${pid_num}" && sleep 1 && kill -TERM "${pid_num}" >/dev/null 2>&1
	#fi

	# candidate 2: kill on group, not the "-" prefix: https://stackoverflow.com/questions/392022/best-way-to-kill-all-child-processes/6481337
	#kill -- -$PGID     Use default signal (TERM = 15)			# use process group id
	#kill -9 -$PGID     Use the signal KILL (9)				# use process group id
	#kill -- -$(ps -o pgid= $PID | grep -o '[0-9]*')   (signal TERM)	# use process id
	#kill -9 -$(ps -o pgid= $PID | grep -o '[0-9]*')   (signal KILL)	# use process id

	# candidate 3: rkill command from pslist package sends given signal (or SIGTERM by default) to specified process and all its descendants:
	#rkill [-SIG] pid/name...
}

# shellcheck disable=2155
func_is_running() {
	local usage="Usage: ${FUNCNAME[0]} <pid_file>" 
	local desc="Desc: check is pid in <pid_file> is running" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1
	
	local pid_num="$(cat "${1}" 2>/dev/null)"
	func_is_positive_int "${pid_num}" || func_die "ERROR: pid_file (${1}) NOT exist or no valid pid inside!"

	func_is_pid_running "${pid_num}"
}

func_is_pid_or_its_child_running() {
	local usage="Usage: ${FUNCNAME[0]} <pid>" 
	local desc="Desc: check is <pid> running, or any of its child running" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1

	ps -ef | grep -v grep | grep -q "[[:space:]]${1}[[:space:]]"
}

func_is_pid_running() {
	local usage="Usage: ${FUNCNAME[0]} <pid>" 
	local desc="Desc: check is <pid> running" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1
	
	func_is_str_blank "${1}" && return 1

	# NOTE: if the process is in sudo mode, 'kill -0' check will failed, at least some plf will complain permission
	# 0 is an inexist signal, but helps check if process exist
	#kill -0 "${1}" 2>/dev/null 

	# POSIX way, better compatible on diff os
	# shellcheck disable=2009
	ps -o pid= -p "${1}" | grep -q "${1}"
}

################################################################################
# Utility: logging
################################################################################
func_techo() {
	local usage="Usage: ${FUNCNAME[0]} <level> <msg>" 
	local desc="Desc: echo msg format: <level-in-uppercase>: <TIME>: <msg>"
	func_param_check 2 "$@"
	
	echo -e "$(date "+%Y-%m-%d %H:%M:%S"): ${1^^}: ${2}"
}

func_decho() {
	local usage="Usage: ${FUNCNAME[0]} <msg>" 
	local desc="Desc: echo msg as DEBUG level, based on env var ME_DEBUG=true to really show"
	func_param_check 1 "$@"
	
	[ "${ME_DEBUG}" = 'true' ] || return 0
	echo -e "DEBUG: ${1}"
}

################################################################################
# Utility: FileSystem
################################################################################
func_cd() {
	local usage="Usage: ${FUNCNAME[0]} <path>" 
	local desc="Desc: (fail fast) change dir, exit whole process if fail"
	func_param_check 1 "$@"
	
	if [ -n "${1}" ] ; then
		"cd" "${1}" || func_die "ERROR: failed to cd back to previous dir" 
		return
	fi
	func_die "ERROR: failed to change dir: cd ${1}"
}

func_mkdir() {
	local usage="Usage: ${FUNCNAME[0]} <path> ..." 
	local desc="Desc: (fail fast) create dirs if NOT exist, exit whole process if fail"
	func_param_check 1 "$@"
	
	for p in "$@" ; do
		[ -e "${p}" ] && continue
		mkdir -p "${p}" || func_die "ERROR: failed to create dir ${p}"
	done
}

func_mkdir_cd() { 
	local usage="Usage: ${FUNCNAME[0]} <path>" 
	local desc="Desc: (fail fast) create dir and cd into it. Create dirs if NOT exist, exit if fail, which is different with /bin/mkdir" 
	func_param_check 1 "$@"

	func_mkdir "$1" 
	"cd" "${1}" || func_die "ERROR: failed to mkdir or cd into it ($1)"

	# to avoid the path have blank, any simpler solution?
	#func_mkdir "$1" && OLDPWD="$PWD" && eval \\cd "\"$1\"" || func_die "ERROR: failed to mkdir or cd into it ($1)"
}

func_is_filetype_text() {
	local usage="Usage: ${FUNCNAME[0]} <path>"
	local desc="Desc: check if filetype is text, return 0 if yes, otherwise 1" 
	func_param_check 1 "$@"

	file "${1}" | grep -q text
}

func_is_dir_empty() {
	local usage="Usage: ${FUNCNAME[0]} <dir>"
	local desc="Desc: check if directory is empty or inexist, return 0 if empty, otherwise 1" 
	func_param_check 1 "$@"

	[ "$(ls -A "${1}" 2> /dev/null)" ] && return 1 || return 0
}

func_is_dir_not_empty() {
	local usage="Usage: ${FUNCNAME[0]} <dir>"
	local desc="Desc: check if directory is not empty, return 0 if not empty, otherwise 1" 
	func_param_check 1 "$@"

	[ "$(ls -A "${1}" 2> /dev/null)" ] && return 0 || return 1
}

func_validate_dir_not_empty() {
	local usage="Usage: ${FUNCNAME[0]} <dir> ..."
	local desc="Desc: the directory must exist and NOT empty, otherwise will exit" 
	func_param_check 1 "$@"
	
	for p in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		func_is_dir_empty "${p}" && func_die "ERROR: ${p} is empty!"
	done
}

func_validate_dir_empty() {
	local usage="Usage: ${FUNCNAME[0]} <dir> ..."
	local desc="Desc: the directory must be empty or NOT exist, otherwise will exit" 
	func_param_check 1 "$@"
	
	for p in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		func_is_dir_empty "${p}" || func_die "ERROR: ${p} not empty!"
	done
}

func_complain_path_exist() {
	local usage="Usage: ${FUNCNAME[0]} <path> <msg>"
	local desc="Desc: complains if path already exist, return 0 if exist, otherwise 1" 
	func_param_check 1 "$@"
	
	[ -e "${1}" ] && echo "${2:-WARN: path ${1} already exist!}" && return 0
	return 1
}

func_complain_path_not_exist() {
	local usage="Usage: ${FUNCNAME[0]} <path> <msg>"
	local desc="Desc: complains if path not exist, return 0 if not exist, otherwise 1" 
	func_param_check 1 "$@"
	
	[ ! -e "${1}" ] && echo "${2:-WARN: path ${1} NOT exist!}" && return 0
	return 1
}

func_validate_path_exist() {
	local usage="Usage: ${FUNCNAME[0]} <path> ..."
	local desc="Desc: the path must be exist, otherwise will exit" 
	func_param_check 1 "$@"
	
	for p in "$@" ; do
		[ ! -e "${p}" ] && func_die "ERROR: ${p} NOT exist!"
	done
}

func_validate_path_not_exist() { func_validate_path_inexist "$@" ;}
func_validate_path_inexist() {
	local usage="Usage: ${FUNCNAME[0]} <path> ..."
	local desc="Desc: the path must be NOT exist, otherwise will exit" 
	func_param_check 1 "$@"
	
	for p in "$@" ; do
		[ -e "${p}" ] && func_die "ERROR: ${p} already exist!"
	done
}

# shellcheck disable=2155,2012
func_validate_path_owner() {
	local usage="Usage: ${FUNCNAME[0]} <path> <owner>"
	local desc="Desc: the path must be owned by owner(xxx:xxx format), otherwise will exit" 
	func_param_check 1 "$@"

	local expect="${2}"
	local real=$(ls -ld "${1}" | awk '{print $3":"$4}')
	[ "${real}" != "${expect}" ] && func_die "ERROR: owner NOT match, expect: ${expect}, real: ${real}"
}

func_link_init() {
	local usage="Usage: ${{FUNCNAME[0]}} <target> <source>"
	local desc="Desc: the directory must be empty or NOT exist, otherwise will exit" 
	func_param_check 2 "$@"

	local target="$1"
	local source="$2"
	echo "INFO: creating link ${target} --> ${source}"

	# check, skip if target already link, remove if target empty 
	func_complain_path_not_exist "${source}" && return 0
	[ -h "${target}" ] && echo "INFO: ${target} already a link (--> $(readlink -f "${target}") ), skip" && return 0
	[ -d "${target}" ] && func_is_dir_empty "${target}" && rmdir "${target}"

	"ln" -s "${source}" "${target}"
}

# shellcheck disable=2015
func_duplicate_dated() {
	local usage="Usage: ${FUNCNAME[0]} <file> ..."
	local desc="Desc: backup file, with suffixed date" 
	func_param_check 1 "$@"
	
	for p in "$@" ; do
		func_complain_path_not_exist "${p}" && continue

		# if target is dir, check size first (>100M will warn and skip)
		if [ -d "${p}" ] ; then
			p_size=$(stat -c%s "${p}")
			p_size_h=$(func_num_to_human zip_size)
			(( p_size > 104857600 )) && echo "WARN: ${p} size (${p_size_h}) too big (>100M), skip" && continue 
		fi

		target="${p}.bak.$(func_dati)"
		echo "INFO: backup file, ${p} --> ${target}"
		if [ -w "${p}" ] ; then
			cp -r "${p}" "${target}"	|| echo "WARN: backup ${p} failed, pls check!"
		else
			sudo cp -r "${p}" "${target}"	|| echo "WARN: backup ${p} failed (with sudo priviledge), pls check!"
		fi
	done
}

################################################################################
# Utility: shell
################################################################################
func_is_non_interactive() {
	# command 1: echo $- | grep -q "i" && echo interactive || echo non-interactive
	# command 2: [ -z "$PS1" ] && echo interactive || echo non-interactive

	# NOTE: when use "bash xxx.sh", it is non-interactive

	# explain: bash manual: PS1 is set and $- includes i if bash is interactive, allowing a shell script or a startup file to test this state.
	if [ -z "$PS1" ] ; then
		return 0 
	else
		return 1
	fi
}

func_is_cmd_exist() {
	local usage="Usage: ${FUNCNAME[0]} <cmd>"
	local desc="Desc: check if cmd exist, return 0 if exist, otherwise 1" 
	func_param_check 1 "$@"

	command -v "${1}" &> /dev/null && return 0 || return 1
}

func_complain_cmd_not_exist() {
	local usage="Usage: ${FUNCNAME[0]} <cmd> <msg>"
	local desc="Desc: complains if command not exist, return 0 if not exist, otherwise 1" 
	func_param_check 1 "$@"

	func_is_cmd_exist "${1}" && return 1
	echo "${2:-WARN: cmd ${1} NOT exist!}" 
	return 0
}

func_validate_cmd_exist() {
	local usage="Usage: ${FUNCNAME[0]} <cmd> ..."
	local desc="Desc: the cmd must be exist, otherwise will exit" 
	func_param_check 1 "$@"

	for p in "$@" ; do
		func_is_cmd_exist "${p}" || func_die "ERROR: cmd (${p}) NOT exist!"
	done
}

func_is_function_exist() {
	local usage="USAGE: ${FUNCNAME[0]} <function-name>" 
	local desc="Desc: check if <function-name> exist as a function, return 0 if exist and a function, otherwise 1" 
	func_param_check 1 "$@"
	
	[ -n "$(type -t "${1}")" ] && [ "$(type -t "${1}")" = function ] && return 0 
	return 1
}

func_complain_function_not_exist() {
	local usage="USAGE: ${FUNCNAME[0]} <function-name>" 
	local desc="Desc: complain if <function-name> NOT exist as a function, return 1 if not exist or not a function, otherwise 1" 
	func_param_check 1 "$@"

	func_is_function_exist "${1}" && return 1
	echo "WARN: ${1} NOT exist or NOT a function!"
}

func_validate_function_exist() {
	local usage="USAGE: ${FUNCNAME[0]} <function-name>" 
	local desc="Desc: check if <function-name> exist as a function" 
	func_param_check 1 "$@"
	
	func_is_function_exist "${1}" && return 0
	func_die "ERROR: ${1} NOT exist or NOT a function!"
}

func_complain_privilege_not_sudoer() { 
	local usage="Usage: ${FUNCNAME[0]} <msg>"
	local desc="Desc: complains if current user not have sudo privilege, return 0 if not have, otherwise 1" 
	
	( ! sudo -n ls &> /dev/null) && echo "${2:-WARN: current user NOT have sudo privilege!}" && return 0
	return 1
}

func_pipe_filter() {
	if [ -z "${1}" ] ; then
		sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"
	else
		tee -a "${1}" | sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"
	fi
}

func_gen_local_vars() {
	local usage="Usage: ${FUNCNAME[0]} <file1> <file2> ..." 
	local desc="Desc: gen local var definition based on file sequence" 
	func_param_check 1 "$@"

	# TODO: if the file has BOMB, will fail. ignore the BOMB chars? 
	#	verify: use set a bomb cnf file in zbox, and try "zbox use xxx"

	# check file existence
	local exist_files=()
	local inexist_files=()
	for f in "$@" ; do
		if ! [ -r "${f}" ] ; then
			inexist_files+=("${f}")
			continue
		fi
		exist_files+=("${f}")
	done

	# report to stderr
	(( ${#inexist_files[*]} > 0 )) && echo "DEBUG: skip those inexist files: ${inexist_files[*]}" 1>&2
	(( ${#exist_files[*]} == 0 )) && echo "WARN: NO files really readable to gen local var: $*" 1>&2 && return 1

	# TODO: embrace value with " or ', since bash eval get error if value have special chars like &/, etc. path field almost always have such chars.
	# works but not efficient: s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
	cat "${exist_files[@]}"			\
	| sed -e "/^[[:blank:]]*\($\|#\)/d;
		s/[[:blank:]]*=[[:blank:]]*/=/;
		s/^/local /"
}

################################################################################
# Utility: platform/os
################################################################################
OS_OSX="osx"
OS_WIN="win"
OS_AIX="aix"
OS_BSD="bsd"
OS_SUSE="suse"
OS_LINUX="linux"
OS_MINGW="mingw"
OS_DEBIAN="debian"
OS_REDHAT="redhat"
OS_CYGWIN="cygwin"
OS_SOLARIS="solaris"
OS_FREEBSD="freebsd"
OS_MANDRAKE="mandrake"

func_os_name() {
	# based on release file, some NOT verified
	if [ -f /etc/lsb-release ] ; then					
		# \L is to lowercase
		sed -n -e "s/DISTRIB_ID=\(\S*\)/\L\1/p" /etc/lsb-release	
		return
	elif [ -f /etc/redhat-release ] ; then
		echo ${OS_REDHAT}
		return
	elif [ -f /etc/SuSE-release ] ; then
		echo ${OS_SUSE}
		return
	elif [ -f /etc/mandrake-release ] ; then
		echo ${OS_MANDRAKE}
		return
	elif [ -f /etc/debian_version ] ; then
		echo ${OS_DEBIAN}
		return
	fi

	local fullname
	if [ -n "$OSTYPE" ] ; then
		# bash buildin var
		fullname="${OSTYPE,,}"
	else
		func_validate_cmd_exist uname
		fullname="$(uname -o)"
		fullname="${fullname,,}"
	fi

	# longer match first, TODO: what if $OSTYPE and $(uname -a) have diff string? list both of them?
	case "${fullname}" in
		solaris*)	echo "${OS_SOLARIS}"	;return ;;
		sunos*)		echo "${OS_SOLARIS}"	;return ;;
		freebsd*)	echo "${OS_FREEBSD}"	;return ;;
		darwin*)	echo "${OS_OSX}"	;return ;; 
		cygwin*)	echo "${OS_CYGWIN}"	;return ;; 
		linux*)		echo "${OS_LINUX}"	;return ;;
		msys*)		echo "${OS_MINGW}"	;return ;;	# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
		bsd*)		echo "${OS_BSD}"	;return ;;
		win*)		echo "${OS_WIN}"	;return ;;	# NOT sure, check on windows!
		aix*)		echo "${OS_AIX}"	;return ;;	# NOT sure, check on windows!
	esac

	# final
	echo "unknown: ${OSTYPE}, ${fullname}" ;
}

func_os_ver() {
	# based on release file, some NOT verified
	if [ -e /etc/lsb-release ] ; then					
		sed -n -e "s/DISTRIB_RELEASE=\(\S*\)/\1/p" /etc/lsb-release
		return
	elif [ -f /etc/redhat-release ] ; then
		sed s/\ release.*// /etc/redhat-release
		#sed s/.*\(// /etc/redhat-release | sed s/\)// 
		#sed s/.*release\ // /etc/redhat-release | sed s/\ .*// 
		return
	elif [ -f /etc/SuSE-release ] ; then
		/etc/SuSE-release | sed s/VERSION.*//
		#tr "\n" ' ' /etc/SuSE-release | sed s/.*=\ //
		return
	elif [ -f /etc/mandrake-release ] ; then
		sed s/.*\(// | sed s/\)// /etc/mandrake-release
		#sed s/.*release\ // /etc/mandrake-release | sed s/\ .*//
		return
	elif [ -f /etc/debian_version ] ; then
		cat /etc/debian_version		# TODO: just cat ?
		return
	fi

	# TODO: to improve, seems returns linux kernel version, not os version
	func_validate_cmd_exist uname
	uname -r
}

# shellcheck disable=2155
func_os_len() {
	func_validate_cmd_exist uname

	# TODO 1: also use the os part to replace func_os_name()?
	# TODO 2: arm part still need improve
	# Note, cygwin is usually 32bit
	local archi="$(uname -sm)"
	case "$archi" in
		*\ *64)    echo "64bit";;
		*\ *86)    echo "32bit";;
		*\ armv5*) echo "armv5";;
		*\ armv6*) echo "armv6";;
		*\ armv7*) echo "armv7";;
		*\ armv8*) echo "armv8";;
		*)         echo "unknown";;
	esac
}

func_os_info() {
	local os_ver=${MY_OS_VER:-$(func_os_ver)}
	local os_len=${MY_OS_LEN:-$(func_os_len)}
	local os_name=${MY_OS_NAME:-$(func_os_name)}
	echo "${os_name}_${os_ver}_${os_len}"
}

################################################################################
# Utility: network
################################################################################
func_is_valid_ip() {
	local usage="Usage: ${FUNCNAME[0]} <address>" 
	local desc="Desc: check if address is valid ipv4/ipv6 address, return 0 if yes otherwise no"
	func_param_check 1 "$@"
	
	func_is_valid_ipv4 "${1}" && return 0
	func_is_valid_ipv6 "${1}" && return 0
	return 1
}

func_is_valid_ipv4() {
	local usage="Usage: ${FUNCNAME[0]} <address>" 
	local desc="Desc: check if address is valid ipv4 address, return 0 if yes otherwise no"
	func_param_check 1 "$@"
	
	# candiate: use python: socket.inet_pton(socket.AF_INET, sys.argv[1])
	# candiate: seems tool ipcalc/sipcalc could do this, but need install

	# Test
	#func_is_valid_ip4 4.2.2.2 && echo yes || echo no
	#func_is_valid_ip4 192.168.1.1 && echo yes || echo no
	#func_is_valid_ip4 0.0.0.0 && echo yes || echo no
	#func_is_valid_ip4 255.255.255.255 && echo yes || echo no
	#func_is_valid_ip4 192.168.0.1 && echo yes || echo no
	#func_is_valid_ip4 " 169.252.12.253       " && eyn
	#echo "^^^^^^^^^^^ is yes -------- vvvvvvvv below is no"
	#func_is_valid_ip4 255.255.255.256 && echo yes || echo no
	#func_is_valid_ip4 a.b.c.d && echo yes || echo no
	#func_is_valid_ip4 192.168.0 && echo yes || echo no
	#func_is_valid_ip4 1234.123.123.123 && echo yes || echo no

	# seems accurate enough
	local part="25[0-5]\|2[0-4][0-9]\|1[0-9][0-9]\|[1-9][0-9]\|[0-9]"

	# shellcheck disable=2086
	# do NOT use " around ${1}, as blank will cause ^ or $ fail in grep
	echo ${1} | grep -q "^\(${part}\)\(\.\(${part}\)\)\{3\}$"
}

func_is_valid_ipv6() {
	local usage="Usage: ${FUNCNAME[0]} <address>" 
	local desc="Desc: check if address is valid ipv6 address, return 0 if yes otherwise no"
	func_param_check 1 "$@"
	
	# candiate: https://twobit.us/2011/07/validating-ip-addresses/
	# candiate: use python: socket.inet_pton(socket.AF_INET6, sys.argv[1])

	# Test
	#func_is_valid_ip6 1:2:3:4:5:6:7:8 && eyn
	#func_is_valid_ip6 1:2:3:4:5:6:7:9999 && eyn
	#echo "^^^^^^^^^^^ is yes -------- vvvvvvvv below is no"
	#func_is_valid_ip6 1:2:3:4:5:6:7: && eyn
	#func_is_valid_ip6 1:2:3:4:5:6:7:9999999 && eyn

	# Source: http://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses
	# Comment: use POSIX regex, seems have some flaw, improve it if really need to 
	local RE_IPV6
	local RE_IPV4="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"
	RE_IPV6="([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|"                    # TEST: 1:2:3:4:5:6:7:8
	RE_IPV6="${RE_IPV6}([0-9a-fA-F]{1,4}:){1,7}:|"                         # TEST: 1::                              1:2:3:4:5:6:7::
	RE_IPV6="${RE_IPV6}([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|"         # TEST: 1::8             1:2:3:4:5:6::8  1:2:3:4:5:6::8
	RE_IPV6="${RE_IPV6}([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|"  # TEST: 1::7:8           1:2:3:4:5::7:8  1:2:3:4:5::8
	RE_IPV6="${RE_IPV6}([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|"  # TEST: 1::6:7:8         1:2:3:4::6:7:8  1:2:3:4::8
	RE_IPV6="${RE_IPV6}([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|"  # TEST: 1::5:6:7:8       1:2:3::5:6:7:8  1:2:3::8
	RE_IPV6="${RE_IPV6}([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|"  # TEST: 1::4:5:6:7:8     1:2::4:5:6:7:8  1:2::8
	RE_IPV6="${RE_IPV6}[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|"       # TEST: 1::3:4:5:6:7:8   1::3:4:5:6:7:8  1::8
	RE_IPV6="${RE_IPV6}:((:[0-9a-fA-F]{1,4}){1,7}|:)|"                     # TEST: ::2:3:4:5:6:7:8  ::2:3:4:5:6:7:8 ::8       ::     
	RE_IPV6="${RE_IPV6}fe08:(:[0-9a-fA-F]{1,4}){2,2}%[0-9a-zA-Z]{1,}|"     # TEST: fe08::7:8%eth0      fe08::7:8%1                                      (link-local IPv6 addresses with zone index)
	RE_IPV6="${RE_IPV6}::(ffff(:0{1,4}){0,1}:){0,1}${RE_IPV4}|"            # TEST: ::255.255.255.255   ::ffff:255.255.255.255  ::ffff:0:255.255.255.255 (IPv4-mapped IPv6 addresses and IPv4-translated addresses)
	RE_IPV6="${RE_IPV6}([0-9a-fA-F]{1,4}:){1,4}:${RE_IPV4}"                # TEST: 2001:db8:3:4::192.0.2.33  64:ff9b::192.0.2.33                        (IPv4-Embedded IPv6 Address)

	# shellcheck disable=2086
	# do NOT use " around ${1}, as blank will cause ^ or $ fail in grep
	echo ${1} | grep -E -q "^(${RE_IPV6})$"
}

func_ip_of_host() {
	local usage="Usage: ${FUNCNAME[0]} <host>" 
	local desc="Desc: echo one ip of the host, otherwise echo empty, return original if already an ip"
	func_param_check 1 "$@"

	# 1st Check: return original, trim spaces, as valid address not have space
	func_is_valid_ip "${1}" && echo "${1//[[:blank:]]/}" && return 0

	# 2nd Check: hardcode for localhost
	[ "${1}" = "localhost" ] && echo "127.0.0.1" && return 0

	# 3rd Check: Use /etc/hosts, faster
	if [ -r /etc/hosts ] ; then
		# shellcheck disable=2155
		local etc_val="$(grep "^[^#]*${1}[[:blank:]].*$" /etc/hosts)" 
		[ -n "${etc_val}" ] && echo "${etc_val%%[[:blank:]]*}" && return 0
	fi
	
	# 4th Check: Use os cmd, (2017-03) simple test shows, time is NOT stable on ubuntu16.04, reason is the OS or the network?
	if uname | grep -q Darwin ; then
		local result
		# dscacheutil -q host -a name "${1}" | sed '/ip_address/!d;s/^[^0-9]*//'
		result="$(dscacheutil -q host -a name "${1}")"
		echo "${result##*: }"
	else
		getent hosts "${1}" | sed "s/\s\+.*$//"
	fi

	# more ways to get ip: ping, ns-lookup, etc
	#ping -c 1 "${1%:*}" | head -1 | sed -e "s/[^(]*(//;s/).*//"	# note when host inexist
}

# shellcheck disable=2155
func_is_local_addr() {
	local usage="Usage: ${FUNCNAME[0]} <host>" 
	local desc="Desc: check if param is address of local machine, return 0 if yes, otherwise no"
	func_param_check 1 "$@"

	local addr="$(func_ip_of_host "${1}")"
	[ "${addr}" = "127.0.0.1" ] && return 0
	func_is_valid_ip "${addr}" || return 1
	func_ip_list | grep -q "${1}"
}

func_ip_single() {
	# some old version of 'sort' NOT support -V, which is better than plain 'sort'
	func_ip_list | sed -e 's/^\S*\s*//;/^\s*$/d' | sort | tail -1
}

func_ip_list() {
	# NOTE: "tr -s ' '" compact space to single for better field identify
	local os_name=${MY_OS_NAME:-$(func_os_name)}
	if [ "${os_name}" = "${OS_CYGWIN}" ] ; then
		# non-cygwin env: ifconfig
		/sbin/ifconfig | sed -n -e '/inet addr/s/.*inet6* addr:\s*\([.:a-z0-9]*\).*/\1/p'	# IPv4
		/sbin/ifconfig | sed -n -e '/inet6* addr/s/.*inet6* addr:\s*\([.:a-z0-9]*\).*/\1/p'	# IPv4 & IPv6
	elif [ "${os_name}" = "${OS_OSX}" ] ; then
		/sbin/ifconfig -a | tr -s ' '		\
		| awk -F'[% ]' '			
			/^[a-z]/{print "";printf $1}	
			/^\s*inet /{printf " " $2}	
			# Un-comment to show IPv6 addr	
			# /^\s*inet6 /{printf " " $2}	
			END{print ""}'			\
		| sed -e "/127.0.0.1/d;/^\s*$/d;/\s/!d;"\
		| column -t -s " "
	elif [ "${os_name}" = "${OS_WIN}" ] ; then
		# seem directly pipe the output of ipconfig is very slow
		raw_data=$(ipconfig) ; echo "$raw_data" | sed -n -e "/IPv[4] Address/s/^[^:]*: //p"	# IPv4
		raw_data=$(ipconfig) ; echo "$raw_data" | sed -n -e "/IPv[46] Address/s/^[^:]*: //p"	# IPv4 & IPv6
		#ipconfig | sed -n -e '/inet addr/s/.*inet addr:\([.0-9]*\).*/\1/p'
	else
		/sbin/ifconfig -a | tr -s ' '		\
		| awk '					
			/^[a-z]/{printf $1 }		
			/inet addr:/{printf " " $2}	
			# Un-comment to show IPv6 addr	
			#/inet6 addr:/{printf " " $3}	
			/^$/{print}'			\
		| sed -e "/127.0.0.1/d;s/addr://" 	\
		| column -t -s " "
	fi
}

func_find_idle_port() {
	local usage="USAGE: ${FUNCNAME[0]} <port_start> <port_end>" 
	local desc="Desc: find available/idle port between range <port_start>-<port_end>, if <port_end> missed, will be <port_start>+20. Return 0 and echo 1st idle port, otherwise return 1" 
	func_param_check 1 "$@"
	
	local tmp_port port_end
	local port_start="${1}"
	[ -n "${2}" ] && port_end="${2}" || port_end="$((${port_start}+20))"

	func_is_int_in_range "${port_end}" 1025 65535 || func_die "ERROR: port_end (${port_end}) not in range 1025~65535!)"
	func_is_int_in_range "${port_start}" 1025 65535 || func_die "ERROR: port_start (${port_start}) not in range 1025~65535!)"

	for tmp_port in $(seq ${port_start} ${port_end}) ; do
		# support linux & osx: netstat on linux/osx use ":/." for port separator
		netstat -an | head | awk '{print gensub(/.*[\.:]/, "", "g", $4)}' | grep -q "${tmp_port}" && continue
		echo ${tmp_port} && return 0
	done
	return 1
}

################################################################################
# Data Type: array
################################################################################
func_is_array_not_empty() {
	local usage="USAGE: ${FUNCNAME[0]} <array-elements>" 
	local desc="Desc: check if <array-elements> is NOT empty, return 0 if true, otherwise 1" 
	
	[[ "$#" -gt 0 ]] && return 0 || return 1
}

func_array_contans() {
	local usage="USAGE: ${FUNCNAME[0]} <element> <array>" 
	local desc="Desc: check if <array> contains <element>, return 0 if contains, otherwise 1" 
	func_param_check 2 "$@"

	local e
	for e in "${@:2}"; do 
		[[ "$e" == "$1" ]] && return 0
	done
	return 1
}

################################################################################
# Data Type: number
################################################################################
func_is_int_in_range() {
	local usage="Usage: ${FUNCNAME[0]} <num> <start> <end>"
	local desc="Desc: return 0 if <num> is number and in range <start> ~ <end>, otherwise return 1" 
	func_param_check 3 "$@"

	local num="${1}"
	local start="${2}"
	local end="${3}"

	func_is_int "${num}" && (( num >= start )) && (( num <= end )) && return 0 || return 1

	# backup way: check $num is a num in 1~$maxNum (verified in cygwin bash, but (( )) always have problem)
	#[[ -z "$num" || ! "$num" =~ ^[0-9]+$ || "$num" -gt "$maxNum" || "$num" -lt "1" ]]	
}

func_is_int() {
	local usage="Usage: ${FUNCNAME[0]} <param>"
	local desc="Desc: return 0 if the param is integer, otherwise will 1" 
	func_param_check 1 "$@"
	
	# NOTE: no quote on the pattern part!
	local num="${1}"
	[[ "${num}" =~ ^[-]?[0-9]+$ ]] && return 0 || return 1
}

func_is_positive_int() {
	local usage="Usage: ${FUNCNAME[0]} <param>"
	local desc="Desc: return 0 if the param is positive integer, otherwise will 1" 
	func_param_check 1 "$@"
	
	# NOTE: no quote on the pattern part!
	local num="${1}"
	func_is_int "${num}" && (( num > 0 )) && return 0 || return 1
}

func_num_to_human() {
	local usage="Usage: ${FUNCNAME[0]} <number>"
	local desc="Desc: convert to number to human readable form, like: 4096 to 4K" 
	func_param_check 1 "$@"
	
	local fraction=''
	local unit_index=0
	local number=${1:-0}
	local UNIT=("" K M G T E P Y Z)
	#local UNIT=({"",K,M,G,T,E,P,Y,Z}) # also works

	while ((number > 1024)); do
		fraction="$(printf ".%02d" $((number % 1024 * 100 / 1024)))"
		number=$((number / 1024))
		let unit_index++
	done
	echo "${number}${fraction}${UNIT[$unit_index]}"
}

################################################################################
# Data Type: string
################################################################################
func_is_str_empty() {
	local usage="Usage: ${FUNCNAME[0]} <string...>"
	local desc="Desc: check if string is empty (or not defined), return 0 if empty, otherwise 1" 
	func_param_check 1 "$@"
	
	[ -z "${1}" ] && return 0 || return 1
}

func_is_str_blank() {
	local usage="Usage: ${FUNCNAME[0]} <string...>"
	local desc="Desc: check if string is blank (or not defined), return 0 if empty, otherwise 1" 
	func_param_check 1 "$@"
	
	# remove all space and use -z to check
	[ -z "${1//[[:blank:]]}" ] && return 0 || return 1
}

func_contains_blank_str() {
	local usage="Usage: ${FUNCNAME[0]} <string...>"
	local desc="Desc: check if parameter contains blank (or not defined) str, return 0 if yes, otherwise 1" 
	func_param_check 1 "$@"
	
	local str
	for str in "$@" ; do
		func_is_str_blank "${str}" && return 0
	done
	return 1
}

func_str_not_contains() {
	! func_str_contains "$@"
}

func_str_contains() {
	local usage="Usage: ${FUNCNAME[0]} <string> <substr>"
	local desc="Desc: check if string contains substr, return 0 if contains, otherwise 1" 
	func_param_check 2 "$@"
	
	func_is_str_empty "${1}" && return 1

	# use != for not contains
	# use =~ for regex match: [[ $string =~ .*My.* ]], note if regex contains space, need escape with "\"
	[[ "${1}" == *"${2}"* ]] && return 0 || return 1
}

func_str_starts_with() {
	local usage="Usage: ${FUNCNAME[0]} <string> <starts_with>"
	local desc="Desc: check if string starts with specifed str, return 0 if yes, otherwise 1" 
	func_param_check 2 "$@"
	
	# TODO
}
