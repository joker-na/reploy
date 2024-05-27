#!/bin/bash

# 更新系统的软件包列表
sudo apt update

# 安装 Node.js 和 npm
sudo apt install -y nodejs npm

# 使用 npm 安装 yarn
sudo npm install -g yarn

# 使用 yarn 安装 pm2
sudo yarn global add pm2

yarn

yarn build
