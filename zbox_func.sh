#!/bin/bash
# shellcheck disable=2155

################################################################################
# TODO
################################################################################
# - list python, output duplicated on lapmac2
#	cause: analysis ins-xxx, output 1 line, analysis osx_ins-xxx, output another line
# - support for global use
#	status: dirty tried on 188: 1) chown every thing to root:root. 2) chmod every thing to 777 (some dir like tmp, data, need this even use "sudo start.sh"). 3) chmod 744 for mysql in stg ./conf/my.cnf (since 777 will be ignored). 4) use "sudo bash start.sh". 5) "sudo bash status.sh" need wait 20 seconds after start, otherwise might fail to detect mysql process
#	chanllege : 1) can not su as root, just use sudo. 2) can not create user.
# - "make -j" to speedup, set a default value if NOT set, and respect user settings
# - support defaults
#	default --prefix for ins_make_configure_opts
#	default use_env

################################################################################
# Install zbox
################################################################################
# git way
#	t="$(mktemp -d)" ; cd "${t}" ; git clone https://github.com/ouyzhu/zbox ; mv zbox ~/.zbox ; source "${HOME}/.zbox/zbox_func.sh"
# zip way
#	without git	t="$(mktemp -d)" ; cd "${t}" ; wget https://codeload.github.com/ouyzhu/zbox/zip/master ; unzip master ; mv zbox-master/ "${HOME}/.zbox" ; source "${HOME}/.zbox/zbox_func.sh"
#	install git	zbox install git 2.1.0	# NOTE, if no libcurl4-openssl-dev or libcurl4-gnutls-dev installed, need manually install one (prefer libcurl4-openssl-dev?)
#	use zbox git	zbox use git 2.1.0
#	trans to git	t="$(mktemp -d)" ; cd "${t}" ; git clone --bare http://github.com/ouyzhu/zbox ; mv zbox.git ${HOME}/.zbox/.git ; cd ${HOME}/.zbox ; git init ; git pull ; git reset HEAD

################################################################################
# Constants
################################################################################
ZBOX_PLF_OSX="osx"
ZBOX_PLF_LINUX="linux"
ZBOX_FUNC_INS_USAGE="Usage: ${FUNCNAME[0]} <tname> <tver> [<tadd>]"
ZBOX_FUNC_STG_USAGE="Usage: ${FUNCNAME[0]} <tname> <tver> [<tadd>] <sname>"
#ZBOX_INS_PLF_DEFAULT="osx,linux"
#ZBOX_STG_PLF_DEFAULT="osx,linux"

# Get zbox base dir
ZBOX_FUNC_PATH="${BASH_SOURCE[0]}"
echo "${ZBOX_FUNC_PATH}" | grep -q '.*zbox_func.sh$' || func_die "ERROR: pls put zbox_func.sh as last parameter in source list!"
ZBOX_BASE="$(readlink -f "$(dirname "${ZBOX_FUNC_PATH}")")"

# Global Variables
ZBOX="${ZBOX:="${ZBOX_BASE}"}"
ZBOX_CNF="${ZBOX_CNF:-"${ZBOX}/cnf"}"
ZBOX_INS="${ZBOX_INS:-"${ZBOX}/ins"}"
ZBOX_SRC="${ZBOX_SRC:-"${ZBOX}/src"}"
ZBOX_STG="${ZBOX_STG:-"${ZBOX}/stg"}"
ZBOX_TMP="${ZBOX_TMP:-"${ZBOX}/tmp"}"
ZBOX_LOG="${ZBOX_LOG:-"${ZBOX}/tmp/zbox.log"}"

################################################################################
# Prepare: Check, source, init
################################################################################
# Check Platform. 
if [ "$(uname -s)" == "Darwin" ]; then
	ZBOX_PLF="${ZBOX_PLF_OSX}"
elif [ "$(uname -s)" == "Linux" ]; then
	ZBOX_PLF="${ZBOX_PLF_LINUX}"
else
	echo "ERROR: current platform is NOT supported yet!"
	exit 1
fi

# Check Bash Feature
# shellcheck disable=2016,2026,2034
if (unset a && declare -A a && eval "a['n']='nnn'" && eval '[ -n "${a['n']}" ]') > /dev/null 2>&1 ; then
	BASH_ASSOCIATIVE_ARRAY=true
else
	BASH_ASSOCIATIVE_ARRAY=false
fi

# tname alias, for better listing
if [ "${BASH_ASSOCIATIVE_ARRAY}" = "true" ] ; then
	declare -A tname_alias
	# shellcheck disable=2154
	tname_alias["java"]="jdk"
fi

# Source Library
source "${ZBOX}/zbox_lib.sh" || func_die "ERROR: failed to source library: zbox_lib.sh"

# Init Check
[ ! -e "${ZBOX_INS}" ] && mkdir "${ZBOX_INS}"
[ ! -e "${ZBOX_STG}" ] && mkdir "${ZBOX_STG}"
[ ! -e "${ZBOX_TMP}" ] && mkdir "${ZBOX_TMP}"

################################################################################
# Functions
################################################################################
zbox() {
	local desc="Desc: zbox functions"
	local usage="Usage: zbox <list(lst) | install(ins) | use | using(uig) | test(tst) | mkstg(stg) | remove(rem) | purge(pur)> <tname> <tver> <tadd> <sname>"
	[ $# -lt 1 ] && echo -e "${desc}\n${usage} \n" && return

	local action="${1}"
	shift
	case "${action}" in
		# use background job to 
		use)		zbox_use "$@"										;;	# do NOT use pipe here, since need source env
		uig | using)	zbox_uig "$@" | column -t									;;
		#lst | list)	zbox_lst "$@" | tee -a "${ZBOX_LOG}" | sed -e "/^DEBUG:/d" ;;
		lst | list)	zbox_lst "$@" | tee -a "${ZBOX_LOG}" | sed -e "/^DEBUG:/d" | column -t -s "|"		;;
		tst | test)	zbox_tst "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"	;;	# NOT show DEBUG
		stg | mkstg)	zbox_stg "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"	;;	# NOT show DEBUG
		pur | purge)	zbox_pur "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"	;;	# NOT show DEBUG
		rem | remove)	zbox_rem "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"	;;	# NOT show DEBUG
		ins | install)	zbox_ins "$@" | tee -a "${ZBOX_LOG}" | sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"	;;	# NOT show DEBUG
		*)		echo -e "ERROR: can not handle action '${action}' ! \n ${desc}\n${usage}" && return 1		;;
	esac
}

