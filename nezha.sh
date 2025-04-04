#!/bin/sh

# 修改安装路径，使用用户目录
NZ_BASE_PATH="$HOME/.nezha"
NZ_DASHBOARD_PATH="${NZ_BASE_PATH}/dashboard"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 新增配色
blue='\033[0;34m'
cyan='\033[0;36m'
white='\033[1;37m'
gray='\033[0;37m'
purple='\033[0;35m'
orange='\033[0;33m'
light_red='\033[1;31m'
light_green='\033[1;32m'
light_blue='\033[1;34m'
light_cyan='\033[1;36m'
bg_red='\033[41m'
bg_green='\033[42m'
bg_blue='\033[44m'
bg_gray='\033[47m'
bold='\033[1m'
underline='\033[4m'
blink='\033[5m'

err() {
    printf "${bg_red}${white}  ERROR  ${plain} ${red}%s${plain}\n" "$*" >&2
}

warn() {
    printf "${bg_red}${white} WARNING ${plain} ${yellow}%s${plain}\n" "$*"
}

success() {
    printf "${bg_green}${white} SUCCESS ${plain} ${green}%s${plain}\n" "$*"
}

info() {
    printf "${bg_blue}${white}  INFO   ${plain} ${blue}%s${plain}\n" "$*"
}

println() {
    printf "$*\n"
}

run_cmd() {
    "$@"
}

deps_check() {
    deps="curl wget unzip grep jq"
    set -- "$api_list"
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            err "未找到依赖 $dep，请先安装。"
            exit 1
        fi
    done
}

env_check() {
    # 检测是否为FreeBSD系统
    OS_TYPE=$(uname -s)
    if [ "$OS_TYPE" = "FreeBSD" ]; then
        IS_FREEBSD=1
    else
        IS_FREEBSD=0
    fi

    # 检测系统架构
    uname=$(uname -m)
    case "$uname" in
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
        s390x)
            os_arch="s390x"
            ;;
        riscv64)
            os_arch="riscv64"
            ;;
        *)
            err "未知架构：$uname"
            exit 1
            ;;
    esac
}

installation_check() {
    if [ -f "$NZ_DASHBOARD_PATH/dashboard" ] || [ -f "$NZ_DASHBOARD_PATH/app" ]; then
        IS_FRESH_INSTALL=0
    else
        IS_FRESH_INSTALL=1
    fi
}

init() {
    deps_check
    env_check
    installation_check
}

before_show_menu() {
    echo ""
    echo ""
    info "* 按回车返回主菜单 *" 
    read -r temp
    show_menu
}

