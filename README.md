# 哪吒探针VPS服务器一键部署脚本

<div align="center">
  <br/>
  <b>简单易用的自托管服务器监控和探针脚本</b>
  <br/>
  <b>适用于共享虚拟主机、VPS等环境</b>
</div>

## 🚀 功能特点

- 🔄 自动下载最新版本的哪吒探针 agent
- 🌐 支持 WebSocket 模式，轻松穿透防火墙
- 🔍 自动检测系统环境，选择匹配的探针版本
- 🛠️ 提供完善的脚本管理功能（启动、停止、重启）
- 🎨 美观的安装界面，提供详细的安装日志

## ⚙️ 系统要求

- Linux 操作系统
- 支持的架构：`x86_64`、`i386`、`arm64`、`arm`、`freebsd`
- 依赖项：`wget`、`unzip`、`grep`

## 📥 快速开始

### 1. 准备工作

首先，你需要一个已经搭建好的哪吒监控面板，或者使用公共的哪吒监控面板。

如果没有，可以参考以下资源：
- [官方面板](https://github.com/nezhahq/nezha) (请注意公共面板可能有使用限制)

### 2. 安装脚本

```bash
# 下载安装脚本
wget -O install.sh https://raw.githubusercontent.com/mobil2723/nezha/main/install.sh

# 添加执行权限
chmod +x install.sh
```

### 3. 修改脚本中的配置文件
```json
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
```
> ⚠️ **注意**：你需要修改的主要是两项内容：
> - **`"server": "服务器IP:端口"`** ⬅️ 替换为你的哪吒面板地址和端口
> - **`"client_secret": "agent_secret_key"`** ⬅️ 替换为你从面板获取的密钥


### 4. 安装哪吒探针
```bash
bash install.sh
```



### 管理哪吒探针

安装完成后，可以使用以下命令管理哪吒探针：

```bash
# 启动服务
./nezha/start.sh

# 停止服务
./nezha/stop.sh

# 查看日志
tail -f ./nezha/logs/nezha-agent.log
```

