FROM ubuntu:24.04

ARG MIHOMO_VERSION=v1.18.1
ARG TARGETARCH=amd64
ARG DEBIAN_FRONTEND=noninteractive

# 1. 安装基础工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash-completion \
    ca-certificates \
    curl \
    git \
    gzip \
    iproute2 \
    iptables \
    locales \
    openssh-client \
    sudo \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# 2. 下载并安装 mihomo (Clash Meta)
RUN wget -O /tmp/mihomo.gz "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${TARGETARCH}-${MIHOMO_VERSION}.gz" \
    && gunzip /tmp/mihomo.gz \
    && mv /tmp/mihomo /usr/local/bin/mihomo \
    && chmod +x /usr/local/bin/mihomo

# 3. 准备配置目录并复制配置文件
RUN mkdir -p /root/.config/mihomo /var/log
COPY config.example.yaml /root/.config/mihomo/config.yaml
COPY entrypoint.sh /entrypoint.sh
COPY skel/ /etc/skel/
COPY workspace-shell.sh /etc/profile.d/workspace-shell.sh

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN chmod +x /entrypoint.sh
RUN chmod 644 /etc/profile.d/workspace-shell.sh \
    && printf '\n[ -r /etc/profile.d/workspace-shell.sh ] && . /etc/profile.d/workspace-shell.sh\n' >> /etc/bash.bashrc

RUN mkdir -p /etc/sudoers.d \
    && printf '%%sudo ALL=(ALL:ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/99-workspace \
    && chmod 440 /etc/sudoers.d/99-workspace

ENTRYPOINT ["/entrypoint.sh"]
