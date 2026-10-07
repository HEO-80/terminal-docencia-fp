# ================================================================= #
#        SANTUARIO: APRENDE A ESCRIBIR SCRIPTS (bash, vía WSL)       #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).
#
# Igual que Forja, pero para bash: lo lanzas desde tu terminal de
# PowerShell y el código se ejecuta dentro de tu Linux (WSL2).
#
#   1. `santuario` te da una misión y abre un archivo .sh de plantilla.
#   2. Escribes tu función o script y guardas.
#   3. Enter (o 'probar') y Santuario lo ejecuta en WSL contra varios
#      casos de prueba, en una carpeta temporal de Linux.
#   4. Los fallos entran en el mismo repaso espaciado que el resto.
#
# Notas técnicas:
#   - Se usa SIEMPRE una distro concreta (-d), nunca la predeterminada:
#     en muchos equipos la predeterminada es 'docker-desktop', que no sirve.
#   - Tu archivo se lee desde Windows y se copia a /tmp de Linux quitando
#     los saltos de línea de Windows (CRLF) y el BOM, para que bash no
#     falle aunque tu editor los añada.
#   - Los tests corren en /tmp (sistema de archivos de Linux), no en /mnt/c,
#     para que chmod, permisos y fechas funcionen como en Linux de verdad.
#   - Los comandos peligrosos (systemctl...) se simulan con mocks: nunca se
#     toca un servicio real.

# Por si se carga este archivo suelto (sin el tema)
if (-not (Get-Command Write-Cyber -ErrorAction SilentlyContinue)) {
    function Write-Cyber {
        param([string]$Text, [string]$Color, [switch]$NoNewline)
        Write-Host $Text -NoNewline:$NoNewline
    }
}

# ================================================================= #
#                     UTILIDADES DE WSL Y RUTAS                     #
# ================================================================= #
$script:SantuarioDistro = $null

function Get-SantuarioWorkspace {
    $dir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "CyberProfile\santuario" } else { Join-Path $HOME ".cache/cyberprofile/santuario" }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

# Escribe texto con saltos LF y UTF-8 SIN BOM (lo que espera bash)
function Write-SantuarioFile {
    param([string]$Path, [string]$Text)
    $lf = ($Text -replace "`r`n", "`n")
    if (-not $lf.EndsWith("`n")) { $lf += "`n" }
    [System.IO.File]::WriteAllText($Path, $lf, (New-Object System.Text.UTF8Encoding($false)))
}

# C:\Users\Ana\x.sh  ->  /mnt/c/Users/Ana/x.sh   (rutas ya de Linux se dejan igual)
function ConvertTo-WslPath {
    param([string]$Path)
    if ($Path -match '^([A-Za-z]):[\\/](.*)$') {
        return "/mnt/$($Matches[1].ToLower())/$($Matches[2] -replace '\\', '/')"
    }
    return ($Path -replace '\\', '/')
}

function ConvertTo-BashSq { param([string]$s) return ($s -replace "'", "'\''") }

function ConvertTo-B64 { param([string]$s) return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($s)) }

function ConvertFrom-B64 {
    param([string]$s)
    if ([string]::IsNullOrEmpty($s)) { return '' }
    try { return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) } catch { return '' }
}

# wsl.exe escribe sus propios mensajes en UTF-16; lo que ejecuta Linux sale en UTF-8.
function ConvertFrom-WslBytes {
    param([byte[]]$Bytes)
    if (-not $Bytes -or $Bytes.Length -eq 0) { return '' }
    if ($Bytes -contains 0) { return [System.Text.Encoding]::Unicode.GetString($Bytes) }
    return [System.Text.Encoding]::UTF8.GetString($Bytes)
}

# Ejecuta wsl.exe con un tiempo máximo. Devuelve Out, Err, Code, TimedOut, Fallo.
# ($env:SANTUARIO_WSL permite indicar otro ejecutable; por defecto wsl.exe)
function Invoke-SantuarioWsl {
    param([string]$Arguments, [int]$TimeoutSec = 30)

    $exe = if ($env:SANTUARIO_WSL) { $env:SANTUARIO_WSL } else { 'wsl.exe' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.RedirectStandardInput  = $true
    $psi.CreateNoWindow = $true

    $res = @{ Out = ''; Err = ''; Code = -1; TimedOut = $false; Fallo = '' }
    $p = $null
    try { $p = [System.Diagnostics.Process]::Start($psi) }
    catch { $res.Fallo = "No pude lanzar '$exe': $($_.Exception.Message)"; return $res }

    try {
        $msO = New-Object System.IO.MemoryStream
        $msE = New-Object System.IO.MemoryStream
        $p.StandardInput.Close()
        $tO = $p.StandardOutput.BaseStream.CopyToAsync($msO)
        $tE = $p.StandardError.BaseStream.CopyToAsync($msE)
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            $res.TimedOut = $true
            try { $p.Kill() } catch {}
        }
        try { [void]$tO.Wait(3000) } catch {}
        try { [void]$tE.Wait(3000) } catch {}
        $res.Out  = ConvertFrom-WslBytes $msO.ToArray()
        $res.Err  = ConvertFrom-WslBytes $msE.ToArray()
        if ($p.HasExited) { $res.Code = $p.ExitCode }
    }
    catch { $res.Fallo = "Error al ejecutar WSL: $($_.Exception.Message)" }
    finally { try { $p.Dispose() } catch {} }
    return $res
}

