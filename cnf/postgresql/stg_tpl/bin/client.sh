#!/bin/bash

if [ $# -eq 0 ] ; then
	# to avoid error 'database "xxx" does not exist'
	ZBOX_INS_FULLPATH/bin/psql "template1"
else
	ZBOX_INS_FULLPATH/bin/psql "$@"
fi