zbox_tst() {
	local desc="Desc: test zbox install and stage of all tools for current platform"

	if [ $# -lt 2 ] ; then
		zbox_tst_ins_all
		zbox_tst_stg_all
	else
		zbox_tst_ins_single "$@"
		zbox_tst_stg_single "$@"
	fi
}

zbox_tst_ins_all() {
	local desc="Desc: test zbox install of all tools for current platform"
}

zbox_tst_stg_all() {
	local desc="Desc: test zbox stage of all tools for current platform"
}

zbox_tst_ins_single() {
	local desc="Desc: test zbox install of single tool\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	zbox_ins_is_plf_support "$@" || func_die "WARN: $* NOT support for current platform (${ZBOX_PLF})"
	echo "INFO: test ins for: $*"

	func_zbox ins "$@"        | sed -e 's/^/\t/'
	zbox_ins_verify "$@" | sed -e 's/^/\t/' && echo "INFO: installation and verification success" && return 0
	
	echo "ERROR: seems installation failed, will remove the installation!"
	func_zbox rem "$@" | sed -e 's/^/\t/'
	return 1
}

zbox_tst_stg_single() {
	local desc="Desc: test zbox stage of single tool\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	zbox_stg_is_plf_support "$@" || func_die "WARN: $* NOT support for current platform (${ZBOX_PLF})"
	echo "INFO: test stg for: $*"

	func_zbox stg "$@"        | sed -e 's/^/\t/'
	zbox_stg_verify "$@" | sed -e 's/^/\t/' && echo "INFO: mkstg and verification success" && return 0
	
	echo "ERROR: seems mkstg failed"
	return 1

	# TODO: remove stg ?
	#echo "ERROR: seems mkstg failed, will remove the stg!"
	#func_zbox rem "$@" | sed -e 's/^/\t/'
}

zbox_lst() {
	local desc="Desc: list tool status"

	local tname=""
	local target_tname="$*"
	local output_line_count=0

	# use alias if defined
	if [ "${BASH_ASSOCIATIVE_ARRAY}" = "true" ] ; then
		[ -n "${target_tname}" ] && local target_tname_alias="${tname_alias[${target_tname}]}"
		[ -n "${target_tname_alias}" ] && target_tname="${target_tname_alias}"
	fi

	pushd "${ZBOX_CNF}" > /dev/null
	zbox_lst_print_head
	for tname in * ; do 

		# only show those specified tools, otherwise all
		#[ -n "$*" ] && !(echo "$*" | grep -q "${tname}") && continue				# works, strict match
		#[ -n "$*" ] && [[ "$*" != *${tname}* ]] && continue					# works, strict match
		[ -n "${target_tname}" ] && ! (echo "${tname}" | grep -q "${target_tname}") && continue	# works, fuzzy match

		local file=""
		pushd "${tname}" > /dev/null
		for file in ins-* ${ZBOX_PLF}_ins-* ; do	# only check necessary files, e.g. ins file is unecessary to check anytime, linux_ins-xxx is unecessary to check on osx

			# TODO: zbox_ (especially zbox_gen ...) functions cost lots of time

			# when only cnf/xxx/ins file, "ins-*/${ZBOX_PLF}_ins-*" will be treated as filename by mistake
			[ "${file}" == "ins-*" -o "${file}" == "${ZBOX_PLF}_ins-*" ] && echo "DEBUG: skip 'ins/${ZBOX_PLF}_ins' file, which not need to analyse" && continue	

			# extract info: tver/tadd
			local tveradd=${file#*ins-}
			local tver=${tveradd%-*}
			local tadd=$(echo "${tveradd}" | sed -e "s/[^-]*//;s/^-//")	# ${tveradd#${tver}-} NOT work, gets tver if there is no tadd

			# check if plf supported
			echo "DEBUG: start to analyse file: ${file}"
			zbox_ins_is_plf_support "${tname}" "${tver}" "${tadd}" || continue

			# insert head block for better reading
			output_line_count=$((output_line_count + 1)) && ((output_line_count % 15 == 0)) && zbox_lst_print_head

			# check if source downloaded
			local src_plfpath="$(zbox_gen_src_plfpath "${tname}" "${tver}" "${tadd}")"
			local src=$([ -e "${src_plfpath}" ] && echo ' Y' || echo ' N')

			# check if installed
			local ins_fullpath=$(zbox_gen_ins_fullpath "${tname}" "${tver}" "${tadd}")
			local ins=$([ -e "${ins_fullpath}" ] && echo ' Y' || echo ' N')

			# check stg in cnf
			local tmpname=""
			local stg_in_cnf=""
			for tmpname in $("ls" "${ZBOX_CNF}/${tname}/" 2> /dev/null | grep "stg-${tveradd}-[^-]*$") ; do
				local sname="${tmpname##*-}"
				local stg_in_cnf="${sname},${stg_in_cnf}"
				zbox_stg_is_plf_support "${tname}" "${tver}" "${tadd}" "${sname}" || continue
			done
			[ -z "${stg_in_cnf}" ] && [ -f "${ZBOX_CNF}/${tname}/stg" ] && stg_in_cnf="(default)"

			# check stg in stg
			local tmpname=""
			local stg_in_stg=""
			for tmpname in $("ls" "${ZBOX_STG}/${tname}/" 2> /dev/null | grep "${tname}-${tveradd}-[^-]*$") ; do
				local stg_in_stg="${tmpname##*-},${stg_in_stg}"
			done

			zbox_lst_print_item "${tname:-N/A}" "${tver:-N/A}" "${tadd:-N/A}" "${src:-N/A}" "${ins:-N/A}" "${stg_in_cnf:-N/A}" "${stg_in_stg:-N/A}"
		done 
		popd > /dev/null
	done

	popd > /dev/null
	zbox_lst_print_tail

	#if [ "${BASH_ASSOCIATIVE_ARRAY}" = "true" ] ; then
	#	[ -n "${target_tname_alias}" ] && local addition_echo_info="($* is aliased to ${target_tname})"	# cause 1st column too long
	#fi
	echo "${output_line_count} tool lines."
}

zbox_ins_is_plf_support() {
	local desc="Desc: check if current plf supported ins for selected tname + tver + <tadd>\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	zbox_is_plf_support "ins" "$@"
}

zbox_stg_is_plf_support() {
	local desc="Desc: check if current plf supported stg for selected tname + tver + <tadd> + sname\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	zbox_is_plf_support "stg" "$@"
}

zbox_is_plf_support() {
	local desc="Desc: check if current plf supported for selected tname + tver + <tadd> + <sname>\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 3 "$@"

	local check_for="${1}"
	shift
	local def_base="${ZBOX_CNF}/${1}/${check_for}"
	local def_base_tver="${def_base}-${2}"
	local def_base_tver_tadd="${def_base}-${2}-${3}"
	local def_base_tver_tadd_stg="${def_base}-${2}-${3}-${4}"
	local plf_base="${ZBOX_CNF}/${1}/${ZBOX_PLF}_${check_for}"
	echo "DEBUG: check platform for ${check_for} config, current: ${ZBOX_PLF}, check for: $*"

	# OPTION 1: support if have ins-.../stg-... file with plf prefix
	[ -f "${plf_base}-${2}" ] || [ -f "${plf_base}-${2}-${3}" ] || [ -f "${plf_base}-${2}-${3}-${4}" ]	\
	&& echo "DEBUG: ${check_for}-... with ${ZBOX_PLF} prefix config exist, platform supported"		\
	&& return 0

	# OPTION 2: for install, if <plf>_ins inexist && ins-... inexist, NOT support
	[ "${check_for}" = "ins" ]											\
	&& ! ( [ -f "${def_base_tver}" ] || [ -f "${def_base_tver_tadd}" ] || [ -f "${def_base_tver_tadd_stg}" ] )	\
	&& echo "DEBUG: ins-... with platorm prefix config INEXIST, and ins-... config INEXIST, platform NOT supported"	\
	&& return 1

	# OPTION 3: for stage, if stg inexist, NOT support
	[ "${check_for}" = "stg" ]							\
	&& ! [ -f "${def_base_tver}" ]							\
	&& echo "DEBUG: stg conf (${def_base_tver}) INEXIST, platform NOT supported"	\
	&& return 1

	# NOTE: ins_plf/stg_plf should be defined in specific tver/tadd/sname config file, NOT in overall stg/ins file (unless it is only for that platform, e.g. macvim)
	# OPTION 4: "assume" support if no ins_plf/stg_plf property defined
	! (grep -q "^[[:space:]]*${check_for}_plf[^#]*=[^#]*"								\
		"${def_base}" "${def_base_tver}" "${def_base_tver_tadd}" "${def_base_tver_tadd_stg}" 2>/dev/null)	\
	&& echo "DEBUG: '${check_for}_plf' NOT defined, zbox 'assume' platform supported"				\
	&& return 0

	# OPTION 5: cnf property defined, check it

	# (version 1) formal way to use cnf property, but too slow
	#if [ "${check_for}" = "ins" ] ; then
	#	eval $(zbox_gen_ins_cnf_vars "$@")
	#	ins_plf=${ins_plf:-"${ZBOX_INS_PLF_DEFAULT}"}
	#	echo "${ins_plf}" | grep -q "${ZBOX_PLF}" && echo "DEBUG: '${check_for}_plf' shows platform supported" && return 0
	#elif [ "${check_for}" = "stg" ] ; then
	#	eval $(zbox_gen_stg_cnf_vars "$@")
	#	stg_plf=${stg_plf:-"${ZBOX_STG_PLF_DEFAULT}"}
	#	echo "${stg_plf}" | grep -q "${ZBOX_PLF}" && echo "DEBUG: '${check_for}_plf' shows platform supported" && return 0
	#fi

	# (version 2) directly grep cnf file, much faster. Note: 1) "tail -1" makes property override still works! 2) "regex" makes commented lines or inline comment still not effect
	grep -o "^[[:space:]]*${check_for}_plf[^#]*=[^#]*"								\
		"${def_base}" "${def_base_tver}" "${def_base_tver_tadd}" "${def_base_tver_tadd_stg}" 2>/dev/null	\
	| tail -1													\
	| grep -q "${ZBOX_PLF}"												\
	&& echo "DEBUG: '${check_for}_plf' shows platform supported" 							\
	&& return 0

	echo "DEBUG: platform NOT supported"
	return 1
}

zbox_lst_print_head() {
	echo "|-----|----|----|---|---|----------|----------|"
	echo "|tname|tver|tadd|src|ins|stg in cnf|stg in stg|"
	echo "|-----|----|----|---|---|----------|----------|"
}

zbox_lst_print_tail() {
	echo "|-----|----|----|---|---|----------|----------|"
}

zbox_lst_print_item() {
	local desc="Desc: format the output of list\n${FUNCNAME[0]} <name> <version> <addtion> <ins> <stg_in_cnf> <stg_in_stg>"
	func_param_check 4 "$@"

	#printf "| %-16s | %-13s | %-9s | %-3s | %-3s | %-12s | %-12s |\n" "$@"
	printf "|%s|%s|%s|%s|%s|%s|%s|\n" "$@"
}

zbox_rem() {
	local desc="Desc: remove tool (uninstall but keep downloaded source)\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	echo "INFO: remove $* (uninstall but keep downloaded source)"
	eval $(zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"

	[ -e "${ins_fullpath}" ] && rm -rf ${ins_fullpath}{,_env}
	[ ! -e "${ins_fullpath}" ] && echo "INFO: remove ${ins_fullpath}{,_env} success" || func_die "ERROR: failed to remove ${ins_fullpath}{,_env}"
}

zbox_pur() {
	local desc="Desc: purge tool (uninstall and delete downloaded source)\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	echo "INFO: purge tool (uninstall and delete downloaded source) for $*"
	eval $(zbox_gen_ins_cnf_vars "$@")
	local src_plfpath=$(zbox_gen_src_plfpath "$@")
	local src_plfpath_real=$(readlink -f "${src_plfpath}")
	local src_realpath=$(zbox_gen_src_realpath "$@")
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"

	local f=""
	for f in "${src_plfpath}" "${src_plfpath_real}" "${src_realpath}" "${ins_fullpath}" "${ins_fullpath}_env" ; do
		echo "INFO: deleting file: ${f}"
		rm "${f}"
	done
}

zbox_ins() {
	local desc="Desc: install tool\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"
 
	[ ! -d "${ZBOX_CNF}/$1" ] && func_die "ERROR: tool $1 NOT exist" 

	eval $(zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"
	echo "INFO: (ins) start installation for $@, ins_steps: ${ins_steps}"

	# pre check and init
	zbox_ins_is_plf_support "$@" || func_die "ERROR: ins $* NOT supported in current platform" 
	zbox_ins_init_dir "$1"

	# execute pre script
	zbox_run_script "ins_pre_script" "${ZBOX_TMP}" "${ins_pre_script}" "${ins_pre_script_desc}"

	local step
	for step in ${ins_steps} ; do
		echo "INFO: (ins) start installation step: ${step}"
		case "${step}" in 
			src)		zbox_ins_src "$@"		;;
			ucd)		zbox_ins_ucd "$@"		;;
			move)		zbox_ins_move "$@"		;;
			copy)		zbox_ins_copy "$@"		;;
			copyucd)	zbox_ins_copyucd "$@"	;;
			dep)		zbox_ins_dep "$@"		;;
			make)		zbox_ins_make "$@"		;;
			default)	zbox_ins_default "$@"	;;
			*)		func_die "ERROR: (ins) can not handle installation process step:'${step}', exit!"	;;
		esac
	done

	# gen env, this step not need to define
	[ -n "${use_env}" -o ${#use_env_alias_array[@]} -ne 0 ] && zbox_use_gen_env "$@"

	# Record what have done for that build
	[ -e "${ins_fullpath}" ] && env > "${ins_fullpath}/zbox_ins_record.txt"

	# execute post script
	zbox_run_script "ins_post_script" "${ins_fullpath}" "${ins_post_script}"

	zbox_ins_verify "$@"

	# TODO: ask user if need to remove the installation?
}

zbox_stg_verify() { 
	local desc="Desc: verify stg\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 3 "$@"

	echo "INFO: (stg) start stage verification for: $*"

	# TODO: 
}

zbox_ins_verify() {
	local desc="Desc: verify installed tool\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	echo "INFO: (ins) start installation verification for: $*"
	eval $(zbox_gen_ins_cnf_vars "$@")

	[ -z "${ins_verify}" ] && func_die "WARN: NO ins_verify script found, skip verification"

	echo "INFO: (ins) verify installation with script ins_verify='${ins_verify}'"
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"
	[ -e "${ins_fullpath}_env" ] && source "${ins_fullpath}_env"
	eval "${ins_verify}"

	[ "$?" = "0" ] && echo "INFO: (ins) verify installation success" && return 0

	# verify is usually the last step, not terminate process (not use func_die) seems better
	echo "ERROR: (ins) verify installation failed!" 
	return 1
}

zbox_uig() {
	local desc="Desc: show which tool is in using"
	for v in "${!ZBOX_USING_@}" ; do
		echo ${!v}
	done
} 

zbox_use_silent() {
	zbox_use "$@" &> /dev/null
}

zbox_use() {
	local desc="Desc: use the tool, usually source the env variables\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")
	local env_fullpath="$(zbox_gen_env_fullpath "$@")"

	# Note: suppress echo here, since could use "zbox using" to check
	#echo "INFO: using ${env_fullpath}"
	#[ ! -e "${env_fullpath}" ] && echo "WARN: ${env_fullpath} not exist, seems no env need to source" && return 0

	# "-" no allowed in env var name
	eval "export ZBOX_USING_${1//-/_}='$*'"
	[ -e "${env_fullpath}" ] && source "${env_fullpath}" || echo "ERROR: failed to source ${env_fullpath}, pls check!"
}

