#!/bin/bash
# OVERSEI Installer v5.3
# GitHub: https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install  

# 发送 API 计数请求（静默模式，不影响脚本执行）
curl -s "https://js.ruseo.cn/api/counter.php?api_key=3976bd1973c3c40ee8c2f7f4a12b059b&action=increment&counter_id=0bc7f9e8ed200173dc9205089c2d3036&value=1" >/dev/null 2>&1 &

# ASCII Art and Colors
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; CYAN='\033[1;36m'; NC='\033[0m'
MIN_MONGO_VERSION="8.0"
DEFAULT_MONGO_VERSION="8.0"

version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]
}

get_latest_mongo_version() {
    local latest_tag
    latest_tag=$(curl -fsSL "https://registry.hub.docker.com/v2/repositories/library/mongo/tags?page_size=100" 2>/dev/null |
        grep -oE '"name":"[0-9]+\.[0-9]+"' |
        cut -d'"' -f4 |
        sort -Vr |
        while read -r tag; do
            if ! version_lt "$tag" "$MIN_MONGO_VERSION"; then
                echo "$tag"
                break
            fi
        done)
    echo "${latest_tag:-$DEFAULT_MONGO_VERSION}"
}

set_rc_value() {
    local key="$1"
    local value="$2"
    local file="$3"

    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >> "$file"
    fi
}

get_container() {
    local exact_name="$1"
    local pattern="$2"
    local name

    name=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "^${exact_name}$" | head -1)
    if [ -z "$name" ] && [ -n "$pattern" ]; then
        name=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "$pattern" | head -1)
    fi

    echo "$name"
}

show_compose_logs() {
    local service="$1"

    if [ -x "bin/docker-compose" ]; then
        bin/docker-compose logs "$service" 2>/dev/null | tail -20
    elif docker compose version &>/dev/null; then
        docker compose logs "$service" 2>/dev/null | tail -20
    elif command -v docker-compose &>/dev/null; then
        docker-compose logs "$service" 2>/dev/null | tail -20
    fi
}

prepare_tlmgr() {
    local container="$1"
    local current_repo="https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet"
    local texlive_year
    local historic_repo

    docker exec "$container" tlmgr option repository "$current_repo" >/dev/null 2>&1 || true
    if docker exec "$container" bash -c 'tlmgr update --self'; then
        return 0
    fi

    texlive_year=$(docker exec "$container" bash -c "tlmgr --version | sed -n 's/^TeX Live .* version \\([0-9][0-9][0-9][0-9]\\).*/\\1/p' | head -1")
    if [ -z "$texlive_year" ]; then
        echo -e "${RED}✗ 无法识别 TeX Live 年份，tlmgr 源配置失败${NC}"
        return 1
    fi

    historic_repo="https://mirrors.tuna.tsinghua.edu.cn/tex-historic-archive/systems/texlive/${texlive_year}/tlnet-final"
    echo -e "${YELLOW}▶ 当前 TeX Live 为 ${texlive_year}，切换到历史归档源避免跨版本错误...${NC}"
    docker exec "$container" tlmgr option repository "$historic_repo" || return 1
    docker exec "$container" bash -c 'tlmgr update --self 2>/dev/null || true'
}

cat << "EOF"
 ██████╗ ██╗   ██╗███████╗██████╗ ███████╗███████╗██╗
██╔═══██╗██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝██║
██║   ██║██║   ██║█████╗  ██████╔╝███████╗█████╗  ██║
██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════██║██╔══╝  ██║
╚██████╔╝ ╚████╔╝ ███████╗██║  ██║███████║███████╗██║
 ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝
EOF

echo -e "${CYAN}:: OVERSEI - Overleaf/ShareLaTeX Easy Installer v5.3 ::${NC}\n"

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

