#!/bin/bash

# Check Platform
if [ "$(uname)" == "Darwin" ]; then
	# after osx 10.6.8, "expr" is NOT installed by default
	ZBOX_PLF="osx"
	ZBOX_PLF_PREFIX="osx_"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	# the default platform where zbox borned
	ZBOX_PLF=""
	ZBOX_PLF_PREFIX=""
else
	# NOT support other platform yet
	echo "ERROR: current platform is NOT supported!"
	exit 1
fi

# Global Variables
ZBOX="${ZBOX:="${HOME}/.zbox"}"
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

# Init Check
[ ! -e "${ZBOX_INS}" ] && mkdir "${ZBOX_INS}"
[ ! -e "${ZBOX_STG}" ] && mkdir "${ZBOX_STG}"
[ ! -e "${ZBOX_TMP}" ] && mkdir "${ZBOX_TMP}"

# create the zbox alias
alias zbox='func_zbox'

# Functions
function func_zbox() {
	local desc="Desc: zbox functions"
	local usage="Usage: zbox <list | install | use | using | mkstg | remove | purge> <tool> <version> <addition>"

	# Better way to check parameters?
	[ "${1}" = "install" -o  "${1}" = "use" ] && [ $# -lt 3 ] && echo "${desc}\n${usage} \n ERROR: need provide tool name and version info" && return
	[ $# -lt 1 ] && echo -e "${desc}\n${usage} \n" && return
	
	local action="${1}"
	shift
	case "${action}" in
		# use background job to 
		use)		func_zbox_use "$@"									;;	# do NOT use pipe here, since need source env
		list)		func_zbox_lst "$@" | column -t -s "|"							;;
		using)		func_zbox_uig "$@" | column -t								;;
		mkstg)		func_zbox_stg "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/\(Desc\|INFO\|WARN\|ERROR\):/p"	;;
		purge)		func_zbox_pur "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/\(Desc\|INFO\|WARN\|ERROR\):/p"	;;
		remove)		func_zbox_rem "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/\(Desc\|INFO\|WARN\|ERROR\):/p"	;;
		install)	func_zbox_ins "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/\(Desc\|INFO\|WARN\|ERROR\):/p"	;;
		*)		echo -e "ERROR: can not handle action '${action}' ! \n ${desc}\n${usage}" && return 1	;;
	esac
}