get_latest_version() {
    if [ "$IS_FREEBSD" = 1 ]; then
        # FreeBSD版本使用特定仓库
        RELEASE_LATEST=$(curl -s https://api.github.com/repos/wansyu/nezha-freebsd/releases/latest | jq -r '.tag_name')
        if [ -z "$RELEASE_LATEST" ]; then
            err "获取最新版本失败，请检查您的网络。"
            exit 1
        fi
    else
        # 其他系统使用原本的版本获取方法
        _version=$(curl -m 10 -sL "https://api.github.com/repos/nezhahq/nezha/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        if [ -z "$_version" ]; then
            _version=$(curl -m 10 -sL "https://fastly.jsdelivr.net/gh/nezhahq/nezha/" | grep "option\.value" | awk -F "'" '{print $2}' | sed 's/nezhahq\/nezha@/v/g')
        fi
        if [ -z "$_version" ]; then
            _version=$(curl -m 10 -sL "https://gcore.jsdelivr.net/gh/nezhahq/nezha/" | grep "option\.value" | awk -F "'" '{print $2}' | sed 's/nezhahq\/nezha@/v/g')
        fi
        if [ -z "$_version" ]; then
            _version=$(curl -m 10 -sL "https://gitee.com/api/v5/repos/naibahq/nezha/releases/latest" | awk -F '"' '{for(i=1;i<=NF;i++){if($i=="tag_name"){print $(i+2)}}}')
        fi
        RELEASE_LATEST=$_version
    fi

    if [ -z "$RELEASE_LATEST" ]; then
        err "获取版本号失败，请检查本机网络连接"
        return 1
    else
        echo "当前最新版本为： ${RELEASE_LATEST}"
    fi
}

get_current_version() {
    if [ -f "${NZ_DASHBOARD_PATH}/VERSION" ]; then
        CURRENT_VERSION=$(cat ${NZ_DASHBOARD_PATH}/VERSION)
    else
        CURRENT_VERSION=""
    fi
}

freebsd_generate_config() {
    echo "关于 Gitee Oauth2 应用：在 https://gitee.com/oauth/applications 创建，无需审核，Callback 填 http(s)://域名或IP/oauth2/callback"
    printf "请输入 OAuth2 提供商(github/gitlab/jihulab/gitee，默认 github): "
    read -r nz_oauth2_type
    printf "请输入 Oauth2 应用的 Client ID: "
    read -r nz_github_oauth_client_id
    printf "请输入 Oauth2 应用的 Client Secret: "
    read -r nz_github_oauth_client_secret
    printf "请输入 GitHub/Gitee 登录名作为管理员，多个以逗号隔开: "
    read -r nz_admin_logins
    printf "请输入站点标题: "
    read -r nz_site_title
    printf "请输入站点访问端口: "
    read -r nz_site_port
    printf "请输入用于 Agent 接入的 RPC 端口: "
    read -r nz_grpc_port

    if [ -z "$nz_admin_logins" ] || [ -z "$nz_github_oauth_client_id" ] || [ -z "$nz_github_oauth_client_secret" ] || [ -z "$nz_site_title" ] || [ -z "$nz_site_port" ] || [ -z "$nz_grpc_port" ]; then
        err "错误! 所有选项都不能为空"
        return 1
    fi

    if [ -z "$nz_oauth2_type" ]; then
        nz_oauth2_type=github
    fi
    
    wget -O ${NZ_DASHBOARD_PATH}/data/config.yaml "https://raw.githubusercontent.com/naiba/nezha/master/script/config.yaml"

    if [ "$IS_FREEBSD" = 1 ]; then
        # FreeBSD使用sed -i ''
        sed -i '' "s/nz_oauth2_type/${nz_oauth2_type}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i '' "s/nz_admin_logins/${nz_admin_logins}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i '' "s/nz_grpc_port/${nz_grpc_port}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i '' "s/nz_github_oauth_client_id/${nz_github_oauth_client_id}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i '' "s/nz_github_oauth_client_secret/${nz_github_oauth_client_secret}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i '' "s/nz_language/zh-CN/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i '' "s/nz_site_title/${nz_site_title}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i '' "s/80/${nz_site_port}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
    else
        # Linux使用sed -i
        sed -i "s/nz_oauth2_type/${nz_oauth2_type}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i "s/nz_admin_logins/${nz_admin_logins}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i "s/nz_grpc_port/${nz_grpc_port}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i "s/nz_github_oauth_client_id/${nz_github_oauth_client_id}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i "s/nz_github_oauth_client_secret/${nz_github_oauth_client_secret}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i "s/nz_language/zh-CN/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i "s/nz_site_title/${nz_site_title}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
        sed -i "s/80/${nz_site_port}/" ${NZ_DASHBOARD_PATH}/data/config.yaml
    fi
}

linux_generate_config() {
    printf "请输入站点标题: "
    read -r nz_site_title
    printf "请输入暴露端口: (默认 8008)"
    read -r nz_port
    printf "请指定安装命令中预设的 nezha-agent 连接地址 （例如 example.com:443）"
    read -r nz_hostport
    printf "是否希望通过 TLS 连接 Agent？（影响安装命令）[y/N]"
    read -r input
    case $input in
    [yY][eE][sS] | [yY])
        nz_tls=true
        ;;
    [nN][oO] | [nN])
        nz_tls=false
        ;;
    *)
        nz_tls=false
        ;;
    esac
    println "请指定后台语言"
    println "1. 中文（简体）"
    println "2. 中文（台灣）"
    println "3. English"
    while true; do
        printf "请输入选项 [1-3]"
        read -r option
        case "${option}" in
            1)
                nz_lang=zh_CN
                break
                ;;
            2)
                nz_lang=zh_TW
                break
                ;;
            3)
                nz_lang=en_US
                break
                ;;
            *)
                err "请输入正确的选项 [1-3]"
                ;;
        esac
    done

    if [ -z "$nz_lang" ] || [ -z "$nz_site_title" ] || [ -z "$nz_hostport" ]; then
        err "所有选项都不能为空"
        before_show_menu
        return 1
    fi

    if [ -z "$nz_port" ]; then
        nz_port=8008
    fi

    _cmd="wget -t 2 -T 60 -O /tmp/nezha-config.yaml https://gitee.com/naibahq/scripts/raw/main/extras/config.yaml >/dev/null 2>&1"
    if ! eval "$_cmd"; then
        err "脚本获取失败，请检查本机能否链接 gitee.com"
        return 0
    fi

    sed -i "s/nz_port/${nz_port}/" /tmp/nezha-config.yaml
    sed -i "s/nz_language/${nz_lang}/" /tmp/nezha-config.yaml
    sed -i "s/nz_site_title/${nz_site_title}/" /tmp/nezha-config.yaml
    sed -i "s/nz_hostport/${nz_hostport}/" /tmp/nezha-config.yaml
    sed -i "s/nz_tls/${nz_tls}/" /tmp/nezha-config.yaml

    mkdir -p $NZ_DASHBOARD_PATH/data
    mv -f /tmp/nezha-config.yaml ${NZ_DASHBOARD_PATH}/data/config.yaml
}

