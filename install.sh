#!/bin/bash
# OVERSEI Installer v5.7
# GitHub: https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install  

# 发送 API 计数请求（静默模式，不影响脚本执行）
curl -s "https://js.ruseo.cn/api/counter.php?api_key=3976bd1973c3c40ee8c2f7f4a12b059b&action=increment&counter_id=0bc7f9e8ed200173dc9205089c2d3036&value=1" >/dev/null 2>&1 &

# ASCII Art and Colors
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; CYAN='\033[1;36m'; NC='\033[0m'
MIN_MONGO_VERSION="8.0"
DEFAULT_MONGO_VERSION="8.0"
DEFAULT_OVERLEAF_PORT="${OVERSEI_PORT:-8888}"
OVERLEAF_PORT="$DEFAULT_OVERLEAF_PORT"
INSTALL_DIR="/root/overleaf"
TOOLKIT_DIR="$INSTALL_DIR/overleaf-toolkit"
AUTO_MODE="${AUTO_MODE:-0}"

version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]
}

is_arm64_host() {
    case "$(uname -m)" in
        aarch64|arm64) return 0 ;;
        *) return 1 ;;
    esac
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

is_valid_port() {
    local port="$1"

    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

get_docker_port_owner() {
    local port="$1"

    docker ps --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Ports}}' 2>/dev/null |
        awk -F'|' -v port="$port" '
            index($4, ":" port "->") || index($4, ":::" port "->") || index($4, "[::]:" port "->") {
                print
                exit
            }
        '
}

is_port_in_use() {
    local port="$1"

    [ -n "$(get_docker_port_owner "$port")" ] && return 0

    if command -v ss &>/dev/null; then
        ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${port}$" && return 0
    elif command -v netstat &>/dev/null; then
        netstat -ltn 2>/dev/null | awk 'NR > 2 {print $4}' | grep -Eq "(:|\\])${port}$" && return 0
    fi

    return 1
}

choose_available_overleaf_port() {
    local requested_port="$1"
    local port

    for port in "$requested_port" $(seq 8889 8999); do
        if ! is_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
    done

    return 1
}

ensure_overleaf_port_available() {
    local requested_port="${1:-$DEFAULT_OVERLEAF_PORT}"
    local owner
    local owner_id
    local owner_name
    local owner_image
    local next_port

    if ! is_valid_port "$requested_port"; then
        echo -e "${YELLOW}⚠ OVERSEI_PORT 无效，使用默认端口 8888${NC}"
        requested_port="8888"
    fi

    owner=$(get_docker_port_owner "$requested_port")
    if [ -n "$owner" ]; then
        owner_id=$(printf '%s' "$owner" | cut -d'|' -f1)
        owner_name=$(printf '%s' "$owner" | cut -d'|' -f2)
        owner_image=$(printf '%s' "$owner" | cut -d'|' -f3)

        if [ "$owner_name" = "sharelatex" ]; then
            OVERLEAF_PORT="$requested_port"
            echo -e "${GREEN}✓ 端口 ${OVERLEAF_PORT} 已由当前 sharelatex 容器使用，继续复用${NC}"
            return 0
        fi

        if printf '%s\n%s\n' "$owner_name" "$owner_image" | grep -Eqi 'sharelatex|overleaf|oversei'; then
            echo -e "${YELLOW}⚠ 端口 ${requested_port} 被旧 Overleaf/ShareLaTeX 容器 ${owner_name} 占用，正在移除...${NC}"
            docker rm -f "$owner_id" >/dev/null 2>&1 || {
                echo -e "${RED}✗ 无法移除占用端口的旧容器 ${owner_name}${NC}"
                return 1
            }
            sleep 2
        else
            echo -e "${YELLOW}⚠ 端口 ${requested_port} 已被其他容器 ${owner_name} 占用，自动寻找可用端口${NC}"
        fi
    fi

    if is_port_in_use "$requested_port"; then
        next_port=$(choose_available_overleaf_port "$requested_port") || {
            echo -e "${RED}✗ 未找到可用端口，请释放 8888-8999 范围内的端口后重试${NC}"
            return 1
        }
        OVERLEAF_PORT="$next_port"
        echo -e "${YELLOW}→ Overleaf 将改用端口 ${OVERLEAF_PORT}${NC}"
    else
        OVERLEAF_PORT="$requested_port"
        echo -e "${GREEN}✓ Overleaf 端口 ${OVERLEAF_PORT} 可用${NC}"
    fi
}

select_latest_mongo_version() {
    local latest_tag

    if [ -n "${OVERSEI_MONGO_VERSION:-}" ]; then
        if [[ "$OVERSEI_MONGO_VERSION" =~ ^[0-9]+\.[0-9]+$ ]] && ! version_lt "$OVERSEI_MONGO_VERSION" "$MIN_MONGO_VERSION"; then
            MONGO_VERSION="$OVERSEI_MONGO_VERSION"
            echo -e "${GREEN}✓ 使用环境变量指定的 MongoDB 版本: ${MONGO_VERSION}${NC}"
            return 0
        fi
        echo -e "${YELLOW}⚠ OVERSEI_MONGO_VERSION 无效或低于 ${MIN_MONGO_VERSION}，改用自动选择${NC}"
    fi

    echo -e "${YELLOW}▶ 正在自动选择 MongoDB 最新兼容版本...${NC}"
    latest_tag="$DEFAULT_MONGO_VERSION"
    if command -v curl &>/dev/null; then
        latest_tag=$(get_latest_mongo_version) || latest_tag="$DEFAULT_MONGO_VERSION"
    fi
    [ -z "$latest_tag" ] && latest_tag="$DEFAULT_MONGO_VERSION"
    MONGO_VERSION="$latest_tag"
    echo -e "${GREEN}✓ 将使用 MongoDB ${MONGO_VERSION}${NC}"
}

