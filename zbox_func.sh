#!/bin/bash

# Global Variables
ZBOX="${ZBOX:="~/.zbox"}"
ZBOX_CNF="${ZBOX_CNF:-"${ZBOX}/cnf"}"
ZBOX_INS="${ZBOX_INS:-"${ZBOX}/ins"}"
ZBOX_SRC="${ZBOX_SRC:-"${ZBOX}/src"}"
ZBOX_STG="${ZBOX_STG:-"${ZBOX}/stg"}"
ZBOX_TMP="${ZBOX_TMP:-"${ZBOX}/tmp"}"
ZBOX_LOG="${ZBOX_LOG:-"${ZBOX}/tmp/zbox.log"}"

# Constants
ZBOX_FUNC_INS_USAGE="Usage: $FUNCNAME <tname> <tver> <tadd>" 
ZBOX_FUNC_STG_USAGE="Usage: $FUNCNAME <tname> <sname>" 

# Source Library
source ${ZBOX}/zbox_lib.sh || eval "$(wget -q -O - "https://raw.github.com/ouyzhu/zbox/master/zbox_lib.sh")" || exit 1

# Common Functions
function func_zbox_run_script() {
	local usage="Usage: $FUNCNAME <script_name> <run_path> <script>"
	local desc="Desc: run user defined scripts" 

	# check if really need to run
	[ $# -lt 3 -o -z "${3}" ] && func_log_echo "${ZBOX_LOG}" "INFO: user defined script (${1}) not set, skip run it" && return 0
	
	local script_name="${1}"
	local run_path="${2}"
	shift; shift

	func_log_echo "${ZBOX_LOG}" "INFO: executing ${script_name}, run in path: ${run_path}, script: $@"
	func_cd "${run_path}" 
	eval "$*" 
	\cd - &>> ${ZBOX_LOG}
}

# ZBOX Functions
function func_zbox_ins() {
	local desc="Desc: install tool, this should be the single entrance for installing tools"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	func_log_echo "${ZBOX_LOG}" "INFO: (install) start installation for $@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	func_zbox_ins_init_dir "$1"

	# execute pre script
	func_zbox_run_script "ins_pre_script" "${ZBOX_TMP}" "${ins_pre_script}"
	#if [ -n "${ins_pre_script}" ] ; then
	#	func_log_echo "${ZBOX_LOG}" "INFO: (install) executing ins_pre_script, dir: ${ZBOX_TMP}, script: ${ins_pre_script}"
	#	func_cd "${ZBOX_TMP}" 
	#	eval "${ins_pre_script}" 
	#	\cd - &>> ${ZBOX_LOG}
	#fi

	local step
	for step in ${ins_steps} ; do
		case "${step}" in 
			src)		func_zbox_ins_src "$@"	;;
			ucd)		func_zbox_ins_ucd "$@"		;;
			move)		func_zbox_ins_move "$@"		;;
			copy)		func_zbox_ins_copy "$@"		;;
			dep)		func_zbox_ins_dep "$@"		;;
			make)		func_zbox_ins_make "$@"		;;
			env)		func_zbox_ins_env "$@"		;;
			default)	func_zbox_ins_default "$@"	;;
			*)		func_log_die "${ZBOX_LOG}" "ERROR: (install) can not handle installation process step:'${step}', exit!"	;;
		esac
	done

	# Record what have done for that build
	[ -e "${ins_fullpath}" ] && env > "${ins_fullpath}/zbox_ins_record.txt"

	# execute post script
	func_zbox_run_script "ins_post_script" "${ins_fullpath}" "${ins_post_script}"
	#if [ -n "${ins_post_script}" ] ; then
	#	func_log_echo "${ZBOX_LOG}" "INFO: (install) executing ins_post_script, dir: ${ZBOX_TMP}, script: ${ins_post_script}"
	#	func_cd "${ins_fullpath}" 
	#	eval "${ins_post_script}" 
	#	\cd - &>> ${ZBOX_LOG}
	#fi

	# Verify if installation success
	if [ -n "${ins_verify}" ] ; then
		func_log_echo "${ZBOX_LOG}" "INFO: (install) verify installation with script ins_verify='${ins_verify}'"
		eval "${ins_verify}"
		if [ "$?" = "0" ] ; then 
			func_log_echo "${ZBOX_LOG}" "INFO: (install) verify installation success"
		else
			func_log_die "${ZBOX_LOG}" "ERROR: (install) verify installation failed!"
		fi
	fi
}