zbox_stg() {
	local desc="Desc: make a working stage, this should be the single entrance for create stage\n${ZBOX_FUNC_STG_USAGE}"
	func_param_check 3 "$@"

	zbox_stg_is_plf_support "$@" || func_die "ERROR: stg $@ NOT supported in current platform" 

	eval $(zbox_gen_stg_cnf_vars "$@")
	local stg_fullpath="$(zbox_gen_stg_fullpath "$@")"
	if [ -n "${4}" ] ; then
		local ins_fullpath="$(zbox_gen_ins_fullpath "${1}" "${2}" "${3}")"
	else
		local ins_fullpath="$(zbox_gen_ins_fullpath "${1}" "${2}")"
	fi

	func_validate_path_exist "${ins_fullpath}"

	zbox_stg_init_dir "$@"

	# execute pre script and pre translate
	zbox_run_script "stg_pre_script" "${stg_fullpath}" "${stg_pre_script}"
	zbox_stg_pre_translate "$@"

	zbox_stg_gen_ctrl_scripts "$@"

	# execute post script
	zbox_run_script "stg_post_script" "${stg_fullpath}" "${stg_post_script}"
}

zbox_stg_pre_translate() {
	local desc="Desc: generate control scripts for stage\n${ZBOX_FUNC_STG_USAGE}"
	func_param_check 3 "$@"

	eval $(zbox_gen_stg_cnf_vars "$@")
	local zbox_username="$(whoami)"
	local stg_fullpath="$(zbox_gen_stg_fullpath "$@")"
	if [ -n "${4}" ] ; then
		local src_plfpath="$(zbox_gen_src_plfpath "${1}" "${2}" "${3}")"
		local ins_fullpath="$(zbox_gen_ins_fullpath "${1}" "${2}" "${3}")"
	else
		local src_plfpath="$(zbox_gen_src_plfpath "${1}" "${2}")"
		local ins_fullpath="$(zbox_gen_ins_fullpath "${1}" "${2}")"
	fi

	[ -z "${stg_pre_translate}" ] && echo "INFO: stg_pre_translate var empty, skip" && return 0

	local f=""
	for f in ${stg_pre_translate} ; do
		[ ! -f "${f}" ] && func_die "ERROR: pre translate failed, can NOT find file: ${f}"
		echo "INFO: translate files defined in var stg_pre_translate: ${f}"
		sed -i -e "s+ZBOX_TMP+${ZBOX_TMP}+g;
			   s+ZBOX_CNF+${ZBOX_CNF}+g;
			   s+ZBOX_USERNAME+${zbox_username}+g;
			   s+ZBOX_SRC_PLFPATH+${src_plfpath}+g;
			   s+ZBOX_INS_FULLPATH+${ins_fullpath}+g;
			   s+ZBOX_STG_FULLPATH+${stg_fullpath}+g;" "${f}"
	done
}

