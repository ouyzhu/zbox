

# source ${HOME}/.myenv/myenv_lib.sh || eval "$(wget -q -O - "https://raw.github.com/stico/myenv/master/.myenv/myenv_lib.sh")" || exit 1

func_date() { date "+%Y-%m-%d";			}
func_time() { date "+%H-%M-%S";			}
func_dati() { date "+%Y-%m-%d_%H-%M-%S";		}
func_nanosec()  { date +%s%N;				}
func_millisec() { echo $(($(date +%s%N)/1000000));	}

func_check_exit_code() {
	# NOTE: should NOT do anything before check, since need check exit status of last command
	[ "$?" = "0" ]  && echo  "INFO: ${1}" || func_die "ERROR: ${2:-${1}}"
}

func_param_check_die() {
	local usage="Usage: $FUNCNAME <count> <error_msg> <string> ..."
	local desc="Desc: (YOU SCRIPT HAS BUG) string counts should 'greater than' or 'equal to' expected count, otherwise print the <error_msg> and exit. Good for parameter amount check." 
	[ $# -lt 2 ] && func_die "${desc} \n ${usage} \n"	# use -lt, so the exit status will not changed in legal condition
	
	local count=$1
	local error_msg=$2
	shift;shift;
	[ $# -lt ${count} ] && func_die "${error_msg}"
}

func_param_check() {
	local usage="Usage: $FUNCNAME <count> <error_msg> <string> ..."
	local desc="Desc: (YOU SCRIPT HAS BUG) string counts should 'greater than' or 'equal to' expected count, otherwise print the <error_msg> and exit. Good for parameter amount check." 
	[ $# -lt 2 ] && func_die "${desc} \n ${usage} \n"	# use -lt, so the exit status will not changed in legal condition
	
	local count=$1
	local error_msg=$2
	shift;shift;
	[ $# -lt ${count} ] && func_cry "${error_msg}"
}

func_cd() {
	local usage="Usage: $FUNCNAME <path>" 
	local desc="Desc: (fail fast) change dir, exit whole process if fail"
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	[ -n "${1}" ] && \cd "${1}" || func_die "ERROR: failed to change dir: cd ${1}"
}

func_mkdir() {
	local usage="Usage: $FUNCNAME <path> ..." 
	local desc="Desc: (fail fast) create dirs if NOT exist, exit whole process if fail"
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		[ -e "${p}" ] && continue
		mkdir -p "${p}" || func_die "ERROR: failed to create dir ${p}"
	done
}

func_mkdir_cd() { 
	local usage="Usage: $FUNCNAME <path>" 
	local desc="Desc: (fail fast) create dir and cd into it. Create dirs if NOT exist, exit if fail, which is different with /bin/mkdir" 
	func_param_check 1 "Usage: $FUNCNAME <path>" "$@"

	func_mkdir "$1" 
	\cd "${1}" || func_die "ERROR: failed to mkdir or cd into it ($1)"

	# to avoid the path have blank, any simpler solution?
	#func_mkdir "$1" && OLDPWD="$PWD" && eval \\cd "\"$1\"" || func_die "ERROR: failed to mkdir or cd into it ($1)"
}

func_download() {
	local usage="Usage: $FUNCNAME <url> <target>"
	local desc="Desc: download from url to local target" 
	func_param_check 2 "${desc} \n ${usage} \n" "$@"
	
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
	local usage="Usage: $FUNCNAME <url> <target_dir>"
	local desc="Desc: download using wget" 
	func_param_check 2 "${desc} \n ${usage} \n" "$@"

	# if the target exist is an file, just return
	local dl_fullpath="${2}/${1##*/}"
	[ -f "${dl_fullpath}" ] && echo "INFO: file (${dl_fullpath}) already exist, skip download" && return 0

	func_mkdir_cd "${2}" 
	echo "INFO: start download, url=${1} target=${dl_fullpath}"

	# TODO: add control to unsecure options?

	wget --progress=dot --no-check-certificate ${1}	2>&1 | grep --line-buffered "%" | sed -u -e "s,\.,,g" 

	# Note, some awk version NOT works friendly
	# Command line explain: [Showing File Download Progress Using Wget](http://fitnr.com/showing-file-download-progress-using-wget.html)
	#wget --progress=dot --no-check-certificate ${1}	2>&1 | grep --line-buffered "%" | sed -u -e "s,\.,,g" | awk 'BEGIN{printf("INFO: Download progress:  0%")}{printf("\b\b\b\b%4s", $2)}'

	echo "" # next line should in new line
	[ -f "${dl_fullpath}" ] || func_die "ERROR: ${dl_fullpath} not found, seems download faild!"
	\cd - &> /dev/null
}

func_uncompress() {
	# TODO 1: gz file might be replaced and NOT in the target dir

	local usage="Usage: $FUNCNAME <source> [target_dir]"
	local desc="Desc: uncompress file, based on filename extension, <target_dir> will be the top level dir for uncompressed content" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	func_validate_path_exist "${1}"

	# use readlink to avoid relative path
	local source_file="$(readlink -f "${1}")"
	local target_dir="${source_file%.*}"
	[ -n "${2}" ] && target_dir="$(readlink -f "${2}")"
	[ -d "${target_dir}" ] && func_cry "ERROR: ${target_dir} already exist, give up!"

	echo "INFO: uncompress file, from: ${source_file} to: ${target_dir}"
	func_mkdir_cd "${target_dir}"
	case "$source_file" in
		# group for 
		*.tar.gz)	tar -zxvf "$source_file" &> /dev/null	;;	# NOTE, should before "*.gz)"
		*.tar.bz2)	tar -jxvf "$source_file" &> /dev/null	;;	# NOTE, should before "*.bz2)"
		*.bz2)		bunzip2 "$source_file" &> /dev/null	;;
		*.gz)		gunzip "$source_file" &> /dev/null	;;
		*.7z)		7z e "$source_file" &> /dev/null	;;	# use "-e" will fail, "e" is extract, "x" is extract with full path
		*.zip)		func_complain_cmd_not_exist unzip \
				&& sudo apt-get install unzip ;			# try intall
				unzip "$source_file" &> /dev/null	;;
		*.tar)		tar -xvf "$source_file" &> /dev/null	;;
		*.xz)		tar -Jxvf "$source_file" &> /dev/null	;;
		*.tgz)		tar -zxvf "$source_file" &> /dev/null	;;
		*.tbz2)		tar -jxvf "$source_file" &> /dev/null	;;
		*.Z)		uncompress "$source_file"		;;
		*.rar)		func_complain_cmd_not_exist unrar \
				&& sudo apt-get install unrar ;			# try intall
				unrar e "$source_file" &> /dev/null	;;	# candidate 1
		#*.rar)		7z e "$source_file" &> /dev/null	;;	# candidate 2
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