# Comprueba WSL, elige distro y verifica las herramientas que usan los tests.
# Devuelve @{ Ok; Distro; Mensaje }.  Se cachea la distro elegida en la sesión.
function Test-SantuarioEntorno {
    param([switch]$Forzar)

    if ($script:SantuarioDistro -and -not $Forzar) {
        return @{ Ok = $true; Distro = $script:SantuarioDistro; Mensaje = '' }
    }

    $exe = if ($env:SANTUARIO_WSL) { $env:SANTUARIO_WSL } else { 'wsl.exe' }
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        return @{ Ok = $false; Distro = ''; Mensaje = "No encuentro WSL ($exe). Instálalo desde un PowerShell de administrador:  wsl --install" }
    }

    Write-Cyber "  Despertando WSL (la primera vez puede tardar unos segundos)..." $global:CY.Dim
    $l = Invoke-SantuarioWsl -Arguments '-l -q' -TimeoutSec 60
    if ($l.Fallo) { return @{ Ok = $false; Distro = ''; Mensaje = $l.Fallo } }

    $distros = @(($l.Out -replace "`0", '') -split "[`r`n]+" | ForEach-Object { $_.Trim() } |
                 Where-Object { $_ -and $_ -notlike 'docker-desktop*' })
    if ($distros.Count -eq 0) {
        return @{ Ok = $false; Distro = ''; Mensaje = "No hay ninguna distro de Linux instalada (docker-desktop no cuenta). Instala una:  wsl --install -d Ubuntu" }
    }

    $distro = $null
    if ($env:SANTUARIO_DISTRO) {
        if ($distros -contains $env:SANTUARIO_DISTRO) { $distro = $env:SANTUARIO_DISTRO }
        else { return @{ Ok = $false; Distro = ''; Mensaje = "`$env:SANTUARIO_DISTRO='$($env:SANTUARIO_DISTRO)' no está en 'wsl -l -q' (hay: $($distros -join ', '))." } }
    }
    if (-not $distro) { $distro = @($distros | Where-Object { $_ -like 'Ubuntu*' } | Select-Object -First 1)[0] }
    if (-not $distro) { $distro = $distros[0] }

    $t = Invoke-SantuarioWsl -Arguments "-d $distro -e which timeout base64 mktemp find sed tr" -TimeoutSec 60
    if ($t.Fallo -or $t.TimedOut) {
        return @{ Ok = $false; Distro = $distro; Mensaje = "No pude arrancar '$distro' (¿WSL parado o bloqueado?). $($t.Fallo)" }
    }
    if ($t.Code -ne 0) {
        return @{ Ok = $false; Distro = $distro; Mensaje = "A '$distro' le faltan herramientas básicas (timeout, base64, mktemp, find, sed, tr). Salida: $((($t.Err + $t.Out) -replace "`0",'').Trim())" }
    }

    $script:SantuarioDistro = $distro
    return @{ Ok = $true; Distro = $distro; Mensaje = '' }
}

function Show-SantuarioDiagnostico {
    $c = $global:CY
    if (-not $c) { $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" } }
    Write-Host ""
    Write-Cyber "  DIAGNÓSTICO DE SANTUARIO" $c.Green
    $e = Test-SantuarioEntorno -Forzar
    if ($e.Ok) {
        Write-Cyber "  ✔ WSL responde y la distro '$($e.Distro)' tiene las herramientas necesarias." $c.Green
        $v = Invoke-SantuarioWsl -Arguments "-d $($e.Distro) -e bash --version" -TimeoutSec 30
        $primera = (($v.Out -replace "`0", '') -split "[`r`n]+" | Select-Object -First 1)
        Write-Cyber "  ✔ $primera" $c.Cyan
        Write-Cyber "  Los tests se ejecutan con:  wsl -d $($e.Distro) -e bash ..." $c.Dim
    } else {
        Write-Cyber "  ✘ $($e.Mensaje)" $c.Magenta
    }
    Write-Host ""
}

# ================================================================= #
#                       MOTOR DE PRUEBAS (bash)                     #
# ================================================================= #

# Cuerpo fijo del arnés. Se ejecuta DENTRO de Linux. Va precedido de
# USERFILE y KIND, y seguido de la definición de los casos.
$script:SantuarioHarnessCore = @'
WORK=$(mktemp -d /tmp/santuario.XXXXXX) || exit 99
export SANDBOX="$WORK/sandbox"
export SCRIPT="$WORK/user.sh"
export KIND
mkdir -p "$SANDBOX"
trap 'rm -rf "$WORK"' EXIT

if [ ! -r "$USERFILE" ]; then echo "@@NOFILE"; exit 0; fi

# Quita saltos de línea de Windows (CRLF) y el BOM que meten algunos editores
tr -d '\r' < "$USERFILE" | sed '1s/^\xEF\xBB\xBF//' > "$SCRIPT"

# Comprobación de sintaxis antes de ejecutar nada
if ! syn=$(bash -n "$SCRIPT" 2>&1); then
    echo "@@SYNTAX|$(printf %s "$syn" | sed "s#$SCRIPT#tu_script#g" | base64 -w0)"
    exit 0
fi

# Crea un comando falso en $SANDBOX/bin (se antepone al PATH en cada caso)
mkmock() {
    mkdir -p "$SANDBOX/bin"
    { echo '#!/bin/bash'; printf '%s\n' "$2"; } > "$SANDBOX/bin/$1"
    chmod +x "$SANDBOX/bin/$1"
}
export -f mkmock

run_case() {
    local idx="$1" rc out err
    find "$SANDBOX" -mindepth 1 -delete 2>/dev/null
    out=$(PREP="$2" RUN="$3" timeout 8 bash -c '
        cd "$SANDBOX" || exit 98
        export PATH="$SANDBOX/bin:$PATH"
        if [ "$KIND" = funcion ]; then source "$SCRIPT" >/dev/null; fi
        eval "$PREP"
        eval "$RUN"
    ' 2>"$WORK/err" </dev/null)
    rc=$?
    err=$(cat "$WORK/err")
    echo "@@CASE|$idx|$rc|$(printf %s "$out" | base64 -w0)|$(printf %s "$err" | base64 -w0)"
}
'@

function New-SantuarioHarness {
    param($Mision, [string]$UserFileWsl)

    $kind = if ($Mision.Tipo -eq 'script') { 'script' } else { 'funcion' }
    $n = @($Mision.Tests).Count
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('#!/bin/bash')
    $lines.Add("USERFILE='$(ConvertTo-BashSq $UserFileWsl)'")
    $lines.Add("KIND='$kind'")
    $lines.Add($script:SantuarioHarnessCore)
    $lines.Add('declare -a PREPS RUNS')
    $i = 0
    foreach ($t in @($Mision.Tests)) {
        $i++
        $prep = if ($t.Prep) { "$($t.Prep)" } else { '' }
        $lines.Add("PREPS[$i]=`$(printf %s '$(ConvertTo-B64 $prep)' | base64 -d)")
        $lines.Add("RUNS[$i]=`$(printf %s '$(ConvertTo-B64 "$($t.Run)")' | base64 -d)")
    }
    $lines.Add("for i in `$(seq 1 $n); do run_case `"`$i`" `"`${PREPS[`$i]}`" `"`${RUNS[`$i]}`"; done")
    return (($lines -join "`n") + "`n")
}

function ConvertTo-SantuarioNorm {
    param([string]$Texto, [string]$Modo = 'exacto')
    $t = ($Texto -replace "`r", '')
    $t = $t.TrimEnd("`n")
    $ls = @($t -split "`n")
    if ($Modo -eq 'espacios') { $ls = @($ls | ForEach-Object { ($_.Trim() -replace '\s+', ' ') }) }
    if ($Modo -eq 'orden')    { $ls = @($ls | Sort-Object) }
    return ($ls -join "`n")
}

function Format-SantuarioLinea {
    param([string]$Texto)
    if ($null -eq $Texto -or $Texto -eq '') { return '(vacío)' }
    $s = ($Texto -replace "`r", '') -replace "`n", ' ↵ '
    if ($s.Length -gt 170) { $s = $s.Substring(0, 170) + '...' }
    return $s
}

