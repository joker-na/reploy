#!/bin/bash
# 更新软件包索引
apk update
# 安装 Docker CE
apk add docker
# 启动 Docker 服务
service docker start
# 设置 Docker 自启动（可选）
rc-update add docker boot
