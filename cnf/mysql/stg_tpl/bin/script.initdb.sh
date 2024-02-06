#!/bin/bash

func_ver_increase() {
	local usage="Usage: ${FUNCNAME[0]} <v1> <v2>"
	local desc="Desc: check if v1 to v2 is increased, also return true if equals"

	# ref: https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
	printf '%s\n' "$1" "$2" | sort -C -V
}

zbox_mysql_init_v1() {
	ZBOX_INS_FULLPATH/scripts/mysql_install_db \
	--basedir=ZBOX_INS_FULLPATH                \
	--datadir=ZBOX_STG_FULLPATH/data           \
	--user=ZBOX_USERNAME                       \
	--lc-messages-dir=ZBOX_INS_FULLPATH/share/ \
	--lc-messages=en_US                        \
	--explicit_defaults_for_timestamp=TRUE

	# NOTE: file "my.cnf" gen by script.initdb.sh is in ZBOX_INS_FULLPATH/my.cnf, NOT in ZBOX_INS_FULLPATH/conf 
	mv ZBOX_INS_FULLPATH/my.cnf ZBOX_STG_FULLPATH/conf/my.cnf.genBy.script.initdb.sh
}

zbox_mysql_init_v2() {
	# TODO: use --initialize and use the generated password
	# NOTE: mysql doc said should only put necessary options for init. But seems the full my.cnf also works
	ZBOX_INS_FULLPATH/bin/mysqld                  \
	--defaults-file=ZBOX_STG_FULLPATH/conf/my.cnf \
	--initialize-insecure
}

# "mysql_install_db" is suggested for version before v5.7.6
if func_ver_increase ZBOX_TVER 5.7.6 ; then
	zbox_mysql_init_v1
else
	zbox_mysql_init_v2
fi