choose_deployment_type() {
    local choice

    echo -e "${BLUE}选择部署类型:${NC}"
    echo "1) 本地部署"
    echo "2) 服务器部署（默认）"
    read -r -p "#? " choice
    choice="${choice:-2}"

    case "$choice" in
        1)
            ACCESS_URL="http://localhost:${OVERLEAF_PORT}"
            LISTEN_IP="127.0.0.1"
            ;;
        2)
            PUBLIC_IPV4=$(detect_public_ipv4)
            PUBLIC_IPV6=$(detect_public_ipv6)
            PUBLIC_IP="${PUBLIC_IPV4:-$PUBLIC_IPV6}"
            ACCESS_URL="http://$(format_url_host "$PUBLIC_IP"):${OVERLEAF_PORT}"
            LISTEN_IP="0.0.0.0"
            ;;
        *)
            echo -e "${YELLOW}⚠ 无效选项，使用默认服务器部署${NC}"
            PUBLIC_IPV4=$(detect_public_ipv4)
            PUBLIC_IPV6=$(detect_public_ipv6)
            PUBLIC_IP="${PUBLIC_IPV4:-$PUBLIC_IPV6}"
            ACCESS_URL="http://$(format_url_host "$PUBLIC_IP"):${OVERLEAF_PORT}"
            LISTEN_IP="0.0.0.0"
            ;;
    esac
}

ensure_dependencies() {
    local cmd

    for cmd in docker git unzip curl bc; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${YELLOW}▶ 安装依赖: $cmd...${NC}"
            apt-get update && apt-get install -y "$cmd" || {
                echo -e "${RED}✗ 安装 $cmd 失败!${NC}"
                return 1
            }
        fi
    done

    if ! docker compose version &>/dev/null && ! command -v docker-compose &>/dev/null; then
        echo -e "${YELLOW}▶ 安装依赖: docker compose...${NC}"
        apt-get update && (apt-get install -y docker-compose-plugin || apt-get install -y docker-compose) || {
            echo -e "${RED}✗ 安装 docker compose 失败!${NC}"
            return 1
        }
    fi

    if ! command -v ss &>/dev/null && ! command -v netstat &>/dev/null; then
        echo -e "${YELLOW}▶ 安装依赖: iproute2（用于端口检测）...${NC}"
        apt-get update && apt-get install -y iproute2 || {
            echo -e "${RED}✗ 安装 iproute2 失败!${NC}"
            return 1
        }
    fi
}

ensure_toolkit_checkout() {
    mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" || return 1
    if [ ! -d "$TOOLKIT_DIR" ]; then
        git clone https://github.com/overleaf/toolkit.git overleaf-toolkit || {
            echo -e "${RED}✗ 克隆失败!${NC}"
            return 1
        }
    else
        echo -e "${GREEN}✓ 已存在 overleaf-toolkit，跳过克隆${NC}"
    fi
    cd "$TOOLKIT_DIR" || return 1
}

ensure_toolkit_initialized() {
    local backup_dir

    if [ -f "config/overleaf.rc" ]; then
        echo -e "${GREEN}✓ 已检测到 Overleaf Toolkit 配置，跳过初始化${NC}"
        touch "config/variables.env" 2>/dev/null || true
        return 0
    fi

    if [ -d "config" ]; then
        backup_dir="config.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}⚠ 检测到不完整的 config 目录，备份为 ${backup_dir} 后重新初始化${NC}"
        mv "config" "$backup_dir" || {
            echo -e "${RED}✗ 备份残缺 config 目录失败${NC}"
            return 1
        }
    fi

    bin/init || {
        if [ -f "config/overleaf.rc" ]; then
            echo -e "${YELLOW}⚠ 初始化命令返回失败，但配置文件已存在，继续修复配置${NC}"
            return 0
        fi
        echo -e "${RED}✗ overleaf-toolkit 初始化失败!${NC}"
        return 1
    }
}

