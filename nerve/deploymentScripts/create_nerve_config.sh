#!/bin/bash

####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################

NERVE_CONFIG_DIRECTORY=/opt/nerve/config
NERVE_SERVICES_DIRECTORY=/opt/nerve/config/nerve_services
NERVE_CONF_FILE=nerve.conf.json

#HOST_IP=`/sbin/ifconfig eth0 | grep "inet addr" | cut -d: -f2 | awk '{print $1}'`
HOST_IP=`ip -f inet add list dev eth0 | grep brd | cut -f1 -d"/" |awk '{print $2}'`
ZOOKEEPER_HOST=`host zookeeperCluster | cut -d " " -f4`
HOSTNAME=`uname -n`

echo "HOST_IP is: $HOST_IP"
echo "ZOOKEEPER_HOST is: $ZOOKEEPER_HOST"
echo "HOSTNAME is: $HOSTNAME"

if [ -d $NERVE_SERVICES_DIRECTORY ]; then
	rm -rf $NERVE_SERVICES_DIRECTORY
fi

mkdir -p $NERVE_SERVICES_DIRECTORY

# Make the nerve conf file
cat > $NERVE_CONFIG_DIRECTORY/$NERVE_CONF_FILE << EOL
{
    "instance_id": "$HOSTNAME",
    "service_conf_dir": "$NERVE_SERVICES_DIRECTORY"
}
EOL

solution_name="$1"
service_name="$2"
echo "solution_name is: $solution_name"
echo "service_name is: $service_name"

#Create the conf files for the services
for var in "${@:3}"
do

echo $var
service=`echo $var | cut -d: -f1`
port=`echo $var | cut -d: -f2`
uri=`echo $var | cut -d: -f3`
hc_port=`echo $var | cut -d: -f4`
echo "service is: $service"
echo "port is: $port"
echo "uri is: $uri"

if [ -z $hc_port ]; then
  hc_port=$port
fi 
echo "Health Check port is: $hc_port"

cat > "$NERVE_SERVICES_DIRECTORY/${HOSTNAME}_${service}.json" << EOL
{
	"host": "$HOST_IP", 
        "port": $port, 
        "reporter_type": "zookeeper",
        "zk_hosts": ["$ZOOKEEPER_HOST:2181"], 
        "zk_path": "/$solution_name/services/$service_name/$service", 
        "check_interval": 5,
        "checks": [
            {
              "type": "http",
              "uri": "$uri", 
              "port": "$hc_port", 
              "timeout": 1,
              "rise": 2,
              "fall": 10
        }
      ]
 }

EOL

done

exit 0
