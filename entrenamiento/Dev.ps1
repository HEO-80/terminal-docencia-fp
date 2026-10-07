# ================================================================= #
#        DEV: HERRAMIENTAS PARA DESARROLLAR (DAM / DAW)              #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).
#
# Se carga desde Developer2077.ps1. Todo son funciones sueltas: si algo no
# te sirve, borra su bloque; si quieres uno nuevo, copia uno parecido.
#
# Secciones:  entorno · compilar (jr) · git · procesos e hilos · red y puertos
#             · bases de datos (Docker) · api y servidor web · proyectos nuevos
#             · seguridad (secretos, .env) · limpieza y búsqueda · Java (JDK)

# Por si se carga este archivo suelto (sin el tema)
if (-not (Get-Command Write-Cyber -ErrorAction SilentlyContinue)) {
    function Write-Cyber {
        param([string]$Text, [string]$Color, [switch]$NoNewline)
        Write-Host $Text -NoNewline:$NoNewline
    }
}

function Get-DevC {
    $c = $global:CY
    if (-not $c) { $c = @{ Green = "#39FF14"; Yellow = "#FCEE0A"; Cyan = "#00F0FF"; Magenta = "#C678DD"; Dim = "#888888"; Dark = "#555555" } }
    return $c
}

function Test-DevWindows { return ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) }
function Test-DevComando { param([string]$Nombre) return [bool](Get-Command $Nombre -ErrorAction SilentlyContinue) }

# Carpeta de caché (la misma que usa el dashboard)
function Get-DevCache {
    if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA "CyberProfile") }
    return (Join-Path $HOME ".cache/cyberprofile")
}

# Carpetas que NO se recorren al buscar (enormes o generadas)
$global:DevExcluidos = @('node_modules', '.git', 'target', 'bin', 'obj', 'dist', 'build', '.idea', '.gradle', '__pycache__', '.vs', 'out')
$global:DevBinarios  = @('png', 'jpg', 'jpeg', 'gif', 'ico', 'pdf', 'zip', 'jar', 'class', 'dll', 'exe', 'so', 'gz', 'tar', '7z', 'woff', 'woff2', 'ttf', 'mp3', 'mp4', 'webp', 'db', 'sqlite', 'pyc')

# Recorre carpetas saltándose las excluidas (no entra en node_modules, .git...)
function Get-DevArchivos {
    param([string]$Ruta = '.', [string[]]$Ext)
    $pend = New-Object System.Collections.Stack
    $pend.Push((Resolve-Path -LiteralPath $Ruta).ProviderPath)
    while ($pend.Count -gt 0) {
        $d = $pend.Pop()
        foreach ($e in @(Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue)) {
            if ($e.PSIsContainer) {
                if ($global:DevExcluidos -notcontains $e.Name) { $pend.Push($e.FullName) }
            } else {
                $x = $e.Extension.TrimStart('.').ToLowerInvariant()
                if ($Ext -and ($Ext -notcontains $x)) { continue }
                $e
            }
        }
    }
}

# ================================================================= #
#  1. ENTORNO: qué tengo instalado                                   #
# ================================================================= #
$global:DevHerramientas = @(
    @{ Nombre = 'Java';   Cmd = 'java';   Args = @('-version') },
    @{ Nombre = 'javac';  Cmd = 'javac';  Args = @('-version') },
    @{ Nombre = 'Maven';  Cmd = 'mvn';    Args = @('-v') },
    @{ Nombre = 'Git';    Cmd = 'git';    Args = @('--version') },
    @{ Nombre = '.NET';   Cmd = 'dotnet'; Args = @('--version') },
    @{ Nombre = 'Node';   Cmd = 'node';   Args = @('--version') },
    @{ Nombre = 'npm';    Cmd = 'npm';    Args = @('--version') },
    @{ Nombre = 'Python'; Cmd = 'python'; Args = @('--version') },
    @{ Nombre = 'Docker'; Cmd = 'docker'; Args = @('--version') }
)

# Devuelve solo el número de versión. java -version escribe por STDERR: por eso 2>&1
function Get-DevVersion {
    param([string]$Cmd, [string[]]$Argumentos)
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) { return $null }
    $antes = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # JAVA_TOOL_OPTIONS hace que java escriba antes una línea 'Picked up ...': se ignora
    try   { $l = & $Cmd @Argumentos 2>&1 | Where-Object { "$_" -notmatch '^Picked up ' } | Select-Object -First 1 }
    catch { return '?' }
    finally { $ErrorActionPreference = $antes }
    $t = "$l".Trim()
    if ($t -match '\d+(\.\d+)+') { return $Matches[0] }
    if ($t) { return $t }
    return '?'
}

# -Cache: usa el resultado guardado (24 h). Sin -Cache: mide y guarda de nuevo.
function Get-EntornoDatos {
    param([switch]$Cache)
    $file = Join-Path (Get-DevCache) "entorno.json"
    if ($Cache -and (Test-Path $file)) {
        $edad = (Get-Date) - (Get-Item $file).LastWriteTime
        if ($edad.TotalHours -lt 24) {
            try { return @(Get-Content $file -Raw | ConvertFrom-Json) } catch { }
        }
    }
    $res = @()
    foreach ($h in $global:DevHerramientas) {
        $v = Get-DevVersion -Cmd $h.Cmd -Argumentos $h.Args
        $res += [pscustomobject]@{ Nombre = $h.Nombre; Version = $v }
    }
    try {
        New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
        $res | ConvertTo-Json | Set-Content -Path $file -Encoding UTF8
    } catch { }
    return $res
}

function entorno {
    $c = Get-DevC
    Write-Cyber "  Entorno de desarrollo" $c.Green
    foreach ($h in @(Get-EntornoDatos)) {
        if ($h.Version) {
            Write-Cyber ("  {0,-8}" -f $h.Nombre) $c.Yellow -NoNewline
            Write-Cyber ("{0}" -f $h.Version) $c.Cyan
        } else {
            Write-Cyber ("  {0,-8}" -f $h.Nombre) $c.Yellow -NoNewline
            Write-Cyber "no instalado" $c.Dim
        }
    }
    if ($env:JAVA_HOME) { Write-Cyber ("  {0,-8}{1}" -f 'JAVA_HOME', $env:JAVA_HOME) $c.Dim }
    Write-Cyber ("  {0,-8}{1} procesos en marcha" -f 'Sistema', @(Get-Process).Count) $c.Dim
}

