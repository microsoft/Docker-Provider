FROM ubuntu:18.04
MAINTAINER OMSContainers@microsoft.com
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers"
ENV tmpdir /opt
ENV APPLICATIONINSIGHTS_AUTH NzAwZGM5OGYtYTdhZC00NThkLWI5NWMtMjA3ZjM3NmM3YmRi
ENV MALLOC_ARENA_MAX 2
ENV HOST_MOUNT_PREFIX /hostfs
ENV HOST_PROC /hostfs/proc
ENV HOST_SYS /hostfs/sys
ENV HOST_ETC /hostfs/etc
ENV HOST_VAR /hostfs/var
ENV AZMON_COLLECT_ENV False
ENV KUBE_CLIENT_BACKOFF_BASE 1
ENV KUBE_CLIENT_BACKOFF_DURATION 0
ENV RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR 0.9
RUN /usr/bin/apt-get update && /usr/bin/apt-get install -y libc-bin wget openssl curl sudo python-ctypes init-system-helpers  net-tools rsyslog cron vim dmidecode apt-transport-https gnupg && rm -rf /var/lib/apt/lists/*
COPY setup.sh main.sh defaultpromenvvariables defaultpromenvvariables-rs defaultpromenvvariables-sidecar mdsd.xml envmdsd logrotate.conf $tmpdir/

ARG IMAGE_TAG=ciprod03172022
ENV AGENT_VERSION ${IMAGE_TAG}

WORKDIR ${tmpdir}

# copy docker provider shell bundle to use the agent image
COPY ./Linux_ULINUX_1.0_*_64_Release/docker-cimprov-*.*.*-*.*.*.sh .
# Note: If you prefer remote destination, uncomment below line and comment above line
# wget https://github.com/microsoft/Docker-Provider/releases/download/10.0.0-1/docker-cimprov-10.0.0-1.universal.x86_64.sh

RUN chmod 775 $tmpdir/*.sh; sync; $tmpdir/setup.sh
CMD [ "/opt/main.sh" ]

