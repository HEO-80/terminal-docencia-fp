# ================================================================= #
#                    CONFIGURACIÓN CyberPunk 2077                   #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).

Clear-Host

# ── Helper de color ANSI directo ──────────────────────────────────
function Write-Cyber {
    param(
        [string]$Text,
        [string]$Color = "#FCEE0A",
        [switch]$NoNewline
    )
    $esc   = [char]27
    $r     = [Convert]::ToInt32($Color.Substring(1,2), 16)
    $g     = [Convert]::ToInt32($Color.Substring(3,2), 16)
    $b     = [Convert]::ToInt32($Color.Substring(5,2), 16)
    $ansi  = "${esc}[38;2;${r};${g};${b}m"
    $reset = "${esc}[0m"
    if ($NoNewline) {
        Write-Host "$ansi$Text$reset" -NoNewline
    } else {
        Write-Host "$ansi$Text$reset"
    }
}

# ── Paleta global (accesible desde cualquier scope) ───────────────
$global:CY = @{
    Yellow  = "#FCEE0A"
    Green   = "#39FF14"
    Cyan    = "#00F0FF"
    Magenta = "#C678DD"
    Dark    = "#555555"
    Dim     = "#888888"
}

# Banner (definido en el perfil)
if ($global:ShowBanner -and (Get-Command Show-AsciiArt -ErrorAction SilentlyContinue)) {
    Show-AsciiArt
}

# ================================================================= #
#                        MÓDULOS Y HERRAMIENTAS                     #
# ================================================================= #
function Import-ModuleSafe {
    param([string]$Name)
    try {
        Import-Module $Name -ErrorAction Stop
        return $true
    } catch {
        Write-Cyber "  [!] Falta el módulo '$Name'  ->  Install-Module $Name -Scope CurrentUser" $global:CY.Dim
        return $false
    }
}

$null = Import-ModuleSafe "Terminal-Icons"

# zoxide (binario, funciona igual en bash/zsh):  winget install ajeetdsouza.zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
} else {
    Write-Cyber "  [!] zoxide no instalado  ->  winget install ajeetdsouza.zoxide" $global:CY.Dim
}

# fzf + PSFzf
if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    $fzfPath = Get-ChildItem "$env:LocalAppData\Microsoft\WinGet\Packages\junegunn.fzf*\fzf.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if ($fzfPath) { $env:PATH += ";$fzfPath" }
}

# ── PSReadLine (ya lo carga el host: NO se descarga/recarga) ──────
try { Set-PSReadLineOption -PredictionSource History } catch {}
try { Set-PSReadLineOption -PredictionViewStyle InlineView } catch {}
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -BellStyle None

# Flechas: buscan en el historial lo que ya has escrito
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
# Tab: menú de opciones navegable
Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
# Atajos estilo Linux/bash (asignados explícitamente, así la ayuda no miente)
Set-PSReadLineKeyHandler -Key Ctrl+a    -Function BeginningOfLine
Set-PSReadLineKeyHandler -Key Ctrl+e    -Function EndOfLine
Set-PSReadLineKeyHandler -Key Alt+d     -Function KillWord
Set-PSReadLineKeyHandler -Key Ctrl+w    -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+l    -Function ClearScreen

if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Import-ModuleSafe "PSFzf")) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ================================================================= #
#                           OH MY POSH                              #
# ================================================================= #
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config (Join-Path $PSScriptRoot "omp_cyberpunk.json") | Invoke-Expression
} else {
    Write-Cyber "  [!] oh-my-posh no instalado  ->  winget install JanDeDobbeleer.OhMyPosh" $global:CY.Dim
}

# ================================================================= #
#                    ATAJOS Y FUNCIONES PERSONALES                  #
# ================================================================= #
$global:ReposPath = Join-Path $HOME "Source\Repos"

function n    { Start-Process "https://www.notion.so/" }
function o    { Start-Process "obsidian://" }
function g    { Start-Process "https://mail.google.com" }
function vsc  { code . }
function proj { code $global:ReposPath }

# ================================================================= #
#                 COMANDOS ERGONÓMICOS DE POWERSHELL                #
# ================================================================= #

