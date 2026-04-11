FROM ubuntu:24.04

ARG MIHOMO_VERSION=v1.18.1
ARG TARGETARCH=amd64

# 1. 安装基础工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gzip \
    iproute2 \
    iptables \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 2. 下载并安装 mihomo (Clash Meta)
RUN wget -O /tmp/mihomo.gz "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${TARGETARCH}-${MIHOMO_VERSION}.gz" \
    && gunzip /tmp/mihomo.gz \
    && mv /tmp/mihomo /usr/local/bin/mihomo \
    && chmod +x /usr/local/bin/mihomo

# 3. 准备配置目录并复制配置文件
RUN mkdir -p /root/.config/mihomo /var/log
COPY config.example.yaml /root/.config/mihomo/config.yaml
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
