FROM crops/yocto:ubuntu-17.04-base

# non-default docker proxy vars
ARG ALL_PROXY
ARG socks_proxy
ARG SOCKS_PROXY

ENV JENKINS_HOME /var/lib/jenkins

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

USER root

RUN apt-get install -y python3-pip
RUN pip3 install unittest-xml-reporting

RUN groupadd -o -g ${gid} ${group} \
	&& useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# VOLUME ${JENKINS_HOME}

USER jenkins
WORKDIR ${JENKINS_HOME}