func_vcs_update() {
	local usage="Usage: $FUNCNAME <src_type> <src_addr> <target_dir>"
	local desc="Desc: init or update vcs like hg/git/svn"
	func_param_check 3 "${desc} \n ${usage} \n" "$@"

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
		\cd "${target_dir}" &> /dev/null
		${cmd_update} || func_die "ERROR: ${cmd_update} failed"
		\cd - &> /dev/null
	else
		mkdir -p "$(dirname ${target_dir})"
		${cmd_init} "${src_addr}" "${target_dir}" || func_die "ERROR: ${cmd_init} failed"
	fi
}

################################################################################
# Utility: validation and check
# TODO: rename: validate to assert
################################################################################
func_complain_privilege_not_sudoer() { 
	local usage="Usage: $FUNCNAME <msg>"
	local desc="Desc: complains if current user not have sudo privilege, return 0 if not have, otherwise 1" 
	
	( ! sudo -n ls &> /dev/null) && echo "${2:-WARN: current user NOT have sudo privilege!}" && result=0
	return 1
}

func_complain_path_not_exist() {
	local usage="Usage: $FUNCNAME <path> <msg>"
	local desc="Desc: complains if path not exist, return 0 if not exist, otherwise 1" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	[ ! -e "${1}" ] && echo "${2:-WARN: path ${1} NOT exist!}" && return 0
	return 1
}

