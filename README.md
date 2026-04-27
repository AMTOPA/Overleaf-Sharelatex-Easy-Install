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
- 🧩 **Interactive menu system** for local/server deployment, MongoDB version, fonts, Chinese support, and LaTeX packages.
- ✅ **MongoDB 8.0+ compatibility** to avoid the ShareLaTeX abort caused by MongoDB 6.x/7.x.
- 🇨🇳 **Chinese typesetting support** with `ctex`, `xeCJK`, Chinese fonts, and XeLaTeX-ready configuration.
- 🪞 **TeX Live repository compatibility** with automatic fallback to the TUNA historic `tlnet-final` mirror when the container TeX Live year is older than the current CTAN repository.
- 🔤 **Font installers** for Windows core fonts, Adobe fonts, and Noto CJK fonts, including `fontconfig`/`fc-cache` handling.
- 📦 **LaTeX package installer** for full scheme, common packages, or custom `tlmgr` package names.
- 🛠️ **Safer diagnostics** with container detection, MongoDB version checks, startup log output, and failure propagation.

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
- Network access to GitHub, Docker Hub, Ubuntu package mirrors, and CTAN/TUNA mirrors.
- Port `8888` available unless you edit the generated Overleaf Toolkit configuration manually.

### 3. Installation Options

| Installation Option | Available Options | Description |
|:--|:--|:--|
| Full Installation | Base Services + Chinese Support + Fonts + LaTeX Packages | Install all major components in sequence |
| Base Services Only | Overleaf + MongoDB + Redis | Minimal deployment using Overleaf Toolkit |
| Chinese Support | `collection-langchinese`, `xeCJK`, `ctex`, Chinese fonts | Enable Chinese document compilation |
| Additional Fonts | Windows Core Fonts / Adobe Fonts / Noto CJK / Manual Times New Roman | Expand available fonts in the ShareLaTeX container |
| LaTeX Packages | `scheme-full` / common packages / custom package list | Install packages through `tlmgr` |

---

## 🔐 MongoDB Compatibility

Recent Overleaf Community Edition images require **MongoDB 8.0 or newer**. Older installer versions could leave `MONGO_VERSION=6.0` in `config/overleaf.rc`, which caused ShareLaTeX to abort during startup.

OVERSEI now:

- Defaults to MongoDB `8.0+`.
- Rejects custom MongoDB versions below `8.0`.
- Writes `MONGO_VERSION` reliably to `config/overleaf.rc`.
- Checks the actual running MongoDB version after startup.
- Stops the installation and prints logs if MongoDB or ShareLaTeX fails.

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

---

## ✅ Validated Setup

The current installer has been tested with:

- `sharelatex/sharelatex:6.1.2`
- `mongo:8.2`
- `redis:7.4`
- Web service exposed on `0.0.0.0:8888`
- `ctex.sty` and `xeCJK.sty`
- `algorithmicx.sty` and `algorithm.sty`
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

### `tlmgr` says the local TeX Live is older than the remote repository

Run the Chinese support or package installer again. OVERSEI will detect the TeX Live year and configure a compatible historic repository automatically.

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
- Default access URL:
  - Local deployment: `http://localhost:8888`
  - Server deployment: `http://<server-ip>:8888`

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
