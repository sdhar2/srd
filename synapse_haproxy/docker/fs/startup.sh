#!/bin/bash
####################################################################################
#Copyright 2015 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
LOGFILE=/var/log/synapse/synapse.log
SYNAPSE_CONFIG_DIRECTORY=/opt/synapse/config
SYNAPSE_SERVICES_DIRECTORY=/opt/synapse/config/synapse_services
SYNAPSE_CONF_FILE=synapse.conf.json

mkdir -p $(dirname ${LOGFILE}) && touch ${LOGFILE}

timestamp() {
  date --rfc-3339=seconds
}

mkdir -p $SYNAPSE_SERVICES_DIRECTORY

if [ -z "${CONFIG}" ] && [ ! -f /opt/synapse/config/synapse.conf.json ]; then
   echo $(timestamp) - No Configuration defined. Creating Default >>${LOGFILE}
   
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
   
else
   if [ -n "${CONFIG}" ]; then 
      curl -s -o /opt/synapse/config/synapse.conf.json ${CONFIG} 
      if [ $? -ne 0 ]; then
         echo $(timestamp) - Error retrieving config from ${CONFIG}. >>${LOGFILE}
         exit 1
      fi
   fi
fi

# make sure that the glob does not return if empty
shopt -s nullglob
serviceFiles=$(echo /opt/synapse/config/synapse_services/*.json)
if [ -z "${SERVICES_CONFIG_FILES}" ] && [ -z "${serviceFiles}" ]; then
   echo $(timestamp) - No Services configured. Creating Template >>${LOGFILE}
   
   # Make a new service template if none exists and SERVICES is not defined
   cat > "$SYNAPSE_SERVICES_DIRECTORY/${SERVICE}.json" << EOL
    {
      "default_servers": [
        {
          "name": "$SERVICE",
          "host": "localhost",
          "port": $PORT
        }
      ],
      "discovery": {
        "method": "zookeeper",
        "path": "/acp/srd/$APPLICATION_NAME/$SERVICE",
        "hosts": [
          "zookeeperCluster:2181"
        ]
      },
      "haproxy": {
        "port": $PORT,
        "server_options": "check inter 600s rise 2 fall 10",
        "listen": [
          "mode http",
          "option httpchk /health"
        ]
      }
    }
EOL
   
else
   if [ -n "${SERVICES_CONFIG_FILES}" ]; then
      (cd /opt/synapse/config/synapse_services/
         rm -f *
         for serviceFileConf in ${SERVICES_CONFIG_FILES//,/ }; do
            curl -s -O ${SERVICES_URI}${serviceFileConf}
            if [ $? -ne 0 ]; then
               echo $(timestamp) - Error retrieving service config files from ${SERVICES_URI}  >>${LOGFILE}
               exit 1
            fi
         done
      ) || exit 1
   fi
fi

echo $(timestamp) - Starting Synapse  >>${LOGFILE}
exec synapse --config /opt/synapse/config/synapse.conf.json &>>${LOGFILE}