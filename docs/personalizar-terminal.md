# Guía de personalización de terminal en Windows

Cómo montar una terminal moderna, productiva y con buena pinta en Windows. Todo lo que puedes instalar y qué hace cada cosa.

---

## 1. Windows Terminal

**Qué es:** El emulador de terminal moderno de Microsoft. Reemplaza al viejo cmd.exe y la ventana clásica de PowerShell.

**Qué te da:** Pestañas, paneles divididos, perfiles múltiples (PowerShell, CMD, WSL, SSH...), transparencia, imágenes de fondo, colores configurables, renderizado GPU.

**Instalar:** Microsoft Store → buscar "Windows Terminal" → Instalar (gratis)

**Configuración:** Menú ☰ → Configuración (o `Ctrl+,`). Todo se guarda en un archivo JSON (`settings.json`) que puedes editar directamente.

**Ajustes recomendados para empezar:**
- **Perfil predeterminado:** PowerShell (no Windows PowerShell — son diferentes)
- **Esquema de color:** "One Half Dark" o "Dark+" (que es el de VS Code)
- **Opacidad:** 85-90% con acrílico activado para efecto cristal
- **Fuente:** Una Nerd Font (ver sección 3)

---

## 2. PowerShell 7 vs PowerShell 5.1

**PowerShell 5.1 (Windows PowerShell):**
- Viene con Windows 10/11
- Icono azul
- Ubicación: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- Compatible con todo el ecosistema Windows

**PowerShell 7.x (PowerShell Core):**
- Se instala aparte
- Icono negro
- Multiplataforma (Windows, Linux, macOS)
- Más rápido, más funciones, operador ternario, null-coalescing
- Algunos módulos de Windows (Active Directory, etc.) solo funcionan en 5.1

**Instalar PowerShell 7:**
```powershell
winget install Microsoft.PowerShell
```

**¿Cuál usar?** Para aprender y administrar, PowerShell 7. Para módulos específicos de Windows Server (AD, GPO), PowerShell 5.1. Puedes tener los dos instalados y usar el que necesites.

---

## 3. Nerd Fonts — Fuentes con iconos

**Qué son:** Fuentes monoespaciadas parcheadas con miles de iconos (carpetas, git, lenguajes, OS, etc.). Sin ellas, Oh My Posh y muchas herramientas muestran cuadrados vacíos en vez de iconos.

**Fuentes recomendadas:**

| Fuente | Estilo | Notas |
|--------|--------|-------|
| **CaskaydiaCove Nerd Font** | Moderna, la de Microsoft | Versión parcheada de Cascadia Code |
| **Hack Nerd Font** | Limpia, muy legible | Muy popular entre sysadmins |
| **FiraCode Nerd Font** | Con ligaduras (`=>` se ve como `⇒`) | Popular entre desarrolladores |
| **JetBrainsMono Nerd Font** | Moderna, amplia | La de JetBrains (IntelliJ, etc.) |

