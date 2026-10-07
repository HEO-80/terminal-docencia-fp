# ================================================================= #
#      RETO: PRACTICA TAREAS REALES (archivos, carpetas, permisos)   #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).
#
# Cómo funciona:
#   reto               te da un reto de 4-6 pasos en una carpeta de práctica propia
#                      (escribes los comandos en TU terminal de siempre: Tab, historial...)
#   comprobar          mira el RESULTADO en la carpeta y te pasa al siguiente paso
#   responder <valor>  para los pasos que piden una respuesta (contar, mirar, verificar)
#   pista / solucion   ayuda del paso ACTUAL (la solución sale paso a paso)
#   pasos / paso       ver todos los pasos / solo el actual
#   reto-salir         abandonar el reto
#
# Se comprueba el resultado, no el comando: vale PowerShell, cmd o lo que uses.
# Depende de Motor.ps1 (progreso y repaso espaciado). Pensado para Windows.

# Por si se carga este archivo suelto (sin el tema)
if (-not (Get-Command Write-Cyber -ErrorAction SilentlyContinue)) {
    function Write-Cyber {
        param([string]$Text, [string]$Color, [switch]$NoNewline)
        Write-Host $Text -NoNewline:$NoNewline
    }
}

$global:RetoActivo = $null

function Get-RetoColores {
    $c = $global:CY
    if (-not $c) { $c = @{ Green = "#39FF14"; Yellow = "#FCEE0A"; Cyan = "#00F0FF"; Magenta = "#C678DD"; Dim = "#888888" } }
    return $c
}

# ── Plataforma y rutas ────────────────────────────────────────────
function Test-RetoWindows {
    return ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
}

# Une la raíz del reto con una ruta relativa escrita con \ o con /
function _rp {
    param([string]$Raiz, [string]$Rel)
    if (-not $Rel) { return $Raiz }
    $sep = [string][System.IO.Path]::DirectorySeparatorChar
    return (Join-Path $Raiz ($Rel -replace '[\\/]', $sep))
}

function Get-RetoBase {
    if ($global:RetoBase) { return $global:RetoBase }
    return (Join-Path (Split-Path (Get-CyberProgresoPath)) 'reto')
}

function Get-RetoRaiz { return (Join-Path (Get-RetoBase) 'entorno') }

function New-RetoCarpeta {
    param([string]$Ruta)
    [void](New-Item -ItemType Directory -Path $Ruta -Force)
}

function New-RetoArchivo {
    param([string]$Ruta, [string]$Texto = '')
    $dir = Split-Path $Ruta
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-RetoCarpeta $dir }
    [System.IO.File]::WriteAllText($Ruta, $Texto)
}

# ── Primitivas de Windows (atributos y permisos) ──────────────────
# Están aparte para poder simularlas en las pruebas.
function Get-RetoAttr {
    param([string]$Path)
    $a = [int][System.IO.File]::GetAttributes($Path)
    [pscustomobject]@{
        Hidden   = (($a -band [int][System.IO.FileAttributes]::Hidden) -ne 0)
        ReadOnly = (($a -band [int][System.IO.FileAttributes]::ReadOnly) -ne 0)
    }
}

function Set-RetoAttr {
    param([string]$Path, [switch]$Hidden, [switch]$ReadOnly)
    $a = [int][System.IO.File]::GetAttributes($Path)
    if ($Hidden)   { $a = $a -bor [int][System.IO.FileAttributes]::Hidden }
    if ($ReadOnly) { $a = $a -bor [int][System.IO.FileAttributes]::ReadOnly }
    [System.IO.File]::SetAttributes($Path, [System.IO.FileAttributes]$a)
}

