FROM opensuse:42.2

# non-default docker proxy vars
ARG ALL_PROXY
ARG socks_proxy
ARG SOCKS_PROXY

RUN zypper --no-color --non-interactive ref -f && \
    zypper --no-color --non-interactive update && \
    zypper --no-color --non-interactive install --no-recommends python gcc \
            gcc-c++ git chrpath make wget python-xml diffstat makeinfo \
            python-curses patch socat libSDL-devel tar which unzip \
            net-tools iproute2 vim \
            python3 python3-curses glibc-locale syslinux

ENV JENKINS_HOME /var/lib/jenkins

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN groupadd -o -g ${gid} ${group} \
	&& useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# VOLUME ${JENKINS_HOME}

USER jenkins
WORKDIR ${JENKINS_HOME}