# Ejecuta tu archivo contra los casos de la misión.
# Devuelve @{ Resultados = <lista>; Aviso = <texto> }
function Invoke-SantuarioTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Mision,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Distro
    )

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "Santuario"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $harnessFile = Join-Path $tmp "run.sh"
    $aviso = ''
    $resultados = @()

    try {
        $harness = New-SantuarioHarness -Mision $Mision -UserFileWsl (ConvertTo-WslPath $File)
        Write-SantuarioFile -Path $harnessFile -Text $harness

        $n = @($Mision.Tests).Count
        $r = Invoke-SantuarioWsl -Arguments "-d $Distro -e bash `"$(ConvertTo-WslPath $harnessFile)`"" -TimeoutSec (20 + 9 * $n)

        if ($r.Fallo) { return @{ Resultados = @(); Aviso = $r.Fallo } }
        if ($r.TimedOut) { return @{ Resultados = @(); Aviso = "Tiempo agotado: WSL no respondió a tiempo." } }

        $lineas = @(($r.Out -replace "`r", '') -split "`n")
        if ($lineas -contains '@@NOFILE') { return @{ Resultados = @(); Aviso = "No encuentro tu archivo desde Linux ($File). ¿Está WSL montando el disco C: en /mnt/c?" } }

        $sint = @($lineas | Where-Object { $_ -like '@@SYNTAX|*' } | Select-Object -First 1)
        if ($sint.Count -gt 0 -and $sint[0]) {
            $msg = (ConvertFrom-B64 ($sint[0].Split('|')[1])).Trim()
            $msg = ($msg -split "`n" | Select-Object -First 3) -join ' | '
            return @{ Resultados = @(@{ Nombre = 'Comprobar la sintaxis de tu script'; Ok = $false; Esperado = 'un script bash sin errores de sintaxis'; Obtenido = $msg; Stderr = '' }); Aviso = '' }
        }

        $casos = @{}
        foreach ($l in $lineas) {
            if ($l -like '@@CASE|*') {
                $p = $l.Split('|')
                if ($p.Count -ge 5) {
                    $casos[[int]$p[1]] = @{ Rc = [int]$p[2]; Out = (ConvertFrom-B64 $p[3]); Err = (ConvertFrom-B64 $p[4]) }
                }
            }
        }

        if ($casos.Count -eq 0) {
            $detalle = (($r.Err + ' ' + $r.Out) -replace "`0", '').Trim()
            if ($detalle.Length -gt 300) { $detalle = $detalle.Substring(0, 300) + '...' }
            return @{ Resultados = @(); Aviso = "No obtuve resultados de Linux. $detalle" }
        }

        $i = 0
        foreach ($t in @($Mision.Tests)) {
            $i++
            $c = $casos[$i]
            if (-not $c) {
                $resultados += @{ Nombre = $t.Nombre; Ok = $false; Esperado = '(un resultado)'; Obtenido = 'el caso no llegó a ejecutarse'; Stderr = '' }
                continue
            }

            $modo = if ($t.Modo) { $t.Modo } else { 'exacto' }
            $obt  = ConvertTo-SantuarioNorm $c.Out $modo
            $ok   = $false
            $desc = ''

            if ($c.Rc -eq 124) {
                $desc = "tiempo agotado (8 s): ¿bucle infinito o esperando entrada?"
                $obtTxt = $desc
            }
            elseif ($t.FallaEsperada) {
                $ok = ($c.Rc -ne 0) -and ($obt -eq '')
                $desc = 'terminar con código distinto de 0 y sin escribir nada en la salida estándar'
                $obtTxt = "código $($c.Rc); salida: $(Format-SantuarioLinea $obt)"
            }
            else {
                $esp = ConvertTo-SantuarioNorm "$($t.Esperado)" $modo
                $ok  = ($obt -ceq $esp)
                if ($t.SinStderr -and $c.Err.Trim() -ne '') { $ok = $false }
                $desc = Format-SantuarioLinea $esp
                $obtTxt = Format-SantuarioLinea $obt
                if ($t.SinStderr -and $c.Err.Trim() -ne '') { $obtTxt += "   (además escribió en stderr: $(Format-SantuarioLinea $c.Err.Trim()))" }
            }

            $resultados += @{ Nombre = $t.Nombre; Ok = $ok; Esperado = $desc; Obtenido = $obtTxt; Stderr = $c.Err.Trim() }
        }
    }
    catch { $aviso = "Error interno al probar: $($_.Exception.Message)" }
    finally { Remove-Item $harnessFile -Force -ErrorAction SilentlyContinue }

    return @{ Resultados = $resultados; Aviso = $aviso }
}

function Show-SantuarioResultados {
    param($Res)
    $c = $global:CY
    if ($Res.Aviso) { Write-Cyber "  ⚠ $($Res.Aviso)" $c.Magenta }
    $bien = 0
    foreach ($r in @($Res.Resultados)) {
        if ($r.Ok) {
            $bien++
            Write-Cyber "  ✔ $($r.Nombre)" $c.Green
        } else {
            Write-Cyber "  ✘ $($r.Nombre)" $c.Magenta
            Write-Cyber "      esperado: $($r.Esperado)" $c.Dim
            Write-Cyber "      obtenido: $($r.Obtenido)" $c.Dim
            if ($r.Stderr) { Write-Cyber "      errores:  $(Format-SantuarioLinea $r.Stderr)" $c.Dim }
        }
    }
    return $bien
}

function Open-SantuarioEditor {
    param([string]$File)
    try {
        if ($env:FORJA_EDITOR) { & $env:FORJA_EDITOR $File; return $true }
        if (Get-Command code -ErrorAction SilentlyContinue) { & code $File; return $true }
        if ($env:OS -eq 'Windows_NT') { Start-Process notepad $File; return $true }
    } catch {}
    return $false
}

