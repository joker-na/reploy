#!/bin/bash

# 检查端口8181是否被占用
port_in_use=$(sudo lsof -i :8181)

# 如果端口被占用，执行第三步和第四步
if [ -n "$port_in_use" ]; then
    # 提取PID
    pid=$(echo "$port_in_use" | awk 'NR==2 {print $2}')

    # 第三步：杀死进程
    sudo kill $pid
    echo "Killed process with PID $pid"
fi

# 第四步：后台运行PandoraNext
nohup ./PandoraNext &
echo "PandoraNext started in the background."
