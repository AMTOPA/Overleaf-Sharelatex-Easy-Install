#!/bin/bash
# OVERSEI Installer v5.2
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

echo -e "${CYAN}:: OVERSEI - Overleaf/ShareLaTeX Easy Installer v5.2 ::${NC}\n"

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
echo -e "${YELLOW}注意: Overleaf社区版推荐使用8.0+版本${NC}"
select mongo_ver in "最新版 (自动获取Docker Hub最新稳定版)" "自定义版本 (手动输入版本号)"; do
    case $REPLY in
        1)
            # 尝试获取最新稳定版
            echo -e "${YELLOW}▶ 正在获取MongoDB最新版本...${NC}"
            
            # 尝试多种方法获取最新版本
            LATEST_MONGO="8.0"  # 默认值
            
            # 方法1: 从Docker Hub API获取
            if command -v curl &>/dev/null; then
                LATEST_TAG=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/mongo/tags?page_size=5" | 
                            grep -o '"name":"[0-9]\+\.[0-9]\+"' | 
                            head -1 | 
                            cut -d'"' -f4 2>/dev/null) || LATEST_TAG=""
                
                if [[ -n "$LATEST_TAG" ]]; then
                    LATEST_MONGO="$LATEST_TAG"
                else
                    # 方法2: 使用简单方法
                    LATEST_MONGO="8.0"
                fi
            fi
            
            MONGO_VERSION="$LATEST_MONGO"
            echo -e "${GREEN}✓ 将安装 MongoDB 最新版本: ${MONGO_VERSION}${NC}"
            break
            ;;
        2)
            while true; do
                read -r -p "请输入MongoDB版本号 (如: 6.0, 7.0, 8.0): " CUSTOM_VER
                if [[ "$CUSTOM_VER" =~ ^[0-9]+\.[0-9]+$ ]]; then
                    MONGO_VERSION="$CUSTOM_VER"
                    echo -e "${GREEN}✓ 已选择自定义版本: MongoDB ${MONGO_VERSION}${NC}"
                    
                    # 版本警告
                    if [[ $(echo "$CUSTOM_VER < 8.0" | bc -l 2>/dev/null) -eq 1 ]]; then
                        echo -e "${YELLOW}⚠ 警告: Overleaf 官方要求 MongoDB 8.0+${NC}"
                        echo -e "${YELLOW}   选择 ${CUSTOM_VER} 版本可能导致兼容性问题${NC}"
                        read -r -p "是否继续? (y/N): " confirm
                        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                            continue
                        fi
                    fi
                    break
                else
                    echo -e "${RED}✗ 版本号格式错误! 请使用格式: X.X (如: 6.0)${NC}"
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
    for cmd in docker docker-compose git unzip curl bc; do
        if ! command -v $cmd &>/dev/null; then
            echo -e "${YELLOW}▶ 安装依赖: $cmd...${NC}"
            apt-get update && apt-get install -y $cmd || {
                echo -e "${RED}✗ 安装 $cmd 失败!${NC}"; exit 1
            }
        fi
    done

    # 检查并安装bc（用于版本比较）
    if ! command -v bc &>/dev/null; then
        apt-get install -y bc
    fi

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

    # Essential configs - 使用用户选择的MONGO_VERSION
    echo -e "${GREEN}✓ 设置 MongoDB 版本为: ${MONGO_VERSION}${NC}"
    sed -i \
        -e "s/^OVERLEAF_LISTEN_IP=.*/OVERLEAF_LISTEN_IP=${LISTEN_IP}/" \
        -e 's/^OVERLEAF_PORT=.*/OVERLEAF_PORT=8888/' \
        -e "s/^MONGO_VERSION=.*/MONGO_VERSION=${MONGO_VERSION}/" \
        config/overleaf.rc

    echo -e "${YELLOW}▶ 启动服务中...${NC}"
    
    bin/up -d
    
    # 等待服务启动，增加版本检查
    echo -e "${YELLOW}▶ 等待服务启动并检查版本兼容性...${NC}"
    
    # 增加等待时间，确保容器完全启动
    for i in {1..10}; do
        echo -ne "${YELLOW}等待服务启动 ($i/10)...${NC}\r"
        sleep 5
    done
    echo ""
    
    # 检查MongoDB容器是否运行
    if docker ps | grep -q mongo; then
        echo -e "${GREEN}✓ MongoDB 容器已启动${NC}"
        
        # 检查MongoDB版本
        echo -e "${YELLOW}▶ 正在检查 MongoDB 实际版本...${NC}"
        MONGO_ACTUAL_VER=$(docker exec mongo mongod --version 2>/dev/null | grep -oP "db\s+version\s+v?\K[0-9]+\.[0-9]+" | head -1)
        if [ -z "$MONGO_ACTUAL_VER" ]; then
            # 尝试另一种版本字符串格式
            MONGO_ACTUAL_VER=$(docker exec mongo mongod --version 2>/dev/null | grep -i version | grep -oP "[0-9]+\.[0-9]+\.[0-9]+" | head -1 | cut -d. -f1-2)
        fi
        
        if [ -n "$MONGO_ACTUAL_VER" ]; then
            echo -e "${GREEN}✓ MongoDB 实际运行版本: ${MONGO_ACTUAL_VER}${NC}"
            
            # 版本兼容性检查
            if [[ $(echo "$MONGO_ACTUAL_VER < 8.0" | bc -l 2>/dev/null) -eq 1 ]]; then
                echo -e "${YELLOW}⚠ 注意: Overleaf 官方要求 MongoDB 8.0+${NC}"
                echo -e "${YELLOW}   当前版本 ${MONGO_ACTUAL_VER} 可能导致兼容性问题${NC}"
                echo -e "${YELLOW}   如果遇到启动失败，请考虑升级到 8.0+ 版本${NC}"
                echo -e "${YELLOW}   要升级MongoDB，请修改 config/overleaf.rc 中的 MONGO_VERSION 并重新运行${NC}"
            else
                echo -e "${GREEN}✓ MongoDB 版本兼容性检查通过${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ 无法获取MongoDB版本信息，但容器正在运行${NC}"
        fi
    else
        echo -e "${RED}✗ MongoDB 容器未运行!${NC}"
        echo -e "${YELLOW}▶ 正在检查日志...${NC}"
        docker-compose logs mongo | tail -20
    fi
    
    echo -e "${GREEN}✓ 基础服务安装完成! 访问: ${ACCESS_URL}${NC}"
}