# 1. Ver qué ocupa más espacio (archivos pesados en la carpeta actual)
function top-size ($count = 10) {
    Get-ChildItem -File -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First $count Name, @{N="Tamaño (MB)"; E={[math]::Round($_.Length / 1MB, 2)}}
}

# 2. Ver procesos glotones de CPU
function top-cpu ($count = 5) {
    Get-Process |
        Sort-Object CPU -Descending |
        Select-Object -First $count ProcessName, @{N="CPU (s)"; E={[math]::Round($_.CPU, 1)}}, @{N="RAM (MB)"; E={[math]::Round($_.WorkingSet64 / 1MB, 1)}}
}

# 3. Matar un proceso por nombre. SEGURO: mínimo 3 letras y pide confirmación
#    por cada proceso (ej: matar chrome, matar node)
function matar {
    param(
        [Parameter(Mandatory)]
        [ValidateLength(3,50)]
        [string]$Nombre
    )
    $procs = @(Get-Process -Name "*$Nombre*" -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) {
        Write-Cyber "Sin coincidencias para '*$Nombre*'." $global:CY.Dim
        return
    }
    $procs |
        Stop-Process -Confirm -PassThru |
        ForEach-Object { Write-Cyber "Proceso detenido: $($_.ProcessName) (PID: $($_.Id))" $global:CY.Green }
}

# 4. Puertos locales en escucha (con el nombre del proceso)
function puertos {
    Get-NetTCPConnection -State Listen |
        Select-Object LocalAddress, LocalPort, OwningProcess,
            @{N="Proceso"; E={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName }} |
        Sort-Object LocalPort
}

# 5. Limpieza de .log/.tmp en la carpeta actual. Prueba antes con:  clean-logs -WhatIf
function clean-logs {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()
    Get-ChildItem -Include *.log, *.tmp -Recurse -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -Verbose
}

# ── Cargar Dojo (Teórico) y Tatami (Práctico) ─────────────────────
# Motor.ps1 primero: contiene el registro de fallos y los motores de dojo/tatami
foreach ($f in "Motor.ps1", "Dojo.ps1", "Dojo2.ps1", "Tatami1.ps1", "Tatami2.ps1", "Forja.ps1", "Santuario.ps1", "Reto.ps1") {
    $ruta = Join-Path $PSScriptRoot $f
    if (Test-Path $ruta) { . $ruta }
    else { Write-Cyber "  [!] Falta $f en $PSScriptRoot" $global:CY.Dim }
}

# ================================================================= #
#                  DATOS ÚNICOS (dashboard + ayuda)                 #
# ================================================================= #
# Edita SOLO aquí: el dashboard y help-ps leen de estas estructuras.

$global:Shortcuts = @(
    @{ Label = "Notion (n)";        Value = "Start-Process https://www.notion.so/" }
    @{ Label = "Obsidian (o)";      Value = "Start-Process obsidian://" }
    @{ Label = "Gmail (g)";         Value = "Start-Process https://mail.google.com" }
    @{ Label = "VS Code (vsc)";     Value = "code ." }
    @{ Label = "Abrir Proj (proj)"; Value = "code $($global:ReposPath)" }
    @{ Label = "Beelink (bee)";     Value = "ssh beelink   (~/.ssh/config)" }
)