func_validate_path_exist() {
	local usage="Usage: $FUNCNAME <path> ..."
	local desc="Desc: the path must be exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		[ ! -e "${p}" ] && func_stop "ERROR: ${p} NOT exist!"
	done
}

func_validate_path_not_exist() { func_validate_path_inexist "$@" ;}
func_validate_path_inexist() {
	local usage="Usage: $FUNCNAME <path> ..."
	local desc="Desc: the path must be NOT exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		[ -e "${p}" ] && func_stop "ERROR: ${p} already exist!"
	done
}

func_validate_path_owner() {
	local usage="Usage: $FUNCNAME <path> <owner>"
	local desc="Desc: the path must be owned by owner(xxx:xxx format), otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"

	local expect="${2}"
	local real=$(ls -ld "${1}" | awk '{print $3":"$4}')
	[ "${real}" != "${expect}" ] && func_stop "ERROR: owner NOT match, expect: ${expect}, real: ${real}"
}

func_is_positive_int() {
	local usage="Usage: $FUNCNAME <param>"
	local desc="Desc: return 0 if the param is positive integer, otherwise will 1" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	# NOTE: no quote on the pattern part!
	local num="${1}"
	[[ "${num}" =~ ^[\-]*[0-9]+$ ]] && (( num > 0 )) && return 0 || return 1
}

func_is_cmd_exist() {
	local usage="Usage: $FUNCNAME <cmd>"
	local desc="Desc: check if cmd exist, return 0 if exist, otherwise 1" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"

	command -v "${1}" &> /dev/null && return 0 || return 1
}

func_complain_cmd_not_exist() {
	local usage="Usage: $FUNCNAME <cmd> <msg>"
	local desc="Desc: complains if command not exist, return 0 if not exist, otherwise 1" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"

	func_is_cmd_exist "${1}" && return 1
	echo "${2:-WARN: cmd ${1} NOT exist!}" 
	return 0
}

func_validate_cmd_exist() {
	local usage="Usage: $FUNCNAME <cmd> ..."
	local desc="Desc: the cmd must be exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"

	for p in "$@" ; do
		func_is_cmd_exist "${p}" || func_stop "ERROR: cmd (${p}) NOT exist!"
	done
}

func_validate_dir_not_empty() {
	local usage="Usage: $FUNCNAME <dir> ..."
	local desc="Desc: the directory must exist and NOT empty, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		[ ! "$(ls -A "${p}" 2> /dev/null)" ] && func_stop "ERROR: ${p} is empty!"
	done
}

func_validate_dir_empty() {
	local usage="Usage: $FUNCNAME <dir> ..."
	local desc="Desc: the directory must be empty or NOT exist, otherwise will exit" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	for p in "$@" ; do
		# only redirect stderr, otherwise the test will always false
		[ "$(ls -A "${p}" 2> /dev/null)" ] && func_stop "ERROR: ${p} not empty!"
	done
}

################################################################################
# Utility: FileSystem
################################################################################

func_link_init() {
	local usage="Usage: ${FUNCNAME} <target> <source>"
	local desc="Desc: the directory must be empty or NOT exist, otherwise will exit" 
	func_param_check 2 "${desc} \n ${usage} \n" "$@"

	local target="$1"
	local source="$2"
	echo "INFO: creating link ${target} --> ${source}"

	# check, skip if target already link, remove if target empty 
	func_complain_path_not_exist ${source} && return 0
	[ -h "${target}" ] && echo "INFO: ${target} already a link (--> $(readlink -f ${target}) ), skip" && return 0
	[ -d "${target}" ] && [ ! "$(ls -A ${target})" ] && rmdir "${target}"

	\ln -s "${source}" "${target}"
}

