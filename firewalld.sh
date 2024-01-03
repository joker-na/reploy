#!/bin/bash

# 安装firewalld（如果未安装的话）
if ! command -v firewall-cmd &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y firewalld
fi

# 判断是否已经添加了默认端口规则
default_ports_added=false

if sudo firewall-cmd --list-ports | grep -q "22/tcp" && \
   sudo firewall-cmd --list-ports | grep -q "80/tcp" && \
   sudo firewall-cmd --list-ports | grep -q "443/tcp"; then
    default_ports_added=true
fi

# 如果没有添加默认端口规则，则添加
if [ "$default_ports_added" = false ]; then
    # 开启22，80，443端口
    sudo firewall-cmd --permanent --add-port=22/tcp > /dev/null 2>&1
    sudo firewall-cmd --permanent --add-port=80/tcp > /dev/null 2>&1
    sudo firewall-cmd --permanent --add-port=443/tcp > /dev/null 2>&1
    # 重新加载firewalld规则
    sudo firewall-cmd --reload > /dev/null 
2>&1
    echo "已添加默认端口规则"
fi

while true; do
    # 输出菜单
    clear
    echo "已开启的端口： $(sudo firewall-cmd --list-ports 2>&1 | awk '/[0-9]+\/tcp|udp/')"
    echo "1. 开启端口"
    echo "2. 关闭端口"
    echo "3. 设置开机自启"
    echo "0. 退出"

    # 读取用户选择
    read -p "请输入选项（1、2、3或0）: " option

    case $option in
        1)
            read -p "请输入要开启的端口号: " port
            if ! [[ $port =~ ^[0-9]+$ ]]; then
                echo "无效的端口号，请输入一个整数。"
                continue
            fi
            sudo firewall-cmd --permanent --add-port=$port/tcp > /dev/null
            sudo firewall-cmd --reload > /dev/null 2>&1
            ;;
        2)
            read -p "请输入要关闭的端口号: " port
            if ! [[ $port =~ ^[0-9]+$ ]]; then
                echo "无效的端口号，请输入一个整数。"
                continue
            fi
            sudo firewall-cmd --permanent --remove-port=$port/tcp > /dev/null 2>&1
            sudo firewall-cmd --reload > /dev/null 2>&1
            ;;
        3)
            # 设置开机自启
            sudo systemctl enable firewalld 2>/dev/null
            echo "已设置firewalld服务开机自启"
            ;;
        0)
            echo "已退出脚本"
            exit 0
            ;;
        *)
            echo "无效选项，请重新输入。"
            ;;
    esac
done
