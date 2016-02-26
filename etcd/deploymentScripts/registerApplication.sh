# Copyright ARRIS INC  March - 2015
# This needs to be installed on the node where the key/value data is to be persisted from.
# Never run inside a docker container.
# i.e. if you are trying to maintain pgpool data, it needs to be on the pgpool node and launched from the same script that 
# launches the pgpool executable.
# usage:  ./registerApplication.sh
# i.e. nohup ./registerApplication.sh 2>&1 >/var/log/registerApplication.log &

prefix=`date +"%G-%m-%d %H:%M:%S registerApplication INFO "`

peer=`host etcdCluster | cut -d " " -f4`:4001

confDir="/opt/config"
file=""
etcdJsonFile="/opt/etcd/config/etcd.json"
addApplicationLog=/tmp/addApplicationStatus.log
firstTime="true"
firstStatic="true"
firstKeepAlive="true"
updatedFile="false"
NERVE_CONFIG_SCRIPT_FILE="create_nerve_config.sh"
SYNAPSE_CONFIG_SCRIPT_FILE="create_synapse_haproxy_config.sh"

#find the config file and validate it is in proper format
findConfig() {
	#find file in /opt/config/?.json
	file=`ls -1 ${confDir}/applicationConf.json | head -1`
	if [ -e ${file} ]
	then

		fileTest=`jq -c '.[]  ' ${file} -e 2>&1 `  
		result=$?  

	        if [ ${result} -gt 0 ]  
		then  
			echo "${prefix} Configuration file corrupt : ${fileTest}"  
			exit;  
		fi  
	fi
}

#save a copy of the original input file for later comparison
saveConfigFile() {
	cp ${confDir}/applicationConf.json ${confDir}/applicationConf.DONOTDELETE
}

#compare old copy of file with the newly input
compareConfigFile() {
	diff ${confDir}/applicationConf.json ${confDir}/applicationConf.DONOTDELETE
	status=$?
	if [ $status -gt 0 ] 
	then
		updatedFile="true"
		firstStatic="true"
		firstKeepAlive="true"
	fi
}

generateStartOfFile() {
	echo "[ { " > $etcdJsonFile
}

generateEndOfFile() {
	echo "} ] " >> $etcdJsonFile
}
 