# ================================================================= #
#                    BUCLE COMÚN DE UNA MISIÓN                      #
# ================================================================= #
function Invoke-SantuarioMision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Mision,
        [Parameter(Mandatory)][string]$MisionId,
        [Parameter(Mandatory)][string]$Distro,
        [string]$Titulo = 'SANTUARIO',
        [switch]$SinEditor,
        [switch]$Continuar
    )

    $c = $global:CY
    if (-not $c) { $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" } }

    $ws   = Get-SantuarioWorkspace
    $file = Join-Path $ws "$($Mision.Id).sh"

    if ((Test-Path $file) -and $Continuar) {
        $nota = "Continuando con tu código anterior."
    } else {
        if (Test-Path $file) { Copy-Item $file (Join-Path $ws "$($Mision.Id).prev.sh") -Force }
        Write-SantuarioFile -Path $file -Text $Mision.Plantilla
        $nota = ""
    }

    $esRepaso = Test-CyberDue $MisionId
    $marca = if ($esRepaso) { "   (REPASO)" } else { "" }
    $tipoTxt = if ($Mision.Tipo -eq 'script') { "un SCRIPT completo (se ejecuta como  bash tu_archivo.sh <argumentos>)" } else { "una FUNCIÓN (Santuario carga tu archivo con  source  y la llama)" }

    Write-Host ""
    Write-Cyber "============================================================" $c.Magenta
    Write-Cyber "  $Titulo" $c.Green
    Write-Cyber "============================================================" $c.Magenta
    Write-Cyber "Misión [nivel $($Mision.Nivel)]: $($Mision.Titulo)$marca" $c.Yellow
    Write-Cyber "Escribirás $tipoTxt" $c.Dim
    Write-Host ""
    Write-Cyber $Mision.Enunciado $c.Cyan
    Write-Host ""
    Write-Cyber "Tu archivo: $file" $c.Dim
    Write-Cyber "Se ejecuta en WSL (distro: $Distro), en una carpeta temporal de Linux." $c.Dim
    if ($nota) { Write-Cyber $nota $c.Dim }
    Write-Cyber "Casos de prueba: $(@($Mision.Tests).Count)   |   Enter o 'probar' = ejecutar   |   'pista', 'ver', 'editar', 'plantilla', 'solucion', 'salir'" $c.Dim
    Write-Host ""

    if (-not $SinEditor) {
        if (-not (Open-SantuarioEditor $file)) {
            Write-Cyber "No pude abrir un editor. Abre ese archivo con el tuyo (o define `$env:FORJA_EDITOR)." $c.Dim
        }
    }

    $resultado = $null
    $usoPista  = $false
    $intentos  = 0
    $superada  = $false

    while (-not $superada) {
        $cmd = (Read-Host "SANTUARIO ❯").Trim()

        if ($cmd -eq 'salir') {
            Write-Cyber "Saliendo del santuario... (tu código queda en el archivo; 'santuario -Id $($Mision.Id) -Continuar' para seguir)" $c.Magenta
            if ($intentos -gt 0 -or $usoPista) { $resultado = 'fail' }
            break
        }
        elseif ($cmd -eq 'pista') {
            $usoPista = $true
            Write-Cyber "💡 Pista: $($Mision.Pista)" $c.Cyan
            continue
        }
        elseif ($cmd -eq 'ver') {
            Write-Cyber $Mision.Enunciado $c.Cyan
            continue
        }
        elseif ($cmd -eq 'editar') {
            if (-not (Open-SantuarioEditor $file)) { Write-Cyber "Abre a mano: $file" $c.Dim }
            continue
        }
        elseif ($cmd -eq 'plantilla') {
            Copy-Item $file (Join-Path $ws "$($Mision.Id).prev.sh") -Force
            Write-SantuarioFile -Path $file -Text $Mision.Plantilla
            Write-Cyber "Plantilla restaurada (tu versión anterior está en $($Mision.Id).prev.sh)." $c.Dim
            continue
        }
        elseif ($cmd -eq 'solucion') {
            Write-Cyber "⚡ Solución de referencia (hay más formas válidas):" $c.Magenta
            Write-Host ""
            Write-Cyber ($Mision.Solucion.TrimEnd()) $c.Yellow
            Write-Host ""
            Write-Cyber "ℹ️  $($Mision.Concepto)" $c.Dim
            $resultado = 'fail'
            break
        }
        elseif ($cmd -ne '' -and $cmd -ne 'probar') {
            Write-Cyber "No entiendo '$cmd'. Enter = probar." $c.Dim
            continue
        }

        # ---- probar ----
        $intentos++
        Write-Cyber "  Ejecutando tu código en Linux (WSL)..." $c.Dim
        $res   = Invoke-SantuarioTests -Mision $Mision -File $file -Distro $Distro
        $bien  = Show-SantuarioResultados $res
        $total = @($Mision.Tests).Count

        if ($bien -eq $total -and -not $res.Aviso) {
            Write-Host ""
            Write-Cyber "✔ ¡MISIÓN SUPERADA!  ($bien/$total casos)" $c.Green
            Write-Cyber "ℹ️  $($Mision.Concepto)" $c.Dim
            Write-Host ""
            Write-Cyber "Solución de referencia (compárala con la tuya; hay más formas válidas):" $c.Dim
            Write-Cyber ($Mision.Solucion.TrimEnd()) $c.Yellow
            $superada  = $true
            $resultado = if ($usoPista -or $intentos -gt 3) { 'pista' } else { 'ok' }
        }
        elseif ($res.Aviso -and @($res.Resultados).Count -eq 0) {
            # Problema del entorno (no de tu código): no cuenta como intento fallido
            $intentos--
            Write-Host ""
            Write-Cyber "  No he podido ejecutar los tests. Prueba 'santuario -Diagnostico'." $c.Magenta
        }
        else {
            Write-Host ""
            Write-Cyber "  $bien/$total casos correctos. Edita, guarda y pulsa Enter otra vez." $c.Magenta
        }
    }

    if ($resultado) {
        $e = Register-CyberResultado -Id $MisionId -Resultado $resultado -Etiqueta $Mision.Titulo
        Write-Host ""
        if ($resultado -eq 'fail') { Write-Cyber "↻ Te la volveré a poner $(Format-CyberProximo $e)." $c.Dim }
        else { Write-Cyber "↻ Próximo repaso: $(Format-CyberProximo $e)  (caja $($e.Caja)/5)" $c.Dim }
    }
    Write-Host ""
    Write-Cyber "============================================================" $c.Magenta
    Write-Host ""
}

# ================================================================= #
#                     BANCO DE MISIONES (bash)                      #
# ================================================================= #
function Get-SantuarioMisiones {
    @(
        # ───────────────────────── NIVEL 1 ─────────────────────────
        @{
            Id = 'saludo'; Nivel = 1; Tipo = 'funcion'; Titulo = "Tu primera función: un saludo"
            Enunciado = @'
Escribe una función llamada saludo que reciba un nombre como primer
argumento y IMPRIMA:  Hola, <nombre>!
Ejemplo:  saludo Ana   ->   Hola, Ana!
'@
            Plantilla = @'
#!/bin/bash
# Misión: una función que imprime un saludo
saludo() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "Saluda a Ana";    Run = 'saludo Ana';    Esperado = 'Hola, Ana!' }
                @{ Nombre = "Saluda a Hector"; Run = 'saludo Hector'; Esperado = 'Hola, Hector!' }
            )
            Pista = 'El primer argumento de una función es $1. echo lo imprime; usa comillas dobles para que se sustituya la variable: echo "Hola, $1!"'
            Solucion = @'
saludo() {
    echo "Hola, $1!"
}
'@
            Concepto = 'Los argumentos de una función son $1, $2... Lo que una función "devuelve" en bash es lo que imprime por la salida estándar (echo).'
        },
        @{
            Id = 'par-impar'; Nivel = 1; Tipo = 'funcion'; Titulo = "¿Par o impar? (códigos de salida)"
            Enunciado = @'
Escribe es_par, una función que reciba un número y termine con código de
salida 0 ("verdadero") si es par y con 1 ("falso") si es impar.
No imprime nada: en bash, la respuesta de un "sí/no" es el código de salida.
Ejemplo:  es_par 4; echo $?   ->   0
'@
            Plantilla = @'
#!/bin/bash
# Misión: decidir si un número es par (con el código de salida)
es_par() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "4 es par (código 0)";    Run = 'es_par 4; echo "codigo=$?"';  Esperado = 'codigo=0' }
                @{ Nombre = "7 es impar (código 1)";  Run = 'es_par 7; echo "codigo=$?"';  Esperado = 'codigo=1' }
                @{ Nombre = "0 es par";               Run = 'es_par 0; echo "codigo=$?"';  Esperado = 'codigo=0' }
                @{ Nombre = "-2 es par";              Run = 'es_par -2; echo "codigo=$?"'; Esperado = 'codigo=0' }
                @{ Nombre = "9 es impar";             Run = 'es_par 9; echo "codigo=$?"';  Esperado = 'codigo=1' }
            )
            Pista = 'Un (( expresión )) hace aritmética y termina con código 0 si es verdadera y 1 si es falsa. Prueba con (( $1 % 2 == 0 )) como última línea de la función.'
            Solucion = @'
