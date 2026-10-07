# ================================================================= #
#                  CYBER-DOJO ROSETTA (Linux / PS / cmd)            #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).

# Por si se carga este archivo suelto (sin el tema)
if (-not (Get-Command Write-Cyber -ErrorAction SilentlyContinue)) {
    function Write-Cyber {
        param([string]$Text, [string]$Color, [switch]$NoNewline)
        Write-Host $Text -NoNewline:$NoNewline
    }
}

# ── Banco de retos ────────────────────────────────────────────────
# R = respuestas aceptadas por "mundo" (Linux / PowerShell / Cmd).
# Un reto con una sola clave solo se pregunta en ese mundo.
# La primera respuesta de cada lista es la "canónica".
function Get-DojoBanco {
    @(
        @{ Tipo = "Listar";           Tarea = "Listar el contenido de una carpeta";
           R = @{ Linux = @('ls'); PowerShell = @('Get-ChildItem','ls','dir','gci'); Cmd = @('dir') };
           Exp = "PowerShell: Get-ChildItem (alias ls, dir, gci). En PS 7 sobre Linux 'ls' es el binario real." },
        @{ Tipo = "Leer archivo";     Tarea = "Mostrar el contenido de un archivo de texto";
           R = @{ Linux = @('cat'); PowerShell = @('Get-Content','cat','type','gc'); Cmd = @('type') };
           Exp = "Get-Content devuelve un array de líneas (usa -Raw para un solo string, -Tail N para las últimas)." },
        @{ Tipo = "Buscar texto";     Tarea = "Buscar un texto dentro de archivos";
           R = @{ Linux = @('grep'); PowerShell = @('Select-String','sls'); Cmd = @('findstr') };
           Exp = "Select-String admite regex y -Recurse a través de Get-ChildItem | Select-String." },
        @{ Tipo = "Procesos";         Tarea = "Listar los procesos en ejecución";
           R = @{ Linux = @('ps'); PowerShell = @('Get-Process','ps','gps'); Cmd = @('tasklist') };
           Exp = "En Linux 'ps aux' o 'top'; en PowerShell Get-Process devuelve objetos que puedes filtrar." },
        @{ Tipo = "Matar proceso";    Tarea = "Terminar un proceso";
           R = @{ Linux = @('kill'); PowerShell = @('Stop-Process','kill','spps'); Cmd = @('taskkill') };
           Exp = "Linux: kill PID (o pkill nombre). PowerShell: Stop-Process -Name/-Id. cmd: taskkill /PID o /IM." },
        @{ Tipo = "Red / puertos";    Tarea = "Ver los puertos en escucha";
           R = @{ Linux = @('ss','netstat'); PowerShell = @('Get-NetTCPConnection'); Cmd = @('netstat') };
           Exp = "Linux moderno: ss -tlnp. Windows: netstat -ano o Get-NetTCPConnection -State Listen." },
        @{ Tipo = "Red / IP";         Tarea = "Ver la configuración IP de tus interfaces";
           R = @{ Linux = @('ip','ip a','ip addr','ifconfig'); PowerShell = @('Get-NetIPAddress','ipconfig'); Cmd = @('ipconfig') };
           Exp = "Linux: ip a. Windows: ipconfig /all o Get-NetIPAddress." },
        @{ Tipo = "Red / DNS";        Tarea = "Resolver el nombre de un dominio (consulta DNS)";
           R = @{ Linux = @('dig','nslookup','host'); PowerShell = @('Resolve-DnsName','nslookup'); Cmd = @('nslookup') };
           Exp = "Resolve-DnsName devuelve objetos y admite -Type MX, -Server 8.8.8.8, etc." },
        @{ Tipo = "Red / conectividad"; Tarea = "Comprobar si un equipo responde";
           R = @{ Linux = @('ping'); PowerShell = @('Test-Connection','ping','Test-NetConnection'); Cmd = @('ping') };
           Exp = "Test-NetConnection -Port 22 comprueba además un puerto TCP concreto." },
        @{ Tipo = "Descubrir";        Tarea = "Localizar dónde está (o qué es) un comando";
           R = @{ Linux = @('which','type'); PowerShell = @('Get-Command','gcm'); Cmd = @('where') };
           Exp = "Get-Command también busca por patrón: Get-Command *process*." },
        @{ Tipo = "Copiar";           Tarea = "Copiar un archivo";
           R = @{ Linux = @('cp'); PowerShell = @('Copy-Item','cp','copy','cpi'); Cmd = @('copy') };
           Exp = "Copy-Item -Recurse copia carpetas; en Linux cp -r." },
        @{ Tipo = "Mover";            Tarea = "Mover o renombrar un archivo";
           R = @{ Linux = @('mv'); PowerShell = @('Move-Item','mv','move','mi'); Cmd = @('move') };
           Exp = "Para renombrar en PowerShell también existe Rename-Item (alias ren)." },
        @{ Tipo = "Borrar";           Tarea = "Borrar un archivo";
           R = @{ Linux = @('rm'); PowerShell = @('Remove-Item','rm','del','ri','erase'); Cmd = @('del') };
           Exp = "Prueba siempre con -WhatIf en PowerShell antes de borrar en masa." },
        @{ Tipo = "Crear carpeta";    Tarea = "Crear una carpeta";
           R = @{ Linux = @('mkdir'); PowerShell = @('mkdir','New-Item','md'); Cmd = @('mkdir','md') };
           Exp = "En PowerShell 'mkdir' es una función que envuelve New-Item -ItemType Directory." },
        @{ Tipo = "Ubicación";        Tarea = "Ver en qué carpeta estás";
           R = @{ Linux = @('pwd'); PowerShell = @('Get-Location','pwd','gl'); Cmd = @('cd') };
           Exp = "En cmd, 'cd' sin argumentos imprime la carpeta actual." },
        @{ Tipo = "Pantalla";         Tarea = "Limpiar la pantalla";
           R = @{ Linux = @('clear'); PowerShell = @('Clear-Host','cls','clear'); Cmd = @('cls') };
           Exp = "En casi todos los terminales, Ctrl+L también limpia." },
        @{ Tipo = "Ayuda";            Tarea = "Leer la ayuda de un comando";
           R = @{ Linux = @('man'); PowerShell = @('Get-Help','help','man'); Cmd = @('help') };
           Exp = "Get-Help -Examples es lo más útil; Update-Help descarga la ayuda completa." },
        @{ Tipo = "Ordenar";          Tarea = "Ordenar la salida de un comando";
           R = @{ Linux = @('sort'); PowerShell = @('Sort-Object','sort'); Cmd = @('sort') };
           Exp = "Sort-Object ordena por propiedades (objetos), no por líneas de texto." },
        @{ Tipo = "Contar";           Tarea = "Contar elementos/líneas de la salida";
           R = @{ Linux = @('wc'); PowerShell = @('Measure-Object','measure') };
           Exp = "Linux: wc -l. PowerShell: ... | Measure-Object (también suma y promedia con -Sum -Average)." },
        @{ Tipo = "Disco";            Tarea = "Ver el espacio en disco libre/usado";
           R = @{ Linux = @('df'); PowerShell = @('Get-PSDrive','gdr') };
           Exp = "Linux: df -h. PowerShell: Get-PSDrive -PSProvider FileSystem." },
        @{ Tipo = "Descubrir objetos"; Tarea = "Ver las propiedades y métodos de un objeto que sale de un pipeline";
           R = @{ PowerShell = @('Get-Member','gm') };
           Exp = "Get-Process | Get-Member  te dice qué propiedades puedes usar en Select-Object / Where-Object." },
        @{ Tipo = "Pipeline";         Tarea = "Alias de UN símbolo para filtrar (Where-Object)";
           R = @{ PowerShell = @('?','Where-Object','where') };
           Exp = "dir | ? Length -gt 10MB" },
        @{ Tipo = "Pipeline";         Tarea = "Alias de UN símbolo para ejecutar algo por cada elemento (ForEach-Object)";
           R = @{ PowerShell = @('%','ForEach-Object','foreach') };
           Exp = "1..5 | % { `$_ * 2 }" },
        @{ Tipo = "Operadores";       Tarea = "Operador para comparar 'mayor que' (no se usa '>')";
           R = @{ PowerShell = @('-gt') };
           Exp = "-gt mayor, -lt menor, -eq igual, -ne distinto, -ge / -le (o igual)." },
        @{ Tipo = "Selección";        Tarea = "Parámetro de Select-Object para quedarte con los primeros N elementos";
           R = @{ PowerShell = @('-First') };
           Exp = "Select-Object -First 10 toma los primeros 10 objetos (-Last para los últimos)." },
        @{ Tipo = "Operadores";       Tarea = "Operador de comparación por expresión regular / texto parcial";
           R = @{ PowerShell = @('-match') };
           Exp = "ps | ? ProcessName -match 'code'  (-like usa comodines * ?; -match usa regex)." }
    )
}