zbox_stg_gen_ctrl_scripts() {
	local desc="Desc: generate control scripts for stage\n${ZBOX_FUNC_STG_USAGE}"
	func_param_check 3 "$@"

	eval $(zbox_gen_stg_cnf_vars "$@")
	local stg_fullpath="$(zbox_gen_stg_fullpath "$@")"

	for cmd in ${stg_cmds:-start stop status} ; do
		local cmd_path="${stg_fullpath}/bin/${cmd}.sh"
		local cmd_var_name="stg_cmd_${cmd}"

		rm "${cmd_path}" &> /dev/null
		echo "INFO: (stage) Generating control scripts: ${cmd_path}"
		echo "${!cmd_var_name}" >> "${cmd_path}"
	done
}

zbox_ins_init_dir() {
	local desc="Desc: init directories for <tname>, currently only <tname> is necessary\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 1 "$@"

	echo  "INFO: (ins) init dir for ${1}"
	mkdir -p "${ZBOX_CNF}/${1}" "${ZBOX_SRC}/${1}" "${ZBOX_INS}/${1}" 
}

zbox_stg_init_dir() {
	local desc="Desc: generate a list of related configure files for stage\n${ZBOX_FUNC_STG_USAGE}"
	func_param_check 3 "$@"

	echo "INFO: (stage) init dir for $*"
	eval $(zbox_gen_stg_cnf_vars "$@")

	local stg_fullpath="$(zbox_gen_stg_fullpath "$@")"
	[ -e "${stg_fullpath}" ] && func_die "ERROR: stg dir already exist, pls check!"

	func_mkdir_cd "${stg_fullpath}"
	local p
	for p in ${stg_dirs:-bin conf logs data} ; do
		mkdir -p "${p}"
	done
	"cd" - >> "${ZBOX_LOG}" 2>&1
}