es_par() {
    (( $1 % 2 == 0 ))
}
'@
            Concepto = 'En bash, 0 es "éxito/verdadero" y cualquier otro valor es "fallo/falso". Por eso "if comando; then" funciona con códigos de salida. (( )) evalúa aritmética.'
        },
        @{
            Id = 'suma-args'; Nivel = 1; Tipo = 'funcion'; Titulo = "Sumar argumentos (bucle for)"
            Enunciado = @'
Escribe suma, una función que reciba cualquier cantidad de números como
argumentos e IMPRIMA su suma. Sin argumentos debe imprimir 0.
Ejemplo:  suma 1 2 3   ->   6
'@
            Plantilla = @'
#!/bin/bash
# Misión: sumar todos los argumentos
suma() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "1+2+3";           Run = 'suma 1 2 3';    Esperado = '6' }
                @{ Nombre = "sin argumentos";  Run = 'suma';          Esperado = '0' }
                @{ Nombre = "con negativos";   Run = 'suma -1 1 10';  Esperado = '10' }
            )
            Pista = '"$@" son todos los argumentos. Empieza con total=0, recórrelos con for n in "$@"; do ... done y suma con total=$(( total + n )). Al final, echo "$total".'
            Solucion = @'
suma() {
    local total=0 n
    for n in "$@"; do
        total=$(( total + n ))
    done
    echo "$total"
}
'@
            Concepto = '"$@" expande todos los argumentos; $(( )) hace aritmética. Inicializar en 0 hace que la lista vacía dé 0.'
        },
        @{
            Id = 'fizzbuzz'; Nivel = 1; Tipo = 'funcion'; Titulo = "FizzBuzz (bucles + condicionales)"
            Enunciado = @'
Escribe fizzbuzz, una función que reciba un número N e imprima, del 1 al N,
una línea por número:
  - FizzBuzz  si es múltiplo de 3 y de 5
  - Fizz      si es múltiplo de 3
  - Buzz      si es múltiplo de 5
  - el propio número en cualquier otro caso
Ejemplo:  fizzbuzz 5   ->   1, 2, Fizz, 4, Buzz (una por línea)
'@
            Plantilla = @'
#!/bin/bash
# Misión: FizzBuzz
fizzbuzz() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "hasta 5";  Run = 'fizzbuzz 5';  Esperado = (@('1','2','Fizz','4','Buzz') -join "`n") }
                @{ Nombre = "hasta 15"; Run = 'fizzbuzz 15'; Esperado = (@('1','2','Fizz','4','Buzz','Fizz','7','8','Fizz','Buzz','11','Fizz','13','14','FizzBuzz') -join "`n") }
                @{ Nombre = "hasta 1";  Run = 'fizzbuzz 1';  Esperado = '1' }
            )
            Pista = 'Bucle: for (( i = 1; i <= $1; i++ )); do ... done. El orden importa: comprueba primero el caso "múltiplo de 3 y de 5" (o i % 15 == 0).'
            Solucion = @'
fizzbuzz() {
    local i
    for (( i = 1; i <= $1; i++ )); do
        if   (( i % 15 == 0 )); then echo FizzBuzz
        elif (( i % 3  == 0 )); then echo Fizz
        elif (( i % 5  == 0 )); then echo Buzz
        else echo "$i"
        fi
    done
}
'@
            Concepto = 'for (( ; ; )) al estilo C, if / elif / else y el caso más específico primero.'
        },
        @{
            Id = 'contar-errores'; Nivel = 1; Tipo = 'funcion'; Titulo = "Contar errores en un log"
            Enunciado = @'
Escribe contar_errores, una función que reciba la ruta de un archivo de log e
IMPRIMA cuántas líneas contienen la palabra ERROR.
Un log sin errores, o vacío, debe imprimir 0.
'@
            Plantilla = @'
#!/bin/bash
# Misión: contar líneas con ERROR en un log
contar_errores() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "log con 3 errores"
                   Prep = 'printf "%s\n" "INFO arranque" "ERROR disco" "INFO ok" "ERROR red" "WARN lento" "ERROR db" > app.log'
                   Run = 'contar_errores app.log'; Esperado = '3' }
                @{ Nombre = "log vacío"
                   Prep = ': > vacio.log'
                   Run = 'contar_errores vacio.log'; Esperado = '0' }
                @{ Nombre = "log sin errores"
                   Prep = 'printf "%s\n" "INFO a" "INFO b" > ok.log'
                   Run = 'contar_errores ok.log'; Esperado = '0' }
            )
            Pista = 'grep -c PATRON archivo imprime cuántas líneas coinciden (y escribe 0 si ninguna).'
            Solucion = @'