install_chinese() {
    echo -e "\n${YELLOW}▶ 安装中文支持...${NC}"
    
    # 检查容器是否运行
    if ! docker ps | grep -q sharelatex; then
        echo -e "${RED}✗ sharelatex 容器未运行!${NC}"
        return 1
    fi

    # 先更新tlmgr自身
    echo -e "${YELLOW}▶ 更新 tlmgr...${NC}"
    docker exec sharelatex bash -c 'tlmgr update --self 2>/dev/null || echo "tlmgr更新失败，继续安装..."'
    
    # 检查tlmgr是否可用
    if ! docker exec sharelatex tlmgr --version &>/dev/null; then
        echo -e "${RED}✗ tlmgr 不可用! 尝试初始化...${NC}"
        docker exec sharelatex bash -c 'tlmgr init-usertree 2>/dev/null || true'
    fi

    echo -e "${YELLOW}▶ 安装中文宏包...${NC}"
    docker exec sharelatex bash -c '
        # 设置镜像源加速
        tlmgr option repository https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet 2>/dev/null || true
        
        # 安装中文支持包
        echo "正在安装中文宏包..."
        tlmgr install collection-langchinese xecjk ctex 2>&1 | grep -E "(installed|already present|warning|error)" || true
        
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
        kpsewhich ctex.sty && echo "✓ ctex 已安装" || echo "✗ ctex 未安装"
        kpsewhich xeCJK.sty && echo "✓ xeCJK 已安装" || echo "✗ xeCJK 未安装"
    '
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 中文支持已安装完成!${NC}"
    else
        echo -e "${YELLOW}⚠ 中文支持安装过程中出现警告，但可能部分功能已安装${NC}"
    fi
}