# ================================================================= #
#  2. COMPILAR Y EJECUTAR                                            #
# ================================================================= #
# jr = javac + java. Solo ejecuta si compiló bien (código de salida 0)
#   jr Paso1Hilos        jr Main arg1 arg2        jr   (si solo hay un .java)
function jr {
    param(
        [Parameter(Position = 0)][string]$Clase,
        [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Argumentos
    )
    $c = Get-DevC
    if (-not (Test-DevComando javac)) {
        Write-Cyber "javac no está en el PATH. Instala un JDK (no basta el JRE) o usa:  javas  /  usa-java 17" $c.Magenta
        return
    }
    if (-not $Clase) {
        $unicos = @(Get-ChildItem -Filter *.java -File -ErrorAction SilentlyContinue)
        if ($unicos.Count -ne 1) { Write-Cyber "Uso:  jr <Clase> [argumentos]   (hay $($unicos.Count) archivos .java aquí)" $c.Dim; return }
        $Clase = $unicos[0].BaseName
    }
    $Clase = $Clase -replace '\.java$', ''
    if (-not (Test-Path "$Clase.java")) { Write-Cyber "No existe $Clase.java en esta carpeta." $c.Magenta; return }

    javac "$Clase.java"
    $codigo = $LASTEXITCODE
    if ($codigo -ne 0) { Write-Cyber "javac terminó con código ${codigo}: no se ejecuta." $c.Magenta; return }
    java $Clase @Argumentos
    $global:LASTEXITCODE = $LASTEXITCODE
}

# ================================================================= #
#  3. GIT                                                            #
# ================================================================= #
function Test-DevRepo {
    if (-not (Test-DevComando git)) { Write-Cyber "git no está instalado." (Get-DevC).Magenta; return $false }
    $r = git rev-parse --is-inside-work-tree 2>$null
    if ($r -ne 'true') { Write-Cyber "Aquí no hay un repositorio de git (haz  git init  o entra en uno)." (Get-DevC).Dim; return $false }
    return $true
}

function gst   { if (Test-DevRepo) { git status -sb } }
function glog  { if (Test-DevRepo) { git log --oneline --graph --decorate -15 } }
function gdif  { if (Test-DevRepo) { git diff --stat; git diff --cached --stat } }
function gramas { if (Test-DevRepo) { git branch -vv } }
function gnueva {
    param([Parameter(Mandatory)][string]$Rama)
    if (Test-DevRepo) { git switch -c $Rama }
}
function gvolver { if (Test-DevRepo) { git switch - } }

# gac = add + commit, pero antes avisa si en lo que vas a subir hay contraseñas o claves
function gac {
    param([Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)][string[]]$Mensaje)
    $c = Get-DevC
    if (-not (Test-DevRepo)) { return }
    $msg = ($Mensaje -join ' ').Trim()
    git add -A
    $n = @(git diff --cached --name-only).Count
    if ($n -eq 0) { Write-Cyber "No hay nada que confirmar (working tree limpio)." $c.Dim; return }

    $hallazgos = @(secretos -Staged -Silencioso)
    if ($hallazgos.Count -gt 0) {
        Write-Cyber "⚠ Posibles secretos en lo que vas a confirmar:" $c.Magenta
        foreach ($h in $hallazgos) { Write-Cyber ("   {0}:{1}  [{2}]" -f $h.Archivo, $h.Linea, $h.Tipo) $c.Yellow }
        $r = Read-Host "¿Confirmar de todas formas? (s/N)"
        if ($r -notmatch '^[sSyY]') { Write-Cyber "Commit cancelado. Los cambios siguen en staging (git restore --staged . para sacarlos)." $c.Dim; return }
    }
    git commit -m $msg
}

# gsync = traer cambios (rebase) y subir los tuyos
function gsync {
    if (-not (Test-DevRepo)) { return }
    git pull --rebase
    if ($LASTEXITCODE -eq 0) { git push }
    else { Write-Cyber "El pull falló: resuelve los conflictos antes de subir." (Get-DevC).Magenta }
}

