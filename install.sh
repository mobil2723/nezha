#!/bin/bash

# 颜色定义
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
plain='\033[0m'

# Logo展示
show_logo() {
    clear
    echo -e "${blue}
    _   __          __              __  ___           _ __            
   / | / /__  ____ / /_  ____ _   /  |/  /___  ____  (_) /_____  _____
  /  |/ / _ \/_  // __ \/ __ \`/  / /|_/ / __ \/ __ \/ / __/ __ \/ ___/
 / /|  /  __/ / // / / / /_/ /  / /  / / /_/ / / / / / /_/ /_/ / /    
/_/ |_/\___/ /___/_/ /_/\__,_/  /_/  /_/\____/_/ /_/_/\__/\____/_/     
                                                                      ${plain}"
    echo -e "${yellow}=================== 哪吒监控探针安装脚本 ===================${plain}"
    echo -e "${green}版本：${plain}1.0.0"
    echo -e "${green}系统：${plain}$(uname -s) $(uname -m)"
    echo -e "${green}内核：${plain}$(uname -r)"
    echo -e "${yellow}=======================================================${plain}"
    echo
}

# 输出函数
err() {
    printf "${red}[错误] %s${plain}\n" "$*" >&2
}

success() {
    printf "${green}[成功] %s${plain}\n" "$*"
}

info() {
    printf "${blue}[信息] %s${plain}\n" "$*"
}

warn() {
    printf "${yellow}[警告] %s${plain}\n" "$*"
}

# 依赖检查
deps_check() {
    info "检查依赖..."
    
    deps="wget unzip grep"
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            err "$dep 未找到，请先安装该依赖"
            exit 1
        fi
    done
    
    success "依赖检查通过"
}

# 环境检查
env_check() {
    info "检查系统环境..."
    
    mach=$(uname -m)
    case "$mach" in
        amd64|x86_64)
            os_arch="amd64"
            ;;
        i386|i686)
            os_arch="386"
            ;;
        aarch64|arm64)
            os_arch="arm64"
            ;;
        *arm*)
            os_arch="arm"
            ;;
        *)
            err "未知架构: $mach"
            exit 1
            ;;
    esac

    system=$(uname)
    case "$system" in
        *Linux*)
            os="linux"
            ;;
        *FreeBSD*)
            os="freebsd"
            ;;
        *)
            err "不支持的操作系统: $system"
            exit 1
            ;;
    esac
    
    success "系统环境检查通过: $os $os_arch"
}

# 清理函数
cleanup() {
    info "清理环境..."
    
    ps aux | grep "[n]ezha-agent" | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    ps aux | grep "[t]ee -a logs/nezha-agent.log" | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    rm -f ./nezha/nezha-agent.pid 2>/dev/null || true
    rm -f ./nezha/config.json 2>/dev/null || true
    rm -f ./nezha/logs/nezha-agent.log 2>/dev/null || true
    mkdir -p ./nezha/logs
    
    success "环境清理完成"
}

# 初始化
init() {
    deps_check
    env_check
}

# 主函数
main() {
    show_logo
    
    # 初始化
    init

    # 清理旧文件
    cleanup

    # 设置安装目录
    INSTALL_DIR="./nezha"
    LOG_DIR="$INSTALL_DIR/logs"

    # 创建必要的目录
    info "创建安装目录..."
    mkdir -p "$LOG_DIR"

    # 下载 nezha-agent
    info "正在下载 nezha-agent..."
    DOWNLOAD_URL="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_${os}_${os_arch}.zip"
    echo "下载地址: $DOWNLOAD_URL"

    # 下载并解压
    cd "$INSTALL_DIR"
    wget -O nezha-agent.zip "$DOWNLOAD_URL" || {
        warn "下载失败，尝试备用地址..."
        wget -O nezha-agent.zip "https://gitee.com/naibahq/agent/releases/latest/download/nezha-agent_${os}_${os_arch}.zip" || {
            err "下载失败，请检查网络连接"
            exit 1
        }
    }

    # 解压文件
    info "解压文件..."
    unzip -o nezha-agent.zip
    rm nezha-agent.zip

    # 设置权限
    chmod +x nezha-agent

    # 检查文件类型
    info "检查文件类型..."
    file nezha-agent

    # 创建配置文件
    info "创建配置文件..."
    cat > config.json << EOF
{
    "client_secret": "agent_secret_key",
    "debug": false,
    "disable_auto_update": false,
    "disable_command_execute": false,
    "disable_force_update": false,
    "disable_nat": false,
    "disable_send_query": false,
    "gpu": false,
    "insecure_tls": false,
    "ip_report_period": 1800,
    "report_delay": 2,
    "server": "服务器IP:端口",
    "skip_connection_count": false,
    "skip_procs_count": false,
    "temperature": false,
    "tls": false,
    "use_gitee_to_upgrade": false,
    "use_ipv6_country_code": false
}
EOF

    # 显示配置文件内容
    info "配置文件内容："
    cat config.json

    # 创建启动脚本
    info "创建启动脚本..."
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
mkdir -p logs

# 颜色定义
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
plain='\033[0m'

# 输出函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> logs/nezha-agent.log
}

