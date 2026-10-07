<div align="center">

<pre>
████████╗███████╗██████╗ ███╗   ███╗██╗███╗   ██╗ █████╗ ██╗
╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║████╗  ██║██╔══██╗██║
   ██║   █████╗  ██████╔╝██╔████╔██║██║██╔██╗ ██║███████║██║
   ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║██║╚██╗██║██╔══██║██║
   ██║   ███████╗██║  ██║██║ ╚═╝ ██║██║██║ ╚████║██║  ██║███████╗
   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝
 D O C E N C I A   F P   ·   P o w e r S h e l l   ·   C M D   ·   B a s h
</pre>

<img src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white"/>
<img src="https://img.shields.io/badge/CMD-4D4D4D?style=for-the-badge&logo=windows-terminal&logoColor=white"/>
<img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white"/>
<img src="https://img.shields.io/badge/Windows_11-0078D4?style=for-the-badge&logo=windows&logoColor=white"/>
<img src="https://img.shields.io/badge/WSL2-FCC624?style=for-the-badge&logo=linux&logoColor=black"/>
<img src="https://img.shields.io/badge/Licencia-MIT-green?style=for-the-badge"/>

**Sistema de entrenamiento interactivo de terminal para Formación Profesional**

*Dojo · Tatami · Reto · Forja · Santuario · Repaso espaciado Leitner · 14 módulos · 3 plataformas*

