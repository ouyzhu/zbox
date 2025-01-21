#!/bin/bash

# source ${HOME}/.myenv/myenv_lib.sh || eval "$(wget -q -O - "https://raw.github.com/stico/myenv/master/.myenv/myenv_lib.sh")" || exit 1

################################################################################
# Todo
################################################################################
# - use func_pkg_mgmt_ins instead of
# 	sudo port install
# 	sudo apt-get instal
# - lots tool need gnu, how to check?
#	sort/find/sed/awk
# - use alias for function instead of func invoke

################################################################################
# Const
################################################################################
PARAM_NON_INTERACTIVE_MODE="param_non_interactive_mode"
DEFAULT_TIME_ZONE="Asia/Shanghai"
UNCOMFIRMED_YM="0000-00"
FIND_UTIL_EXCLUDE=".fu.exclude"
FIND_UTIL_FILESIZE=".fu.filesize"

################################################################################
# Time
################################################################################
func_time() { date "+%H-%M-%S";						}
func_daty() { TZ="${DEFAULT_TIME_ZONE}" date "+%Y";			}
func_datm() { TZ="${DEFAULT_TIME_ZONE}" date "+%Y-%m";			}
func_date() { TZ="${DEFAULT_TIME_ZONE}" date "+%Y-%m-%d";		}
func_dati() { TZ="${DEFAULT_TIME_ZONE}" date "+%Y-%m-%d_%H-%M-%S";	}
func_nanosec()  { date +%s%N;						}
func_millisec() { echo $(($(date +%s%N)/1000000));			}

func_is_str_date() {
	local usage="Usage: ${FUNCNAME[0]} <date_str>" 
	local desc="Desc: check if str is in +%Y-%m-%d format"
	func_param_check 1 "$@"
	
	func_is_str_dati "$(func_str_trim "${1}")_00-00-00"
}

func_is_str_dati() {
	local usage="Usage: ${FUNCNAME[0]} <dati_str>" 
	local desc="Desc: check if str is in +%Y-%m-%d_%H-%M-%S format"
	func_param_check 1 "$@"

	# date只能解析通用格式，无法通过指定格式来解析。
	# 注: Python可以: datetime.datetime.strptime(str, "%Y-%m-%d_%H-%M-%S")
	[[ "$(func_str_trim "${1}")" =~ ^[1-2][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]_[0-2][0-9]-[0-5][0-9]-[0-5][0-9]$ ]] && return 0 || return 1
}

func_date_in_dati() {
	local usage="Usage: ${FUNCNAME[0]} <dati_str>" 
	local desc="Desc: extract date str from dati str"
	func_param_check 1 "$@"

	func_is_str_dati "${1}" || func_die "ERROR: ${1} is NOT a dati string, pls check!"
	echo "${1%_*}"
}

################################################################################
# Misc
################################################################################
func_info()         { func_techo "INFO"  "$@" ; }
func_warn()         { func_techo "WARN"  "$@" ; }
func_error()        { func_techo "ERROR" "$@" ; }
func_debug()        { [[ "${ME_DEBUG}" == 'true' ]] && func_techo "DEBUG" "$@" ; }
func_warn_stderr()  { func_warn  "$@" 1>&2 ; }
func_error_stderr() { func_error "$@" 1>&2 ; }
func_debug_stderr() { func_debug "$@" 1>&2 ; }

func_var_to_str()    {
	local usage="Usage: ${FUNCNAME[0]} <var-name> ..." 
	local desc="Desc: concat var name-value pairs into str, simplify the code"
	func_param_check 1 "$@"
	
	local v
	for v in "$@" ; do 
		printf "%s: '%q'" "${v}" "${!v}"
	done
	# TODO
}

func_techo() {
	local usage="Usage: ${FUNCNAME[0]} <level> <msg>" 
	local desc="Desc: echo msg format: <level-in-uppercase>: <TIME>: <msg>"
	func_param_check 2 "$@"
	
	local level="${1}"
	shift
	echo -e "$(date "+%Y-%m-%d %H:%M:%S") ${level^^} $*"
}

func_die() {
	local usage="Usage: ${FUNCNAME[0]} <error_info>" 
	local desc="Desc: echo error info to stderr and exit" 
	[ $# -lt 1 ] && echo -e "${desc}\n${usage}\n" 1>&2 && exit 1
	
	echo -e "$@" 1>&2
	exit 1 
	# ~signal@bash: -INT NOT suitable, as it actually only breaks from function
	#func_is_non_interactive && exit 1 || kill -INT $$
}

func_ask_yes_or_no() {
	local usage="Usage: ${FUNCNAME[0]} <msg>" 
	local desc="Desc: (interactive mode) ask user yes or no, return 0 for yes, 1 for others"
	func_param_check 1 "$@"

	local msg user_input
	[[ "${1}" = *y/n* ]] && msg="${1}" || msg="${1}, pls answer y/n?" 

	while 'true'; do
		echo "${msg}" 1>&2
		read -r -e user_input
		{ [[ "${user_input}" = "y" ]] || [[ "${user_input}" = "Y" ]] ; } && return 0
		{ [[ "${user_input}" = "n" ]] || [[ "${user_input}" = "N" ]] ; } && return 1
	done
}

func_param_complain() {
	PARAM_COMPLAIN=true func_param_check "$@"
}

func_param_validate() { func_param_check "$@" ; }
func_param_check() {
	# Self param check. use -lt, so the exit status will not changed in legal condition
	# NOT use desc/usage var name, so invoker could call 'func_param_check 2 "$@"' instead of 'func_param_check 2 "${desc}\n${usage}\n" "$@"'
	local self_usage="Usage: ${FUNCNAME[0]} <count> <string> ..."
	local self_desc="Desc: check if parameter number >= <count>, otherwise print error_msg and exit. If invoker defined var desc/usage, error_msg will be \${desc}\\\\n\${usage}\\\\n, ohterwise use default"
	local self_warn="Warn: (YOU SCRIPT HAS BUG) might be: \n\t1) NOT provide <count> or any <string> \n\t2) called ${FUNCNAME[0]} but actually not need to check" 
	[ $# -lt 1 ] && func_die "${self_warn}\n${self_desc}\n${self_usage}\n"	
	
	local error_msg count
	count="${1}"
	shift

	error_msg="${desc}\n${usage}\n"
	#[[ "${count}" =~ ^[-]*[0-9]+$ ]] && (( count > 0 )) || func_die "ERROR: <count> of ${FUNCNAME[0]}, must be a positive number"
	[[ "${count}" =~ ^[-]*[0-9]+$ ]] && (( count > 0 )) || error_msg="${error_msg}\nERROR: <count> of ${FUNCNAME[0]}, must be a positive number"

	# do NOT call func_is_str_blank here, which cause infinite loop and "Segmentation fault: 11"
	[ -z "${error_msg//[[:blank:]\\n]}" ] && error_msg="ERROR: param counts < expected (${count}), and desc/usage NOT defined."

	# real parameter check
	if [ $# -lt "${count}" ] ; then
		echo -e "${error_msg}" 1>&2
		[[ "${PARAM_COMPLAIN}" == 'true' ]] && return 0
		exit 1
	fi
	return 1
}

func_vcs_update() {
	# USED_IN: $MY_DCD/vcs/code_dw_update.sh
	local usage="Usage: ${FUNCNAME[0]} <src_type> <src_addr> <target_dir>"
	local desc="Desc: init or update vcs like hg/git/svn"
	func_param_check 3 "$@"

	local src_type src_addr target_dir cmd_update cmd_init cmd
	src_type="${1}"
	src_addr="${2}"
	target_dir="${3}"
	echo "INFO: init/update source, type: ${src_type}, addr: ${src_addr}, target: ${target_dir}"
	case "${src_type}" in
		hg)	cmd="hg"  ; cmd_init="hg clone"     ; cmd_update="hg pull"	;;
		git)	cmd="git" ; cmd_init="git clone"    ; cmd_update="git pull"	;;
		svn)	cmd="svn" ; cmd_init="svn checkout" ; cmd_update="svn update"	;;
		*)	func_die "ERROR: Can not handle src_type (${src_type})"	;;
	esac

	func_validate_cmd_exist ${cmd}
	
	if [[ -e "${target_dir}" ]] ; then
		pushd "${target_dir}" &> /dev/null	|| func_die "ERROR: cd failed (${target_dir})"
		${cmd_update}				|| func_die "ERROR: ${cmd_update} failed"
		# shellcheck disable=2164
		popd &> /dev/null			
	else
		mkdir -p "$(dirname "${target_dir}")"
		${cmd_init} "${src_addr}" "${target_dir}" || func_die "ERROR: ${cmd_init} failed"
	fi
}

