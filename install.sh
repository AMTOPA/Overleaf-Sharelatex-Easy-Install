#!/bin/bash
# OVERSEI Installer v5.1
# GitHub: https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install  

# 发送 API 计数请求（静默模式，不影响脚本执行）
curl -s "https://js.ruseo.cn/api/counter.php?api_key=3976bd1973c3c40ee8c2f7f4a12b059b&action=increment&counter_id=0bc7f9e8ed200173dc9205089c2d3036&value=1" >/dev/null 2>&1 &

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

# Ask for deployment type
echo -e "${BLUE}选择部署类型:${NC}"
select deployment in "本地部署" "服务器部署"; do
    case $deployment in
        "本地部署") 
            ACCESS_URL="http://localhost:8888"
            LISTEN_IP="127.0.0.1"
            break ;;
        "服务器部署") 
            PUBLIC_IP=$(curl -s ifconfig.me)
            ACCESS_URL="http://${PUBLIC_IP}:8888"
            LISTEN_IP="0.0.0.0"
            break ;;
        *) echo -e "${RED}无效选项!${NC}" ;;
    esac
done

# Paths
INSTALL_DIR="/root/overleaf"
TOOLKIT_DIR="$INSTALL_DIR/overleaf-toolkit"

# Main Menu
show_menu() {
    echo -e "${BLUE}选择安装选项:${NC}"
    options=(
        "完整安装 (基础服务+中文支持+常用字体+宏包)"
        "仅安装基础服务"
        "安装中文支持包"
        "安装额外字体包"
        "安装LaTeX宏包"
        "退出"
    )
    select opt in "${options[@]}"; do
        case $REPLY in
            1) install_base; install_chinese; install_fonts; install_packages ;;
            2) install_base ;;
            3) install_chinese ;;
            4) install_fonts ;;
            5) install_packages ;;
            6) exit 0 ;;
            *) echo -e "${RED}无效选项!${NC}";;
        esac
        break
    done
}

# Core Functions
install_base() {
    echo -e "\n${YELLOW}▶ 正在安装基础服务...${NC}"
    
    # Check and install dependencies
    for cmd in docker git unzip; do
        if ! command -v $cmd &>/dev/null; then
            echo -e "${YELLOW}▶ 安装依赖: $cmd...${NC}"
            apt-get update && apt-get install -y $cmd || {
                echo -e "${RED}✗ 安装 $cmd 失败!${NC}"; exit 1
            }
        fi
    done

    mkdir -p $INSTALL_DIR && cd $INSTALL_DIR
    if [ ! -d "$TOOLKIT_DIR" ]; then
        git clone https://github.com/overleaf/toolkit.git overleaf-toolkit || {
            echo -e "${RED}✗ 克隆失败!${NC}"; exit 1
        }
    else
        echo -e "${GREEN}✓ 已存在 overleaf-toolkit，跳过克隆${NC}"
    fi

    cd $TOOLKIT_DIR
    bin/init

    # Essential configs
    sed -i \
        -e "s/^OVERLEAF_LISTEN_IP=.*/OVERLEAF_LISTEN_IP=${LISTEN_IP}/" \
        -e 's/^OVERLEAF_PORT=.*/OVERLEAF_PORT=8888/' \
        -e 's/^MONGO_VERSION=.*/MONGO_VERSION=6.0/' \
        config/overleaf.rc

    echo -e "${GREEN}✓ 启动服务中...${NC}"
    bin/up -d && sleep 30
    echo -e "${GREEN}✓ 基础服务安装完成! 访问: ${ACCESS_URL}${NC}"
}

install_chinese() {
    echo -e "\n${YELLOW}▶ 安装中文支持...${NC}"
    if ! docker exec sharelatex tlmgr --version &>/dev/null; then
        echo -e "${RED}✗ sharelatex 容器未运行或 tlmgr 不可用!${NC}"
        return 1
    fi

    docker exec sharelatex bash -c '
        tlmgr install collection-langchinese xecjk ctex || exit 1
        mkdir -p /usr/share/fonts/chinese
        wget -O /usr/share/fonts/chinese/simsun.ttc "https://github.com/jiaxiaochu/font/raw/master/simsun.ttc" || true
        wget -O /usr/share/fonts/chinese/simkai.ttf "https://github.com/jiaxiaochu/font/raw/master/simkai.ttf" || true
        fc-cache -fv
    ' && echo -e "${GREEN}✓ 中文支持已安装!${NC}" || {
        echo -e "${RED}✗ 中文支持安装失败!${NC}"
    }
}

