#!/bin/bash

# source ${HOME}/.myenv/myenv_lib.sh || eval "$(wget -q -O - "https://raw.github.com/stico/myenv/master/.myenv/myenv_lib.sh")" || exit 1

function func_date() {	date "+%Y-%m-%d";		}
function func_time() {	date "+%H-%M-%S";		}
function func_dati() {	date "+%Y-%m-%d_%H-%M-%S";	}

function func_die() {
	[ $# -lt 1 ] && echo -e "Usage: $FUNCNAME [error_info] \n Desc: echo error info to stderr and exit \n" && exit 1
	
	echo -e "$@" 1>&2
	exit 1
	#[ "$0" = "/bin/bash" ] && return 1 || exit 1		# Return if invoked from command line, exit if from script. BUT messy up invoke chain 
}
