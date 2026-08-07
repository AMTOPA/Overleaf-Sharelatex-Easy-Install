

<div align="center">
<h1>OVERSEI: Instalador automático con un solo clic para Overleaf/ShareLaTeX 🚀</h1>

<a href="README_zh.md">简体中文</a> | ESPAÑOL

[![GitHub release](https://img.shields.io/github/release/AMTOPA/Overleaf-Sharelatex-Easy-Install.svg?style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/releases)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Installs](https://img.shields.io/badge/dynamic/json?url=https://js.ruseo.cn/api/counter.php%3Fapi_key=3976bd1973c3c40ee8c2f7f4a12b059b%26action%3Dget%26counter_id%3D0bc7f9e8ed200173dc9205089c2d3036&label=installs&query=counter.current_count&color=blue&style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install)
[![Platform](https://img.shields.io/badge/platform-Linux%20|%20WSL-blue?style=for-the-badge)](https://en.wikipedia.org/wiki/Linux)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green?style=for-the-badge)](https://github.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/graphs/commit-activity)
[![One-Click Install](https://img.shields.io/badge/INSTALL-OVERSEI-brightgreen?style=for-the-badge&logo=shell)](https://raw.githubusercontent.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/main/install.sh)

</div>

---

## ✨ Características

- 🚀 **Despliegue con un solo comando** para la edición comunitaria de Overleaf a través de las herramientas oficiales de Overleaf.
- 🧩 **Flujo predeterminado recomendado**: elige despliegue local/en servidor, luego OVERSEI selecciona automáticamente la versión compatible más reciente de MongoDB y ejecuta la instalación completa recomendada por defecto.
- ✅ **Compatibilidad con MongoDB 8.0+** para evitar que ShareLaTeX se detenga por usar MongoDB 6.x/7.x.
- 🧩 **Compatibilidad con servidores ARM64/aarch64** configurando ShareLaTeX para ejecutarse como `linux/amd64` con soporte QEMU/binfmt en hosts ARM.
- 🇨🇳 **Interfaz y maquetación en chino** con `OVERLEAF_SITE_LANGUAGE=zh-CN`, `ctex`, `xeCJK`, fuentes chinas, fuentes core de Windows y configuración lista para XeLaTeX.
- 🪞 **Compatibilidad con repositorios de TeX Live** con retorno automático al espejo histórico `tlnet-final` de TUNA cuando el año de TeX Live del contenedor es anterior al del repositorio actual de CTAN.
- 🔤 **Instaladores de fuentes** para fuentes core de Windows, Adobe y Noto CJK, incluido el manejo de `fontconfig`/`fc-cache`.
- 📦 **Instalador de paquetes LaTeX** para el esquema completo, paquetes comunes de plantillas de tesis o nombres de paquetes `tlmgr` personalizados, incluyendo `collection-latexextra`, `multirow`/`bigstrut`, `cprotect` y dependencias comunes al estilo CUMCM.
- 🧱 **Persistencia opcional de imagen personalizada** después de instalar soporte en chino, fuentes o paquetes, evitando que la recreación del contenedor borre `ctex.sty` u otros archivos instalados una vez confirmes que tus plantillas se compilan correctamente.
- 🛠️ **Modo de reparación automática** para clonaciones existentes de `overleaf-toolkit`, directorios `config` parciales, configuraciones de versión de MongoDB, anulaciones ARM64 y problemas de inicio de servicios.
- 🔌 **Manejo de conflictos de puerto**: si `8888` está en uso por un contenedor antiguo de Overleaf, se elimina; si otro servicio lo ocupa, OVERSEI selecciona automáticamente un puerto disponible entre `8889-8999`.
- 🧰 **Comando de gestión local**: después de la instalación, usa `oversei` o `OVERSEI` para mostrar URLs, estado, configuración, registros o continuar la instalación de paquetes/fuentes.

---

## 🛠️ Guía de instalación

### 1. Instalación rápida

Ejecútalo como `root` en un servidor Linux:

```bash
bash <(curl -sL --connect-timeout 10 https://raw.githubusercontent.com/AMTOPA/Overleaf-Sharelatex-Easy-Install/main/install.sh) || bash <(curl -sL --connect-timeout 10 https://github.math-enthusiast.top/OVERSEI/install.sh)
```

### 2. Requisitos

- Entorno Linux o WSL con `apt-get`.
- Privilegios de `root`.
- Docker y Docker Compose. El instalador puede instalar soporte de Compose faltante cuando sea posible.
- Los servidores ARM64/aarch64 son compatibles mediante el modo de compatibilidad `linux/amd64` para la imagen CE de ShareLaTeX, lo cual suele ser más lento que el nativo x86_64.
- Acceso a Internet a GitHub, Docker Hub, espejos de paquetes de Ubuntu y espejos de CTAN/TUNA.
- Se usa el puerto `8888` por defecto.
- Si `8888` ya está ocupado, el instalador selecciona automáticamente un puerto disponible entre `8889-8999`. También puedes establecer `OVERSEI_PORT=8890` antes de ejecutar el script para preferir un puerto específico.

### 3. Opciones de instalación

| Opción de instalación | Opciones disponibles | Descripción |
|:--|:--|:--|
| Instalación completa recomendada (predeterminada) | Servicios base + Soporte en chino + Fuentes recomendadas + Paquetes LaTeX comunes | Opción predeterminada; aplica las opciones recomendadas sin pedir nuevamente la versión de MongoDB, modo de fuentes o paquetes |
| Solo servicios base | Overleaf + MongoDB + Redis | Despliegue mínimo usando las herramientas de Overleaf |
| Soporte en chino | Interfaz web en chino, `collection-langchinese`, `xeCJK`, `ctex`, SimSun/SimKai, fuentes core de Windows | Habilita la interfaz en chino, plantillas al estilo CUMCM y compilación de documentos |
| Fuentes adicionales | Fuentes Core de Windows / Adobe Fonts / Noto CJK / Times New Roman manual | Expande las fuentes disponibles en el contenedor de ShareLaTeX |
| Paquetes LaTeX | `scheme-full` / paquetes comunes de plantillas de tesis / lista de paquetes personalizada | Instala paquetes a través de `tlmgr`; el modo común incluye `collection-latexextra` |
| Reparación automática | Configuración existente de toolkit/config/contenedor | Úsalo después de instalaciones interrumpidas, parciales o ejecuciones repetidas que encuentren errores de inicialización del toolkit |

### 4. Comando de gestión local

El instalador escribe `/usr/local/bin/oversei` y un alias en mayúsculas `OVERSEI`. Después, no necesitarás descargar el instalador nuevamente:

```bash
oversei --help
oversei urls
oversei status
oversei packages
OVERSEI repair
```

Comandos comunes:

| Comando | Descripción |
|:--|:--|
| `oversei urls` | Muestra URLs de acceso recomendadas y limpias |
| `oversei urls --all` | También muestra URLs internas de Docker |
| `oversei status` | Muestra el estado de los contenedores y puertos |
| `oversei config` | Muestra los valores clave de configuración del Toolkit |
| `oversei repair` | Detecta y repara una instalación existente |
| `oversei packages` | Abre el instalador de paquetes LaTeX |
| `oversei logs sharelatex` | Muestra registros recientes de ShareLaTeX |

---

## 🔐 Compatibilidad con MongoDB

Las imágenes recientes de Overleaf Community Edition requieren **MongoDB 8.0 o posterior**. Versiones anteriores del instalador podían dejar `MONGO_VERSION=6.0` en `config/overleaf.rc`, lo que provocaba que ShareLaTeX se detuviera durante el inicio.

OVERSEI ahora:

- Usa MongoDB `8.0+` por defecto.
- Obtiene automáticamente la etiqueta compatible más reciente de MongoDB después de seleccionar el tipo de despliegue, volviendo a un valor seguro por defecto si Docker Hub no está disponible.
- Si `OVERSEI_MONGO_VERSION` está configurado, rechaza valores inferiores a `8.0` y vuelve a la selección automática.
- Escribe `MONGO_VERSION` de forma fiable en `config/overleaf.rc`.
- Verifica la versión real en ejecución de MongoDB después del inicio.
- Detiene la instalación e imprime registros si MongoDB o ShareLaTeX fallan.

---

## 🧩 Compatibilidad con ARM64/aarch64

Actualmente, `sharelatex/sharelatex:6.1.2` no proporciona un manifiesto de imagen para ARM64. En hosts Oracle ARM, Ampere, Raspberry Pi y otros aarch64, Docker puede fallar con:

```text
no matching manifest for linux/arm64/v8 in the manifest list entries
```

En hosts ARM64, OVERSEI ahora:

- Instala `qemu-user-static` y `binfmt-support`.
- Monta y habilita `binfmt_misc` para `qemu-x86_64`; si el servicio de la distribución no lo registra, OVERSEI ejecuta automáticamente un registrador binfmt de Docker con privilegios.
- Se detiene antes de iniciar ShareLaTeX si la emulación amd64 aún no está disponible, evitando reinicios repetidos con el error `exec /sbin/my_init: exec format error`.
- Escribe `sharelatex.platform=linux/amd64` en `config/docker-compose.override.yml`.
- Mantiene MongoDB y Redis en imágenes nativas ARM64; solo ShareLaTeX usa el modo de compatibilidad amd64.

Si un instalador anterior ya falló, vuelve a ejecutar el comando de instalación y elige reparación automática. El instalador regenerará o reparará la configuración de compatibilidad.

---

## 📚 TeX Live y soporte en chino

La imagen de ShareLaTeX puede contener una versión congelada de TeX Live, mientras que el repositorio actual de CTAN `tlnet` puede haber avanzado al siguiente año. En ese caso, `tlmgr` reportará un error como:

```text
Local TeX Live (2025) is older than remote repository (2026).
Cross release updates are only supported with update-tlmgr-latest --update.
```

OVERSEI detecta el año de TeX Live local y cambia automáticamente al archivo histórico compatible de TUNA:

```text
https://mirrors.tuna.tsinghua.edu.cn/tex-historic-archive/systems/texlive/<year>/tlnet-final
```

Esto mantiene la instalación de paquetes compatible con la versión de TeX Live incluida en el contenedor de Overleaf.

Después de instalar el soporte en chino, fuentes o paquetes LaTeX, OVERSEI pregunta si deseas confirmar el contenedor `sharelatex` actual como una imagen personalizada local y configurar Overleaf Toolkit para usarla. Se recomienda compilar y verificar tus propias plantillas primero, y luego persistir la imagen una vez que todo funcione correctamente.

---

## ✅ Configuración validada

El instalador actual ha sido probado con:

- `sharelatex/sharelatex:6.1.2`
- `mongo:8.2`
- `redis:7.4`
- Servicio web expuesto en `0.0.0.0:8888`
- `ctex.sty` y `xeCJK.sty`
- `algorithmicx.sty`, `algorithm.sty`, `multirow.sty` y `bigstrut.sty`
- `cprotect.sty` y `suffix.sty`
- `Times New Roman`, `Arial`, `SimSun` y `simkai.ttf`
- Fuentes Noto CJK
- Un documento mínimo de XeLaTeX que usa texto en chino y paquetes de algoritmos

---

## 🧯 Solución de problemas

### ShareLaTeX se detiene después del inicio

Verifica la versión de MongoDB en la configuración generada del toolkit:

```bash
grep '^MONGO_VERSION=' /root/overleaf/overleaf-toolkit/config/overleaf.rc
```

Debe ser `8.0` o posterior.

### Los servidores ARM64 reportan `no matching manifest for linux/arm64/v8`

Vuelve a ejecutar el comando de instalación con la v5.6 o posterior. El instalador genera:

```yaml
services:
  sharelatex:
    platform: linux/amd64
```

e instala las dependencias de compatibilidad de contenedores amd64.

### `tlmgr` indica que el TeX Live local es anterior al repositorio remoto

Ejecuta nuevamente el instalador de soporte en chino o de paquetes. OVERSEI detectará el año de TeX Live y configurará automáticamente un repositorio histórico compatible.

### Al volver a ejecutar aparece `ERROR: Config files already exist, exiting`

Esto ocurre porque Overleaf Toolkit se niega a ejecutar `bin/init` cuando ya existe un directorio `config`. Desde la v5.5, OVERSEI detecta un `config/overleaf.rc` existente y omite `bin/init`; si `config` está incompleto, se hace una copia de seguridad en `config.bak.<timestamp>` antes de la reinicialización. Vuelve a ejecutar el instalador y elige reparación automática.

### El inicio reporta `Bind for 0.0.0.0:8888 failed: port is already allocated`

El puerto `8888` del host ya está ocupado. Desde la v5.6, OVERSEI verifica el puerto antes del inicio: los contenedores antiguos de Overleaf/ShareLaTeX se eliminan automáticamente, mientras que los servicios no relacionados hacen que el instalador cambie al siguiente puerto disponible e imprima la URL de acceso real al final.

### Faltan `ctex.sty`, `cprotect.sty`, `suffix.sty` u otros archivos `.sty`

El soporte en chino solo instala paquetes de maquetación en chino como `ctex` y `xeCJK`. Para plantillas de tesis como CUMCM, usa el modo de paquetes comunes de plantillas de tesis, que instala `collection-latexextra` y dependencias comunes de plantillas. Usa `scheme-full` solo cuando necesites la instalación más completa de TeX Live y puedas aceptar el mayor costo de disco y E/S.

### Aparecen muchos errores de `fontspec` o `Missing character ... nullfont`

Las plantillas al estilo CUMCM a menudo requieren nombres de fuentes de Windows como `Times New Roman`, `Arial`, `SimSun` y el nombre de archivo exacto `simkai.ttf`. Ejecuta nuevamente el instalador de soporte en chino. OVERSEI instala las fuentes core de Microsoft, descarga SimSun/SimKai, actualiza `fc-cache` y agrega `simkai.ttf` al árbol de fuentes local de TeX Live con `mktexlsr`.

### Las fuentes están instaladas pero no se detectan

Instala una opción de fuentes nuevamente. El instalador se asegura de que `fontconfig` exista y actualiza la caché de fuentes con `fc-cache`.

### Verificar contenedores en ejecución

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

---

## 📁 Rutas predeterminadas

- Repositorio del instalador: este proyecto.
- Instalación de Overleaf Toolkit: `/root/overleaf/overleaf-toolkit`.
- Archivo de configuración del Toolkit: `/root/overleaf/overleaf-toolkit/config/overleaf.rc`.
- URL de acceso externo predeterminada:
  - Despliegue local: `http://localhost:8888`
  - Despliegue en servidor: `http://<ip-del-servidor>:8888`
- Si `8888` está ocupado, usa el puerto real impreso por el instalador.
- URL de configuración inicial de administrador: `http://<ip>:<puerto-real>/launchpad`.
- URL de inicio de sesión después de la inicialización: `http://<ip>:<puerto-real>/login`.
- Después de instalar los servicios base, el instalador imprime por defecto las URLs públicas, URLs de LAN del host, `localhost` y `127.0.0.1`. Para incluir URLs internas de Docker, ejecuta `oversei urls --all`.

---

## 📄 Licencia

Este proyecto está licenciado bajo la [Licencia MIT](LICENSE).