zbox_ins_src() {
	local desc="Desc: init source package or source code specified by 'ins_src_addr'\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")
	local src_plfpath="$(zbox_gen_src_plfpath "$@")"
	local src_realpath="$(zbox_gen_src_realpath "$@")"
	local src_fulldir="$(dirname "${src_plfpath}")"
	local ver="${2:-pkg}"

	case "${ver}" in
		svn|hg|git)	func_vcs_update "${ver}" "${ins_src_addr}" "${src_realpath}"	;;
		*)		[[ -e "${src_plfpath}" ]]					\
				&& echo "INFO: ${src_plfpath} already exist, skip"		\
				|| func_download "${ins_src_addr}" "${src_fulldir}"		;;
	esac

	# execute post script, NOTE: this will execute every time svn/git/hg updates
	zbox_run_script "ins_src_post_script" "${src_fulldir}" "${ins_src_post_script}"

	# create a "standard" naming symboic link, use ins_src_post_script if need customize
	if [ ! -e "${src_plfpath}" ] ; then
		func_cd "${src_fulldir}" 
		ln -s "$(basename ${src_realpath})" "$(basename ${src_plfpath})" >> ${ZBOX_LOG} 2>&1 
		\cd - >> ${ZBOX_LOG} 2>&1										
	fi
}

zbox_ins_default() {
	local desc="Desc: make it as the default one. In other word, create a link only have <tname> info\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"
	local ins_fullpath_default="$(zbox_gen_ins_fullpath_default "$@")"

	rm "${ins_fullpath_default}" >> ${ZBOX_LOG} 2>&1
	echo "INFO: (ins) make this installation as defaut, linking: ${ins_fullpath_default} -> ${ins_fullpath}"
	func_cd "$(dirname "${ins_fullpath}")" 
	ln -s "$(basename "${ins_fullpath}")" "${ins_fullpath_default}" 
	\cd - >> ${ZBOX_LOG} 2>&1
}