function func_zbox_mkstage() {
	local desc="Desc: make a working stage, this should be the single entrance for create stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"

	eval $(func_zbox_gen_stage_cnf_vars "$@")
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "${1}" "${stg_tver}" "${stg_tadd}")"

	func_validate_path_exist "${ins_fullpath}"
	[ -z "${stg_tver}" ] && func_log_die "${ZBOX_LOG}" "ERROR: (stage) 'stg_tver' must NOT be empty!"

	func_zbox_stg_init_dir "$@"

	# execute pre script
	func_zbox_run_script "stg_pre_script" "${stg_fullpath}" "${stg_pre_script}"
	#if [ -n "${stg_pre_script}" ] ; then
	#	func_log_echo "${ZBOX_LOG}" "INFO: (stage) executing stg_pre_script, dir: ${stg_fullpath}, script: ${stg_pre_script}"
	#	func_cd "${stg_fullpath}" 
	#	eval "${stg_pre_script}" 
	#	\cd - &>> ${ZBOX_LOG}
	#fi

	func_zbox_stg_gen_ctrl_scripts "$@"

	# execute post script
	func_zbox_run_script "stg_post_script" "${stg_fullpath}" "${stg_post_script}"
	#if [ -n "${stg_post_script}" ] ; then
	#	func_log_echo "${ZBOX_LOG}" "INFO: (stage) executing stg_post_script, dir: ${stg_fullpath}, script: ${stg_post_script}"
	#	func_cd "${stg_fullpath}" 
	#	eval "${stg_post_script}" 
	#	\cd - &>> ${ZBOX_LOG}
	#fi
}

function func_zbox_stg_gen_ctrl_scripts() {
	local desc="Desc: generate control scripts for stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"

	eval $(func_zbox_gen_stage_cnf_vars "$@")
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	local stg_ctrl_stop="${stg_fullpath}/bin/stop.sh"
	local stg_ctrl_start="${stg_fullpath}/bin/start.sh"
	local stg_ctrl_client="${stg_fullpath}/bin/client.sh"
	local stg_ctrl_status="${stg_fullpath}/bin/status.sh"

	func_log_echo "${ZBOX_LOG}" "INFO: (stage) Generating control scripts: ${stg_ctrl_stop}, ${stg_ctrl_start}, ${stg_ctrl_status}, ${stg_ctrl_client}"
	rm "${stg_ctrl_stop}" "${stg_ctrl_start}" "${stg_ctrl_status}" "${stg_ctrl_client}"

	echo "#!/bin/bash" >> "${stg_ctrl_stop}"
	echo "${stg_cmd_stop}" >> "${stg_ctrl_stop}"

	echo "#!/bin/bash" >> "${stg_ctrl_start}"
	echo "${stg_cmd_start} &" >> "${stg_ctrl_start}"

	echo "#!/bin/bash" >> "${stg_ctrl_status}"
	echo "${stg_cmd_status}" >> "${stg_ctrl_status}"

	echo "#!/bin/bash" >> "${stg_ctrl_client}"
	echo "${stg_cmd_client}" >> "${stg_ctrl_client}"
}

function func_zbox_ins_init_dir() {
	local desc="Desc: init directories for <tname>, currently only <tname> is necessary"
	func_param_check 1 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	func_log_echo "${ZBOX_LOG}"  "INFO: (Install) init dir for ${1}"
	mkdir -p "${ZBOX_CNF}/${1}" "${ZBOX_SRC}/${1}" "${ZBOX_INS}/${1}" 
}

function func_zbox_stg_init_dir() {
	local desc="Desc: generate a list of related configure files for stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"

	eval $(func_zbox_gen_stage_cnf_vars "$@")

	func_log_echo "${ZBOX_LOG}" "INFO: (stage) init dir for ${1}"
	func_mkdir_cd "$(func_zbox_gen_stg_fullpath "$@")"
	local p
	for p in ${stg_dirs:-bin conf logs data} ; do
		mkdir -p "${p}"
	done
	\cd - &>> ${ZBOX_LOG}
}