**🇪🇸 [Español](#-qué-es-esto) · 🌍 [English](#-english-version)**

</div>

---

## ✨ Qué es esto

Un sistema completo para que los alumnos de FP aprendan a usar la terminal **practicando**, no leyendo apuntes. Incluye **14 scripts de entrenamiento**, **7 documentos de apoyo** y un **sistema de repaso espaciado** que recuerda lo que fallas y te lo vuelve a preguntar.

Todo funciona directamente en **PowerShell 5.1** (el que viene con Windows 10/11), sin instalar nada extra.

---

## 🥋 Los 3 motores de entrenamiento

| Motor | Qué hace | Ejemplo |
|---|---|---|
| **Dojo** | Preguntas rápidas: ¿qué comando hace X? | `dojo -Modo Linux -Preguntas 10` |
| **Tatami** | Misiones en sandbox: ejecuta comandos reales y se comprueba el resultado | `tatami` |
| **Reto** | Tareas por pasos: flujos completos de administración de sistemas | `reto` |

**Más motores de scripting:**

| Motor | Qué hace | Comando |
|---|---|---|
| **PwShell** / **PwShell2** | ~82 retos de scripting PowerShell (niveles 1-5) | `pwshell` / `pwshell2` |
| **Comandos** | Scripting CMD / .bat | `comandos` |
| **Forja** | Escribe scripts completos de PowerShell con tests automáticos | `forja` |
| **Santuario** | Lo mismo en Bash, ejecutado en WSL2 | `santuario` |

```powershell
dojo -Modo Linux -Preguntas 5     # preguntas rápidas de Linux
tatami2                            # misión práctica avanzada
reto                               # reto por pasos
forja                              # escribe una función; Enter = probar
santuario                          # escribe una función en bash (WSL2)
dojo -Repaso                       # solo lo que toca repasar hoy
rosetta                            # tabla Linux / PowerShell / CMD
```

---

## 📦 Sistema de repaso espaciado (Leitner)

Todos los motores comparten un sistema que recuerda tu progreso:

| Caja | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Vuelve a salir | siempre | 1 día | 3 días | 7 días | 21 días |

**Acierto** → sube una caja (sale menos) · **Fallo o pista** → baja a caja 1 (sale enseguida)

El progreso se guarda en `%LOCALAPPDATA%\CyberProfile\progreso.json` (fuera del repo, local de cada alumno).

---

## 🚀 Instalación

```powershell
# 1. Clona el repositorio
git clone https://github.com/HEO-80/terminal-docencia-fp.git

# 2. Permite la ejecución de scripts (solo la primera vez)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 3. Carga el entrenamiento
cd terminal-docencia-fp/entrenamiento
. .\Cyberpunk2077.ps1

# 4. Empieza
dojo
```

> Si Windows bloquea los scripts descargados: `Get-ChildItem . -Recurse -Filter *.ps1 | Unblock-File`

📖 Guía detallada con solución de problemas en **[docs/instalacion.md](docs/instalacion.md)**

---

## 🗂️ Estructura

```
terminal-docencia-fp/
├── entrenamiento/                     # 14 scripts de entrenamiento
│   ├── Cyberpunk2077.ps1              ← cargador principal + tema visual
│   ├── Motor.ps1                      ← motor Leitner + motores Dojo/Tatami
│   ├── Dojo.ps1 · Dojo2.ps1          ← Q&A nivel 1 (nombres) y nivel 2 (comandos completos)
│   ├── Tatami1.ps1 · Tatami2.ps1     ← misiones en sandbox nivel 1 y 2
│   ├── Reto.ps1                       ← retos por pasos (administración de sistemas)
│   ├── PwShell.ps1 · PwShell2.ps1    ← scripting PowerShell niveles 1-5
│   ├── Comandos.ps1                   ← scripting CMD / .bat
│   ├── Forja.ps1                      ← escribir scripts completos (PowerShell)
│   ├── Santuario.ps1                  ← escribir scripts completos (Bash vía WSL2)
│   ├── Dev.ps1                        ← herramientas de desarrollo
│   └── Developer2077.ps1              ← cargador alternativo con Dev.ps1
│
├── docs/                              # Documentación
│   ├── instalacion.md                 ← instalar y empezar
│   ├── motores.md                     ← cómo funcionan los 3 motores (con sintaxis PS)
│   ├── anadir-ejercicios.md           ← cómo crear tus propios ejercicios
│   ├── comandos-esenciales.md         ← referencia cruzada Linux / PowerShell / CMD
│   ├── modulos-entrenamiento.md       ← qué hace cada uno de los 14 scripts
│   ├── personalizar-terminal.md       ← guía de personalización de terminal
│   └── ejercicio-montar-terminal.md   ← práctica: monta tu terminal profesional
│
├── LICENSE                            ← MIT
└── README.md
```

---

## 📚 Documentación

### Para profesores

| Documento | Descripción |
|---|---|
| **[Instalación](docs/instalacion.md)** | Requisitos, pasos, comandos disponibles, auto-carga en $PROFILE, problemas comunes |
| **[Cómo funcionan los motores](docs/motores.md)** | Explicación técnica de los 3 motores con sintaxis PowerShell desde cero |
| **[Cómo añadir ejercicios](docs/anadir-ejercicios.md)** | Plantillas y ejemplos reales para crear ejercicios en Dojo, Tatami y Reto |
| **[Descripción de los 14 módulos](docs/modulos-entrenamiento.md)** | Qué entrena cada script, diagrama de dependencias y ruta de 12 semanas |
| **[Comandos esenciales](docs/comandos-esenciales.md)** | ~80 tareas con su equivalente en Linux, PowerShell y CMD |

### Para alumnos

| Documento | Descripción |
|---|---|
| **[Personalizar tu terminal](docs/personalizar-terminal.md)** | Windows Terminal, Oh My Posh, Nerd Fonts, módulos, CLI tools, $PROFILE |
| **[Ejercicio: Monta tu terminal](docs/ejercicio-montar-terminal.md)** | Práctica guiada en 6 partes con 16 preguntas y rúbrica de evaluación |

---

## 🗺️ Ruta de aprendizaje recomendada

| Semana | Módulos | Objetivo |
|---|---|---|
| 1-2 | `dojo` + `tatami` | Conocer los comandos básicos en las 3 plataformas |
| 3-4 | `reto` (nivel 1) + `dojo2` | Tareas reales de archivos y carpetas, comandos completos |
| 5-6 | `tatami2` + `reto` (nivel 2) | Pipelines, filtros, exportar datos |
| 7-8 | `pwshell` | Empezar a escribir scripts de PowerShell |
| 9-10 | `pwshell2` + `forja` | Scripting avanzado y scripts completos con tests |
| 11-12 | `comandos` + `santuario` | CMD/.bat y Bash para completar las 3 plataformas |

---

## 🎯 Para quién es

- **Alumnos de FP** (ASIR, DAM, DAW, SMR) que necesitan aprender a usar la terminal
- **Profesores de FP** que buscan material práctico y listo para usar en clase
- **Autodidactas** que quieran aprender PowerShell, CMD o Bash de forma práctica
- **Sysadmins** que quieran repasar o cambiar de plataforma

---

## 🛠️ Herramientas recomendadas para tu terminal

El sistema de entrenamiento funciona sin nada extra, pero si quieres una terminal profesional, estas son las herramientas que merece la pena tener:

### Imprescindibles

| Herramienta | Qué hace | Instalar |
|---|---|---|
| **[Windows Terminal](https://aka.ms/terminal)** | Emulador moderno: pestañas, paneles, temas, GPU | Microsoft Store |
| **[PowerShell 7](https://github.com/PowerShell/PowerShell)** | PowerShell multiplataforma, más rápido y moderno | `winget install Microsoft.PowerShell` |
| **[Git](https://git-scm.com/)** | Control de versiones | `winget install Git.Git` |
| **[VS Code](https://code.visualstudio.com/)** | Editor de código con terminal integrada | `winget install Microsoft.VisualStudioCode` |
| **[WSL2](https://learn.microsoft.com/windows/wsl/)** | Linux dentro de Windows | `wsl --install` |

### Personalización de terminal

| Herramienta | Qué hace | Instalar |
|---|---|---|
| **[Oh My Posh](https://ohmyposh.dev/)** | Prompt con info de git, ruta, hora, errores... | `winget install JanDeDobbeleer.OhMyPosh` |
| **[Nerd Fonts](https://www.nerdfonts.com/)** | Fuentes con iconos (necesarias para OMP) | `oh-my-posh font install Hack` |
| **[Terminal-Icons](https://github.com/devblackops/Terminal-Icons)** | Iconos de archivos en `Get-ChildItem` | `Install-Module Terminal-Icons -Scope CurrentUser` |
| **[PSReadLine](https://github.com/PowerShell/PSReadLine)** | Autocompletado predictivo del historial | Ya viene instalado, solo configurar |
| **[z](https://github.com/badmotorfinger/z)** | Saltar a carpetas frecuentes (`z proyecto`) | `Install-Module z -Scope CurrentUser` |
| **[posh-git](https://github.com/dahlbyk/posh-git)** | Info de git en el prompt (si no usas OMP) | `Install-Module posh-git -Scope CurrentUser` |

### Herramientas CLI avanzadas

| Herramienta | Qué hace | Instalar |
|---|---|---|
| **[bat](https://github.com/sharkdp/bat)** | `cat` con colores y números de línea | `winget install sharkdp.bat` |
| **[fzf](https://github.com/junegunn/fzf)** | Buscador fuzzy interactivo | `winget install junegunn.fzf` |
| **[ripgrep](https://github.com/BurntSushi/ripgrep)** | `grep` ultrarrápido y recursivo | `winget install BurntSushi.ripgrep.MSVC` |
| **[fd](https://github.com/sharkdp/fd)** | `find` más rápido e intuitivo | `winget install sharkdp.fd` |
| **[jq](https://jqlang.github.io/jq/)** | Procesar JSON desde la terminal | `winget install jqlang.jq` |
| **[zoxide](https://github.com/ajeetdsouza/zoxide)** | Alternativa a `z` escrita en Rust, más rápida | `winget install ajeetdsouza.zoxide` |
| **[Docker](https://www.docker.com/)** | Contenedores para labs, bases de datos, servicios | `winget install Docker.DockerDesktop` |
| **[Node.js](https://nodejs.org/)** | Runtime JavaScript (para DAM/DAW) | `winget install OpenJS.NodeJS.LTS` |
| **[Python](https://www.python.org/)** | Scripting, automatización, datos | `winget install Python.Python.3.12` |

> 📖 Guía completa de personalización en **[docs/personalizar-terminal.md](docs/personalizar-terminal.md)**
>
> 🎯 Ejercicio guiado para alumnos en **[docs/ejercicio-montar-terminal.md](docs/ejercicio-montar-terminal.md)**

### 👀 ¿Quieres ver cómo queda todo montado?

Mi terminal personal usa este mismo sistema de entrenamiento dentro de un entorno Cyberpunk con dashboard, Oh My Posh, zoxide, fzf y más. Puedes verlo en:

➡️ **[powershell-cyberpunk](https://github.com/HEO-80/powershell-cyberpunk)** — Mi configuración personal de PowerShell con tema NETWATCH

---

## ⚙️ Compatibilidad

| Entorno | Estado |
|---|---|
| PowerShell 5.1 (Windows 10/11) | ✅ Soportado |
| PowerShell 7.x | ✅ Soportado |
| Windows Terminal | ✅ Soportado |
| Terminal integrado de VS Code | ✅ Soportado |
| WSL2 (para Santuario) | ✅ Opcional |

> Los archivos `.ps1` deben guardarse como **UTF-8 con BOM** y con saltos de línea **CRLF** para compatibilidad con PowerShell 5.1.

---

## 🤝 Contribuir

¿Quieres añadir ejercicios, corregir algo o traducir? Las Pull Requests son bienvenidas.

Lee **[docs/anadir-ejercicios.md](docs/anadir-ejercicios.md)** para ver cómo se estructura un ejercicio en cada motor — incluye plantillas y un checklist de publicación.

---

## 📄 Licencia

Este proyecto está bajo la licencia [MIT](LICENSE). Úsalo, modifícalo y compártelo libremente.

---

## 🌍 English Version

### What is this?

A complete interactive training system for learning the terminal (PowerShell, CMD and Bash) designed for vocational training students in Spain (FP). It includes **14 training scripts**, **7 support documents** and a **spaced repetition system** (Leitner) that tracks what you get wrong and brings it back at the right time.

Everything runs on **PowerShell 5.1** (included in Windows 10/11) with no extra dependencies.

### Training engines

| Engine | What it does | Command |
|---|---|---|
| **Dojo** / **Dojo2** | Q&A: what command does X? (name only / full command) | `dojo` / `dojo2` |
| **Tatami** / **Tatami2** | Hands-on missions in a sandbox: you run real commands, the result is checked | `tatami` / `tatami2` |
| **Reto** | Multi-step sysadmin tasks with guided verification | `reto` |
| **PwShell** / **PwShell2** | ~82 PowerShell scripting challenges (levels 1-5) | `pwshell` / `pwshell2` |
| **Comandos** | CMD / .bat scripting | `comandos` |
| **Forja** | Write complete PowerShell scripts, tested automatically | `forja` |
| **Santuario** | Same for Bash, running in WSL2 | `santuario` |

### Quick install

```powershell
git clone https://github.com/HEO-80/terminal-docencia-fp.git
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
cd terminal-docencia-fp/entrenamiento
. .\Cyberpunk2077.ps1
dojo
```

Full install guide: **[docs/instalacion.md](docs/instalacion.md)**

---

<div align="center">

### 🧑‍💻 Autor / Author

**Hector Eduardo Oviedo** — Profesor de FP (DAM, DAW, SMR, ASIR) · Zaragoza, España

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/hectoreduardooviedo/)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/HEO-80)

<sub>Terminal Docencia FP · Material libre para la comunidad educativa · MIT License</sub>

</div>