$global:HelpData = [ordered]@{
    "NAVEGACIÓN Y PANTALLA (SIN RATÓN)" = @(
        @{ K = "Shift + RePag / AvPag";       D = "Scroll arriba/abajo en Windows Terminal, sin ratón" }
        @{ K = "Ctrl + Shift + Arriba/Abajo"; D = "Desplazar la pantalla línea a línea (Windows Terminal)" }
        @{ K = "ls | more";                   D = "Paginar listas largas (Espacio avanza, Q sale)" }
        @{ K = "cd -";                        D = "Volver a la carpeta anterior (solo PowerShell 7)" }
        @{ K = "cd ..";                       D = "Subir un nivel de carpeta" }
        @{ K = "z <nombre>";                  D = "zoxide: saltar a carpetas frecuentes (zi = interactivo)" }
    )
    "ATAJOS DE WINDOWS Y ESCRITORIOS" = @(
        @{ K = "Win + R  ->  wt";        D = "Lanzar Windows Terminal al instante" }
        @{ K = "Win + Flechas";          D = "Maximizar, minimizar o acoplar ventana a los lados" }
        @{ K = "Alt + Tab";              D = "Cambiar a la siguiente ventana" }
        @{ K = "Alt + Shift + Tab";      D = "Cambiar a la ventana anterior" }
        @{ K = "Ctrl + Win + Flechas";   D = "Cambiar entre escritorios virtuales (izq/der)" }
        @{ K = "Ctrl + Win + D";         D = "Crear un nuevo escritorio virtual" }
        @{ K = "Ctrl + Win + F4";        D = "Cerrar el escritorio virtual actual" }
    )
    "HERRAMIENTAS INSTALADAS" = @(
        @{ K = "Terminal-Icons"; D = "ls / dir  ->  iconos junto a archivos y carpetas" }
        @{ K = "fzf (PSFzf)";    D = "Búsqueda difusa de archivos e historial (ver Ctrl+T / Ctrl+R)" }
        @{ K = "PSReadLine";     D = "Predicción del historial en gris (Flecha derecha la acepta)" }
        @{ K = "zoxide";         D = "z nombre_carpeta  ->  salta a carpetas visitadas" }
        @{ K = "Oh My Posh";     D = "Prompt con rama git, ruta y colores (automático)" }
    )
    "ATAJOS DE TECLADO" = @(
        @{ K = "Tab";              D = "Menú de autocompletado navegable" }
        @{ K = "Ctrl + Space";     D = "Menú de autocompletado (alternativa)" }
        @{ K = "Flechas Arriba/Ab"; D = "Historial filtrado por lo que ya has escrito" }
        @{ K = "Ctrl + T";         D = "fzf: buscar archivos en la carpeta actual" }
        @{ K = "Ctrl + R";         D = "fzf: buscar en el historial" }
        @{ K = "Ctrl + A / Ctrl + E"; D = "Inicio / final de línea (reasignado: antes 'seleccionar todo')" }
        @{ K = "Alt + D";          D = "Borrar palabra hacia adelante" }
        @{ K = "Ctrl + W";         D = "Borrar palabra hacia atrás" }
        @{ K = "Ctrl + L";         D = "Limpiar pantalla" }
        @{ K = "Ctrl + C";         D = "Cancelar el comando en ejecución" }
    )
    "FUNCIONES PERSONALES" = @(
        @{ K = "n / o / g";           D = "Abrir Notion / Obsidian / Gmail" }
        @{ K = "vsc / proj";          D = "Abrir VS Code (carpeta actual / repositorios)" }
        @{ K = "top-size [n]";        D = "Los N archivos más pesados de la carpeta" }
        @{ K = "top-cpu [n]";         D = "Los N procesos con más consumo de CPU" }
        @{ K = "matar <nombre>";      D = "Cerrar procesos por nombre (mín. 3 letras, pide confirmación)" }
        @{ K = "puertos";             D = "Puertos locales en escucha, con su proceso" }
        @{ K = "clean-logs [-WhatIf]"; D = "Borra .log y .tmp recursivamente (-WhatIf = solo simular)" }
        @{ K = "dojo / quiz";         D = "Dojo 1 (nombres de comandos): -Modo Linux|PowerShell|Cmd, -Preguntas, -Repaso" }
        @{ K = "dojo2";               D = "Dojo 2 (comandos completos, nivel intermedio): mismas opciones" }
        @{ K = "rosetta";             D = "Tabla de equivalencias Linux / PowerShell / cmd" }
        @{ K = "tatami [-Repaso]";    D = "Tatami 1: misiones básicas en un sandbox temporal" }
        @{ K = "tatami2 [-Repaso]";   D = "Tatami 2: misiones intermedias (texto, CSV, renombrar, try/catch)" }
        @{ K = "forja [-Repaso]";     D = "Forja: aprende a ESCRIBIR scripts (misiones con tests). -Nivel 1|2, -Id, -Lista, -Continuar" }
        @{ K = "santuario [-Repaso]"; D = "Santuario: lo mismo que Forja pero en bash (se ejecuta en WSL). -Nivel, -Id, -Lista, -Diagnostico" }
        @{ K = "reto [-Repaso]"; D = "Reto: practica tareas reales de archivos, carpetas y permisos (icacls, attrib) en 4-6 pasos. -Nivel 1|2|3, -Id, -Lista, -Reiniciar. Dentro: comprobar, responder, pista, solucion (paso a paso), pasos, reto-salir. Alias: challenge" }
        @{ K = "progreso";            D = "Tu estado: dominados, pendientes de repaso, los que más fallas (-Reset borra)" }
        @{ K = "bee";                 D = "SSH al Beelink (host y puerto salen de ~/.ssh/config)" }
        @{ K = "Show-Dashboard";      D = "Dashboard (-Refresh actualiza caché, -SinDocker lo omite)" }
        @{ K = "Measure-Profile";     D = "Mide cuánto tarda en arrancar el perfil" }
        @{ K = "help-ps";             D = "Mostrar este menú de ayuda" }
    )
}