# ================================================================= #
#  4. PROCESOS E HILOS (lo que ves aquí, lo programas en PSP)         #
# ================================================================= #
# procesos: los que más CPU gastan, con PID, memoria e hilos
function procesos {
    param([int]$Top = 10, [string]$Nombre)
    $lista = @(Get-Process)
    if ($Nombre) { $lista = @($lista | Where-Object { $_.ProcessName -like "*$Nombre*" }) }
    $lista | Sort-Object CPU -Descending | Select-Object -First $Top `
        @{ N = 'PID';    E = { $_.Id } },
        @{ N = 'Nombre'; E = { $_.ProcessName } },
        @{ N = 'CPU_s';  E = { [math]::Round($_.CPU, 1) } },
        @{ N = 'RAM_MB'; E = { [math]::Round($_.WorkingSet64 / 1MB, 0) } },
        @{ N = 'Hilos';  E = { $_.Threads.Count } }
}

function Get-DevHijos {
    param([int]$Id)
    if (Test-DevWindows) {
        foreach ($p in @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $Id" -ErrorAction SilentlyContinue)) {
            [pscustomobject]@{ PID = [int]$p.ProcessId; Nombre = $p.Name; Comando = $p.CommandLine }
        }
    } else {
        foreach ($p in @(Get-Process | Where-Object { $_.Parent -and $_.Parent.Id -eq $Id })) {
            [pscustomobject]@{ PID = $p.Id; Nombre = $p.ProcessName; Comando = $null }
        }
    }
}

# hijos: procesos hijos de un PID (por defecto, tu propia terminal)
function hijos {
    param([int]$Id = $PID)
    $h = @(Get-DevHijos -Id $Id)
    if ($h.Count -eq 0) { Write-Cyber "El proceso $Id no tiene hijos ahora mismo." (Get-DevC).Dim; return }
    $h
}

# arbol: jerarquía de procesos a partir de un PID (por defecto, tu terminal)
function arbol {
    param([int]$Id = $PID, [int]$Prof = 4)
    $c = Get-DevC
    $visto = @{}
    function Show-DevNodo {
        param([int]$Pid_, [int]$Nivel, [string]$Prefijo)
        if ($visto.ContainsKey($Pid_) -or $Nivel -gt $Prof) { return }
        $visto[$Pid_] = $true
        $kids = @(Get-DevHijos -Id $Pid_)
        for ($i = 0; $i -lt $kids.Count; $i++) {
            $ultimo = ($i -eq $kids.Count - 1)
            $rama = if ($ultimo) { '└─ ' } else { '├─ ' }
            Write-Cyber ("{0}{1}{2} ({3})" -f $Prefijo, $rama, $kids[$i].Nombre, $kids[$i].PID) $c.Cyan
            $sig = if ($ultimo) { '   ' } else { '│  ' }
            Show-DevNodo -Pid_ $kids[$i].PID -Nivel ($Nivel + 1) -Prefijo ($Prefijo + $sig)
        }
    }
    $raiz = Get-Process -Id $Id -ErrorAction SilentlyContinue
    if (-not $raiz) { Write-Cyber "No existe el proceso $Id." $c.Magenta; return }
    Write-Cyber ("{0} ({1})" -f $raiz.ProcessName, $raiz.Id) $c.Yellow
    Show-DevNodo -Pid_ $Id -Nivel 1 -Prefijo ''
}

# lanzar = el ProcessBuilder de PowerShell: PID, stdout, stderr, código de salida y tiempo
#   lanzar java -version      lanzar ping -n 2 127.0.0.1      lanzar programa-que-no-existe
function lanzar {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Programa,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Argumentos
    )
    $c = Get-DevC
    $maxSeg = 60

    $exe = $Programa
    $app = Get-Command $Programa -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($app) { $exe = $app.Source }
    $args2 = @($Argumentos | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } })

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($exe -match '\.(cmd|bat)$') {
        $psi.FileName  = 'cmd.exe'
        $psi.Arguments = '/c "' + $exe + '" ' + ($args2 -join ' ')
    } else {
        $psi.FileName  = $exe
        $psi.Arguments = ($args2 -join ' ')
    }
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $true

    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    try { $p = [System.Diagnostics.Process]::Start($psi) }
    catch {
        Write-Cyber "No se pudo lanzar '$Programa': $($_.Exception.Message)" $c.Magenta
        return
    }
    Write-Cyber ("PID del proceso hijo: {0}" -f $p.Id) $c.Cyan

    # Se leen los dos canales a la vez: si no, un proceso que escriba mucho por uno se bloquea
    $tOut = $p.StandardOutput.ReadToEndAsync()
    $tErr = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($maxSeg * 1000)) {
        try { $p.Kill() } catch { }
        Write-Cyber "Pasaron $maxSeg s: proceso terminado a la fuerza." $c.Magenta
    }
    $p.WaitForExit()
    $reloj.Stop()

    Write-Cyber "[stdout]" $c.Green
    if ($tOut.Result) { Write-Host $tOut.Result.TrimEnd() }
    Write-Cyber "[stderr]" $c.Yellow
    if ($tErr.Result) { Write-Host $tErr.Result.TrimEnd() }
    $col = if ($p.ExitCode -eq 0) { $c.Green } else { $c.Magenta }
    Write-Cyber ("Código de salida: {0}   ·   {1:N2} s" -f $p.ExitCode, $reloj.Elapsed.TotalSeconds) $col
    $global:LASTEXITCODE = $p.ExitCode
}

# mide { ... }  cuánto tarda un bloque.   mide { ... } -Veces 3  hace la media
function mide {
    param([Parameter(Mandatory, Position = 0)][scriptblock]$Bloque, [int]$Veces = 1)
    $c = Get-DevC
    $tot = 0.0
    for ($i = 1; $i -le $Veces; $i++) {
        $t = Measure-Command { & $Bloque | Out-Null }
        $tot += $t.TotalSeconds
        Write-Cyber ("  Ejecución {0}: {1:N2} s" -f $i, $t.TotalSeconds) $c.Cyan
    }
    if ($Veces -gt 1) { Write-Cyber ("  Media: {0:N2} s" -f ($tot / $Veces)) $c.Green }
}

# proceso-vs-hilo: Start-Job crea un PROCESO (PID distinto); Start-ThreadJob, un HILO (mismo PID)
function proceso-vs-hilo {
    $c = Get-DevC
    Write-Cyber "PID de mi terminal:       $PID" $c.Yellow
    $j1 = Start-Job { $PID }
    $r1 = Receive-Job $j1 -Wait -AutoRemoveJob
    Write-Cyber "Start-Job (¿proceso?):    $r1" $c.Cyan
    if (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue) {
        $j2 = Start-ThreadJob { $PID }
        $r2 = Receive-Job $j2 -Wait -AutoRemoveJob
        Write-Cyber "Start-ThreadJob (¿hilo?): $r2" $c.Cyan
        if ($r1 -ne $PID -and $r2 -eq $PID) { Write-Cyber "→ El job es otro proceso; el ThreadJob vive dentro de tu terminal." $c.Green }
    } else {
        Write-Cyber "Falta el módulo:  Install-Module ThreadJob -Scope CurrentUser" $c.Magenta
    }
}

# servicios: servicios de Windows (por defecto, los que están en marcha)
function servicios {
    param([string]$Filtro, [switch]$Parados)
    $c = Get-DevC
    if (-not (Get-Command Get-Service -ErrorAction SilentlyContinue)) { Write-Cyber "Los servicios de Windows solo existen en Windows." $c.Dim; return }
    $s = @(Get-Service)
    if ($Filtro) { $s = @($s | Where-Object { $_.Name -like "*$Filtro*" -or $_.DisplayName -like "*$Filtro*" }) }
    $estado = if ($Parados) { 'Stopped' } else { 'Running' }
    $s | Where-Object { [string]$_.Status -eq $estado } | Sort-Object DisplayName |
        Select-Object Status, Name, DisplayName
}

# ================================================================= #
#  5. RED Y PUERTOS                                                  #
# ================================================================= #
# puerto 8080: qué proceso lo usa
function puerto {
    param([Parameter(Mandatory, Position = 0)][int]$Numero)
    $c = Get-DevC
    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) { Write-Cyber "puerto usa Get-NetTCPConnection (solo Windows)." $c.Dim; return }
    $con = @(Get-NetTCPConnection -LocalPort $Numero -ErrorAction SilentlyContinue)
    if ($con.Count -eq 0) { Write-Cyber "El puerto $Numero está libre." $c.Green; return }
    foreach ($x in $con) {
        $pr = Get-Process -Id $x.OwningProcess -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Puerto = $x.LocalPort; Estado = [string]$x.State; PID = $x.OwningProcess
            Proceso = if ($pr) { $pr.ProcessName } else { '?' }
        }
    }
}

# libera 8080: termina el proceso que está ESCUCHANDO en ese puerto (pide confirmación)
function libera {
    param([Parameter(Mandatory, Position = 0)][int]$Numero)
    $c = Get-DevC
    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) { Write-Cyber "libera usa Get-NetTCPConnection (solo Windows)." $c.Dim; return }
    $ids = @(Get-NetTCPConnection -LocalPort $Numero -State Listen -ErrorAction SilentlyContinue |
             Select-Object -ExpandProperty OwningProcess -Unique)
    if ($ids.Count -eq 0) { Write-Cyber "Nadie escucha en el puerto $Numero." $c.Green; return }
    foreach ($id in $ids) {
        if ($id -le 4) { Write-Cyber "El puerto $Numero lo usa el sistema (PID $id): no lo toco." $c.Magenta; continue }
        Get-Process -Id $id -ErrorAction SilentlyContinue | Stop-Process -Confirm -PassThru |
            ForEach-Object { Write-Cyber "Terminado: $($_.ProcessName) (PID $($_.Id))" $c.Green }
    }
}

# probar localhost 5432: ¿responde ese servidor en ese puerto? (devuelve $true / $false)
function probar {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Servidor,
        [Parameter(Mandatory, Position = 1)][int]$Puerto,
        [int]$TimeoutMs = 2000
    )
    $c = Get-DevC
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $t = $tcp.ConnectAsync($Servidor, $Puerto)
        if ($t.Wait($TimeoutMs) -and $tcp.Connected) {
            Write-Cyber "✔ ${Servidor}:${Puerto} responde" $c.Green
            return $true
        }
        Write-Cyber "✗ ${Servidor}:${Puerto} no responde (timeout ${TimeoutMs} ms)" $c.Magenta
        return $false
    } catch {
        Write-Cyber "✗ ${Servidor}:${Puerto} rechaza la conexión" $c.Magenta
        return $false
    } finally { $tcp.Close() }
}

# mi-ip: direcciones IPv4 de tus interfaces activas
function mi-ip {
    foreach ($n in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($n.OperationalStatus -ne 'Up' -or $n.NetworkInterfaceType -eq 'Loopback') { continue }
        foreach ($a in $n.GetIPProperties().UnicastAddresses) {
            if ($a.Address.AddressFamily -eq 'InterNetwork') {
                [pscustomobject]@{ Interfaz = $n.Name; IP = $a.Address.ToString() }
            }
        }
    }
}

# ssh-hosts: los Host de tu ~/.ssh/config  (luego:  ssh <nombre>)
function ssh-hosts {
    $f = Join-Path $HOME ".ssh/config"
    if (-not (Test-Path $f)) { Write-Cyber "No existe $f" (Get-DevC).Dim; return }
    Get-Content $f | ForEach-Object {
        if ($_ -match '^\s*Host\s+(.+)$' -and $Matches[1] -notmatch '[\*\?]') { $Matches[1].Trim() }
    }
}

# ================================================================= #
#  6. BASES DE DATOS EN DOCKER                                       #
# ================================================================= #
# Contraseñas de DESARROLLO local. Nunca las uses en un servidor real.
$global:DevBDs = [ordered]@{
    mysql     = @{ Imagen = 'mysql:8';          Puerto = 3306;  Datos = '/var/lib/mysql';      Env = @('MYSQL_ROOT_PASSWORD=dev1234', 'MYSQL_DATABASE=dev');
                   Info = 'jdbc:mysql://localhost:{0}/dev   usuario: root   clave: dev1234' }
    mariadb   = @{ Imagen = 'mariadb:11';       Puerto = 3306;  Datos = '/var/lib/mysql';      Env = @('MARIADB_ROOT_PASSWORD=dev1234', 'MARIADB_DATABASE=dev');
                   Info = 'jdbc:mariadb://localhost:{0}/dev   usuario: root   clave: dev1234' }
    postgres  = @{ Imagen = 'postgres:16';      Puerto = 5432;  Datos = '/var/lib/postgresql/data'; Env = @('POSTGRES_PASSWORD=dev1234', 'POSTGRES_DB=dev');
                   Info = 'jdbc:postgresql://localhost:{0}/dev   usuario: postgres   clave: dev1234' }
    mongo     = @{ Imagen = 'mongo:7';          Puerto = 27017; Datos = '/data/db';            Env = @();
                   Info = 'mongodb://localhost:{0}   (sin usuario)' }
    sqlserver = @{ Imagen = 'mcr.microsoft.com/mssql/server:2022-latest'; Puerto = 1433; Datos = '/var/opt/mssql'; Env = @('ACCEPT_EULA=Y', 'MSSQL_SA_PASSWORD=Dev_1234567!');
                   Info = 'Server=localhost,{0};User Id=sa;Password=Dev_1234567!;TrustServerCertificate=true' }
    redis     = @{ Imagen = 'redis:7';          Puerto = 6379;  Datos = '/data';               Env = @();
                   Info = 'redis://localhost:{0}' }
}

function Test-DevDocker {
    $c = Get-DevC
    if (-not (Test-DevComando docker)) { Write-Cyber "Docker no está instalado (winget install Docker.DockerDesktop)." $c.Magenta; return $false }
    docker info *> $null
    if ($LASTEXITCODE -ne 0) { Write-Cyber "Docker no está arrancado: abre Docker Desktop y espera a que diga 'running'." $c.Magenta; return $false }
    return $true
}

# db-up mysql   →  crea (o arranca) un contenedor dev-mysql con su volumen de datos
function db-up {
    param(
        [Parameter(Mandatory, Position = 0)][ValidateSet('mysql', 'mariadb', 'postgres', 'mongo', 'sqlserver', 'redis')][string]$Tipo,
        [int]$Puerto
    )
    $c = Get-DevC
    if (-not (Test-DevDocker)) { return }
    $d = $global:DevBDs[$Tipo]
    if (-not $Puerto) { $Puerto = $d.Puerto }
    $nombre = "dev-$Tipo"
    $filtro = "name=^/$nombre$"

    $existe = @(docker ps -a --filter $filtro --format '{{.Names}}')
    if ($existe.Count -gt 0) {
        $vivo = @(docker ps --filter $filtro --format '{{.Names}}')
        if ($vivo.Count -gt 0) { Write-Cyber "$nombre ya está en marcha." $c.Dim }
        else { docker start $nombre | Out-Null; Write-Cyber "$nombre arrancado (con los datos de antes)." $c.Green }
    } else {
        $a = @('run', '-d', '--name', $nombre, '-p', "${Puerto}:$($d.Puerto)", '-v', "${nombre}-data:$($d.Datos)")
        foreach ($e in $d.Env) { $a += @('-e', $e) }
        $a += $d.Imagen
        Write-Cyber "docker $($a -join ' ')" $c.Dim
        & docker @a | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Cyber "docker run falló (¿el puerto $Puerto está ocupado? prueba:  puerto $Puerto)" $c.Magenta; return }
        Write-Cyber "$nombre creado. La primera vez tarda unos segundos en estar listo." $c.Green
    }
    Write-Cyber ("  Conexión: " + ($d.Info -f $Puerto)) $c.Cyan
    Write-Cyber "  Comprobar: probar localhost $Puerto        Parar: db-down $Tipo" $c.Dim
}

# db-down mysql [-Borrar]   →  para y quita el contenedor. Los datos se conservan salvo -Borrar
function db-down {
    param(
        [Parameter(Mandatory, Position = 0)][ValidateSet('mysql', 'mariadb', 'postgres', 'mongo', 'sqlserver', 'redis')][string]$Tipo,
        [switch]$Borrar
    )
    $c = Get-DevC
    if (-not (Test-DevDocker)) { return }
    $nombre = "dev-$Tipo"
    docker stop $nombre 2>$null | Out-Null
    docker rm $nombre 2>$null | Out-Null
    Write-Cyber "$nombre eliminado." $c.Green
    if ($Borrar) { docker volume rm "${nombre}-data" 2>$null | Out-Null; Write-Cyber "Datos borrados (volumen ${nombre}-data)." $c.Magenta }
    else { Write-Cyber "Los datos siguen en el volumen ${nombre}-data (db-down $Tipo -Borrar los elimina)." $c.Dim }
}

function db-list {
    if (-not (Test-DevDocker)) { return }
    docker ps -a --filter "name=^/dev-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# ================================================================= #
#  7. API Y SERVIDOR WEB                                             #
# ================================================================= #
# api https://...  [-Metodo POST] [-Cuerpo '{"a":1}']  → estado, tiempo y JSON bonito
function api {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Url,
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Metodo = 'GET',
        [string]$Cuerpo,
        [hashtable]$Cabeceras,
        [switch]$Crudo
    )
    $c = Get-DevC
    $p = @{ Uri = $Url; Method = $Metodo; UseBasicParsing = $true; ErrorAction = 'Stop' }
    if ($Cabeceras) { $p.Headers = $Cabeceras }
    if ($Cuerpo)    { $p.Body = $Cuerpo; $p.ContentType = 'application/json' }

    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    $codigo = 0; $texto = ''
    try {
        $r = Invoke-WebRequest @p
        $codigo = [int]$r.StatusCode
        $texto  = [string]$r.Content
    } catch {
        $reloj.Stop()
        $resp = $_.Exception.Response
        if ($resp) {
            $codigo = [int]$resp.StatusCode
            $texto  = [string]$_.ErrorDetails.Message
        } else {
            Write-Cyber "✗ No se pudo conectar: $($_.Exception.Message)" $c.Magenta
            return
        }
    }
    $reloj.Stop()

    $col = if ($codigo -ge 200 -and $codigo -lt 300) { $c.Green } elseif ($codigo -ge 400) { $c.Magenta } else { $c.Yellow }
    Write-Cyber ("{0} {1}  →  {2}   ({3} ms)" -f $Metodo, $Url, $codigo, [int]$reloj.Elapsed.TotalMilliseconds) $col
    if (-not $texto) { return }
    if ($Crudo) { Write-Host $texto; return }
    try   { Write-Host ($texto | ConvertFrom-Json | ConvertTo-Json -Depth 10) }
    catch { Write-Host $texto }
}

# servidor [-Puerto 8080] [-Carpeta .]  → servidor web estático para probar HTML/CSS/JS (Ctrl+C para parar)
function servidor {
    param([int]$Puerto = 8080, [string]$Carpeta = '.', [int]$Maximo = 0)
    $c = Get-DevC
    $raiz = (Resolve-Path -LiteralPath $Carpeta).ProviderPath.TrimEnd('\', '/')
    $tipos = @{
        html = 'text/html; charset=utf-8'; htm = 'text/html; charset=utf-8'; css = 'text/css; charset=utf-8'
        js = 'text/javascript; charset=utf-8'; json = 'application/json; charset=utf-8'; txt = 'text/plain; charset=utf-8'
        png = 'image/png'; jpg = 'image/jpeg'; jpeg = 'image/jpeg'; gif = 'image/gif'; svg = 'image/svg+xml'
        ico = 'image/x-icon'; webp = 'image/webp'; pdf = 'application/pdf'; woff2 = 'font/woff2'; xml = 'application/xml'
    }
    $l = New-Object System.Net.HttpListener
    $l.Prefixes.Add("http://localhost:$Puerto/")
    try { $l.Start() }
    catch {
        Write-Cyber "No se pudo abrir el puerto ${Puerto}: $($_.Exception.Message)" $c.Magenta
        Write-Cyber "¿Está ocupado?  puerto $Puerto" $c.Dim
        return
    }
    Write-Cyber "Sirviendo $raiz en  http://localhost:$Puerto/   (Ctrl+C para parar)" $c.Green
    $n = 0
    try {
        while ($l.IsListening) {
            $t = $l.GetContextAsync()
            while (-not $t.AsyncWaitHandle.WaitOne(200)) { }   # así Ctrl+C sí funciona
            $ctx = $t.GetAwaiter().GetResult()
            $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
            $ruta = [System.IO.Path]::GetFullPath((Join-Path $raiz ($rel -replace '/', [string][System.IO.Path]::DirectorySeparatorChar)))
            if (Test-Path -LiteralPath $ruta -PathType Container) { $ruta = Join-Path $ruta 'index.html' }

            $estado = 200
            if (-not $ruta.StartsWith($raiz)) { $estado = 403 }                       # nada de ../
            elseif (-not (Test-Path -LiteralPath $ruta -PathType Leaf)) { $estado = 404 }

            if ($estado -eq 200) {
                $bytes = [System.IO.File]::ReadAllBytes($ruta)
                $ext = [System.IO.Path]::GetExtension($ruta).TrimStart('.').ToLowerInvariant()
                $ctx.Response.ContentType = if ($tipos.ContainsKey($ext)) { $tipos[$ext] } else { 'application/octet-stream' }
            } else {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("$estado")
            }
            $ctx.Response.StatusCode = $estado
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $ctx.Response.Close()

            $col = if ($estado -eq 200) { $c.Cyan } else { $c.Magenta }
            Write-Cyber ("  {0}  {1}  {2}" -f $estado, $ctx.Request.HttpMethod, $ctx.Request.Url.AbsolutePath) $col
            $n++
            if ($Maximo -gt 0 -and $n -ge $Maximo) { break }
        }
    } finally {
        $l.Stop(); $l.Close()
        Write-Cyber "Servidor parado." $c.Dim
    }
}

# ================================================================= #
#  8. PROYECTOS NUEVOS                                               #
# ================================================================= #
function Get-DevPlantilla {
    param([string]$Tipo, [string]$Nombre)
    $f = [ordered]@{}
    switch ($Tipo) {
        'java' {
            $f['src/Main.java'] = @'
public class Main {
    public static void main(String[] args) {
        System.out.println("Hola desde __NOMBRE__");
    }
}
'@
            $f['.gitignore'] = "out/`ntarget/`n*.class`n.idea/`n*.iml`n.env`n"
        }
        'web' {
            $f['index.html'] = @'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>__NOMBRE__</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body>
  <h1>__NOMBRE__</h1>
  <p id="mensaje">Cargando...</p>
  <script src="js/app.js"></script>
</body>
</html>
'@
            $f['css/style.css'] = "body { font-family: system-ui, sans-serif; margin: 2rem; }`nh1 { color: #0a7; }`n"
            $f['js/app.js'] = "document.getElementById('mensaje').textContent = 'JavaScript funcionando';`n"
            $f['.gitignore'] = "node_modules/`n.env`n.DS_Store`n"
        }
        'node' {
            $f['package.json'] = "{`n  `"name`": `"__NOMBRE__`",`n  `"version`": `"1.0.0`",`n  `"main`": `"index.js`",`n  `"scripts`": { `"start`": `"node index.js`" }`n}`n"
            $f['index.js'] = "console.log('Hola desde __NOMBRE__');`n"
            $f['.gitignore'] = "node_modules/`n.env`n"
        }
    }
    $f['README.md'] = "# __NOMBRE__`n`nProyecto creado con ``nuevo $Tipo``.`n"
    $salida = [ordered]@{}
    foreach ($k in $f.Keys) { $salida[$k] = ($f[$k] -replace '__NOMBRE__', $Nombre) }
    return $salida
}

