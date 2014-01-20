#!/bin/bash

# Global Variables
ZBOX="${ZBOX:="~/.zbox"}"
ZBOX_CNF="${ZBOX_CNF:="${ZBOX}/cnf"}"
ZBOX_EXE="${ZBOX_EXE:="${ZBOX}/exe"}"
ZBOX_SRC="${ZBOX_SRC:="${ZBOX}/src"}"
ZBOX_STG="${ZBOX_TMP:="${ZBOX}/stg"}"
ZBOX_TMP="${ZBOX_TMP:="${ZBOX}/tmp"}"

# Constants
ZBOX_FUNC_SETUP_USAGE="Usage: $FUNCNAME <tname> <tver> <tadd>" 
ZBOX_FUNC_STAGE_USAGE="Usage: $FUNCNAME <tname> <sname>" 

# Common functions
source ${ZBOX}/zbox_lib.sh || eval "$(wget -q -O - "https://raw.github.com/ouyzhu/zbox/master/zbox_lib.sh")" || exit 1

# Functions
function func_zbox_setup() {
	local desc="Desc: setup tool, this should be the single entrance for setup tool"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")
	func_zbox_setup_init_dir "$1"

	local step
	for step in ${zbox_process} ; do
		case "${step}" in 
			download)	func_zbox_download "$@"		;;
			uncompress)	func_zbox_uncompress "$@"	;;
			ins_move)	func_zbox_ins_move "$@"		;;
			ins_copy)	func_zbox_ins_copy "$@"		;;
			ins_dep)	func_zbox_ins_dep "$@"		;;
			ins_make)	func_zbox_ins_make "$@"		;;
			gen_env)	func_zbox_gen_env "$@"		;;
			as_default)	func_zbox_as_default "$@"	;;
			*)		func_die "ERROR: can not handle setup process step:'${step}', exit!"	;;
		esac
	done
}

function func_zbox_mkstage() {
	local desc="Desc: make a working stage, this should be the single entrance for create stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"

	eval $(func_zbox_gen_stage_cnf_vars "$@")
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "${1}" "${zbox_stage_tver}" "${zbox_stage_tadd}")"

	func_validate_path_exist "${exe_fullpath}"
	[ -z "${zbox_stage_tver}" ] && func_die "ERROR: 'zbox_stage_tver' must NOT be empty!"

	func_zbox_stage_init_dir "$@"

	# execute pre script
	if [ -n "${zbox_stage_pre_script}" ] ; then
		echo "INFO: executing zbox_stage_pre_script, dir: "${stg_fullpath}", script: '${zbox_stage_pre_script}'"
		func_cd "${stg_fullpath}" 
		eval "${zbox_stage_pre_script}" 
		\cd - &> /dev/null
	fi

	func_zbox_stage_gen_ctrl_scripts "$@"

	# execute post script
	if [ -n "${zbox_stage_post_script}" ] ; then
		echo "INFO: executing zbox_stage_post_script, dir: "${stg_fullpath}", script: '${zbox_stage_post_script}'"
		func_cd "${stg_fullpath}" 
		eval "${zbox_stage_post_script}" 
		\cd - &> /dev/null
	fi
}

function func_zbox_stage_gen_ctrl_scripts() {
	local desc="Desc: generate control scripts for stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"

	eval $(func_zbox_gen_stage_cnf_vars "$@")
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	local stg_ctrl_stop="${stg_fullpath}/bin/stop.sh"
	local stg_ctrl_start="${stg_fullpath}/bin/start.sh"
	local stg_ctrl_client="${stg_fullpath}/bin/client.sh"
	local stg_ctrl_status="${stg_fullpath}/bin/status.sh"

	rm "${stg_ctrl_stop}"
	echo "#!/bin/bash" >> "${stg_ctrl_stop}"
	echo "${zbox_stage_cmd_stop}" >> "${stg_ctrl_stop}"

	rm "${stg_ctrl_start}"
	echo "#!/bin/bash" >> "${stg_ctrl_start}"
	echo "${zbox_stage_cmd_start} &" >> "${stg_ctrl_start}"

	rm "${stg_ctrl_status}"
	echo "#!/bin/bash" >> "${stg_ctrl_status}"
	echo "${zbox_stage_cmd_status}" >> "${stg_ctrl_status}"

	rm "${stg_ctrl_client}"
	echo "#!/bin/bash" >> "${stg_ctrl_client}"
	echo "${zbox_stage_cmd_client}" >> "${stg_ctrl_client}"
}

function func_zbox_setup_init_dir() {
	local desc="Desc: init directories for <tname>, currently only <tname> is necessary"
	func_param_check 1 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	echo "INFO: (setup) init dir for ${1}"
	mkdir -p "${ZBOX_CNF}/${1}" "${ZBOX_SRC}/${1}" "${ZBOX_EXE}/${1}" 
}

