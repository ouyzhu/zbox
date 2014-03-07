#!/bin/bash

# source ${HOME}/.myenv/myenv_lib.sh || eval "$(wget -q -O - "https://raw.github.com/stico/myenv/master/.myenv/myenv_lib.sh")" || exit 1

function func_date() {	date "+%Y-%m-%d";		}
function func_time() {	date "+%H-%M-%S";		}
function func_dati() {	date "+%Y-%m-%d_%H-%M-%S";	}

function func_die() {
	local usage="Usage: $FUNCNAME <error_info>" 
	local desc="Desc: echo error info to stderr and exit" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1
	
	echo -e "$@" 1>&2
	exit 1
}

function func_param_check {
	local usage="Usage: $FUNCNAME <count> <error_msg> <string> ..."
	local desc="Desc: string counts should 'greater than' or 'equal to' expected count, otherwise print the <error_msg> and exit. Good for parameter amount check." 
	[ $# -lt 2 ] && func_die "${desc} \n ${usage} \n"	# use -lt, so the exit status will not changed in legal condition
	
	local count=$1
	local error_msg=$2
	shift;shift;
	[ $# -lt ${count} ] && func_die "${error_msg}"
}

function func_log_die() {
	local usage="Usage: $FUNCNAME <log_file> <info>" 
	local desc="Desc: echo error info to log_file, them to stderr and exit" 
	func_param_check 2 "${desc} \n ${usage} \n" "$@"
	
	local logfile="${1}"
	echo "[$(date)] $@" >> "${logfile}"
	shift
	func_die "$@"
}

function func_log_echo() {
	local usage="Usage: $FUNCNAME <log_file> <info>"
	local desc="Desc: echo information and also record into log" 
	func_param_check 2 "${desc} \n ${usage} \n" "$@"
	
	local logfile="${1}"
	shift
	echo "[$(date)] $@" | tee -a "${logfile}"
}

function func_cd() {
	local usage="Usage: $FUNCNAME <path>" 
	local desc="Desc: (fail fast) change dir, exit whole process if fail"
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	[ -n "${1}" ] && \cd "${1}" || func_die "ERROR: failed to change dir: cd ${1}"
}

function func_mkdir() {
	local usage="Usage: $FUNCNAME <path> ..." 
	local desc="Desc: (fail fast) create dirs if NOT exist, exit whole process if fail"
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		[ -e "${p}" ] && continue
		mkdir -p "${p}" || func_die "ERROR: failed to create dir ${p}"
	done
}

function func_mkdir_cd { 
	local usage="Usage: $FUNCNAME <path> ..." 
	local desc="Desc: (fail fast) create dir and cd into it. Create dirs if NOT exist, exit if fail, which is different with /bin/mkdir" 
	func_param_check 1 "Usage: $FUNCNAME <path>" "$@"

	func_mkdir "$1" 
	\cd "${1}" || func_die "ERROR: failed to mkdir or cd into it ($1)"

	# to avoid the path have blank, any simpler solution?
	#func_mkdir "$1" && OLDPWD="$PWD" && eval \\cd "\"$1\"" || func_die "ERROR: failed to mkdir or cd into it ($1)"
}

function func_download() {
	local usage="Usage: $FUNCNAME <url> <target>"
	local desc="Desc: download from url to local target" 
	func_param_check 2 "${desc} \n ${usage} \n" "$@"
	
	[ -z "${1}" ] && func_die "ERROR: url is null or empty, download failed"
	[ -f "${2}" ] && echo "INFO: file (${2}) already exist, skip download" && return 0

	case "${1}" in
		*)		func_download_wget "$@"		;;
		#http://*)	func_download_wget "$@" ;;
		#https://*)	func_download_wget "$@" ;;
	esac
}

function func_download_wget() {
	local usage="Usage: $FUNCNAME <url> <target_dir>"
	local desc="Desc: download using wget" 
	func_param_check 2 "${desc} \n ${usage} \n" "$@"

	# if the target exist is an file, just return
	local dl_fullpath="${2}/${1##*/}"
	[ -f "${dl_fullpath}" ] && echo "INFO: file (${dl_fullpath}) already exist, skip download" && return 0

	func_mkdir_cd "${2}" 
	echo "INFO: start download, url=${1} target=${2}"
	# TODO: add control to unsecure options?
	# Command line explain: [Showing File Download Progress Using Wget](http://fitnr.com/showing-file-download-progress-using-wget.html)
	wget --progress=dot --no-check-certificate ${1}	2>&1 | grep --line-buffered "%" | sed -u -e "s,\.,,g" | awk 'BEGIN{printf("INFO: Download progress:  0%")}{printf("\b\b\b\b%4s", $2)}'
	[ -f "${dl_fullpath}" ] || func_die "ERROR: ${dl_fullpath} not found, seems download faild!"
	\cd - &> /dev/null
}

function func_uncompress() {
	local usage="Usage: $FUNCNAME <source> [target_dir]"
	local desc="Desc: uncompress file, based on filename extension, <target_dir> will be the top level dir for uncompressed content" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	func_validate_path_exist "${1}"

	# use readlink to avoid relative path
	source_file="$(readlink -f "${1}")"
	[ -n "${2}" ] && target_dir="$(readlink -f "${2}")" || target_dir="${source_file}_EXTRACT"

	echo "INFO: uncompress file, from: ${source_file} to: ${target_dir}"
	func_mkdir_cd "${target_dir}"
	case "$source_file" in
		#*.Z)		uncompress "$source_file"		;;
		*.rar)		7z e "$source_file" &> /dev/null	;;
		*.7z)		7z e "$source_file" &> /dev/null	;;		# use "-e" will fail
		*.zip)		unzip "$source_file" &> /dev/null	;;
		*.tar)		tar -xvf "$source_file" &> /dev/null	;;
		*.gz)		tar -zxvf "$source_file" &> /dev/null	;;
		*.xz)		tar -Jxvf "$source_file" &> /dev/null	;;
		*.tgz)		tar -zxvf "$source_file" &> /dev/null	;;
		*.bz2)		tar -jxvf "$source_file" &> /dev/null	;;
		#*.tbz2)	tar -jxvf "$source_file" &> /dev/null	;;
		*)		echo "ERROR: unknow format of file: ${source_file}"	;;
	esac

	func_validate_dir_not_empty "${target_dir}"

	# try to move dir level up, there might be only 1 file/dir in the uncompressed 
	if [ "$(ls -A "${target_dir}" | wc -l)" = 1 ] ; then
		mv -f "${target_dir}"/**/* "${target_dir}"/**/.* "${target_dir}"/ &> /dev/null 
		rmdir "${target_dir}"/**/ &> /dev/null 
	fi

	\cd - &> /dev/null
}