contar_errores() {
    grep -c ERROR "$1"
}
'@
            Concepto = 'grep -c cuenta líneas que coinciden. Que devuelva código 1 cuando no hay coincidencias no es un error grave: solo significa "ninguna".'
        },
        @{
            Id = 'archivos-grandes'; Nivel = 1; Tipo = 'funcion'; Titulo = "Archivos por encima de un tamaño"
            Enunciado = @'
Escribe grandes, una función con dos argumentos: una carpeta y un tamaño en KB.
Debe imprimir SOLO LOS NOMBRES de los archivos de esa carpeta (no de las
subcarpetas) cuyo tamaño sea ESTRICTAMENTE MAYOR que ese número de KB, uno por
línea y ordenados alfabéticamente. Uno de exactamente ese tamaño no cuenta.
Ejemplo:  grandes /var/log 10
'@
            Plantilla = @'
#!/bin/bash
# Misión: archivos más grandes que N KB
grandes() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "mayores de 10 KB"
                   Prep = 'for s in a:5 b:40 c:12 d:90 e:10; do head -c $(( ${s#*:} * 1024 )) /dev/zero > "${s%%:*}.bin"; done'
                   Run = 'grandes . 10'; Esperado = (@('b.bin','c.bin','d.bin') -join "`n") }
                @{ Nombre = "mayores de 50 KB"
                   Prep = 'for s in a:5 b:40 c:12 d:90 e:10; do head -c $(( ${s#*:} * 1024 )) /dev/zero > "${s%%:*}.bin"; done'
                   Run = 'grandes . 50'; Esperado = 'd.bin' }
                @{ Nombre = "ninguno supera 100 KB"
                   Prep = 'head -c 5120 /dev/zero > a.bin'
                   Run = 'grandes . 100'; Esperado = '' }
            )
            Pista = 'find CARPETA -maxdepth 1 -type f -size +Nk selecciona por tamaño; -printf "%f\n" imprime solo el nombre; y al final | sort.'
            Solucion = @'
grandes() {
    find "$1" -maxdepth 1 -type f -size +"$2"k -printf '%f\n' | sort
}
'@
            Concepto = 'find con -maxdepth, -type y -size hace de filtro; -printf da el formato; sort ordena. Es el pipeline clásico de Linux.'
        },

        # ───────────────────────── NIVEL 2 ─────────────────────────
        @{
            Id = 'validar-puerto'; Nivel = 2; Tipo = 'funcion'; Titulo = "Validar argumentos (y fallar bien)"
            Enunciado = @'
Escribe set_puerto, una función que reciba un número de puerto.
  - Si es un entero entre 1 y 65535: imprime  Puerto <n> configurado
  - Si NO lo es (0, 70000, "abc", vacío...): NO imprime nada en la salida
    estándar, escribe un mensaje de error en stderr (>&2) y termina con
    código distinto de 0 (return 1).
'@
            Plantilla = @'
#!/bin/bash
# Misión: aceptar solo puertos válidos
set_puerto() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "puerto 22";    Run = 'set_puerto 22';    Esperado = 'Puerto 22 configurado' }
                @{ Nombre = "puerto 65535"; Run = 'set_puerto 65535'; Esperado = 'Puerto 65535 configurado' }
                @{ Nombre = "puerto 0 rechazado";      Run = 'set_puerto 0 2>/dev/null';      FallaEsperada = $true }
                @{ Nombre = "puerto 70000 rechazado";  Run = 'set_puerto 70000 2>/dev/null';  FallaEsperada = $true }
                @{ Nombre = "texto rechazado";         Run = 'set_puerto abc 2>/dev/null';    FallaEsperada = $true }
                @{ Nombre = "vacío rechazado";         Run = 'set_puerto 2>/dev/null';        FallaEsperada = $true }
            )
            Pista = 'Comprueba primero que sea numérico con [[ "$1" =~ ^[0-9]+$ ]] y después el rango con (( $1 >= 1 && $1 <= 65535 )). Para el error: echo "..." >&2; return 1.'
            Solucion = @'
set_puerto() {
    if [[ ! "$1" =~ ^[0-9]+$ ]] || (( 10#$1 < 1 || 10#$1 > 65535 )); then
        echo "Puerto invalido: $1" >&2
        return 1
    fi
    echo "Puerto $1 configurado"
}
'@
            Concepto = 'Valida la entrada al principio, manda los errores a stderr (>&2) y devuelve un código distinto de 0: así otros scripts pueden reaccionar con if / ||.'
        },
        @{
            Id = 'args-script'; Nivel = 2; Tipo = 'script'; Titulo = "Un script con argumentos y códigos de salida"
            Enunciado = @'
Esta vez escribes un SCRIPT completo (no una función), que se ejecutará como:
    bash tu_archivo.sh <carpeta>
Debe:
  - Si no recibe exactamente 1 argumento: escribir el uso en stderr y salir con código 2.
  - Si la carpeta no existe: escribir un error en stderr y salir con código 1.
  - Si todo va bien: imprimir cuántos archivos normales hay directamente dentro
    de la carpeta (sin contar subcarpetas) y salir con código 0.
'@
            Plantilla = @'
#!/bin/bash
# Misión: contar los archivos de una carpeta (script con argumentos)
# TU CÓDIGO AQUÍ
'@
            Tests = @(
                @{ Nombre = "carpeta con 3 archivos"
                   Prep = 'mkdir -p docs/sub; touch docs/a docs/b docs/c docs/sub/dentro'
                   Run = 'bash "$SCRIPT" docs; echo "rc=$?"'; Esperado = "3`nrc=0"; Modo = 'espacios' }
                @{ Nombre = "sin argumentos (código 2)"
                   Run = 'bash "$SCRIPT" 2>/dev/null; echo "rc=$?"'; Esperado = 'rc=2' }
                @{ Nombre = "demasiados argumentos (código 2)"
                   Run = 'bash "$SCRIPT" a b 2>/dev/null; echo "rc=$?"'; Esperado = 'rc=2' }
                @{ Nombre = "carpeta inexistente (código 1)"
                   Run = 'bash "$SCRIPT" noexiste 2>/dev/null; echo "rc=$?"'; Esperado = 'rc=1' }
            )
            Pista = '$# es el número de argumentos; [ "$#" -ne 1 ] los comprueba; [ ! -d "$1" ] mira si la carpeta existe; exit N sale con código N; find "$1" -maxdepth 1 -type f | wc -l cuenta.'
            Solucion = @'
#!/bin/bash
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <carpeta>" >&2
    exit 2
fi
if [ ! -d "$1" ]; then
    echo "No existe: $1" >&2
    exit 1
fi
find "$1" -maxdepth 1 -type f | wc -l
'@
            Concepto = '$#, $1 y exit N son la base de cualquier script serio: comprobar argumentos, fallar con un código distinto para cada error y trabajar con lo que llega.'
        },
        @{
            Id = 'csv-activos'; Nivel = 2; Tipo = 'funcion'; Titulo = "Leer un CSV y filtrar"
            Enunciado = @'
Escribe usuarios_activos, una función que reciba la ruta de un CSV con las
columnas nombre,rol,activo y IMPRIMA solo los nombres de los usuarios cuyo
campo activo vale "si", en el orden del archivo (la primera línea es la
cabecera y no cuenta).
'@
            Plantilla = @'
#!/bin/bash
# Misión: usuarios activos desde un CSV
usuarios_activos() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "CSV mixto"
                   Prep = 'printf "%s\n" "nombre,rol,activo" "ana,admin,si" "luis,usuario,no" "marta,admin,si" "pedro,usuario,si" > usuarios.csv'
                   Run = 'usuarios_activos usuarios.csv'; Esperado = (@('ana','marta','pedro') -join "`n") }
                @{ Nombre = "nadie activo"
                   Prep = 'printf "%s\n" "nombre,rol,activo" "ana,admin,no" "luis,usuario,no" > usuarios.csv'
                   Run = 'usuarios_activos usuarios.csv'; Esperado = '' }
            )
            Pista = 'awk -F, usa la coma como separador. NR > 1 salta la cabecera; $3 == "si" filtra; { print $1 } imprime el nombre.'
            Solucion = @'