function func_zbox_ins_src() {
	local desc="Desc: init source package or source code specified by 'ins_src_addr'"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local src_fullpath_expect=$(func_zbox_gen_src_fullpath "$@")
	local src_dir="$(dirname "${src_fullpath_expect}")"
	local ver="${2:-pkg}"

	case "${ver}" in
		pkg)		
				func_download "${ins_src_addr}" "${src_dir}" | tee -a "${ZBOX_LOG}"

				# create symboic link if the download name is not 'standard'
				func_cd "${src_dir}" 
				ln -s "${ins_src_addr##*/}" "${src_fullpath_expect}" &>> ${ZBOX_LOG} 
				\cd - &>> ${ZBOX_LOG}										
				;;
		svn|hg|git)	
				func_vcs_update "${ver}" "${ins_src_addr}" "${src_fullpath_expect}" | tee -a "${ZBOX_LOG}"	
				;;
		*)		
				func_log_die "${ZBOX_LOG}" "ERROR: (install) can not get source, ver=${ver}, src_addr=${ins_src_addr}"	
				;;
	esac
}

function func_zbox_ins_default() {
	local desc="Desc: make it as the default one. In other word, create a link only have <tname> info"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	local ins_fullpath_default="$(func_zbox_gen_ins_fullpath_default "$@")"

	rm "${ins_fullpath_default}" &>> ${ZBOX_LOG}
	func_log_echo "${ZBOX_LOG}" "INFO: (install) make this installation as defaut, linking: ${ins_fullpath_default} -> ${ins_fullpath}"
	func_cd "$(dirname "${ins_fullpath}")" 
	ln -s "$(basename "${ins_fullpath}")" "${ins_fullpath_default}" 
	\cd - &>> ${ZBOX_LOG}
}

function func_zbox_ins_dep() {
	local desc="Desc: install dependencies (using apt-get)"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")

	if [ -n "${ins_dep_apt_install}" ] ; then
		func_log_echo "${ZBOX_LOG}" "INFO: (install) dependencies: sudo apt-get install -y ${ins_dep_apt_install}"
		sudo apt-get install -y ${ins_dep_apt_install} &>> ${ZBOX_LOG}
	fi

	if [ -n "${ins_dep_apt_build_dep}" ] ; then
		func_log_echo "${ZBOX_LOG}" "INFO: (install) dependencies: sudo apt-get build-dep ${ins_dep_apt_build_dep}"
		sudo apt-get build-dep -y ${ins_dep_apt_build_dep} &>> ${ZBOX_LOG}
	fi

	if [ -n "${ins_dep_zbox_ins}" ] ; then
		# TODO: how to detect infinite loop?
		local dep_zbox
		for dep_zbox in "${ins_dep_zbox_ins[@]}" ; do
			[ -z "${dep_zbox}" ] && continue
			func_log_echo "${ZBOX_LOG}" "INFO: (install) dependencies: func_zbox_ins ${dep_zbox}"
			func_zbox_ins ${dep_zbox}
		done
	fi
}

function func_zbox_ins_make() {
	local desc="Desc: install by configure > make > make install, the typical installation"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")

	# Pre-Conditions
	local make_steps="${ins_make_steps}"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	local configure_opts="${ins_make_configure_opts}"
	func_validate_path_inexist "${ins_fullpath}"
	[ -z "${make_steps}" ] && func_log_die "${ZBOX_LOG}" "ERROR: (install) 'ins_make_steps' not defined, can not make"

	# Make
	func_cd "$(func_zbox_gen_ucd_fullpath "$@")"
	func_log_echo "${ZBOX_LOG}" "INFO: (install) start make, make_steps='${make_steps}', configure_opts='${configure_opts}'"
	for step in ${make_steps} ; do
		case "${step}" in 
			make)		make &>> ${ZBOX_LOG}					; func_zbox_ins_make_check_result ${step}	;;
			test)		make test &>> ${ZBOX_LOG}				; func_zbox_ins_make_check_result ${step}	;;
			clean)		make clean &>> ${ZBOX_LOG}				; func_zbox_ins_make_check_result ${step}	;;
			install)	make ${ins_make_install_cmd:-install} &>> ${ZBOX_LOG}	; func_zbox_ins_make_check_result ${step}	;;
			configure)	./configure ${configure_opts} &>> ${ZBOX_LOG}		; func_zbox_ins_make_check_result ${step}	;;
			*)		func_log_die "${ZBOX_LOG}" "ERROR: (install) can not handle ${step}, exit!"				;;
		esac
	done
	\cd - &>> ${ZBOX_LOG}
}

