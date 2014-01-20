#!/bin/bash
[ -e /home/ouyangzhu//.zbox/stg/mysql/mysql-common/pidfile ] && echo 'Running' && ps -ef | grep $(cat /home/ouyangzhu//.zbox/stg/mysql/mysql-common/pidfile) | grep -v grep || echo 'Not running.'