func_ver_increase() {
	local usage="Usage: ${FUNCNAME[0]} <v1> <v2>"
	local desc="Desc: check if v1 > v2 is increased, also return true if equals"
	func_param_check 2 "$@"
	
	# ref: https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
	printf '%s\n' "$1" "$2" | sort -C -V
}
################################################################################
# Process
################################################################################
func_pids_of_descendants() {
	local usage="Usage: ${FUNCNAME[0]} <need_sudo> <pid>" 
	local desc="Desc: return pid list of all descendants (including self), or empty if none" 
	#func_param_check 1 "$@"

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
	#func_param_check 1 "$@"

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
	#func_param_check 1 "$@"

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
	echo "ERROR: this function is NOT ready yet" 1>&2
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
	#func_param_check 1 "$@"
	
	local pid_num="$(cat "${1}" 2>/dev/null)"
	func_is_positive_int "${pid_num}" || func_die "ERROR: pid_file (${1}) NOT exist or no valid pid inside!"

	func_is_pid_running "${pid_num}"
}

func_is_pid_or_its_child_running() {
	local usage="Usage: ${FUNCNAME[0]} <pid>" 
	local desc="Desc: check is <pid> running, or any of its child running" 
	#func_param_check 1 "$@"

	# shellcheck disable=2009 # suggest use pgrep
	ps -ef | grep -v grep | grep -q "[[:space:]]${1}[[:space:]]"
}

func_is_pid_running() {
	local usage="Usage: ${FUNCNAME[0]} <pid>" 
	local desc="Desc: check is <pid> running" 
	#func_param_check 1 "$@"
	
	func_is_str_blank "${1}" && return 1

	# NOTE: if the process is in sudo mode, 'kill -0' check will failed, at least some plf will complain permission
	# 0 is an inexist signal, but helps check if process exist
	#kill -0 "${1}" 2>/dev/null 

	# POSIX way, better compatible on diff os
	# shellcheck disable=2009
	ps -o pid= -p "${1}" | grep -q "${1}"
}

################################################################################
# MultiMedia
################################################################################
func_media_time_ym() {
	local usage="Usage: ${FUNCNAME[0]} <file>"
	local desc="Desc: extract year/month info from media (format: YYYY-mm), return ${UNCOMFIRMED_YM} if failed"
	func_param_check 1 "$@"

	func_complain_cmd_not_exist exiftool "exiftool NOT installed, pls check (zbox have it)" && return 1		# zbox / homebrew / apt install exiftool

	local dm f tag
	f="${1}"
	for tag in DateTimeOriginal CreateDate ModifyDate GPSDateStamp; do
		# GPSDateStamp ALWAYS output in "%Y:%m:%d" format, so use this format to unify the following process
		dm="$(exiftool -s -"${tag}" -d "%Y:%m:%d" "${f}" | sed -e 's/^.*: \+//;s/:/-/g;s/-..$//;')"
		if func_is_std_format_ym "${dm}" ; then
			#echo "INFO: get Date-Month ${STR_SUCCESS}: ${dm} (${tag}, ${f##*"${BASENAME}"/})" >> "${log_file}"
			echo "${dm}" 
			return 0
		fi
	done

	echo "${UNCOMFIRMED_YM}"
	return 1
}

func_is_std_format_ym() {
	local usage="Usage: ${FUNCNAME[0]} <str>"
	local desc="Desc: check if time in 'YYYY-mm' format"
	func_param_check 1 "$@"

	func_is_str_blank "${1}" && return 1

	# ${UNCOMFIRMED_YM} is NOT valid, so invoker of func_media_time_ym can do more logic for it
	[[ "${1}" == 20[0-9][0-9]-[0-9][0-9] ]] && return 0 || return 1
}

################################################################################
# Pattern_Matching (regex / patterns) (also see ~Text_Process )
################################################################################
func_grepf() {
	local usage="Usage: ${FUNCNAME[0]} [-param1] [-param2] ... [-paramN] [--] <pattern-file> [input-file]"
	local desc="Desc: grep patterns in file (support big count of lines), filter blank/comment lines before grep which makes more stable (blank lines seems match everything!)"
	func_param_check 1 "$@"

	# DO NOT use 'local' claim this var, test case need change its value
	FUNC_GREPF_MAX_PATTERN_LINE="${FUNC_GREPF_MAX_PATTERN_LINE:=2000}"

	# Parse params
	local p params pattern_file pattern_file_line_count
	for p in "$@"; do 
		[[ -z "${p}" ]] && shift && continue
		[[ "${p}" == "--" ]] && shift && break
		[[ "${p}" == -* ]] && params="${params} ${p}" && shift
	done

	# Check pattern file
	pattern_file="${1}"
	shift
	func_validate_path_exist "${pattern_file}"
	pattern_file_line_count="$(func_del_blank_hash_lines "${pattern_file}" | wc -l)"

	# Check mode
	#[[ -n "${1}" ]] && pipe_mode='false' || pipe_mode='true'

	# shellcheck disable=2086
	# NOTE: 1) SHOULD support both pipe and file. 2) do NOT quote $params. 
	if (( pattern_file_line_count <= FUNC_GREPF_MAX_PATTERN_LINE )) ; then
		func_debug_stderr "Not need to split pattern file: ${pattern_file_line_count} <= ${FUNC_GREPF_MAX_PATTERN_LINE}"
		func_debug_stderr "CMD: grep ${params} -f <(func_del_blank_hash_lines ${pattern_file}) $*"

		# PIPE_CONTENT_GOES_HERE
		grep ${params} -f <(func_del_blank_hash_lines "${pattern_file}") "$@"
	else
		local tmp_split_dir tmp_split_f_prefix tmp_in tmp_out f 
		tmp_split_f_prefix="$(mktemp -d)/func_grepf.tmp" 
		tmp_split_dir="/tmp/func_grepf-pattern-split-${FUNC_GREPF_MAX_PATTERN_LINE}-$(func_file_md5sum "${pattern_file}")"

		func_debug_stderr "Split/Reuse pattern file (${pattern_file_line_count} > ${FUNC_GREPF_MAX_PATTERN_LINE}) at: ${tmp_split_f_prefix%/*}/"
		if [ ! -d "${tmp_split_dir}" ] ; then
			mkdir -p "${tmp_split_dir}" 
			split -d -l "${FUNC_GREPF_MAX_PATTERN_LINE}" <(func_del_blank_hash_lines "${pattern_file}") "${tmp_split_dir}/${pattern_file##*/}-" 
		fi

		# 注意: 有和没有参数 "-v" 方式是不一样的，所以需要分开不同的逻辑。
		if func_str_contains "${params}" " -v" ; then

			func_debug_stderr "params contain '-v'. 逻辑: 针对输入一个个pattern文件过滤即可，最后一个过滤出的文件即为结果"
			for f in "${tmp_split_dir}"/* ; do
				[[ -s "${f}" ]] || continue
				tmp_out="${tmp_split_f_prefix}-OUTPUT-${f##*/}" 

				if [[ ! -e "${tmp_in}" ]] ; then	
					# PIPE_CONTENT_GOES_HERE, 1st round goes here, other rount goes in 'else' block
					grep ${params} -f "${f}" "$@" > "${tmp_out}"
				else									
					grep ${params} -f "${f}" "${tmp_in}" > "${tmp_out}"
				fi
				tmp_in="${tmp_out}"
			done
		else
			local tmp_in_0 tmp_in_1
			tmp_in_0="${tmp_split_f_prefix}-INPUT-ALL" 
			tmp_out="${tmp_split_f_prefix}-OUTPUT-ALL" 

			func_debug_stderr "params NOT contain '-v'. 逻辑: 依次用pattern扫描，累积到结果文件。注意: 匹配过的行需用'-v'过滤掉，以免被后续pattern文件再次匹配"

			# PIPE_CONTENT_GOES_HERE, 输入要先全部保留下来
			grep "" "$@" > "${tmp_in_0}"

			for f in "${tmp_split_dir}"/* ; do
				[[ -s "${f}" ]] || continue

				tmp_in_1="${tmp_split_f_prefix}-INPUT-${f##*/}" 
				grep ${params} -f "${f}" "${tmp_in_0}" >> "${tmp_out}"
				grep ${params} -v -f "${f}" "${tmp_in_0}" > "${tmp_in_1}"
				tmp_in_0="${tmp_in_1}"
			done
		fi

		cat "${tmp_out}"
		# cleanup? : delete tmp files: rm -r "${tmp_split_f_prefix%/*}/"
	fi
}

func_del_blank_lines() {
	# PIPE_CONTENT_GOES_HERE 
	func_del_pattern_lines '^[[:space:]]*$' -- "$@"
}

func_del_blank_hash_lines() { func_del_blank_and_hash_lines "$@" ; }
func_del_blank_and_hash_lines() {
	# PIPE_CONTENT_GOES_HERE 
	func_del_pattern_lines '^[[:space:]]*$' '^[[:space:]]*#' -- "$@"
}

func_del_string_lines_f() {
	local usage="Usage: ${FUNCNAME[0]} <string_file> [input_file...]"
	local desc="Desc: delete string (NOT pattern) listed in <string_file>" 
	func_param_check 1 "$@"

	func_grepf -v -F "$@"
}

