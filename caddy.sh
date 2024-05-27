#!/bin/bash

# 更新系统
sudo apt-get update

# 安装必要的工具
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https

# 导入Caddy的公钥
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo apt-key add -

# 导入Caddy的APT repo
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/deb/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# 更新APT包索引
sudo apt-get update

# 安装Caddy
sudo apt-get install caddy
