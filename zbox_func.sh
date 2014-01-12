#!/bin/bash

ZBOX=~/.zbox
ZBOX_CNF="${ZBOX}/cnf"
ZBOX_EXE="${ZBOX}/exe"
ZBOX_SRC="${ZBOX}/src"
ZBOX_TMP="${ZBOX}/tmp"
ZBOX_FUNC_USAGE="Usage: $FUNCNAME <tname> <tver> <tadd>" 

[ ! -e "${ZBOX}" ] && mkdir -p "${ZBOX}" 
source ${ZBOX}/zbox_lib.sh || eval "$(wget -q -O - "https://raw.github.com/ouyzhu/zbox/master/zbox_lib.sh")" || exit 1

function func_zbox_setup() {
	local desc="Desc: setup tool, this should be the single entrance of zbox"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local step

	func_zbox_init "$1"
	for step in ${zbox_process} ; do
		case "${step}" in 
			download)	func_zbox_download "$@"		;;
			uncompress)	func_zbox_uncompress "$@"	;;
			ins_move)	func_zbox_ins_move "$@"		;;
			ins_copy)	func_zbox_ins_copy "$@"		;;
			ins_make)	func_zbox_ins_make "$@"		;;
			as_default)	func_zbox_as_default "$@"	;;
			*)		func_die "ERROR: can not handle '${step}', exit!"	;;
		esac
	done
}

function func_zbox_init() {
	local desc="Desc: init directories for <tname>, currently only <tname> is necessary"
	func_param_check 1 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	echo "INFO: init dir for ${1}"
	mkdir -p "${ZBOX_CNF}/${1}" "${ZBOX_SRC}/${1}" "${ZBOX_EXE}/${1}" 
}

function func_zbox_download() {
	local desc="Desc: download source package or checkout source code specified by 'zbox_url'"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local dl_fullpath_expect=$(func_zbox_gen_src_fullpath "$@")
	local dl_dir="$(dirname "${dl_fullpath_expect}")"
	func_download "${zbox_url}" "${dl_dir}"

	# create symboic link if the download name is not 'standard'
	\cd "${dl_dir}" && ln -s "${zbox_url##*/}" "${dl_fullpath_expect}" &> /dev/null && \cd - &> /dev/null
}

function func_zbox_as_default() {
	local desc="Desc: make it as the default one. In other word, create a link only have <tname> info"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local exe_path="$(func_zbox_gen_exe_fullpath "$@")"
	local exe_path_default="$(func_zbox_gen_exe_fullpath_default "$@")"

	rm "${exe_path_default}" &> /dev/null
	echo "INFO: make this setup as defaut, linking: ${exe_path_default} -> ${exe_path}"
	\cd "$(dirname "${exe_path}")" && ln -s "$(basename "${exe_path}")" "${exe_path_default}" && \cd - &> /dev/null
}

function func_zbox_ins_make() {
	local desc="Desc: install by configure > make > make install, the typical installation"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")

	if [ -n "${zbox_dependency_apt}" ] ; then
		echo "INFO: install dependencies: sudo apt-get install -y ${zbox_dependency_apt}"
		sudo apt-get install -y ${zbox_dependency_apt} &> /dev/null
	fi

	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"
	local configure_opts="$(echo "${zbox_ins_make_configure_opts}" | sed -e "s+--prefix=zbox_configure_prefix+--prefix=${exe_fullpath}+" )"
	func_validate_path_inexist "${exe_fullpath}"

	\cd "$(func_zbox_gen_ucd_fullpath "$@")"
	local make_steps="${zbox_process_ins_make_steps:-"make_clean configure make make_install"}"
	echo "INFO: start make, make_steps='${make_steps}', configure_opts='${configure_opts}'"
	for step in ${make_steps} ; do
		case "${step}" in 
			make)		make &> /dev/null				&& echo "INFO: '${step}' success" || func_die "ERROR: '${step}' failed!"				;;
			make_test)	make test &> /dev/null				&& echo "INFO: '${step}' success" || echo "WARN: '${step}' failed!"			;;
			make_clean)	make clean &> /dev/null				&& echo "INFO: '${step}' success" || echo "WARN: '${step}' failed!"			;;
			make_install)	make install &> /dev/null			&& echo "INFO: '${step}' success" || func_die "ERROR: '${step}' failed!"			;;
			configure)	./configure ${configure_opts} &> /dev/null	&& echo "INFO: '${step}' success" || func_die "ERROR: '${step}' failed!"	;;
			*)		func_die "ERROR: can not handle '${step}', exit!"	;;
		esac
	done
	#./configure ${configure_opts} &> /dev/null && make &> /dev/null && make install &> /dev/null
	\cd - &> /dev/null
}

