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
	wget -q --no-check-certificate ${1}	# TODO: add control to unsecure options?
	[ -f "${dl_fullpath}" ] || func_die "ERROR: ${dl_fullpath} not found, seems download faild!"
	\cd - &> /dev/null
}

function func_uncompress {
	local usage="Usage: $FUNCNAME <source> <target_dir>"
	local desc="Desc: uncompress file, based on filename extension, <target_dir> will be the top level dir for uncompressed content" 
	func_param_check 2 "${desc} \n ${usage} \n" "$@"

	func_validate_path_exist "$1"
	func_validate_dir_empty "$2"

	target_dir="${2}"
	source_file="$(readlink -f "$1")"
	func_mkdir_cd "${target_dir}"

	echo "INFO: uncompress file, from: ${source_file} to: ${target_dir}"
	case "$source_file" in
		#*.Z)		uncompress "$source_file"	;;
		*.7z)		7z e "$source_file" &> /dev/null		;;	# do NOT use -e, which will fail
		*.gz)		tar -zxvf "$source_file" &> /dev/null	;;
		*.tgz)		tar -zxvf "$source_file" &> /dev/null	;;
		*.xz)		tar -Jxvf "$source_file" &> /dev/null	;;
		*.bz2)		tar -jxvf "$source_file" &> /dev/null	;;
		*.tar)		tar -xvf "$source_file" &> /dev/null	;;
		*.rar)		7z e "$source_file" &> /dev/null	;;
		*.zip)		unzip "$source_file" &> /dev/null	;;
		#*.tbz2)	tar -jxvf "$source_file" &> /dev/null	;;
		*)		echo "ERROR: unknow format of file: ${source_file}"	;;
	esac

	func_validate_dir_not_empty "${target_dir}"

	# try to move dir level up, there might be only 1 file in the compressed file
	if [ "$(ls -A "${target_dir}" | wc -l)" = 1 ] ; then
		mv -f "${target_dir}"/**/* "${target_dir}"/ &> /dev/null 
		rmdir "${target_dir}"/**/ &> /dev/null 
	fi

	\cd - &> /dev/null
}

function func_validate_path_exist() {
	local usage="Usage: $FUNCNAME <path> ..."
	local desc="Desc: the path must be not exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		[ ! -e "${p}" ] && echo "ERROR: ${p} NOT exist!" && exit 1
	done
}

function func_validate_path_inexist() {
	local usage="Usage: $FUNCNAME <path> ..."
	local desc="Desc: the path must be exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		[ -e "${p}" ] && echo "ERROR: ${p} already exist!" && exit 1
	done
}

function func_validate_dir_not_empty() {
	local usage="Usage: $FUNCNAME <dir> ..."
	local desc="Desc: the directory must exist and NOT empty, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for path in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		[ ! "$(ls -A "$path" 2> /dev/null)" ] && echo "ERROR: $path is empty!" && exit 1
	done
}

function func_validate_dir_empty() {
	local usage="Usage: $FUNCNAME <dir> ..."
	local desc="Desc: the directory must be empty or NOT exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for path in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		[ "$(ls -A "$path" 2> /dev/null)" ] && echo "ERROR: $path not empty!" && exit 1
	done
}

