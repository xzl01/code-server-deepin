# syntax=docker/dockerfile:experimental

ARG BASE=linuxdeepin/deepin
FROM scratch AS packages

# 使用 Deepin 基础镜像
FROM $BASE

RUN echo "deb [trusted=yes] https://ci.deepin.com/repo/deepin/deepin-community/testing/ unstable main community commercial" | tee -a /etc/apt/sources.list

# 更新系统并安装必要工具
RUN apt-get update \
  && apt-get install -y \
    curl \
    dumb-init \
    git \
    git-lfs \
    htop \
    locales \
    lsb-release \
    man-db \
    nano \
    openssh-client \
    procps \
    sudo \
    vim-tiny \
    wget \
    zsh \
    jq \
  && git lfs install \
  && rm -rf /var/lib/apt/lists/*

# 下载code server
RUN ARCH=$(dpkg --print-architecture) && \
    curl -s https://api.github.com/repos/coder/code-server/releases/latest \
    | jq -r ".assets[] | select(.name | test(\"code-server.*$ARCH.deb\")) | .browser_download_url" \
    | sed 's#https://github.com#https://gh-proxy.com/https://github.com#' \
    | xargs -n 1 wget -P /tmp/

# 设置中文语言环境
RUN sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen \
  && locale-gen
ENV LANG=en_US.UTF-8

# 添加新用户 coder 并给予 sudo 权限
RUN adduser --gecos '' --disabled-password coder \
  && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# 安装 fixuid 工具，用于保持用户和组 ID 一致性
RUN ARCH="$(dpkg --print-architecture)" \
  && curl -fsSL "https://gh-proxy.com/https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-$ARCH.tar.gz" | tar -C /usr/local/bin -xzf - \
  && chown root:root /usr/local/bin/fixuid \
  && chmod 4755 /usr/local/bin/fixuid \
  && mkdir -p /etc/fixuid \
  && printf "user: coder\ngroup: coder\n" > /etc/fixuid/config.yml

# 拷贝 entrypoint 脚本
COPY ./entrypoint.sh  /usr/bin/entrypoint.sh

# 安装 code-server
RUN dpkg -i /tmp/code-server*$(dpkg --print-architecture).deb

# 允许用户在容器启动时执行脚本来准备工作空间
ENV ENTRYPOINTD=${HOME}/entrypoint.d

# 暴露端口
EXPOSE 8080

# 设置用户和工作目录
USER 1000
ENV USER=coder
WORKDIR /home/coder

# 自定义启动命令
ENTRYPOINT ["/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]