function func_zbox_lst() {
	local desc="Desc: list tool status"

	local tool_line_count=0
	func_zbox_lst_print_head
	pushd "${ZBOX_CNF}" > /dev/null
	for tool in * ; do 

		# only show those specified tools, otherwise all
		#[ -n "$*" ] && !(echo "$*" | grep -q "${tool}") && continue	# works
		[ -n "$*" ] && [[ "$*" != *${tool}* ]]&& continue

		pushd "${tool}" > /dev/null
		for file in *ins-* ; do 

			tool_line_count=$((${tool_line_count}+1)) && ((${tool_line_count}%15==0)) && func_zbox_lst_print_head

			local va=${file#*ins-}
			local version=${va%-*}
			#local addition=${va#${version}-} # NOT work, will equal version if there is no addition
			local addition=$(echo $va | sed -e "s/[^-]*//;s/^-//")
			local ins_fullpath=$(func_zbox_gen_ins_fullpath "${tool}" "${version}" "${addition}")
			local ins=$([ -e "${ins_fullpath}" ] && echo ' Y')

			local stg_in_cnf=""
			if [ -e "stg" ] ; then
				for stgincnf in stg-* ; do 
					local stg_in_cnf="${stgincnf##*-},${stg_in_cnf}"
				done
			fi
			
			local stg_in_stg=""
			if [ -e "${ZBOX_STG}/${tool}" ] ; then
				pushd "${ZBOX_STG}/${tool}" > /dev/null
				for stginstg in $(find . -maxdepth 1 -name "${tool}-*") ; do 
					local stg_in_stg="${stginstg##*-},${stg_in_stg}"
				done
				popd > /dev/null
			fi

			func_zbox_lst_print_item "${tool}" "${version}" "${addition}" "${ins}" "${stg_in_cnf}" "${stg_in_stg}"
		done 
		popd > /dev/null
	done
	popd > /dev/null
	func_zbox_lst_print_tail
	echo "${tool_line_count} tool lines."
}

function func_zbox_lst_print_head() {
	echo "|----|-------|--------|---|----------|----------|"
	echo "|Name|Version|Addition|ins|stg in cnf|stg in stg|"
	echo "|----|-------|--------|---|----------|----------|"
}

function func_zbox_lst_print_tail() {
	echo "|----|-------|--------|---|----------|----------|"
}

function func_zbox_lst_print_item() {
	local desc="Desc: format the output of list"
	func_param_check 4 "${desc}\n${FUNCNAME} <name> <version> <addtion> <ins> <stg_in_cnf> <stg_in_stg>\n" "$@"

	#printf "| %-16s | %-13s | %-9s | %-3s | %-12s | %-12s |\n" "$@"
	printf "|%s|%s|%s|%s|%s|%s|\n" "$@"
}

function func_zbox_rem() {
	local desc="Desc: remove tool (uninstall but keep downloaded source)"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "INFO: remove $@ (uninstall but keep downloaded source)"
	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"

	[ -e "${ins_fullpath}" ] && rm -rf ${ins_fullpath}{,_env}
	[ ! -e "${ins_fullpath}" ] && echo "INFO: remove ${ins_fullpath}{,_env} success" || func_die "ERROR: failed to remove ${ins_fullpath}{,_env}"
}

function func_zbox_pur() {
	local desc="Desc: purge tool (uninstall and delete downloaded source)"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "INFO: purge tool (uninstall and delete downloaded source) for $@"
	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local src_plfpath=$(func_zbox_gen_src_plfpath "$@")
	local src_realpath=$(func_zbox_gen_src_realpath "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"

	[ -e "${src_plfpath}" ] && rm -rf "${src_plfpath}"
	[ -e "${src_realpath}" ] && rm -rf "${src_realpath}"
	[ -e "${ins_fullpath}" ] && rm -rf ${ins_fullpath}{,_env}
}

function func_zbox_ins() {
	local desc="Desc: install tool"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "INFO: (install) start installation for $@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	func_zbox_ins_init_dir "$1"

	# execute pre script
	func_zbox_run_script "ins_pre_script" "${ZBOX_TMP}" "${ins_pre_script}" "${ins_pre_script_desc}"

	local step
	for step in ${ins_steps} ; do
		case "${step}" in 
			src)		func_zbox_ins_src "$@"		;;
			ucd)		func_zbox_ins_ucd "$@"		;;
			move)		func_zbox_ins_move "$@"		;;
			copy)		func_zbox_ins_copy "$@"		;;
			copyucd)	func_zbox_ins_copyucd "$@"	;;
			dep)		func_zbox_ins_dep "$@"		;;
			make)		func_zbox_ins_make "$@"		;;
			default)	func_zbox_ins_default "$@"	;;
			*)		func_die "ERROR: (install) can not handle installation process step:'${step}', exit!"	;;
		esac
	done
	# gen env, this step not need to define
	[ -n "${use_env}" -o ${#use_env_alias_array[@]} -ne 0 ] && func_zbox_use_gen_env "$@"

	# Record what have done for that build
	[ -e "${ins_fullpath}" ] && env > "${ins_fullpath}/zbox_ins_record.txt"

	# execute post script
	func_zbox_run_script "ins_post_script" "${ins_fullpath}" "${ins_post_script}"

	# Verify if installation success
	if [ -n "${ins_verify}" ] ; then
		echo "INFO: (install) verify installation with script ins_verify='${ins_verify}'"
		[ -e "${ins_fullpath}_env" ] && source "${ins_fullpath}_env"
		eval "${ins_verify}"
		if [ "$?" = "0" ] ; then 
			echo "INFO: (install) verify installation success"
		else
			echo "ERROR: (install) verify installation failed!"
			# verify is usually the last step, not terminate process seems better
			#func_die "ERROR: (install) verify installation failed!"
		fi
	fi
}

func_zbox_uig() {
	local desc="Desc: show which tool is in using"
	for v in "${!ZBOX_USING_@}" ; do
		echo ${!v}
	done
} 

function func_zbox_use() {
	local desc="Desc: use the tool, usually source the env variables"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local env_fullpath="$(func_zbox_gen_env_fullpath "$@")"

	# Note: suppress echo here, since could use "zbox using" to check
	#echo "INFO: using ${env_fullpath}"
	#[ ! -e "${env_fullpath}" ] && echo "WARN: ${env_fullpath} not exist, seems no env need to source" && return 0

	eval "export ZBOX_USING_${1}='$*'"
	[ -e "${env_fullpath}" ] && source "${env_fullpath}" || echo "ERROR: failed to source ${env_fullpath}, pls check!"
}

function func_zbox_stg() {
	local desc="Desc: make a working stage, this should be the single entrance for create stage"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"

	eval $(func_zbox_gen_stg_cnf_vars "$@")
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "${1}" "${stg_tver}" "${stg_tadd}")"

	func_validate_path_exist "${ins_fullpath}"
	[ -z "${stg_tver}" ] && func_die "ERROR: (stage) 'stg_tver' must NOT be empty!"

	func_zbox_stg_init_dir "$@"

	# execute pre script and pre translate
	func_zbox_run_script "stg_pre_script" "${stg_fullpath}" "${stg_pre_script}"
	func_zbox_stg_pre_translate "$@"

	func_zbox_stg_gen_ctrl_scripts "$@"

	# execute post script
	func_zbox_run_script "stg_post_script" "${stg_fullpath}" "${stg_post_script}"
}

