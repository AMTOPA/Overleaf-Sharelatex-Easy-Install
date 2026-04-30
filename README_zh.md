<div align="center">
<h1>OVERSEI: Overleaf/ShareLaTeX 一键安装工具 🚀</h1>

简体中文 | <a href="README.md">ENGLISH</a>

[![GitHub release](https://img.shields.io/github/release/AMTOPA/Overleaf-Sharelatex-Easy-Install.svg?style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/releases)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Installs](https://img.shields.io/badge/dynamic/json?url=https://js.ruseo.cn/api/counter.php%3Fapi_key=3976bd1973c3c40ee8c2f7f4a12b059b%26action%3Dget%26counter_id%3D0bc7f9e8ed200173dc9205089c2d3036&label=installs&query=counter.current_count&color=blue&style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install)
[![Platform](https://img.shields.io/badge/platform-Linux%20|%20WSL-blue?style=for-the-badge)](https://zh.wikipedia.org/wiki/Linux)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green?style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/graphs/commit-activity)
[![一键安装](https://img.shields.io/badge/一键安装-绿色-brightgreen?style=for-the-badge&logo=shell)](https://raw.githubusercontent.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/main/install.sh)

</div>

---

## ✨ 功能特性

- 🚀 **单命令部署**，基于官方 Overleaf Toolkit 部署 Overleaf Community Edition。
- 🧩 **交互式菜单**，支持本地/服务器部署、MongoDB 版本、中文支持、字体和 LaTeX 宏包安装。
- ✅ **MongoDB 8.0+ 兼容修复**，避免 MongoDB 6.x/7.x 导致 ShareLaTeX 启动 abort。
- 🧩 **ARM64/aarch64 服务器兼容**，在 ARM 主机上自动为 ShareLaTeX 配置 `linux/amd64` 平台并安装 QEMU/binfmt 兼容依赖。
- 🇨🇳 **中文界面与中文排版支持**，设置 `OVERLEAF_SITE_LANGUAGE=zh-CN`，安装 `ctex`、`xeCJK`、中文字体、Windows 核心字体，并支持 XeLaTeX 编译。
- 🪞 **TeX Live 镜像兼容处理**，当容器内 TeX Live 年份落后于当前 CTAN 源时，自动切换到清华历史归档 `tlnet-final`。
- 🔤 **字体安装器**，支持 Windows 核心字体、Adobe 字体、思源/Noto CJK 字体，并自动处理 `fontconfig` 与 `fc-cache`。
- 📦 **LaTeX 宏包安装器**，支持完整宏包、常用论文模板宏包和自定义 `tlmgr` 包名，并包含 `collection-latexextra`、`multirow`/`bigstrut`、`cprotect` 以及 CUMCM 模板常见依赖。
- 🧱 **可选自定义镜像持久化**，安装中文支持、字体或宏包后，可在确认模板能正常编译后再固化当前容器，避免容器重建后丢失 `ctex.sty` 等已安装文件。
- 🛠️ **更可靠的诊断与错误处理**，包括容器检测、MongoDB 实际版本检查、启动日志输出和失败中止。

---

## 🛠️ 安装指南

### 1. 快速安装

请使用 `root` 用户在 Linux 服务器上运行：

```bash
bash <(curl -sL --connect-timeout 10 https://raw.githubusercontent.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/main/install.sh) || bash <(curl -sL --connect-timeout 10 https://github.math-enthusiast.top/OVERSEI/install.sh)
```

### 2. 环境要求

- Linux 或 WSL 环境，并支持 `apt-get`。
- `root` 权限。
- Docker 与 Docker Compose。缺少 Compose 支持时，脚本会尽量自动安装。
- ARM64/aarch64 服务器可以部署，但 ShareLaTeX 官方 CE 镜像会通过 `linux/amd64` 兼容模式运行，性能通常低于 x86_64 原生服务器。
- 能访问 GitHub、Docker Hub、Ubuntu 软件源以及 CTAN/清华镜像源。
- 默认使用 `8888` 端口。如需修改端口，可在生成 Overleaf Toolkit 配置后手动调整。

### 3. 安装选项

| 安装选项 | 可选内容 | 描述 |
|:--|:--|:--|
| 完整安装 | 基础服务 + 中文支持 + 字体 + LaTeX 宏包 | 按顺序安装主要组件 |
| 仅安装基础服务 | Overleaf + MongoDB + Redis | 基于 Overleaf Toolkit 的最小化部署 |
| 安装中文支持包 | 中文网页界面、`collection-langchinese`、`xeCJK`、`ctex`、SimSun/SimKai、Windows 核心字体 | 启用中文界面、CUMCM 模板和中文文档编译能力 |
| 安装额外字体包 | Windows 核心字体 / Adobe 字体 / 思源字体 / 手动 Times New Roman | 扩展 ShareLaTeX 容器内可用字体 |
| 安装 LaTeX 宏包 | `scheme-full` / 常用论文模板宏包 / 自定义包列表 | 通过 `tlmgr` 安装宏包；常用模式包含 `collection-latexextra` |

---

## 🔐 MongoDB 兼容性

新版 Overleaf Community Edition 要求 **MongoDB 8.0 或更高版本**。旧版本安装脚本可能会在 `config/overleaf.rc` 中留下 `MONGO_VERSION=6.0`，从而导致 ShareLaTeX 启动时直接 abort。

OVERSEI 现在会：

- 默认选择 MongoDB `8.0+`。
- 拒绝低于 `8.0` 的自定义 MongoDB 版本。
- 可靠写入 `config/overleaf.rc` 中的 `MONGO_VERSION`。
- 启动后检查实际运行的 MongoDB 版本。
- MongoDB 或 ShareLaTeX 启动失败时中止安装并输出日志。

---

## 🧩 ARM64/aarch64 兼容性

`sharelatex/sharelatex:6.1.2` 当前没有 ARM64 镜像清单。在 Oracle ARM、Ampere、树莓派等 aarch64 主机上，直接拉取会出现：

```text
no matching manifest for linux/arm64/v8 in the manifest list entries
```

OVERSEI 会在 ARM64 主机上自动：

- 安装 `qemu-user-static` 与 `binfmt-support`。
- 在 `config/docker-compose.override.yml` 写入 `sharelatex.platform=linux/amd64`。
- 让 MongoDB/Redis 继续使用原生 ARM64 镜像，只有 ShareLaTeX 走 amd64 兼容模式。

如果已经用旧脚本失败过，重新运行安装命令即可；也可以删除 `/root/overleaf/overleaf-toolkit/config/docker-compose.override.yml` 后再重跑，让脚本重新生成兼容配置。

---

## 📚 TeX Live 与中文支持

ShareLaTeX 镜像内可能包含冻结的 TeX Live 版本，而当前 CTAN `tlnet` 源可能已经进入下一年度。这时 `tlmgr` 会报错，例如：

```text
Local TeX Live (2025) is older than remote repository (2026).
Cross release updates are only supported with update-tlmgr-latest --update.
```

OVERSEI 会自动识别容器内 TeX Live 年份，并切换到兼容的清华历史归档源：

```text
https://mirrors.tuna.tsinghua.edu.cn/tex-historic-archive/systems/texlive/<year>/tlnet-final
```

这样可以保证安装的宏包与 Overleaf 容器内自带的 TeX Live 版本一致。

安装中文支持、字体或 LaTeX 宏包后，OVERSEI 会询问是否把当前 `sharelatex` 容器固化为本地自定义镜像，并配置 Overleaf Toolkit 后续使用该镜像。建议先用自己的模板完成编译验证，确认无误后再固化。

---

## ✅ 已验证环境

当前安装脚本已在以下环境中验证：

- `sharelatex/sharelatex:6.1.2`
- `mongo:8.2`
- `redis:7.4`
- Web 服务监听 `0.0.0.0:8888`
- `ctex.sty` 与 `xeCJK.sty`
- `algorithmicx.sty`、`algorithm.sty`、`multirow.sty` 与 `bigstrut.sty`
- `cprotect.sty` 与 `suffix.sty`
- `Times New Roman`、`Arial`、`SimSun` 与 `simkai.ttf`
- Noto CJK 字体
- 最小中文 + 算法宏包 XeLaTeX 文档编译通过

---

## 🧯 故障排查

### ShareLaTeX 启动后 abort

检查生成的 Overleaf Toolkit 配置：

```bash
grep '^MONGO_VERSION=' /root/overleaf/overleaf-toolkit/config/overleaf.rc
```

版本必须是 `8.0` 或更高。

### ARM64 服务器提示 `no matching manifest for linux/arm64/v8`

请使用 v5.4 或更新的安装脚本重新运行安装命令。脚本会自动生成：

```yaml
services:
  sharelatex:
    platform: linux/amd64
```

并安装 amd64 容器兼容依赖。

### `tlmgr` 提示本地 TeX Live 旧于远程源

重新运行中文支持或宏包安装选项。OVERSEI 会自动识别 TeX Live 年份，并配置兼容的历史归档源。

### 缺少 `ctex.sty`、`cprotect.sty`、`suffix.sty` 或其他 `.sty` 文件

中文支持只安装 `ctex`、`xeCJK` 等中文排版包，不等于完整 TeX Live。CUMCM 等论文模板建议使用“常用论文模板宏包”模式，该模式会安装 `collection-latexextra` 和常见模板依赖。只有在确实需要最完整 TeX Live，且能接受更大的磁盘占用和 IO 压力时，才建议选择 `scheme-full`。

### 出现大量 `fontspec` 或 `Missing character ... nullfont` 错误

CUMCM 等模板常会强制使用 `Times New Roman`、`Arial`、`SimSun` 和精确文件名 `simkai.ttf`。重新运行中文支持安装选项即可。OVERSEI 会安装 Microsoft core fonts，下载 SimSun/SimKai，刷新 `fc-cache`，并通过 `mktexlsr` 把 `simkai.ttf` 加入 TeX Live 本地字体树。

### 字体安装后无法识别

重新运行字体安装选项。脚本会确保容器内存在 `fontconfig`，并使用 `fc-cache` 刷新字体缓存。

### 查看运行中的容器

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

---

## 📁 默认路径

- 安装器仓库：当前项目。
- Overleaf Toolkit 安装目录：`/root/overleaf/overleaf-toolkit`。
- Toolkit 配置文件：`/root/overleaf/overleaf-toolkit/config/overleaf.rc`。
- 默认外部访问地址：
  - 本地部署：`http://localhost:8888`
  - 服务器部署：`http://<server-ip>:8888`
- 首次管理员初始化地址：`http://<ip>:8888/launchpad`。
- 初始化后的登录地址：`http://<ip>:8888/login`。
- 基础服务安装成功后，脚本会自动输出公网 IP、宿主机 IP、`localhost`、`127.0.0.1`，以及可检测到的 Docker 容器内部 IP 候选地址。Docker 内部地址通常使用 `80` 端口，一般只适合宿主机或 Docker 网络内部访问。

---

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。