function func_zbox_stage_init_dir() {
	local desc="Desc: generate a list of related configure files for stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"

	eval $(func_zbox_gen_stage_cnf_vars "$@")

	echo "INFO: (stage) init dir for ${1}"
	func_mkdir_cd "$(func_zbox_gen_stg_fullpath "$@")"
	local p
	for p in ${zbox_stage_dir_list:-bin conf logs data} ; do
		mkdir -p "${p}"
	done
	\cd - &> /dev/null
}

function func_zbox_download() {
	local desc="Desc: download source package or checkout source code specified by 'zbox_url'"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")
	local dl_fullpath_expect=$(func_zbox_gen_src_fullpath "$@")
	local dl_dir="$(dirname "${dl_fullpath_expect}")"
	func_download "${zbox_url}" "${dl_dir}"

	# create symboic link if the download name is not 'standard'
	func_cd "${dl_dir}" 
	ln -s "${zbox_url##*/}" "${dl_fullpath_expect}" &> /dev/null 
	\cd - &> /dev/null
}

function func_zbox_as_default() {
	local desc="Desc: make it as the default one. In other word, create a link only have <tname> info"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"
	local exe_fullpath_default="$(func_zbox_gen_exe_fullpath_default "$@")"

	rm "${exe_fullpath_default}" &> /dev/null
	echo "INFO: make this setup as defaut, linking: ${exe_fullpath_default} -> ${exe_fullpath}"
	func_cd "$(dirname "${exe_fullpath}")" 
	ln -s "$(basename "${exe_fullpath}")" "${exe_fullpath_default}" 
	\cd - &> /dev/null
}

function func_zbox_ins_dep() {
	local desc="Desc: install dependencies (using apt-get)"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")

	if [ -n "${zbox_dependency_apt_get_install}" ] ; then
		echo "INFO: install dependencies: sudo apt-get install -y ${zbox_dependency_apt_get_install}"
		sudo apt-get install -y ${zbox_dependency_apt} &> /dev/null
	fi
	if [ -n "${zbox_dependency_apt_get_build_dep}" ] ; then
		echo "INFO: install dependencies: sudo apt-get build-dep ${zbox_dependency_apt_get_build_dep}"
		sudo apt-get install -y ${zbox_dependency_apt} &> /dev/null
	fi
}

function func_zbox_ins_make() {
	local desc="Desc: install by configure > make > make install, the typical installation"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")

	# Pre-Conditions
	local make_steps="${zbox_process_ins_make_steps}"
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"
	local configure_opts="${zbox_ins_make_configure_opts}"
	func_validate_path_inexist "${exe_fullpath}"
	[ -z "${make_steps}" ] && func_die "ERROR: 'zbox_process_ins_make_steps' not defined, can not make"

	# Make
	func_cd "$(func_zbox_gen_ucd_fullpath "$@")"
	echo "INFO: start make, make_steps='${make_steps}', configure_opts='${configure_opts}'"
	for step in ${make_steps} ; do
		case "${step}" in 
			make)		make &> /dev/null				&& echo "INFO: '${step}' success" || func_die "ERROR: '${step}' failed!"	;;
			make_test)	make test &> /dev/null				&& echo "INFO: '${step}' success" || echo "WARN: '${step}' failed!"		;;
			make_clean)	make clean &> /dev/null				&& echo "INFO: '${step}' success" || echo "WARN: '${step}' failed!"		;;
			make_install)	make install &> /dev/null			&& echo "INFO: '${step}' success" || func_die "ERROR: '${step}' failed!"	;;
			configure)	./configure ${configure_opts} &> /dev/null	&& echo "INFO: '${step}' success" || func_die "ERROR: '${step}' failed!"	;;
			*)		func_die "ERROR: can not handle '${step}', exit!"	;;
		esac
	done
	\cd - &> /dev/null
}

function func_zbox_gen_env() {
	local desc="Desc: generate env file, some tools need export some env to use (like python)"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")
	local env_fullpath="$(func_zbox_gen_env_fullpath "$@")"
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"

	[ -z "${zbox_gen_env_vars}" ] && func_die "ERROR: 'zbox_gen_env_vars' is empty, can NOT gen env file!"
	rm -f "${env_fullpath}"
	for var in ${zbox_gen_env_vars} ; do
		echo "export ${var}" >> "${env_fullpath}"
	done
}

function func_zbox_ins_copy() {
	local desc="Desc: install by copy, this means only need to copy the download package to 'exe' dir"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")
	local dl_fullpath=$(func_zbox_gen_src_fullpath "$@")
	local dl_fullpath_actual=$(readlink -f "${dl_fullpath}")
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"

	echo "INFO: copy source, from: ${dl_fullpath_actual} to: ${exe_fullpath}"
	func_validate_path_inexist "${exe_fullpath}"
	func_validate_path_exist "${dl_fullpath_actual}"
	func_mkdir "${exe_fullpath}" 
	cp -R "${dl_fullpath_actual}" "${exe_fullpath}"
}