func_del_pattern_lines_f() {
	local usage="Usage: ${FUNCNAME[0]} <pattern_file> [input_file...]"
	local desc="Desc: delete patterns listed in <pattern_file>" 
	func_param_check 1 "$@"

	func_grepf -v "$@"
}

func_del_pattern_lines() {
	local usage="Usage: <OTHER_CMD> | ${FUNCNAME[0]} <pattern1> ... <patternN> -- [file1] [file2] ... [fileN]"
	local desc="Desc: delete patterns listed in paraemter, NOTE: if against files the '--' MUST used as separator!" 
	func_param_check 1 "$@"

	local p patterns
	for p in "$@"; do 
		[[ -z "${p}" ]] && shift && continue
		[[ "${p}" == "--" ]] && shift && break

		patterns="${patterns}\|${p}"
		shift
	done

	# PIPE_CONTENT_GOES_HERE 
	grep -v "${patterns#\\|}" "$@"
}

# func_file_remove_lines() {
# 
# 	# DEPRECATED: use func_grepf
# 	# USE CASE: func_file_remove_lines fhr.lst <quick_code_file.txt>
# 
# 	local usage="Usage: ${FUNCNAME[0]} <pattern_file> <input_file>"
# 	local desc="Desc: remove patterns listed in file, useful when pattern list a very long" 
# 	func_param_check 2 "$@"
# 
# 	# Var & Check
# 	local PATTERN_SPLIT_COUNT pattern_file input_file result_file pattern_count pattern_file_md5 tmp_p_dir input_lines result_lines
# 	PATTERN_SPLIT_COUNT="1000"
# 	pattern_file="${1}"
# 	input_file="${2}"
# 	#local target_file="${2}.removed.$(func_dati)"
# 	func_complain_path_not_exist "${input_file}" && return 1
# 	func_complain_path_not_exist "${pattern_file}" && return 1
# 
# 	# Remove
# 	result_file="$(mktemp -d)/$(basename "${input_file}").REMOVED" 
# 	pattern_count="$(func_file_line_count "${pattern_file}")"
# 	if (( pattern_count <= PATTERN_SPLIT_COUNT )) ; then 
# 		echo "INFO: pattern lines NOT need split ( $pattern_count <= $PATTERN_SPLIT_COUNT )"
# 		func_file_remove_lines_simple -i "${pattern_file}" "${input_file}" > "${result_file}"
# 	else
# 		echo "INFO: too much pattern lines, need split ( $pattern_count > $PATTERN_SPLIT_COUNT )"
# 
# 		# split patterns
# 		pattern_file_md5="$(md5sum "${pattern_file}" | cut -d' ' -f1)"
# 		tmp_p_dir="/tmp/func_file_remove_lines-patterns-${PATTERN_SPLIT_COUNT}-${pattern_file_md5}"
# 		if [ ! -d "${tmp_p_dir}" ] ; then
# 			mkdir -p "${tmp_p_dir}" 
# 			split -d -l "${PATTERN_SPLIT_COUNT}" "${pattern_file}" "${tmp_p_dir}/${pattern_file##*/}" 
# 			echo "INFO: splited pattern files in: ${tmp_p_dir}/"
# 		else
# 			echo "INFO: reuse splited pattern files in: ${tmp_p_dir}/"
# 		fi
# 
# 		# use splited pattern files one by one
# 		local tmp_out
# 		local tmp_in="${input_file}" 
# 		for f in "${tmp_p_dir}"/* ; do
# 			[[ -e "$f" ]] || continue
# 			tmp_out="${result_file}.${f##*/}" 
# 			func_file_remove_lines_simple -i "${f}" "${tmp_in}" > "${tmp_out}"
# 			tmp_in="${tmp_out}"
# 		done
# 		result_file="${tmp_out}"
# 	fi
# 
# 	# Show result
# 	input_lines="$(func_file_line_count "${input_file}")"
# 	result_lines="$(func_file_line_count "${result_file}")"
# 	echo "INFO: result/input lines: ${result_lines}/${input_lines}, result file: ${result_file}"
# 
# 	# Old solution: works, but bak is in same dir
# 	#local sed_cmd="$(func_sed_gen_d_cmd "$@")"
# 	#sed --in-place=".bak-of-sed-cmd.$(func_dati)" -e "${sed_cmd}" "${file}"
# }

################################################################################
# Text_Process (also see ~Pattern_Matching )
################################################################################
func_merge_lines() { func_combine_lines "$@"; }
func_combine_lines() {
	local usage="Usage: <OTHER_CMD> | ${FUNCNAME[0]} -b <begin_str> -e <end_str> -s <sep_str> -n <n, default: 2> [file]"
	local desc="Desc: combine [n] (default is 2) not-blank-or-hash lines into 1 line: <begin_str><LINE-CONTENT><end_str><sep_str>..."

	# check getopt verison (need 
	getopt --test
	[[ "$?" != 4 ]] && func_warn_stderr "getopt is NOT util-linux version, pls check"

	# parse argument, note the quotes around "$TEMP": they are essential!
	local TEMP begin end sep count
	TEMP=$(getopt -o 'b:e:s:n:' --long 'begin:,end:,sep:,count:' -n "${FUNCNAME[0]}" -- "$@")
	eval set -- "$TEMP"
	unset TEMP
	count=2
	while true; do
		case "${1}" in
			'-n'|'--count')	count="${2}"; shift 2; continue ;;
			'-b'|'--begin')	begin="${2}"; shift 2; continue ;;
			'-e'|'--end')	end="${2}"; shift 2; continue ;;
			'-s'|'--sep')	sep="${2}"; shift 2; continue ;;
			'--')		shift; break ;;
			*)		func_warn_stderr "parse arguments failed: $*" ; exit 1 ;;
		esac
	done

	# CRLF line terminators need to convert
	# PIPE_CONTENT_GOES_HERE. Old: 'NR%3{printf "%s,",$0;next;}{print $0}' "${input}" > "${tmp_csv_merge}"
	func_del_blank_hash_lines "$@" \
	| sed 's/$//' \
	| awk -v begin="${begin}" -v end="${end}" -v sep="${sep}" -v count="${count}" \
		'NR%count {
			# (count-1)th lines goes here
			printf "%s%s%s%s", begin, $0, end, sep;
			next;
		}
		{
			# (count)th line goes here
			printf "%s%s%s\n", begin, $0, end ;
		}' \
	| sed -e "s/${sep}$//"
}

func_shrink_pattern_lines() {
	# USED_IN: secu/$HOSTNAME/telegram (shrink kword.title)
	local usage="Usage: ${FUNCNAME[0]} <pattern-file>"
	local desc="Desc: shrink lines (and remove blank lines), e.g. if lineA is sub string of lineB, lineB will be removed"
	desc="$desc \nNote 1: NOT support pipe, seems not needed"
	desc="$desc \nNote 2: useful for shrinking pattern file used in func_grepf()"
	func_param_check 1 "$@"

	# Collect: lines to delete. NOTE: '-F' is necessary, otherwise gets 'grep: Invalid range end' if have such sub str: '[9-1]'
	local input_file lines_to_del tmp_grep line
	input_file="${1}"
	lines_to_del="$(mktemp)"
	while IFS= read -r line || [[ -n "${line}" ]] ; do
		tmp_grep="$(grep -F "${line}" "${input_file}" | grep -v -x -F "${line}")"
		func_is_str_blank "${tmp_grep}" && continue
		echo -e "# match-line-found-with-this-line: ${line}\n${tmp_grep}" >> "${lines_to_del}"
	done < <(func_del_blank_lines "${input_file}")
	[[ ! -e "${lines_to_del}" ]] && echo "INFO: nothing to shrink, nothing performed" && return

	# Shrink '-x' seems unnecessary here. NOTE, will also delete duplicated lines (and merge blank lines)
	func_grepf -v -F "${lines_to_del}" "${input_file}" | func_del_blank_lines | func_shrink_dup_lines
}

# shellcheck disable=2120
func_shrink_blank_lines() {
	local usage="Usage: <OTHER_CMD> | ${FUNCNAME[0]} [file]"
	local desc="Desc: shrink blank lines, multiple consecutive blank lines into 1" 

	[[ -n "${1}" ]] && func_complain_path_not_exist "${1}" && return 1

	# PIPE_CONTENT_GOES_HERE, NOT use func_del_blank_lines, since it delete all blank lines
	sed -r 's/^\s+$//' "$@" | cat -s

}