function func_zbox_stg_pre_translate() {
	local desc="Desc: generate control scripts for stage"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"

	eval $(func_zbox_gen_stg_cnf_vars "$@")
	local zbox_username="$(whoami)"
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	local src_plfpath="$(func_zbox_gen_src_plfpath "${1}" "${stg_tver}" "${stg_tadd}")"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "${1}" "${stg_tver}" "${stg_tadd}")"

	[ -z "${stg_pre_translate}" ] && echo "INFO: stg_pre_translate var empty, skip" && return 0

	local f=""
	for f in ${stg_pre_translate} ; do
		[ ! -f "${f}" ] && func_die "ERROR: pre translate failed, can NOT find file: ${f}"
		echo "INFO: translate files defined in var stg_pre_translate: ${f}"
		sed -i -e "s+ZBOX_TMP+${ZBOX_TMP}+g;
			   s+ZBOX_CNF+${ZBOX_CNF}+g;
			   s+ZBOX_USERNAME+${zbox_username}+g;
			   s+ZBOX_SRC_FULLPATH+${src_plfpath}+g;
			   s+ZBOX_INS_FULLPATH+${ins_fullpath}+g;
			   s+ZBOX_STG_FULLPATH+${stg_fullpath}+g;" "${f}"
	done
}

function func_zbox_stg_gen_ctrl_scripts() {
	local desc="Desc: generate control scripts for stage"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"

	eval $(func_zbox_gen_stg_cnf_vars "$@")
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"

	for cmd in ${stg_cmds:-start stop status} ; do
		local cmd_path="${stg_fullpath}/bin/${cmd}.sh"
		local cmd_var_name="stg_cmd_${cmd}"

		rm "${cmd_path}" &> /dev/null
		echo "INFO: (stage) Generating control scripts: ${cmd_path}"
		echo "${!cmd_var_name}" >> "${cmd_path}"
	done
}

