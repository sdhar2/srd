# Base image with java supervisor
FROM arrs/arrs-cloud-base-nerve:1.2.0.1
MAINTAINER ARRIS
RUN cd /etc/yum.repos.d/ && sed -i -e 's/168.84.250.205/acpdocker/' *.repo
RUN yum install -y wget && yum -y upgrade glibc bash && yum clean all && rm -rf /tmp/* /var/tmp/*
ADD fs /
WORKDIR /
RUN chmod +x /startup.sh
CMD ["/startup.sh"]