# shellcheck disable=2119,2120
func_shrink_dup_lines() {
	local usage="Usage: ${FUNCNAME[0]} [pattern-file]"
	local desc="Desc: shrink duplicated lines (and merge blank lines), without sorting" 

	[[ -n "${1}" ]] && func_complain_path_not_exist "${1}" && return 1

	# Candidates
	# awk '!x[$0]++'				# remove duplicate lines without sorting. (++) is performed after (!), which is crucial
	# awk '!x[$0]++ { print $0; fflush() }'		# helps when output a.s.a.p.
	# awk 'length==0 || !x[$0]++'			# retain empty line
	# awk '($0 ~ /^[[:space:]]*$/) || !x[$0]++'	# retain blank line

	# PIPE_CONTENT_GOES_HERE 
	awk '($0 ~ /^[[:space:]]*$/) || !x[$0]++' "$@" | func_shrink_blank_lines
}

################################################################################
# File System: basic
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
	
	local p
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

func_mv_structurally() { 
	local usage="Usage: ${FUNCNAME[0]} <fd_path> <tgt_base> [src_base]"
	local desc="Desc: mv <fd_path> from <tgt_base>, use <src_base> to determine what dir hierarchy to perserve (none if omit)"
	func_param_check 2 "$@"

	local src_base tgt_base src_path rel_path

	# PWD as src_base default value
	src_path="$(readlink -f "${1}")"
 	tgt_base="$(readlink -f "${2}")"
	[[ -n "${3}" ]] && src_base="$(readlink -f "${3}")/" || src_base="$(readlink -f "${PWD}")"

	# Check
	func_complain_path_inexist "${src_path}" && return 1
	[[ ! -d "${tgt_base}" ]] && func_error "${tgt_base} should be a dir, pls check" && return 1

	# count rel_path
	if func_str_not_contains "${src_path}" "${src_base}" ; then
		func_error "src_base should be part of src_path (is src_path a link?), pls check: ${src_path} V.S. ${src_base}"
		return 1
	fi
	rel_path="${src_path##*"${src_base}"}"

	# Perform
	tgt_dir="$(dirname "${tgt_base}/${rel_path}")"
	mkdir -p "${tgt_dir}" &> /dev/null
	func_debug mv "${src_path}" "${tgt_dir}"
	mv "${src_path}" "${tgt_dir}" 
}

func_file_line_count_clean() {
	local usage="Usage: ${FUNCNAME[0]} <file>"
	local desc="Desc: output only lines of file (exclude blank and hash lines)" 
	func_param_check 1 "$@"

	func_del_blank_hash_lines "${1}" | wc -l
}

func_file_lines() { func_file_line_count "$@"; }
func_file_line_count() {
	local usage="Usage: ${FUNCNAME[0]} <file>"
	local desc="Desc: output only lines of file" 
	func_param_check 1 "$@"

	func_complain_path_not_exist "${1}" && return 1
	wc -l "${1}" | awk '{print $1}'
}

func_path_size_human() { func_file_size_human "$@"; }
func_file_size_human() {
	#func_num_to_human "$(func_file_size "$@")"
	func_num_to_human_IEC "$(func_file_size "$@")"
}

func_path_size() { func_file_size "$@"; }
func_file_size() {
	local usage="Usage: ${FUNCNAME[0]} <target>"
	local desc="Desc: get file size, in Bytes" 
	func_param_check 1 "$@"

	if [ -d "${1}" ] ; then
		# NOTE: even use --apparent-size, still found case, that output is DIFF when dir on diff FS
		\du --apparent-size --bytes --summarize "${1}" | awk '{print $1}'
	else
		stat --printf="%s" "${1}"
	fi
}

func_path_common_base() {
	local usage="Usage: <OTHER_CMD> | ${FUNCNAME[0]} \n ${FUNCNAME[0]} <file> [file] ..."
	local desc="Desc: get common base of file paths, via pipe or paths store in <file>"

	local result

	# 处理空行，注释行，前缀空格
	result="$(cat "$@" | func_del_blank_hash_lines | func_str_common_prefix | sed -e 's+[^/]*$++')"

	# "/"为保底路径
	echo "${result:-/}"
}

func_file_md5sum() { 
	local usage="Usage: ${FUNCNAME[0]} <file>"
	local desc="Desc: get file size, in Bytes" 
	func_param_check 1 "$@"

	[[ ! -e "${1}" ]] && func_error_stderr "file not found, skip gen md5: ${1}" && return 1

	# 用head相比cut/awk，好处是没有结尾的'\n'，不过有它似乎很多场景下也没问题
	md5sum "${1}" | head -c 32
}

func_ln_soft() {
	local usage="Usage: ${FUNCNAME[0]} <source> <target>"
	local desc="Desc: the directory must be empty or NOT exist, otherwise will exit" 
	func_param_check 2 "$@"

	local source="$1"
	local target="$2"
	echo "INFO: create soft link ${target} --> ${source}"

	# check, skip if target already link, remove if target empty 
	func_complain_path_not_exist "${source}" && return 0
	[ -h "${target}" ] && echo "INFO: ${target} already a link (--> $(readlink -f "${target}") ), skip" && return 0
	[ -d "${target}" ] && func_is_dir_empty "${target}" && rmdir "${target}"

	"ln" -s "${source}" "${target}"
}

func_is_file_ext_image() {
	local usage="Usage: ${FUNCNAME[0]} <path>"
	local desc="Desc: check if file name extension is image, return 0 if yes, otherwise 1" 
	func_param_check 1 "$@"

	# for sed cmd: '/\.\(jpg\|jpeg\|gif\|png\|apng\|avif\|svg\|webp\|bmp\|ico\|tiff\|tif\)$/d;'

	[[ "${1,,}" =~ .*\.(heic|jpg|jpeg|gif|png|apng|avif|svg|webp|bmp|ico|tiff|tif) ]] && return 0	# ordinary ext
	[[ "${1,,}" =~ .*\.(raw|cr2|nef|orf|sr2) ]] && return 0						# raw ext
	return 1
}

func_is_file_type_text() {
	local usage="Usage: ${FUNCNAME[0]} <path>"
	local desc="Desc: check if filetype is text, return 0 if yes, otherwise 1" 
	func_param_check 1 "$@"

	file "${1}" | grep -q text
}

func_is_dir_empty() {
	local usage="Usage: ${FUNCNAME[0]} <dir>"
	local desc="Desc: check if directory is empty or inexist, return 0 if empty, otherwise 1" 
	func_param_check 1 "$@"

	# enough for me to use, for better solution: https://mywiki.wooledge.org/BashFAQ/004
	[ "$(ls -A "${1}" 2> /dev/null)" ] && return 1 || return 0
}

func_is_dir_not_empty() {
	local usage="Usage: ${FUNCNAME[0]} <dir>"
	local desc="Desc: check if directory is not empty, return 0 if not empty, otherwise 1" 
	func_param_check 1 "$@"

	# enough for me to use, for better solution: https://mywiki.wooledge.org/BashFAQ/004
	[ "$(ls -A "${1}" 2> /dev/null)" ] && return 0 || return 1
}

func_validate_dir_not_empty() {
	local usage="Usage: ${FUNCNAME[0]} <dir> ..."
	local desc="Desc: the directory must exist and NOT empty, otherwise will exit" 
	func_param_check 1 "$@"
	
	local p
	for p in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		func_is_dir_empty "${p}" && func_die "ERROR: ${p} is empty!"
	done
}

func_validate_dir_empty() {
	local usage="Usage: ${FUNCNAME[0]} <dir> ..."
	local desc="Desc: the directory must be empty or NOT exist, otherwise will exit" 
	func_param_check 1 "$@"
	
	local p
	for p in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		func_is_dir_empty "${p}" || func_die "ERROR: ${p} not empty!"
	done
}

func_complain_path_exist() {
	local usage="Usage: ${FUNCNAME[0]} <path> <msg>"
	local desc="Desc: complains if path already exist, return 0 if exist, otherwise 1" 
	func_param_check 1 "$@"
	
	[ -e "${1}" ] && echo "${2:-WARN: path ${1} already exist}" 1>&2 && return 0
	return 1
}

func_complain_path_inexist() { func_complain_path_not_exist "$@" ;}
func_complain_path_not_exist() {
	local usage="Usage: ${FUNCNAME[0]} <path> <msg>"
	local desc="Desc: complains if path not exist, return 0 if not exist, otherwise 1" 
	func_param_check 1 "$@"
	
	func_is_str_blank "${1}" && func_error_stderr "${FUNCNAME[0]}: path param blank!" && func_script_stacktrace && return 0
	[ ! -e "${1}" ] && func_error_stderr "${2:-WARN: path ${1} NOT exist}" && return 0
	return 1
}

func_validate_path_exist() {
	local usage="Usage: ${FUNCNAME[0]} <path> ..."
	local desc="Desc: the path must be exist, otherwise will exit" 
	func_param_check 1 "$@"
	
	local p
	for p in "$@" ; do
		[ ! -e "${p}" ] && func_die "ERROR: ${p} NOT exist!"
	done
}