usuarios_activos() {
    awk -F, 'NR > 1 && $3 == "si" { print $1 }' "$1"
}
'@
            Concepto = 'awk es la navaja para columnas: -F fija el separador, NR es el número de línea, $1 $2 $3 son las columnas.'
        },
        @{
            Id = 'servicio-activo'; Nivel = 2; Tipo = 'funcion'; Titulo = "Usar el código de salida como condición (con mock)"
            Enunciado = @'
Escribe servicio_activo, una función que reciba el nombre de un servicio e
imprima  <nombre>: activo  o  <nombre>: parado  según lo que diga
systemctl is-active. Usa el código de salida de systemctl en un if.
(Santuario simula systemctl: tu código se prueba sin tocar servicios reales.
En la simulación, ssh y cron están activos y el resto parados.)
'@
            Plantilla = @'
#!/bin/bash
# Misión: decir si un servicio está activo
servicio_activo() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "ssh está activo"
                   Prep = 'mkmock systemctl "$(printf "%s\n" "[ \"\$1\" = is-active ] || exit 1" "shift" "q=0; if [ \"\$1\" = --quiet ] || [ \"\$1\" = -q ]; then q=1; shift; fi" "case \"\$1\" in ssh|cron) [ \$q = 1 ] || echo active; exit 0;; *) [ \$q = 1 ] || echo inactive; exit 3;; esac")"'
                   Run = 'servicio_activo ssh'; Esperado = 'ssh: activo' }
                @{ Nombre = "nginx está parado"
                   Prep = 'mkmock systemctl "$(printf "%s\n" "[ \"\$1\" = is-active ] || exit 1" "shift" "q=0; if [ \"\$1\" = --quiet ] || [ \"\$1\" = -q ]; then q=1; shift; fi" "case \"\$1\" in ssh|cron) [ \$q = 1 ] || echo active; exit 0;; *) [ \$q = 1 ] || echo inactive; exit 3;; esac")"'
                   Run = 'servicio_activo nginx'; Esperado = 'nginx: parado' }
                @{ Nombre = "cron está activo"
                   Prep = 'mkmock systemctl "$(printf "%s\n" "[ \"\$1\" = is-active ] || exit 1" "shift" "q=0; if [ \"\$1\" = --quiet ] || [ \"\$1\" = -q ]; then q=1; shift; fi" "case \"\$1\" in ssh|cron) [ \$q = 1 ] || echo active; exit 0;; *) [ \$q = 1 ] || echo inactive; exit 3;; esac")"'
                   Run = 'servicio_activo cron'; Esperado = 'cron: activo' }
            )
            Pista = 'if systemctl is-active --quiet "$1"; then ... else ... fi   (--quiet no imprime nada: solo importa el código de salida).'
            Solucion = @'
servicio_activo() {
    if systemctl is-active --quiet "$1"; then
        echo "$1: activo"
    else
        echo "$1: parado"
    fi
}
'@
            Concepto = 'if ejecuta un comando y decide por su código de salida. Los mocks (comandos falsos en el PATH) permiten probar scripts de administración sin riesgo.'
        },
        @{
            Id = 'leer-seguro'; Nivel = 2; Tipo = 'funcion'; Titulo = "Leer sin romperse (plan B)"
            Enunciado = @'
Escribe leer_seguro, una función que reciba una ruta e imprima el contenido
del archivo. Si el archivo NO existe, debe imprimir exactamente NO_EXISTE y
no escribir ningún error en stderr.
'@
            Plantilla = @'
#!/bin/bash
# Misión: leer un archivo sin que falle si no existe
leer_seguro() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "archivo que existe"
                   Prep = 'echo "hola mundo" > nota.txt'
                   Run = 'leer_seguro nota.txt'; Esperado = 'hola mundo'; SinStderr = $true }
                @{ Nombre = "archivo que NO existe"
                   Run = 'leer_seguro no-existe.txt'; Esperado = 'NO_EXISTE'; SinStderr = $true }
            )
            Pista = 'Dos formas: if [ -f "$1" ]; then cat ...; else echo ...; fi   o   cat "$1" 2>/dev/null || echo NO_EXISTE'
            Solucion = @'
leer_seguro() {
    if [ -f "$1" ]; then
        cat "$1"
    else
        echo "NO_EXISTE"
    fi
}
'@
            Concepto = '[ -f ] comprueba antes; 2>/dev/null descarta los errores; y "comando || plan B" ejecuta el plan B solo si el comando falla.'
        },
        @{
            Id = 'top-ips'; Nivel = 2; Tipo = 'funcion'; Titulo = "El pipeline clásico: las 3 IPs más repetidas"
            Enunciado = @'
Escribe top_ips, una función que reciba un archivo con una IP por línea (sin
ordenar) e imprima las 3 IPs que más se repiten, en el formato
    <veces> <ip>
de la más repetida a la menos. Si hay menos de 3 IPs distintas, las que haya.
'@
            Plantilla = @'
#!/bin/bash
# Misión: las 3 IPs más frecuentes
top_ips() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "cuatro IPs mezcladas"
                   Prep = 'printf "%s\n" 10.0.0.2 10.0.0.1 10.0.0.1 10.0.0.3 10.0.0.1 10.0.0.2 10.0.0.4 10.0.0.1 10.0.0.3 10.0.0.2 > ips.txt'
                   Run = 'top_ips ips.txt'; Esperado = (@('4 10.0.0.1','3 10.0.0.2','2 10.0.0.3') -join "`n"); Modo = 'espacios' }
                @{ Nombre = "solo dos IPs distintas"
                   Prep = 'printf "%s\n" 2.2.2.2 1.1.1.1 1.1.1.1 > ips.txt'
                   Run = 'top_ips ips.txt'; Esperado = (@('2 1.1.1.1','1 2.2.2.2') -join "`n"); Modo = 'espacios' }
            )
            Pista = 'sort agrupa las repetidas; uniq -c las cuenta; sort -rn ordena por ese número de mayor a menor; head -3 se queda con 3.'
            Solucion = @'