generate_start_script() {
    # 创建启动脚本
    if [ "$IS_FREEBSD" = 1 ]; then
        cat > ${NZ_DASHBOARD_PATH}/start.sh << EOF
#!/bin/sh
pgrep -f 'dashboard' | xargs -r kill
cd ${NZ_DASHBOARD_PATH}
exec ${NZ_DASHBOARD_PATH}/dashboard >/dev/null 2>&1
EOF
    else
        cat > ${NZ_DASHBOARD_PATH}/start.sh << EOF
#!/bin/sh
pgrep -f '${NZ_DASHBOARD_PATH}/app' | xargs -r kill
cd ${NZ_DASHBOARD_PATH}
exec ${NZ_DASHBOARD_PATH}/app >/dev/null 2>&1
EOF
    fi
    chmod +x ${NZ_DASHBOARD_PATH}/start.sh
}

download_dashboard() {
    if [ "$IS_FREEBSD" = 1 ]; then
        # FreeBSD版本
        TMP_DIRECTORY="$(mktemp -d)"
        INSTALLER_FILE="${TMP_DIRECTORY}/dashboard"
        
        DOWNLOAD_LINK="https://github.com/wansyu/nezha-freebsd/releases/latest/download/dashboard"
        
        if ! wget -qO "$INSTALLER_FILE" "$DOWNLOAD_LINK"; then
            err "下载失败！请检查您的网络或稍后再试。"
            return 1
        fi
        
        curl -s https://api.github.com/repos/wansyu/nezha-freebsd/releases/latest | jq -r '.tag_name' > ${NZ_DASHBOARD_PATH}/VERSION
        
        install -m 755 ${TMP_DIRECTORY}/dashboard ${NZ_DASHBOARD_PATH}/dashboard
        rm -rf "$TMP_DIRECTORY"
    else
        # 原版下载方式
        if [ -z "$CN" ]; then
            NZ_DASHBOARD_URL="https://github.com/nezhahq/nezha/releases/download/${RELEASE_LATEST}/dashboard-linux-${os_arch}.zip"
        else
            NZ_DASHBOARD_URL="https://gitee.com/naibahq/nezha/releases/download/${RELEASE_LATEST}/dashboard-linux-${os_arch}.zip"
        fi

        # 下载并解压
        mkdir -p $NZ_DASHBOARD_PATH
        wget -qO $NZ_DASHBOARD_PATH/app.zip "$NZ_DASHBOARD_URL" >/dev/null 2>&1
        if [ -f "$NZ_DASHBOARD_PATH/app.zip" ]; then
            unzip -qq -o $NZ_DASHBOARD_PATH/app.zip -d $NZ_DASHBOARD_PATH
            dashboard_file="$NZ_DASHBOARD_PATH/dashboard-linux-$os_arch"
            if [ -f "$dashboard_file" ]; then
                mv "$dashboard_file" $NZ_DASHBOARD_PATH/app
                chmod +x $NZ_DASHBOARD_PATH/app
                rm -f $NZ_DASHBOARD_PATH/app.zip
                echo "$RELEASE_LATEST" > ${NZ_DASHBOARD_PATH}/VERSION
            else
                err "解压失败，未找到文件 $dashboard_file"
                return 1
            fi
        else
            err "下载失败，未找到文件 $NZ_DASHBOARD_PATH/app.zip"
            return 1
        fi
    fi
    return 0
}