function func_bak_file() {
	local usage="Usage: $FUNCNAME <file> ..."
	local desc="Desc: backup file, with suffixed date" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		func_validate_path_exist "${p}"
		[ -d "${p}" ] && func_die "WARN: skipping backup directory ${p}" 

		[ -w "${p}" ] && cp "${p}"{,.bak.$(func_dati)} || sudo cp "${p}"{,.bak.$(func_dati)}
		[ "$?" != "0" ] && func_die "ERROR: backup file ${p} failed!"
	done
}

function func_vcs_update() {
	local usage="Usage: $FUNCNAME <src_type> <src_addr> <target_dir>"
	local desc="Desc: init or update vcs like hg/git/svn"
	func_param_check 3 "${desc} \n ${usage} \n" "$@"

	local src_type="${1}"
	local src_addr="${2}"
	local target_dir="${3}"
	echo "INFO: init/update source, type=${src_type}, addr=${1}, target=${2}"
	case "${src_type}" in
		hg)	local cmd="hg"  ; local cmd_init="hg clone"     ; local cmd_update="hg pull"	;;
		git)	local cmd="git" ; local cmd_init="git clone"    ; local cmd_update="git pull"	;;
		svn)	local cmd="svn" ; local cmd_init="svn checkout" ; local cmd_update="svn update"	;;
		*)	func_die "ERROR: Can not handle src_type (${src_type})"	;;
	esac

	func_validate_cmd_exist ${cmd}
	
	if [ -e "${target_dir}" ] ; then
		\cd "${target_dir}" &> /dev/null
		${cmd_update} || func_die "ERROR: ${cmd_update} failed"
		\cd - &> /dev/null
	else
		mkdir -p "$(dirname ${target_dir})"
		${cmd_init} "${src_addr}" "${target_dir}" || func_die "ERROR: ${cmd_init} failed"
	fi
}

function func_validate_path_exist() {
	local usage="Usage: $FUNCNAME <path> ..."
	local desc="Desc: the path must be exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		[ ! -e "${p}" ] && echo "ERROR: ${p} NOT exist!" && exit 1
	done
}

function func_validate_path_inexist() {
	local usage="Usage: $FUNCNAME <path> ..."
	local desc="Desc: the path must be NOT exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		[ -e "${p}" ] && echo "ERROR: ${p} already exist!" && exit 1
	done
}

function func_validate_cmd_exist() {
	local usage="Usage: $FUNCNAME <cmd> ..."
	local desc="Desc: the cmd must be exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"

	( ! command -v "${1}" &> /dev/null) && echo "ERROR: cmd (${1}) NOT exist!" && exit 1
}

function func_validate_dir_not_empty() {
	local usage="Usage: $FUNCNAME <dir> ..."
	local desc="Desc: the directory must exist and NOT empty, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		[ ! "$(ls -A "${p}" 2> /dev/null)" ] && echo "ERROR: ${p} is empty!" && exit 1
	done
}

function func_validate_dir_empty() {
	local usage="Usage: $FUNCNAME <dir> ..."
	local desc="Desc: the directory must be empty or NOT exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		[ "$(ls -A "${p}" 2> /dev/null)" ] && echo "ERROR: ${p} not empty!" && exit 1
	done
}

