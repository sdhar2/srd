#!/bin/bash

PORT1=4001
PORT2=7001 
export ETCD_HOST=`host etcdCluster | cut -d " " -f4`

touch $ETCD_OUT_FILE
chmod 777 $ETCD_OUT_FILE

ip -family inet -oneline addr list dev eth0 | awk '{split($4,array,"/"); print array[1];}' > /tmp2/myIp

cp /etcd/config/*.json /opt/etcd/config/

if [ "${IS_LEADER}" == "true" ]
then
   ETCD_ARGS="-name ${HOST_IP} \
   -advertise-client-urls http://${HOST_IP}:$PORT1 \
   -data-dir=$ETCD_DATA_DIR \
   -initial-advertise-peer-urls http://${HOST_IP}:$PORT2 \
   -initial-cluster-state new \
   -initial-cluster ${HOST_IP}=http://${HOST_IP}:$PORT2 \
   -listen-client-urls http://0.0.0.0:$PORT1 -listen-peer-urls http://0.0.0.0:$PORT2 -cors=*"
else
   etcdctl  --no-sync --peers  http://${ETCD_HOST}:$PORT1 member add ${HOST_IP} http://${HOST_IP}:$PORT2 2>&1 > /tmp/members             
   
   initial=`grep ETCD_INITIAL_CLUSTER= /tmp/members`
   list="$( cut -d '=' -f 2- <<< "$initial" )"
   newlist="$(cut -d '"'  -f 2- <<< "$list" )"
   newerlist="$(cut -d '"'  -f1 <<< "$newlist" )"

   export ETCD_INITIAL_CLUSTER=$newerlist
   export ETCD_INITIAL_CLUSTER_STATE="existing"
   export ETCD_NAME="${HOST_IP}"
   export ETCD_ARGS="-advertise-client-urls http://${HOST_IP}:$PORT1 \
   -data-dir=$ETCD_DATA_DIR \
   -initial-advertise-peer-urls http://${HOST_IP}:$PORT2 \
   -listen-client-urls http://0.0.0.0:$PORT1 -listen-peer-urls http://0.0.0.0:$PORT2 -cors=*"
fi

./etcd-v2.0.0-rc.1-linux-amd64/etcd $ETCD_ARGS 