start_dashboard() {
    # 先停止已运行的面板
    if [ "$IS_FREEBSD" = 1 ]; then
        ps_pid=$(ps -ef | grep "$NZ_DASHBOARD_PATH/dashboard" | grep -v grep | awk '{print $2}')
    else
        ps_pid=$(ps -ef | grep "$NZ_DASHBOARD_PATH/app" | grep -v grep | awk '{print $2}')
    fi
    
    if [ -n "$ps_pid" ]; then
        kill -9 "$ps_pid" || true
    fi
    
    # 启动面板
    nohup ${NZ_DASHBOARD_PATH}/start.sh >/dev/null 2>&1 &
    
    # 检查启动状态
    sleep 3
    if [ "$IS_FREEBSD" = 1 ]; then
        if pgrep -f "dashboard" > /dev/null; then
            # 尝试获取IP地址，FreeBSD可能需要特定命令
            IP_ADDRESS=$(hostname -I 2>/dev/null | awk '{print $1}' || ifconfig | grep -E 'inet.[0-9]' | grep -v '127.0.0.1' | awk '{print $2}')
            success "哪吒面板已启动成功！"
            if [ -n "$nz_site_port" ]; then
                info "请访问 http://${IP_ADDRESS}:${nz_site_port} 进行配置"
            else
                info "请访问 http://${IP_ADDRESS}:8008 进行配置"
            fi
            return 0
        else
            err "面板启动失败，请检查配置是否正确"
            return 1
        fi
    else
        if pgrep -f "$NZ_DASHBOARD_PATH/app" > /dev/null; then
            IP_ADDRESS=$(hostname -I 2>/dev/null | awk '{print $1}' || ifconfig | grep -E 'inet.[0-9]' | grep -v '127.0.0.1' | awk '{print $2}')
            success "哪吒面板已启动成功！"
            if [ -n "$nz_port" ]; then
                info "请访问 http://${IP_ADDRESS}:${nz_port} 进行配置"
            else
                info "请访问 http://${IP_ADDRESS}:8008 进行配置"
            fi
            return 0
        else
            err "面板启动失败，请检查配置是否正确"
            return 1
        fi
    fi
}