ensure_amd64_emulation() {
    if ! is_arm64_host; then
        return 0
    fi

    echo -e "${YELLOW}▶ 检测到 ARM64/aarch64 主机，ShareLaTeX 官方镜像将使用 linux/amd64 兼容模式运行...${NC}"

    if ! command -v qemu-x86_64-static &>/dev/null || ! command -v update-binfmts &>/dev/null; then
        echo -e "${YELLOW}▶ 安装 amd64 容器兼容依赖: qemu-user-static binfmt-support...${NC}"
        apt-get update && apt-get install -y qemu-user-static binfmt-support || {
            echo -e "${RED}✗ 安装 amd64 兼容依赖失败，ARM64 主机无法运行 ShareLaTeX amd64 镜像${NC}"
            return 1
        }
    fi

    if command -v update-binfmts &>/dev/null; then
        update-binfmts --enable qemu-x86_64 >/dev/null 2>&1 || true
    fi

    if command -v systemctl &>/dev/null; then
        systemctl restart systemd-binfmt >/dev/null 2>&1 || true
    fi

    if [ -f /proc/sys/fs/binfmt_misc/qemu-x86_64 ]; then
        echo -e "${GREEN}✓ amd64 容器兼容支持已启用${NC}"
    else
        echo -e "${YELLOW}⚠ 未检测到 qemu-x86_64 binfmt 注册项，Docker 可能无法启动 amd64 ShareLaTeX 容器${NC}"
        echo -e "${YELLOW}   如果后续启动失败，请执行: systemctl restart systemd-binfmt && docker run --rm --platform linux/amd64 hello-world${NC}"
    fi
}