function Get-RetoYo {
    if (Test-RetoWindows) { return [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
    return 'S-1-5-21-1000-1000-1000-1001'
}

# SID conocidos (valen en cualquier idioma de Windows)
$global:RetoSid = @{
    Todos  = 'S-1-1-0'        # Everyone / Todos
    Users  = 'S-1-5-32-545'   # BUILTIN\Users / Usuarios
    Admins = 'S-1-5-32-544'   # BUILTIN\Administrators / Administradores
    System = 'S-1-5-18'       # SYSTEM
}

# Lista las entradas de permisos (ACE) de una ruta, con el SID ya resuelto
function Get-RetoAce {
    param([string]$Path)
    $acl = Get-Acl -LiteralPath $Path
    foreach ($r in $acl.Access) {
        try   { $sid = $r.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value }
        catch { $sid = [string]$r.IdentityReference }
        [pscustomobject]@{
            Sid      = $sid
            Derechos = [int]$r.FileSystemRights
            Tipo     = [string]$r.AccessControlType
            Heredado = [bool]$r.IsInherited
        }
    }
}

function Test-RetoHerenciaActiva {
    param([string]$Path)
    return (-not (Get-Acl -LiteralPath $Path).AreAccessRulesProtected)
}

function Get-RetoPropietario {
    param([string]$Path)
    return [string](Get-Acl -LiteralPath $Path).Owner
}

# ¿Tiene ese SID permiso efectivo de lectura o de escritura? (un Deny gana a un Allow)
function Test-RetoPermiso {
    param([string]$Path, [string]$Sid, [ValidateSet('Lectura', 'Escritura')][string]$Tipo)
    $mask  = if ($Tipo -eq 'Lectura') { 1 } else { 2 }
    $aces  = @(Get-RetoAce $Path | Where-Object { $_.Sid -eq $Sid })
    $allow = @($aces | Where-Object { $_.Tipo -eq 'Allow' -and (($_.Derechos -band $mask) -ne 0) })
    $deny  = @($aces | Where-Object { $_.Tipo -eq 'Deny'  -and (($_.Derechos -band $mask) -ne 0) })
    return ($allow.Count -gt 0 -and $deny.Count -eq 0)
}

function Invoke-RetoIcacls {
    param([string[]]$Argumentos)
    try {
        $salida = & icacls @Argumentos 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Cyber "  [!] No pude preparar los permisos: $($salida | Select-Object -First 1)" (Get-RetoColores).Dim
        }
    } catch {
        Write-Cyber "  [!] icacls no está disponible: $($_.Exception.Message)" (Get-RetoColores).Dim
    }
}

# Deja una carpeta con permisos EXPLÍCITOS (sin herencia). Permisos: SID -> F | M | RX | R
function Set-RetoAclExplicito {
    param([string]$Ruta, [hashtable]$Permisos)
    $lista = @($Ruta)
    foreach ($sid in $Permisos.Keys) {
        $lista += '/grant'
        $lista += ('*{0}:(OI)(CI){1}' -f $sid, $Permisos[$sid])
    }
    $lista += '/inheritance:r'
    Invoke-RetoIcacls $lista
}

# ── Carpeta de práctica (sandbox) ─────────────────────────────────
function Remove-RetoSandbox {
    param([string]$Ruta)
    if (-not (Test-Path -LiteralPath $Ruta)) { return }
    # Seguridad: solo borramos dentro de la base de los retos
    $base = Get-RetoBase
    if (-not $Ruta.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase) -or $Ruta.Length -le $base.Length + 3) {
        Write-Cyber "  [!] Me niego a borrar fuera de la carpeta de retos: $Ruta" (Get-RetoColores).Dim
        return
    }
    try { Remove-Item -LiteralPath $Ruta -Recurse -Force -ErrorAction Stop; return } catch { }

    # Había algo protegido (solo lectura, oculto o con permisos raros): lo desbloqueamos
    if (Test-RetoWindows) {
        try { & icacls $Ruta /reset /t /c /q | Out-Null } catch { }
        try { & cmd.exe /c "attrib -r -h -s `"$Ruta\*`" /s /d" | Out-Null } catch { }
    } else {
        try { & chmod -R u+rwx $Ruta } catch { }
    }
    try { Remove-Item -LiteralPath $Ruta -Recurse -Force -ErrorAction Stop }
    catch { Write-Cyber "  [!] No pude limpiar $Ruta del todo: $($_.Exception.Message)" (Get-RetoColores).Dim }
}

# ── Respuestas ────────────────────────────────────────────────────
function ConvertTo-RetoNorm {
    param([string]$Texto)
    if ($null -eq $Texto) { return '' }
    $t = $Texto.Trim().Trim('"').Trim("'").Trim().ToLowerInvariant()
    $d = $t.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $d.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

# Modos: exacto (texto o número; si escribes una ruta vale el último nombre) |
#        bool (si/no) | regex (patrón) | enTexto (la respuesta aparece dentro del valor esperado)
function Test-RetoRespuesta {
    param([string]$Dada, $Esperada, [string]$Modo = 'exacto')
    $d = ConvertTo-RetoNorm $Dada
    if ($d -eq '') { return $false }
    $esp = @($Esperada)

    switch ($Modo) {
        'bool' {
            $si = @('si', 's', 'yes', 'y', 'true', 'verdadero', 'activada', 'activado')
            $no = @('no', 'n', 'false', 'falso', 'desactivada', 'desactivado')
            $e  = ConvertTo-RetoNorm ([string]$esp[0])
            if ($e -eq 'si') { return ($si -contains $d) }
            return ($no -contains $d)
        }
        'regex' {
            return ($d -match [string]$esp[0])
        }
        'enTexto' {
            $e = ConvertTo-RetoNorm ([string]$esp[0])
            return ($d.Length -ge 3 -and $e.Contains($d))
        }
        default {
            $hoja = ($d -split '[\\/]')[-1]
            foreach ($x in $esp) {
                $e = ConvertTo-RetoNorm ([string]$x)
                if ($d -eq $e -or $hoja -eq $e) { return $true }
                $nd = 0.0; $ne = 0.0
                if ([double]::TryParse($d, [ref]$nd) -and [double]::TryParse($e, [ref]$ne) -and $nd -eq $ne) { return $true }
            }
            return $false
        }
    }
}

# ── Sesión de un reto ─────────────────────────────────────────────
function Format-RetoLineas {
    param([string]$Texto)
    return ((($Texto.TrimEnd() -split "`r?`n") | ForEach-Object { "      $_" }) -join "`n")
}

function Show-RetoPaso {
    $a = $global:RetoActivo
    if (-not $a) { return }
    $c = Get-RetoColores
    $n = @($a.Reto.Pasos).Count
    $p = $a.Reto.Pasos[$a.Paso]
    Write-Cyber ("PASO {0}/{1}:  {2}" -f ($a.Paso + 1), $n, $p.T) $c.Yellow
    if ($p.Esperada) { Write-Cyber "   (se responde con:  responder <valor>)" $c.Dim }
    else             { Write-Cyber "   (cuando lo tengas:  comprobar)" $c.Dim }
}

function Show-RetoPasos {
    $a = $global:RetoActivo
    $c = Get-RetoColores
    if (-not $a) { Write-Cyber "No hay ningún reto activo. Escribe:  reto" $c.Dim; return }
    $n = @($a.Reto.Pasos).Count
    Write-Host ""
    Write-Cyber "  $($a.Reto.Titulo)" $c.Green
    for ($i = 0; $i -lt $n; $i++) {
        $p = $a.Reto.Pasos[$i]
        if ($i -lt $a.Paso)      { Write-Cyber ("  ✔ {0}. {1}" -f ($i + 1), $p.T) $c.Green }
        elseif ($i -eq $a.Paso)  { Write-Cyber ("  ➜ {0}. {1}" -f ($i + 1), $p.T) $c.Yellow }
        else                     { Write-Cyber ("  · {0}. {1}" -f ($i + 1), $p.T) $c.Dim }
    }
    Write-Host ""
}

function Show-RetoPasoActual {
    $a = $global:RetoActivo
    if (-not $a) { Write-Cyber "No hay ningún reto activo. Escribe:  reto" (Get-RetoColores).Dim; return }
    Show-RetoPaso
}

function Complete-Reto {
    $a = $global:RetoActivo
    $c = Get-RetoColores
    $r = $a.Reto
    $res = if ($a.UsoSolucion) { 'fail' } elseif ($a.UsoPista -or $a.Fallos -gt 6) { 'pista' } else { 'ok' }

    Write-Host ""
    Write-Cyber "✔ ¡RETO SUPERADO!   ($(@($r.Pasos).Count) pasos)" $c.Green
    if ($r.Concepto) { Write-Cyber "ℹ️  $($r.Concepto)" $c.Dim }

    $e = Register-CyberResultado -Id "reto:$($r.Id)" -Resultado $res -Etiqueta $r.Titulo
    Write-Host ""
    if ($res -eq 'fail') { Write-Cyber "↻ Como has usado la solución, te lo volveré a poner $(Format-CyberProximo $e)." $c.Dim }
    else                 { Write-Cyber "↻ Próximo repaso: $(Format-CyberProximo $e)  (caja $($e.Caja)/5)" $c.Dim }
    Write-Cyber "Tu carpeta de práctica sigue en: $($a.Raiz)   (se borra al empezar otro reto)" $c.Dim
    Write-Cyber "Siguiente:  reto        Ver todos:  reto -Lista" $c.Dim
    Write-Host ""
    Write-Cyber "============================================================" $c.Magenta
    Write-Host ""

    try { Set-Location -LiteralPath $a.Previo -ErrorAction Stop } catch { }
    $global:RetoActivo = $null
}

function Step-RetoAvance {
    $a = $global:RetoActivo
    $c = Get-RetoColores
    Write-Cyber ("✔ Paso {0} superado" -f ($a.Paso + 1)) $c.Green
    $a.Paso++
    if ($a.Paso -ge @($a.Reto.Pasos).Count) { Complete-Reto }
    else { Write-Host ""; Show-RetoPaso }
}

function Invoke-RetoComprobar {
    $a = $global:RetoActivo
    $c = Get-RetoColores
    if (-not $a) { Write-Cyber "No hay ningún reto activo. Escribe:  reto" $c.Dim; return }
    $p = $a.Reto.Pasos[$a.Paso]
    if ($p.Esperada) { Write-Cyber "Este paso se responde con:  responder <valor>" $c.Dim; return }

    $a.Comprobaciones++
    $r = $null
    try { $r = @(& $p.C $a.Raiz) | Select-Object -Last 1 }
    catch { $r = "No he podido comprobarlo: $($_.Exception.Message)" }

    if ($r -is [bool] -and $r) { Step-RetoAvance; return }

    $a.Fallos++
    if ($r -is [string] -and $r) { Write-Cyber "✗ Todavía no: $r" $c.Magenta }
    else { Write-Cyber "✗ Todavía no. Relee el paso (paso), pide  pista  o mira  solucion." $c.Magenta }
}

function Invoke-RetoResponder {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Valor)
    $a = $global:RetoActivo
    $c = Get-RetoColores
    if (-not $a) { Write-Cyber "No hay ningún reto activo. Escribe:  reto" $c.Dim; return }
    $p = $a.Reto.Pasos[$a.Paso]
    if (-not $p.Esperada) { Write-Cyber "Este paso no pide una respuesta: hazlo y escribe  comprobar." $c.Dim; return }
    $txt = (@($Valor) -join ' ').Trim()
    if (-not $txt) { Write-Cyber "Escribe la respuesta detrás:  responder <valor>" $c.Dim; return }

    $a.Comprobaciones++
    $esp = @()
    try { $esp = @(& $p.Esperada $a.Raiz) }
    catch { Write-Cyber "No he podido calcular la respuesta esperada: $($_.Exception.Message)" $c.Magenta; return }

    if (Test-RetoRespuesta -Dada $txt -Esperada $esp -Modo $p.Modo) { Step-RetoAvance; return }
    $a.Fallos++
    Write-Cyber "✗ Esa no es. Ejecuta el comando, mira bien el resultado y vuelve a probar (o pide  pista)." $c.Magenta
}

function Show-RetoPista {
    $a = $global:RetoActivo
    $c = Get-RetoColores
    if (-not $a) { Write-Cyber "No hay ningún reto activo. Escribe:  reto" $c.Dim; return }
    $p = $a.Reto.Pasos[$a.Paso]
    $a.UsoPista = $true
    if ($p.P) { Write-Cyber "💡 Pista: $($p.P)" $c.Cyan }
    else      { Write-Cyber "Este paso no tiene pista. Prueba  solucion." $c.Dim }
}

# La solución sale PASO A PASO: solo la del paso en el que estás
function Show-RetoSolucion {
    $a = $global:RetoActivo
    $c = Get-RetoColores
    if (-not $a) { Write-Cyber "No hay ningún reto activo. Escribe:  reto" $c.Dim; return }
    $p = $a.Reto.Pasos[$a.Paso]
    $a.UsoSolucion = $true
    $n = @($a.Reto.Pasos).Count
    Write-Host ""
    Write-Cyber ("⚡ Solución del paso {0}/{1}   (escríbela tú en tu terminal):" -f ($a.Paso + 1), $n) $c.Magenta
    if ($p.Ps)  { Write-Cyber "  PowerShell:" $c.Cyan; Write-Cyber (Format-RetoLineas $p.Ps) $c.Yellow }
    if ($p.Cmd) { Write-Cyber "  cmd:" $c.Cyan;        Write-Cyber (Format-RetoLineas $p.Cmd) $c.Yellow }
    if ($p.Alt) { Write-Cyber "  PowerShell (otra forma):" $c.Cyan; Write-Cyber (Format-RetoLineas $p.Alt) $c.Yellow }
    Write-Host ""
    if ($p.Esperada) { Write-Cyber "Ejecútalo, mira el resultado y responde con:  responder <valor>" $c.Dim }
    else             { Write-Cyber "Cuando lo hayas escrito:  comprobar   (y con  solucion  verás el siguiente paso)" $c.Dim }
    Write-Host ""
}

function Exit-Reto {
    $a = $global:RetoActivo
    $c = Get-RetoColores
    if (-not $a) { Write-Cyber "No hay ningún reto activo." $c.Dim; return }
    $hizo = ($a.Paso -gt 0) -or $a.UsoPista -or $a.UsoSolucion -or ($a.Comprobaciones -gt 0)
    if ($hizo) {
        $e = Register-CyberResultado -Id "reto:$($a.Reto.Id)" -Resultado fail -Etiqueta $a.Reto.Titulo
        Write-Cyber "Saliendo del reto... te lo volveré a poner $(Format-CyberProximo $e)." $c.Magenta
    } else {
        Write-Cyber "Saliendo del reto (sin haber empezado, no cuenta como fallo)." $c.Magenta
    }
    try { Set-Location -LiteralPath $a.Previo -ErrorAction Stop } catch { }
    $global:RetoActivo = $null
}

function Start-Reto {
    param([Parameter(Mandatory)]$Reto, [string]$Previo)
    $c = Get-RetoColores
    $raiz = Get-RetoRaiz
    if (-not $Previo) { $Previo = (Get-Location).Path }
    if ($Previo.StartsWith($raiz, [System.StringComparison]::OrdinalIgnoreCase)) { $Previo = $HOME }

    # Salimos de la carpeta de práctica antes de limpiarla
    if ((Get-Location).Path.StartsWith($raiz, [System.StringComparison]::OrdinalIgnoreCase)) {
        try { Set-Location -LiteralPath $Previo -ErrorAction Stop } catch { }
    }
    Remove-RetoSandbox $raiz
    New-RetoCarpeta $raiz
    try { & $Reto.Preparar $raiz }
    catch { Write-Cyber "  [!] No pude preparar el reto: $($_.Exception.Message)" $c.Magenta; return }

    $inicio = _rp $raiz $Reto.Inicio
    Set-Location -LiteralPath $inicio

    $global:RetoActivo = @{
        Reto = $Reto; Raiz = $raiz; Previo = $Previo; Paso = 0
        UsoPista = $false; UsoSolucion = $false; Comprobaciones = 0; Fallos = 0
    }

    $esRepaso = Test-CyberDue "reto:$($Reto.Id)"
    $marca = if ($esRepaso) { "   (REPASO)" } else { "" }
    $nivel = @('', 'ARCHIVOS Y CARPETAS', 'SERVIDOR Y PERMISOS', 'ESCENARIOS')[$Reto.Nivel]

    Write-Host ""
    Write-Cyber "============================================================" $c.Magenta
    Write-Cyber "  RETO · nivel $($Reto.Nivel): $nivel" $c.Green
    Write-Cyber "============================================================" $c.Magenta
    Write-Cyber "$($Reto.Titulo)$marca" $c.Yellow
    Write-Host ""
    if ($Reto.Intro) { Write-Cyber $Reto.Intro $c.Cyan; Write-Host "" }
    Write-Cyber "Estás en tu carpeta de práctica:  $inicio" $c.Dim
    Write-Cyber "Es un entorno de juguete: nada de esto toca tus archivos reales." $c.Dim
    Write-Cyber "Escribe los comandos aquí mismo. Comandos del reto:  comprobar · responder <x> · pista · solucion · pasos · paso · reto-salir" $c.Dim
    Write-Host ""
    Show-RetoPaso
}

# ── Elegir y lanzar un reto ───────────────────────────────────────
function Invoke-Reto {
    [CmdletBinding()]
    param(
        # 1 = archivos y carpetas, 2 = servidor y permisos, 3 = escenarios
        [ValidateRange(1, 3)]
        [int]$Nivel,

        # Un reto concreto por su id (ver -Lista)
        [string]$Id,

        # Solo los retos que toca repasar hoy
        [switch]$Repaso,

        # Muestra todos los retos y tu estado
        [switch]$Lista,

        # Vuelve a empezar el reto actual desde cero
        [switch]$Reiniciar
    )

    $c = Get-RetoColores

    if (-not (Test-RetoWindows) -and -not $global:RetoForzar) {
        Write-Cyber "Los retos usan atributos y permisos de Windows (attrib, icacls, NTFS): ejecútalos en Windows." $c.Magenta
        return
    }

    $todos = @(Get-RetoBanco)
    $pool  = @($todos | ForEach-Object { [pscustomobject]@{ R = $_; Id = "reto:$($_.Id)" } })
    if ($PSBoundParameters.ContainsKey('Nivel')) { $pool = @($pool | Where-Object { $_.R.Nivel -eq $Nivel }) }

    if ($Lista) {
        Write-Host ""
        Write-Cyber "  $("NIV".PadRight(5)) $("ID".PadRight(20)) $("RETO".PadRight(44)) $("PASOS".PadRight(6)) ESTADO" $c.Green
        Write-Cyber "  $("-" * 92)" $c.Magenta
        foreach ($p in $pool) {
            $e = Get-CyberEntrada $p.Id
            if (-not $e) { $estado = "nuevo" }
            elseif (Test-CyberDue $p.Id) { $estado = "caja $($e.Caja)  ·  REPASO HOY" }
            else { $estado = "caja $($e.Caja)  ·  $(Format-CyberProximo $e)" }
            $t = $p.R.Titulo
            if ($t.Length -gt 44) { $t = $t.Substring(0, 44) }
            Write-Cyber "  $("$($p.R.Nivel)".PadRight(5)) " $c.Cyan -NoNewline
            Write-Cyber "$($p.R.Id.PadRight(20)) " $c.Yellow -NoNewline
            Write-Cyber "$($t.PadRight(44)) " $c.Cyan -NoNewline
            Write-Cyber "$("$(@($p.R.Pasos).Count)".PadRight(6)) " $c.Dim -NoNewline
            Write-Cyber $estado $c.Dim
        }
        Write-Host ""
        Write-Cyber "  reto -Id <id>  para uno concreto   |   reto -Repaso  para lo pendiente   |   reto -Nivel 1|2|3" $c.Dim
        Write-Host ""
        return
    }

    if ($global:RetoActivo) {
        if ($Reiniciar) {
            $act = $global:RetoActivo
            Write-Cyber "Reiniciando el reto '$($act.Reto.Id)' desde el paso 1..." $c.Magenta
            Start-Reto -Reto $act.Reto -Previo $act.Previo
            return
        }
        Write-Cyber "Ya tienes un reto en marcha: $($global:RetoActivo.Reto.Titulo)" $c.Magenta
        Write-Cyber "  pasos  ver los pasos   |   reto -Reiniciar  empezar de cero   |   reto-salir  abandonarlo" $c.Dim
        return
    }
    if ($Reiniciar) { Write-Cyber "No hay ningún reto en marcha que reiniciar. Escribe:  reto" $c.Dim; return }

    if ($Id) {
        $sel = @($pool | Where-Object { $_.R.Id -eq $Id }) | Select-Object -First 1
        if (-not $sel) {
            Write-Cyber "No existe el reto '$Id'. Mira las ids con:  reto -Lista" $c.Magenta
            return
        }
    }
    else {
        $due = @($pool | Where-Object { Test-CyberDue $_.Id } |
                 Sort-Object { ConvertTo-CyberFecha (Get-CyberEntrada $_.Id).Due })

        if ($Repaso -and $due.Count -eq 0) {
            Write-Cyber "Nada pendiente de repaso en Reto. ¡Bien!  (prueba 'progreso' para ver tu estado)" $c.Green
            return
        }

        if ($due.Count -gt 0) { $sel = $due[0] }
        else {
            $nuevos = @($pool | Where-Object { -not (Get-CyberEntrada $_.Id) })
            if ($nuevos.Count -gt 0) {
                # En orden: primero los de nivel bajo
                $sel = $nuevos[0]
            } else {
                $minCaja = ($pool | ForEach-Object { (Get-CyberEntrada $_.Id).Caja } | Measure-Object -Minimum).Minimum
                $sel = @($pool | Where-Object { (Get-CyberEntrada $_.Id).Caja -eq $minCaja }) | Get-Random
            }
        }
    }

    Start-Reto -Reto $sel.R
}

Set-Alias reto Invoke-Reto
Set-Alias challenge Invoke-Reto
Set-Alias comprobar Invoke-RetoComprobar
Set-Alias responder Invoke-RetoResponder
Set-Alias pista Show-RetoPista
Set-Alias solucion Show-RetoSolucion
Set-Alias pasos Show-RetoPasos
Set-Alias paso Show-RetoPasoActual
Set-Alias reto-salir Exit-Reto

# ================================================================= #
#                        BANCO DE RETOS                              #
# ================================================================= #
# Cada reto: Id, Nivel, Titulo, Intro, Concepto, Inicio (carpeta donde empiezas),
#            Preparar (crea el entorno) y Pasos. Cada paso tiene:
#   T = enunciado, C = comprobación del ESTADO (devuelve $true o un texto que explica qué falta)
#   o Esperada = respuesta correcta (para pasos de "responder"), Modo = exacto|bool|regex|enTexto
#   P = pista, Ps = solución PowerShell, Cmd = solución cmd, Alt = otra forma en PowerShell
# Para añadir un reto: copia uno, cambia los datos y añádelo al final de esta función.

# ── Ayudas de comprobación ────────────────────────────────────────
function Get-RetoLineas {
    param([string]$Ruta)
    if (-not (Test-Path -LiteralPath $Ruta -PathType Leaf)) { return @() }
    return @(Get-Content -LiteralPath $Ruta -ErrorAction SilentlyContinue | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne '' })
}

function Get-RetoNombres {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $Dir -Force -File | ForEach-Object { $_.Name })
}

function Get-RetoRelativos {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return @() }
    $base = (Resolve-Path -LiteralPath $Dir).ProviderPath.TrimEnd('\', '/')
    return @(Get-ChildItem -LiteralPath $Dir -Recurse -Force -File | ForEach-Object { $_.FullName.Substring($base.Length + 1) -replace '\\', '/' })
}

function Test-RetoMismoConjunto {
    param($A, $B)
    $x = [string[]]@($A | ForEach-Object { "$_".ToLowerInvariant() })
    $y = [string[]]@($B | ForEach-Object { "$_".ToLowerInvariant() })
    if ($x.Count -ne $y.Count) { return $false }
    [Array]::Sort($x, [System.StringComparer]::Ordinal)
    [Array]::Sort($y, [System.StringComparer]::Ordinal)
    for ($i = 0; $i -lt $x.Count; $i++) { if ($x[$i] -ne $y[$i]) { return $false } }
    return $true
}

