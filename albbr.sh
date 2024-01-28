#!/bin/bash

# 将内容写入 /etc/sysctl.conf
cat <<EOF > /etc/sysctl.conf
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF

# 应用更改
sysctl -p