# MongoDB版本选择
echo -e "${BLUE}选择MongoDB版本:${NC}"
echo -e "${YELLOW}注意: Overleaf社区版要求使用${MIN_MONGO_VERSION}+版本${NC}"
select mongo_ver in "最新版 (自动获取Docker Hub最新${MIN_MONGO_VERSION}+稳定版)" "自定义版本 (手动输入版本号)"; do
    case $REPLY in
        1)
            # 尝试获取最新稳定版
            echo -e "${YELLOW}▶ 正在获取MongoDB最新版本...${NC}"
            
            # 尝试多种方法获取最新版本
            LATEST_MONGO="$DEFAULT_MONGO_VERSION"  # 默认值
            
            # 方法1: 从Docker Hub API获取
            if command -v curl &>/dev/null; then
                LATEST_TAG=$(get_latest_mongo_version) || LATEST_TAG=""
                
                if [[ -n "$LATEST_TAG" ]]; then
                    LATEST_MONGO="$LATEST_TAG"
                else
                    # 方法2: 使用简单方法
                    LATEST_MONGO="$DEFAULT_MONGO_VERSION"
                fi
            fi
            
            MONGO_VERSION="$LATEST_MONGO"
            echo -e "${GREEN}✓ 将安装 MongoDB 最新版本: ${MONGO_VERSION}${NC}"
            break
            ;;
        2)
            while true; do
                read -r -p "请输入MongoDB版本号 (如: 8.0, 8.2): " CUSTOM_VER
                if [[ "$CUSTOM_VER" =~ ^[0-9]+\.[0-9]+$ ]]; then
                    # 版本警告
                    if version_lt "$CUSTOM_VER" "$MIN_MONGO_VERSION"; then
                        echo -e "${RED}✗ Overleaf 当前版本要求 MongoDB ${MIN_MONGO_VERSION}+，请重新输入${NC}"
                        continue
                    fi
                    MONGO_VERSION="$CUSTOM_VER"
                    echo -e "${GREEN}✓ 已选择自定义版本: MongoDB ${MONGO_VERSION}${NC}"
                    break
                else
                    echo -e "${RED}✗ 版本号格式错误! 请使用格式: X.X (如: 8.0)${NC}"
                fi
            done
            break
            ;;
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
            1) install_base && install_chinese && install_fonts && install_packages ;;
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
    local MONGO_CONTAINER
    local SHARELATEX_CONTAINER
    
    # Check and install dependencies
    for cmd in docker git unzip curl bc; do
        if ! command -v $cmd &>/dev/null; then
            echo -e "${YELLOW}▶ 安装依赖: $cmd...${NC}"
            apt-get update && apt-get install -y $cmd || {
                echo -e "${RED}✗ 安装 $cmd 失败!${NC}"; exit 1
            }
        fi
    done

    if ! docker compose version &>/dev/null && ! command -v docker-compose &>/dev/null; then
        echo -e "${YELLOW}▶ 安装依赖: docker compose...${NC}"
        apt-get update && (apt-get install -y docker-compose-plugin || apt-get install -y docker-compose) || {
            echo -e "${RED}✗ 安装 docker compose 失败!${NC}"; exit 1
        }
    fi

    # 检查并安装bc（用于版本比较）
    if ! command -v bc &>/dev/null; then
        apt-get install -y bc
    fi

    mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" || exit 1
    if [ ! -d "$TOOLKIT_DIR" ]; then
        git clone https://github.com/overleaf/toolkit.git overleaf-toolkit || {
            echo -e "${RED}✗ 克隆失败!${NC}"; exit 1
        }
    else
        echo -e "${GREEN}✓ 已存在 overleaf-toolkit，跳过克隆${NC}"
    fi

    cd "$TOOLKIT_DIR" || exit 1
    bin/init || {
        echo -e "${RED}✗ overleaf-toolkit 初始化失败!${NC}"; return 1
    }

    if [ ! -f "config/overleaf.rc" ]; then
        echo -e "${RED}✗ 未找到 config/overleaf.rc!${NC}"
        return 1
    fi

    # Essential configs - 使用用户选择的MONGO_VERSION
    echo -e "${GREEN}✓ 设置 MongoDB 版本为: ${MONGO_VERSION}${NC}"
    set_rc_value "OVERLEAF_LISTEN_IP" "$LISTEN_IP" "config/overleaf.rc"
    set_rc_value "OVERLEAF_PORT" "8888" "config/overleaf.rc"
    set_rc_value "MONGO_VERSION" "$MONGO_VERSION" "config/overleaf.rc"

    echo -e "${YELLOW}▶ 启动服务中...${NC}"
    
    bin/up -d || {
        echo -e "${RED}✗ 服务启动失败!${NC}"
        show_compose_logs "mongo"
        show_compose_logs "sharelatex"
        return 1
    }
    
    # 等待服务启动，增加版本检查
    echo -e "${YELLOW}▶ 等待服务启动并检查版本兼容性...${NC}"
    
    # 增加等待时间，确保容器完全启动
    for i in {1..10}; do
        echo -ne "${YELLOW}等待服务启动 ($i/10)...${NC}\r"
        sleep 5
    done
    echo ""
    
    # 检查MongoDB容器是否运行
    MONGO_CONTAINER=$(get_container "mongo" "mongo")
    if [ -n "$MONGO_CONTAINER" ]; then
        echo -e "${GREEN}✓ MongoDB 容器已启动${NC}"
        
        # 检查MongoDB版本
        echo -e "${YELLOW}▶ 正在检查 MongoDB 实际版本...${NC}"
        MONGO_ACTUAL_VER=$(docker exec "$MONGO_CONTAINER" mongod --version 2>/dev/null | grep -oE "v?[0-9]+\.[0-9]+(\.[0-9]+)?" | head -1 | sed 's/^v//' | cut -d. -f1-2)
        if [ -z "$MONGO_ACTUAL_VER" ]; then
            # 尝试另一种版本字符串格式
            MONGO_ACTUAL_VER=$(docker exec "$MONGO_CONTAINER" mongod --version 2>/dev/null | grep -i version | grep -oE "[0-9]+\.[0-9]+(\.[0-9]+)?" | head -1 | cut -d. -f1-2)
        fi
        
        if [ -n "$MONGO_ACTUAL_VER" ]; then
            echo -e "${GREEN}✓ MongoDB 实际运行版本: ${MONGO_ACTUAL_VER}${NC}"
            
            # 版本兼容性检查
            if version_lt "$MONGO_ACTUAL_VER" "$MIN_MONGO_VERSION"; then
                echo -e "${RED}✗ Overleaf 当前版本要求 MongoDB ${MIN_MONGO_VERSION}+${NC}"
                echo -e "${RED}   当前实际版本 ${MONGO_ACTUAL_VER} 不兼容，sharelatex 会中止启动${NC}"
                echo -e "${YELLOW}▶ 正在检查 sharelatex 日志...${NC}"
                show_compose_logs "sharelatex"
                return 1
            else
                echo -e "${GREEN}✓ MongoDB 版本兼容性检查通过${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ 无法获取MongoDB版本信息，但容器正在运行${NC}"
        fi
    else
        echo -e "${RED}✗ MongoDB 容器未运行!${NC}"
        echo -e "${YELLOW}▶ 正在检查日志...${NC}"
        show_compose_logs "mongo"
        return 1
    fi

    SHARELATEX_CONTAINER=$(get_container "sharelatex" "sharelatex")
    if [ -z "$SHARELATEX_CONTAINER" ]; then
        echo -e "${RED}✗ sharelatex 容器未运行!${NC}"
        echo -e "${YELLOW}▶ 正在检查日志...${NC}"
        show_compose_logs "sharelatex"
        return 1
    fi
    
    echo -e "${GREEN}✓ sharelatex 容器已启动${NC}"
    echo -e "${GREEN}✓ 基础服务安装完成! 访问: ${ACCESS_URL}${NC}"
}