# ================================================================= #
#                            DASHBOARD                              #
# ================================================================= #
# CPU/RAM/OS casi nunca cambian: se cachean 24 h para no lanzar
# consultas CIM en cada terminal nueva.
function Get-SysInfoCached {
    param([switch]$Refresh)

    $dir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "CyberProfile" } else { Join-Path $HOME ".cache/cyberprofile" }
    $file = Join-Path $dir "sysinfo.json"

    if ($Refresh -and (Test-Path $file)) { Remove-Item $file -Force -ErrorAction SilentlyContinue }

    if (Test-Path $file) {
        $edad = (Get-Date) - (Get-Item $file).LastWriteTime
        if ($edad.TotalHours -lt 24) {
            try { return (Get-Content $file -Raw | ConvertFrom-Json) } catch {}
        }
    }

    try {
        $cpu = ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace 'AMD | 8-Core| Processor| @.*$', '').Trim()
        $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        $os  = (Get-CimInstance Win32_OperatingSystem).Caption
    } catch {
        $cpu = "n/d"; $ram = "n/d"; $os = "n/d"
    }

    $info = [pscustomobject]@{ CPU = $cpu; RAM = $ram; OS = $os }
    try {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $info | ConvertTo-Json | Set-Content -Path $file -Encoding UTF8
    } catch {}
    return $info
}