func_validate_path_not_exist() { func_validate_path_inexist "$@" ;}
func_validate_path_inexist() {
	local usage="Usage: ${FUNCNAME[0]} <path> ..."
	local desc="Desc: the path must be NOT exist, otherwise will exit" 
	func_param_check 1 "$@"
	
	local p
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

func_backup_tmp() {
	func_backup_simple "${1}" "/tmp/${1##*/}_$(func_dati)"
}

func_backup_aside() {
	func_backup_simple "${1}" "${1}_$(func_dati)"
}

# NOTE: func_backup_dated is in myenv_func.sh
func_backup_simple() {
	local usage="Usage: ${FUNCNAME[0]} <src_path> [target_path]"
	local desc="Desc: backup file, do safe check before backup, e.g.: size limit, space count"
	func_param_check 2 "$@"
	func_validate_path_exist "${1}"
	func_validate_path_not_exist "${2}"
	local size target_dir available_space

	# check size of file
	size="$(func_file_size "${1}")"
	if (( size > 100*1000*1000 )) ; then
		func_error "file size too big (${size}): ${1}" 1>&2
		return 1
	fi

	# prepare target dir
	target_dir="$(dirname "${2}")"
	[[ -e "${target_dir}" ]] || mkdir "${target_dir}"

	# shellcheck disable=2181
	if [ "$?" -ne "0" ] ; then 
		func_error "failed to make target dir"
		return 1
	fi

	# check size of available space
	available_space="$(func_disk_available_space "${target_dir}")"
	if (( size + 500*1000*1000 > available_space )); then
		func_error "available space too small ($(func_num_to_human_IEC "${available_space}")), less than 500M after copy" 1>&2
		return 1
	fi

	# check privilidge and cp
	if [ -w "${target_dir}" ] ; then
		cp -r "${1}" "${2}"
	else
		sudo cp -r "${1}" "${2}"
	fi

	# very important, many case need this info
	echo "${2}" 
}

################################################################################
# File System: Disk
################################################################################
func_disk_mount_point() {
	local usage="Usage: ${FUNCNAME[0]} <path>"
	local desc="Desc: show the mount point of path (partition mount point)" 
	func_param_check 1 "$@"
	func_validate_path_exist "${1}"
	
	# '-P': use the POSIX output format
	\df "${1}" -P | tail -1 | awk '{print $6}'
}

func_disk_available_space() {
	local usage="Usage: ${FUNCNAME[0]} <path>"
	local desc="Desc: show the remain space of path (partition of that path)" 
	func_param_check 1 "$@"
	func_validate_path_exist "${1}"
	
	# '-P': use the POSIX output format
	# '-B1' == "--block-size=1": unit: bytes.
	\df "${1}" -P -B1 | tail -1 | awk '{print $4}'
}

################################################################################
# File System: Find Utils
################################################################################
func_gen_filesize_list() {
	local usage="Usage: ${FUNCNAME[0]} [path] ..."
	local desc="Desc: gen 'size\tfile' list for paths, support exclude paths in ${FIND_UTIL_FILESIZE}"

	# default is current dir
	[[ "$#" -eq 0 ]] && func_gen_filesize_list_single && return

	# gen for each dir
	local d err_msg
	for d in "$@" ; do
		err_msg="skip gen file-size list for path: ${d}"
		func_complain_path_inexist "${d}" "path NOT exist, ${err_msg}" && continue
		(
			\cd "${d}" || func_die "Failed to cd, ${err_msg}"
			func_gen_filesize_list_single
		)
	done
}

func_gen_filesize_list_single() {
	# check if reuse
	[[ "${FU_GEN_FSL}" == 'false' ]] && [[ -e "${FIND_UTIL_FILESIZE}" ]] && return

	# make sure file is empty
	rm "${FIND_UTIL_FILESIZE}" &> /dev/null

	# assemble exclude params
	local ex_params
	if [[ -e "${FIND_UTIL_EXCLUDE}" ]] ; then
		# 用作命令行时，需要有"\"，放在脚本中则不需要
		#ex_params=" -not \( -path $(func_del_blank_hash_lines "${FIND_UTIL_EXCLUDE}" | awk 'ORS=" -prune \\) -not \\( -path "' | sed -e 's/-not .( -path $//')"
		#ex_params=" -not ( -path $(func_del_blank_hash_lines "${FIND_UTIL_EXCLUDE}" | awk 'ORS=" -prune ) -not ( -path "' | sed -e 's/-not ( -path $//')"
		ex_params="$( func_combine_lines -b "-not ( -path " -e " -prune ) " "${FIND_UTIL_EXCLUDE}" -n 99999 )"
		echo "# NOTE: exclude param used: ${ex_params}" > "${FIND_UTIL_FILESIZE}"
	fi

	# 注意1: (必须) 保持用"."，因为exclude里用它，改了则excllude的规则均无效了
	# 注意2: (建议) 保持逆序，即大文件在前面 (目前没有地方强依赖这个)
	# REF: (很好的解释了-prune的用法) https://stackoverflow.com/questions/4210042/how-do-i-exclude-a-directory-when-using-find#answer-16595367
	# shellcheck disable=2086
	find . ${ex_params} -type f -printf "%s\t%p\n" | sort -rn >> "${FIND_UTIL_FILESIZE}"
}

func_find_loop_f() {
	local usage="Usage: ${FUNCNAME[0]} <path> <function_name>"
	local desc="Desc: run <function_name> for each file (xargs or -exec NOT support <function_name>)"
	func_param_check 2 "$@"

	local path file func
	path="${1}"
	func="${2}"
	func_complain_path_inexist "${path}" && return 1
	func_complain_func_inexist "${func}" && return 1

	while IFS= read -r -d '' file ; do
		 "${func}" "${file}"
	done < <(find "${path}" -type f -print0)
}

################################################################################
# File transfer
################################################################################
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

	# "dot:giga": each dot represents 1M retrieved
	wget --progress=dot:giga --no-check-certificate "${1}" 2>&1 | grep --line-buffered "%" | sed -u -e "s,\.,,g" 

	# Note, some awk version NOT works friendly
	# Command line explain: [Showing File Download Progress Using Wget](http://fitnr.com/showing-file-download-progress-using-wget.html)
	#wget --progress=dot --no-check-certificate ${1}	2>&1 | grep --line-buffered "%" | sed -u -e "s,\.,,g" | awk 'BEGIN{printf("INFO: Download progress:  0%")}{printf("\b\b\b\b%4s", $2)}'

	echo "" # next line should in new line
	[ -f "${dl_fullpath}" ] || func_die "ERROR: ${dl_fullpath} not found, seems download faild!"
	"cd" - &> /dev/null || func_die "ERROR: failed to cd back to previous dir"
}

func_log() {
	local usage="Usage: ${FUNCNAME[0]} <level> <prefix> <log_path> <str>" 
	func_param_check 4 "$@"

	local level="$1"
	local prefix="$2"
	local log_path="$3"
	shift; shift; shift

	[ ! -e "$log_path" ] && mkdir -p "$(dirname "$log_path")" && touch "$log_path"

	echo "$(func_dati) $level [$prefix] $*" >> "$log_path"
}

func_log_info() {
	local usage="Usage: ${FUNCNAME[0]} <prefix> <log_path> <str>" 
	func_param_check 3 "$@"

	func_log "INFO" "$@"
}