function func_zbox_ins_init_dir() {
	local desc="Desc: init directories for <tname>, currently only <tname> is necessary"
	func_param_check 1 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo  "INFO: (Install) init dir for ${1}"
	mkdir -p "${ZBOX_CNF}/${1}" "${ZBOX_SRC}/${1}" "${ZBOX_INS}/${1}" 
}

function func_zbox_stg_init_dir() {
	local desc="Desc: generate a list of related configure files for stage"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"

	echo "INFO: (stage) init dir for $*"
	eval $(func_zbox_gen_stg_cnf_vars "$@")

	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	[ -e "${stg_fullpath}" ] && func_die "ERROR: stg dir already exist, pls check!"

	func_mkdir_cd "${stg_fullpath}"
	local p
	for p in ${stg_dirs:-bin conf logs data} ; do
		mkdir -p "${p}"
	done
	\cd - >> ${ZBOX_LOG} 2>&1
}

function func_zbox_ins_src() {
	local desc="Desc: init source package or source code specified by 'ins_src_addr'"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local src_plfpath=$(func_zbox_gen_src_plfpath "$@")
	local src_realpath="$(func_zbox_gen_src_realpath "$@")"
	local src_fulldir="$(dirname "${src_plfpath}")"
	local ver="${2:-pkg}"

	[ -e "${src_plfpath}" ] && echo "INFO: ${src_plfpath} already exist, skip" && return 0
	case "${ver}" in
		svn|hg|git)	func_vcs_update "${ver}" "${ins_src_addr}" "${src_realpath}"	;;
		*)		func_download "${ins_src_addr}" "${src_fulldir}"		;;
	esac

	# execute post script
	func_zbox_run_script "ins_src_post_script" "${src_fulldir}" "${ins_src_post_script}"

	# create symboic link if the download name is not 'standard'
	if [ ! -e "${src_plfpath}" ] ; then
		func_cd "${src_fulldir}" 
		ln -s "$(basename ${src_realpath})" "$(basename ${src_plfpath})" >> ${ZBOX_LOG} 2>&1 
		\cd - >> ${ZBOX_LOG} 2>&1										
	fi
}

function func_zbox_ins_default() {
	local desc="Desc: make it as the default one. In other word, create a link only have <tname> info"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	local ins_fullpath_default="$(func_zbox_gen_ins_fullpath_default "$@")"

	rm "${ins_fullpath_default}" >> ${ZBOX_LOG} 2>&1
	echo "INFO: (install) make this installation as defaut, linking: ${ins_fullpath_default} -> ${ins_fullpath}"
	func_cd "$(dirname "${ins_fullpath}")" 
	ln -s "$(basename "${ins_fullpath}")" "${ins_fullpath_default}" 
	\cd - >> ${ZBOX_LOG} 2>&1
}

function func_zbox_ins_dep() {
	local desc="Desc: install dependencies (using apt-get on linux, port on osx)"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")

	# dep for linux platform
	if [ -z "${ZBOX_PLF}" ] ; then
		if [ -n "${ins_dep_apt_install}" ] ; then
			echo "INFO: (install) dependencies: sudo apt-get install -y ${ins_dep_apt_install}"
			sudo apt-get install -y ${ins_dep_apt_install} >> ${ZBOX_LOG} 2>&1
		fi

		if [ -n "${ins_dep_apt_build_dep}" ] ; then
			echo "INFO: (install) dependencies: sudo apt-get build-dep ${ins_dep_apt_build_dep}"
			sudo apt-get build-dep -y ${ins_dep_apt_build_dep} >> ${ZBOX_LOG} 2>&1
		fi

		if [ -n "${ins_dep_port_install}" ] ; then
			echo "INFO: (install) dependencies: sudo port install ${ins_dep_port_install}"
			sudo port install ${ins_dep_apt_install} >> ${ZBOX_LOG} 2>&1
		fi
	fi

	# dep for osx platform
	if [ -n "${ins_dep_zbox_ins}" && "${ZBOX_PLF}" = "osx" ] ; then
		# TODO: how to detect infinite loop?
		local dep_zbox
		for dep_zbox in "${ins_dep_zbox_ins[@]}" ; do
			[ -z "${dep_zbox}" ] && continue
			echo "INFO: (install) dependencies: func_zbox_ins ${dep_zbox}"
			func_zbox_ins ${dep_zbox}
		done
	fi
}