configure_arm64_compose_override() {
    local override_file="config/docker-compose.override.yml"
    local tmp_file
    local updated=0

    if ! is_arm64_host; then
        return 0
    fi

    if [ ! -f "$override_file" ]; then
        cat > "$override_file" <<'EOF'
services:
  sharelatex:
    platform: linux/amd64
EOF
        echo -e "${GREEN}✓ 已为 ARM64 主机配置 ShareLaTeX 使用 linux/amd64 镜像平台${NC}"
        return 0
    fi

    if awk '
        /^[[:space:]]*sharelatex:[[:space:]]*$/ { in_sharelatex=1; next }
        in_sharelatex && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { in_sharelatex=0 }
        in_sharelatex && /^[[:space:]]*platform:[[:space:]]*linux\/amd64[[:space:]]*$/ { found=1 }
        END { exit found ? 0 : 1 }
    ' "$override_file"; then
        echo -e "${GREEN}✓ ARM64 Docker Compose 平台配置已存在${NC}"
        return 0
    fi

    cp "$override_file" "${override_file}.bak.$(date +%Y%m%d%H%M%S)" || {
        echo -e "${RED}✗ 备份 $override_file 失败${NC}"
        return 1
    }

    tmp_file=$(mktemp) || return 1
    if grep -q '^  sharelatex:[[:space:]]*$' "$override_file"; then
        awk '
            BEGIN { in_sharelatex=0; inserted=0; replaced=0 }
            function insert_platform() {
                if (!inserted && !replaced) {
                    print "    platform: linux/amd64"
                    inserted=1
                }
            }
            {
                if (in_sharelatex && $0 ~ /^  [A-Za-z0-9_.-]+:[[:space:]]*$/) {
                    insert_platform()
                    in_sharelatex=0
                }
                if ($0 ~ /^  sharelatex:[[:space:]]*$/) {
                    print
                    in_sharelatex=1
                    next
                }
                if (in_sharelatex && $0 ~ /^    platform:[[:space:]]*/) {
                    print "    platform: linux/amd64"
                    replaced=1
                    next
                }
                print
            }
            END {
                if (in_sharelatex) {
                    insert_platform()
                }
            }
        ' "$override_file" > "$tmp_file" && mv "$tmp_file" "$override_file" && updated=1
    elif grep -q '^services:[[:space:]]*$' "$override_file"; then
        awk '
            {
                print
                if (!inserted && $0 ~ /^services:[[:space:]]*$/) {
                    print "  sharelatex:"
                    print "    platform: linux/amd64"
                    inserted=1
                }
            }
        ' "$override_file" > "$tmp_file" && mv "$tmp_file" "$override_file" && updated=1
    else
        {
            cat "$override_file"
            printf '\nservices:\n  sharelatex:\n    platform: linux/amd64\n'
        } > "$tmp_file" && mv "$tmp_file" "$override_file" && updated=1
    fi

    if [ "$updated" -ne 1 ]; then
        rm -f "$tmp_file"
        echo -e "${RED}✗ 更新 $override_file 失败${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ 已更新 ARM64 Docker Compose 平台配置: ${override_file}${NC}"
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

read_rc_value() {
    local key="$1"
    local file="$2"

    [ -f "$file" ] || return 1
    grep -E "^${key}=" "$file" | tail -1 | cut -d= -f2-
}

is_ipv4() {
    local ip="$1"
    local IFS=.
    local a b c d

    [[ "$ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
    read -r a b c d <<< "$ip"
    for octet in "$a" "$b" "$c" "$d"; do
        [ "$octet" -ge 0 ] 2>/dev/null && [ "$octet" -le 255 ] 2>/dev/null || return 1
    done
}

is_ipv6() {
    local ip="$1"

    [[ "$ip" == *:* ]] && [[ "$ip" =~ ^[0-9A-Fa-f:]+$ ]]
}

is_valid_host() {
    local host="$1"

    [ -z "$host" ] && return 1
    [[ "$host" =~ [[:space:]] ]] && return 1
    [ "$host" = "invalid" ] && return 1
    [ "$host" = "invalid IP" ] && return 1
    is_ipv4 "$host" || is_ipv6 "$host" || [ "$host" = "localhost" ]
}

is_private_ipv4() {
    local ip="$1"
    local IFS=.
    local a b c d

    is_ipv4 "$ip" || return 1
    read -r a b c d <<< "$ip"
    [ "$a" -eq 10 ] && return 0
    [ "$a" -eq 127 ] && return 0
    [ "$a" -eq 169 ] && [ "$b" -eq 254 ] && return 0
    [ "$a" -eq 172 ] && [ "$b" -ge 16 ] && [ "$b" -le 31 ] && return 0
    [ "$a" -eq 192 ] && [ "$b" -eq 168 ] && return 0
    return 1
}

format_url_host() {
    local host="$1"

    if is_ipv6 "$host"; then
        printf '[%s]' "$host"
    else
        printf '%s' "$host"
    fi
}

detect_public_ipv4() {
    local ip

    ip=$(curl -4 -fsSL --connect-timeout 5 https://api.ipify.org 2>/dev/null ||
        curl -4 -fsSL --connect-timeout 5 https://ipv4.icanhazip.com 2>/dev/null ||
        true)
    ip=$(printf '%s' "$ip" | tr -d '[:space:]')
    if is_ipv4 "$ip" && ! is_private_ipv4 "$ip"; then
        echo "$ip"
    fi
}

detect_public_ipv6() {
    local ip

    ip=$(curl -6 -fsSL --connect-timeout 5 https://api64.ipify.org 2>/dev/null ||
        curl -6 -fsSL --connect-timeout 5 https://ipv6.icanhazip.com 2>/dev/null ||
        true)
    ip=$(printf '%s' "$ip" | tr -d '[:space:]')
    if is_ipv6 "$ip"; then
        echo "$ip"
    fi
}

load_runtime_config() {
    local rc_file="$TOOLKIT_DIR/config/overleaf.rc"
    local configured_port
    local configured_ip

    configured_port=$(read_rc_value "OVERLEAF_PORT" "$rc_file" 2>/dev/null || true)
    if is_valid_port "$configured_port"; then
        OVERLEAF_PORT="$configured_port"
    fi

    configured_ip=$(read_rc_value "OVERLEAF_LISTEN_IP" "$rc_file" 2>/dev/null || true)
    if [ -n "$configured_ip" ]; then
        LISTEN_IP="$configured_ip"
    elif [ -z "${LISTEN_IP:-}" ]; then
        LISTEN_IP="0.0.0.0"
    fi

    PUBLIC_IPV4=$(detect_public_ipv4)
    PUBLIC_IPV6=$(detect_public_ipv6)
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

print_url_group() {
    local host="$1"
    local port="$2"
    local base_url
    local url_host

    is_valid_host "$host" || return 0
    url_host=$(format_url_host "$host")
    base_url="http://${url_host}:${port}"
    echo -e "${CYAN}- ${base_url}${NC}"
    echo -e "  管理员初始化: ${base_url}/launchpad"
    echo -e "  登录地址:     ${base_url}/login"
}

show_access_urls() {
    local sharelatex_container="$1"
    local seen_hosts=" "
    local host
    local printed_external=0
    local printed_lan=0

    load_runtime_config
    echo -e "${BLUE}推荐访问地址:${NC}"
    echo -e "${YELLOW}首次使用请先打开管理员初始化地址创建管理员账号，之后使用登录地址进入系统。${NC}"

    for host in "${PUBLIC_IPV4:-}" "${PUBLIC_IPV6:-}"; do
        is_valid_host "$host" || continue
        case "$seen_hosts" in *" $host "*) continue ;; esac
        seen_hosts="${seen_hosts}${host} "
        print_url_group "$host" "$OVERLEAF_PORT"
        printed_external=1
    done

    if [ -z "${PUBLIC_IPV4:-}" ]; then
        echo -e "${YELLOW}⚠ 未检测到公网 IPv4；如果云服务器应有 IPv4，请检查公网 IP 绑定、安全组和防火墙。${NC}"
    fi
    if [ "$printed_external" -eq 0 ]; then
        echo -e "${YELLOW}⚠ 未检测到公网访问地址，当前仅显示内网/本机地址。${NC}"
    fi

    for host in $(ip -o -4 addr show scope global 2>/dev/null | awk '$2 !~ /^(docker|br-|veth)/ {split($4,a,"/"); print a[1]}'); do
        is_ipv4 "$host" || continue
        case "$seen_hosts" in *" $host "*) continue ;; esac
        seen_hosts="${seen_hosts}${host} "
        if [ "$printed_lan" -eq 0 ]; then
            echo -e "${BLUE}内网/宿主机地址:${NC}"
            printed_lan=1
        fi
        print_url_group "$host" "$OVERLEAF_PORT"
    done

    echo -e "${BLUE}本机地址:${NC}"
    print_url_group "localhost" "$OVERLEAF_PORT"
    print_url_group "127.0.0.1" "$OVERLEAF_PORT"

    if [ "${OVERSEI_SHOW_INTERNAL_URLS:-0}" = "1" ] && [ -n "$sharelatex_container" ]; then
        echo -e "${YELLOW}Docker 内部地址（通常仅宿主机或 Docker 网络内可访问）:${NC}"
        docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{"\n"}}{{end}}' "$sharelatex_container" 2>/dev/null |
            while IFS= read -r host; do
                is_ipv4 "$host" || continue
                print_url_group "$host" "80"
            done
    fi
}

configure_chinese_ui() {
    local variables_file="$TOOLKIT_DIR/config/variables.env"

    if [ ! -d "$TOOLKIT_DIR/config" ]; then
        echo -e "${YELLOW}⚠ 未找到 Overleaf Toolkit 配置目录，跳过网页中文界面配置${NC}"
        return 0
    fi

    touch "$variables_file" || {
        echo -e "${RED}✗ 无法写入 $variables_file，网页中文界面配置失败${NC}"
        return 1
    }
    set_rc_value "OVERLEAF_SITE_LANGUAGE" "zh-CN" "$variables_file"
    echo -e "${GREEN}✓ Overleaf 网页界面默认语言已设置为简体中文${NC}"
}

persist_sharelatex_image() {
    local container="$1"
    local image_name="oversei/sharelatex"
    local image_version="latest"
    local image_tag

    if [ -f "$TOOLKIT_DIR/config/version" ]; then
        image_version=$(head -1 "$TOOLKIT_DIR/config/version" | tr -d '[:space:]')
        [ -z "$image_version" ] && image_version="latest"
    fi
    image_tag="${image_name}:${image_version}"

    echo -e "${YELLOW}▶ 正在固化当前 sharelatex 容器为自定义镜像，避免重建后丢失中文/宏包/字体...${NC}"
    docker commit "$container" "$image_tag" >/dev/null || {
        echo -e "${RED}✗ 自定义镜像固化失败${NC}"
        return 1
    }

    if [ -f "$TOOLKIT_DIR/config/overleaf.rc" ]; then
        set_rc_value "OVERLEAF_IMAGE_NAME" "$image_name" "$TOOLKIT_DIR/config/overleaf.rc"
    fi

    echo -e "${GREEN}✓ 已固化自定义镜像: ${image_tag}${NC}"
    echo -e "${GREEN}✓ 后续 Overleaf Toolkit 将使用: ${image_tag}${NC}"
}

offer_persist_sharelatex_image() {
    local container="$1"

    echo -e "${YELLOW}是否将当前 sharelatex 容器固化为自定义镜像？${NC}"
    echo -e "${YELLOW}建议在确认中文、字体和你的模板都能正常编译后再固化。${NC}"
    select choice in "暂不固化，继续测试" "固化并重建容器"; do
        case $REPLY in
            1)
                echo -e "${YELLOW}→ 已跳过固化；后续容器重建可能丢失本次安装的宏包/字体${NC}"
                break
                ;;
            2)
                persist_sharelatex_image "$container" || return 1
                recreate_sharelatex_container || return 1
                break
                ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
    done
}