top_ips() {
    sort "$1" | uniq -c | sort -rn | head -3
}
'@
            Concepto = 'sort | uniq -c | sort -rn es la receta universal para contar repeticiones. uniq solo cuenta líneas consecutivas: por eso el primer sort es imprescindible.'
        },
        @{
            Id = 'dry-run'; Nivel = 2; Tipo = 'funcion'; Titulo = "Borrado seguro con --dry-run"
            Enunciado = @'
Escribe limpiar_viejos, una función con argumentos: carpeta, días y,
opcionalmente, --dry-run. Borra los archivos normales de esa carpeta (sin
entrar en subcarpetas) modificados hace MÁS de N días.
  - Con --dry-run NO borra nada: imprime una línea  SE BORRARIA: <nombre>
    por cada archivo que borraría.
  - Sin --dry-run borra y no imprime nada.
'@
            Plantilla = @'
#!/bin/bash
# Misión: borrar archivos antiguos, con modo de simulación
limpiar_viejos() {
    # TU CÓDIGO AQUÍ (borra los dos puntos de abajo)
    :
}
'@
            Tests = @(
                @{ Nombre = "con --dry-run no borra nada"
                   Prep = 'touch -d "60 days ago" vieja.log; touch reciente.log'
                   Run = 'limpiar_viejos . 30 --dry-run; ls'; Esperado = (@('SE BORRARIA: vieja.log','reciente.log','vieja.log') -join "`n") }
                @{ Nombre = "sin --dry-run borra solo lo viejo"
                   Prep = 'touch -d "60 days ago" vieja.log; touch reciente.log'
                   Run = 'limpiar_viejos . 30; ls'; Esperado = 'reciente.log' }
                @{ Nombre = "no toca las subcarpetas"
                   Prep = 'mkdir sub; touch -d "60 days ago" sub/vieja-dentro.log; touch -d "60 days ago" vieja.log'
                   Run = 'limpiar_viejos . 30; ls sub'; Esperado = 'vieja-dentro.log' }
            )
            Pista = 'find CARPETA -maxdepth 1 -type f -mtime +N localiza los viejos. Recórrelos con un while read (o un for) y en cada uno decide: si el 3er argumento es --dry-run, echo; si no, rm.'
            Solucion = @'
limpiar_viejos() {
    local carpeta="$1" dias="$2" modo="$3" f
    while IFS= read -r -d '' f; do
        if [ "$modo" = "--dry-run" ]; then
            echo "SE BORRARIA: $(basename "$f")"
        else
            rm -- "$f"
        fi
    done < <(find "$carpeta" -maxdepth 1 -type f -mtime +"$dias" -print0)
}
'@
            Concepto = 'El patrón dry-run (simular antes de borrar) es el equivalente de -WhatIf en PowerShell: decides en un solo sitio si actúas o solo cuentas lo que harías.'
        }
    )
}

# ================================================================= #
#                          COMANDO PRINCIPAL                        #
# ================================================================= #
function Invoke-Santuario {
    [CmdletBinding()]
    param(
        # 1 = básico, 2 = intermedio
        [ValidateRange(1, 2)]
        [int]$Nivel,

        # Una misión concreta por su id (ver -Lista)
        [string]$Id,

        # Solo las misiones que toca repasar hoy
        [switch]$Repaso,

        # Muestra todas las misiones y tu estado
        [switch]$Lista,

        # Comprueba que WSL y la distro funcionan
        [switch]$Diagnostico,

        # Sigue con tu código anterior en vez de restaurar la plantilla
        [switch]$Continuar,

        # No abre el editor (lo abres tú)
        [switch]$SinEditor
    )

    $c = $global:CY
    if (-not $c) { $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" } }

    if ($Diagnostico) { Show-SantuarioDiagnostico; return }

    $todas = @(Get-SantuarioMisiones)
    $pool  = @($todas | ForEach-Object { [pscustomobject]@{ M = $_; Id = "santuario:$($_.Id)" } })
    if ($PSBoundParameters.ContainsKey('Nivel')) { $pool = @($pool | Where-Object { $_.M.Nivel -eq $Nivel }) }

    if ($Lista) {
        Write-Host ""
        Write-Cyber "  $("NIV".PadRight(5)) $("ID".PadRight(20)) $("MISIÓN".PadRight(50)) ESTADO" $c.Green
        Write-Cyber "  $("-" * 92)" $c.Magenta
        foreach ($p in $pool) {
            $e = Get-CyberEntrada $p.Id
            if (-not $e) { $estado = "nueva" }
            elseif (Test-CyberDue $p.Id) { $estado = "caja $($e.Caja)  ·  REPASO HOY" }
            else { $estado = "caja $($e.Caja)  ·  $(Format-CyberProximo $e)" }
            Write-Cyber "  $("$($p.M.Nivel)".PadRight(5)) " $c.Cyan -NoNewline
            Write-Cyber "$($p.M.Id.PadRight(20)) " $c.Yellow -NoNewline
            Write-Cyber "$($p.M.Titulo.PadRight(50).Substring(0,50)) " $c.Cyan -NoNewline
            Write-Cyber $estado $c.Dim
        }
        Write-Host ""
        Write-Cyber "  santuario -Id <id>  para una misión concreta   |   santuario -Repaso  para lo pendiente" $c.Dim
        Write-Host ""
        return
    }

    if ($Id) {
        $sel = @($pool | Where-Object { $_.M.Id -eq $Id }) | Select-Object -First 1
        if (-not $sel) {
            Write-Cyber "No existe la misión '$Id'. Mira las ids con:  santuario -Lista" $c.Magenta
            return
        }
    }
    else {
        $due = @($pool | Where-Object { Test-CyberDue $_.Id } |
                 Sort-Object { ConvertTo-CyberFecha (Get-CyberEntrada $_.Id).Due })

        if ($Repaso -and $due.Count -eq 0) {
            Write-Cyber "Nada pendiente de repaso en Santuario. ¡Bien!  (prueba 'progreso' para ver tu estado)" $c.Green
            return
        }

        if ($due.Count -gt 0) {
            $sel = $due[0]
        } else {
            $nuevas = @($pool | Where-Object { -not (Get-CyberEntrada $_.Id) })
            if ($nuevas.Count -gt 0) {
                $sel = $nuevas[0]
            } else {
                $minCaja = ($pool | ForEach-Object { (Get-CyberEntrada $_.Id).Caja } | Measure-Object -Minimum).Minimum
                $sel = @($pool | Where-Object { (Get-CyberEntrada $_.Id).Caja -eq $minCaja }) | Get-Random
            }
        }
    }

    $env = Test-SantuarioEntorno
    if (-not $env.Ok) {
        Write-Host ""
        Write-Cyber "  ✘ Santuario necesita WSL con una distro de Linux." $c.Magenta
        Write-Cyber "    $($env.Mensaje)" $c.Dim
        Write-Cyber "    (Comprobación completa:  santuario -Diagnostico)" $c.Dim
        Write-Host ""
        return
    }

    Invoke-SantuarioMision -Mision $sel.M -MisionId $sel.Id -Distro $env.Distro -Titulo 'SANTUARIO: ESCRIBE TU PROPIO SCRIPT (bash en WSL)' -SinEditor:$SinEditor -Continuar:$Continuar
}

Set-Alias santuario Invoke-Santuario