function func_zbox_ins_make() {
	local desc="Desc: install by configure > make > make install, the typical installation"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")

	# Pre-Conditions
	local make_steps="${ins_make_steps}"
	local make_opts="${ins_make_make_opts}"
	local install_opts="${ins_make_install_opts}"
	local configure_opts="${ins_make_configure_opts}"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"
	func_validate_path_inexist "${ins_fullpath}"
	[ -z "${make_steps}" ] && func_die "ERROR: (install) 'ins_make_steps' not defined, can not make"

	# execute pre script
	func_zbox_run_script "ins_make_pre_script" "${ZBOX_TMP}" "${ins_make_pre_script}"

	# Make
	local clean_cmd=${ins_make_clean_cmd:-clean} 
	local install_cmd=${ins_make_install_cmd:-install} 
	func_cd "${ucd_fullpath}"
	echo "INFO: (install) start make, make_steps='${make_steps}', make_opts='${make_opts}', install_opts='${install_opts}', install_cmd='${install_cmd}', configure_opts='${configure_opts}', clean_cmd='${clean_cmd}'"
	for step in ${make_steps} ; do
		case "${step}" in 
			make)		make ${make_opts} >> ${ZBOX_LOG} 2>&1
					func_check_exit_code "${step} success" "${step} failed" >> ${ZBOX_LOG} 2>&1 
					;;
			test)		make test >> ${ZBOX_LOG} 2>&1
					func_check_exit_code "${step} success" "${step} failed" >> ${ZBOX_LOG} 2>&1 
					;;
			clean)		make ${clean_cmd} >> ${ZBOX_LOG} 2>&1
					func_check_exit_code "${step} success" "${step} failed" >> ${ZBOX_LOG} 2>&1 
					;;
			install)	make ${install_opts} ${install_cmd} >> ${ZBOX_LOG} 2>&1
					func_check_exit_code "${step} success" "${step} failed" >> ${ZBOX_LOG} 2>&1 
					;;
			configure)	./configure ${configure_opts} >> ${ZBOX_LOG} 2>&1
					func_check_exit_code "${step} success" "${step} failed" >> ${ZBOX_LOG} 2>&1
					func_zbox_run_script "ins_configure_post_script" "${ucd_fullpath}" "${ins_configure_post_script}"
					;;
			*)		func_die "ERROR: (install) can not handle ${step}, exit!"				
					;;
		esac
	done

	# execute pre script
	func_zbox_run_script "ins_make_post_script" "${ZBOX_TMP}" "${ins_make_post_script}"

	\cd - >> ${ZBOX_LOG} 2>&1
}

