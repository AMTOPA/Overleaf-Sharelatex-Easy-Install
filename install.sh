#!/bin/bash
# OVERSEI Installer v4.0
# GitHub: https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install

# ASCII Art and Colors
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; CYAN='\033[1;36m'; NC='\033[0m'

cat << "EOF"
 ██████╗ ██╗   ██╗███████╗██████╗ ███████╗███████╗██╗
██╔═══██╗██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝██║
██║   ██║██║   ██║█████╗  ██████╔╝███████╗█████╗  ██║
██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════██║██╔══╝  ██║
╚██████╔╝ ╚████╔╝ ███████╗██║  ██║███████║███████╗██║
 ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝
EOF

echo -e "${CYAN}:: OVERSEI - Overleaf/ShareLaTeX Easy Installer ::${NC}\n"

# Check root
[ "$(id -u)" != "0" ] && echo -e "${RED}✗ 请使用root用户运行!${NC}" && exit 1

# Paths
INSTALL_DIR="/root/overleaf"
TOOLKIT_DIR="$INSTALL_DIR/overleaf-toolkit"

# Main Menu
show_menu() {
    echo -e "${BLUE}选择安装选项:${NC}"
    options=(
        "完整安装 (基础服务+中文支持+常用字体)"
        "仅安装基础服务"
        "安装中文支持包"
        "安装额外字体包"
        "退出"
    )
    select opt in "${options[@]}"; do
        case $REPLY in
            1) install_base; install_chinese; install_fonts ;;
            2) install_base ;;
            3) install_chinese ;;
            4) install_fonts ;;
            5) exit 0 ;;
            *) echo -e "${RED}无效选项!${NC}";;
        esac
        break
    done
}

# Core Functions
install_base() {
    echo -e "\n${YELLOW}▶ 正在安装基础服务...${NC}"
    
    mkdir -p $INSTALL_DIR && cd $INSTALL_DIR
    git clone https://github.com/overleaf/toolkit.git overleaf-toolkit || {
        echo -e "${RED}✗ 克隆失败!${NC}"; exit 1
    }

    cd $TOOLKIT_DIR
    bin/init

    # Essential configs
    sed -i \
        -e 's/^OVERLEAF_LISTEN_IP=.*/OVERLEAF_LISTEN_IP=0.0.0.0/' \
        -e 's/^OVERLEAF_PORT=.*/OVERLEAF_PORT=8888/' \
        -e 's/^MONGO_VERSION=.*/MONGO_VERSION=4.4/' \
        config/overleaf.rc

    echo -e "${GREEN}✓ 启动服务中...${NC}"
    bin/up -d && sleep 30
    echo -e "${GREEN}✓ 安装完成! 访问: http://your-server-ip:8888${NC}"
}

install_chinese() {
    echo -e "\n${YELLOW}▶ 安装中文支持...${NC}"
    docker exec sharelatex bash -c '
        tlmgr install collection-langchinese xecjk ctex
        mkdir -p /usr/share/fonts/chinese
        wget -qO /tmp/simsun.ttc "https://example.com/simsun.ttc"
        wget -qO /tmp/simkai.zip "https://example.com/simkai.zip"
        unzip /tmp/simkai.zip -d /usr/share/fonts/chinese/
        fc-cache -fv
    ' && echo -e "${GREEN}✓ 中文支持已安装!${NC}"
}

install_fonts() {
    echo -e "\n${YELLOW}▶ 字体安装选项:${NC}"
    PS3="请选择字体包: "
    options=(
        "Windows核心字体"
        "Adobe全家桶" 
        "思源字体"
        "返回"
    )
    select opt in "${options[@]}"; do
        case $REPLY in
            1) docker exec sharelatex apt install -y ttf-mscorefonts-installer ;;
            2) docker exec sharelatex apt install -y fonts-adobe-* ;;
            3) docker exec sharelatex apt install -y fonts-noto-cjk ;;
            4) break ;;
            *) echo -e "${RED}无效选择!${NC}";;
        esac
        fc-cache -fv
        break
    done
}

# Main Flow
check_dependencies() {
    for cmd in docker git unzip; do
        if ! command -v $cmd &>/dev/null; then
            echo -e "${RED}✗ 缺少依赖: $cmd${NC}"
            exit 1
        fi
    done
}

check_dependencies
show_menu