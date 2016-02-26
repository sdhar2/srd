
FROM arrs/arrs-cloud-base-centos6-6:2.0.0.1
MAINTAINER ARRIS

ADD fs /
WORKDIR /

RUN curl -s --insecure https://areopagus/binaries/etcd-v2.0.0-rc.1.tar.gz | tar xz

RUN chmod 755 /usr/local/bin/etcdctl; chmod +x /startEtcd.sh

# Container start command
CMD /startEtcd.sh 