function func_zbox_use_gen_env() {
	local desc="Desc: generate env file, some tools need export some env to use (like python)"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	# NEED support array, but not want to mess in "ins" file
	declare -A use_env_alias_array

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local env_fullpath="$(func_zbox_gen_env_fullpath "$@")"
	rm -f "${env_fullpath}"

	# TODO: update use_env to use_env_arary, so could stop using "|||ZBOX_SPACE|||"
	if [ -n "${use_env}" ] ; then
		echo "INFO: (install) gen env with 'use_env', target: ${env_fullpath}"
		for var in ${use_env} ; do
			[ -e "${var}" ] && echo "source ${var}" >> "${env_fullpath}" && continue	# use "source" if it is a file
			echo "export ${var//|||ZBOX_SPACE|||/ }" >> "${env_fullpath}"			# use "export" otherwise. Any better way to handle the "space"?
		done
	fi

	if [ ${#use_env_alias_array[@]} -ne 0 ] ; then 
		echo "INFO: (install) gen env with 'use_env_alias_array', target: ${env_fullpath}"
		for alias_name in "${!use_env_alias_array[@]}" ; do
			echo "alias ${alias_name}='${use_env_alias_array[$alias_name]}'" >> "${env_fullpath}"
		done
	fi
}

function func_zbox_ins_copyucd() {
	local desc="Desc: install by copy stuff in ucd, usually for those need copy after 'make', which not need to use 'configure --prefix'"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"

	echo "INFO: (install) copy stuff in ucd, from: ${ucd_fullpath} to: ${ins_fullpath}"
	func_validate_path_inexist "${ins_fullpath}"
	func_validate_path_exist "${ucd_fullpath}"

	# only makedir when name is different
	#[ "${ins_fullpath##*/}" = "${ucd_fullpath##*/}" ] || func_mkdir "${ins_fullpath}" 
	func_mkdir "${ins_fullpath}" 
	cp -R "${ucd_fullpath}"/"${ins_copyucd_filter}" "${ins_fullpath}"
}

function func_zbox_ins_copy() {
	local desc="Desc: install by copy, this means only need to copy the source package to 'ins' dir"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local src_realpath=$(func_zbox_gen_src_realpath "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"

	echo "INFO: (install) copy source, from: ${src_realpath} to: ${ins_fullpath}"
	func_validate_path_inexist "${ins_fullpath}"
	func_validate_path_exist "${src_realpath}"
	func_mkdir "${ins_fullpath}" 
	cp -R "${src_realpath}" "${ins_fullpath}"
}

function func_zbox_ins_move() {
	local desc="Desc: install by move, this means only need to move the uncompressed dir to 'ins' dir"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"

	echo "INFO: (install) move source, from: ${ucd_fullpath} to: ${ins_fullpath}"
	func_validate_path_inexist "${ins_fullpath}"
	func_validate_path_exist "${ucd_fullpath}"
	mv "${ucd_fullpath}" "${ins_fullpath}"

	# execute post script
	func_zbox_run_script "ins_move_post_script" "${ins_fullpath}" "${ins_move_post_script}"
}

function func_zbox_ins_ucd() {
	local desc="Desc: uncompress the source package"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	eval $(func_zbox_gen_ins_cnf_vars "$@")
	local src_plfpath="$(func_zbox_gen_src_plfpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"

	rm -rf "${ucd_fullpath}"
	func_uncompress "${src_plfpath}" "${ucd_fullpath}" 

	# execute post script
	func_zbox_run_script "ins_ucd_post_script" "${ucd_fullpath}" "${ins_ucd_post_script}"
}

function func_zbox_gen_uname() {
	local desc="Desc: generate the unique tool name"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	[ -n "${3}" ] && echo "${1}-${2}-${3}" || echo "${1}-${2}"
}

function func_zbox_gen_usname() {
	local desc="Desc: generate the unique stage name of the tool"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"

	echo "${1}-${2}"
}

function func_zbox_gen_env_fullpath() {
	local desc="Desc: generate full path of the tool's env file"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "$(func_zbox_gen_ins_fullpath "$@")_env"
}

function func_zbox_gen_ins_fullpath() {
	local desc="Desc: generate full path of the tool's installation"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "${ZBOX_INS}/${1}/$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_ins_fullpath_default() {
	local desc="Desc: generate full path of default executable, which is a symbloic link"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	echo "${ZBOX_INS}/${1}/${1}"
}

function func_zbox_gen_src_plfpath() {
	local desc="Desc: generate platform dependent path of source package/code, which contains platform prefix (ZBOX_PLF_PREFIX) in filename"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"
	echo "${ZBOX_SRC}/${1}/${ZBOX_PLF_PREFIX}$(func_zbox_gen_uname "$@")"
}

function func_zbox_gen_src_realpath() {
	local desc="Desc: generate real path of source package/code, only conatins uname, tver, tadd info"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	case "${2}" in
		svn|hg|git)	
			# for source code in VS, just use "tver" and "tadd"
			echo "${ZBOX_SRC}/${1}/$(func_zbox_gen_uname "$1" "$2")"	
			;;	
		*)	
			# for package, use the real name in address
			eval $(func_zbox_gen_ins_cnf_vars "$@")
			echo "${ZBOX_SRC}/${1}/${ins_src_addr##*/}"
			;;
	esac
}

# TODO: deprecate this, should use "func_zbox_gen_src_plfpath" instead
#function func_zbox_gen_src_fullpath() {
#	local desc="Desc: generate full path of source package/code"
#	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"
#
#	if [ "${ins_gen_src_fullpath}" = "only_tname_tver" ] ; then
#		#echo "${ZBOX_SRC}/${1}/${ZBOX_PLF_PREFIX}$(func_zbox_gen_uname "${1}" "${2}")"
#		echo "${ZBOX_SRC}/${1}/$(func_zbox_gen_uname "${1}" "${2}")"
#	else
#		#echo "${ZBOX_SRC}/${1}/${ZBOX_PLF_PREFIX}$(func_zbox_gen_uname "$@")"
#		echo "${ZBOX_SRC}/${1}/$(func_zbox_gen_uname "$@")"
#	fi
#}

function func_zbox_gen_ucd_fullpath() {
	local desc="Desc: generate full path of the uncompressed source packages"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"

	if echo "${2}" | grep -q '^\(svn\|hg\|git\)$' ; then
		# obviously, no ucd there, just use the source path
		func_zbox_gen_src_plfpath "$@"
	else
		echo "${ZBOX_TMP}/$(func_zbox_gen_uname "$@")"
	fi
}

function func_zbox_gen_stg_fullpath() {
	local desc="Desc: generate full path of the stage"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"

	echo "${ZBOX_STG}/${1}/$(func_zbox_gen_usname "$@")"
}

function func_zbox_gen_stg_cnf_files() {
	local desc="Desc: generate a list of related configure files for stage"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"
	
	local stg_default=${ZBOX_CNF}/${1}/stg 
	[ -n "${ZBOX_PLF_PREFIX}" ] && local plf_stg_default=${ZBOX_CNF}/${1}/${ZBOX_PLF_PREFIX}stg 

	local stg_version=${ZBOX_CNF}/${1}/stg-${2}
	[ -n "${ZBOX_PLF_PREFIX}" ] && local plf_stg_version=${ZBOX_CNF}/${1}/${ZBOX_PLF_PREFIX}stg-${2}

	echo "${stg_default} ${plf_stg_default} ${stg_version} ${plf_stg_version}"
}

function func_zbox_gen_stg_cnf_vars() {
	local desc="Desc: generate a list of related configure variables for stage, with ZBOX varibles substituted"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"

	# TODO: need eval twice to get ZBOX var substituted, since need to get "${stg_tver}" "${stg_tadd}" first. Any better way?
	eval $(func_zbox_gen_stg_cnf_vars_raw "$@")
	local src_plfpath="$(func_zbox_gen_src_plfpath "$@")"
	local stg_fullpath="$(func_zbox_gen_stg_fullpath "$@")"
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "${1}" "${stg_tver}" "${stg_tadd}")"

	func_zbox_gen_stg_cnf_vars_raw "$@"		|\
	sed -e	"s+ZBOX_TMP+${ZBOX_TMP}+g;
		s+ZBOX_CNF+${ZBOX_CNF}+g;
		s+ZBOX_STG_TVER+${stg_tver}+g;
		s+ZBOX_SRC_FULLPATH+${src_plfpath}+g;
		s+ZBOX_INS_FULLPATH+${ins_fullpath}+g;
		s+ZBOX_STG_FULLPATH+${stg_fullpath}+g;"
}

