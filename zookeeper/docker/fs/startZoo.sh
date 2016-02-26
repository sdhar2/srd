#!/bin/bash

cp /etcd/config/*.json /opt/etcd/config/
cp /opt/zookeeper-3.4.6/data/myid /zoo/data/myid

prog="zookeeper"
exec="/opt/zookeeper-3.4.6/bin"
pidfile="/var/run/$prog.pid"
lockfile="/var/lock/subsys/$prog"
logfile="/var/log/$prog"


if [ ${HAMode} == "HA" ]; then
	echo "$date DEBUG: running in HA Mode." >> $logfile
else
	echo "$date DEBUG: running in non-HA Mode." >> $logfile
	cp /zoo/conf/zoo.single.cfg /zoo/conf/zoo.cfg
fi

rm -f $pidfile
echo "$date DEBUG: Starting $prog" >> $logfile
cd /zoo/bin
sh ./zkServer.sh start &>> $logfile &
pid=$!
touch $lockfile

/bin/bash