zbox_ins_dep() {
	local desc="Desc: install dependencies (using apt-get on linux, port on osx)\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")
	echo "INFO: (ins) start to install dependencies, ZBOX_PLF is '${ZBOX_PLF}'"

	# dep of linux platform
	if [ "${ZBOX_PLF}" = "${ZBOX_PLF_LINUX}" ] ; then
		if [ -n "${ins_dep_apt_install}" ] ; then
			echo "INFO: (ins) dependencies: sudo apt-get install -y ${ins_dep_apt_install}"
			sudo apt-get install -y ${ins_dep_apt_install} >> ${ZBOX_LOG} 2>&1
		fi

		if [ -n "${ins_dep_apt_build_dep}" ] ; then
			echo "INFO: (ins) dependencies: sudo apt-get build-dep ${ins_dep_apt_build_dep}"
			sudo apt-get build-dep -y ${ins_dep_apt_build_dep} >> ${ZBOX_LOG} 2>&1
		fi
	fi


	# dep of osx platform
	if [ -n "${ins_dep_port_install}" ] && [ "${ZBOX_PLF}" = "${ZBOX_PLF_OSX}" ] ; then
		echo "INFO: (ins) dependencies: sudo port install ${ins_dep_port_install}"
		sudo port install ${ins_dep_port_install} >> ${ZBOX_LOG} 2>&1
	fi

	# dep of zbox self
	# TODO: how to detect infinite loop?
	if [ -n "${ins_dep_zbox_ins}" ] ; then
		local dep_zbox
		for dep_zbox in "${ins_dep_zbox_ins[@]}" ; do
			[ -z "${dep_zbox}" ] && continue
			echo "INFO: (ins) dependencies: zbox_ins ${dep_zbox}"
			zbox_ins ${dep_zbox}
		done
	fi
}

zbox_ins_make() {
	local desc="Desc: install by configure > make > make install, the typical installation\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")

	# Pre-Conditions
	local make_steps="${ins_make_steps}"
	local make_opts="${ins_make_make_opts}"
	local install_opts="${ins_make_install_opts}"
	local configure_opts="${ins_make_configure_opts}"
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"
	local ucd_fullpath="$(zbox_gen_ucd_fullpath "$@")"
	func_validate_path_inexist "${ins_fullpath}"
	[ -z "${make_steps}" ] && func_die "ERROR: (ins) 'ins_make_steps' not defined, can not make"

	# execute pre script
	zbox_run_script "ins_make_pre_script" "${ucd_fullpath}" "${ins_make_pre_script}"

	# Make
	local make_cmd=${ins_make_cmd:-make} 
	local clean_cmd=${ins_make_clean_cmd:-clean} 
	local install_cmd=${ins_make_install_cmd:-install} 
	func_cd "${ucd_fullpath}"
	echo "INFO: (ins) start make, make_steps='${make_steps}', make_opts='${make_opts}', install_opts='${install_opts}', install_cmd='${install_cmd}', configure_opts='${configure_opts}', clean_cmd='${clean_cmd}'"
	for step in ${make_steps} ; do
		case "${step}" in 
			make)		"${make_cmd}" ${make_opts} >> "${ZBOX_LOG}" 2>&1
					zbox_check_exit_code "${step} success" "${step} failed" >> "${ZBOX_LOG}" 2>&1 
					;;
			test)		"${make_cmd}" test >> "${ZBOX_LOG}" 2>&1
					zbox_check_exit_code "${step} success" "${step} failed" >> "${ZBOX_LOG}" 2>&1 
					;;
			clean)		"${make_cmd}" ${clean_cmd} >> ${ZBOX_LOG} 2>&1
					zbox_check_exit_code "${step} success" "${step} failed" >> "${ZBOX_LOG}" 2>&1 
					;;
			install)	"${make_cmd}" ${install_opts} ${install_cmd} >> ${ZBOX_LOG} 2>&1
					zbox_check_exit_code "${step} success" "${step} failed" >> "${ZBOX_LOG}" 2>&1 
					;;
			autoconf)	autoconf ${autoconf_opts} >> ${ZBOX_LOG} 2>&1
					zbox_check_exit_code "${step} success" "${step} failed" >> ${ZBOX_LOG} 2>&1
					;;
			configure)	zbox_run_script "ins_configure_pre_script" "${ucd_fullpath}" "${ins_configure_pre_script}"
					./configure ${configure_opts} >> ${ZBOX_LOG} 2>&1
					zbox_check_exit_code "${step} success" "${step} failed" >> ${ZBOX_LOG} 2>&1
					zbox_run_script "ins_configure_post_script" "${ucd_fullpath}" "${ins_configure_post_script}"
					;;
			*)		func_die "ERROR: (ins) can not handle ${step}, exit!"				
					;;
		esac
	done

	# execute pre script
	zbox_run_script "ins_make_post_script" "${ucd_fullpath}" "${ins_make_post_script}"

	"cd" - >> "${ZBOX_LOG}" 2>&1
}