func_log_filter_brief() {
	sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"
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
	func_mkdir_cd "${target_dir}"
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

# shellcheck disable=2086
func_rsync_ask_then_run() {
	local usage="Usage: ${FUNCNAME[0]} <src> <tgt> <add_options>" 
	local desc="Desc: rsync between source and target (including --delete), ask before run: --dry-run > show result > run" 
	[ $# -lt 2 ] && echo -e "${desc} \n ${usage} \n" && exit 1

	local tmp_file_1 opt_del rsync_stat_str_1 rsync_stat_str_2 rsync_stat_str_3
	tmp_file_1="$(mktemp)"
	
	func_rsync_simple "$@" --stats --dry-run --delete > "${tmp_file_1}"

	# check if need ask, depends on options: --stats
	rsync_stat_str_1='Number of created files: 0$'
	rsync_stat_str_2='Number of deleted files: 0$'
	rsync_stat_str_3='Number of regular files transferred: 0$'
	if grep -q "${rsync_stat_str_1}" "${tmp_file_1}" &&  grep -q "${rsync_stat_str_2}" "${tmp_file_1}" &&  grep -q "${rsync_stat_str_3}" "${tmp_file_1}" ; then
		echo "INFO: ${1} -> ${2}: nothing need to update"
		echo "INFO: ${1} -> ${2}: detail log: ${tmp_file_1}"
		return 0
	fi

	# show brief and ask
	func_rsync_out_brief "${tmp_file_1}" 
	sleep 1
	echo "INFO: there are changes for: ${1} -> ${2}"
	echo "INFO: detail log: ${tmp_file_1} ( $(func_file_lines "${tmp_file_1}" lines ) )"
	func_ask_yes_or_no "Do you want to run (y/n)?" || return 1 
	[[ "$*" = *--delete* ]] || opt_del="--delete"
	func_rsync_simple "$@" ${opt_del}
}

# shellcheck disable=2086
func_rsync_simple() {
	local usage="Usage: ${FUNCNAME[0]} <src> <tgt> <add_options>" 
	local desc="Desc: rsync between source and target" 
	[ $# -lt 2 ] && echo -e "${desc} \n ${usage} \n" && exit 1

	local src tgt rsync_big_ver

	# check rsync version
	rsync_big_ver="$(rsync --version | head -1 | sed -e "s/^[^0-9]*\([0-9]\).*$/\1/" )"
	(( "${rsync_big_ver}" < 3 )) && func_die "ERROR: rsync verison too low, exit, pls check!"

	# check path
	src="${1}"
	tgt="${2}"
	shift; shift;
	func_validate_path_exist "${src}" "${tgt}"

	func_info "CMD: rsync -avP $* ${src} ${tgt} 2>&1"
	rsync -avP "$@" "${src}" "${tgt}" 2>&1
}

func_rsync_del_detect() {
	local usage="Usage: ${FUNCNAME[0]} <src> <tgt>" 
	local desc="Desc: detect if any file need delete" 
	[ $# -lt 2 ] && echo -e "${desc} \n ${usage} \n" && exit 1

	#echo rsync --dry-run -rv --delete "${1}" "${2}"
	rsync --dry-run -rv --delete "${1}" "${2}"	\
		| grep '^deleting '			\
		| sed -e 's+/[^/]*$+/+'			\
		| sort -u
}

func_rsync_out_brief() {
	local usage="Usage: ${FUNCNAME[0]} <log_file>" 
	local desc="Desc: show brief of rsync out" 
	[ $# -lt 1 ] && echo -e "${desc}\n${usage} \n" && exit 1

	local log_file del_count
	log_file="${1}"
	func_complain_path_not_exist "${log_file}" && return 1
	del_count="$(grep -c "^deleting " "${log_file}")"

	awk -v del_count="${del_count}" '
	BEBIN {}

		/DEBUG|INFO|WARN|ERROR/ { print; next; }	# reserve log lines

		/\/$/ { next; }					# remove dirs in output, which not really will change
		/^File list / { next; }
		/^Total bytes / { next; }
		/^Literal data:/ { next; }
		/^Matched data:/ { next; }
		/^Number of files:/ { next; }
		/^Total file size:/ { next; }
		/^Total transferred file/ { next; }
		/^sending incremental file/ { next; }

		/^deleting / {
			if (del_count > 50) {			# need shrink lines if too much
				sub("[^/]*$", "", $0); 		# remove leaf files to reduce lines (by func_shrink_dup_lines later)
				print "updating " $0;
			} else {
				print $0;
			}
			next;
		}

		/\// {
			sub("[^/]*$", "", $0); 			# remove leaf files to reduce lines (by func_shrink_dup_lines later)
			print "updating " $0;
			next;
		}

		// { print $0; }				# for other lines, just print out

	END {
		print "======== NOTE: Lines Compacted, Check Detail ! ========"
	}' "${log_file}"					\
	| head --lines=-3					\
	| func_shrink_dup_lines 
}

# TODO: seems deprecated
func_rsync_out_filter_mydoc() {
	# shellcheck disable=2148
	awk '
		/DEBUG|INFO|WARN|ERROR/ { print;next; }	# reserve log lines

		/^$/ {			next;}	# skip empty lines
		/\/$/ {			next;}	# skip dir lines
		/^sent / {		next;}	# skip rsync lines
		/^sending / {		next;}	# skip rsync lines
		/^total size / {	next;}	# skip rsync lines
		/%.*\/s.*:..:/ {	next;}	# skip rsync lines (progress), sample: "171,324 100%   66.07MB/s    0:00:00 (xfr#1, ir-chk=1038/78727)"
		/\(xfr#.*(ir|to)-chk=/ {next;}	# skip rsync lines (progress), sample: "171,324 100%   66.07MB/s    0:00:00 (xfr#1, ir-chk=1038/78727)"

		# compact those too noisy output. Use last blank line to trigger the summary count
		/^FCS\/maven\/m2_repo\/repository/ {
			mvn_repo_updated_files++;
			if(mvn_repo_update_flag == 0){
				print "MAVEN REPO: START TO UPDATE.";
				mvn_repo_update_flag = 1;
			}
			next;
		} 
		/^DCD\/mail/ {
			dcd_mail_updated_files++;
			if(dcd_mail_updated_flag == 0){
				print "DCD MAIL: START TO UPDATE.";
				dcd_mail_updated_flag = 1;
			}
			next;
		} 
		/^\s*$/ {		
			if(mvn_repo_update_flag == 1 ) {
				print "MAVEN REPO: UPDATED FILES: " mvn_repo_updated_files; 
				mvn_repo_update_flag = 2;
			}; 
			if(dcd_mail_updated_flag == 1){
				print "DCD MAIL: UPDATED_FILES: " dcd_mail_updated_files;
				dcd_mail_updated_flag = 2;
			}
			next;
		} 

		!/\/$/ { print $0; }			# for other lines, just print out
	'
}

################################################################################
# Shell Scripting
################################################################################
func_script_self() { 
	local usage="Usage: ${FUNCNAME[0]}" 
	local desc="Desc: get fullpath of self (script)" 

	test -L "$0" && readlink "$0" || echo "$0"
}

func_script_origin_base() { 
	local usage="Usage: ${FUNCNAME[0]} <suffix> (MUST invoke in script !!!)" 
	local desc="Desc: get origin dir of current script (e.g. when script is a soft link, will get its original dir), suffix will be directly added to the base dir" 

	local script_original_path script_dir
	script_original_path="$(readlink -f "${0}")"
	script_dir="$(dirname "${script_original_path}")"
	func_is_str_empty "${script_dir}" && func_die "ERROR: failed to get script dir (empty), pls check"

	readlink -f "${script_dir}/${*}"
}

func_script_base() { 
	local usage="Usage: ${FUNCNAME[0]} <suffix> (MUST invoke in script !!!)" 
	local desc="Desc: get dir of current script (soft link script will NOT get its original dir), suffix will be directly added to the base dir" 

	local script_dir
	script_dir="$(dirname "${0}")"
	func_is_str_empty "${script_dir}" && func_die "ERROR: failed to get script dir (empty), pls check"

	readlink -f "${script_dir}/${*}"
	#base="$(readlink -f $(dirname ${0}))"
}

func_script_base_of_parent() { 
	local usage="Usage: ${FUNCNAME[0]} (MUST invoke in script !!!)" 
	local desc="Desc: get parent dir of current script" 

	func_script_base "/../"
}

func_script_stacktrace() { 
	local i=1 line file func 
	while read -r line func file < <(caller "${i}"); do
		echo "[$((++i))] ${file}:${line}:${func}(): $(sed -n "${line}"p "${file}")" >&2 
	done
}

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
	echo "${2:-WARN: cmd ${1} NOT exist}" 1>&2 
	return 0
}

func_validate_cmd_exist() {
	local usage="Usage: ${FUNCNAME[0]} <cmd> ..."
	local desc="Desc: the cmd must be exist, otherwise will exit" 
	func_param_check 1 "$@"

	local p
	for p in "$@" ; do
		func_is_cmd_exist "${p}" || func_die "ERROR: cmd (${p}) NOT exist!"
	done
}

func_validate_function_exist() {
	local usage="USAGE: ${FUNCNAME[0]} <function-name>" 
	local desc="Desc: check if <function-name> exist as a function" 
	func_param_check 1 "$@"
	
	func_is_function_exist "${1}" && return 0
	func_die "ERROR: ${1} NOT exist or NOT a function!"
}

func_is_funcn_exist() { func_is_function_exist "$@" ; }
func_is_function_exist() {
	local usage="USAGE: ${FUNCNAME[0]} <function-name>" 
	local desc="Desc: check if <function-name> exist as a function, return 0 if exist and a function, otherwise 1" 
	func_param_check 1 "$@"
	
	[ -n "$(type -t "${1}")" ] && [ "$(type -t "${1}")" = function ] && return 0 
	return 1
}

func_complain_func_inexist() { func_complain_function_not_exist "$@" ; }
func_complain_function_not_exist() {
	local usage="USAGE: ${FUNCNAME[0]} <function-name>" 
	local desc="Desc: complain if <function-name> NOT exist as a function, return 1 if not exist or not a function, otherwise 1" 
	func_param_check 1 "$@"

	func_is_function_exist "${1}" && return 1
	echo "WARN: ${1} NOT exist or NOT a function" 1>&2
}

func_complain_sudo_not_auto() { 
	local usage="Usage: ${FUNCNAME[0]} <msg>"
	local desc="Desc: complains if current user not have sudo privilege, or need input password, return 0 if not have, otherwise 1" 
	
	( ! sudo -n ls &> /dev/null) && echo "${2:-WARN: current user NOT have sudo privilege, or NOT auto (need input password), pls check}" 1>&2 && return 0
	return 1
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

	# TODO:	embrace value with "/', otherwise bash eval complains on chars like &/, which always in path
	# v1: works but not efficient (used in zbox_gen_stg_cnf_vars) : s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
	cat "${exist_files[@]}"			| \
	func_del_blank_hash_lines		| \
	sed -e "s/[[:blank:]]*=[[:blank:]]*/=/;
		s/^/local /"
}


# TODO: code is mostly dup with func_gen_local_vars(), only last sed part diff
# NOTE: this is for those value might have special chars, and value NOT quoted (used in fcw script)
func_gen_local_vars_secure() {
	local usage="Usage: ${FUNCNAME[0]} <file1> <file2> ..."
	local desc="Desc: gen local var definition based on file sequence, embrace each value with quote"
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
	| sed -e '/^[[:blank:]]*\($\|#\)/d;
		s/[[:blank:]]*=[[:blank:]]*/=/;
		s/=/="/;
		s/$/"/;
		s/^/local /'
}

################################################################################
# System: os/platform/machine
################################################################################
# os name def: ALL IN LOWERCASE !!!
# shellcheck disable=2034
OS_UBUNTU="ubuntu"
OS_OSX="osx"
OS_OSXX86="osxx86"
OS_OSXARM="osxarm"
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

func_os_type() {
	# TODO: not really used yet, always use func_os_name?
	case "$OSTYPE" in
		solaris*) echo "SOLARIS" ;;
		darwin*)  echo "OSX" ;; 
		linux*)   echo "LINUX" ;;
		bsd*)     echo "BSD" ;;
		msys*)    echo "WINDOWS" ;;
		cygwin*)  echo "ALSO WINDOWS" ;;
		*)        echo "unknown: $OSTYPE" ;;
	esac
}