install() {
    clear
    echo ""
    echo "${green}安装哪吒监控面板${plain}"
    echo ""
    echo ""

    # 创建基础目录
    mkdir -p $NZ_DASHBOARD_PATH/data
    
    # 生成配置文件
    if [ "$IS_FREEBSD" = 1 ]; then
        freebsd_generate_config
    else
        linux_generate_config
    fi
    
    # 获取最新版本
    get_latest_version
    
    # 下载面板
    echo "${blue}>> 正在下载面板...${plain}"
    download_dashboard
    
    # 创建启动脚本
    echo "${blue}>> 正在创建启动脚本...${plain}"
    generate_start_script
    
    # 启动面板
    echo "${blue}>> 正在启动面板...${plain}"
    start_dashboard
    
    if [ $# = 0 ]; then
        before_show_menu
    fi
}

update() {
    echo ""
    echo "${green}更新哪吒面板${plain}"
    echo ""
    echo ""
    
    # 获取当前版本和最新版本
    get_current_version
    get_latest_version
    
    # 检查是否需要更新
    if [ "${RELEASE_LATEST}" = "${CURRENT_VERSION}" ]; then
        info "当前已是最新版本 ${CURRENT_VERSION}，无需更新"
        before_show_menu
        return 0
    fi
    
    echo "${blue}>> 正在下载最新版本...${plain}"
    # 下载并安装最新版本
    download_dashboard
    
    echo "${blue}>> 正在重启面板...${plain}"
    # 重启面板
    start_dashboard
    
    if [ $# = 0 ]; then
        before_show_menu
    fi
}

uninstall() {
    echo ""
    echo "${green}卸载哪吒面板${plain}"
    echo ""
    echo ""

    warn "警告：卸载前请备份您的文件。"
    printf "继续？ [y/N] "
    read -r input
    case $input in
    [yY][eE][sS] | [yY])
        info "卸载中…"
        ;;
    *)
        info "已取消卸载"
        before_show_menu
        return 0
        ;;
    esac

    # 停止服务
    if [ "$IS_FREEBSD" = 1 ]; then
        ps_pid=$(ps -ef | grep "$NZ_DASHBOARD_PATH/dashboard" | grep -v grep | awk '{print $2}')
    else
        ps_pid=$(ps -ef | grep "$NZ_DASHBOARD_PATH/app" | grep -v grep | awk '{print $2}')
    fi
    
    if [ -n "$ps_pid" ]; then
        echo "${blue}>> 正在停止服务...${plain}"
        kill -9 "$ps_pid" || true
    fi

    # 删除文件
    echo "${blue}>> 正在删除文件...${plain}"
    rm -rf $NZ_DASHBOARD_PATH
    success "哪吒面板已成功卸载"

    if [ $# = 0 ]; then
        before_show_menu
    fi
}

show_log() {
    echo ""
    echo "${green}查看哪吒面板日志${plain}"
    echo "$"
    echo ""

    # 根据系统类型获取日志
    if [ "$IS_FREEBSD" = 1 ]; then
        if [ -f "$NZ_DASHBOARD_PATH/dashboard.log" ]; then
            echo "${blue}>> 最近50行日志内容：${plain}"
            echo ""
            tail -n 50 "$NZ_DASHBOARD_PATH/dashboard.log"
            echo ""
        else
            echo "${yellow}未找到日志文件，请检查服务是否正在运行${plain}"
        fi
    else
        if [ -f "$NZ_DASHBOARD_PATH/dashboard.log" ]; then
            echo "${blue}>> 最近50行日志内容：${plain}"
            echo ""
            tail -n 50 "$NZ_DASHBOARD_PATH/dashboard.log"
            echo ""
        else
            echo "${yellow}未找到日志文件，请检查服务是否正在运行${plain}"
        fi
    fi

    if [ $# = 0 ]; then
        before_show_menu
    fi
}

# 添加两个函数：停止面板和清理进程
stop_dashboard() {
    echo ""
    echo "${green}停止哪吒监控面板${plain}"
    echo ""
    echo ""
    
    if [ "$IS_FREEBSD" = 1 ]; then
        ps_pid=$(ps -ef | grep "$NZ_DASHBOARD_PATH/dashboard" | grep -v grep | awk '{print $2}')
    else
        ps_pid=$(ps -ef | grep "$NZ_DASHBOARD_PATH/app" | grep -v grep | awk '{print $2}')
    fi
    
    if [ -n "$ps_pid" ]; then
        echo "${blue}>> 正在停止哪吒面板进程...${plain}"
        kill -9 "$ps_pid" || true
        success "哪吒面板已停止运行"
    else
        info "哪吒面板未在运行"
    fi
    
    if [ $# = 0 ]; then
        before_show_menu
    fi
}

cleanup_processes() {
    echo ""
    echo "${green}清理哪吒监控进程${plain}"
    echo "${gray}────────────────────────────────────────────────${plain}"
    echo ""
    
    # 查找所有与哪吒面板相关的进程
    if [ "$IS_FREEBSD" = 1 ]; then
        ps_pids=$(ps -ef | grep -E 'nezha|dashboard' | grep -v grep | grep -v "$0" | awk '{print $2}')
    else
        ps_pids=$(ps -ef | grep -E 'nezha|app' | grep -v grep | grep -v "$0" | awk '{print $2}')
    fi
    
    if [ -n "$ps_pids" ]; then
        echo "${yellow}发现以下进程需要清理：${plain}"
        echo "${gray}────────────────────────────────────────────────${plain}"
        if [ "$IS_FREEBSD" = 1 ]; then
            ps -ef | grep -E 'nezha|dashboard' | grep -v grep | grep -v "$0"
        else
            ps -ef | grep -E 'nezha|app' | grep -v grep | grep -v "$0"
        fi
        echo "${gray}────────────────────────────────────────────────${plain}"
        
        echo "${blue}>> 正在清理进程...${plain}"
        for pid in $ps_pids; do
            echo "${gray}终止进程 PID: $pid${plain}"
            kill -9 "$pid" 2>/dev/null || true
        done
        success "进程清理完成"
    else
        info "未发现需要清理的进程"
    fi
    
    if [ $# = 0 ]; then
        before_show_menu
    fi
}

# 修改show_menu函数，使用更简单的ASCII艺术标志
show_menu() {
    clear
    echo ""
    echo "${cyan}    _   __          __              __  ___           _ __            ${plain}"
    echo "${cyan}   / | / /__  ____ / /_  ____ _   /  |/  /___  ____  (_) /_____  _____${plain}"
    echo "${cyan}  /  |/ / _ \\/_  // __ \\/ __ \\\`/  / /|_/ / __ \\/ __ \\/ / __/ __ \\/ ___/${plain}"
    echo "${cyan} / /|  /  __/ / // / / / /_/ /  / /  / / /_/ / / / / / /_/ /_/ / /    ${plain}"
    echo "${cyan}/_/ |_/\\___/ /___/_/ /_/\\__,_/  /_/  /_/\\____/_/ /_/_/\\__/\\____/_/     ${plain}"
    echo ""
    echo "${green}哪吒监控管理脚本 ${white}v2.0 ${orange}(FreeBSD兼容版)${plain}"
    echo "${blue}系统: ${white}$(uname -s) ${blue}架构: ${white}$(uname -m)${plain}"
    echo "${green}● 基础功能${plain}"
    printf "${light_green}%2s.${plain} ${white}%-42s${plain}\n" "1" "安装面板端"
    printf "${light_green}%2s.${plain} ${white}%-42s${plain}\n" "2" "修改面板配置"
    printf "${light_green}%2s.${plain} ${white}%-42s${plain}\n" "3" "重启并更新面板"
    echo "${orange}● 运维管理${plain}"
    printf "${light_green}%2s.${plain} ${white}%-42s${plain}\n" "4" "查看面板日志"
    printf "${light_green}%2s.${plain} ${white}%-42s${plain}\n" "5" "卸载管理面板"
    printf "${light_green}%2s.${plain} ${white}%-42s${plain}\n" "6" "更新脚本"
    printf "${light_green}%2s.${plain} ${white}%-42s${plain}\n" "7" "停止面板"
    printf "${light_green}%2s.${plain} ${white}%-42s${plain}\n" "8" "清理面板进程"
    printf "${red}%2s.${plain} ${white}%-42s${plain}\n" "0" "退出脚本"
    echo "${gray}项目地址: ${underline}https://github.com/nezhahq/nezha${plain}"
    echo ""
    printf "${cyan}请输入选择 [0-8]:${plain} "
    read -r num
    case "${num}" in
        0)
            echo "${red}已退出脚本${plain}"
            exit 0
            ;;
        1)
            install
            ;;
        2)
            if [ "$IS_FREEBSD" = 1 ]; then
                freebsd_generate_config
            else
                linux_generate_config
            fi
            ;;
        3)
            update
            ;;
        4)
            show_log
            ;;
        5)
            uninstall
            ;;
        6)
            update_script
            ;;
        7)
            stop_dashboard
            ;;
        8)
            cleanup_processes
            ;;
        *)
            err "请输入正确的数字 [0-8]"
            ;;
    esac
}