function func_zbox_gen_stg_cnf_vars_raw() {
	local desc="Desc: generate a list of related configure variables for stage, with ZBOX varibles NOT substituted"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"
	
	local cnfs=$(func_zbox_gen_stg_cnf_files "$@")

	cat ${cnfs} 2>> ${ZBOX_LOG}						|\
	sed -e 	"/^\s*#/d;
		/^\s*$/d;
		s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
		s/^/local /"
}

function func_zbox_gen_ins_cnf_files() {
	local desc="Desc: generate a list of related configure files for installation"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_STG_USAGE} \n" "$@"
	
	local ins_default=${ZBOX_CNF}/${1}/ins 
	[ -n "${ZBOX_PLF_PREFIX}" ] && local plf_ins_default=${ZBOX_CNF}/${1}/${ZBOX_PLF_PREFIX}ins

	local ins_version=${ZBOX_CNF}/${1}/ins-${2}
	[ -n "${ZBOX_PLF_PREFIX}" ] && local plf_ins_version=${ZBOX_CNF}/${1}/${ZBOX_PLF_PREFIX}ins-${2}

	[ -n "${3}" ] && local ins_addition=${ZBOX_CNF}/${1}/ins-${2}-${3}
	[ -n "${3}" ] && [ -n "${ZBOX_PLF_PREFIX}" ] && local plf_ins_addition=${ZBOX_CNF}/${1}/${ZBOX_PLF_PREFIX}ins-${2}-${3}

	# Note the precedence
	echo "${ins_default} ${plf_ins_default} ${ins_version} ${plf_ins_version} ${ins_addition} ${plf_ins_addition}"
}