function func_zbox_ins_make_check_result() {
	# NOTE, can NOTE do anything, since need check exit status of last command
	#local usage="Usage: $FUNCNAME <make_step>"
	#local desc="Desc: check result of the make_step"
	#func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	if [ "$?" = "0" ] ; then 
		func_log_echo "${ZBOX_LOG}" "INFO: (install) make step of '${1}' success"
	else
		func_log_die "${ZBOX_LOG}" "ERROR: (install) make step of '${1}' failed!"
	fi
}

function func_zbox_ins_env() {
	local desc="Desc: generate env file, some tools need export some env to use (like python)"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local env_fullpath="$(func_zbox_gen_env_fullpath "$@")"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"

	[ -z "${ins_env_vars}" ] && func_log_die "${ZBOX_LOG}" "ERROR: (install) 'ins_env_vars' is empty, can NOT gen env file!"
	rm -f "${env_fullpath}"
	for var in ${ins_env_vars} ; do
		echo "export ${var}" >> "${env_fullpath}"
	done
}

function func_zbox_ins_copy() {
	local desc="Desc: install by copy, this means only need to copy the source package to 'ins' dir"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local dl_fullpath=$(func_zbox_gen_src_fullpath "$@")
	local dl_fullpath_actual=$(readlink -f "${dl_fullpath}")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"

	func_log_echo "${ZBOX_LOG}" "INFO: (install) copy source, from: ${dl_fullpath_actual} to: ${ins_fullpath}"
	func_validate_path_inexist "${ins_fullpath}"
	func_validate_path_exist "${dl_fullpath_actual}"
	func_mkdir "${ins_fullpath}" 
	cp -R "${dl_fullpath_actual}" "${ins_fullpath}"
}

function func_zbox_ins_move() {
	local desc="Desc: install by move, this means only need to move the uncompressed dir to 'ins' dir"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"

	func_log_echo "${ZBOX_LOG}" "INFO: (install) move source, from: ${ucd_fullpath} to: ${ins_fullpath}"
	func_validate_path_inexist "${ins_fullpath}"
	func_validate_path_exist "${ucd_fullpath}"
	mv "${ucd_fullpath}" "${ins_fullpath}"

	# execute post script
	func_zbox_run_script "ins_move_post_script" "${ins_fullpath}" "${ins_move_post_script}"
	#if [ -n "${ins_move_post_script}" ] ; then
	#	func_log_echo "${ZBOX_LOG}" "INFO: (install) executing ins_move_post_script, dir: ${ins_fullpath}, script: ${ins_move_post_script}"
	#	func_cd "${ins_fullpath}" 
	#	eval "${ins_move_post_script}" 
	#	\cd - &>> ${ZBOX_LOG}
	#fi
}

function func_zbox_ins_ucd() {
	local desc="Desc: uncompress the source package"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local src_fullpath="$(func_zbox_gen_src_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"

	func_uncompress "${src_fullpath}" "${ucd_fullpath}"  | tee -a "${ZBOX_LOG}"

	# execute post script
	func_zbox_run_script "ins_ucd_post_script" "${ucd_fullpath}" "${ins_ucd_post_script}"
	#if [ -n "${ins_uncompress_post_script}" ] ; then
	#	func_log_echo "${ZBOX_LOG}" "INFO: (install) executing ins_uncompress_post_script, dir: ${ucd_fullpath}, script: ${ins_uncompress_post_script}"
	#	func_cd "${ucd_fullpath}" 
	#	eval "${ins_uncompress_post_script}" 
	#	\cd - &>> ${ZBOX_LOG}
	#fi
}

function func_zbox_gen_uname() {
	local desc="Desc: generate the unique tool name"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	[ -n "${3}" ] && echo "${1}-${2}-${3}" || echo "${1}-${2}"
}