zbox_use_gen_env() {
	local desc="Desc: generate env file, some tools need export some env to use (like python)\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	# NEED support array, but not want to mess in "ins" file
	declare -A use_env_alias_array

	eval $(zbox_gen_ins_cnf_vars "$@")
	local env_fullpath="$(zbox_gen_env_fullpath "$@")"
	rm -f "${env_fullpath}"

	# TODO: update use_env to use_env_arary, so could stop using "|||ZBOX_SPACE|||, which used to support env value have space"
	if [ -n "${use_env}" ] ; then
		echo "INFO: (ins) gen env with 'use_env', target: ${env_fullpath}"
		for var in ${use_env} ; do
			[ -e "${var}" ] && echo "source ${var}" >> "${env_fullpath}" && continue	# use "source" if it is a file
			echo "export ${var//|||ZBOX_SPACE|||/ }" >> "${env_fullpath}"			# use "export" otherwise. Any better way to handle the "space" of |||ZBOX_SPACE|||?
		done
	fi

	if [ ${#use_env_alias_array[@]} -ne 0 ] ; then 
		echo "INFO: (ins) gen env with 'use_env_alias_array', target: ${env_fullpath}"
		for alias_name in "${!use_env_alias_array[@]}" ; do
			echo "alias ${alias_name}='${use_env_alias_array[$alias_name]}'" >> "${env_fullpath}"
		done
	fi

	# simply append the "use_cmd"
	if [ -n "${use_cmd}" ] ; then
		echo "${use_cmd}" >> "${env_fullpath}"
	fi
}

zbox_ins_copyucd() {
	local desc="Desc: install by copy stuff in ucd, usually for those need copy after 'make', which not need to use 'configure --prefix'\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")
	local ucd_fullpath="$(zbox_gen_ucd_fullpath "$@")"
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"

	echo "INFO: (ins) copy stuff in ucd, from: ${ucd_fullpath} to: ${ins_fullpath}"
	func_validate_path_inexist "${ins_fullpath}"
	func_validate_path_exist "${ucd_fullpath}"

	# only makedir when name is different
	#[ "${ins_fullpath##*/}" = "${ucd_fullpath##*/}" ] || func_mkdir "${ins_fullpath}" 
	func_mkdir "${ins_fullpath}" 
	cp -R "${ucd_fullpath}"/"${ins_copyucd_filter}" "${ins_fullpath}"
}

zbox_ins_copy() {
	local desc="Desc: install by copy, this means only need to copy the source package to 'ins' dir, usually for those git/svn/hg repo\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")
	local src_plfpath=$(zbox_gen_src_plfpath "$@")
	local src_plfpath_real=$(readlink -f ${src_plfpath})
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"

	echo "INFO: (ins) copy source, from: ${src_plfpath_real} to: ${ins_fullpath}"
	func_validate_path_inexist "${ins_fullpath}"
	func_validate_path_exist "${src_plfpath_real}"
	func_mkdir "${ins_fullpath}" 
	
	if [ "$(basename "${src_plfpath_real}")" == "$(basename "${ins_fullpath}")" ] ; then
		# copy content to avoid duplated same dir name in path
		"cp" -R "${src_plfpath_real}"/* "${ins_fullpath}"

		# NOT copy .* by default, reason: 1) usually unecessary. 2) seem will copy ../* (why?)
		#\cp -R "${src_plfpath_real}"/.* "${ins_fullpath}"
	else
		cp -R "${src_plfpath_real}" "${ins_fullpath}"
	fi
}

zbox_ins_move() {
	local desc="Desc: install by move, this means only need to move the uncompressed dir to 'ins' dir\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"
	local ucd_fullpath="$(zbox_gen_ucd_fullpath "$@")"

	echo "INFO: (ins) move source, from: ${ucd_fullpath} to: ${ins_fullpath}"
	func_validate_path_inexist "${ins_fullpath}"
	func_validate_path_exist "${ucd_fullpath}"
	mv "${ucd_fullpath}" "${ins_fullpath}"

	# execute post script
	zbox_run_script "ins_move_post_script" "${ins_fullpath}" "${ins_move_post_script}"
}

zbox_ins_ucd() {
	local desc="Desc: uncompress the source package\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	eval $(zbox_gen_ins_cnf_vars "$@")
	local src_plfpath="$(zbox_gen_src_plfpath "$@")"
	local ucd_fullpath="$(zbox_gen_ucd_fullpath "$@")"

	rm -rf "${ucd_fullpath}"
	func_uncompress "${src_plfpath}" "${ucd_fullpath}" 

	# execute post script
	zbox_run_script "ins_ucd_post_script" "${ucd_fullpath}" "${ins_ucd_post_script}"
}

zbox_gen_uname() {
	local desc="Desc: generate the unique tool name\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	[ -n "${3}" ] && echo "${1}-${2}-${3}" || echo "${1}-${2}"
}

zbox_gen_usname() {
	local desc="Desc: generate the unique stage name of the tool\n${ZBOX_FUNC_STG_USAGE}"
	func_param_check 3 "$@"

	local tmp_name="${1}-${2}-${3}"
	[ -n "${4}" ] && echo "${tmp_name}-${4}" || echo "${tmp_name}"
}

zbox_gen_env_fullpath() {
	local desc="Desc: generate full path of the tool's env file\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	echo "$(zbox_gen_ins_fullpath "$@")_env"
}

zbox_gen_ins_fullpath() {
	local desc="Desc: generate full path of the tool's installation\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	echo "${ZBOX_INS}/${1}/$(zbox_gen_uname "$@")"
}

zbox_gen_ins_fullpath_default() {
	local desc="Desc: generate full path of default executable, which is a symbloic link\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	echo "${ZBOX_INS}/${1}/${1}"
}

zbox_gen_src_plfpath() {
	local desc="Desc: generate platform dependent path of source package/code, which contains platform prefix (ZBOX_PLF) in filename\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"
	echo "${ZBOX_SRC}/${1}/${ZBOX_PLF}_$(zbox_gen_uname "$@")"
}

zbox_gen_src_realpath() {
	local desc="Desc: generate real path of source package/code, only conatins uname, tver, tadd info\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	case "${2}" in
		svn|hg|git)	
			# for source code in VS, just use "tver" and "tadd"
			echo "${ZBOX_SRC}/${1}/$(zbox_gen_uname "$1" "$2")"	
			;;	
		*)	
			# for package, use the real name in address
			eval $(zbox_gen_ins_cnf_vars "$@")
			echo "${ZBOX_SRC}/${1}/${ins_src_addr##*/}"
			;;
	esac
}

zbox_gen_ucd_fullpath() {
	local desc="Desc: generate full path of the uncompressed source packages\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"

	if echo "${2}" | grep -q '^\(svn\|hg\|git\)$' ; then
		# obviously, no ucd there, just use the source path
		zbox_gen_src_plfpath "$@"
	else
		echo "${ZBOX_TMP}/$(zbox_gen_uname "$@")"
	fi
}

zbox_gen_stg_fullpath() {
	local desc="Desc: generate full path of the stage\n${ZBOX_FUNC_STG_USAGE}"
	func_param_check 3 "$@"

	echo "${ZBOX_STG}/${1}/$(zbox_gen_usname "$@")"
}

