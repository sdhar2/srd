# Dockerfile for ZooKeeper


FROM arrs/arrs-cloud-base-java:2.0.0.1
MAINTAINER ARRIS

# Get latest stable release of ZooKeeper

ADD fs /
WORKDIR /

RUN mkdir zoo
RUN unzip binaries/zoo.zip -d /zoo

RUN chmod +x /startZoo.sh; chmod +x /addKey.sh; chmod +x /usr/local/bin/*

CMD  /startZoo.sh