install_fonts() {
    echo -e "\n${YELLOW}▶ 字体安装选项:${NC}"
    PS3="请选择字体包: "
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
                docker exec sharelatex bash -c '
                    apt-get update
                    # 安装微软核心字体包
                    apt-get install -y ttf-mscorefonts-installer
                    # 同意EULA
                    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
                    # 重新配置以触发字体安装
                    dpkg-reconfigure ttf-mscorefonts-installer
                    echo "Windows核心字体安装完成"
                '
                ;;
            2) 
                echo -e "${YELLOW}▶ 安装Adobe字体...${NC}"
                docker exec sharelatex bash -c "apt-get update && apt-get install -y fonts-adobe-*" 
                ;;
            3) 
                echo -e "${YELLOW}▶ 安装思源字体...${NC}"
                docker exec sharelatex bash -c "apt-get update && apt-get install -y fonts-noto-cjk fonts-noto" 
                ;;
            4)
                echo -e "${YELLOW}▶ 手动安装Times New Roman字体...${NC}"
                docker exec sharelatex bash -c '
                    mkdir -p /usr/share/fonts/truetype/msttcorefonts
                    cd /usr/share/fonts/truetype/msttcorefonts
                    
                    # 下载Times New Roman字体
                    echo "下载Times New Roman字体..."
                    wget -q --timeout=10 -O times.ttf "http://sourceforge.net/projects/corefonts/files/the%20fonts/final/times32.exe/download" || \
                    wget -q --timeout=10 -O times.ttf "https://downloads.sourceforge.net/project/corefonts/the%20fonts/final/times32.exe" || \
                    echo "下载失败，尝试从备用源下载"
                    
                    # 如果下载成功，提取字体
                    if [ -f "times32.exe" ]; then
                        cabextract -L -F "*.ttf" times32.exe 2>/dev/null || \
                        (echo "cabextract未安装，安装中..." && apt-get update && apt-get install -y cabextract && cabextract -L -F "*.ttf" times32.exe)
                        
                        # 重命名字体文件
                        mv times.ttf Times_New_Roman.ttf 2>/dev/null || true
                        mv timesbd.ttf Times_New_Roman_Bold.ttf 2>/dev/null || true
                        mv timesbi.ttf Times_New_Roman_Bold_Italic.ttf 2>/dev/null || true
                        mv timesi.ttf Times_New_Roman_Italic.ttf 2>/dev/null || true
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
        docker exec sharelatex fc-cache -fv 2>/dev/null
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
    docker exec sharelatex bash -c "tlmgr update --self 2>/dev/null || echo 'tlmgr更新失败，继续...'" > /dev/null 2>&1

    # Choose mirror
    echo -e "${BLUE}请选择 CTAN 镜像源:${NC}"
    select mirror in "官方源 (CTAN)" "清华源 (mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet)"; do
        case $REPLY in
            1) 
                echo -e "${GREEN}✓ 使用官方源${NC}"
                break 
                ;;
            2) 
                docker exec sharelatex tlmgr option repository https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet;
                echo -e "${GREEN}✓ 已切换至清华镜像源${NC}"
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
                docker exec sharelatex tlmgr install scheme-full && \
                    echo -e "${GREEN}✓ 全部宏包安装完成!${NC}" || \
                    echo -e "${YELLOW}⚠ 安装可能未完全成功，但部分宏包已安装${NC}"
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
                    echo -e "${YELLOW}⚠ 部分宏包安装失败，但大部分已安装${NC}"
                break
                ;;
            3)
                echo -e "${YELLOW}请输入要安装的宏包名称（空格分隔，如：gbt7714 mhchem）:${NC}"
                read -r -p "宏包列表: " CUSTOM_PKGS
                [ -z "$CUSTOM_PKGS" ] && echo -e "${YELLOW}→ 未输入宏包，跳过${NC}" && return 0

                echo -e "${YELLOW}▶ 正在安装自定义宏包: $CUSTOM_PKGS${NC}"
                docker exec sharelatex tlmgr install $CUSTOM_PKGS && \
                    echo -e "${GREEN}✓ 自定义宏包安装完成: $CUSTOM_PKGS${NC}" || \
                    echo -e "${YELLOW}⚠ 部分宏包安装失败，请检查宏包名称是否正确${NC}"
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