func_os_name() {
	# Check release file, some NOT verified
	if [ -f /etc/lsb-release ] ; then					
		# \L is to lowercase. Possible value: $OS_UBUNTU
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

	# Check bash buildin var
	local fullname arch
	if [ -n "$OSTYPE" ] ; then
		fullname="${OSTYPE,,}"
	else
		func_validate_cmd_exist uname
		fullname="$(uname -o)"
		fullname="${fullname,,}"
	fi

	# Detail for osx
	if [[ "${fullname}" = darwin* ]] ; then
		arch="$(uname -m)"
		case "${arch}" in
			x86*)	echo "${OS_OSXX86}"	;return ;;
			arm*)	echo "${OS_OSXARM}"	;return ;;
			*)	echo "${OS_OSX}"	;return ;;
		esac
	fi

	# longer match first, TODO: what if $OSTYPE and $(uname -a) have diff string? list both of them?
	case "${fullname}" in
		solaris*)	echo "${OS_SOLARIS}"	;return ;;
		sunos*)		echo "${OS_SOLARIS}"	;return ;;
		freebsd*)	echo "${OS_FREEBSD}"	;return ;;
		cygwin*)	echo "${OS_CYGWIN}"	;return ;; 
		linux*)		echo "${OS_LINUX}"	;return ;;
		msys*)		echo "${OS_MINGW}"	;return ;;	# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
		bsd*)		echo "${OS_BSD}"	;return ;;
		win*)		echo "${OS_WIN}"	;return ;;	# NOT sure, check on windows
		aix*)		echo "${OS_AIX}"	;return ;;	# NOT sure, check on windows
	esac

	# final
	echo "UNKNOWN_OS_NAME_${OSTYPE}_${fullname}" ;
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
		*)         echo "UNKNOWN_OS_LEN";;
	esac
}

func_os_info() {
	local os_ver=${MY_OS_VER:-$(func_os_ver)}
	local os_len=${MY_OS_LEN:-$(func_os_len)}
	local os_name=${MY_OS_NAME:-$(func_os_name)}
	echo "${os_name}_${os_ver}_${os_len}"
}

func_is_os_osx() {
	[[ "$(func_os_name)" = "${OS_OSX}"* ]]
}

func_pkg_mgmt_cmd() {
	local os_name="$(func_os_name)" 
	[ "${os_name}" = "${OS_DEBIAN}" ] && echo "apt" && return
	func_is_os_osx && [ -d "/opt/local/man" ] && echo "port" && return
	func_is_os_osx && [ -d "/opt/homebrew/Cellar" ] && echo "brew" && return
	echo "UNKNOWN_PKG_CMD"
}

func_pkg_mgmt_ins() {
	local usage="Usage: ${FUNCNAME[0]} <pkg-name> <pkg-more-param>" 
	local desc="Desc: use platform pkg cmd to install package"
	func_param_check 1 "$@"
	
	local pkg_mgmt_cmd="$(func_pkg_mgmt_cmd)"
	func_complain_cmd_not_exist "${pkg_mgmt_cmd}" && return 1

	if [ "${1}" = "${PARAM_NON_INTERACTIVE_MODE}" ] ; then
		shift
		# TODO: seems brew install don't have this mode? -c not works
		[ "${pkg_mgmt_cmd}" = "brew" ] && pkg_mgmt_cmd="brew  install"
		[ "${pkg_mgmt_cmd}" = "apt" ] && pkg_mgmt_cmd="sudo DEBIAN_FRONTEND=noninteractive apt install --yes"
		[ "${pkg_mgmt_cmd}" = "port" ] && pkg_mgmt_cmd="sudo port install -N"
	else
		[ "${pkg_mgmt_cmd}" = "brew" ] && pkg_mgmt_cmd="brew install"
		[ "${pkg_mgmt_cmd}" = "apt" ] && pkg_mgmt_cmd="sudo apt install"
		[ "${pkg_mgmt_cmd}" = "port" ] && pkg_mgmt_cmd="sudo port install"
	fi
	${pkg_mgmt_cmd} "$@"
}

################################################################################
# System: network
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

func_ip_single() {
	# some old version of 'sort' NOT support -V, which is better than plain 'sort'
	func_ip_list | sed -e 's/^\S*\s*//;/^\s*$/d' | sort | head -1
}

func_ip_list() {
	# NOTE: "tr -s ' '" compact space to single for better field identify
	local os_name=${MY_OS_NAME:-$(func_os_name)}

	if func_is_os_osx ; then
		func_ip_list_via_ifconfig_osx
	elif [ "${os_name}" = "${OS_CYGWIN}" ] ; then
		func_ip_list_via_ifconfig_cygwin
	elif [ "${os_name}" = "${OS_WIN}" ] ; then
		func_ip_list_via_ipconfig_win
	else
		func_ip_list_lu
	fi
}

func_ip_list_via_ipconfig_win() {
	# seem directly pipe the output of ipconfig is very slow
	raw_data=$(ipconfig) ; echo "$raw_data" | sed -n -e "/IPv[4] Address/s/^[^:]*: //p"	# IPv4
	raw_data=$(ipconfig) ; echo "$raw_data" | sed -n -e "/IPv[46] Address/s/^[^:]*: //p"	# IPv4 & IPv6
	#ipconfig | sed -n -e '/inet addr/s/.*inet addr:\([.0-9]*\).*/\1/p'
}

func_ip_list_via_ifconfig_cygwin() {
	# non-cygwin env: ifconfig
	/sbin/ifconfig | sed -n -e '/inet addr/s/.*inet6* addr:\s*\([.:a-z0-9]*\).*/\1/p'	# IPv4
	/sbin/ifconfig | sed -n -e '/inet6* addr/s/.*inet6* addr:\s*\([.:a-z0-9]*\).*/\1/p'	# IPv4 & IPv6
}

func_ip_list_via_ifconfig_osx() {
	# output sample: en0:  172.29.160.219
	/sbin/ifconfig -a | tr -s ' '			\
	| awk -F'[% ]' '			
		/^[a-z]/{print "";printf $1}	
		/^\s*inet /{printf " " $2}	
		# Un-comment to show IPv6 addr	
		# /^\s*inet6 /{printf " " $2}	
		END{print ""}'				\
	| sed -e "/127.0.0.1/d;/^\s*$/d;/\s/!d;"	\
	| column -t -s " "
}

func_ip_list_lu() {
	if func_is_cmd_exist ip ; then
		func_ip_list_via_ip_lu
	else func_is_cmd_exist ifconfig
		func_ip_list_via_ifconfig_lu
	fi
}

func_ip_list_via_ifconfig_lu() {
	/sbin/ifconfig -a | tr -s ' '		\
	| awk '					
		/^[a-z]/{printf $1 }		
		/inet /{printf " " $2}	
		# Un-comment to show IPv6 addr	
		#/inet6 addr:/{printf " " $3}	
		/^$/{print}'			\
	| sed -e "/127.0.0.1/d;s/addr://" 	\
	| column -t -s " "
}

func_ip_list_via_ip_lu() {
	/bin/ip addr |				\
	awk '
		/^[0-9]/{printf $2 }; 
		/inet /{print " " $2};'		\
	| sed -e '/127.0.0.1/d;s/\/[0-9][0-9]$//'
}