install_chinese() {
    echo -e "\n${YELLOW}▶ 安装中文支持...${NC}"
    local SHARELATEX_CONTAINER
    
    # 检查容器是否运行
    SHARELATEX_CONTAINER=$(get_container "sharelatex" "sharelatex")
    if [ -z "$SHARELATEX_CONTAINER" ]; then
        echo -e "${RED}✗ sharelatex 容器未运行!${NC}"
        return 1
    fi

    # 先更新tlmgr自身
    echo -e "${YELLOW}▶ 更新 tlmgr...${NC}"
    prepare_tlmgr "$SHARELATEX_CONTAINER" || return 1
    
    # 检查tlmgr是否可用
    if ! docker exec "$SHARELATEX_CONTAINER" tlmgr --version &>/dev/null; then
        echo -e "${RED}✗ tlmgr 不可用! 尝试初始化...${NC}"
        docker exec "$SHARELATEX_CONTAINER" bash -c 'tlmgr init-usertree 2>/dev/null || true'
    fi

    echo -e "${YELLOW}▶ 安装中文宏包...${NC}"
    docker exec "$SHARELATEX_CONTAINER" bash -c '
        check_status=0
        
        # 安装中文支持包
        echo "正在安装中文宏包..."
        tlmgr install collection-langchinese xecjk ctex
        install_status=$?
        
        # 创建中文字体目录
        mkdir -p /usr/share/fonts/chinese
        
        # 下载中文字体
        echo "正在下载中文字体..."
        if [ ! -f "/usr/share/fonts/chinese/simsun.ttc" ]; then
            wget -q --timeout=10 --tries=2 -O /usr/share/fonts/chinese/simsun.ttc \
                "https://github.com/jiaxiaochu/font/raw/master/simsun.ttc" || \
            wget -q --timeout=10 --tries=2 -O /usr/share/fonts/chinese/simsun.ttc \
                "https://mirrors.tuna.tsinghua.edu.cn/deepin/pool/non-free/f/fonts-simsun/simsun.ttc" || \
            echo "下载simsun.ttc失败，将使用备用方案"
        fi
        
        if [ ! -f "/usr/share/fonts/chinese/simkai.ttf" ]; then
            wget -q --timeout=10 --tries=2 -O /usr/share/fonts/chinese/simkai.ttf \
                "https://github.com/jiaxiaochu/font/raw/master/simkai.ttf" || \
            wget -q --timeout=10 --tries=2 -O /usr/share/fonts/chinese/simkai.ttf \
                "https://mirrors.tuna.tsinghua.edu.cn/deepin/pool/non-free/f/fonts-simsun/simkai.ttf" || \
            echo "下载simkai.ttf失败，将使用备用方案"
        fi
        
        # 刷新字体缓存
        echo "正在刷新字体缓存..."
        fc-cache -fv 2>/dev/null || true
        
        # 检查安装结果
        echo "检查安装结果:"
        kpsewhich ctex.sty >/dev/null && echo "✓ ctex 已安装" || { echo "✗ ctex 未安装"; check_status=1; }
        kpsewhich xeCJK.sty >/dev/null && echo "✓ xeCJK 已安装" || { echo "✗ xeCJK 未安装"; check_status=1; }
        [ "$install_status" -eq 0 ] && [ "$check_status" -eq 0 ]
    '
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 中文支持已安装完成!${NC}"
    else
        echo -e "${RED}✗ 中文支持安装失败，请检查 tlmgr 输出${NC}"
        return 1
    fi
}