#read any Static info
generateStatic() {


	if [ -e ${file} ]
	then
		totalCnt=0
		exists=`cat ${confDir}/applicationConf.json | grep '"Static"' | grep -v "grep" | wc -l`
		if [ $exists -gt 0 ]
		then
			totalCnt=`jq -c -r '.[] .Static | map(.key), map(.value) ' ${file} | jq -c -r '.[] ' | wc -l` 
		fi
		if [ $totalCnt -gt 0 ]
		then
			cnt=$(expr ${totalCnt}/2)
			i=0
			if [ $firstStatic == "true" ]
			then
				generateStartOfFile
				firstStatic="false"	
				echo \"Static\": [ >> $etcdJsonFile
			fi
			for ((i=0; i < ${cnt}; i++)); do
				iteration="'.[${i}] '"
				arry=( `eval "jq -c -r '.[] .Static| map(.key), map(.value) ' ${file} | jq -c -r ${iteration}" `)
				key=${arry[0]}
				value=${arry[1]}
				if [ $i == 0 ]
				then
					echo  {\"key\":\"$key\", \"value\":\"$value\" }  >> $etcdJsonFile
				else
					echo , {\"key\":\"$key\", \"value\":\"$value\" }  >> $etcdJsonFile
				fi
			done
			echo "${prefix} Processed Static data"
			return 0
		else
			echo "${prefix} No data for Static section"
			return 0
		fi
	else
		echo "${prefix} Configuration file not found"
		exit;
	fi
}

#read any KeepAlive info
generateKeepAlive() {


	if [ -e ${file} ]
	then
		totalCnt=0
		exists=`cat ${confDir}/applicationConf.json | grep '"KeepAlive"' | grep -v "grep" | wc -l`
		if [ $exists -gt 0 ]
		then
			totalCnt=`jq -c -r '.[] .KeepAlive | map(.key), map(.value) ' ${file} | jq -c -r '.[] ' | wc -l` 
		fi
		if [ $totalCnt -gt 0 ]
		then
			cnt=$(expr ${totalCnt}/2)
			i=0
			if [ $firstKeepAlive == "true" ]
			then
				if [ $firstStatic == "true" ]
				then
					generateStartOfFile
				fi
				if [ $firstStatic == "false" ]
				then
					echo "," >> $etcdJsonFile
				fi
				echo \"KeepAlive\": [ >> $etcdJsonFile
			fi			
			for ((i=0; i < ${cnt}; i++)); do
				iteration="'.[${i}] '"
				arry=( `eval "jq -c -r '.[] .KeepAlive | map(.key), map(.value), map(.healthCheck) ' ${file} | jq -c -r ${iteration}" `)
				key=${arry[0]}
				value=${arry[1]}
				healthCheck=${arry[2]}
				if [ $i == 0 ]
				then
					if [ $firstKeepAlive == "true" ]
					then
						firstKeepAlive="false"	
						echo  {\"key\":\"$key\", \"value\":\"$value\", \"healthcheck\":\"$healthCheck\", \"interval\":60, \"InitialDelay\":300 }  >> $etcdJsonFile
					else
						echo , {\"key\":\"$key\", \"value\":\"$value\", \"healthcheck\":\"$healthCheck\", \"interval\":60, \"InitialDelay\":300 }  >> $etcdJsonFile
					fi
				else
					echo , {\"key\":\"$key\", \"value\":\"$value\", \"healthcheck\":\"$healthCheck\", \"interval\":60, \"InitialDelay\":300 }  >> $etcdJsonFile
				fi
			done
			echo "${prefix} Processed KeepAlive data"
			return 0
		else
			echo "${prefix} No data for KeepAlive section"
			return 0
		fi
	else
		echo "${prefix} Configuration file not found"
		exit;
	fi
}

#read the ClientConfiguration key/value pairs and validate appName with port. If successful, create static keys and return code to cause dynamic keys to be generated
readClientConfiguration() {


	if [ -e ${file} ]
	then
		totalCnt=0
		exists=`cat ${confDir}/applicationConf.json | grep '"ClientConfiguration"' | grep -v "grep" | wc -l`
		if [ $exists -gt 0 ]
		then
			totalCnt=`jq -c -r '.[] .ClientConfiguration| map(.applicationName) ' ${file} | jq -c -r '.[] ' | wc -l` 
		fi
		if [ $totalCnt -gt 0 ]
		then
			iteration="'.[0] '"
			arry=( `eval "jq -c -r '.[] .ClientConfiguration | map(.applicationName), map(.applicationPort), map(.HARequired) ' ${file} | jq -c -r ${iteration}" `)
			applicationName=${arry[0]}
			applicationPort=${arry[1]}
			HARequired=${arry[2]}

                        if [ $HARequired == null ]
                        then
                                HARequired=true
                        fi

			addApplicationWithPort.sh $applicationName $applicationPort $HARequired
			status=$?
			if [ $status -eq 0 ]
			then
				if [ $firstStatic == "true" ]
				then
					generateStartOfFile
					firstStatic="false"	
					echo \"Static\": [ >> $etcdJsonFile
					echo  {\"key\":\"/config/lbaas/$applicationName:$applicationPort\", \"value\":\"$applicationPort\" }  >> $etcdJsonFile
				else
					echo , {\"key\":\"/config/lbaas/$applicationName:$applicationPort\", \"value\":\"$applicationPort\" }  >> $etcdJsonFile
				fi
				echo "0: good status back from addApplicationWithPort for $applicationName and $applicationPort" > $addApplicationLog
				return 0
			else
				echo "$status: bad status back from addApplicationWithPort for $applicationName and $applicationPort" > $addApplicationLog
				return $status
			fi
			echo "${prefix} Processed Client Configuration data"
		else
			echo "${prefix} No data for Client Configuration section"
			echo "0: " > $addApplicationLog
			return 1
		fi
	else
		echo "${prefix} Configuration file not found"
		exit;
	fi
	return 0
}

#read the ClientConfiguration and create keepAlive keys 
generateKeepAliveClientConfiguration() {

		iteration="'.[0] '"
		arry=( `eval "jq -c -r '.[] .ClientConfiguration | map(.applicationName), map(.applicationPort), map(.healthCheckFile) ' ${file} | jq -c -r ${iteration}" `)
		healthCheckFile=${arry[2]}
		if [ $firstKeepAlive == "true" ]
		then
			if [ $firstStatic == "true" ]
			then
				generateStartOfFile
			fi
			firstKeepAlive="false"	
			if [ $firstStatic == "false" ]
			then
				echo "," >> $etcdJsonFile
			fi
			echo \"KeepAlive\": [ >> $etcdJsonFile
		fi			
		echo  {\"key\":\"/lbaas/$applicationName/$applicationName\$HostIP\", \"value\":\"\$HostIP:$applicationPort\", \"healthcheck\":\"$healthCheckFile\", \"interval\":60, \"InitialDelay\":300  }  >> $etcdJsonFile
}

#read the Monitoring key/value pairs from the json file specified
#these will be maintained in the etcd cluster and replaced if deleted
readMonitoring() {

	if [ -e ${file} ]
	then
		monitoring=`jq -c -r '.[] .Monitoring ' ${file}`
		if [ $monitoring == "true" ] 
		then
			echo "${prefix} Monitoring is enabled"
			return 0
		else
			echo "${prefix} Monitoring is disabled"
			return 1
		fi
	else
		echo "${prefix} Configuration file not found"
		exit;
	fi
}

#read the ServiceRegistration key/value pairs from the json file specified
#these will be maintained in the zk cluster and replaced if deleted
#"solution": "ndvr",	
#"component": "frontend",
#"serviceName": "sms",
#"port":"8805",
#"healthCheckUrl": "/sms"

readServiceRegistration() {

	if [ -e ${file} ]
	then
		totalCnt=0
		exists=`cat ${confDir}/applicationConf.json | grep '"ServiceRegistration"' | grep -v "grep" | wc -l`
		if [ $exists -gt 0 ]
		then
			totalCnt=`jq -c -r '.[] .ServiceRegistration | map(.component), map(.serviceName) ' ${file} | jq -c -r '.[] ' | wc -l`
		fi
		if [ $totalCnt -gt 0 ] 
		then
			cnt=$(expr ${totalCnt}/2)
			i=0
			for ((i=0; i < ${cnt}; i++)); do
				iteration="'.[${i}] '"
				arry=( `eval "jq -c -r '.[] .ServiceRegistration | map(.solution), map(.component), map(.serviceName), map(.port), map(.healthCheckUrl), map(.healthCheckPort) ' ${file} | jq -c -r ${iteration}" `)
				SR_SOLUTION_ARRAY[${i}]=${arry[0]}
				SR_COMPONENT_ARRAY[${i}]=${arry[1]}
				SR_NAME_ARRAY[${i}]=${arry[2]}
				SR_PORT_ARRAY[${i}]=${arry[3]}
				SR_HEALTH_ARRAY[${i}]=${arry[4]}
				SR_HEALTHPORT_ARRAY[${i}]=${arry[5]}
			done
			echo "${prefix} Processed Service Registration data"
		else
			echo "${prefix} No data for Service Registration section"
		fi
	else
		echo "${prefix} Configuration file not found"
		exit;
	fi
	nerveList=null
	for ((instance=0; instance < ${#SR_NAME_ARRAY[@]}; instance++)); do
        	solution=${SR_SOLUTION_ARRAY[${instance}]}	
        	component=${SR_COMPONENT_ARRAY[${instance}]}
        	name=${SR_NAME_ARRAY[${instance}]}
        	port=${SR_PORT_ARRAY[${instance}]}
        	health=${SR_HEALTH_ARRAY[${instance}]}
        	healthPort=${SR_HEALTHPORT_ARRAY[${instance}]}
		if [ $instance == 0 ]
 		then
			nerveList=$solution" "$component" "$name:$port:$health
		else
			nerveList=$nerveList" "$name:$port:$health
		fi
		if [ $healthPort != null ]
		then
			nerveList=$nerveList:$healthPort
		fi
	done
	if [ "${nerveList}" != null ]
	then
		/usr/sbin/$NERVE_CONFIG_SCRIPT_FILE `echo $nerveList`
	fi
}

#read the ServiceDiscovery key/value pairs from the json file specified
#these will be maintained in the zk cluster and replaced if deleted
#"solution": "ndvr",	    
#"component": "frontend",
#"serviceName": "cs",
#"haProxyPort":"3213"

readServiceDiscovery() {

	if [ -e ${file} ]
	then
		totalCnt=0
		exists=`cat ${confDir}/applicationConf.json | grep '"ServiceDiscovery"' | grep -v "grep" | wc -l`
		if [ $exists -gt 0 ]
		then
			totalCnt=`jq -c -r '.[] .ServiceDiscovery | map(.component), map(.serviceName) ' ${file} | jq -c -r '.[] ' | wc -l`
		fi	
		if [ $totalCnt -gt 0 ] 
		then
			cnt=$(expr ${totalCnt}/2)
			i=0
			for ((i=0; i < ${cnt}; i++)); do
				iteration="'.[${i}] '"
				arry=( `eval "jq -c -r '.[] .ServiceDiscovery | map(.solution), map(.component), map(.serviceName), map(.haProxyPort) ' ${file} | jq -c -r ${iteration}" `)
				SD_SOLUTION_ARRAY[${i}]=${arry[0]}
				SD_COMPONENT_ARRAY[${i}]=${arry[1]}
				SD_NAME_ARRAY[${i}]=${arry[2]}
				SD_HAPROXYPORT_ARRAY[${i}]=${arry[3]}
			done
			echo "${prefix} Processed Service Discovery data"
		else
			echo "${prefix} No data for Service Discovery section"
		fi
	else
		echo "${prefix} Configuration file not found"
		exit;
	fi
	synapseList=null
	port=9999
	for ((instance=0; instance < ${#SD_NAME_ARRAY[@]}; instance++)); do
        	solution=${SD_SOLUTION_ARRAY[${instance}]}	
        	component=${SD_COMPONENT_ARRAY[${instance}]}
        	name=${SD_NAME_ARRAY[${instance}]}
        	haProxyPort=${SD_HAPROXYPORT_ARRAY[${instance}]}
		if [ $instance == 0 ]
 		then
			synapseList=$solution" "$component":"$name:$port:$haProxyPort
		else
			synapseList=$synapseList" "$component:$name:$port:$haProxyPort
		fi
	done
	if [ "${synapseList}" != null ]
	then
		/usr/sbin/$SYNAPSE_CONFIG_SCRIPT_FILE `echo $synapseList`
	fi
}

generateMonitoringData() {

		if [ $firstStatic == "true" ]
		then
			echo \"Static\": [ {\"key\":\"/config/advisor/\$HostName\", \"value\":\"\$HostIP\" }  >> $etcdJsonFile
			firstStatic="false"
		else
			echo , {\"key\":\"/config/advisor/\$HostName\", \"value\":\"\$HostIP\" }  >> $etcdJsonFile
		fi
}

############### Start ######################
rm -rf $addApplicationLog
findConfig
while :
do
	if [ $firstTime == "false" ]
	then
		compareConfigFile
	fi
	if [ $firstTime == "true" ] || [ $updatedFile == "true" ]
	then
		rm -f $etcdJsonFile
		generateStatic 

		readClientConfiguration
		goodClientConfiguration=$?

		readMonitoring
		monitoringExist=$? 
		if [ $monitoringExist -eq 0 ]
		then
    			generateMonitoringData
		fi

		if [ $firstStatic == "false" ]
		then
			echo " ] " >> $etcdJsonFile
		fi

		if [ $goodClientConfiguration -eq 0 ] || [ $goodClientConfiguration -eq 3 ]
		then
			#need to generate KeepAlived keys for etcd
			generateKeepAliveClientConfiguration

		fi
		generateKeepAlive
		if [ $firstKeepAlive == "false" ]
		then
			echo " ] " >> $etcdJsonFile
		fi
		if [ $firstKeepAlive == "false" ] || [ $firstStatic == "false" ]
		then
			generateEndOfFile
		fi
		readServiceRegistration
		readServiceDiscovery
		saveConfigFile
	fi
	if [ $goodClientConfiguration -ne 0 ]
	then
		exit $goodClientConfiguration
	fi
	firstTime="false"
	updatedFile="false"
	sleep 60
done