func_find_idle_port() {
	local usage="USAGE: ${FUNCNAME[0]} <port_start> <port_end>" 
	local desc="Desc: find available/idle port between range <port_start>-<port_end>, if <port_end> missed, will be <port_start>+20. Return 0 and echo 1st idle port, otherwise return 1" 
	func_param_check 1 "$@"
	
	local tmp_port port_end
	local port_start="${1}"
	[ -n "${2}" ] && port_end="${2}" || port_end="$(( port_start + 20))"

	func_is_int_in_range "${port_end}" 1025 65535 || func_die "ERROR: port_end (${port_end}) not in range 1025~65535!)"
	func_is_int_in_range "${port_start}" 1025 65535 || func_die "ERROR: port_start (${port_start}) not in range 1025~65535!)"

	for tmp_port in $(seq "${port_start}" "${port_end}") ; do
		# support linux & osx: netstat on linux/osx use ":/." for port separator
		netstat -an | head | awk '{print gensub(/.*[\.:]/, "", "g", $4)}' | grep -q "${tmp_port}" && continue
		echo "${tmp_port}" && return 0
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


func_is_array_contains() { func_array_contains "$@" ;}
func_array_contains() {
	local usage="USAGE: ${FUNCNAME[0]} <element> <array>" 
	local desc="Desc: check if <array> contains <element>, return 0 if contains, otherwise 1" 
	func_param_check 2 "$@"

	local e
	for e in "${@:2}"; do 
		[[ "$e" == "$1" ]] && return 0
	done
	return 1
}

func_array_join() {
	local usage="USAGE: ${FUNCNAME[0]} <separator_str> <array-elements>" 
	local desc="Desc: join items by separator (string)" 
	func_param_check 2 "$@"
	
	local separator="${1-}"
	local first_item="${2-}"
	if shift 2; then
		# '/#' means prepend "${separator}" string to each element
		printf "%s" "${first_item}" "${@/#/${separator}}"
	fi
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

func_num_to_human_IEC() {
	local usage="Usage: ${FUNCNAME[0]} <number>"
	local desc="Desc: convert to number to human readable form (IEC std, 1K=1024)" 
	func_param_check 1 "$@"
	
	echo "${1}" | numfmt --to=iec
}

func_num_to_human_SI() {
	local usage="Usage: ${FUNCNAME[0]} <number>"
	local desc="Desc: convert to number to human readable form (SI std, 1K=1000)" 
	func_param_check 1 "$@"
	
	echo "${1}" | numfmt --to=si
}

# deprecated by: func_num_to_human_SI / func_num_to_human_IEC
func_num_to_human() {
	local usage="Usage: ${FUNCNAME[0]} <number>"
	local desc="Desc: convert to number to human readable form (IEC std, 1K=1024)"
	func_param_check 1 "$@"
	
	local fraction=''
	local unit_index=0
	local number=${1:-0}
	local UNIT=("" K M G T E P Y Z)
	#local UNIT=({"",K,M,G,T,E,P,Y,Z}) # also works

	while ((number > 1024)); do
		fraction="$(printf ".%02d" $((number % 1024 * 100 / 1024)))"
		number=$((number / 1024))
		# let unit_index++
		(( unit_index++ ))
	done
	echo "${number}${fraction}${UNIT[$unit_index]}"
}

func_sum_1st_columm_SI() {
	local usage="Usage: ${FUNCNAME[0]} <disk> [name]"
	local desc="Desc: sum total size of 1st column, support optional unit suffix (SI unit, 1K=1000, KMGTPEZY)"

	awk '
	BEBIN {sum=0}
	{
		ex = index("KMGTPEZY", substr($1, length($1)))
		if (ex == 0) {
			size = $1
		} else {
			val = substr($1, 0, length($1) - 1)
			size = val * 10^(ex * 3)
		}
		sum += size
	}
	END {print sum}' | numfmt --field=1 --to=si --format="%-6f"
}

################################################################################
# Data Type: string
################################################################################
# 更多 (定义在本文件的其它地方) 
# func_is_str_dati
# func_is_str_date　
func_is_str_empty() {
	local usage="Usage: ${FUNCNAME[0]} <string...>"
	local desc="Desc: check if string is empty (or not defined), return 0 if empty, otherwise 1" 
	func_param_check 1 "$@"
	
	[ -z "${1}" ] && return 0 || return 1
}

func_is_str_digit() {
	local usage="Usage: ${FUNCNAME[0]} <string>"
	local desc="Desc: check if string contains only digit, return 0 if yes, otherwise 1" 
	func_param_check 1 "$@"

	[[ "${1}" =~ ^[0-9]+$ ]] && return 0 || return 1
}

func_is_str_not_blank() {
	func_is_str_blank "$@" && return 1 || return 0
}

func_is_str_blank() {
	local usage="Usage: ${FUNCNAME[0]} <string>"
	local desc="Desc: check if string is blank (or not defined), return 0 if empty, otherwise 1" 
	func_param_check 1 "$@"
	
	# remove all space and use -z to check
	[ -z "${1//[[:space:]]}" ] && return 0 || return 1
}

func_str_trim_right() { 
	local usage="Usage: ${FUNCNAME[0]} <string>"
	local desc="Desc: remove trailing space from string" 
	func_param_check 1 "$@"
	
	local var="$*"
	var="${var%"${var##*[![:space:]]}"}"		# remove trailing whitespace characters
	printf '%s' "$var"
}

func_str_trim_left() { 
	local usage="Usage: ${FUNCNAME[0]} <string>"
	local desc="Desc: remove leading space from string" 
	func_param_check 1 "$@"
	
	# FROM: https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
	local var="$*"
	var="${var#"${var%%[![:space:]]*}"}"		# remove leading whitespace characters
	printf '%s' "$var"
}

func_str_trim() { 
	local usage="Usage: ${FUNCNAME[0]} <string>"
	local desc="Desc: remove leading & trailing space from string" 
	func_param_check 1 "$@"
	
	# FROM: https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
	local var="$*"
	var="${var#"${var%%[![:space:]]*}"}"		# remove leading whitespace characters
	var="${var%"${var##*[![:space:]]}"}"		# remove trailing whitespace characters
	printf '%s' "$var"

	# WORKS
	#echo "${1}" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//;'
}

func_str_common_prefix() {
	local usage="Usage: <OTHER_CMD> | ${FUNCNAME[0]}"
	local desc="Desc: find common prefix of lines" 

	# Ref
	# - https://unix.stackexchange.com/questions/441801/longest-common-prefix-of-lines
	# - https://stackoverflow.com/questions/6973088/longest-common-prefix-of-two-strings-in-bash
	# Note
	# - sed: Use BRE back-references: \(.*\).*\n\1.* (其中"\1"为两行中一样的部分)
	# - sed: N/D的配合，达到一行一行比较的效果，最后输出单行 (即结果) 
	# - 预处理: 去掉前缀的空白字符 / 去掉空行。这里不合适去掉注释行(#开头)，因为它是正常的"str"
	
	# PIPE_CONTENT_GOES_HERE: 这里不用支持通过参数传文件的情况，因为调用方基本上是通过pipe来用它
	sed -e 's/^[[:space:]]*//' | func_del_blank_lines | sed -e 'N;s/^\(.*\).*\n\1.*$/\1\n\1/;D'
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
	func_error "${FUNCNAME[0]} NOT impl yet !!!"
}

func_str_contains_blank() {
	local usage="Usage: ${FUNCNAME[0]} <string...>"
	local desc="Desc: check if parameter contains blank (or not defined) str, return 0 if yes, otherwise 1" 
	func_param_check 1 "$@"
	
	local str
	for str in "$@" ; do
		func_is_str_blank "${str}" && return 0
	done 
	return 1
}

func_str_urldecode() { 
	# pure bash version, from https://stackoverflow.com/questions/6250698/how-to-decode-url-encoded-string-in-shell
	# '$_' 意思是上一个命令的最后一个参数。利用 : (no-op操作符)，让后面的参数变成可以被下一行的 '$_' 来引用到
	# 作者有点玩技巧了，原链接的评论里也有人给出了更易读的方案，直接用个变量承载就好了: urldecode() { local i="${*//+/ }"; echo -e "${i//%/\\x}"; }

	# 注意: 针对有Unicode的情况，没有验证过。下面FAQ链接有提到，url编码规范是在字节level的，所以针对Unicode，也是当作byte来处理的。
	# 这个FAQ里有另外一个版本 (有urlencdoe和urldecode)，有很多关于unicode细节: http://mywiki.wooledge.org/BashFAQ/071
	# 命令行工具: nkf can decode URLs: echo 'https://ja.wikipedia.org/wiki/%E9%87%8E%E8%89%AF%E7%8C%AB' | nkf --url-input

	# ${*//+/ } will replace all + with space 
	: "${*//+/ }";			

	# ${_//%/\\x} will replace all % with \x.
	echo -e "${_//%/\\x}"; 
}