zbox_gen_stg_cnf_files() {
	local desc="Desc: generate a list of related configure files for stage\n${ZBOX_FUNC_STG_USAGE}"
	func_param_check 3 "$@"
	
	local stg=${ZBOX_CNF}/${1}/stg
	local plf_stg=${ZBOX_CNF}/${1}/${ZBOX_PLF}_stg

	local stg_tver=${stg}-${2}
	local plf_stg_tver=${plf_stg}-${2}

	# check if "tadd" exist and use different files
	if [ -n "${4}" ] ; then
		local stg_tver_tadd=${stg}-${2}-${3}
		local plf_stg_tver_tadd=${plf_stg}-${2}-${3}
		local stg_tver_tadd_sname=${stg}-${2}-${3}-${4}
		local plf_stg_tver_tadd_sname=${plf_stg}-${2}-${3}-${4}
	else
		local stg_tver_tadd_sname=${stg}-${2}-${3}
		local plf_stg_tver_tadd_sname=${plf_stg}-${2}-${3}
	fi

	# Note the precedence
	echo "${stg} ${plf_stg} ${stg_tver} ${plf_stg_tver} ${stg_tver_tadd} ${plf_stg_tver_tadd} ${stg_tver_tadd_sname} ${plf_stg_tver_tadd_sname}"
}

zbox_gen_stg_cnf_vars() {
	local desc="Desc: generate a list of related configure variables for stage, with ZBOX varibles substituted\n${ZBOX_FUNC_STG_USAGE}"
	func_param_check 3 "$@"

	local stg_fullpath="$(zbox_gen_stg_fullpath "$@")"
	if [ -n "${4}" ] ; then
		local src_plfpath="$(zbox_gen_src_plfpath "${1}" "${2}" "${3}")"
		local ins_fullpath="$(zbox_gen_ins_fullpath "${1}" "${2}" "${3}")"
	else
		local src_plfpath="$(zbox_gen_src_plfpath "${1}" "${2}")"
		local ins_fullpath="$(zbox_gen_ins_fullpath "${1}" "${2}")"
	fi

	# TODO: deprecated this after update naming of stg (2015-10)
	#zbox_gen_stg_cnf_vars_raw "$@"		|\

	local cnfs=$(zbox_gen_stg_cnf_files "$@")
	cat ${cnfs} 2>> ${ZBOX_LOG}						|\
	sed -e 	"/^\s*#/d;
		/^\s*$/d;
		s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
		s/^/local /"							|\
	sed -e	"s+ZBOX_TMP+${ZBOX_TMP}+g;
		s+ZBOX_CNF+${ZBOX_CNF}+g;
		s+ZBOX_STG_TVER+${2}+g;
		s+ZBOX_PLF+${ZBOX_PLF}+g;
		s+ZBOX_SRC_PLFPATH+${src_plfpath}+g;
		s+ZBOX_INS_FULLPATH+${ins_fullpath}+g;
		s+ZBOX_STG_FULLPATH+${stg_fullpath}+g;"
}

zbox_gen_ins_cnf_files() {
	local desc="Desc: generate a list of related configure files for installation\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"
	
	local ins=${ZBOX_CNF}/${1}/ins 
	local plf_ins=${ZBOX_CNF}/${1}/${ZBOX_PLF}_ins

	local ins_tver=${ins}-${2}
	local plf_ins_tver=${plf_ins}-${2}

	[ -n "${3}" ] && local ins_tver_tadd=${ins}-${2}-${3}
	[ -n "${3}" ] && local plf_ins_tver_tadd=${plf_ins}-${2}-${3}

	# Note the precedence
	echo "${ins} ${plf_ins} ${ins_tver} ${plf_ins_tver} ${ins_tver_tadd} ${plf_ins_tver_tadd}"
}

zbox_gen_ins_cnf_vars() {
	local desc="Desc: 1) generate variable list for functions to source. 2) replace any zbox predefined variales. 3) all variables are prefixed with 'local'\n${ZBOX_FUNC_INS_USAGE}"
	func_param_check 2 "$@"
	
	# NOTE: cnf file should NOT use BOM (":set bomb?" in vim to check), otherwise might cause: "bash: local: `xxx=yyy': not a valid identifier"

	local cnfs=$(zbox_gen_ins_cnf_files "$@")
	local ins_fullpath="$(zbox_gen_ins_fullpath "$@")"
	local ucd_fullpath="$(zbox_gen_ucd_fullpath "$@")"
	local src_plfpath="$(zbox_gen_src_plfpath "$@")"
	local src_fulldir="$(dirname "${src_plfpath}")"

	# version 1: old, TODO: delete
	#cat ${cnfs} 2>> ${ZBOX_LOG} | sed -e "/^\s*#/d;/^\s*$/d;s/^/local /"

	# version 2: works
	#cat ${cnfs} 2>> ${ZBOX_LOG}						|\
	#sed -e 	"/^\s*#/d;
	#	/^\s*$/d;
	#	s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
	#	s/^/local /"							|\

	# version 3: more elegant to skip inexist files
	func_gen_local_vars ${cnfs} 2>> ${ZBOX_LOG}				|\
	sed -e	"s+ZBOX_TMP+${ZBOX_TMP}+g;
	        s+ZBOX_TVER+${2}+g;
	        s+ZBOX_CNF+${ZBOX_CNF}+g;
		s+ZBOX_PLF+${ZBOX_PLF}+g;
		s+ZBOX_SRC_FULLDIR+${src_fulldir}+g;
		s+ZBOX_SRC_PLFPATH+${src_plfpath}+g;
		s+ZBOX_UCD_FULLPATH+${ucd_fullpath}+g;
		s+ZBOX_INS_FULLPATH+${ins_fullpath}+g;" 
}

zbox_run_script() {
	local usage="Usage: ${FUNCNAME[0]} <script_name> <run_path> <script> <script_desc>"
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
	zbox_check_exit_code "${script_name} execution success" "${script_desc:-${script_name} execution failed}" 2>&1 
	"cd" - >> "${ZBOX_LOG}" 2>&1
}

zbox_check_exit_code() {
	# shellcheck disable=2015
	# NOTE: should NOT do anything before check, since need check exit status of last command
	[ "$?" = "0" ]  && echo  "INFO: ${1}" || func_die "ERROR: ${2:-${1}}"
}