func_duplicate_dated() {
	local usage="Usage: $FUNCNAME <file> ..."
	local desc="Desc: backup file, with suffixed date" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
	local dati="$(func_dati)"
	for p in "$@" ; do
		func_complain_path_not_exist "${p}" && continue

		# if target is dir, check size first (>100M will warn and skip)
		if [ -d "${p}" ] ; then
			p_size=$(stat -c%s "${p}")
			p_size_h=$(func_num_to_human zip_size)
			(( p_size > 104857600 )) && echo "WARN: ${p} size (${p_size_h}) too big (>100M), skip" && continue 
		fi

		target="${p}.bak.${dati}"
		echo "INFO: backup file, ${p} --> ${target}"
		[ -w "${p}" ] && cp -r "${p}" "${target}" || sudo cp -r "${p}" "${target}"
		[ "$?" != "0" ] && echo "WARN: backup ${p} failed, pls check!"
	done
}

################################################################################
# Utility: shell
################################################################################

func_is_non_interactive() {
	# command 1: echo $- | grep -q "i" && echo interactive || echo non-interactive
	# command 2: [ -z "$PS1" ] && echo interactive || echo non-interactive
	# explain: bash manual: PS1 is set and $- includes i if bash is interactive, allowing a shell script or a startup file to test this state.
	[ -z "$PS1" ] && return 0 || return 1
}

func_pipe_filter() {
	if [ -z "${1}" ] ; then
		sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"
	else
		tee -a "${1}" | sed -n -e "/^\(Desc\|INFO\|WARN\|ERROR\):/p"
	fi
}

func_gen_local_vars() {
	local usage="Usage: $FUNCNAME <file1> <file2> ..." 
	local desc="Desc: gen local var definition based on file sequence" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1

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
	(( ${#exist_files[*]} == 0 )) && echo "WARN: NO files really readable to gen local var: $@" 1>&2 && return 1

	# TODO: embrace value with " or ', since bash eval get error if value have special chars like &/, etc. path field almost always have such chars.
	# works but not efficient: s/^\([^=[:blank:]]*\)[[:blank:]]*=[[:blank:]]*/\1=/;
	cat "${exist_files[@]}"			\
	| sed -e "/^[[:blank:]]*\($\|#\)/d;
		s/[[:blank:]]*=[[:blank:]]*/=/;
		s/^/local /"
}

################################################################################
# Utility: process
################################################################################

func_stop() {
	local usage="Usage: $FUNCNAME <error_info>" 
	local desc="Desc: echo error info to stderr and exit" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1
	
	echo -e "$@" 1>&2
	func_is_non_interactive && exit 1 || kill -INT $$
}

func_die() {
	# old, use func_stop() instead
	# TODO: redirect to func_stop after verified

	local usage="Usage: $FUNCNAME <error_info>" 
	local desc="Desc: echo error info to stderr and exit" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1
	
	echo -e "$@" 1>&2
	exit 1
}

func_cry() {
	# old, use func_stop() instead
	# TODO: redirect to func_stop after verified

	local usage="Usage: $FUNCNAME <error_info>" 
	local desc="Desc: echo error info to stderr and kill current job (exit the function stack without exiting shell)" 
	[ $# -lt 1 ] && echo -e "${desc} \n ${usage} \n" && exit 1
	
	echo -e "$@" 1>&2
	kill -INT $$
}

################################################################################
# Data Type: number
################################################################################

func_num_to_human() {
	local usage="Usage: $FUNCNAME <number>"
	local desc="Desc: convert to number to human readable form, like: 4096 to 4K" 
	func_param_check 1 "${desc} \n ${usage} \n" "$@"
	
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
