#!/bin/bash

####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################

SYNAPSE_CONFIG_DIRECTORY=/opt/synapse/config
SYNAPSE_SERVICES_DIRECTORY=/opt/synapse/config/synapse_services
SYNAPSE_CONF_FILE=synapse.conf.json

#HOST_IP=`/sbin/ifconfig eth0 | grep "inet addr" | cut -d: -f2 | awk '{print $1}'`
HOST_IP=`ip -f inet add list dev eth0 | grep brd | cut -f1 -d"/" |awk '{print $2}'`
ZOOKEEPER_HOST=`host zookeeperCluster | cut -d " " -f4`
HOSTNAME=`uname -n`

echo "HOST_IP is: $HOST_IP"
echo "ZOOKEEPER_HOST is: $ZOOKEEPER_HOST"
echo "HOSTNAME is: $HOSTNAME"

if [ -d $SYNAPSE_SERVICES_DIRECTORY ]; then
	rm -rf $SYNAPSE_SERVICES_DIRECTORY
fi

mkdir -p $SYNAPSE_SERVICES_DIRECTORY

# Make the synapse conf file
cat > $SYNAPSE_CONFIG_DIRECTORY/$SYNAPSE_CONF_FILE << EOL
{
    "service_conf_dir": "$SYNAPSE_SERVICES_DIRECTORY",
    "haproxy": {
    "reload_command": "service haproxy reload",
    "config_file_path": "/etc/haproxy/haproxy.cfg",
    "socket_file_path": "/var/haproxy/stats.sock",
    "do_writes": true,
    "do_reloads": true,
    "do_socket": false,
    "bind_address": "*",
    "global": [
      "daemon",
      "user haproxy",
      "group haproxy",
      "maxconn 4096",
      "log     127.0.0.1 local0",
      "log     127.0.0.1 local1 notice"
    ],
    "defaults": [
      "log      global",
      "option   dontlognull",
      "maxconn  2000",
      "retries  3",
      "timeout  connect 5s",
      "timeout  client  1m",
      "timeout  server  1m",
      "option   redispatch",
      "balance  roundrobin"
    ],
    "extra_sections": {
      "listen stats :3212": [
        "mode http",
        "stats enable",
        "stats uri /",
        "stats refresh 5s"
      ]
    }
  }
}    

EOL

solution_name="$1"
echo "solution_name is: $solution_name"

#Create the conf files for the services
for var in "${@:2}"
do
  
  service_name=`echo $var | cut -d: -f1`
  service=`echo $var | cut -d: -f2`
  port=`echo $var | cut -d: -f3`
  ha_proxy_port=`echo $var | cut -d: -f4`
  
cat > "$SYNAPSE_SERVICES_DIRECTORY/${HOSTNAME}_${service}.json" << EOL
    {
      "default_servers": [
        {
          "name": "$service",
          "host": "localhost",
          "port": $port
        }
      ],
      "discovery": {
        "method": "zookeeper",
        "path": "/$solution_name/services/$service_name/$service",
        "hosts": [
          "$ZOOKEEPER_HOST:2181"
        ]
      },
      "haproxy": {
        "port": $ha_proxy_port,
        "server_options": "check inter 600s rise 2 fall 10",
        "listen": [
          "mode http",
          "option httpchk /health"
        ]
      }
    }
EOL
done

exit 0