# 记录启动时间
log "===================== 启动哪吒探针 ====================="
log "启动时间: $(date)"

# 检查配置文件
if [ ! -f "config.json" ]; then
    log "错误: 配置文件不存在"
    exit 1
fi

# 检查可执行文件
if [ ! -x "./nezha-agent" ]; then
    log "错误: nezha-agent 文件不存在或没有执行权限"
    exit 1
fi

# 检查系统信息
log "系统信息:"
uname -a >> logs/nezha-agent.log
log "内存信息:"
free -h >> logs/nezha-agent.log
log "磁盘信息:"
df -h >> logs/nezha-agent.log

# 检查系统限制
log "检查系统限制..."
ulimit -a >> logs/nezha-agent.log

# 启动进程
log "正在启动哪吒探针..."
log "当前目录: $(pwd)"
log "配置文件内容:"
cat config.json >> logs/nezha-agent.log

# 直接运行并捕获输出
./nezha-agent -c config.json 2>&1 | tee -a logs/nezha-agent.log &

# 保存PID
echo $! > nezha-agent.pid
log "进程PID: $!"

# 等待几秒检查进程是否存活
sleep 3
if ps -p $! > /dev/null; then
    log "哪吒探针启动成功"
else
    log "哪吒探针启动失败"
    log "最后10行日志："
    tail -n 10 logs/nezha-agent.log >> logs/nezha-agent.log
    log "进程状态："
    ps aux | grep nezha-agent >> logs/nezha-agent.log
    log "系统日志："
    dmesg | tail -n 20 >> logs/nezha-agent.log 2>&1 || true
    exit 1
fi
EOF

    chmod +x start.sh

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
EOF

    chmod +x stop.sh

    # 启动服务
    info "正在启动哪吒探针..."
    ./start.sh

    # 检查进程是否运行
    if [ -f "nezha-agent.pid" ]; then
        pid=$(cat nezha-agent.pid)
        if ps -p $pid > /dev/null; then
            success "哪吒探针已成功启动！"
            echo -e "${green}PID: ${plain}$pid"
            echo -e "${green}日志文件位置: ${plain}$LOG_DIR/nezha-agent.log"
        else
            err "启动失败，请检查日志文件"
            echo "最后10行日志："
            tail -n 10 "$LOG_DIR/nezha-agent.log"
        fi
    else
        err "启动失败，请检查日志文件"
        echo "最后10行日志："
        tail -n 10 "$LOG_DIR/nezha-agent.log"
    fi

    echo -e "\n${yellow}=======================================================${plain}"
    success "哪吒探针已安装完成，已成功启动！"
    echo -e "${blue}使用方法：${plain}"
    echo -e "  ${green}启动服务：${plain}$INSTALL_DIR/start.sh"
    echo -e "  ${green}停止服务：${plain}$INSTALL_DIR/stop.sh"
    echo -e "  ${green}查看日志：${plain}tail -f $LOG_DIR/nezha-agent.log"
    echo -e "${yellow}=======================================================${plain}\n"
}

# 运行主函数
main 