function func_zbox_ins_copy() {
	local desc="Desc: install by copy, this means only need to copy the download package to 'exe' dir"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local dl_fullpath=$(func_zbox_gen_src_fullpath "$@")
	local dl_fullpath_actual=$(readlink -f "${dl_fullpath}")
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"

	echo "INFO: copy source, from: ${dl_fullpath_actual} to: ${exe_fullpath}"
	func_validate_path_inexist "${exe_fullpath}"
	func_validate_path_exist "${dl_fullpath_actual}"
	func_mkdir "${exe_fullpath}" && cp -R "${dl_fullpath_actual}" "${exe_fullpath}"
}

function func_zbox_ins_move() {
	local desc="Desc: install by move, this means only need to move the uncompressed dir to 'exe' dir"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"

	echo "INFO: move source, from: ${ucd_fullpath} to: ${exe_fullpath}"
	func_validate_path_inexist "${exe_fullpath}"
	func_validate_path_exist "${ucd_fullpath}"
	mv "${ucd_fullpath}" "${exe_fullpath}"
}

function func_zbox_uncompress() {
	local desc="Desc: uncompress the downloaded package"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	eval $(func_zbox_gen_cnf_vars "$@")
	local src_fullpath="$(func_zbox_gen_src_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"

	[ -e "${ucd_fullpath}" ] && rm -rf "${ucd_fullpath}"
	func_uncompress "${src_fullpath}" "${ucd_fullpath}" 
}

function func_zbox_gen_uname() {
	local desc="Desc: generate the unique name of the tool"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	[ -n "${3}" ] && echo "${1}-${2}-${3}" || echo "${1}-${2}"
}

function func_zbox_gen_exe_fullpath() {
	local desc="Desc: generate full path of the tool's executable"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	echo "${ZBOX_EXE}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_exe_fullpath_default() {
	local desc="Desc: generate full path of default executable, which is a symbloic link"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	echo "${ZBOX_EXE}/${1}/${1}"
}

function func_zbox_gen_src_fullpath() {
	local desc="Desc: generate full path of the source package or source code"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	echo "${ZBOX_SRC}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_ucd_fullpath() {
	local desc="Desc: generate full path of the uncompressed source packages"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"

	echo "${ZBOX_TMP}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_cnf_files() {
	local desc="Desc: generate a list of related configure files"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"
	
	local setup_default=${ZBOX_CNF}/${1}/setup 
	local setup_version=${ZBOX_CNF}/${1}/setup-${2}
	[ -n "${3}" ] && local setup_addition=${ZBOX_CNF}/${1}/setup-${2}-${3}

	echo "${setup_default} ${setup_version} ${setup_addition}"
}

function func_zbox_gen_cnf_vars() {
	local desc="Desc: generate variable list for functions to source, all variables are prefixed with 'local'"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_USAGE} \n" "$@"
	
	local cnfs=$(func_zbox_gen_cnf_files "$@")
	#cat ${cnfs} 2> /dev/null | sed -e "/^\s*#/d;/^\s*$/d;s/^/local /"
	cat ${cnfs} 2> /dev/null | sed -e 	"/^\s*#/d;
						/^\s*$/d;
						s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
						s/^/local /"
}