recreate_sharelatex_container() {
    if [ ! -d "$TOOLKIT_DIR" ]; then
        return 0
    fi

    echo -e "${YELLOW}▶ 正在重建 sharelatex 容器以应用中文界面/自定义镜像配置...${NC}"
    (
        cd "$TOOLKIT_DIR" || exit 1
        if [ -x "bin/docker-compose" ]; then
            bin/docker-compose rm -f -s sharelatex >/dev/null 2>&1 || true
        elif docker compose version &>/dev/null; then
            docker compose rm -f -s sharelatex >/dev/null 2>&1 || true
        elif command -v docker-compose &>/dev/null; then
            docker-compose rm -f -s sharelatex >/dev/null 2>&1 || true
        fi

        if [ -x "bin/docker-compose" ]; then
            bin/docker-compose up -d sharelatex
        elif docker compose version &>/dev/null; then
            docker compose up -d sharelatex
        elif command -v docker-compose &>/dev/null; then
            docker-compose up -d sharelatex
        else
            exit 1
        fi
    ) || {
        echo -e "${RED}✗ sharelatex 容器重建失败${NC}"
        show_compose_logs "sharelatex"
        return 1
    }
}

print_banner() {
    cat << "EOF"
 ██████╗ ██╗   ██╗███████╗██████╗ ███████╗███████╗██╗
██╔═══██╗██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝██║
██║   ██║██║   ██║█████╗  ██████╔╝███████╗█████╗  ██║
██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════██║██╔══╝  ██║
╚██████╔╝ ╚████╔╝ ███████╗██║  ██║███████║███████╗██║
 ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝
EOF

    echo -e "${CYAN}:: OVERSEI - Overleaf/ShareLaTeX Easy Installer v5.7 ::${NC}\n"
}

# Main Menu
show_menu() {
    local choice

    echo -e "${BLUE}选择安装选项:${NC}"
    options=(
        "推荐完整安装（默认：基础服务+中文支持+常用字体+常用宏包）"
        "仅安装基础服务"
        "安装中文界面/中文支持包"
        "安装额外字体包"
        "安装LaTeX宏包"
        "自动检测并修复现有安装"
        "退出"
    )
    for i in "${!options[@]}"; do
        printf '%s) %s\n' "$((i + 1))" "${options[$i]}"
    done
    read -r -p "#? " choice
    choice="${choice:-1}"
    case "$choice" in
        1) install_full_default ;;
        2) install_base ;;
        3) install_chinese ;;
        4) install_fonts ;;
        5) install_packages ;;
        6) repair_installation ;;
        7) exit 0 ;;
        *) echo -e "${RED}无效选项!${NC}"; show_menu ;;
    esac
}

