#!/bin/bash

FILE_LOG="ZBOX_STG_FULLPATH/logs/default.log" 
CMD_STOP=""
CMD_START="ZBOX_STG_FULLPATH/bin/mysqld --defaults-file=ZBOX_STG_FULLPATH/conf/my.cnf"

# mysqld will record pid, so not need do it in script
CONF_START_RECORD_PID=false

# FILE_PID is used in mysql conf: tpl_ins/cnf.basic
FILE_PID="ZBOX_STG_FULLPATH/pidfile" 


