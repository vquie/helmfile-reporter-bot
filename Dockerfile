FROM debian:11.6-slim

ARG VERSION
ENV VERSION ${VERSION}

ARG TARGETARCH

ARG _HELMFILE_VERSION="0.152.0"
ARG _GIT_VERSION="*"
ARG _AWSCLI_VERSION="1.27.*"

RUN apt-get update && apt-get install -y --no-install-recommends \
    git=${_GIT_VERSION} \
    wget \
    ca-certificates \
	python3 \
	python3-pip && \
    pip3 install --no-cache-dir awscli==${_AWSCLI_VERSION} && \
    apt-get remove --purge -y python3-pip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install helmfile
RUN wget --no-check-certificate https://github.com/helmfile/helmfile/releases/download/v${_HELMFILE_VERSION}/helmfile_${_HELMFILE_VERSION}_linux_${TARGETARCH}.tar.gz \
    -O /tmp/helmfile.tar.gz && \
    tar xzvf /tmp/helmfile.tar.gz -C /tmp && \
    mv /tmp/helmfile /usr/local/bin/ && \
    rm -rf /tmp/*

# init helmfile
RUN helmfile init --force

COPY ./rootfs /

RUN chmod -R 0755 /opt/helmfile-reporter-bot/*

VOLUME ["/opt/helmfile-reporter-bot/"]

CMD ["/opt/helmfile-reporter-bot/helmfile-reporter-bot.sh"]