# Core Functions
install_base() {
    echo -e "\n${YELLOW}▶ 正在安装基础服务...${NC}"
    local MONGO_CONTAINER
    local SHARELATEX_CONTAINER

    ensure_dependencies || return 1
    ensure_toolkit_checkout || return 1
    ensure_toolkit_initialized || return 1

    if [ ! -f "config/overleaf.rc" ]; then
        echo -e "${RED}✗ 未找到 config/overleaf.rc!${NC}"
        return 1
    fi

    ensure_overleaf_port_available "$DEFAULT_OVERLEAF_PORT" || return 1

    # Essential configs - 使用用户选择的MONGO_VERSION
    echo -e "${GREEN}✓ 设置 MongoDB 版本为: ${MONGO_VERSION}${NC}"
    set_rc_value "OVERLEAF_LISTEN_IP" "$LISTEN_IP" "config/overleaf.rc"
    set_rc_value "OVERLEAF_PORT" "$OVERLEAF_PORT" "config/overleaf.rc"
    set_rc_value "MONGO_VERSION" "$MONGO_VERSION" "config/overleaf.rc"
    set_rc_value "SIBLING_CONTAINERS_ENABLED" "false" "config/overleaf.rc"
    configure_chinese_ui || return 1
    ensure_amd64_emulation || return 1
    configure_arm64_compose_override || return 1

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
    show_access_urls "$SHARELATEX_CONTAINER"
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
    configure_chinese_ui || return 1

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
        
        command -v fc-cache >/dev/null || (apt-get update && apt-get install -y fontconfig)
        if ! fc-match "Times New Roman" | grep -qi "Times New Roman" || ! fc-match "Arial" | grep -qi "Arial"; then
            export DEBIAN_FRONTEND=noninteractive
            echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections
            apt-get update
            apt-get install -y fontconfig cabextract xfonts-utils ttf-mscorefonts-installer
        fi

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
        
        mkdir -p /usr/local/texlive/texmf-local/fonts/truetype/oversei
        [ -s "/usr/share/fonts/chinese/simsun.ttc" ] && cp -f /usr/share/fonts/chinese/simsun.ttc /usr/local/texlive/texmf-local/fonts/truetype/oversei/simsun.ttc
        [ -s "/usr/share/fonts/chinese/simkai.ttf" ] && cp -f /usr/share/fonts/chinese/simkai.ttf /usr/local/texlive/texmf-local/fonts/truetype/oversei/simkai.ttf
        mktexlsr >/dev/null 2>&1 || true

        # 刷新字体缓存
        echo "正在刷新字体缓存..."
        fc-cache -fv 2>/dev/null || true
        
        # 检查安装结果
        echo "检查安装结果:"
        kpsewhich ctex.sty >/dev/null && echo "✓ ctex 已安装" || { echo "✗ ctex 未安装"; check_status=1; }
        kpsewhich xeCJK.sty >/dev/null && echo "✓ xeCJK 已安装" || { echo "✗ xeCJK 未安装"; check_status=1; }
        fc-match "Times New Roman" | grep -qi "Times New Roman" && echo "✓ Times New Roman 已安装" || { echo "✗ Times New Roman 未安装"; check_status=1; }
        fc-match "Arial" | grep -qi "Arial" && echo "✓ Arial 已安装" || { echo "✗ Arial 未安装"; check_status=1; }
        fc-match "SimSun" | grep -qi "SimSun" && echo "✓ SimSun 已安装" || { echo "✗ SimSun 未安装"; check_status=1; }
        kpsewhich simkai.ttf >/dev/null && echo "✓ simkai.ttf 已加入 TeX Live 字体树" || { echo "✗ simkai.ttf 未加入 TeX Live 字体树"; check_status=1; }
        [ "$install_status" -eq 0 ] && [ "$check_status" -eq 0 ]
    '
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 中文支持已安装完成!${NC}"
        if [ "$AUTO_MODE" = "1" ]; then
            echo -e "${YELLOW}→ 自动模式下暂不固化镜像，将在完整安装结束后统一处理${NC}"
        else
            offer_persist_sharelatex_image "$SHARELATEX_CONTAINER" || return 1
        fi
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
        offer_persist_sharelatex_image "$SHARELATEX_CONTAINER" || return 1
        break
    done
}

install_default_fonts() {
    echo -e "\n${YELLOW}▶ 正在安装推荐字体包（Windows 核心字体 + Noto CJK）...${NC}"
    local SHARELATEX_CONTAINER

    SHARELATEX_CONTAINER=$(get_container "sharelatex" "sharelatex")
    if [ -z "$SHARELATEX_CONTAINER" ]; then
        echo -e "${RED}✗ sharelatex 容器未运行!${NC}"
        return 1
    fi

    docker exec "$SHARELATEX_CONTAINER" bash -c '
        set -e
        export DEBIAN_FRONTEND=noninteractive
        command -v fc-cache >/dev/null || apt-get update
        echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula boolean true" | debconf-set-selections
        apt-get update
        apt-get install -y fontconfig cabextract xfonts-utils ttf-mscorefonts-installer fonts-noto-cjk fonts-noto
        fc-cache -fv >/dev/null 2>&1 || true
        fc-match "Times New Roman" >/dev/null
        fc-match "Noto Sans CJK SC" >/dev/null || fc-match "Noto Sans CJK" >/dev/null
    ' || {
        echo -e "${RED}✗ 推荐字体包安装失败${NC}"
        return 1
    }

    echo -e "${GREEN}✓ 推荐字体包已安装并刷新缓存${NC}"
}

