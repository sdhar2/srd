#!/bin/bash
####################################################################################
#Copyright 2015 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
LOGFILE=/var/log/nerve/nerve.log
NERVE_CONFIG_DIRECTORY=/opt/nerve/config
NERVE_SERVICES_DIRECTORY=/opt/nerve/config/nerve_services
NERVE_CONF_FILE=nerve.conf.json

#CONFIG="http://10.10.41.140:9087/code_controller/srdconfig/nerve/config/nerve.conf.json"
#SERVICES_URI="http://10.10.41.140:9087/code_controller/srdconfig/nerve/config/services/"
#SERVICES_CONFIG_FILES="acomms_0.json,acomms_1.json,acomms_2.json,acomms_3.json,acomms_4.json"
#SERVICES_CONFIG_FILES="serviceConfigFiles.json"
#HOSTNAME=`uname -n`

mkdir -p $(dirname ${LOGFILE}) && touch ${LOGFILE}

timestamp() {
  date --rfc-3339=seconds
}

mkdir -p $NERVE_SERVICES_DIRECTORY

if [ -z "${CONFIG}" ] && [ ! -f /opt/nerve/config/nerve.conf.json ]; then
   echo $(timestamp) - No Configuration defined. Creating Default >>${LOGFILE}

	# Make the nerve conf file
	cat > $NERVE_CONFIG_DIRECTORY/$NERVE_CONF_FILE << EOL
{
    "instance_id": "$HOST_IP",
    "service_conf_dir": "$NERVE_SERVICES_DIRECTORY"
}
EOL

else
   if [ -n "${CONFIG}" ]; then 
      curl -s -o /opt/nerve/config/nerve.conf.json ${CONFIG} 
      if [ $? -ne 0 ]; then
         echo $(timestamp) - Error retrieving config from ${CONFIG} >>${LOGFILE}
         exit 1
      fi
   fi
fi

# make sure that the glob does not return if empty
shopt -s nullglob
serviceFiles=$(echo /opt/nerve/config/nerve_services/*.json)
if [ -z "${SERVICES_CONFIG_FILES}" ] && [ -z "${serviceFiles}" ]; then
   echo $(timestamp) - No Services configured. Creating Template >>${LOGFILE}

   # Make a new service template if none exists and SERVICES is not defined
   cat > "$NERVE_SERVICES_DIRECTORY/${SERVICE}.json" << EOL
{
	"host": "$HOST_IP", 
        "port": $PORT, 
        "reporter_type": "zookeeper",
        "zk_hosts": ["zookeeperCluster:2181"], 
        "zk_path": "/acp/srd/$APPLICATION_NAME/$SERVICE", 
        "check_interval": 5,
        "checks": [
            {
              "type": "http",
              "uri": "$HC_URI", 
              "port": "$PORT", 
              "timeout": 1,
              "rise": 2,
              "fall": 10
        }
      ]
}
EOL

else
   if [ -n "${SERVICES_CONFIG_FILES}" ]; then
      (cd /opt/nerve/config/nerve_services/
         rm -f *
         curl -s -O ${SERVICES_URI}${SERVICES_CONFIG_FILES}
         configFilesList=`cat /opt/nerve/config/nerve_services/${SERVICES_CONFIG_FILES} | uniq`
         configFiles=`echo $configFilesList | tr '\n' ' '`

         for serviceFileConf in ${configFiles}; do
            curl -s -O ${SERVICES_URI}${serviceFileConf}
            if [ $? -ne 0 ]; then
               echo $(timestamp) - Error retrieving service config files from ${SERVICES_URI}  >>${LOGFILE}
               exit 1
            fi
         done
         rm /opt/nerve/config/nerve_services/${SERVICES_CONFIG_FILES}
      ) || exit 1
   fi
fi

echo $(timestamp) - Starting Nerve  >>${LOGFILE}
exec nerve --config /opt/nerve/config/nerve.conf.json &>>${LOGFILE}