# 更新用法说明，简化界面
show_usage() {
    echo "${light_green}哪吒监控 管理脚本使用方法${plain}"  
    echo ""
    printf "${white}%-53s${plain}\n" "./nezha-freebsd.sh                    - 显示管理菜单"
    printf "${white}%-53s${plain}\n" "./nezha-freebsd.sh install            - 安装面板端"
    printf "${white}%-53s${plain}\n" "./nezha-freebsd.sh modify_config      - 修改面板配置"
    printf "${white}%-53s${plain}\n" "./nezha-freebsd.sh restart_and_update - 重启并更新面板"
    printf "${white}%-53s${plain}\n" "./nezha-freebsd.sh show_log           - 查看面板日志"
    printf "${white}%-53s${plain}\n" "./nezha-freebsd.sh uninstall          - 卸载管理面板"
    printf "${white}%-53s${plain}\n" "./nezha-freebsd.sh stop               - 停止面板"
    printf "${white}%-53s${plain}\n" "./nezha-freebsd.sh cleanup            - 清理面板进程"
    echo ""
}

update_script() {
    echo ""
    echo "${green}更新哪吒监控脚本${plain}"
    echo ""

    echo "${blue}>> 正在下载最新脚本...${plain}"
    curl -sL "https://${GITHUB_RAW_URL:-raw.githubusercontent.com/nezhahq/scripts/main}/install.sh" -o /tmp/nezha.sh
    mv -f /tmp/nezha.sh ./nezha-freebsd.sh && chmod a+x ./nezha-freebsd.sh

    echo ""
    echo "${light_green}>> 脚本更新成功，3秒后执行新脚本...${plain}"
    sleep 3s
    clear
    exec ./nezha-freebsd.sh
    exit 0
}

init

if [ $# -gt 0 ]; then
    case $1 in
        "install")
            install 0
            ;;
        "modify_config")
            if [ "$IS_FREEBSD" = 1 ]; then
                freebsd_generate_config 0
            else
                linux_generate_config 0
            fi
            ;;
        "restart_and_update")
            update 0
            ;;
        "show_log")
            show_log 0
            ;;
        "uninstall")
            uninstall 0
            ;;
        "update_script")
            update_script 0
            ;;
        "stop")
            stop_dashboard 0
            ;;
        "cleanup")
            cleanup_processes 0
            ;;
        *) show_usage ;;
    esac
else
    show_menu
fi 