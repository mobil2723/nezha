#!/bin/bash

# 停止所有nezha-agent进程
echo "正在停止所有哪吒探针进程..."
ps aux | grep "[n]ezha-agent" | awk '{print $2}' | xargs kill -9 2>/dev/null || true
ps aux | grep "[t]ee -a logs/nezha-agent.log" | awk '{print $2}' | xargs kill -9 2>/dev/null || true

# 检查是否还有进程存在
if ps aux | grep -q "[n]ezha-agent"; then
    echo "警告：仍有哪吒探针进程在运行。"
    ps aux | grep "[n]ezha-agent"
else
    echo "所有哪吒探针进程已停止。"
fi

# 清理临时文件
echo "正在清理PID文件和配置文件..."
rm -f ./nezha/nezha-agent.pid 2>/dev/null || true
rm -f ./nezha/config.json 2>/dev/null || true

# 清理日志
echo "清理旧日志文件..."
rm -f ./nezha/logs/nezha-agent.log 2>/dev/null || true
mkdir -p ./nezha/logs

echo "清理完成！" 