#!/bin/bash

####################################################################################
#Copyright 2015 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
peer=`host etcdCluster | cut -d " " -f4`:4001
loadBalancerPrimary=`host loadBalancerPrimary | cut -d " " -f4`
loadBalancerSecondary=`host loadBalancerSecondary | cut -d " " -f4`
status_port="9500"
#hostIP=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
hostIP=`ip -f inet add list dev eth0 | grep brd |cut -f1 -d"/"| awk '{print $2}'`

# This script file can be used by any application which use lbaas service
# Application invokes this script file before application is running
# If fail to validate the port and application, application fail to start and the porper error message in log file
# Otherwise the port and application key/value pair will be added to /config/lbaas
# Application will start with the port properly, it will invoke etcdKeepAlive.bash later with the configured port and application

# validate port and application name again /config/lbaas,
# if the port is used by another application, exit with error log, 
# if the port is in used and the matched application pair is also in /config/lbaas, no nothing
# if the port is not in used, but the application name uses another port, exit with error log
# if the port and the application name key/pair does not exist, add it to /config/lbaas

prefix=`date +"%G-%m-%d %H:%M:%S addApplicationWithPort INFO "`

[ $# -lt 2 ] && {
    echo $prefix "Usage: $0 <application> <port>";
	echo $prefix "<application> svcmgr and appserver";
	echo $prefix "<port> 8080 for svcmgr, 8085 for appserver";

    exit 0; }

application=$1 
port=$2 
HARequired=$3 

key=/config/lbaas/${application}:${port}
value=${port}

foundApplication=`etcdctl --no-sync -peers ${peer} ls --recursive /config/lbaas | grep ${application}`
failure=$?
if [ $failure -gt 0 ]
then
    foundPort=`etcdctl --no-sync -peers ${peer} ls --recursive /config/lbaas | grep $port`
    failure=$?
    if [ $failure -gt 0 ]
    then
        # check if both nginx are up
        wgetcount1=`wget -v -t1 -T5 -O /dev/null "http://${loadBalancerPrimary}:${status_port}" 2>&1 | grep "200 OK" | wc -l` 
        wgetcount2=`wget -v -t1 -T5 -O /dev/null "http://${loadBalancerSecondary}:${status_port}" 2>&1 | grep "200 OK" | wc -l` 
	if [ $HARequired == "true" ]
	then
        	if [ $wgetcount1 -eq "1" -a $wgetcount2 -eq "1" ]
		then
			exit 0
		else
        		echo $prefix "LoadBalancer is not running HA mode, can not route the port $port for the application $application"
        		exit 3
		fi
	else
        	if [ $wgetcount1 -eq "1" -o $wgetcount2 -eq "1" ]
		then
			exit 0
		else
        		echo $prefix "LoadBalancer is not running at all, can not route the port $port for the application $application"
			exit 3
		fi
	fi
    else
        echo $prefix "The port $port is in use by other application, can not use $port for $application"
        exit 1
    fi
else
    echo $prefix "The application ${application} is found"
    foundApplicationAndPort=`etcdctl --no-sync -peers  ${peer} get ${key} | grep $port`
    failure=$?
    if [ $failure -gt 0 ]
        then
        echo $prefix "found the application ${application}, but with different port already"
        exit 2
    else
        echo $prefix "found the application ${application} and its paired port ${port} in /config/lbaas"
    fi
fi