**Instalar:**
1. Ve a [nerdfonts.com/font-downloads](https://www.nerdfonts.com/font-downloads)
2. Descarga la que quieras (ej: "Hack")
3. Descomprime el .zip
4. Selecciona todos los archivos `.ttf`, clic derecho → "Instalar para todos los usuarios"
5. En Windows Terminal → Configuración → Perfil → Apariencia → Tipo de letra → Selecciona la Nerd Font

**O con un comando:**
```powershell
# Instalar Oh My Posh primero (ver sección 4), luego:
oh-my-posh font install Hack
```

---

## 4. Oh My Posh — Prompt personalizado

**Qué es:** Un motor de personalización del prompt (la línea donde escribes los comandos). Muestra información útil: rama de git, estado de cambios, lenguaje del proyecto, errores, hora, duración del último comando, etc.

**Antes:**
```
PS C:\Users\alumno\proyecto>
```

**Después (ejemplo con tema Cyberpunk):**
```
╭─  C:\Users\alumno\proyecto   main ≡ +3 ~1   10:35:22
╰─❯
```

**Instalar:**
```powershell
winget install JanDeDobbeleer.OhMyPosh
```

**Activar en tu perfil de PowerShell:**
```powershell
# Abre tu perfil:
notepad $PROFILE

# Añade esta línea (usa el tema que quieras):
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
```

**Temas incluidos:** Oh My Posh trae ~150 temas. Para verlos todos:
```powershell
Get-PoshThemes
```

**Temas recomendados para empezar:**
- `jandedobbeleer` — El clásico, equilibrado
- `powerlevel10k_rainbow` — Tipo P10K de Zsh, muy completo
- `agnoster` — Minimalista, popular
- `night-owl` — Colores suaves, elegante
- `atomic` — Colorido, muestra mucha info

**Crear tu propio tema:** Los temas son archivos JSON. Puedes copiar uno, modificarlo y apuntar a tu archivo:
```powershell
oh-my-posh init pwsh --config "C:\Users\alumno\.mytheme.omp.json" | Invoke-Expression
```

---

## 5. Módulos de PowerShell útiles

Módulos que puedes instalar para mejorar tu experiencia en la terminal.

### Terminal-Icons — Iconos de archivos en ls/dir

Muestra iconos junto a los archivos y carpetas al hacer `Get-ChildItem`:

```powershell
Install-Module Terminal-Icons -Scope CurrentUser
# Activar en tu perfil:
Import-Module Terminal-Icons
```

### PSReadLine — Autocompletado inteligente (ya viene instalado)

Mejora el autocompletado, historial predictivo y colores de sintaxis:

```powershell
# Añadir a tu perfil para activar predicción basada en historial:
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
```

Con esto, mientras escribes un comando, PowerShell te sugiere comandos que ya has usado antes.

### z — Saltar a carpetas frecuentes

Recuerda las carpetas que visitas. Escribe `z proyecto` y salta directamente a `C:\Users\alumno\Documents\proyecto` aunque no estés cerca:

```powershell
Install-Module z -Scope CurrentUser
```

### posh-git — Info de Git en el prompt

Muestra la rama actual, archivos modificados, etc. (Oh My Posh ya incluye esto, pero si no usas Oh My Posh, este módulo lo añade):

```powershell
Install-Module posh-git -Scope CurrentUser
```

---

## 6. Herramientas de línea de comandos

Programas que se usan desde la terminal y que merece la pena tener instalados.

### Git

Control de versiones. Imprescindible.
```powershell
winget install Git.Git
```

### Node.js (incluye npm)

Runtime de JavaScript. Necesario para desarrollo web.
```powershell
winget install OpenJS.NodeJS.LTS
```

### Python

Lenguaje de scripting y automatización.
```powershell
winget install Python.Python.3.12
```

### Visual Studio Code

Editor de código con terminal integrado.
```powershell
winget install Microsoft.VisualStudioCode
```

### WSL2 (Windows Subsystem for Linux)

Linux dentro de Windows. Necesario para Santuario y para practicar Bash.
```powershell
wsl --install
# Reiniciar Windows
# Se instala Ubuntu por defecto
```

### Docker Desktop

Contenedores. Para bases de datos, servicios, labs de red.
```powershell
winget install Docker.DockerDesktop
```

### Otras herramientas útiles

| Herramienta | Qué hace | Instalar |
|-------------|----------|----------|
| `jq` | Procesar JSON desde la terminal | `winget install jqlang.jq` |
| `curl` | Peticiones HTTP (ya viene en Windows) | — |
| `ssh` | Conexión remota (ya viene en Windows 10+) | — |
| `winget` | Gestor de paquetes de Windows (ya viene) | — |
| `7zip` | Comprimir/descomprimir desde terminal | `winget install 7zip.7zip` |
| `bat` | `cat` con colores y números de línea | `winget install sharkdp.bat` |
| `fzf` | Buscador fuzzy interactivo | `winget install junegunn.fzf` |
| `ripgrep` (rg) | `grep` ultrarrápido | `winget install BurntSushi.ripgrep.MSVC` |
| `fd` | `find` más rápido e intuitivo | `winget install sharkdp.fd` |

---

## 7. El perfil de PowerShell ($PROFILE)

**Qué es:** Un archivo `.ps1` que se ejecuta automáticamente cada vez que abres PowerShell. Es donde pones tu configuración personal.

**Dónde está:**
```powershell
echo $PROFILE
# Suele ser: C:\Users\TuUsuario\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

**Crear si no existe:**
```powershell
if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force }
```

**Ejemplo de perfil completo:**

```powershell
# ── Oh My Posh (prompt personalizado) ──
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression

# ── Módulos ──
Import-Module Terminal-Icons        # Iconos en ls/dir
Import-Module z                     # Saltar a carpetas frecuentes

# ── PSReadLine (autocompletado) ──
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

# ── Alias personales ──
Set-Alias ll Get-ChildItem
Set-Alias g git
Set-Alias c code
Set-Alias n npm
Set-Alias py python

# ── Funciones útiles ──
function mkcd { param($dir) mkdir $dir -Force; cd $dir }
function which { param($cmd) Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source }
function touch { param($file) if (Test-Path $file) { (Get-Item $file).LastWriteTime = Get-Date } else { New-Item $file -Force } }

# ── Cargar entrenamiento (opcional) ──
# . "$HOME\Documents\terminal-docencia-fp\entrenamiento\Cyberpunk2077.ps1"
```

---

## 8. Configuración de Windows Terminal (settings.json)

El archivo `settings.json` de Windows Terminal controla toda la apariencia y comportamiento. Ejemplo de perfil personalizado:

```json
{
    "profiles": {
        "defaults": {
            "font": {
                "face": "Hack Nerd Font",
                "size": 12,
                "weight": "normal"
            },
            "opacity": 85,
            "useAcrylic": true,
            "colorScheme": "One Half Dark",
            "cursorShape": "bar",
            "scrollbarState": "hidden",
            "padding": "8, 8, 8, 8"
        },
        "list": [
            {
                "name": "PowerShell",
                "source": "Windows.Terminal.PowershellCore",
                "colorScheme": "Dark+",
                "font": {
                    "face": "Hack Nerd Font"
                }
            }
        ]
    },
    "schemes": [],
    "actions": [
        { "command": "paste", "keys": "ctrl+v" },
        { "command": { "action": "splitPane", "split": "auto" }, "keys": "alt+shift+d" },
        { "command": "find", "keys": "ctrl+shift+f" }
    ]
}
```

**Dónde está el archivo:**
```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

---

## Resumen: ¿qué instalo?

### Mínimo (para empezar)

1. **Windows Terminal** (Microsoft Store)
2. **Una Nerd Font** (Hack o CaskaydiaCove)
3. **Oh My Posh** (`winget install JanDeDobbeleer.OhMyPosh`)
4. **Terminal-Icons** (`Install-Module Terminal-Icons`)

### Completo (para productividad)

Todo lo anterior más:
5. **PowerShell 7** (`winget install Microsoft.PowerShell`)
6. **PSReadLine con predicción** (configurar en $PROFILE)
7. **z** (`Install-Module z`)
8. **Git** (`winget install Git.Git`)
9. **VS Code** (`winget install Microsoft.VisualStudioCode`)
10. **WSL2** (`wsl --install`)

### Para desarrolladores (DAM/DAW)

Todo lo anterior más:
11. **Node.js** (`winget install OpenJS.NodeJS.LTS`)
12. **Python** (`winget install Python.Python.3.12`)
13. **Docker Desktop** (`winget install Docker.DockerDesktop`)
14. **jq, bat, fzf, ripgrep** (ver tabla arriba)
