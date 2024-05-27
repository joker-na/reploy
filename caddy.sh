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
sudo apt-get install caddy -y

# 获取用户输入的域名
echo "Please enter the domain you want to use:"
read domain

# 获取用户输入的端口
echo "Please enter the port you want to reverse proxy to:"
read port

# 清空Caddyfile并写入新的配置
echo "${domain} {
  reverse_proxy 127.0.0.1:${port}
}" | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# 重启Caddy服务以应用新的配置
sudo systemctl restart caddy