install_common_latex_packages() {
    local SHARELATEX_CONTAINER="$1"
    local COMMON_PKGS

    COMMON_PKGS="
    collection-latexextra
    amsmath amsfonts mathtools tools physics graphics
    geometry fancyhdr enumitem titlesec hyperref
    booktabs caption float listings algorithms algorithmicx
    xcolor soul tikz-cd mhchem wrapfig multirow
    abstract natbib gbt7714 lastpage tocloft fancyvrb cprotect
    "

    echo -e "${YELLOW}▶ 正在安装常用论文模板及排版宏包...${NC}"
    docker exec "$SHARELATEX_CONTAINER" tlmgr install $COMMON_PKGS
}

install_packages_default() {
    echo -e "\n${YELLOW}▶ 正在安装推荐 LaTeX 宏包...${NC}"
    local SHARELATEX_CONTAINER

    SHARELATEX_CONTAINER=$(get_container "sharelatex" "sharelatex")
    if [ -z "$SHARELATEX_CONTAINER" ]; then
        echo -e "${RED}✗ sharelatex 容器未运行，请先启动基础服务!${NC}"
        return 1
    fi

    prepare_tlmgr "$SHARELATEX_CONTAINER" || return 1
    install_common_latex_packages "$SHARELATEX_CONTAINER" || {
        echo -e "${RED}✗ 推荐宏包安装失败，请检查 tlmgr 输出${NC}"
        return 1
    }

    echo -e "${GREEN}✓ 推荐宏包安装完成!${NC}"
}

install_full_default() {
    local SHARELATEX_CONTAINER
    local previous_auto_mode="$AUTO_MODE"

    echo -e "\n${YELLOW}▶ 正在执行推荐完整安装...${NC}"
    AUTO_MODE=1
    install_base &&
    install_chinese &&
    install_default_fonts &&
    install_packages_default || {
        AUTO_MODE="$previous_auto_mode"
        return 1
    }
    AUTO_MODE="$previous_auto_mode"

    SHARELATEX_CONTAINER=$(get_container "sharelatex" "sharelatex")
    if [ -n "$SHARELATEX_CONTAINER" ]; then
        persist_sharelatex_image "$SHARELATEX_CONTAINER" && recreate_sharelatex_container || return 1
    fi

    echo -e "${GREEN}✓ 推荐完整安装完成!${NC}"
}