install_fonts() {
    echo -e "\n${YELLOW}▶ 字体安装选项:${NC}"
    local SHARELATEX_CONTAINER
    PS3="请选择字体包: "
    SHARELATEX_CONTAINER=$(get_container "sharelatex" "sharelatex")
    if [ -z "$SHARELATEX_CONTAINER" ]; then
        echo -e "${RED}✗ sharelatex 容器未运行!${NC}"
        return 1
    fi
    options=(
        "Windows核心字体 (包含Times New Roman等)"
        "Adobe字体" 
        "思源字体 (Noto CJK)"
        "手动安装Times New Roman字体"
        "返回"
    )
    select opt in "${options[@]}"; do
        case $REPLY in
            1) 
                echo -e "${YELLOW}▶ 安装Windows核心字体...${NC}"
                docker exec "$SHARELATEX_CONTAINER" bash -c '
                    # 更新包列表
                    apt-get update
                    
                    # 设置非交互式安装并接受EULA
                    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula boolean true" | debconf-set-selections
                    
                    # 安装微软核心字体包
                    echo "正在安装ttf-mscorefonts-installer..."
                    DEBIAN_FRONTEND=noninteractive apt-get install -y fontconfig ttf-mscorefonts-installer
                    
                    # 检查字体文件是否存在
                    echo "检查Times New Roman字体是否安装:"
                    if [ -f "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf" ] || \
                       [ -f "/usr/share/fonts/truetype/msttcorefonts/times.ttf" ]; then
                        echo "✓ Times New Roman字体已安装"
                    else
                        echo "✗ Times New Roman字体未安装，可能需要手动安装"
                    fi
                    
                    echo "Windows核心字体安装完成"
                '
                ;;
            2) 
                echo -e "${YELLOW}▶ 安装Adobe字体...${NC}"
                docker exec "$SHARELATEX_CONTAINER" bash -c "apt-get update && apt-get install -y fontconfig fonts-adobe-*"
                ;;
            3) 
                echo -e "${YELLOW}▶ 安装思源字体...${NC}"
                docker exec "$SHARELATEX_CONTAINER" bash -c "apt-get update && apt-get install -y fontconfig fonts-noto-cjk fonts-noto"
                ;;
            4)
                echo -e "${YELLOW}▶ 手动安装Times New Roman字体...${NC}"
                docker exec "$SHARELATEX_CONTAINER" bash -c '
                    mkdir -p /usr/share/fonts/truetype/msttcorefonts
                    cd /usr/share/fonts/truetype/msttcorefonts
                    
                    # 下载Times New Roman字体
                    echo "下载Times New Roman字体..."
                    if ! command -v wget &> /dev/null; then
                        apt-get update && apt-get install -y wget
                    fi
                    
                    # 尝试从不同源下载
                    if [ ! -f "times32.exe" ]; then
                        wget -q --timeout=30 --tries=2 -O times32.exe \
                            "https://downloads.sourceforge.net/project/corefonts/the%20fonts/final/times32.exe" || \
                        wget -q --timeout=30 --tries=2 -O times32.exe \
                            "http://sourceforge.net/projects/corefonts/files/the%20fonts/final/times32.exe/download" || \
                        echo "下载失败，尝试其他方法"
                    fi
                    
                    # 如果下载成功，提取字体
                    if [ -f "times32.exe" ]; then
                        echo "提取字体文件..."
                        if ! command -v cabextract &> /dev/null; then
                            echo "安装cabextract..."
                            apt-get update && apt-get install -y cabextract
                        fi
                        
                        if cabextract -L -F "*.ttf" times32.exe 2>/dev/null; then
                            echo "字体提取成功"
                            # 重命名字体文件
                            for font in times*.ttf; do
                                case "$font" in
                                    "times.ttf")
                                        mv "times.ttf" "Times_New_Roman.ttf" 2>/dev/null || true
                                        ;;
                                    "timesbd.ttf")
                                        mv "timesbd.ttf" "Times_New_Roman_Bold.ttf" 2>/dev/null || true
                                        ;;
                                    "timesbi.ttf")
                                        mv "timesbi.ttf" "Times_New_Roman_Bold_Italic.ttf" 2>/dev/null || true
                                        ;;
                                    "timesi.ttf")
                                        mv "timesi.ttf" "Times_New_Roman_Italic.ttf" 2>/dev/null || true
                                        ;;
                                esac
                            done
                        else
                            echo "字体提取失败"
                        fi
                    else
                        echo "未能下载times32.exe文件"
                        echo "您可以手动下载并安装字体"
                    fi
                    
                    # 刷新字体缓存
                    fc-cache -fv
                    echo "Times New Roman字体安装完成"
                '
                ;;
            5) break ;;
            *) echo -e "${RED}无效选择!${NC}"; continue ;;
        esac
        
        # 刷新字体缓存
        docker exec "$SHARELATEX_CONTAINER" bash -c 'command -v fc-cache >/dev/null || (apt-get update && apt-get install -y fontconfig); fc-cache -fv' >/dev/null || {
            echo -e "${RED}✗ 字体缓存刷新失败${NC}"
            return 1
        }
        echo -e "${GREEN}✓ 字体缓存已刷新${NC}"
        break
    done
}

