#!/bin/bash

ZBOX=~/.zbox
ZBOX_CNF="${ZBOX}/cnf"
ZBOX_EXE="${ZBOX}/exe"
ZBOX_SRC="${ZBOX}/src"
[ ! -e "${ZBOX}" ] && mkdir "${ZBOX}" 

source ${ZBOX}/zbox/script/env_func_bash.sh

function func_zbox_init() {
	func_param_check 1 "Usage: $FUNCNAME <tname>" "$@"

	echo "INFO: init dir for ${1}"
	mkdir -p "${ZBOX_CNF}/${1}" "${ZBOX_SRC}/${1}" "${ZBOX_EXE}/${1}" 
}

function func_zbox_gen_uname() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	[ -n "${3}" ] && echo "${1}-${2}-${3}" || echo "${1}-${2}"
}

function func_zbox_gen_exe_path() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	echo "${ZBOX_EXE}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_exe_path_link() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	echo "${ZBOX_EXE}/${1}/${1}"
}

function func_zbox_gen_src_path() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	echo "${ZBOX_SRC}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_src_path_extract() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	echo "/tmp/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_cnf_files() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"
	
	local setup_default=${ZBOX_CNF}/${1}/setup 
	local setup_version=${ZBOX_CNF}/${1}/setup-${2}
	[ -n "${3}" ] && local setup_addition=${ZBOX_CNF}/${1}/setup-${2}-${3}

	echo "${setup_default} ${setup_version} ${setup_addition}"
}

function func_zbox_gen_cnf_vars() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"
	
	local cnfs=$(func_zbox_gen_cnf_files "$@")
	#cat ${cnfs} 2> /dev/null | sed -e "/^\s*#/d;/^\s*$/d;s/^/local /"
	cat ${cnfs} 2> /dev/null	\
	| sed -e "/^\s*#/d;
		  /^\s*$/d;
		  s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
		  s/^/local /"
}

function func_zbox_setup() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local step

	for step in ${zbox_setup_process} ; do
		case "${step}" in 
			getsrc)		func_zbox_setup_getsrc "$@"	;;
			extract)	func_zbox_setup_extract "$@"	;;
			move)		func_zbox_setup_move "$@"	;;
			mklink)		func_zbox_setup_mklink "$@"	;;
		esac
	done
}

function func_zbox_setup_mklink() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local exe_path="$(func_zbox_gen_exe_path "$@")"
	local exe_path_link="$(func_zbox_gen_exe_path_link "$@")"

	[ -e "${exe_path_link}" ] && echo "INFO: exe_path_link ("${exe_path_link}") already exist, skip create link" && return 0
	echo "INFO: create link: ${exe_path_link} > ${exe_path}"
	ln -s "${exe_path}" "${exe_path_link}"
}

function func_zbox_setup_move() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local exe_path="$(func_zbox_gen_exe_path "$@")"
	local src_path_extract="$(func_zbox_gen_src_path_extract "$@")"

	echo "INFO: move source: ${src_path_extract} > ${exe_path}"
	func_validate_inexist "${exe_path}"
	func_validate_exist "${src_path_extract}"
	mv "${src_path_extract}" "${exe_path}"
}

function func_zbox_setup_extract() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local src_path="$(func_zbox_gen_src_path "$@")"
	local src_path_extract="$(func_zbox_gen_src_path_extract "$@")"

	echo "INFO: extract source: ${src_path} > ${src_path_extract}"
	[ -e "${src_path_extract}" ] && rm -rf "${src_path_extract}"
	func_uncompress "${src_path}" "${src_path_extract}" &> /dev/null
}

function func_zbox_setup_getsrc() {
	func_param_check 2 "Usage: $FUNCNAME <tname> <tver> <tadd>" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local target=$(func_zbox_gen_src_path "$@")
	
	case "${zbox_setup_url}" in
		*.7z | *.gz | *.tgz | *.bz2 | *.tar | *.rar | *.zip)
			func_zbox_setup_getsrc_wget "${zbox_setup_url}" "${target}"
		;;
	esac
}

function func_zbox_setup_getsrc_wget() {
	func_param_check 2 "Usage: $FUNCNAME <url> <target>" "$@"

	[ -e "${2}" ] && echo "INFO: ${2} already exist, skip download" && return 0

	echo "INFO: download source: ${1} > ${2}"
	\cd $(dirname "${2}")
	local downloadname="${1##*/}"
	wget ${1} 
	[ ! -e "${downloadname}" ] && func_die "ERROR: can not find download file (${downloadname}), seems download faild!"
	[ "${downloadname}" = "$(basename ${2})" ] || ln -s ${downloadname} ${2}
	\cd -
}