# ── Dojo nivel 1 (usa el motor de Motor.ps1: registro de fallos y repaso) ──
function Invoke-CyberDojo {
    [CmdletBinding()]
    param(
        [Alias('Ronda')]
        [int]$Preguntas = 5,

        [ValidateSet('Mix', 'Linux', 'PowerShell', 'Cmd')]
        [string]$Modo = 'Mix',

        # Solo los retos que toca repasar hoy
        [switch]$Repaso
    )
    Invoke-DojoEngine -Banco (Get-DojoBanco) -Prefijo 'dojo1' -Titulo 'CYBER-DOJO ROSETTA  -  nivel 1' -Preguntas $Preguntas -Modo $Modo -Repaso:$Repaso
}

# ── Tabla Rosetta de consulta rápida ──────────────────────────────
function Show-Rosetta {
    $c = $global:CY
    if (-not $c) {
        $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" }
    }

    $filas = Get-DojoBanco | Where-Object { $_.R.Count -ge 2 }

    Write-Host ""
    Write-Cyber "  $("TAREA".PadRight(44)) $("LINUX".PadRight(9)) $("POWERSHELL".PadRight(22)) CMD" $c.Green
    Write-Cyber "  $("-" * 88)" $c.Magenta
    foreach ($f in $filas) {
        $li = if ($f.R.ContainsKey('Linux'))      { $f.R.Linux[0] }      else { "-" }
        $ps = if ($f.R.ContainsKey('PowerShell')) { $f.R.PowerShell[0] } else { "-" }
        $cm = if ($f.R.ContainsKey('Cmd'))        { $f.R.Cmd[0] }        else { "-" }
        Write-Cyber "  $($f.Tarea.PadRight(44).Substring(0,44)) " $c.Cyan -NoNewline
        Write-Cyber "$($li.PadRight(9)) " $c.Yellow -NoNewline
        Write-Cyber "$($ps.PadRight(22)) " $c.Yellow -NoNewline
        Write-Cyber "$cm" $c.Yellow
    }
    Write-Host ""
    Write-Cyber "  Nota: en PowerShell 7 sobre Linux los alias ls/cat/ps/kill NO existen: gana el binario nativo." $c.Dim
    Write-Host ""
}

# Alias
Set-Alias dojo    Invoke-CyberDojo
Set-Alias quiz    Invoke-CyberDojo
Set-Alias rosetta Show-Rosetta