function func_zbox_gen_ins_cnf_vars() {
	local desc="Desc: 1) generate variable list for functions to source. 2) replace any zbox predefined variales. 3) all variables are prefixed with 'local'"
	func_param_check 2 "${desc}\n${ZBOX_FUNC_INS_USAGE} \n" "$@"
	
	local cnfs=$(func_zbox_gen_ins_cnf_files "$@")
	local ins_fullpath="$(func_zbox_gen_ins_fullpath "$@")"
	local ucd_fullpath="$(func_zbox_gen_ucd_fullpath "$@")"
	local src_plfpath="$(func_zbox_gen_src_plfpath "$@")"
	local src_fulldir="$(dirname "${src_plfpath}")"

	#cat ${cnfs} 2>> ${ZBOX_LOG} | sed -e "/^\s*#/d;/^\s*$/d;s/^/local /"
	cat ${cnfs} 2>> ${ZBOX_LOG}						|\
	sed -e 	"/^\s*#/d;
		/^\s*$/d;
		s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
		s/^/local /"							|\
	sed -e	"s+ZBOX_TMP+${ZBOX_TMP}+g;
	        s+ZBOX_TVER+${2}+g;
		s+ZBOX_SRC_FULLDIR+${src_fulldir}+g;
		s+ZBOX_SRC_FULLPATH+${src_plfpath}+g;
		s+ZBOX_UCD_FULLPATH+${ucd_fullpath}+g;
		s+ZBOX_INS_FULLPATH+${ins_fullpath}+g;" 
}

function func_zbox_run_script() {
	local usage="Usage: $FUNCNAME <script_name> <run_path> <script> <script_desc>"
	local desc="Desc: run user defined scripts" 

	[ $# -lt 3 -o -z "${3}" ] && echo "INFO: user defined script (${1}) not set, skip" && return 0
	
	local script_name="${1}"
	local run_path="${2}"
	local script="${3}"
	local script_desc="${4}"

	echo "INFO: executing ${script_name}, run in path: ${run_path}, script: ${script}"
	func_cd "${run_path}" 
	eval "${script}" 
	# NOTE, do NOT use pipe here, which makes the func_die fail (since pipe creates sub-shell). But how to put a copy in log?
	func_check_exit_code "${script_name} execution success" "${script_desc:-${script_name} execution failed}" 2>&1 
	\cd - >> ${ZBOX_LOG} 2>&1
}