function Show-Dashboard {
    param(
        [switch]$Refresh,
        [switch]$SinDocker
    )

    $c   = $global:CY
    $sys = Get-SysInfoCached -Refresh:$Refresh

    $sessionInfo = [ordered]@{
        "Started" = (Get-Date -Format "yyyy-MM-dd HH:mm")
        "Shell"   = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) $($PSVersionTable.PSEdition)"
        "CPU"     = $sys.CPU
        "RAM"     = $sys.RAM
        "User"    = [Environment]::UserName
        "OS"      = $sys.OS
    }

    $shortcuts = $global:Shortcuts
    $features  = $global:HelpData["HERRAMIENTAS INSTALADAS"]

    $sep  = "=" * 80
    $sep2 = "-" * 80
    $colIzq = 38   # 10 (clave) + 2 (": ") + 26 (valor)

    Write-Cyber $sep $c.Magenta
    Write-Host ""
    Write-Cyber "$("System Info".PadRight($colIzq))| Shortcuts" $c.Green
    Write-Host ""

    $maxLines = [System.Math]::Max($sessionInfo.Count, $shortcuts.Count)
    $sysKeys  = @($sessionInfo.Keys)

    for ($i = 0; $i -lt $maxLines; $i++) {
        if ($i -lt $sysKeys.Count) {
            $k = $sysKeys[$i]
            $v = "$($sessionInfo[$k])"
            if ($v.Length -gt 26) { $v = $v.Substring(0, 25) + "…" }
            Write-Cyber "$($k.PadRight(10))" $c.Yellow -NoNewline
            Write-Cyber ": " $c.Magenta -NoNewline
            Write-Cyber $v.PadRight(26) $c.Cyan -NoNewline
        } else {
            Write-Host "".PadRight($colIzq) -NoNewline
        }

        if ($i -lt $shortcuts.Count) {
            Write-Cyber "| " $c.Magenta -NoNewline
            Write-Cyber "$($shortcuts[$i].Label.PadRight(18))" $c.Yellow -NoNewline
            Write-Cyber " $($shortcuts[$i].Value)" $c.Cyan
        } else {
            Write-Host ""
        }
    }

    Write-Host ""
    Write-Cyber $sep2 $c.Magenta
    Write-Host ""
    Write-Cyber "  Features instalados   (help-ps para todo)" $c.Green
    Write-Host ""
    foreach ($f in $features) {
        Write-Cyber "  $($f.K.PadRight(16))" $c.Yellow -NoNewline
        Write-Cyber "  $($f.D)" $c.Cyan
    }

    if (Get-Command Get-CyberDueCount -ErrorAction SilentlyContinue) {
        $pend = Get-CyberDueCount
        if ($pend -gt 0) {
            Write-Host ""
            Write-Cyber "  Repaso pendiente: $pend  ->  dojo/dojo2/tatami/tatami2/forja/santuario/reto  con  -Repaso" $c.Magenta
        }
    }

    if (-not $SinDocker) {
        Write-Host ""
        Write-Cyber $sep2 $c.Magenta
        Write-Host ""
        Write-Cyber "  Docker" $c.Green
        Write-Host ""

        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            Write-Cyber "  Docker no instalado o no disponible en PATH." $c.Dim
        }
        elseif (-not (Get-Process -Name "com.docker.backend", "dockerd" -ErrorAction SilentlyContinue)) {
            # Evita que 'docker ps' se cuelgue cuando el daemon está parado
            Write-Cyber "  Docker parado (arranca Docker Desktop)." $c.Dim
        }
        else {
            try {
                $containers = docker ps --format "{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}" 2>$null
                if ($containers) {
                    Write-Cyber "  $("NOMBRE".PadRight(22)) $("IMAGEN".PadRight(25)) $("ESTADO".PadRight(20)) PUERTOS" $c.Cyan
                    Write-Cyber "  $("-" * 76)" $c.Dark
                    foreach ($line in $containers) {
                        $parts  = $line -split "\|"
                        $name   = $parts[0].PadRight(22)
                        $image  = $parts[1].PadRight(25)
                        $status = $parts[2].PadRight(20)
                        $ports  = if ($parts[3]) { $parts[3] } else { "-" }
                        Write-Cyber "  $name " $c.Yellow -NoNewline
                        Write-Cyber "$image " $c.Cyan -NoNewline
                        Write-Cyber "$status " $c.Green -NoNewline
                        Write-Cyber "$ports" $c.Dim
                    }
                } else {
                    Write-Cyber "  Sin contenedores activos." $c.Dim
                }
            } catch {
                Write-Cyber "  No se pudo conectar con el daemon de Docker." $c.Dim
            }
        }
    }

    Write-Host ""
    Write-Cyber $sep $c.Magenta
    Write-Host ""
}

Show-Dashboard

# ================================================================= #
#                          AYUDA Y ATAJOS                           #
# ================================================================= #
function Show-Help {
    $c   = $global:CY
    $bar = "=" * 70

    foreach ($seccion in $global:HelpData.Keys) {
        Write-Host ""
        Write-Cyber $bar $c.Magenta
        Write-Cyber "  $seccion" $c.Green
        Write-Cyber $bar $c.Magenta
        foreach ($item in $global:HelpData[$seccion]) {
            Write-Cyber "  $($item.K.PadRight(28))" $c.Yellow -NoNewline
            Write-Cyber "$($item.D)" $c.Cyan
        }
    }
    Write-Host ""
    Write-Cyber "  Consejo: comprueba cualquier atajo con  Get-PSReadLineKeyHandler" $c.Dim
    Write-Host ""
}

Set-Alias help-ps Show-Help