function Get-RetoAqui {
    return ([System.IO.Path]::GetFullPath((Get-Location).Path)).TrimEnd('\', '/')
}

function Test-RetoMismaRuta {
    param([string]$A, [string]$B)
    $x = ([System.IO.Path]::GetFullPath($A)).TrimEnd('\', '/')
    $y = ([System.IO.Path]::GetFullPath($B)).TrimEnd('\', '/')
    return ($x -ieq $y)
}

# ── Entornos de práctica reutilizables ────────────────────────────
function Get-RetoPermisosBase {
    param([string]$Users = 'RX')
    $h = @{}
    $h[(Get-RetoYo)] = 'F'
    $h[$global:RetoSid.Admins] = 'F'
    $h[$global:RetoSid.System] = 'F'
    if ($Users) { $h[$global:RetoSid.Users] = $Users }
    return $h
}

# Un "servidor de archivos" de juguete: SRV01\Shares\..., Backup
function New-RetoServidor {
    param([string]$Raiz)
    $s = _rp $Raiz 'SRV01'
    foreach ($d in 'Ventas', 'IT', 'RRHH', 'Finanzas') {
        $dep = _rp $s "Shares\Departamentos\$d"
        New-RetoArchivo (_rp $dep ("informe_" + $d.ToLower() + ".txt")) "Informe de $d`r`n"
        New-RetoArchivo (_rp $dep 'Documentos\leeme.txt') "Documentos de $d`r`n"
        New-RetoArchivo (_rp $dep 'Privado\nota.txt') "Solo para $d`r`n"
    }
    New-RetoArchivo (_rp $s 'Shares\Departamentos\RRHH\Nominas\nomina_enero.txt') "Nominas de enero`r`n"
    New-RetoArchivo (_rp $s 'Shares\Publico\manual.pdf') "Manual de empresa`r`n"
    New-RetoArchivo (_rp $s 'Shares\Publico\avisos.txt') "Bienvenido`r`n"
    New-RetoCarpeta (_rp $s 'Backup')
    Set-RetoAclExplicito (_rp $s 'Shares') (Get-RetoPermisosBase -Users 'RX')
}

# Un árbol de empresa para practicar búsquedas y rutas
function New-RetoEmpresa {
    param([string]$Raiz)
    $e = _rp $Raiz 'Empresa'
    New-RetoArchivo (_rp $e 'Ventas\2023\ventas.log') "ventas 2023`r`n"
    New-RetoArchivo (_rp $e 'Ventas\2023\cierre_2023.txt') "cierre`r`n"
    New-RetoArchivo (_rp $e 'Ventas\2024\Q1\ventas_q1.txt') "q1`r`n"
    New-RetoArchivo (_rp $e 'Ventas\2024\Q4\informe-final.docx') "informe final`r`n"
    New-RetoArchivo (_rp $e 'Ventas\2024\Q4\ventas_q4.log') "q4`r`n"
    New-RetoArchivo (_rp $e 'IT\backups\dump.sql') ('x' * 5000)
    New-RetoArchivo (_rp $e 'IT\backups\backup.log') "backup ok`r`n"
    New-RetoArchivo (_rp $e 'IT\logs\sistema.log') "sistema`r`n"
    New-RetoArchivo (_rp $e 'IT\logs\acceso.log') "acceso`r`n"
    New-RetoArchivo (_rp $e 'RRHH\nominas.txt') "nominas`r`n"
    New-RetoArchivo (_rp $e 'RRHH\rrhh.log') "rrhh`r`n"
    New-RetoArchivo (_rp $e 'Legal\contrato.txt') "contrato`r`n"
    New-RetoArchivo (_rp $e 'Legal\legal.log') "legal`r`n"
}

function Get-RetoBanco {
    $b = @()

    # ============================================================= #
    #  NIVEL 1 · ARCHIVOS Y CARPETAS                                #
    # ============================================================= #

    $b += @{
        Id = 'estructura'; Nivel = 1; Titulo = 'Tu primera estructura: carpeta, archivos y texto'
        Intro = 'Vas a crear una carpeta de proyecto con archivos y escribir dentro de ellos. Es lo más básico que se hace en una terminal y lo vas a repetir mil veces.'
        Concepto = 'mkdir / New-Item crean; > sobrescribe y >> añade al final; Get-Content / type leen. Todo esto funciona igual en PowerShell y en cmd.'
        Inicio = ''
        Preparar = { param($Raiz) }
        Pasos = @(
            @{
                T = 'Crea una carpeta llamada `proyecto`.'
                C = { param($Raiz)
                    if (Test-Path -LiteralPath (_rp $Raiz 'proyecto') -PathType Container) { return $true }
                    return 'No encuentro la carpeta `proyecto` en tu carpeta de práctica.' }
                P = '`mkdir` (o `New-Item -ItemType Directory`) crea carpetas. Es igual en PowerShell y en cmd.'
                Ps = 'mkdir proyecto'
                Cmd = 'mkdir proyecto'
                Alt = 'New-Item -ItemType Directory proyecto'
            },
            @{
                T = 'Dentro de `proyecto`, crea tres archivos vacíos: `a.txt`, `b.txt` y `c.txt`.'
                C = { param($Raiz)
                    $falta = @('a.txt', 'b.txt', 'c.txt' | Where-Object { -not (Test-Path -LiteralPath (_rp $Raiz "proyecto\$_") -PathType Leaf) })
                    if ($falta.Count -eq 0) { return $true }
                    return "Faltan estos archivos dentro de proyecto: $($falta -join ', ')" }
                P = '`New-Item -ItemType File` crea un archivo. En cmd, `type nul > nombre` crea uno vacío.'
                Ps = 'New-Item proyecto\a.txt, proyecto\b.txt, proyecto\c.txt -ItemType File'
                Cmd = @'
type nul > proyecto\a.txt
type nul > proyecto\b.txt
type nul > proyecto\c.txt
'@
            },
            @{
                T = 'Escribe la palabra `hola` dentro de `a.txt`.'
                C = { param($Raiz)
                    $l = Get-RetoLineas (_rp $Raiz 'proyecto\a.txt')
                    if ($l -contains 'hola') { return $true }
                    return 'No veo la palabra `hola` dentro de proyecto\a.txt.' }
                P = 'Con `>` mandas lo que sale de un comando a un archivo (lo sobrescribe). En PowerShell también sirve `Set-Content`.'
                Ps = 'Set-Content proyecto\a.txt "hola"'
                Cmd = 'echo hola > proyecto\a.txt'
            },
            @{
                T = 'Añade una segunda línea con la palabra `adios` **sin borrar** la primera.'
                C = { param($Raiz)
                    $l = @(Get-RetoLineas (_rp $Raiz 'proyecto\a.txt'))
                    if ($l.Count -eq 2 -and $l[0] -eq 'hola' -and $l[1] -eq 'adios') { return $true }
                    return "a.txt debería tener dos líneas (hola y adios) y ahora tiene: $($l -join ' / ')" }
                P = '`>>` añade al final del archivo; `>` lo borra y escribe de nuevo. En PowerShell: `Add-Content`.'
                Ps = 'Add-Content proyecto\a.txt "adios"'
                Cmd = 'echo adios >> proyecto\a.txt'
            },
            @{
                T = 'Comprueba con un comando (no a ojo) cuántas líneas tiene `a.txt` y responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoLineas (_rp $Raiz 'proyecto\a.txt')).Count }
                P = 'En PowerShell, `Get-Content` te da las líneas y `.Count` las cuenta. En cmd, `find /c /v ""` cuenta líneas.'
                Ps = '(Get-Content proyecto\a.txt).Count'
                Cmd = 'find /c /v "" proyecto\a.txt'
            }
        )
    }

    $b += @{
        Id = 'ocultos'; Nivel = 1; Titulo = 'Archivos ocultos: esconder y encontrar'
        Intro = 'En Windows un archivo oculto sigue existiendo, pero no sale en un listado normal. Vas a ver cómo se esconde, cómo se encuentra y cómo se vuelve a mostrar.'
        Concepto = 'Oculto es un atributo, no un borrado. `-Force` (PowerShell) o `dir /a` (cmd) lo enseñan; `attrib +h` / `attrib -h` lo ponen y lo quitan.'
        Inicio = 'docs'
        Preparar = { param($Raiz)
            foreach ($n in 'informe.txt', 'notas.txt', 'tarifas.txt', 'clave.txt', 'copia.bak') {
                New-RetoArchivo (_rp $Raiz "docs\$n") "contenido de $n`r`n"
            }
            Set-RetoAttr (_rp $Raiz 'docs\clave.txt') -Hidden
            Set-RetoAttr (_rp $Raiz 'docs\copia.bak') -Hidden
        }
        Pasos = @(
            @{
                T = 'Haz un listado normal de esta carpeta. ¿Cuántos archivos ves? Responde con el número.'
                Esperada = { param($Raiz) @(Get-ChildItem -LiteralPath (_rp $Raiz 'docs') -Force -File | Where-Object { -not (Get-RetoAttr $_.FullName).Hidden }).Count }
                P = '`ls` o `dir` no enseñan los archivos ocultos.'
                Ps = 'Get-ChildItem'
                Cmd = 'dir'
            },
            @{
                T = 'Ahora lista también los **ocultos**. ¿Cuántos archivos hay en total? Responde con el número.'
                Esperada = { param($Raiz) @(Get-ChildItem -LiteralPath (_rp $Raiz 'docs') -Force -File).Count }
                P = 'En PowerShell añade `-Force`. En cmd, `dir /a` (o `dir /ah` para ver solo los ocultos).'
                Ps = 'Get-ChildItem -Force'
                Cmd = 'dir /a'
            },
            @{
                T = 'Oculta `notas.txt`.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'docs\notas.txt'
                    if (-not (Test-Path -LiteralPath $f)) { return 'notas.txt ya no existe: no lo borres, solo ocúltalo.' }
                    if ((Get-RetoAttr $f).Hidden) { return $true }
                    return 'notas.txt todavía no está oculto.' }
                P = '`attrib +h archivo` pone el atributo oculto (`-h` lo quita). Funciona igual en PowerShell y en cmd.'
                Ps = 'attrib +h notas.txt'
                Cmd = 'attrib +h notas.txt'
                Alt = "(Get-Item notas.txt).Attributes = 'Hidden'"
            },
            @{
                T = 'Comprueba que `notas.txt` ya no sale en un listado normal. ¿Cuántos archivos ves ahora? Responde con el número.'
                Esperada = { param($Raiz) @(Get-ChildItem -LiteralPath (_rp $Raiz 'docs') -Force -File | Where-Object { -not (Get-RetoAttr $_.FullName).Hidden }).Count }
                P = 'Haz otra vez el listado normal, sin `-Force` ni `/a`.'
                Ps = 'Get-ChildItem'
                Cmd = 'dir'
            },
            @{
                T = 'Vuelve a hacer `notas.txt` **visible**.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'docs\notas.txt'
                    if (-not (Test-Path -LiteralPath $f)) { return 'notas.txt ya no existe.' }
                    if (-not (Get-RetoAttr $f).Hidden) { return $true }
                    return 'notas.txt sigue oculto.' }
                P = 'Es el mismo comando de antes pero con `-h` en lugar de `+h`.'
                Ps = 'attrib -h notas.txt'
                Cmd = 'attrib -h notas.txt'
                Alt = "(Get-Item notas.txt -Force).Attributes = 'Normal'"
            }
        )
    }

    $b += @{
        Id = 'solo-lectura'; Nivel = 1; Titulo = 'Solo lectura: proteger, fallar y forzar'
        Intro = 'El atributo de solo lectura protege un archivo de cambios y borrados accidentales. Vas a ponerlo, ver qué error da, y aprender a forzar cuando de verdad hay que borrar.'
        Concepto = '`attrib +r` / `-r` (o `IsReadOnly`) activan y quitan la protección. Para borrar un archivo protegido hay que forzar: `Remove-Item -Force` en PowerShell, `del /f` en cmd.'
        Inicio = ''
        Preparar = { param($Raiz)
            New-RetoArchivo (_rp $Raiz 'config.ini') "modo=produccion`r`n"
            New-RetoArchivo (_rp $Raiz 'datos.txt') "registro 1`r`n"
            Set-RetoAttr (_rp $Raiz 'datos.txt') -ReadOnly
        }
        Pasos = @(
            @{
                T = 'Pon `config.ini` en modo **solo lectura**.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'config.ini'
                    if (-not (Test-Path -LiteralPath $f)) { return 'config.ini ya no existe.' }
                    if ((Get-RetoAttr $f).ReadOnly) { return $true }
                    return 'config.ini todavía se puede modificar.' }
                P = '`attrib +r archivo` activa el solo lectura. En PowerShell también: `Set-ItemProperty archivo -Name IsReadOnly -Value $true`.'
                Ps = 'Set-ItemProperty config.ini -Name IsReadOnly -Value $true'
                Cmd = 'attrib +r config.ini'
                Alt = 'attrib +r config.ini'
            },
            @{
                T = 'Intenta **añadir una línea** a `config.ini` y luego **borrarlo** de forma normal. Los dos intentos fallarán. Lee los errores y responde con la palabra del error que dice qué ha pasado (la que significa que no tienes acceso).'
                Esperada = { 'deneg|denied|acces|permis|protegid|read|lectura' }
                Modo = 'regex'
                P = 'Fíjate en el mensaje rojo de cada intento: habla de acceso denegado o de permisos.'
                Ps = @'
Add-Content config.ini "x=1"
Remove-Item config.ini
'@
                Cmd = @'
echo x=1 >> config.ini
del config.ini
'@
            },
            @{
                T = 'Ahora **bórralo de verdad**: fuerza el borrado de `config.ini`.'
                C = { param($Raiz)
                    if (-not (Test-Path -LiteralPath (_rp $Raiz 'config.ini'))) { return $true }
                    return 'config.ini sigue ahí.' }
                P = 'PowerShell: el parámetro `-Force`. cmd: el modificador `/f` de `del`.'
                Ps = 'Remove-Item config.ini -Force'
                Cmd = 'del /f config.ini'
            },
            @{
                T = '`datos.txt` también estaba protegido. Quítale el solo lectura y añade una línea con la palabra `fin`.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'datos.txt'
                    if ((Get-RetoAttr $f).ReadOnly) { return 'datos.txt sigue en solo lectura.' }
                    if ((Get-RetoLineas $f) -contains 'fin') { return $true }
                    return 'Ya no está protegido, pero falta la línea `fin` dentro de datos.txt.' }
                P = 'Primero `attrib -r` (o `IsReadOnly $false`), y ya puedes añadir la línea con `>>` o `Add-Content`.'
                Ps = @'
Set-ItemProperty datos.txt -Name IsReadOnly -Value $false
Add-Content datos.txt "fin"
'@
                Cmd = @'
attrib -r datos.txt
echo fin >> datos.txt
'@
            }
        )
    }

    $b += @{
        Id = 'mover'; Nivel = 1; Titulo = 'Mover y organizar archivos'
        Intro = 'Tienes una carpeta de entrada con archivos mezclados. Vas a crear carpetas, mover cada tipo a su sitio y limpiar lo que sobra.'
        Concepto = 'Los comodines (`*.txt`) permiten mover o copiar muchos archivos con un solo comando. `move` / `Move-Item` mueven, `rmdir` / `Remove-Item` borran carpetas vacías.'
        Inicio = ''
        Preparar = { param($Raiz)
            foreach ($n in 'a.txt', 'b.txt', 'c.txt', 'f1.jpg', 'f2.jpg', 'f3.jpg') { New-RetoArchivo (_rp $Raiz "entrada\$n") "archivo $n`r`n" }
        }
        Pasos = @(
            @{
                T = 'Crea dos carpetas nuevas: `textos` e `imagenes`.'
                C = { param($Raiz)
                    $falta = @('textos', 'imagenes' | Where-Object { -not (Test-Path -LiteralPath (_rp $Raiz $_) -PathType Container) })
                    if ($falta.Count -eq 0) { return $true }
                    return "Faltan estas carpetas: $($falta -join ', ')" }
                P = '`mkdir` acepta varios nombres a la vez.'
                Ps = 'mkdir textos, imagenes'
                Cmd = 'mkdir textos imagenes'
            },
            @{
                T = 'Mueve los tres archivos `.txt` de `entrada` a la carpeta `textos`.'
                C = { param($Raiz)
                    $n = @(Get-RetoNombres (_rp $Raiz 'textos') | Where-Object { $_ -like '*.txt' })
                    $sobran = @(Get-RetoNombres (_rp $Raiz 'entrada') | Where-Object { $_ -like '*.txt' })
                    if ($n.Count -eq 3 -and $sobran.Count -eq 0) { return $true }
                    return "En textos hay $($n.Count) .txt y en entrada quedan $($sobran.Count)." }
                P = 'Usa el comodín `*.txt` para moverlos todos de golpe. Mover no es copiar: en `entrada` no debe quedar ninguno.'
                Ps = 'Move-Item entrada\*.txt textos'
                Cmd = 'move entrada\*.txt textos'
            },
            @{
                T = 'Mueve las tres imágenes `.jpg` a la carpeta `imagenes`.'
                C = { param($Raiz)
                    $n = @(Get-RetoNombres (_rp $Raiz 'imagenes') | Where-Object { $_ -like '*.jpg' })
                    $sobran = @(Get-RetoNombres (_rp $Raiz 'entrada') | Where-Object { $_ -like '*.jpg' })
                    if ($n.Count -eq 3 -and $sobran.Count -eq 0) { return $true }
                    return "En imagenes hay $($n.Count) .jpg y en entrada quedan $($sobran.Count)." }
                P = 'Igual que antes, pero con `*.jpg` y otro destino.'
                Ps = 'Move-Item entrada\*.jpg imagenes'
                Cmd = 'move entrada\*.jpg imagenes'
            },
            @{
                T = 'La carpeta `entrada` ya debería estar vacía: bórrala.'
                C = { param($Raiz)
                    $e = _rp $Raiz 'entrada'
                    if (-not (Test-Path -LiteralPath $e)) { return $true }
                    if (@(Get-ChildItem -LiteralPath $e -Force).Count -gt 0) { return 'entrada todavía tiene cosas dentro: ¿te ha faltado mover algo?' }
                    return 'entrada sigue existiendo.' }
                P = '`rmdir` (cmd) y `Remove-Item` (PowerShell) borran una carpeta vacía.'
                Ps = 'Remove-Item entrada'
                Cmd = 'rmdir entrada'
            },
            @{
                T = 'Cuenta con un comando cuántos archivos hay en total entre `textos` e `imagenes`. Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoNombres (_rp $Raiz 'textos')).Count + @(Get-RetoNombres (_rp $Raiz 'imagenes')).Count }
                P = 'Puedes listar las dos carpetas a la vez y contar las líneas o los objetos.'
                Ps = '(Get-ChildItem textos, imagenes).Count'
                Cmd = 'dir /b textos imagenes | find /c /v ""'
            }
        )
    }

    $b += @{
        Id = 'copiar'; Nivel = 1; Titulo = 'Copiar carpetas sin romper el original'
        Intro = 'Antes de tocar un proyecto conviene hacer una copia. Vas a copiar una carpeta entera con sus subcarpetas, comprobar que es idéntica y trabajar sobre la copia.'
        Concepto = 'Copiar una carpeta exige pedir recursividad: `Copy-Item -Recurse` en PowerShell, `xcopy /e /i` en cmd. Trabajar sobre la copia deja el original intacto.'
        Inicio = ''
        Preparar = { param($Raiz)
            New-RetoArchivo (_rp $Raiz 'proyecto\src\main.py') "print('hola')`r`n"
            New-RetoArchivo (_rp $Raiz 'proyecto\src\util.py') "def util(): pass`r`n"
            New-RetoArchivo (_rp $Raiz 'proyecto\docs\leeme.txt') "documentacion`r`n"
            New-RetoArchivo (_rp $Raiz 'proyecto\leeme.txt') "Este es el proyecto`r`n"
        }
        Pasos = @(
            @{
                T = 'Copia la carpeta `proyecto` **entera** (con sus subcarpetas) a una nueva llamada `proyecto_backup`.'
                C = { param($Raiz)
                    $o = Get-RetoRelativos (_rp $Raiz 'proyecto')
                    $c = Get-RetoRelativos (_rp $Raiz 'proyecto_backup')
                    if ($c.Count -eq 0) { return 'No encuentro la copia proyecto_backup (o está vacía).' }
                    if (Test-RetoMismoConjunto $o $c) { return $true }
                    return "La copia tiene $($c.Count) archivos y el original $($o.Count): ¿copiaste también las subcarpetas?" }
                P = 'Sin recursividad solo se copia el primer nivel. PowerShell: `-Recurse`. cmd: `xcopy` con `/e /i`.'
                Ps = 'Copy-Item proyecto proyecto_backup -Recurse'
                Cmd = 'xcopy proyecto proyecto_backup /e /i'
            },
            @{
                T = 'Comprueba cuántos archivos tiene la copia en total (contando subcarpetas). Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoRelativos (_rp $Raiz 'proyecto_backup')).Count }
                P = 'Lista solo archivos y de forma recursiva, y cuéntalos.'
                Ps = '(Get-ChildItem proyecto_backup -Recurse -File).Count'
                Cmd = 'dir /s /b /a-d proyecto_backup | find /c /v ""'
            },
            @{
                T = 'Borra `util.py` de la **copia**. El original debe seguir intacto.'
                C = { param($Raiz)
                    $c = Test-Path -LiteralPath (_rp $Raiz 'proyecto_backup\src\util.py')
                    $o = Test-Path -LiteralPath (_rp $Raiz 'proyecto\src\util.py')
                    if (-not $o) { return '¡Has borrado el del original! Vuelve a empezar el reto con: reto -Reiniciar' }
                    if ($c) { return 'util.py sigue en la copia (proyecto_backup\src).' }
                    return $true }
                P = 'Fíjate en la ruta: está dentro de `proyecto_backup\src`.'
                Ps = 'Remove-Item proyecto_backup\src\util.py'
                Cmd = 'del proyecto_backup\src\util.py'
            },
            @{
                T = 'Crea una carpeta `entrega` y copia dentro solo el `leeme.txt` que está en la raíz de `proyecto`.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'entrega\leeme.txt'
                    if (-not (Test-Path -LiteralPath $f)) { return 'No veo entrega\leeme.txt.' }
                    $t = ((Get-RetoLineas $f) -join ' ')
                    if ($t -match 'Este es el proyecto') { return $true }
                    return 'Ese leeme.txt no es el de la raíz de proyecto (¿copiaste el de docs?).' }
                P = 'Primero la carpeta y luego la copia de un solo archivo (sin `-Recurse`).'
                Ps = @'
mkdir entrega
Copy-Item proyecto\leeme.txt entrega
'@
                Cmd = @'
mkdir entrega
copy proyecto\leeme.txt entrega
'@
            },
            @{
                T = 'Renombra la carpeta `entrega` a `entrega_final`.'
                C = { param($Raiz)
                    if (Test-Path -LiteralPath (_rp $Raiz 'entrega')) { return 'La carpeta entrega sigue con su nombre antiguo.' }
                    if (Test-Path -LiteralPath (_rp $Raiz 'entrega_final\leeme.txt')) { return $true }
                    return 'No encuentro entrega_final con su leeme.txt dentro.' }
                P = '`ren` en cmd, `Rename-Item` en PowerShell. Solo se pone el nombre nuevo, sin ruta.'
                Ps = 'Rename-Item entrega entrega_final'
                Cmd = 'ren entrega entrega_final'
            }
        )
    }

    $b += @{
        Id = 'renombrar'; Nivel = 1; Titulo = 'Renombrar en masa'
        Intro = 'Renombrar archivos uno a uno es un rollo. Vas a cambiar extensiones, nombres y añadir un prefijo a muchos archivos con una sola orden.'
        Concepto = 'En PowerShell, `Rename-Item -NewName { ... }` calcula el nombre nuevo de cada archivo. En cmd `ren *.txt *.bak` sirve para extensiones, pero para todo lo demás PowerShell gana con mucha diferencia.'
        Inicio = ''
        Preparar = { param($Raiz)
            foreach ($n in 'foto1.jpg', 'foto2.jpg', 'foto3.jpg', 'notas1.txt', 'notas2.txt') { New-RetoArchivo (_rp $Raiz "fotos\$n") "contenido $n`r`n" }
        }
        Pasos = @(
            @{
                T = 'Cambia la extensión de todos los `.txt` de `fotos` a `.bak`.'
                C = { param($Raiz)
                    $n = Get-RetoNombres (_rp $Raiz 'fotos')
                    $bak = @($n | Where-Object { $_ -like '*.bak' }).Count
                    $txt = @($n | Where-Object { $_ -like '*.txt' }).Count
                    if ($bak -eq 2 -and $txt -eq 0) { return $true }
                    return "Ahora hay $bak archivos .bak y $txt .txt (debería haber 2 y 0)." }
                P = 'En cmd, `ren *.txt *.bak` lo hace de golpe. En PowerShell, `Rename-Item -NewName { ... }` con `[IO.Path]::ChangeExtension`.'
                Ps = "(Get-ChildItem fotos\*.txt) | Rename-Item -NewName { [IO.Path]::ChangeExtension(`$_.Name, 'bak') }"
                Cmd = 'ren fotos\*.txt *.bak'
            },
            @{
                T = 'Renombra `foto1.jpg`, `foto2.jpg` y `foto3.jpg` a `img_1.jpg`, `img_2.jpg` y `img_3.jpg`.'
                C = { param($Raiz)
                    $n = Get-RetoNombres (_rp $Raiz 'fotos')
                    $falta = @('img_1.jpg', 'img_2.jpg', 'img_3.jpg' | Where-Object { $n -notcontains $_ })
                    $viejos = @($n | Where-Object { $_ -like 'foto*' })
                    if ($falta.Count -eq 0 -and $viejos.Count -eq 0) { return $true }
                    return "Faltan: $($falta -join ', ')   ·   Quedan con nombre antiguo: $($viejos -join ', ')" }
                P = 'En PowerShell, `-replace` cambia una parte del nombre. En cmd tendrás que hacerlo con tres `ren` (no hay una forma cómoda en masa).'
                Ps = "(Get-ChildItem fotos\foto*.jpg) | Rename-Item -NewName { `$_.Name -replace 'foto', 'img_' }"
                Cmd = @'
ren fotos\foto1.jpg img_1.jpg
ren fotos\foto2.jpg img_2.jpg
ren fotos\foto3.jpg img_3.jpg
'@
            },
            @{
                T = 'Añade el prefijo `2024_` a **todos** los archivos de `fotos` (por ejemplo `img_1.jpg` pasa a `2024_img_1.jpg`).'
                C = { param($Raiz)
                    $n = @(Get-RetoNombres (_rp $Raiz 'fotos'))
                    $esperados = @('2024_img_1.jpg', '2024_img_2.jpg', '2024_img_3.jpg', '2024_notas1.bak', '2024_notas2.bak')
                    if (Test-RetoMismoConjunto $n $esperados) { return $true }
                    return "Ahora tienes: $($n -join ', ')   (¡ojo con poner el prefijo dos veces!)" }
                P = 'En PowerShell, guarda la lista entre paréntesis antes de renombrar para no volver a procesar los ya renombrados. En cmd, recorre la salida de `dir /b`.'
                Ps = "(Get-ChildItem fotos -File) | Rename-Item -NewName { '2024_' + `$_.Name }"
                Cmd = 'for /f "delims=" %f in (''dir /b fotos'') do ren "fotos\%f" "2024_%f"'
            },
            @{
                T = 'Cuenta con un comando cuántos archivos de `fotos` empiezan por `2024_img`. Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoNombres (_rp $Raiz 'fotos') | Where-Object { $_ -like '2024_img*' }).Count }
                P = 'Filtra por el patrón `2024_img*` y cuenta.'
                Ps = '(Get-ChildItem fotos -Filter 2024_img*).Count'
                Cmd = 'dir /b fotos\2024_img* | find /c /v ""'
            }
        )
    }

    $b += @{
        Id = 'redirecciones'; Nivel = 1; Titulo = 'Redirecciones y filtros: de un log a un informe'
        Intro = 'Tienes dos logs de una aplicación. Vas a sacar solo los errores, juntarlos, contarlos y ordenarlos, todo con redirecciones (`>`, `>>`) y filtros.'
        Concepto = '`findstr` / `Select-String` filtran líneas; `>` guarda (y sobrescribe), `>>` añade, y `sort` / `Sort-Object` ordenan. Así se prepara un informe sin abrir el archivo.'
        Inicio = ''
        Preparar = { param($Raiz)
            $app = @(
                '10:01:05 INFO Servidor iniciado',
                '10:02:11 ERROR No se pudo abrir la base de datos',
                '10:03:40 INFO Usuario ana conectado',
                '10:05:02 WARN Memoria al 80%',
                '10:06:59 ERROR Tiempo de espera agotado',
                '10:08:15 INFO Usuario luis conectado',
                '10:09:30 ERROR Disco casi lleno',
                '10:11:00 INFO Copia de seguridad hecha',
                '10:12:45 WARN Certificado a punto de caducar',
                '10:14:20 ERROR Fallo al enviar correo'
            )
            $web = @(
                '09:15:02 INFO GET /index.html 200',
                '09:16:44 ERROR GET /admin 500',
                '09:20:10 INFO GET /logo.png 200',
                '09:31:05 ERROR POST /login 503',
                '09:40:00 INFO GET /contacto 200',
                '09:45:12 INFO GET /precios 200'
            )
            New-RetoArchivo (_rp $Raiz 'logs\app.log') (($app -join "`r`n") + "`r`n")
            New-RetoArchivo (_rp $Raiz 'logs\web.log') (($web -join "`r`n") + "`r`n")
        }
        Pasos = @(
            @{
                T = 'Guarda en `errores.txt` solo las líneas de `logs\app.log` que contengan `ERROR`.'
                C = { param($Raiz)
                    $esp = @(Get-RetoLineas (_rp $Raiz 'logs\app.log') | Where-Object { $_ -cmatch 'ERROR' })
                    $got = @(Get-RetoLineas (_rp $Raiz 'errores.txt'))
                    if ($got.Count -eq 0) { return 'errores.txt no existe o está vacío.' }
                    if (($got -join '|') -ceq ($esp -join '|')) { return $true }
                    return "errores.txt debería tener $($esp.Count) líneas (solo las ERROR de app.log) y tiene $($got.Count)." }
                P = 'Filtra con `Select-String` (PowerShell) o `findstr` (cmd) y redirige el resultado a un archivo con `>`.'
                Ps = 'Select-String -Path logs\app.log -Pattern ERROR | ForEach-Object { $_.Line } | Set-Content errores.txt'
                Cmd = 'findstr ERROR logs\app.log > errores.txt'
            },
            @{
                T = 'Añade a `errores.txt` también las líneas ERROR de `logs\web.log`, **sin borrar** lo que ya había.'
                C = { param($Raiz)
                    $esp = @((Get-RetoLineas (_rp $Raiz 'logs\app.log') | Where-Object { $_ -cmatch 'ERROR' }) + (Get-RetoLineas (_rp $Raiz 'logs\web.log') | Where-Object { $_ -cmatch 'ERROR' }))
                    $got = @(Get-RetoLineas (_rp $Raiz 'errores.txt'))
                    if (($got -join '|') -ceq ($esp -join '|')) { return $true }
                    return "errores.txt debería tener $($esp.Count) líneas (las de app.log y luego las de web.log) y tiene $($got.Count)." }
                P = 'Para añadir en vez de sobrescribir: `>>` (cmd y PowerShell) o `Add-Content`.'
                Ps = 'Select-String -Path logs\web.log -Pattern ERROR | ForEach-Object { $_.Line } | Add-Content errores.txt'
                Cmd = 'findstr ERROR logs\web.log >> errores.txt'
            },
            @{
                T = 'Comprueba con un comando cuántas líneas tiene ahora `errores.txt`. Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoLineas (_rp $Raiz 'logs\app.log') | Where-Object { $_ -cmatch 'ERROR' }).Count + @(Get-RetoLineas (_rp $Raiz 'logs\web.log') | Where-Object { $_ -cmatch 'ERROR' }).Count }
                P = '`(Get-Content archivo).Count` en PowerShell; `find /c /v ""` en cmd.'
                Ps = '(Get-Content errores.txt).Count'
                Cmd = 'find /c /v "" errores.txt'
            },
            @{
                T = 'Crea `resumen.txt` con **una sola línea**: el número de líneas de `errores.txt`.'
                C = { param($Raiz)
                    $n = @(Get-RetoLineas (_rp $Raiz 'errores.txt')).Count
                    $l = @(Get-RetoLineas (_rp $Raiz 'resumen.txt'))
                    if ($l.Count -eq 1 -and $l[0] -eq "$n") { return $true }
                    return "resumen.txt debería contener solo el número $n." }
                P = 'Redirige el resultado de contar a un archivo. En cmd, `find /c /v "" < errores.txt` escribe solo el número.'
                Ps = '(Get-Content errores.txt).Count | Set-Content resumen.txt'
                Cmd = 'find /c /v "" < errores.txt > resumen.txt'
            },
            @{
                T = 'Guarda en `errores_ordenados.txt` las líneas de `errores.txt` ordenadas alfabéticamente.'
                C = { param($Raiz)
                    $orig = @(Get-RetoLineas (_rp $Raiz 'errores.txt'))
                    $esp = [string[]]$orig
                    [Array]::Sort($esp, [System.StringComparer]::Ordinal)
                    $got = @(Get-RetoLineas (_rp $Raiz 'errores_ordenados.txt'))
                    if ($got.Count -eq 0) { return 'errores_ordenados.txt no existe o está vacío.' }
                    if (($got -join '|') -ceq ($esp -join '|')) { return $true }
                    return 'errores_ordenados.txt no está ordenado como debería (o le faltan líneas).' }
                P = '`sort` en cmd y `Sort-Object` en PowerShell ordenan líneas. Redirige el resultado a otro archivo.'
                Ps = 'Get-Content errores.txt | Sort-Object | Set-Content errores_ordenados.txt'
                Cmd = 'sort errores.txt > errores_ordenados.txt'
            }
        )
    }

    $b += @{
        Id = 'buscar'; Nivel = 1; Titulo = 'Buscar en un árbol de carpetas'
        Intro = 'Una empresa tiene su información repartida en muchas carpetas. Vas a encontrar archivos perdidos, contarlos y sacar informes con búsquedas recursivas.'
        Concepto = 'Buscar en profundidad: `-Recurse` en PowerShell, `/s` en cmd. Con `-Filter`, `Sort-Object` y `Select-Object` puedes encontrar, contar y ordenar sin abrir ninguna carpeta a mano.'
        Inicio = ''
        Preparar = { param($Raiz) New-RetoEmpresa $Raiz }
        Pasos = @(
            @{
                T = '¿En qué carpeta está `informe-final.docx`? Responde solo con el nombre de la carpeta que lo contiene.'
                Esperada = { 'Q4' }
                P = 'Busca en todo `Empresa` de forma recursiva (`-Recurse` o `/s`) y mira la ruta del resultado.'
                Ps = 'Get-ChildItem Empresa -Recurse -Filter informe-final.docx'
                Cmd = 'dir /s /b informe-final.docx'
            },
            @{
                T = '¿Cuántos archivos `.log` hay en total dentro de `Empresa` (en todas las subcarpetas)? Responde con el número.'
                Esperada = { param($Raiz) @(Get-ChildItem -LiteralPath (_rp $Raiz 'Empresa') -Recurse -Force -File -Filter '*.log').Count }
                P = 'Filtra por `*.log` de forma recursiva y cuenta los resultados.'
                Ps = '(Get-ChildItem Empresa -Recurse -Filter *.log).Count'
                Cmd = 'dir /s /b Empresa\*.log | find /c /v ""'
            },
            @{
                T = 'Crea `rutas.txt` con la ruta **completa** de todos los `.log` de `Empresa`, una por línea.'
                C = { param($Raiz)
                    $esp = @(Get-ChildItem -LiteralPath (_rp $Raiz 'Empresa') -Recurse -Force -File -Filter '*.log' | ForEach-Object { $_.FullName })
                    $got = @(Get-RetoLineas (_rp $Raiz 'rutas.txt'))
                    if ($got.Count -eq 0) { return 'rutas.txt no existe o está vacío.' }
                    if (Test-RetoMismoConjunto $got $esp) { return $true }
                    return "rutas.txt debería tener $($esp.Count) rutas completas y tiene $($got.Count) (¿rutas completas, no solo nombres?)." }
                P = 'Necesitas la ruta completa: en PowerShell, la propiedad `FullName`; en cmd, `dir /s /b` ya la da.'
                Ps = 'Get-ChildItem Empresa -Recurse -Filter *.log | ForEach-Object FullName | Set-Content rutas.txt'
                Cmd = 'dir /s /b Empresa\*.log > rutas.txt'
            },
            @{
                T = '¿Cuál es el archivo **más grande** de todo `Empresa`? Responde con su nombre.'
                Esperada = { 'dump.sql' }
                P = 'Ordena todos los archivos por tamaño (`Length`) de mayor a menor y quédate con el primero.'
                Ps = 'Get-ChildItem Empresa -Recurse -File | Sort-Object Length -Descending | Select-Object -First 1'
                Cmd = 'dir /s Empresa      (y mira los tamaños; en cmd no se puede ordenar todo el árbol: aquí PowerShell gana)'
            },
            @{
                T = 'Crea la carpeta `Empresa\Auditoria` y copia dentro `informe-final.docx`.'
                C = { param($Raiz)
                    if (-not (Test-Path -LiteralPath (_rp $Raiz 'Empresa\Auditoria\informe-final.docx'))) { return 'No veo Empresa\Auditoria\informe-final.docx.' }
                    if (-not (Test-Path -LiteralPath (_rp $Raiz 'Empresa\Ventas\2024\Q4\informe-final.docx'))) { return 'Has movido el archivo en vez de copiarlo: el original ya no está en Q4.' }
                    return $true }
                P = 'Primero la carpeta y luego `Copy-Item` / `copy` del archivo con su ruta completa.'
                Ps = @'
mkdir Empresa\Auditoria
Copy-Item Empresa\Ventas\2024\Q4\informe-final.docx Empresa\Auditoria
'@
                Cmd = @'
mkdir Empresa\Auditoria
copy Empresa\Ventas\2024\Q4\informe-final.docx Empresa\Auditoria
'@
            }
        )
    }

    $b += @{
        Id = 'borrar'; Nivel = 1; Titulo = 'Borrar con cabeza'
        Intro = 'Borrar es lo más peligroso que hace una terminal. Vas a limpiar una carpeta temporal por partes: primero solo lo que toca, luego lo que se resiste, y sin tocar lo importante.'
        Concepto = 'Borra siempre con un filtro claro (`*.tmp`). Para carpetas con archivos protegidos hace falta forzar (`Remove-Item -Recurse -Force`, `rmdir /s /q`). Y comprueba siempre lo que no debía tocarse.'
        Inicio = ''
        Preparar = { param($Raiz)
            New-RetoArchivo (_rp $Raiz 'temp\a.tmp') "temporal`r`n"
            New-RetoArchivo (_rp $Raiz 'temp\b.txt') "apuntes`r`n"
            New-RetoArchivo (_rp $Raiz 'temp\cache\c.tmp') "temporal`r`n"
            New-RetoArchivo (_rp $Raiz 'temp\cache\bloqueado.dat') "protegido`r`n"
            New-RetoArchivo (_rp $Raiz 'temp\logs\d.tmp') "temporal`r`n"
            New-RetoArchivo (_rp $Raiz 'importante.txt') "NO BORRAR`r`n"
            Set-RetoAttr (_rp $Raiz 'temp\cache\bloqueado.dat') -ReadOnly
        }
        Pasos = @(
            @{
                T = '¿Cuántos archivos hay en total dentro de `temp` (contando todas las subcarpetas)? Responde con el número.'
                Esperada = { param($Raiz) @(Get-ChildItem -LiteralPath (_rp $Raiz 'temp') -Recurse -Force -File).Count }
                P = 'Lista solo archivos, de forma recursiva, y cuéntalos.'
                Ps = '(Get-ChildItem temp -Recurse -File).Count'
                Cmd = 'dir /s /b /a-d temp | find /c /v ""'
            },
            @{
                T = 'Borra solo los archivos `.tmp` de `temp` (en todas las subcarpetas), sin tocar nada más.'
                C = { param($Raiz)
                    $t = _rp $Raiz 'temp'
                    $tmp = @(Get-ChildItem -LiteralPath $t -Recurse -Force -File -Filter '*.tmp')
                    if ($tmp.Count -gt 0) { return "Todavía quedan $($tmp.Count) archivos .tmp." }
                    if (-not (Test-Path -LiteralPath (_rp $Raiz 'temp\b.txt'))) { return 'Has borrado b.txt, que no era .tmp. Reinicia con: reto -Reiniciar' }
                    if (-not (Test-Path -LiteralPath (_rp $Raiz 'temp\cache\bloqueado.dat'))) { return 'Has borrado bloqueado.dat, que no era .tmp. Reinicia con: reto -Reiniciar' }
                    return $true }
                P = 'Filtra por `*.tmp` en todo el árbol y borra solo eso.'
                Ps = 'Get-ChildItem temp -Recurse -Filter *.tmp | Remove-Item'
                Cmd = 'del /s /q temp\*.tmp'
            },
            @{
                T = 'Borra la carpeta `temp\cache` **completa**. Ojo: tiene dentro un archivo protegido, así que tendrás que forzar.'
                C = { param($Raiz)
                    if (Test-Path -LiteralPath (_rp $Raiz 'temp\cache')) { return 'temp\cache sigue existiendo.' }
                    if (-not (Test-Path -LiteralPath (_rp $Raiz 'temp\b.txt'))) { return 'Te has llevado b.txt por delante. Reinicia con: reto -Reiniciar' }
                    return $true }
                P = 'PowerShell se niega sin `-Force`. En cmd, `rmdir /s /q` borra el árbol; si se queja, quita antes la protección con `attrib -r temp\cache\*.* /s`.'
                Ps = 'Remove-Item temp\cache -Recurse -Force'
                Cmd = 'rmdir /s /q temp\cache'
            },
            @{
                T = 'Deja `temp` **completamente vacía** pero que la carpeta `temp` siga existiendo. `importante.txt` (que está fuera de `temp`) no se toca.'
                C = { param($Raiz)
                    $t = _rp $Raiz 'temp'
                    if (-not (Test-Path -LiteralPath (_rp $Raiz 'importante.txt'))) { return '¡Has borrado importante.txt! Reinicia con: reto -Reiniciar' }
                    if (-not (Test-Path -LiteralPath $t -PathType Container)) { return 'La carpeta temp ya no existe: debía quedar vacía, no desaparecer.' }
                    $resto = @(Get-ChildItem -LiteralPath $t -Force).Count
                    if ($resto -gt 0) { return "A temp todavía le quedan $resto elementos dentro." }
                    return $true }
                P = 'Borra el contenido de `temp`, no `temp`. En cmd puedes borrar la carpeta y volver a crearla.'
                Ps = 'Get-ChildItem temp -Force | Remove-Item -Recurse -Force'
                Cmd = @'
rmdir /s /q temp
mkdir temp
'@
            }
        )
    }

    $b += @{
        Id = 'rutas'; Nivel = 1; Titulo = 'Moverte por rutas: absolutas, relativas y ..'
        Intro = 'Moverse con soltura entre carpetas es la base de todo. Vas a navegar, crear cosas en otra carpeta sin salir de la tuya usando rutas relativas y saber siempre dónde estás.'
        Concepto = '`cd` cambia de carpeta; `..` es la carpeta de arriba; una ruta relativa parte de donde estás y una absoluta parte de la raíz. `Get-Location` (o `cd` a secas en cmd) te dice dónde estás.'
        Inicio = ''
        Preparar = { param($Raiz)
            New-RetoCarpeta (_rp $Raiz 'Empresa\Ventas\2024')
            New-RetoCarpeta (_rp $Raiz 'Empresa\IT')
            New-RetoCarpeta (_rp $Raiz 'Empresa\RRHH')
        }
        Pasos = @(
            @{
                T = 'Entra con `cd` en la carpeta `Empresa\Ventas\2024`.'
                C = { param($Raiz)
                    if (Test-RetoMismaRuta (Get-RetoAqui) (_rp $Raiz 'Empresa\Ventas\2024')) { return $true }
                    return "Ahora estás en: $(Get-RetoAqui)" }
                P = 'Puedes escribir la ruta relativa completa de una vez.'
                Ps = 'cd Empresa\Ventas\2024'
                Cmd = 'cd Empresa\Ventas\2024'
            },
            @{
                T = 'Sin moverte de ahí, crea un archivo `notas.txt` dentro de la carpeta `IT`, usando una ruta **relativa** que suba con `..`.'
                C = { param($Raiz)
                    if (-not (Test-RetoMismaRuta (Get-RetoAqui) (_rp $Raiz 'Empresa\Ventas\2024'))) { return "Te has movido de sitio: ahora estás en $(Get-RetoAqui). Vuelve a Empresa\Ventas\2024." }
                    if (Test-Path -LiteralPath (_rp $Raiz 'Empresa\IT\notas.txt')) { return $true }
                    return 'No veo Empresa\IT\notas.txt.' }
                P = 'Desde `2024` hay que subir dos niveles (`..\..`) para llegar a `Empresa`, y luego bajar a `IT`.'
                Ps = 'New-Item ..\..\IT\notas.txt'
                Cmd = 'type nul > ..\..\IT\notas.txt'
            },
            @{
                T = 'Vuelve a la carpeta donde empezaste el reto (tu carpeta de práctica).'
                C = { param($Raiz)
                    if (Test-RetoMismaRuta (Get-RetoAqui) $Raiz) { return $true }
                    return "Ahora estás en: $(Get-RetoAqui)" }
                P = 'Cada `..` sube un nivel; desde `2024` son tres. También sirve la ruta completa.'
                Ps = 'cd ..\..\..'
                Cmd = 'cd ..\..\..'
            },
            @{
                T = 'Crea las carpetas `Empresa\Legal\Contratos` con **un solo comando** (`Legal` y `Contratos` a la vez).'
                C = { param($Raiz)
                    if (Test-Path -LiteralPath (_rp $Raiz 'Empresa\Legal\Contratos') -PathType Container) { return $true }
                    return 'No veo la carpeta Empresa\Legal\Contratos.' }
                P = '`mkdir` crea también las carpetas intermedias que falten.'
                Ps = 'mkdir Empresa\Legal\Contratos'
                Cmd = 'mkdir Empresa\Legal\Contratos'
            },
            @{
                T = 'Guarda en `donde.txt` la ruta **completa** de la carpeta en la que estás ahora.'
                C = { param($Raiz)
                    $l = @(Get-RetoLineas (_rp $Raiz 'donde.txt'))
                    if ($l.Count -eq 0) { return 'donde.txt no existe o está vacío.' }
                    $t = ($l[0] -replace '\\', '/').TrimEnd('/')
                    $cola = ((Split-Path (Split-Path $Raiz) -Leaf) + '/' + (Split-Path $Raiz -Leaf))
                    if ($t.EndsWith($cola, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
                    return 'La ruta de donde.txt no es la de tu carpeta de práctica actual.' }
                P = 'En PowerShell, `Get-Location` da la ruta actual. En cmd, `cd` sin nada la muestra.'
                Ps = '(Get-Location).Path | Set-Content donde.txt'
                Cmd = 'cd > donde.txt'
            }
        )
    }

    # ============================================================= #
    #  NIVEL 2 · SERVIDOR Y PERMISOS                                #
    # ============================================================= #
    # Todos estos retos usan un "servidor de archivos" de juguete: SRV01\Shares\...
    # Los permisos son NTFS de verdad (icacls). Para que funcione en cualquier idioma
    # de Windows se usan SID: *S-1-5-32-545 = Users/Usuarios, *S-1-5-32-544 = Administrators.

    $b += @{
        Id = 'servidor'; Nivel = 2; Titulo = 'Montar un departamento nuevo en el servidor de archivos'
        Intro = 'Trabajas en el servidor SRV01. Ha llegado un departamento nuevo, Marketing, y tienes que prepararle su carpeta, su estructura y una copia de seguridad, como se haría en un Windows Server de verdad.'
        Concepto = 'Un servidor de archivos es un árbol de carpetas compartidas (Shares\Departamentos\...) con una carpeta por departamento y una copia en Backup. Todo lo que hagas aquí a mano se puede automatizar luego con un script.'
        Inicio = 'SRV01'
        Preparar = { param($Raiz) New-RetoServidor $Raiz }
        Pasos = @(
            @{
                T = 'Entra en `Shares\Departamentos` y cuenta cuántos departamentos (carpetas) hay ya. Responde con el número.'
                Esperada = { param($Raiz) @(Get-ChildItem -LiteralPath (_rp $Raiz 'SRV01\Shares\Departamentos') -Force -Directory).Count }
                P = 'Lista solo las carpetas de `Departamentos` y cuéntalas.'
                Ps = '(Get-ChildItem Shares\Departamentos -Directory).Count'
                Cmd = 'dir /b /ad Shares\Departamentos | find /c /v ""'
            },
            @{
                T = 'Crea la carpeta del departamento `Marketing` dentro de `Shares\Departamentos`, con dos subcarpetas: `Documentos` y `Privado`.'
                C = { param($Raiz)
                    $m = _rp $Raiz 'SRV01\Shares\Departamentos\Marketing'
                    $falta = @('Documentos', 'Privado' | Where-Object { -not (Test-Path -LiteralPath (Join-Path $m $_) -PathType Container) })
                    if ($falta.Count -eq 0) { return $true }
                    return "Falta dentro de Marketing: $($falta -join ', ')" }
                P = 'Puedes crear las dos subcarpetas con `mkdir` (crea también las carpetas intermedias que falten).'
                Ps = @'
mkdir Shares\Departamentos\Marketing\Documentos
mkdir Shares\Departamentos\Marketing\Privado
'@
                Cmd = @'
mkdir Shares\Departamentos\Marketing\Documentos
mkdir Shares\Departamentos\Marketing\Privado
'@
            },
            @{
                T = 'Crea el archivo `bienvenida.txt` dentro de `Marketing\Documentos` con el texto `Bienvenido a Marketing`.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'SRV01\Shares\Departamentos\Marketing\Documentos\bienvenida.txt'
                    if (-not (Test-Path -LiteralPath $f)) { return 'No veo Marketing\Documentos\bienvenida.txt.' }
                    if ((Get-RetoLineas $f) -contains 'Bienvenido a Marketing') { return $true }
                    return 'El archivo existe pero no contiene exactamente: Bienvenido a Marketing' }
                P = 'Redirige un `echo` al archivo con `>` o usa `Set-Content`.'
                Ps = 'Set-Content Shares\Departamentos\Marketing\Documentos\bienvenida.txt "Bienvenido a Marketing"'
                Cmd = 'echo Bienvenido a Marketing > Shares\Departamentos\Marketing\Documentos\bienvenida.txt'
            },
            @{
                T = 'Haz la copia de seguridad: copia la carpeta `Marketing` **entera** dentro de `Backup` (debe quedar `Backup\Marketing`).'
                C = { param($Raiz)
                    $o = Get-RetoRelativos (_rp $Raiz 'SRV01\Shares\Departamentos\Marketing')
                    $c = Get-RetoRelativos (_rp $Raiz 'SRV01\Backup\Marketing')
                    if ($c.Count -eq 0) { return 'No encuentro Backup\Marketing con archivos dentro.' }
                    if (Test-RetoMismoConjunto $o $c) { return $true }
                    return "La copia tiene $($c.Count) archivos y el original $($o.Count)." }
                P = 'Copia con recursividad: `Copy-Item -Recurse`, `xcopy /e /i` o `robocopy /e`.'
                Ps = 'Copy-Item Shares\Departamentos\Marketing Backup\Marketing -Recurse'
                Cmd = 'xcopy Shares\Departamentos\Marketing Backup\Marketing /e /i'
                Alt = 'robocopy Shares\Departamentos\Marketing Backup\Marketing /e'
            },
            @{
                T = 'Verifica la copia: cuenta cuántos archivos hay en **todo** `Backup` (contando subcarpetas). Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoRelativos (_rp $Raiz 'SRV01\Backup')).Count }
                P = 'Lista todos los archivos de `Backup` de forma recursiva y cuéntalos.'
                Ps = '(Get-ChildItem Backup -Recurse -File).Count'
                Cmd = 'dir /s /b /a-d Backup | find /c /v ""'
            }
        )
    }

    $b += @{
        Id = 'permisos-leer'; Nivel = 2; Titulo = 'Ver y dar permisos con icacls'
        Intro = 'Los permisos NTFS deciden quién puede leer, escribir o borrar. La herramienta de terminal para verlos y cambiarlos es `icacls`. Vas a leer los permisos de la carpeta Publico y darle escritura al grupo Usuarios.'
        Concepto = '`icacls carpeta` muestra los permisos. `/grant` añade. Las letras: F control total, M modificar, RX leer y ejecutar, R solo leer. (OI)(CI) hace que lo hereden archivos y subcarpetas. Con `*S-1-5-32-545` te sirve el grupo Usuarios en cualquier idioma de Windows.'
        Inicio = 'SRV01'
        Preparar = { param($Raiz) New-RetoServidor $Raiz }
        Pasos = @(
            @{
                T = 'Mira con `icacls` los permisos de `Shares\Publico`. En la línea de `BUILTIN\Users` (o `BUILTIN\Usuarios`) hay unas letras entre paréntesis que dicen qué puede hacer. Responde con esas letras (por ejemplo `F`, `M`... las que veas).'
                Esperada = { 'RX' }
                P = 'Escribe `icacls Shares\Publico`. La línea de Users acaba en `(OI)(CI)(RX)`: la última parte es el permiso.'
                Ps = 'icacls Shares\Publico'
                Cmd = 'icacls Shares\Publico'
            },
            @{
                T = 'Ahora los usuarios necesitan poder **escribir** en `Publico`. Concede al grupo Usuarios el permiso **Modificar (M)**, heredable a lo que haya dentro.'
                C = { param($Raiz)
                    $p = _rp $Raiz 'SRV01\Shares\Publico'
                    if (Test-RetoPermiso $p $global:RetoSid.Users 'Escritura') { return $true }
                    return 'El grupo Usuarios todavía no puede escribir en Publico. Revisa con icacls Shares\Publico.' }
                P = 'Usa `/grant` con el SID del grupo Usuarios: `"*S-1-5-32-545:(OI)(CI)M"` (las comillas son necesarias).'
                Ps = 'icacls Shares\Publico /grant "*S-1-5-32-545:(OI)(CI)M"'
                Cmd = 'icacls Shares\Publico /grant "*S-1-5-32-545:(OI)(CI)M"'
                Alt = 'icacls Shares\Publico /grant "Users:(OI)(CI)M"      (solo si tu Windows está en inglés)'
            },
            @{
                T = 'Comprueba el cambio con `icacls Shares\Publico`. ¿Qué letra pone ahora para Users? Responde con la letra.'
                Esperada = { 'M' }
                P = 'Vuelve a listar los permisos: ahora hay una entrada nueva de Users con `(M)`.'
                Ps = 'icacls Shares\Publico'
                Cmd = 'icacls Shares\Publico'
            },
            @{
                T = 'Prueba que funciona: crea el archivo `prueba.txt` en `Shares\Publico`.'
                C = { param($Raiz)
                    if (Test-Path -LiteralPath (_rp $Raiz 'SRV01\Shares\Publico\prueba.txt')) { return $true }
                    return 'No veo Shares\Publico\prueba.txt.' }
                P = '`New-Item` en PowerShell, `type nul >` en cmd.'
                Ps = 'New-Item Shares\Publico\prueba.txt -ItemType File'
                Cmd = 'type nul > Shares\Publico\prueba.txt'
            }
        )
    }

    $b += @{
        Id = 'permisos-quitar'; Nivel = 2; Titulo = 'Cerrar una carpeta: quitar la herencia y los permisos'
        Intro = 'La carpeta de nóminas de RRHH la puede leer todo el mundo porque hereda los permisos de arriba. Es un problema serio. Vas a cortar la herencia y quitar al grupo Usuarios.'
        Concepto = 'Para que una carpeta tenga permisos distintos a los de su padre hay que cortar la herencia (`/inheritance:d` la corta copiando lo heredado). Solo después se puede quitar un permiso heredado con `/remove:g`.'
        Inicio = 'SRV01'
        Preparar = { param($Raiz) New-RetoServidor $Raiz }
        Pasos = @(
            @{
                T = 'Corta la herencia en `Shares\Departamentos\RRHH\Nominas`, **convirtiendo** los permisos heredados en permisos propios.'
                C = { param($Raiz)
                    $n = _rp $Raiz 'SRV01\Shares\Departamentos\RRHH\Nominas'
                    if (Test-RetoHerenciaActiva $n) { return 'Nominas todavía hereda los permisos de su carpeta padre.' }
                    if (@(Get-RetoAce $n).Count -eq 0) { return 'Has cortado la herencia sin copiar permisos: la carpeta se ha quedado sin nadie. Usa /inheritance:d' }
                    return $true }
                P = '`icacls carpeta /inheritance:d` desactiva la herencia y copia los permisos heredados como propios.'
                Ps = 'icacls Shares\Departamentos\RRHH\Nominas /inheritance:d'
                Cmd = 'icacls Shares\Departamentos\RRHH\Nominas /inheritance:d'
            },
            @{
                T = 'Quita el permiso del grupo Usuarios sobre `Nominas`.'
                C = { param($Raiz)
                    $n = _rp $Raiz 'SRV01\Shares\Departamentos\RRHH\Nominas'
                    $u = @(Get-RetoAce $n | Where-Object { $_.Sid -eq $global:RetoSid.Users })
                    if ($u.Count -gt 0) { return 'El grupo Usuarios todavía aparece en los permisos de Nominas.' }
                    return $true }
                P = '`/remove:g` quita los permisos concedidos a un grupo: `icacls carpeta /remove:g "*S-1-5-32-545"`.'
                Ps = 'icacls Shares\Departamentos\RRHH\Nominas /remove:g "*S-1-5-32-545"'
                Cmd = 'icacls Shares\Departamentos\RRHH\Nominas /remove:g "*S-1-5-32-545"'
                Alt = 'icacls Shares\Departamentos\RRHH\Nominas /remove:g "Users"      (solo si tu Windows está en inglés)'
            },
            @{
                T = 'Comprueba con `icacls` cuántas cuentas quedan con acceso a `Nominas`. Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoAce (_rp $Raiz 'SRV01\Shares\Departamentos\RRHH\Nominas')).Count }
                P = 'Cada línea de permiso de `icacls` es una cuenta con acceso. Cuéntalas (no cuentes la línea de la ruta ni el mensaje final).'
                Ps = 'icacls Shares\Departamentos\RRHH\Nominas'
                Cmd = 'icacls Shares\Departamentos\RRHH\Nominas'
            },
            @{
                T = 'Crea un archivo nuevo `nomina_febrero.txt` dentro de `Nominas` y comprueba que **hereda** el cierre: Usuarios no debe poder leerlo.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'SRV01\Shares\Departamentos\RRHH\Nominas\nomina_febrero.txt'
                    if (-not (Test-Path -LiteralPath $f)) { return 'No veo Nominas\nomina_febrero.txt.' }
                    if (Test-RetoPermiso $f $global:RetoSid.Users 'Lectura') { return 'Usuarios todavía puede leer ese archivo: revisa los permisos de la carpeta.' }
                    return $true }
                P = 'Basta con crear el archivo: los permisos los hereda de la carpeta `Nominas`.'
                Ps = 'New-Item Shares\Departamentos\RRHH\Nominas\nomina_febrero.txt -ItemType File'
                Cmd = 'type nul > Shares\Departamentos\RRHH\Nominas\nomina_febrero.txt'
            }
        )
    }

    $b += @{
        Id = 'herencia'; Nivel = 2; Titulo = 'Herencia de permisos: cortarla y recuperarla'
        Intro = 'Lo normal en un servidor es que las subcarpetas hereden permisos de su carpeta padre. Vas a crear una subcarpeta, cortarle la herencia, cambiar sus permisos y luego volver a activarla.'
        Concepto = 'Con herencia activada la subcarpeta copia lo del padre. `/inheritance:d` la corta (copiando), `/inheritance:r` la corta (borrando lo heredado) y `/inheritance:e` la vuelve a activar.'
        Inicio = 'SRV01'
        Preparar = { param($Raiz) New-RetoServidor $Raiz }
        Pasos = @(
            @{
                T = 'Crea la subcarpeta `Informes` dentro de `Shares\Departamentos\Finanzas`. Después responde: ¿hereda los permisos de `Finanzas`? (si/no)'
                Esperada = { 'si' }
                Modo = 'bool'
                P = 'Créala con `mkdir`. Las carpetas nuevas heredan por defecto. Mira `icacls` y busca los `(I)` en las líneas de permisos.'
                Ps = 'mkdir Shares\Departamentos\Finanzas\Informes'
                Cmd = 'mkdir Shares\Departamentos\Finanzas\Informes'
            },
            @{
                T = 'Corta la herencia en `Informes` **copiando** los permisos heredados.'
                C = { param($Raiz)
                    $i = _rp $Raiz 'SRV01\Shares\Departamentos\Finanzas\Informes'
                    if (-not (Test-Path -LiteralPath $i)) { return 'No existe la carpeta Informes: créala en el paso anterior.' }
                    if (Test-RetoHerenciaActiva $i) { return 'Informes todavía hereda los permisos.' }
                    return $true }
                P = '`/inheritance:d` corta y copia.'
                Ps = 'icacls Shares\Departamentos\Finanzas\Informes /inheritance:d'
                Cmd = 'icacls Shares\Departamentos\Finanzas\Informes /inheritance:d'
            },
            @{
                T = 'Quita al grupo Usuarios de `Informes`.'
                C = { param($Raiz)
                    $i = _rp $Raiz 'SRV01\Shares\Departamentos\Finanzas\Informes'
                    $u = @(Get-RetoAce $i | Where-Object { $_.Sid -eq $global:RetoSid.Users })
                    if ($u.Count -eq 0) { return $true }
                    return 'Usuarios todavía tiene permisos en Informes.' }
                P = '`/remove:g "*S-1-5-32-545"`'
                Ps = 'icacls Shares\Departamentos\Finanzas\Informes /remove:g "*S-1-5-32-545"'
                Cmd = 'icacls Shares\Departamentos\Finanzas\Informes /remove:g "*S-1-5-32-545"'
            },
            @{
                T = 'Has cambiado de idea: vuelve a **activar la herencia** en `Informes`.'
                C = { param($Raiz)
                    $i = _rp $Raiz 'SRV01\Shares\Departamentos\Finanzas\Informes'
                    if (-not (Test-RetoHerenciaActiva $i)) { return 'La herencia sigue desactivada.' }
                    return $true }
                P = '`/inheritance:e` la vuelve a activar.'
                Ps = 'icacls Shares\Departamentos\Finanzas\Informes /inheritance:e'
                Cmd = 'icacls Shares\Departamentos\Finanzas\Informes /inheritance:e'
            },
            @{
                T = 'Comprueba con `icacls` si el grupo Usuarios vuelve a tener acceso a `Informes` (por herencia). Responde si o no.'
                Esperada = { param($Raiz)
                    if (Test-RetoPermiso (_rp $Raiz 'SRV01\Shares\Departamentos\Finanzas\Informes') $global:RetoSid.Users 'Lectura') { 'si' } else { 'no' } }
                Modo = 'bool'
                P = 'Vuelve a listar con `icacls`: al activar la herencia reaparecen los permisos del padre.'
                Ps = 'icacls Shares\Departamentos\Finanzas\Informes'
                Cmd = 'icacls Shares\Departamentos\Finanzas\Informes'
            }
        )
    }

    $b += @{
        Id = 'verificar'; Nivel = 2; Titulo = 'Verificar y auditar permisos: guardar un informe y usar Deny'
        Intro = 'Un administrador no solo cambia permisos: los comprueba y deja constancia. Vas a guardar un informe de permisos en un archivo y usar una denegación explícita (Deny), que es lo más fuerte que hay.'
        Concepto = 'Una denegación (`/deny`) siempre gana a un permiso concedido. Se quita con `/remove:d`. Y cualquier salida de `icacls` puede redirigirse a un archivo con `>` para guardarla como evidencia.'
        Inicio = 'SRV01'
        Preparar = { param($Raiz) New-RetoServidor $Raiz }
        Pasos = @(
            @{
                T = 'Guarda en `permisos_it.txt` (en `SRV01`) la salida de `icacls` de la carpeta `Shares\Departamentos\IT`.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'SRV01\permisos_it.txt'
                    $l = @(Get-RetoLineas $f)
                    if ($l.Count -eq 0) { return 'permisos_it.txt no existe o está vacío.' }
                    if (($l -join ' ') -match 'Departamentos[\\/]IT') { return $true }
                    return 'permisos_it.txt no parece la salida de icacls sobre Departamentos\IT.' }
                P = 'Redirige con `>`: `icacls carpeta > archivo`.'
                Ps = 'icacls Shares\Departamentos\IT > permisos_it.txt'
                Cmd = 'icacls Shares\Departamentos\IT > permisos_it.txt'
            },
            @{
                T = 'Impide que el grupo Usuarios **escriba** en `IT\Privado` con una denegación explícita (`W`), heredable.'
                C = { param($Raiz)
                    $p = _rp $Raiz 'SRV01\Shares\Departamentos\IT\Privado'
                    $d = @(Get-RetoAce $p | Where-Object { $_.Sid -eq $global:RetoSid.Users -and $_.Tipo -eq 'Deny' -and (($_.Derechos -band 2) -ne 0) })
                    if ($d.Count -gt 0) { return $true }
                    return 'No veo ninguna denegación de escritura para Usuarios en IT\Privado.' }
                P = '`/deny "*S-1-5-32-545:(OI)(CI)W"`'
                Ps = 'icacls Shares\Departamentos\IT\Privado /deny "*S-1-5-32-545:(OI)(CI)W"'
                Cmd = 'icacls Shares\Departamentos\IT\Privado /deny "*S-1-5-32-545:(OI)(CI)W"'
            },
            @{
                T = 'Pregunta teórica: si a un grupo le das permiso de modificar **y** una denegación de escribir, ¿qué gana? Responde `deny` o `allow`.'
                Esperada = { 'deny|deneg|prohib' }
                Modo = 'regex'
                P = 'La denegación explícita es la regla más fuerte de NTFS.'
                Ps = 'responder deny'
                Cmd = 'responder deny'
            },
            @{
                T = 'Quita la denegación que acabas de poner (solo la denegación, no los demás permisos).'
                C = { param($Raiz)
                    $p = _rp $Raiz 'SRV01\Shares\Departamentos\IT\Privado'
                    $d = @(Get-RetoAce $p | Where-Object { $_.Tipo -eq 'Deny' })
                    if ($d.Count -eq 0) { return $true }
                    return 'Todavía queda una denegación en IT\Privado.' }
                P = '`/remove:d` quita las denegaciones de una cuenta.'
                Ps = 'icacls Shares\Departamentos\IT\Privado /remove:d "*S-1-5-32-545"'
                Cmd = 'icacls Shares\Departamentos\IT\Privado /remove:d "*S-1-5-32-545"'
            },
            @{
                T = 'Guarda un informe final en `permisos_it_final.txt` con los permisos actuales de `IT\Privado`.'
                C = { param($Raiz)
                    $l = @(Get-RetoLineas (_rp $Raiz 'SRV01\permisos_it_final.txt'))
                    if ($l.Count -eq 0) { return 'permisos_it_final.txt no existe o está vacío.' }
                    if (($l -join ' ') -match 'IT[\\/]Privado') { return $true }
                    return 'Ese informe no es de IT\Privado.' }
                P = 'Igual que el primer paso, pero con la carpeta `Privado`.'
                Ps = 'icacls Shares\Departamentos\IT\Privado > permisos_it_final.txt'
                Cmd = 'icacls Shares\Departamentos\IT\Privado > permisos_it_final.txt'
            }
        )
    }

    # ============================================================= #
    #  NIVEL 3 · ESCENARIOS                                         #
    # ============================================================= #

    $b += @{
        Id = 'rescate'; Nivel = 3; Titulo = 'Rescate: recuperar datos de una carpeta llena de trampas'
        Intro = 'Te han pasado una carpeta de un compañero que se fue. Tiene archivos ocultos y de solo lectura repartidos por las subcarpetas. Tienes que recuperar todo en una carpeta limpia y borrar la original.'
        Concepto = '`attrib` con `/s /d` trabaja en todo el árbol. Ocultos y solo lectura son atributos independientes: hay que quitar los dos. Para borrar un árbol con protegidos hay que forzar.'
        Inicio = ''
        Preparar = { param($Raiz)
            foreach ($n in 'plan.txt', 'presupuesto.txt') { New-RetoArchivo (_rp $Raiz "Proyectos\$n") "contenido $n`r`n" }
            foreach ($n in 'acta.txt', 'claves.txt', 'notas.txt') { New-RetoArchivo (_rp $Raiz "Proyectos\Reuniones\$n") "contenido $n`r`n" }
            New-RetoArchivo (_rp $Raiz 'Proyectos\Reuniones\Viejas\acta_2019.txt') "acta vieja`r`n"
            New-RetoArchivo (_rp $Raiz 'Proyectos\Fotos\f1.jpg') "foto`r`n"
            Set-RetoAttr (_rp $Raiz 'Proyectos\plan.txt') -ReadOnly
            Set-RetoAttr (_rp $Raiz 'Proyectos\Reuniones\claves.txt') -Hidden
            Set-RetoAttr (_rp $Raiz 'Proyectos\Reuniones\notas.txt') -ReadOnly
            Set-RetoAttr (_rp $Raiz 'Proyectos\Reuniones\Viejas\acta_2019.txt') -Hidden -ReadOnly
            Set-RetoAttr (_rp $Raiz 'Proyectos\Fotos\f1.jpg') -Hidden
        }
        Pasos = @(
            @{
                T = 'Cuenta **todos** los archivos de `Proyectos` (ocultos incluidos, en todas las subcarpetas). Responde con el número.'
                Esperada = { param($Raiz) @(Get-ChildItem -LiteralPath (_rp $Raiz 'Proyectos') -Recurse -Force -File).Count }
                P = 'Sin `-Force` (o `/a`) no ves los ocultos.'
                Ps = '(Get-ChildItem Proyectos -Recurse -Force -File).Count'
                Cmd = 'dir /s /b /a-d Proyectos | find /c /v ""'
            },
            @{
                T = 'Quita el atributo **oculto** a todos los archivos de `Proyectos` y sus subcarpetas.'
                C = { param($Raiz)
                    $h = @(Get-ChildItem -LiteralPath (_rp $Raiz 'Proyectos') -Recurse -Force -File | Where-Object { (Get-RetoAttr $_.FullName).Hidden })
                    if ($h.Count -eq 0) { return $true }
                    return "Todavía hay $($h.Count) archivos ocultos." }
                P = '`attrib -h` con `/s` (subcarpetas) y `/d` (incluir carpetas), sobre `Proyectos\*`.'
                Ps = 'attrib -h Proyectos\* /s /d'
                Cmd = 'attrib -h Proyectos\* /s /d'
                Alt = 'Get-ChildItem Proyectos -Recurse -Force -File | ForEach-Object { $_.Attributes = $_.Attributes -band (-bnot [IO.FileAttributes]::Hidden) }'
            },
            @{
                T = 'Quita ahora el **solo lectura** a todos.'
                C = { param($Raiz)
                    $h = @(Get-ChildItem -LiteralPath (_rp $Raiz 'Proyectos') -Recurse -Force -File | Where-Object { (Get-RetoAttr $_.FullName).ReadOnly })
                    if ($h.Count -eq 0) { return $true }
                    return "Todavía hay $($h.Count) archivos de solo lectura." }
                P = 'Igual, pero con `-r`.'
                Ps = 'attrib -r Proyectos\* /s /d'
                Cmd = 'attrib -r Proyectos\* /s /d'
            },
            @{
                T = 'Crea una carpeta `Recuperado` y copia dentro todo el contenido de `Proyectos` (con subcarpetas).'
                C = { param($Raiz)
                    $o = Get-RetoRelativos (_rp $Raiz 'Proyectos')
                    $c = Get-RetoRelativos (_rp $Raiz 'Recuperado')
                    if ($c.Count -eq 0) { return 'Recuperado no existe o está vacía.' }
                    if (Test-RetoMismoConjunto $o $c) { return $true }
                    return "Recuperado tiene $($c.Count) archivos y Proyectos $($o.Count)." }
                P = 'Recuerda la recursividad. Si copias `Proyectos\*` el contenido cae dentro de `Recuperado` sin la carpeta `Proyectos`.'
                Ps = 'Copy-Item Proyectos Recuperado -Recurse'
                Cmd = 'xcopy Proyectos Recuperado /e /i'
            },
            @{
                T = 'Borra la carpeta original `Proyectos`.'
                C = { param($Raiz)
                    if (Test-Path -LiteralPath (_rp $Raiz 'Proyectos')) { return 'Proyectos sigue existiendo.' }
                    if (@(Get-RetoRelativos (_rp $Raiz 'Recuperado')).Count -eq 0) { return 'Has borrado Proyectos pero Recuperado está vacía. Reinicia con: reto -Reiniciar' }
                    return $true }
                P = 'Borrado recursivo: `-Recurse -Force` o `rmdir /s /q`.'
                Ps = 'Remove-Item Proyectos -Recurse -Force'
                Cmd = 'rmdir /s /q Proyectos'
            },
            @{
                T = 'Última comprobación: cuenta los archivos de `Recuperado`. Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoRelativos (_rp $Raiz 'Recuperado')).Count }
                P = 'Recursivo y solo archivos.'
                Ps = '(Get-ChildItem Recuperado -Recurse -Force -File).Count'
                Cmd = 'dir /s /b /a-d Recuperado | find /c /v ""'
            }
        )
    }

    $b += @{
        Id = 'auditoria'; Nivel = 3; Titulo = 'Auditoría del servidor: sacar datos y guardarlos en un informe'
        Intro = 'El jefe de IT quiere un informe del servidor: qué hay, cuánto ocupa y qué carpetas están cerradas a los usuarios. Aquí PowerShell brilla: cmd apenas sirve para esto.'
        Concepto = '`Get-ChildItem` + `Where-Object` + `Sort-Object` + `Export-Csv` forman un mini sistema de informes. La salida son objetos (Name, Length, FullName), no texto suelto.'
        Inicio = 'SRV01'
        Preparar = { param($Raiz)
            New-RetoServidor $Raiz
            New-RetoArchivo (_rp $Raiz 'SRV01\Shares\Departamentos\IT\Privado\claves.kdbx') ('x' * 3000)
            New-RetoArchivo (_rp $Raiz 'SRV01\Shares\Departamentos\Finanzas\Documentos\balance.xlsx') ('x' * 1500)
            $rrhh = _rp $Raiz 'SRV01\Shares\Departamentos\RRHH\Nominas'
            Invoke-RetoIcacls @($rrhh, '/inheritance:d')
            Invoke-RetoIcacls @($rrhh, '/remove:g', "*$($global:RetoSid.Users)")
        }
        Pasos = @(
            @{
                T = '¿Cuántos archivos hay en total en `Shares` (todas las subcarpetas)? Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoRelativos (_rp $Raiz 'SRV01\Shares')).Count }
                P = 'Recursivo, solo archivos, y cuenta.'
                Ps = '(Get-ChildItem Shares -Recurse -File).Count'
                Cmd = 'dir /s /b /a-d Shares | find /c /v ""'
            },
            @{
                T = '¿Cuál es el archivo más grande de `Shares`? Responde con su nombre.'
                Esperada = { 'claves.kdbx' }
                P = 'Ordena por `Length` de mayor a menor y coge el primero.'
                Ps = 'Get-ChildItem Shares -Recurse -File | Sort-Object Length -Descending | Select-Object -First 1'
                Cmd = 'dir /s Shares      (mira los tamaños a ojo: para ordenar, PowerShell)'
            },
            @{
                T = 'Guarda en `grandes.txt` los **nombres** de los archivos de `Shares` que pesen más de 1000 bytes, uno por línea.'
                C = { param($Raiz)
                    $esp = @(Get-ChildItem -LiteralPath (_rp $Raiz 'SRV01\Shares') -Recurse -Force -File | Where-Object { $_.Length -gt 1000 } | ForEach-Object { $_.Name })
                    $got = @(Get-RetoLineas (_rp $Raiz 'SRV01\grandes.txt'))
                    if ($got.Count -eq 0) { return 'grandes.txt no existe o está vacío.' }
                    if (Test-RetoMismoConjunto $got $esp) { return $true }
                    return "grandes.txt debería tener $($esp.Count) nombres y tiene $($got.Count)." }
                P = '`Where-Object { $_.Length -gt 1000 }` y luego `ForEach-Object Name` o `Select-Object -ExpandProperty Name`.'
                Ps = 'Get-ChildItem Shares -Recurse -File | Where-Object { $_.Length -gt 1000 } | ForEach-Object Name | Set-Content grandes.txt'
                Cmd = ''
            },
            @{
                T = 'Exporta a `informe.csv` el nombre y el tamaño (`Name` y `Length`) de todos los archivos de `Shares`.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'SRV01\informe.csv'
                    if (-not (Test-Path -LiteralPath $f)) { return 'informe.csv no existe.' }
                    try { $d = @(Import-Csv -LiteralPath $f) } catch { return 'informe.csv no se puede leer como CSV.' }
                    $n = @(Get-RetoRelativos (_rp $Raiz 'SRV01\Shares')).Count
                    if ($d.Count -ne $n) { return "informe.csv tiene $($d.Count) filas y debería tener $n." }
                    $cols = @($d[0].PSObject.Properties.Name)
                    if ($cols -notcontains 'Name' -or $cols -notcontains 'Length') { return 'Las columnas deben incluir Name y Length.' }
                    return $true }
                P = '`Select-Object Name, Length | Export-Csv informe.csv -NoTypeInformation`.'
                Ps = 'Get-ChildItem Shares -Recurse -File | Select-Object Name, Length | Export-Csv informe.csv -NoTypeInformation'
                Cmd = ''
            },
            @{
                T = 'Algunas carpetas de `Departamentos` están cerradas al grupo Usuarios. ¿Cuál? Compruébalo con `icacls` en cada una y responde con el **nombre de la subcarpeta** de `RRHH` que lo está.'
                Esperada = { 'Nominas' }
                P = 'Mira `icacls` de `RRHH\Nominas` y compáralo con el de otra carpeta: falta la línea de Users.'
                Ps = 'icacls Shares\Departamentos\RRHH\Nominas'
                Cmd = 'icacls Shares\Departamentos\RRHH\Nominas'
            }
        )
    }

    $b += @{
        Id = 'bloqueado'; Nivel = 3; Titulo = 'Acceso denegado: ¿quién me ha bloqueado esta carpeta?'
        Intro = 'Un compañero ha puesto una denegación sobre tu usuario en la carpeta Confidencial y no puedes ni listarla. Diagnostica el problema, arréglalo y recupera un archivo.'
        Concepto = 'Cuando aparece "Acceso denegado" no hay que pelearse: `icacls` dice qué cuenta tiene un `(DENY)`. Si eres el propietario (o administrador) puedes quitarla con `/remove:d`.'
        Inicio = ''
        Preparar = { param($Raiz)
            New-RetoArchivo (_rp $Raiz 'Confidencial\contrato.txt') "contrato secreto`r`n"
            New-RetoArchivo (_rp $Raiz 'Confidencial\clientes.txt') "lista de clientes`r`n"
            New-RetoArchivo (_rp $Raiz 'Confidencial\Anexos\anexo1.txt') "anexo`r`n"
            Invoke-RetoIcacls @((_rp $Raiz 'Confidencial'), '/deny', ('*{0}:(OI)(CI)(RD)' -f (Get-RetoYo)))
        }
        Pasos = @(
            @{
                T = 'Intenta listar el contenido de `Confidencial`. Fallará. ¿Cuál es el mensaje de error? Responde con la palabra clave del error (la que dice que no tienes acceso).'
                Esperada = { 'deneg|denied|acces' }
                Modo = 'regex'
                P = 'Es el típico "Acceso denegado" / "Access is denied".'
                Ps = 'Get-ChildItem Confidencial'
                Cmd = 'dir Confidencial'
            },
            @{
                T = 'Mira con `icacls` los permisos de `Confidencial`. Hay una línea con `(DENY)`. Responde con esa palabra.'
                Esperada = { 'deny|deneg' }
                Modo = 'regex'
                P = 'Busca la línea que dice `(DENY)` o `(DENEGAR)` al lado de tu usuario.'
                Ps = 'icacls Confidencial'
                Cmd = 'icacls Confidencial'
            },
            @{
                T = 'Quita esa denegación sobre tu usuario (`%USERNAME%`).'
                C = { param($Raiz)
                    $d = @(Get-RetoAce (_rp $Raiz 'Confidencial') | Where-Object { $_.Tipo -eq 'Deny' -and $_.Sid -eq (Get-RetoYo) })
                    if ($d.Count -eq 0) { return $true }
                    return 'Todavía hay una denegación sobre tu usuario en Confidencial.' }
                P = '`icacls Confidencial /remove:d $env:USERNAME` (en cmd `%USERNAME%`).'
                Ps = 'icacls Confidencial /remove:d $env:USERNAME'
                Cmd = 'icacls Confidencial /remove:d %USERNAME%'
            },
            @{
                T = 'Ahora sí: cuenta cuántos archivos hay en `Confidencial` (en todas las subcarpetas). Responde con el número.'
                Esperada = { param($Raiz) @(Get-ChildItem -LiteralPath (_rp $Raiz 'Confidencial') -Recurse -Force -File -ErrorAction SilentlyContinue).Count }
                P = 'Recursivo y solo archivos.'
                Ps = '(Get-ChildItem Confidencial -Recurse -File).Count'
                Cmd = 'dir /s /b /a-d Confidencial | find /c /v ""'
            },
            @{
                T = 'Crea `Recuperado` y copia dentro `contrato.txt`.'
                C = { param($Raiz)
                    $f = _rp $Raiz 'Recuperado\contrato.txt'
                    if (-not (Test-Path -LiteralPath $f)) { return 'No veo Recuperado\contrato.txt.' }
                    if ((Get-RetoLineas $f) -contains 'contrato secreto') { return $true }
                    return 'El contrato de Recuperado no tiene el contenido original.' }
                P = '`mkdir` y luego `copy`.'
                Ps = @'
mkdir Recuperado
Copy-Item Confidencial\contrato.txt Recuperado
'@
                Cmd = @'
mkdir Recuperado
copy Confidencial\contrato.txt Recuperado
'@
            }
        )
    }

    $b += @{
        Id = 'backup-seguro'; Nivel = 3; Titulo = 'Copia de seguridad con robocopy y registro'
        Intro = 'Las copias serias no se hacen con arrastrar y soltar. Vas a copiar el árbol de Datos con robocopy, guardar un registro, y dejar la copia protegida contra cambios.'
        Concepto = '`robocopy origen destino /E` copia carpetas con subcarpetas y es reanudable; `/LOG:archivo` guarda el registro. La copia se protege con solo lectura (`attrib +r /s`).'
        Inicio = ''
        Preparar = { param($Raiz)
            New-RetoArchivo (_rp $Raiz 'Datos\clientes.csv') "id,nombre`r`n1,ana`r`n"
            New-RetoArchivo (_rp $Raiz 'Datos\facturas\f001.txt') "factura 1`r`n"
            New-RetoArchivo (_rp $Raiz 'Datos\facturas\f002.txt') "factura 2`r`n"
            New-RetoArchivo (_rp $Raiz 'Datos\config\app.ini') "modo=prod`r`n"
        }
        Pasos = @(
            @{
                T = 'Copia `Datos` a `Backup\Datos` con **robocopy** (con subcarpetas, aunque estén vacías o no).'
                C = { param($Raiz)
                    $o = Get-RetoRelativos (_rp $Raiz 'Datos')
                    $c = Get-RetoRelativos (_rp $Raiz 'Backup\Datos')
                    if ($c.Count -eq 0) { return 'No encuentro Backup\Datos con archivos.' }
                    if (Test-RetoMismoConjunto $o $c) { return $true }
                    return "La copia tiene $($c.Count) archivos y el original $($o.Count)." }
                P = '`robocopy origen destino /E`. Si quieres saltarte robocopy, `Copy-Item -Recurse` también vale.'
                Ps = 'robocopy Datos Backup\Datos /E'
                Cmd = 'robocopy Datos Backup\Datos /E'
                Alt = 'Copy-Item Datos Backup\Datos -Recurse'
            },
            @{
                T = 'Vuelve a lanzar la copia guardando el registro en `backup.log`.'
                C = { param($Raiz)
                    $l = _rp $Raiz 'backup.log'
                    if (-not (Test-Path -LiteralPath $l)) { return 'No veo backup.log en tu carpeta de práctica.' }
                    if ((Get-Item -LiteralPath $l).Length -eq 0) { return 'backup.log está vacío.' }
                    return $true }
                P = '`/LOG:backup.log` (o `/LOG+:` para añadir).'
                Ps = 'robocopy Datos Backup\Datos /E /LOG:backup.log'
                Cmd = 'robocopy Datos Backup\Datos /E /LOG:backup.log'
                Alt = '"copia hecha" | Set-Content backup.log      (si no tienes robocopy)'
            },
            @{
                T = 'Protege la copia: pon **solo lectura** a todos los archivos de `Backup\Datos`.'
                C = { param($Raiz)
                    $f = @(Get-ChildItem -LiteralPath (_rp $Raiz 'Backup\Datos') -Recurse -Force -File)
                    if ($f.Count -eq 0) { return 'Backup\Datos está vacío.' }
                    $no = @($f | Where-Object { -not (Get-RetoAttr $_.FullName).ReadOnly })
                    if ($no.Count -eq 0) { return $true }
                    return "Faltan $($no.Count) archivos por proteger." }
                P = '`attrib +r` con `/s`.'
                Ps = 'attrib +r Backup\Datos\* /s'
                Cmd = 'attrib +r Backup\Datos\* /s'
            },
            @{
                T = 'Comprueba que la protección funciona: intenta borrar `Backup\Datos\clientes.csv` sin forzar. Responde con el resultado: ¿se ha borrado? (si/no)'
                Esperada = { param($Raiz) if (Test-Path -LiteralPath (_rp $Raiz 'Backup\Datos\clientes.csv')) { 'no' } else { 'si' } }
                Modo = 'bool'
                P = 'Sin `-Force` el borrado falla y el archivo sigue ahí.'
                Ps = 'Remove-Item Backup\Datos\clientes.csv'
                Cmd = 'del Backup\Datos\clientes.csv'
            },
            @{
                T = 'Verifica que el original no se ha tocado: cuenta los archivos de `Datos`. Responde con el número.'
                Esperada = { param($Raiz) @(Get-RetoRelativos (_rp $Raiz 'Datos')).Count }
                P = 'Recursivo y solo archivos.'
                Ps = '(Get-ChildItem Datos -Recurse -File).Count'
                Cmd = 'dir /s /b /a-d Datos | find /c /v ""'
            }
        )
    }

    return $b
}
