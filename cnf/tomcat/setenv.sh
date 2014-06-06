#!/bin/bash
[ -z "${JAVA_HOME}" ] && echo "ERROR: env JAVA_HOME not set!" && exit 1
[ -z "${CATALINA_HOME}" ] && echo "ERROR: env CATALINA_HOME not set!" && exit 1
[ -z "${CATALINA_BASE}" ] && echo "ERROR: env CATALINA_BASE not set!" && exit 1

### Default values in catalina.sh
#$CATALINA_BASE/webapps is the default app dir
#CATALINA_OUT=$CATALINA_BASE/logs/catalina.out
#CATALINA_TMPDIR=$CATALINA_BASE/temp
#CATALINA_OPTS=""

### Use env, otherwise need set
#JAVA_HOME=/usr/local/java
#JRE_HOME=$JAVA_HOME/jre
#TOMCAT_USER=www-data

### User settings
CATALINA_PID=$CATALINA_BASE/pidfile
# for test
JAVA_OPTS="-Xms128m -Xmx2048m"
# for production
#JAVA_OPTS="-Xms1024m -Xmx3500m -Xmn512m -XX:PermSize=192m -Xss256k -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSCompactAtFullCollection -XX:LargePageSizeInBytes=128m -XX:+UseFastAccessorMethods -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=70 -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -Duser.timezone=Asia/Shanghai -Dfile.encoding=UTF-8"

### Misc options
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CATALINA_HOME/lib
export LD_LIBRARY_PATH
JSVC_OPTS='-jvm server'