# nuevo java|web|node|dotnet <nombre>   →  carpeta + archivos base + git init
#   nuevo java practica-hilos      nuevo web mi-landing -Abrir
function nuevo {
    param(
        [Parameter(Mandatory, Position = 0)][ValidateSet('java', 'web', 'node', 'dotnet')][string]$Tipo,
        [Parameter(Mandatory, Position = 1)][string]$Nombre,
        [string]$Ruta,
        [switch]$Abrir
    )
    $c = Get-DevC
    if ($Nombre -notmatch '^[A-Za-z0-9._-]+$') { Write-Cyber "El nombre solo puede llevar letras, números, punto, guion y guion bajo." $c.Magenta; return }
    if (-not $Ruta) { $Ruta = if ($global:ReposPath) { $global:ReposPath } else { Join-Path $HOME 'Source\Repos' } }
    $dir = Join-Path $Ruta $Nombre
    if (Test-Path -LiteralPath $dir) { Write-Cyber "Ya existe $dir : elige otro nombre." $c.Magenta; return }

    if ($Tipo -eq 'dotnet') {
        if (-not (Test-DevComando dotnet)) { Write-Cyber "Falta el SDK de .NET (winget install Microsoft.DotNet.SDK.8)." $c.Magenta; return }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Push-Location $dir
        try { dotnet new console -n $Nombre -o . | Out-Null; dotnet new gitignore | Out-Null } finally { Pop-Location }
    } else {
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        $plantilla = Get-DevPlantilla -Tipo $Tipo -Nombre $Nombre
        foreach ($rel in $plantilla.Keys) {
            $destino = Join-Path $dir ($rel -replace '/', [string][System.IO.Path]::DirectorySeparatorChar)
            $carpeta = Split-Path $destino
            if (-not (Test-Path -LiteralPath $carpeta)) { New-Item -ItemType Directory -Path $carpeta -Force | Out-Null }
            [System.IO.File]::WriteAllText($destino, $plantilla[$rel], $utf8)
        }
    }

    if (Test-DevComando git) {
        git -C $dir init -q
        git -C $dir symbolic-ref HEAD refs/heads/main
    }
    Set-Location -LiteralPath $dir
    Write-Cyber "Proyecto '$Nombre' creado en $dir" $c.Green
    switch ($Tipo) {
        'java'   { Write-Cyber "  Siguiente:  cd src  ·  jr Main" $c.Dim }
        'web'    { Write-Cyber "  Siguiente:  servidor   (y abre http://localhost:8080/)" $c.Dim }
        'node'   { Write-Cyber "  Siguiente:  node index.js   (o  npm start)" $c.Dim }
        'dotnet' { Write-Cyber "  Siguiente:  dotnet run" $c.Dim }
    }
    if ($Abrir -and (Test-DevComando code)) { code . }
}