repair_installation() {
    echo -e "\n${YELLOW}▶ 正在自动检测并修复现有安装...${NC}"

    ensure_dependencies || return 1
    ensure_toolkit_checkout || return 1
    ensure_toolkit_initialized || return 1

    if [ ! -f "config/overleaf.rc" ]; then
        echo -e "${RED}✗ 修复失败：未找到 config/overleaf.rc${NC}"
        return 1
    fi

    echo -e "${YELLOW}▶ 正在修复核心配置...${NC}"
    echo -e "${GREEN}✓ 将通过基础服务安装流程统一修复配置、端口和服务状态${NC}"
    install_base
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
    select pkg_type in "全部宏包 (scheme-full, 约 4GB+)" "常用论文模板宏包 (含 collection-latexextra/CUMCM 依赖)" "自定义宏包 (手动输入名称)"; do
        case $REPLY in
            1)
                echo -e "${YELLOW}▶ 开始安装 scheme-full (可能耗时较长，请耐心等待)...${NC}"
                docker exec "$SHARELATEX_CONTAINER" tlmgr install scheme-full && {
                    echo -e "${GREEN}✓ 全部宏包安装完成!${NC}"
                    offer_persist_sharelatex_image "$SHARELATEX_CONTAINER" || return 1
                } || {
                    echo -e "${RED}✗ 全部宏包安装失败，请检查 tlmgr 输出${NC}"
                    return 1
                }
                break
                ;;
            2)
                install_common_latex_packages "$SHARELATEX_CONTAINER" && {
                    echo -e "${GREEN}✓ 常用宏包安装完成!${NC}"
                    offer_persist_sharelatex_image "$SHARELATEX_CONTAINER" || return 1
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
                    offer_persist_sharelatex_image "$SHARELATEX_CONTAINER" || return 1
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

install_cli_command() {
    local lib_dir="/usr/local/lib/oversei"
    local script_target="$lib_dir/install.sh"
    local wrapper="/usr/local/bin/oversei"
    local source_script="${BASH_SOURCE[0]}"

    mkdir -p "$lib_dir" || return 1
    if [ "$source_script" != "$script_target" ]; then
        cp "$source_script" "$script_target" 2>/dev/null || {
            echo -e "${YELLOW}⚠ 无法保存本地 OVERSEI 脚本副本，命令行工具安装跳过${NC}"
            return 0
        }
        chmod 755 "$script_target" || true
    fi

    cat > "$wrapper" <<'EOF'
#!/bin/bash
exec /usr/local/lib/oversei/install.sh "$@"
EOF
    chmod 755 "$wrapper" || true
    ln -sf "$wrapper" /usr/local/bin/OVERSEI 2>/dev/null || true
    echo -e "${GREEN}✓ 本地命令已安装: oversei / OVERSEI${NC}"
}

show_cli_help() {
    cat <<'EOF'
OVERSEI local command

Usage:
  oversei --help | -h          Show this help
  oversei menu                 Open the interactive installer menu
  oversei urls [--all]         Show clean access URLs; --all also shows Docker internal URLs
  oversei status               Show container and toolkit status
  oversei config               Show key Toolkit config values
  oversei repair               Detect and repair the existing installation
  oversei base                 Install or repair base services
  oversei full                 Run recommended full installation
  oversei chinese              Install Chinese UI/typesetting support
  oversei fonts                Open font installer
  oversei packages             Open LaTeX package installer
  oversei logs [service]       Show recent logs, default service: sharelatex
  oversei restart              Restart Overleaf services
  oversei stop                 Stop Overleaf services

Examples:
  oversei urls
  oversei packages
  OVERSEI repair
EOF
}

show_status() {
    load_runtime_config
    echo -e "${BLUE}OVERSEI 状态:${NC}"
    echo "Toolkit: $TOOLKIT_DIR"
    echo "Port: ${OVERLEAF_PORT}"
    if [ -f "$TOOLKIT_DIR/config/overleaf.rc" ]; then
        echo "MongoDB: $(read_rc_value "MONGO_VERSION" "$TOOLKIT_DIR/config/overleaf.rc")"
        echo "Listen IP: $(read_rc_value "OVERLEAF_LISTEN_IP" "$TOOLKIT_DIR/config/overleaf.rc")"
    fi
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
}

show_config_summary() {
    local rc_file="$TOOLKIT_DIR/config/overleaf.rc"
    local variables_file="$TOOLKIT_DIR/config/variables.env"

    echo -e "${BLUE}配置文件:${NC}"
    echo "Toolkit: $TOOLKIT_DIR"
    echo "overleaf.rc: $rc_file"
    echo "variables.env: $variables_file"
    if [ -f "$rc_file" ]; then
        echo -e "${BLUE}关键配置:${NC}"
        for key in OVERLEAF_LISTEN_IP OVERLEAF_PORT MONGO_VERSION OVERLEAF_IMAGE_NAME SIBLING_CONTAINERS_ENABLED; do
            echo "$key=$(read_rc_value "$key" "$rc_file")"
        done
    else
        echo -e "${YELLOW}⚠ 尚未找到 overleaf.rc，请先运行 oversei repair 或 oversei base${NC}"
    fi
}

run_toolkit_compose() {
    if [ ! -d "$TOOLKIT_DIR" ]; then
        echo -e "${RED}✗ 未找到 Overleaf Toolkit: $TOOLKIT_DIR${NC}"
        return 1
    fi

    (
        cd "$TOOLKIT_DIR" || exit 1
        if [ -x "bin/docker-compose" ]; then
            bin/docker-compose "$@"
        elif docker compose version &>/dev/null; then
            docker compose "$@"
        elif command -v docker-compose &>/dev/null; then
            docker-compose "$@"
        else
            exit 1
        fi
    )
}

show_cli_urls() {
    local show_all="$1"
    local container

    load_runtime_config
    container=$(get_container "sharelatex" "sharelatex")
    if [ "$show_all" = "1" ]; then
        OVERSEI_SHOW_INTERNAL_URLS=1
    fi
    show_access_urls "$container"
}

require_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}✗ 请使用 root 用户运行该命令${NC}"
        exit 1
    fi
}

run_cli() {
    local command="${1:-help}"
    local service

    case "$command" in
        -h|--help|help)
            show_cli_help
            ;;
        menu)
            require_root
            run_interactive_main
            ;;
        urls|url|address|addr)
            show_cli_urls "$([ "${2:-}" = "--all" ] && echo 1 || echo 0)"
            ;;
        status)
            show_status
            ;;
        config)
            show_config_summary
            ;;
        repair)
            require_root
            load_runtime_config
            select_latest_mongo_version
            repair_installation
            ;;
        base)
            require_root
            load_runtime_config
            select_latest_mongo_version
            install_base
            ;;
        full)
            require_root
            load_runtime_config
            select_latest_mongo_version
            install_full_default
            ;;
        chinese)
            require_root
            load_runtime_config
            install_chinese
            ;;
        fonts)
            require_root
            load_runtime_config
            install_fonts
            ;;
        packages|pkg)
            require_root
            load_runtime_config
            install_packages
            ;;
        logs)
            service="${2:-sharelatex}"
            if [ -d "$TOOLKIT_DIR" ]; then
                (cd "$TOOLKIT_DIR" && show_compose_logs "$service")
            else
                echo -e "${RED}✗ 未找到 Overleaf Toolkit: $TOOLKIT_DIR${NC}"
                return 1
            fi
            ;;
        restart)
            require_root
            run_toolkit_compose up -d
            ;;
        stop)
            require_root
            run_toolkit_compose down
            ;;
        *)
            echo -e "${RED}未知命令: $command${NC}"
            show_cli_help
            return 1
            ;;
    esac
}

run_interactive_main() {
    print_banner
    require_root
    install_cli_command || true
    choose_deployment_type
    select_latest_mongo_version
    show_menu
}

if [ "$#" -gt 0 ]; then
    run_cli "$@"
else
    run_interactive_main
fi