install_fonts() {
    echo -e "\n${YELLOW}▶ 字体安装选项:${NC}"
    PS3="请选择字体包: "
    options=(
        "Windows核心字体"
        "Adobe字体" 
        "思源字体"
        "返回"
    )
    select opt in "${options[@]}"; do
        case $REPLY in
            1) 
                docker exec sharelatex bash -c "apt-get update && apt-get install -y ttf-mscorefonts-installer" ;;
            2) 
                docker exec sharelatex bash -c "apt-get update && apt-get install -y fonts-adobe-*" ;;
            3) 
                docker exec sharelatex bash -c "apt-get update && apt-get install -y fonts-noto-cjk" ;;
            4) break ;;
            *) echo -e "${RED}无效选择!${NC}"; continue ;;
        esac
        docker exec sharelatex fc-cache -fv
        echo -e "${GREEN}✓ 字体缓存已刷新${NC}"
        break
    done
}

# New: Install LaTeX Packages
install_packages() {
    echo -e "\n${YELLOW}▶ 开始安装 LaTeX 宏包...${NC}"

    # Check if container is running
    if ! docker ps | grep -q sharelatex; then
        echo -e "${RED}✗ sharelatex 容器未运行，请先启动基础服务!${NC}"
        return 1
    fi

    # Ensure tlmgr is ready
    echo -e "${YELLOW}▶ 正在准备 tlmgr...${NC}"
    docker exec sharelatex bash -c "tlmgr update --self || true" > /dev/null 2>&1

    # Choose mirror
    echo -e "${BLUE}请选择 CTAN 镜像源:${NC}"
    select mirror in "官方源 (CTAN)" "清华源 (mirrors.tuna.tsinghua.edu.cn/tex-archive)"; do
        case $REPLY in
            1) MIRROR=""; break ;;
            2) 
                docker exec sharelatex tlmgr option repository http://mirrors.tuna.tsinghua.edu.cn/tex-archive/;
                echo -e "${GREEN}✓ 已切换至清华镜像源${NC}"
                break ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
    done

    # Choose package type
    echo -e "${BLUE}选择宏包安装模式:${NC}"
    select pkg_type in "全部宏包 (scheme-full, 约 4GB+)" "常用数学宏包 (amsmath, geometry 等)" "自定义宏包 (手动输入名称)"; do
        case $REPLY in
            1)
                echo -e "${YELLOW}▶ 开始安装 scheme-full (可能耗时较长，请耐心等待)...${NC}"
                docker exec sharelatex tlmgr install scheme-full && \
                    echo -e "${GREEN}✓ 全部宏包安装完成!${NC}" || \
                    echo -e "${RED}✗ 安装失败，可能是磁盘空间不足或网络问题${NC}"
                break
                ;;
            2)
                # 推荐数学与常用宏包
                COMMON_PKGS="
                amsmath amssymb mathtools bm physics graphicx
                geometry fancyhdr enumitem titlesec hyperref
                booktabs caption float listings algorithm algpseudocode
                xcolor soul tikz-cd mhchem wrapfig subcaption
                "
                echo -e "${YELLOW}▶ 正在安装常用数学及排版宏包...${NC}"
                docker exec sharelatex tlmgr install $COMMON_PKGS && \
                    echo -e "${GREEN}✓ 常用宏包安装完成!${NC}" || \
                    echo -e "${RED}✗ 部分宏包安装失败${NC}"
                break
                ;;
            3)
                echo -e "${YELLOW}请输入要安装的宏包名称（空格分隔，如：gbt7714 mhchem）:${NC}"
                read -r -p "宏包列表: " CUSTOM_PKGS
                [ -z "$CUSTOM_PKGS" ] && echo -e "${YELLOW}→ 未输入宏包，跳过${NC}" && return 0

                echo -e "${YELLOW}▶ 正在安装自定义宏包: $CUSTOM_PKGS${NC}"
                docker exec sharelatex tlmgr install $CUSTOM_PKGS && \
                    echo -e "${GREEN}✓ 自定义宏包安装完成: $CUSTOM_PKGS${NC}" || \
                    echo -e "${RED}✗ 安装失败，请检查宏包名称是否正确${NC}"
                break
                ;;
            *)
                echo -e "${RED}无效选择!${NC}"
                ;;
        esac
    done
}

# Main Flow
show_menu