# New: Install LaTeX Packages
install_packages() {
    echo -e "\n${YELLOW}▶ 开始安装 LaTeX 宏包...${NC}"
    local SHARELATEX_CONTAINER

    # Check if container is running
    SHARELATEX_CONTAINER=$(get_container "sharelatex" "sharelatex")
    if [ -z "$SHARELATEX_CONTAINER" ]; then
        echo -e "${RED}✗ sharelatex 容器未运行，请先启动基础服务!${NC}"
        return 1
    fi

    # Ensure tlmgr is ready
    echo -e "${YELLOW}▶ 正在准备 tlmgr...${NC}"
    prepare_tlmgr "$SHARELATEX_CONTAINER" || return 1

    # Choose mirror
    echo -e "${BLUE}请选择 CTAN 镜像源:${NC}"
    select mirror in "自动兼容源 (推荐)" "清华源 (自动处理 TeX Live 年份兼容)"; do
        case $REPLY in
            1) 
                echo -e "${GREEN}✓ 使用自动兼容源${NC}"
                break 
                ;;
            2) 
                prepare_tlmgr "$SHARELATEX_CONTAINER" || return 1
                echo -e "${GREEN}✓ 已配置清华兼容镜像源${NC}"
                break 
                ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
    done

    # Choose package type
    echo -e "${BLUE}选择宏包安装模式:${NC}"
    select pkg_type in "全部宏包 (scheme-full, 约 4GB+)" "常用数学宏包 (amsmath, geometry 等)" "自定义宏包 (手动输入名称)"; do
        case $REPLY in
            1)
                echo -e "${YELLOW}▶ 开始安装 scheme-full (可能耗时较长，请耐心等待)...${NC}"
                docker exec "$SHARELATEX_CONTAINER" tlmgr install scheme-full && {
                    echo -e "${GREEN}✓ 全部宏包安装完成!${NC}"
                } || {
                    echo -e "${RED}✗ 全部宏包安装失败，请检查 tlmgr 输出${NC}"
                    return 1
                }
                break
                ;;
            2)
                # 推荐数学与常用宏包
                COMMON_PKGS="
                amsmath amsfonts mathtools tools physics graphics
                geometry fancyhdr enumitem titlesec hyperref
                booktabs caption float listings algorithms algorithmicx
                xcolor soul tikz-cd mhchem wrapfig
                "
                echo -e "${YELLOW}▶ 正在安装常用数学及排版宏包...${NC}"
                docker exec "$SHARELATEX_CONTAINER" tlmgr install $COMMON_PKGS && {
                    echo -e "${GREEN}✓ 常用宏包安装完成!${NC}"
                } || {
                    echo -e "${RED}✗ 常用宏包安装失败，请检查 tlmgr 输出${NC}"
                    return 1
                }
                break
                ;;
            3)
                echo -e "${YELLOW}请输入要安装的宏包名称（空格分隔，如：gbt7714 mhchem）:${NC}"
                read -r -p "宏包列表: " CUSTOM_PKGS
                [ -z "$CUSTOM_PKGS" ] && echo -e "${YELLOW}→ 未输入宏包，跳过${NC}" && return 0

                echo -e "${YELLOW}▶ 正在安装自定义宏包: $CUSTOM_PKGS${NC}"
                docker exec "$SHARELATEX_CONTAINER" tlmgr install $CUSTOM_PKGS && {
                    echo -e "${GREEN}✓ 自定义宏包安装完成: $CUSTOM_PKGS${NC}"
                } || {
                    echo -e "${RED}✗ 自定义宏包安装失败，请检查宏包名称是否正确${NC}"
                    return 1
                }
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