# ================================================================= #
#  9. SEGURIDAD: SECRETOS Y VARIABLES DE ENTORNO                     #
# ================================================================= #
# Dos familias de patrones: literales entre comillas (en cualquier archivo) y
# valores sin comillas (solo en archivos de configuración: .env, .properties, .yml...)
$global:DevPatrones = @(
    @{ N = 'Valor secreto en el código'; Solo = $null;
       R = '(?i)(password|passwd|pwd|secret|token|api[_-]?key|apikey|access[_-]?key)\w*\s*[=:]\s*["''][^"''\s]{4,}["'']' },
    @{ N = 'Valor secreto en configuración'; Solo = @('env', 'properties', 'yml', 'yaml', 'ini', 'conf', 'cfg', 'toml', 'json', 'xml');
       R = '(?i)^\s*[\w.\-]*(password|passwd|pwd|secret|token|api[_-]?key)[\w.\-]*\s*[=:]\s*[^\s"''#$\{<\[][^\s#]{3,}' },
    @{ N = 'Clave privada';       Solo = $null; R = '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' },
    @{ N = 'Clave de acceso AWS'; Solo = $null; R = 'AKIA[0-9A-Z]{16}' },
    @{ N = 'URL con usuario:clave'; Solo = $null; R = '[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s/:@"'']+:[^\s/@"'']{3,}@' }
)
$global:DevIgnorarLinea = '(?i)(example|ejemplo|changeme|cambiame|your[_-]|tu[_-]|xxxx|<.*>|\$\{)'