function func_zbox_ins_move() {
	local desc="Desc: install by move, this means only need to move the uncompressed dir to 'exe' dir"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"

	echo "INFO: move source, from: ${ucd_fullpath} to: ${exe_fullpath}"
	func_validate_path_inexist "${exe_fullpath}"
	func_validate_path_exist "${ucd_fullpath}"
	mv "${ucd_fullpath}" "${exe_fullpath}"

	# execute post script
	if [ -n "${zbox_process_ins_move_post_script}" ] ; then
		echo "INFO: executing zbox_process_ins_move_post_script, dir: "${exe_fullpath}", script: '${zbox_process_ins_move_post_script}'"
		func_cd "${exe_fullpath}" 
		eval "${zbox_process_ins_move_post_script}" 
		\cd - &> /dev/null
	fi
}

function func_zbox_uncompress() {
	local desc="Desc: uncompress the downloaded package"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	eval $(func_zbox_gen_setup_cnf_vars "$@")
	local src_fullpath="$(func_zbox_gen_src_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"

	[ -e "${ucd_fullpath}" ] && rm -rf "${ucd_fullpath}"
	func_uncompress "${src_fullpath}" "${ucd_fullpath}" 
}

function func_zbox_gen_uname() {
	local desc="Desc: generate the unique tool name"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	[ -n "${3}" ] && echo "${1}-${2}-${3}" || echo "${1}-${2}"
}

function func_zbox_gen_usname() {
	local desc="Desc: generate the unique stage name of the tool"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"

	echo "${1}-${2}"
}

function func_zbox_gen_env_fullpath() {
	local desc="Desc: generate full path of the tool's env file"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	echo "$(func_zbox_gen_exe_fullpath "$@")_env"
}

function func_zbox_gen_exe_fullpath() {
	local desc="Desc: generate full path of the tool's executable"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	echo "${ZBOX_EXE}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_exe_fullpath_default() {
	local desc="Desc: generate full path of default executable, which is a symbloic link"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	echo "${ZBOX_EXE}/${1}/${1}"
}

function func_zbox_gen_src_fullpath() {
	local desc="Desc: generate full path of the source package or source code"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	echo "${ZBOX_SRC}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_ucd_fullpath() {
	local desc="Desc: generate full path of the uncompressed source packages"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"

	echo "${ZBOX_TMP}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_stg_fullpath() {
	local desc="Desc: generate full path of the stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"

	echo "${ZBOX_STG}/${1}/$(func_zbox_gen_usname "$@")"
}

function func_zbox_gen_stage_cnf_files() {
	local desc="Desc: generate a list of related configure files for stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"
	
	local stage_default=${ZBOX_CNF}/${1}/stage 
	local stage_version=${ZBOX_CNF}/${1}/stage-${2}

	echo "${stage_default} ${stage_version}"
}

function func_zbox_gen_stage_cnf_vars() {
	local desc="Desc: generate a list of related configure variables for stage, with ZBOX varibles substituted"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"

	# need eval twice to get substitute ZBOX varibles, any better way?
	eval $(func_zbox_gen_stage_cnf_vars_raw "$@")
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "${@}")"
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "${1}" "${zbox_stage_tver}" "${zbox_stage_tadd}")"

	func_zbox_gen_stage_cnf_vars_raw "$@"		|\
	sed -e	"s+ZBOX_EXE_FULLPATH+${exe_fullpath}+g;
		s+ZBOX_STG_FULLPATH+${stg_fullpath}+g;"
}

function func_zbox_gen_stage_cnf_vars_raw() {
	local desc="Desc: generate a list of related configure variables for stage, with ZBOX varibles NOT substituted"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"
	
	local cnfs=$(func_zbox_gen_stage_cnf_files "$@")

	cat ${cnfs} 2> /dev/null						|\
	sed -e 	"/^\s*#/d;
		/^\s*$/d;
		s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
		s/^/local /"
}

function func_zbox_gen_setup_cnf_files() {
	local desc="Desc: generate a list of related configure files for setup"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STAGE_USAGE} \n" "$@"
	
	local setup_default=${ZBOX_CNF}/${1}/setup 
	local setup_version=${ZBOX_CNF}/${1}/setup-${2}
	[ -n "${3}" ] && local setup_addition=${ZBOX_CNF}/${1}/setup-${2}-${3}

	echo "${setup_default} ${setup_version} ${setup_addition}"
}

function func_zbox_gen_setup_cnf_vars() {
	local desc="Desc: 1) generate variable list for functions to source. 2) replace any zbox predefined variales. 3) all variables are prefixed with 'local'"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_SETUP_USAGE} \n" "$@"
	
	local cnfs=$(func_zbox_gen_setup_cnf_files "$@")
	local exe_fullpath="$(func_zbox_gen_exe_fullpath "$@")"

	#cat ${cnfs} 2> /dev/null | sed -e "/^\s*#/d;/^\s*$/d;s/^/local /"
	cat ${cnfs} 2> /dev/null						|\
	sed -e 	"/^\s*#/d;
		/^\s*$/d;
		s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
		s/^/local /"							|\
	sed -e	"s+ZBOX_EXE_FULLPATH+${exe_fullpath}+g;
		" 
}