function func_zbox_gen_usname() {
	local desc="Desc: generate the unique stage name of the tool"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"

	echo "${1}-${2}"
}

function func_zbox_gen_env_fullpath() {
	local desc="Desc: generate full path of the tool's env file"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "$(func_zbox_gen_ins_fullpath "$@")_env"
}

function func_zbox_gen_ins_fullpath() {
	local desc="Desc: generate full path of the tool's installation"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "${ZBOX_INS}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_ins_fullpath_default() {
	local desc="Desc: generate full path of default executable, which is a symbloic link"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "${ZBOX_INS}/${1}/${1}"
}

function func_zbox_gen_src_fullpath() {
	local desc="Desc: generate full path of the source package or source code"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "${ZBOX_SRC}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_ucd_fullpath() {
	local desc="Desc: generate full path of the uncompressed source packages"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "${ZBOX_TMP}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_stg_fullpath() {
	local desc="Desc: generate full path of the stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"

	echo "${ZBOX_STG}/${1}/$(func_zbox_gen_usname "$@")"
}

function func_zbox_gen_stage_cnf_files() {
	local desc="Desc: generate a list of related configure files for stage"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"
	
	local stage_default=${ZBOX_CNF}/${1}/stage 
	local stage_version=${ZBOX_CNF}/${1}/stage-${2}

	echo "${stage_default} ${stage_version}"
}

function func_zbox_gen_stage_cnf_vars() {
	local desc="Desc: generate a list of related configure variables for stage, with ZBOX varibles substituted"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"

	# TODO: need eval twice to get ZBOX var substituted, since need to get "${stg_tver}" "${stg_tadd}" first. Any better way?
	eval $(func_zbox_gen_stage_cnf_vars_raw "$@")
	local src_fullpath="$(func_zbox_gen_src_fullpath "$@")"
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "${1}" "${stg_tver}" "${stg_tadd}")"

	func_zbox_gen_stage_cnf_vars_raw "$@"		|\
	sed -e	"s+ZBOX_TMP+${ZBOX_TMP}+g;
		s+ZBOX_SRC_FULLPATH+${src_fullpath}+g;
		s+ZBOX_INS_FULLPATH+${ins_fullpath}+g;
		s+ZBOX_STG_FULLPATH+${stg_fullpath}+g;"
}

function func_zbox_gen_stage_cnf_vars_raw() {
	local desc="Desc: generate a list of related configure variables for stage, with ZBOX varibles NOT substituted"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"
	
	local cnfs=$(func_zbox_gen_stage_cnf_files "$@")

	cat ${cnfs} 2>> ${ZBOX_LOG}						|\
	sed -e 	"/^\s*#/d;
		/^\s*$/d;
		s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
		s/^/local /"
}

function func_zbox_gen_ins_cnf_files() {
	local desc="Desc: generate a list of related configure files for installation"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_STG_USAGE} \n" "$@"
	
	local ins_default=${ZBOX_CNF}/${1}/ins 
	local ins_version=${ZBOX_CNF}/${1}/ins-${2}
	[ -n "${3}" ] && local ins_addition=${ZBOX_CNF}/${1}/ins-${2}-${3}

	echo "${ins_default} ${ins_version} ${ins_addition}"
}

function func_zbox_gen_ins_cnf_vars() {
	local desc="Desc: 1) generate variable list for functions to source. 2) replace any zbox predefined variales. 3) all variables are prefixed with 'local'"
	func_param_check 2 "${desc} \n ${ZBOX_FUNC_INS_USAGE} \n" "$@"
	
	local cnfs=$(func_zbox_gen_ins_cnf_files "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	local src_fullpath="$(func_zbox_gen_src_fullpath "$@")"

	#cat ${cnfs} 2>> ${ZBOX_LOG} | sed -e "/^\s*#/d;/^\s*$/d;s/^/local /"
	cat ${cnfs} 2>> ${ZBOX_LOG}						|\
	sed -e 	"/^\s*#/d;
		/^\s*$/d;
		s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
		s/^/local /"							|\
	sed -e	"s+ZBOX_TMP+${ZBOX_TMP}+g;
		s+ZBOX_SRC_FULLPATH+${src_fullpath}+g;
		s+ZBOX_INS_FULLPATH+${ins_fullpath}+g;" 
}