# secretos            revisa la carpeta (o el repo) buscando contraseñas, tokens y claves en texto plano
# secretos -Staged    solo lo que está preparado para commit (lo usa gac)
function secretos {
    param([string]$Ruta = '.', [switch]$Staged, [switch]$Silencioso)
    $c = Get-DevC
    $hallazgos = @()
    $archivos = @()
    $base = (Resolve-Path -LiteralPath $Ruta).ProviderPath
    $enRepo = $false
    if (Test-DevComando git) { $enRepo = ((git -C $base rev-parse --is-inside-work-tree 2>$null) -eq 'true') }

    if ($Staged -and $enRepo) {
        $top = (git -C $base rev-parse --show-toplevel).Trim()
        $base = $top
        foreach ($r in @(git -C $top diff --cached --name-only --diff-filter=ACM)) { $archivos += (Join-Path $top $r) }
    } elseif ($enRepo) {
        foreach ($r in @(git -C $base ls-files -co --exclude-standard)) { $archivos += (Join-Path $base $r) }
        foreach ($e in '.env', '.env.local') {
            $f = Join-Path $base $e
            if ((Test-Path -LiteralPath $f) -and ($archivos -notcontains $f)) { }   # ya ignorado: bien
        }
    } else {
        $archivos = @(Get-DevArchivos -Ruta $base | ForEach-Object { $_.FullName })
    }

    # Un .env dentro del repo sin ignorar es un secreto esperando a subirse
    if ($enRepo) {
        foreach ($f in @($archivos | Where-Object { (Split-Path $_ -Leaf) -match '^\.env(\.[a-z]+)?$' -and (Split-Path $_ -Leaf) -notmatch 'example|sample' })) {
            $hallazgos += [pscustomobject]@{ Archivo = ($f.Substring($base.Length).TrimStart('\', '/')); Linea = 0; Tipo = 'Archivo .env sin ignorar (añádelo a .gitignore)'; Texto = '' }
        }
    }

    foreach ($f in $archivos) {
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
        $it = Get-Item -LiteralPath $f -Force
        $ext = $it.Extension.TrimStart('.').ToLowerInvariant()
        if ($global:DevBinarios -contains $ext -or $it.Length -gt 1MB) { continue }
        if ($it.Name -match 'example|sample') { continue }
        $n = 0
        foreach ($linea in @(Get-Content -LiteralPath $f -ErrorAction SilentlyContinue)) {
            $n++
            $s = "$linea"
            if ($s.Length -gt 400 -or $s -match $global:DevIgnorarLinea) { continue }
            foreach ($p in $global:DevPatrones) {
                if ($p.Solo -and ($p.Solo -notcontains $ext) -and ($it.Name -notmatch '^\.env')) { continue }
                if ($s -match $p.R) {
                    $mask = ($s.Trim() -replace '([=:]\s*["'']?)[^\s"'']{4,}', '$1***')
                    if ($mask.Length -gt 80) { $mask = $mask.Substring(0, 80) + '…' }
                    $hallazgos += [pscustomobject]@{
                        Archivo = ($f.Substring($base.Length).TrimStart('\', '/')); Linea = $n; Tipo = $p.N; Texto = $mask }
                    break
                }
            }
        }
    }

    if (-not $Silencioso) {
        if ($hallazgos.Count -eq 0) { Write-Cyber "✔ No he visto secretos en texto plano ($($archivos.Count) archivos revisados)." $c.Green }
        else {
            Write-Cyber "⚠ $($hallazgos.Count) posible(s) secreto(s):" $c.Magenta
            foreach ($h in $hallazgos) {
                Write-Cyber ("  {0}:{1}" -f $h.Archivo, $h.Linea) $c.Yellow -NoNewline
                Write-Cyber ("  [{0}]  {1}" -f $h.Tipo, $h.Texto) $c.Cyan
            }
            Write-Cyber "  Mueve los valores a variables de entorno o a un .env ignorado por git (cargar-env)." $c.Dim
        }
    }
    return $hallazgos
}

# cargar-env [.env]   carga KEY=VALOR en las variables de entorno de ESTA terminal (solo muestra los nombres)
function cargar-env {
    param([string]$Archivo = '.env', [switch]$Quitar)
    $c = Get-DevC
    if (-not (Test-Path -LiteralPath $Archivo)) { Write-Cyber "No existe $Archivo" $c.Magenta; return }
    $nombres = @()
    foreach ($l in @(Get-Content -LiteralPath $Archivo)) {
        $t = "$l".Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        if ($t -notmatch '^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') { continue }
        $k = $Matches[1]; $v = $Matches[2].Trim()
        if ($v.Length -ge 2 -and (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")))) {
            $v = $v.Substring(1, $v.Length - 2)
        } else { $v = ($v -replace '\s+#.*$', '') }
        if ($Quitar) { [System.Environment]::SetEnvironmentVariable($k, $null, 'Process') }
        else         { [System.Environment]::SetEnvironmentVariable($k, $v, 'Process') }
        $nombres += $k
    }
    $accion = if ($Quitar) { 'quitadas' } else { 'cargadas' }
    Write-Cyber "$($nombres.Count) variables $accion desde ${Archivo}: $($nombres -join ', ')" $c.Green
}

# ================================================================= #
#  10. LIMPIEZA Y BÚSQUEDA                                           #
# ================================================================= #
# limpia [-WhatIf]  borra carpetas que se regeneran (node_modules, target, bin/obj, __pycache__...)
# Solo borra bin/obj/target/dist/build cuando al lado hay un proyecto que las genera.
function Test-DevLimpiable {
    param([string]$Nombre, [string]$Padre)
    switch ($Nombre) {
        'node_modules' { return $true }
        '__pycache__'  { return $true }
        '.gradle'      { return $true }
        'target' { return ((Test-Path (Join-Path $Padre 'pom.xml')) -or (Test-Path (Join-Path $Padre 'Cargo.toml'))) }
        { $_ -in 'bin', 'obj' } { return [bool](Get-ChildItem -LiteralPath $Padre -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.csproj', '.fsproj', '.vbproj' }) }
        'build' { return ((Test-Path (Join-Path $Padre 'build.gradle')) -or (Test-Path (Join-Path $Padre 'build.gradle.kts'))) }
        'dist'  { return (Test-Path (Join-Path $Padre 'package.json')) }
    }
    return $false
}

function limpia {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Ruta = '.', [switch]$Si)
    $c = Get-DevC
    $pend = New-Object System.Collections.Stack
    $pend.Push((Resolve-Path -LiteralPath $Ruta).ProviderPath)
    $cand = @()
    while ($pend.Count -gt 0) {
        $d = $pend.Pop()
        foreach ($e in @(Get-ChildItem -LiteralPath $d -Directory -Force -ErrorAction SilentlyContinue)) {
            if ($e.Name -eq '.git') { continue }
            if (Test-DevLimpiable -Nombre $e.Name -Padre $d) { $cand += $e.FullName }
            else { $pend.Push($e.FullName) }
        }
    }
    if ($cand.Count -eq 0) { Write-Cyber "Nada que limpiar." $c.Green; return }

    $total = 0
    foreach ($x in $cand) {
        $mb = (Get-ChildItem -LiteralPath $x -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
        $total += $mb
        Write-Cyber ("  {0,8:N1} MB  {1}" -f $mb, $x) $c.Cyan
    }
    Write-Cyber ("  {0} carpetas, {1:N1} MB en total" -f $cand.Count, $total) $c.Yellow
    if ($WhatIfPreference) { return }
    if (-not $Si) {
        $r = Read-Host "¿Borrarlas? (s/N)"
        if ($r -notmatch '^[sSyY]') { Write-Cyber "Cancelado." $c.Dim; return }
    }
    foreach ($x in $cand) {
        if ($PSCmdlet.ShouldProcess($x, 'Borrar')) { Remove-Item -LiteralPath $x -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Cyber "Listo: $([math]::Round($total,1)) MB liberados." $c.Green
}

# grepr <texto> [-Ext java,js] [-Literal]   busca en todos los archivos de código (sin node_modules, .git, target...)
function grepr {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Patron,
        [string[]]$Ext,
        [string]$Ruta = '.',
        [switch]$Literal,
        [switch]$Mayus,
        [int]$Max = 200
    )
    $c = Get-DevC
    $base = (Resolve-Path -LiteralPath $Ruta).ProviderPath
    $n = 0
    foreach ($f in @(Get-DevArchivos -Ruta $base -Ext $Ext)) {
        if ($global:DevBinarios -contains $f.Extension.TrimStart('.').ToLowerInvariant() -or $f.Length -gt 1MB) { continue }
        $r = Select-String -LiteralPath $f.FullName -Pattern $Patron -SimpleMatch:$Literal -CaseSensitive:$Mayus -ErrorAction SilentlyContinue
        foreach ($m in $r) {
            $rel = $f.FullName.Substring($base.Length).TrimStart('\', '/')
            $txt = $m.Line.Trim(); if ($txt.Length -gt 110) { $txt = $txt.Substring(0, 110) + '…' }
            Write-Cyber $rel $c.Yellow -NoNewline
            Write-Cyber (":{0}: " -f $m.LineNumber) $c.Green -NoNewline
            Write-Cyber $txt $c.Cyan
            $n++
            if ($n -ge $Max) { Write-Cyber "  (paro en $Max resultados: usa -Ext o un patrón más concreto)" $c.Dim; return }
        }
    }
    if ($n -eq 0) { Write-Cyber "Sin resultados para '$Patron'." $c.Dim }
}

# abrir  → abre la carpeta actual en el Explorador
function abrir { Invoke-Item . }
# repos  → ir a la carpeta de repositorios
function repos { if ($global:ReposPath) { Set-Location $global:ReposPath } else { Write-Cyber "Define `$global:ReposPath" (Get-DevC).Dim } }

# ================================================================= #
#  11. JAVA: VARIOS JDK                                              #
# ================================================================= #
function Get-DevJdkRaices {
    $r = @()
    foreach ($b in $env:ProgramFiles, ${env:ProgramFiles(x86)}) {
        if (-not $b) { continue }
        foreach ($s in 'Java', 'Eclipse Adoptium', 'Microsoft', 'Amazon Corretto', 'Zulu', 'BellSoft', 'Semeru', 'GraalVM') { $r += (Join-Path $b $s) }
    }
    $r += (Join-Path $HOME '.jdks')      # aquí descarga los JDK IntelliJ IDEA
    return $r
}

function Get-DevJdks {
    param([string[]]$Raices)
    if (-not $Raices) { $Raices = Get-DevJdkRaices }
    $res = @()
    foreach ($r in $Raices) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue)) {
            $javac = Join-Path $d.FullName 'bin\javac.exe'
            if (-not (Test-Path $javac)) { $javac = Join-Path $d.FullName 'bin/javac' }
            if (-not (Test-Path $javac)) { continue }
            $mayor = 0
            if ($d.Name -match '(?<![\d.])1\.(\d+)') { $mayor = [int]$Matches[1] }
            elseif ($d.Name -match '(?<!\d)(\d{1,2})(?!\d)') { $mayor = [int]$Matches[1] }
            $res += [pscustomobject]@{ Mayor = $mayor; Nombre = $d.Name; Ruta = $d.FullName }
        }
    }
    return @($res | Sort-Object Mayor, Nombre)
}

# javas  → JDK instalados (marca el activo).   usa-java 17  → cambia a ese JDK en ESTA terminal
function javas {
    param([string[]]$Raices)
    $c = Get-DevC
    $l = @(Get-DevJdks -Raices $Raices)
    if ($l.Count -eq 0) { Write-Cyber "No encuentro JDK en las carpetas habituales (Program Files\Java, Adoptium, ~/.jdks...)." $c.Dim; return }
    foreach ($j in $l) {
        $activo = ($env:JAVA_HOME -and ($env:JAVA_HOME.TrimEnd('\', '/') -ieq $j.Ruta))
        $marca = if ($activo) { '►' } else { ' ' }
        $col = if ($activo) { $c.Green } else { $c.Cyan }
        Write-Cyber ("  {0} Java {1,-3} {2,-28} {3}" -f $marca, $j.Mayor, $j.Nombre, $j.Ruta) $col
    }
    Write-Cyber "  Cambiar:  usa-java <número>   (solo afecta a esta terminal)" $c.Dim
}

function usa-java {
    param([Parameter(Mandatory, Position = 0)][int]$Version, [string[]]$Raices)
    $c = Get-DevC
    $j = @(Get-DevJdks -Raices $Raices | Where-Object { $_.Mayor -eq $Version }) | Select-Object -Last 1
    if (-not $j) { Write-Cyber "No hay un JDK $Version instalado. Mira cuáles tienes con:  javas" $c.Magenta; return }
    $sep = [string][System.IO.Path]::PathSeparator
    $viejo = $env:JAVA_HOME
    $partes = @($env:PATH -split [regex]::Escape($sep) | Where-Object { $_ })
    if ($viejo) { $partes = @($partes | Where-Object { $_.TrimEnd('\', '/') -ine (Join-Path $viejo 'bin').TrimEnd('\', '/') }) }
    $env:JAVA_HOME = $j.Ruta
    $env:PATH = ((Join-Path $j.Ruta 'bin') + $sep + ($partes -join $sep))
    Write-Cyber "JAVA_HOME = $($j.Ruta)" $c.Green
    if (Test-DevComando java) { java -version 2>&1 | Select-Object -First 1 | ForEach-Object { Write-Cyber "  $_" $c.Cyan } }
}

# ================================================================= #
#  12. dev: ESTADO DE UN VISTAZO                                     #
# ================================================================= #
function dev {
    $c = Get-DevC
    Write-Cyber "  Proyecto: $(Split-Path -Leaf (Get-Location))" $c.Green
    if ((Test-DevComando git) -and ((git rev-parse --is-inside-work-tree 2>$null) -eq 'true')) {
        $rama = git branch --show-current
        $cambios = @(git status --porcelain).Count
        $txt = if ($cambios -eq 0) { 'limpio' } else { "$cambios archivo(s) con cambios" }
        Write-Cyber ("  {0,-9}{1}  ·  {2}" -f 'Git', $rama, $txt) $c.Cyan
    } else { Write-Cyber ("  {0,-9}(no es un repositorio)" -f 'Git') $c.Dim }

    $v = @(Get-EntornoDatos -Cache | Where-Object { $_.Version })
    if ($v.Count -gt 0) { Write-Cyber ("  {0,-9}{1}" -f 'Entorno', (($v | ForEach-Object { "$($_.Nombre) $($_.Version)" }) -join '  ·  ')) $c.Cyan }

    if ((Test-DevComando docker) -and (Get-Process -Name 'com.docker.backend', 'dockerd' -ErrorAction SilentlyContinue)) {
        $bd = @(docker ps --filter 'name=^/dev-' --format '{{.Names}} ({{.Ports}})' 2>$null)
        if ($bd.Count -gt 0) { Write-Cyber ("  {0,-9}{1}" -f 'BD Docker', ($bd -join ' · ')) $c.Cyan }
    }
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        $dev = 3000, 3306, 4200, 5000, 5173, 5432, 8000, 8080, 27017, 1433, 6379
        $ocu = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $dev -contains $_.LocalPort } |
                 Select-Object -ExpandProperty LocalPort -Unique | Sort-Object)
        if ($ocu.Count -gt 0) { Write-Cyber ("  {0,-9}{1}   (puerto <n> para ver quién)" -f 'Puertos', ($ocu -join ', ')) $c.Yellow }
    }
}

# ================================================================= #
#  AYUDA (la lee Developer2077.ps1 para help-ps / ayuda)             #
# ================================================================= #
$global:DevAyuda = @(
    @{ K = "dev";                    D = "Estado de un vistazo: rama de git, herramientas, BD en Docker, puertos de desarrollo ocupados" }
    @{ K = "entorno";                D = "Versiones de Java, javac, Maven, Git, .NET, Node, npm, Python y Docker" }
    @{ K = "jr <Clase> [args]";      D = "javac + java en un comando (solo ejecuta si compiló bien)" }
    @{ K = "javas / usa-java 17";    D = "Ver los JDK instalados y cambiar de JDK en esta terminal" }
    @{ K = "gst / glog / gdif";      D = "git status corto / últimos commits en árbol / resumen de cambios" }
    @{ K = "gac <mensaje>";          D = "git add + commit, avisando antes si hay contraseñas o claves" }
    @{ K = "gsync";                  D = "git pull --rebase y luego push" }
    @{ K = "gramas / gnueva / gvolver"; D = "Ver ramas / crear una rama / volver a la anterior" }
    @{ K = "procesos [-Top n]";      D = "Procesos con más CPU: PID, RAM e hilos (-Nombre filtra)" }
    @{ K = "hijos [pid] / arbol";    D = "Procesos hijos de un PID / árbol de procesos desde tu terminal" }
    @{ K = "lanzar prog args";       D = "Tu ProcessBuilder: PID, stdout, stderr, código de salida y tiempo" }
    @{ K = "mide { } [-Veces n]";    D = "Cuánto tarda un bloque de código (con -Veces, la media)" }
    @{ K = "proceso-vs-hilo";        D = "Start-Job (proceso, otro PID) frente a Start-ThreadJob (hilo, mismo PID)" }
    @{ K = "servicios [texto]";      D = "Servicios de Windows en marcha (-Parados para los detenidos)" }
    @{ K = "puerto <n> / libera <n>"; D = "Quién usa un puerto / terminar el proceso que lo escucha" }
    @{ K = "probar host puerto";     D = "¿Responde ese servidor en ese puerto? (BD, API...)" }
    @{ K = "mi-ip / ssh-hosts";      D = "Tus IPv4 activas / los Host de ~/.ssh/config" }
    @{ K = "db-up <tipo>";           D = "Base de datos en Docker: mysql, mariadb, postgres, mongo, sqlserver, redis" }
    @{ K = "db-down <tipo> / db-list"; D = "Quitar la BD (los datos se conservan; -Borrar los elimina) / listar" }
    @{ K = "api <url> [-Metodo]";    D = "Llamada HTTP con estado, tiempo y JSON legible (-Cuerpo, -Cabeceras, -Crudo)" }
    @{ K = "servidor [-Puerto 8080]"; D = "Servidor web estático para HTML/CSS/JS (Ctrl+C para parar)" }
    @{ K = "nuevo <tipo> <nombre>";  D = "Proyecto nuevo con git init: java, web, node o dotnet (-Abrir lo abre en VS Code)" }
    @{ K = "secretos [-Staged]";     D = "Busca contraseñas, tokens y claves en texto plano en el repo" }
    @{ K = "cargar-env [.env]";      D = "Carga las variables de un .env en esta terminal (-Quitar las borra)" }
    @{ K = "limpia [-WhatIf]";       D = "Borra node_modules, target, bin/obj, __pycache__... (enseña el tamaño antes)" }
    @{ K = "grepr <texto> [-Ext js]"; D = "Buscar texto en el código, sin node_modules, .git ni target" }
    @{ K = "abrir / repos";          D = "Abrir la carpeta en el Explorador / ir a tu carpeta de repositorios" }
)
