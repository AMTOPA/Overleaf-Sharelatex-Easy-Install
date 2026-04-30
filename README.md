<div align="center">
<h1>OVERSEI: Overleaf/ShareLaTeX One-Click Installer 🚀</h1>

<a href="README_zh.md">简体中文</a> | ENGLISH

[![GitHub release](https://img.shields.io/github/release/AMTOPA/Overleaf-Sharelatex-Easy-Install.svg?style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/releases)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Installs](https://img.shields.io/badge/dynamic/json?url=https://js.ruseo.cn/api/counter.php%3Fapi_key=3976bd1973c3c40ee8c2f7f4a12b059b%26action%3Dget%26counter_id%3D0bc7f9e8ed200173dc9205089c2d3036&label=installs&query=counter.current_count&color=blue&style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install)
[![Platform](https://img.shields.io/badge/platform-Linux%20|%20WSL-blue?style=for-the-badge)](https://en.wikipedia.org/wiki/Linux)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green?style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/graphs/commit-activity)
[![One-Click Install](https://img.shields.io/badge/INSTALL-OVERSEI-brightgreen?style=for-the-badge&logo=shell)](https://raw.githubusercontent.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/main/install.sh)

</div>

---

## ✨ Features

- 🚀 **One-command deployment** for Overleaf Community Edition through the official Overleaf Toolkit.
- 🧩 **Recommended default flow**: choose local/server deployment, then OVERSEI automatically selects the latest compatible MongoDB version and runs the recommended full install by default.
- ✅ **MongoDB 8.0+ compatibility** to avoid the ShareLaTeX abort caused by MongoDB 6.x/7.x.
- 🧩 **ARM64/aarch64 server compatibility** by configuring ShareLaTeX to run as `linux/amd64` with QEMU/binfmt support on ARM hosts.
- 🇨🇳 **Chinese UI and typesetting support** with `OVERLEAF_SITE_LANGUAGE=zh-CN`, `ctex`, `xeCJK`, Chinese fonts, Windows core fonts, and XeLaTeX-ready configuration.
- 🪞 **TeX Live repository compatibility** with automatic fallback to the TUNA historic `tlnet-final` mirror when the container TeX Live year is older than the current CTAN repository.
- 🔤 **Font installers** for Windows core fonts, Adobe fonts, and Noto CJK fonts, including `fontconfig`/`fc-cache` handling.
- 📦 **LaTeX package installer** for full scheme, common thesis-template packages, or custom `tlmgr` package names, including `collection-latexextra`, `multirow`/`bigstrut`, `cprotect`, and common CUMCM-style dependencies.
- 🧱 **Optional custom image persistence** after installing Chinese support, fonts, or packages, preventing container recreation from losing `ctex.sty` or other installed files after you confirm your templates compile correctly.
- 🛠️ **Automatic repair mode** for existing `overleaf-toolkit` checkouts, partial `config` directories, MongoDB version settings, ARM64 overrides, and service startup issues.
- 🔌 **Port conflict handling**: if `8888` is used by an old Overleaf container, it is removed; if another service owns it, OVERSEI automatically selects an available port from `8889-8999`.

---

## 🛠️ Installation Guide

### 1. Quick Install

Run as `root` on a Linux server:

```bash
bash <(curl -sL --connect-timeout 10 https://raw.githubusercontent.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/main/install.sh) || bash <(curl -sL --connect-timeout 10 https://github.math-enthusiast.top/OVERSEI/install.sh)
```

### 2. Requirements

- Linux or WSL environment with `apt-get`.
- Root privileges.
- Docker and Docker Compose. The installer can install missing Compose support when possible.
- ARM64/aarch64 servers are supported through `linux/amd64` compatibility mode for the ShareLaTeX CE image, which is usually slower than native x86_64.
- Network access to GitHub, Docker Hub, Ubuntu package mirrors, and CTAN/TUNA mirrors.
- Port `8888` is used by default.
- If `8888` is already occupied, the installer automatically selects an available port from `8889-8999`. You can also set `OVERSEI_PORT=8890` before running the script to prefer a specific port.

### 3. Installation Options

| Installation Option | Available Options | Description |
|:--|:--|:--|
| Recommended Full Installation (default) | Base Services + Chinese Support + Recommended Fonts + Common LaTeX Packages | Default option; applies recommended choices without asking for MongoDB, font, or package mode again |
| Base Services Only | Overleaf + MongoDB + Redis | Minimal deployment using Overleaf Toolkit |
| Chinese Support | Chinese web UI, `collection-langchinese`, `xeCJK`, `ctex`, SimSun/SimKai, Windows core fonts | Enable Chinese UI, CUMCM-style templates, and document compilation |
| Additional Fonts | Windows Core Fonts / Adobe Fonts / Noto CJK / Manual Times New Roman | Expand available fonts in the ShareLaTeX container |
| LaTeX Packages | `scheme-full` / common thesis-template packages / custom package list | Install packages through `tlmgr`; the common mode includes `collection-latexextra` |
| Automatic Repair | Existing toolkit/config/container setup | Use this after interrupted installs, partial installs, or repeated runs that hit toolkit initialization errors |

---

## 🔐 MongoDB Compatibility

Recent Overleaf Community Edition images require **MongoDB 8.0 or newer**. Older installer versions could leave `MONGO_VERSION=6.0` in `config/overleaf.rc`, which caused ShareLaTeX to abort during startup.

OVERSEI now:

- Defaults to MongoDB `8.0+`.
- Automatically fetches the latest compatible MongoDB tag after the deployment type is selected, falling back to a safe default if Docker Hub is unavailable.
- If `OVERSEI_MONGO_VERSION` is set, rejects values below `8.0` and falls back to automatic selection.
- Writes `MONGO_VERSION` reliably to `config/overleaf.rc`.
- Checks the actual running MongoDB version after startup.
- Stops the installation and prints logs if MongoDB or ShareLaTeX fails.

---

## 🧩 ARM64/aarch64 Compatibility

`sharelatex/sharelatex:6.1.2` currently does not provide an ARM64 image manifest. On Oracle ARM, Ampere, Raspberry Pi, and other aarch64 hosts, Docker can fail with:

```text
no matching manifest for linux/arm64/v8 in the manifest list entries
```

On ARM64 hosts, OVERSEI now:

- Installs `qemu-user-static` and `binfmt-support`.
- Writes `sharelatex.platform=linux/amd64` to `config/docker-compose.override.yml`.
- Keeps MongoDB and Redis on native ARM64 images; only ShareLaTeX uses amd64 compatibility mode.

If an older installer already failed, rerun the install command and choose automatic repair. The installer will regenerate or repair the compatibility configuration.

---

## 📚 TeX Live and Chinese Support

The ShareLaTeX image may contain a frozen TeX Live release, while the current CTAN `tlnet` repository may have already moved to the next year. In that case, `tlmgr` reports an error like:

```text
Local TeX Live (2025) is older than remote repository (2026).
Cross release updates are only supported with update-tlmgr-latest --update.
```

OVERSEI detects the local TeX Live year and automatically switches to the compatible TUNA historic archive:

```text
https://mirrors.tuna.tsinghua.edu.cn/tex-historic-archive/systems/texlive/<year>/tlnet-final
```

This keeps package installation compatible with the TeX Live version bundled in the Overleaf container.

After Chinese support, fonts, or LaTeX packages are installed, OVERSEI asks whether to commit the current `sharelatex` container to a local custom image and configure Overleaf Toolkit to use it. It is recommended to compile and verify your own templates first, then persist the image after everything works.

---

## ✅ Validated Setup

The current installer has been tested with:

- `sharelatex/sharelatex:6.1.2`
- `mongo:8.2`
- `redis:7.4`
- Web service exposed on `0.0.0.0:8888`
- `ctex.sty` and `xeCJK.sty`
- `algorithmicx.sty`, `algorithm.sty`, `multirow.sty`, and `bigstrut.sty`
- `cprotect.sty` and `suffix.sty`
- `Times New Roman`, `Arial`, `SimSun`, and `simkai.ttf`
- Noto CJK fonts
- A minimal XeLaTeX document using Chinese text and algorithm packages

---

## 🧯 Troubleshooting

### ShareLaTeX aborts after startup

Check the MongoDB version in the generated toolkit config:

```bash
grep '^MONGO_VERSION=' /root/overleaf/overleaf-toolkit/config/overleaf.rc
```

It must be `8.0` or newer.

### ARM64 servers report `no matching manifest for linux/arm64/v8`

Rerun the install command with v5.6 or newer. The installer generates:

```yaml
services:
  sharelatex:
    platform: linux/amd64
```

and installs the amd64 container compatibility dependencies.

### `tlmgr` says the local TeX Live is older than the remote repository

Run the Chinese support or package installer again. OVERSEI will detect the TeX Live year and configure a compatible historic repository automatically.

### Re-running reports `ERROR: Config files already exist, exiting`

This is Overleaf Toolkit refusing to run `bin/init` when a `config` directory already exists. Since v5.5, OVERSEI detects an existing `config/overleaf.rc` and skips `bin/init`; if `config` is incomplete, it is backed up to `config.bak.<timestamp>` before reinitialization. Rerun the installer and choose automatic repair.

### Startup reports `Bind for 0.0.0.0:8888 failed: port is already allocated`

The host port `8888` is already occupied. Since v5.6, OVERSEI checks the port before startup: old Overleaf/ShareLaTeX containers are removed automatically, while unrelated services cause the installer to switch to the next available port and print the actual access URL at the end.

### `ctex.sty`, `cprotect.sty`, `suffix.sty`, or other `.sty` files are missing

Chinese support only installs Chinese typesetting packages such as `ctex` and `xeCJK`. For thesis templates such as CUMCM, use the common thesis-template package mode, which installs `collection-latexextra` and common template dependencies. Use `scheme-full` only when you need the most complete TeX Live installation and can accept the larger disk and IO cost.

### Many `fontspec` or `Missing character ... nullfont` errors appear

CUMCM-style templates often require Windows font names such as `Times New Roman`, `Arial`, `SimSun`, and the exact file name `simkai.ttf`. Run the Chinese support installer again. OVERSEI installs Microsoft core fonts, downloads SimSun/SimKai, refreshes `fc-cache`, and adds `simkai.ttf` to the TeX Live local font tree with `mktexlsr`.

### Fonts are installed but not detected

Install a font option again. The installer ensures `fontconfig` exists and refreshes the font cache with `fc-cache`.

### Check running containers

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

---

## 📁 Default Paths

- Installer repository: this project.
- Overleaf Toolkit installation: `/root/overleaf/overleaf-toolkit`.
- Toolkit config file: `/root/overleaf/overleaf-toolkit/config/overleaf.rc`.
- Default external access URL:
  - Local deployment: `http://localhost:8888`
  - Server deployment: `http://<server-ip>:8888`
- If `8888` is occupied, use the actual port printed by the installer.
- First-time admin setup URL: `http://<ip>:<actual-port>/launchpad`.
- Login URL after initialization: `http://<ip>:<actual-port>/login`.
- After base service installation, the installer prints candidate URLs for the public IP, host IP addresses, `localhost`, `127.0.0.1`, and Docker internal container IP addresses when available. Docker internal URLs normally use port `80` and are usually reachable only from the host or Docker networks.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
