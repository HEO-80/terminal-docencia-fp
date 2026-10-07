# ================================================================= #
#        MOTOR COMÚN: REGISTRO DE FALLOS + REPASO ESPACIADO         #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).
#
# Sistema Leitner: cada reto/misión tiene una "caja" del 1 al 5.
#   - Fallar (solución / abandonar)      -> caja 1, vuelve en el próximo repaso
#   - Acertar con pista o con muchos fallos -> misma caja, vuelve pronto
#   - Acertar a la primera                -> sube de caja, tarda más en volver
# Intervalos por caja (días):  1=0   2=1   3=3   4=7   5=21
# El progreso se guarda en un JSON pequeño y NO lleva datos personales.

# Por si se carga este archivo suelto (sin el tema)
if (-not (Get-Command Write-Cyber -ErrorAction SilentlyContinue)) {
    function Write-Cyber {
        param([string]$Text, [string]$Color, [switch]$NoNewline)
        Write-Host $Text -NoNewline:$NoNewline
    }
}

$global:CyberIntervalosDias = @{ 1 = 0; 2 = 1; 3 = 3; 4 = 7; 5 = 21 }

# ── Almacén de progreso ───────────────────────────────────────────
function Get-CyberProgresoPath {
    if ($global:CyberProgresoPath) { return $global:CyberProgresoPath }
    $dir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "CyberProfile" } else { Join-Path $HOME ".cache/cyberprofile" }
    return (Join-Path $dir "progreso.json")
}

function ConvertTo-CyberFecha {
    param([string]$Texto)
    [datetime]::Parse($Texto, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
}

function Get-CyberProgreso {
    if ($null -ne $global:CyberProgreso) { return $global:CyberProgreso }

    $store = @{}
    $file  = Get-CyberProgresoPath
    if (Test-Path $file) {
        try {
            $json = Get-Content $file -Raw | ConvertFrom-Json
            foreach ($p in $json.PSObject.Properties) {
                # PowerShell 7 convierte las fechas ISO a DateTime al leer el JSON:
                # las devolvemos SIEMPRE a texto ISO (si no, dependen del idioma del sistema).
                $due = $p.Value.Due
                if ($due -is [datetime]) { $due = $due.ToUniversalTime().ToString('o') }
                $store[$p.Name] = @{
                    Caja      = [int]$p.Value.Caja
                    Due       = [string]$due
                    Aciertos  = [int]$p.Value.Aciertos
                    Fallos    = [int]$p.Value.Fallos
                    Ultima    = [string]$p.Value.Ultima
                    Etiqueta  = [string]$p.Value.Etiqueta
                }
            }
        } catch {
            Write-Cyber "  [!] No pude leer el progreso ($file). Empiezo en blanco." $global:CY.Dim
        }
    }
    $global:CyberProgreso = $store
    return $store
}

function Save-CyberProgreso {
    $file = Get-CyberProgresoPath
    try {
        New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
        (Get-CyberProgreso) | ConvertTo-Json -Depth 4 | Set-Content -Path $file -Encoding UTF8
    } catch {
        Write-Cyber "  [!] No pude guardar el progreso: $_" $global:CY.Dim
    }
}

function Get-CyberEntrada {
    param([string]$Id)
    $s = Get-CyberProgreso
    if ($s.ContainsKey($Id)) { return $s[$Id] }
    return $null
}

function Test-CyberDue {
    param([string]$Id)
    $e = Get-CyberEntrada $Id
    if (-not $e) { return $false }
    return ((ConvertTo-CyberFecha $e.Due) -le (Get-Date).ToUniversalTime())
}

function Get-CyberDueCount {
    $s = Get-CyberProgreso
    $ahora = (Get-Date).ToUniversalTime()
    $n = 0
    foreach ($k in $s.Keys) {
        if ((ConvertTo-CyberFecha $s[$k].Due) -le $ahora) { $n++ }
    }
    return $n
}

# Resultado: ok | pista | fail
function Register-CyberResultado {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][ValidateSet('ok','pista','fail')][string]$Resultado,
        [string]$Etiqueta = ""
    )
    $s   = Get-CyberProgreso
    $now = (Get-Date).ToUniversalTime()
    if (-not $s.ContainsKey($Id)) {
        $s[$Id] = @{ Caja = 1; Due = $now.ToString('o'); Aciertos = 0; Fallos = 0; Ultima = ''; Etiqueta = $Etiqueta }
    }
    $e = $s[$Id]
    if ($Etiqueta) { $e.Etiqueta = $Etiqueta }

    switch ($Resultado) {
        'ok' {
            $e.Aciertos++
            $e.Caja = [math]::Min($e.Caja + 1, 5)
            $e.Due  = $now.AddDays($global:CyberIntervalosDias[$e.Caja]).ToString('o')
        }
        'pista' {
            $e.Aciertos++
            $dias = [math]::Max(1, $global:CyberIntervalosDias[$e.Caja])
            $e.Due = $now.AddDays($dias).ToString('o')
        }
        'fail' {
            $e.Fallos++
            $e.Caja = 1
            $e.Due  = $now.ToString('o')
        }
    }
    $e.Ultima = $Resultado
    Save-CyberProgreso
    return $e
}

function Format-CyberProximo {
    param($Entrada)
    $due = ConvertTo-CyberFecha $Entrada.Due
    $dias = [math]::Round(($due - (Get-Date).ToUniversalTime()).TotalDays, 0)
    if ($dias -le 0) { return "en el próximo repaso" }
    if ($dias -eq 1) { return "mañana" }
    return "dentro de $dias días"
}

function Show-CyberStats {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([switch]$Reset)

    $c = $global:CY
    if (-not $c) { $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" } }

    if ($Reset) {
        if ($PSCmdlet.ShouldProcess((Get-CyberProgresoPath), "Borrar TODO el progreso")) {
            $global:CyberProgreso = @{}
            Remove-Item (Get-CyberProgresoPath) -Force -ErrorAction SilentlyContinue
            Write-Cyber "Progreso borrado." $c.Magenta
        }
        return
    }

    $s = Get-CyberProgreso
    if ($s.Count -eq 0) {
        Write-Cyber "Aún no hay progreso. Juega un 'dojo' o un 'tatami' primero." $c.Dim
        return
    }
    $ahora = (Get-Date).ToUniversalTime()

    Write-Host ""
    Write-Cyber "============================================================" $c.Magenta
    Write-Cyber "                  PROGRESO Y REPASO                         " $c.Green
    Write-Cyber "============================================================" $c.Magenta

    $grupos = $s.Keys | Group-Object { ($_ -split ':')[0] } | Sort-Object Name
    foreach ($g in $grupos) {
        $entradas   = @($g.Group | ForEach-Object { $s[$_] })
        $dominados  = @($entradas | Where-Object { $_.Caja -ge 4 }).Count
        $pendientes = @($entradas | Where-Object { (ConvertTo-CyberFecha $_.Due) -le $ahora }).Count
        $ac = ($entradas | Measure-Object Aciertos -Sum).Sum
        $fa = ($entradas | Measure-Object Fallos -Sum).Sum
        Write-Cyber "  $($g.Name.PadRight(10))" $c.Yellow -NoNewline
        Write-Cyber "vistos: $($entradas.Count)   dominados (caja 4-5): $dominados   pendientes hoy: $pendientes   aciertos/fallos: $ac/$fa" $c.Cyan
    }

    $peores = $s.Keys | Where-Object { $s[$_].Fallos -gt 0 } | Sort-Object { -$s[$_].Fallos } | Select-Object -First 5
    if ($peores) {
        Write-Host ""
        Write-Cyber "  Los que más se te resisten:" $c.Green
        foreach ($k in $peores) {
            $et = if ($s[$k].Etiqueta) { $s[$k].Etiqueta } else { $k }
            Write-Cyber "    $($s[$k].Fallos) fallos  -  $et" $c.Dim
        }
    }
    Write-Host ""
    Write-Cyber "  Repasa lo pendiente con:  dojo / dojo2 / tatami / tatami2 / forja / santuario / reto  y el parámetro  -Repaso" $c.Dim
    Write-Host ""
}

# ── Utilidades compartidas ────────────────────────────────────────
# Saca nombres de la salida de un comando (FileInfo, objetos con propiedad, strings)
function Get-CyberNombres {
    param($Salida, [string]$Prop = 'Name')
    @($Salida | Where-Object { $null -ne $_ } | ForEach-Object {
        if ($_ -is [System.IO.FileInfo]) { $_.Name }
        elseif ($_ -is [string]) { $_ }
        elseif ($_.PSObject.Properties[$Prop]) { $_.$Prop }
        else { "$_" }
    })
}

# ================================================================= #
#                         MOTOR DEL DOJO                            #
# ================================================================= #
$global:NombreMundo = @{
    Linux      = "terminal Linux (bash)"
    PowerShell = "PowerShell"
    Cmd        = "cmd (símbolo del sistema de Windows)"
}

function ConvertTo-DojoAcepta {
    param($Def)
    if ($Def -is [hashtable]) {
        $ok = @()
        if ($Def.Ej) { $ok += $Def.Ej }
        if ($Def.Ok) { $ok += @($Def.Ok) }
        $rx = if ($Def.Rx) { @($Def.Rx) } else { @() }
        return @{ Ej = $(if ($Def.Ej) { $Def.Ej } else { $ok[0] }); Ok = $ok; Rx = $rx }
    }
    $arr = @($Def)
    return @{ Ej = $arr[0]; Ok = $arr; Rx = @() }
}

# Normaliza: sin comillas, espacios colapsados, sin espacios a los lados
function ConvertTo-DojoNorm {
    param([string]$Texto)
    (($Texto -replace '["'']', '') -replace '\s+', ' ').Trim()
}

function Test-DojoRespuesta {
    param([string]$Intento, $Acepta)
    $n = ConvertTo-DojoNorm $Intento
    if (-not $n) { return $false }
    foreach ($ok in $Acepta.Ok) {
        if ($n -ieq (ConvertTo-DojoNorm $ok)) { return $true }
    }
    foreach ($rx in $Acepta.Rx) {
        if ($n -match $rx) { return $true }
    }
    return $false
}

function Get-DojoId {
    param($Reto)
    if ($Reto.Id) { return "$($Reto.Id)" }
    (("$($Reto.Tipo)-$($Reto.Tarea)").ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
}

function Invoke-DojoEngine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Banco,
        [Parameter(Mandatory)][string]$Prefijo,
        [string]$Titulo = "CYBER-DOJO",
        [int]$Preguntas = 5,
        [string]$Modo = 'Mix',
        [switch]$Repaso
    )

    $c = $global:CY
    if (-not $c) { $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" } }

    # Pares (reto, mundo) posibles según el modo
    $pares = @()
    foreach ($r in @($Banco)) {
        $mundos = if ($Modo -eq 'Mix') { @($r.R.Keys) } elseif ($r.R.ContainsKey($Modo)) { @($Modo) } else { @() }
        foreach ($m in $mundos) {
            $rid = Get-DojoId $r
            $pares += [pscustomobject]@{ Reto = $r; Mundo = $m; RetoId = $rid; Id = "${Prefijo}:${rid}|${m}" }
        }
    }
    if ($pares.Count -eq 0) {
        Write-Cyber "No hay retos para ese modo." $c.Magenta
        return
    }

    # Selección: primero lo pendiente de repaso (más antiguo antes),
    # luego retos nuevos; nunca la misma tarea dos veces en una sesión.
    $due = @($pares | Where-Object { Test-CyberDue $_.Id } |
             Sort-Object { ConvertTo-CyberFecha (Get-CyberEntrada $_.Id).Due })

    if ($Repaso -and $due.Count -eq 0) {
        Write-Cyber "Nada pendiente de repaso en $Prefijo. ¡Bien!  (prueba 'progreso' para ver tu estado)" $c.Green
        return
    }

    $elegidos = New-Object System.Collections.ArrayList
    $usados   = New-Object 'System.Collections.Generic.HashSet[string]'
    $limite   = [math]::Min($Preguntas, @($pares | Select-Object -ExpandProperty RetoId -Unique).Count)

    foreach ($p in $due) {
        if ($elegidos.Count -ge $limite) { break }
        if ($usados.Add($p.RetoId)) { [void]$elegidos.Add($p) }
    }
    if (-not $Repaso) {
        $nuevos = @($pares | Where-Object { -not (Get-CyberEntrada $_.Id) } | Get-Random -Count ([math]::Max(1, $pares.Count)))
        foreach ($p in $nuevos) {
            if ($elegidos.Count -ge $limite) { break }
            if ($usados.Add($p.RetoId)) { [void]$elegidos.Add($p) }
        }
        if ($elegidos.Count -lt $limite) {
            $resto = @($pares | Get-Random -Count $pares.Count)
            foreach ($p in $resto) {
                if ($elegidos.Count -ge $limite) { break }
                if ($usados.Add($p.RetoId)) { [void]$elegidos.Add($p) }
            }
        }
    }

    $total  = $elegidos.Count
    $puntos = 0

    Write-Host ""
    Write-Cyber "============================================================" $c.Magenta
    Write-Cyber "  $Titulo" $c.Green
    Write-Cyber "============================================================" $c.Magenta
    $modoTxt = if ($Repaso) { "REPASO" } else { $Modo }
    Write-Cyber "Modo: $modoTxt   |   Preguntas: $total   |   Pendientes de repaso: $($due.Count)" $c.Dim
    Write-Cyber "Escribe 'pista', 'solucion' para pasar, o 'salir' para terminar." $c.Dim
    Write-Host ""

    $abandonar = $false
    foreach ($par in $elegidos) {
        if ($abandonar) { break }

        $reto   = $par.Reto
        $acepta = ConvertTo-DojoAcepta $reto.R[$par.Mundo]
        $ej     = "$($acepta.Ej)"
        $etiq   = "$($reto.Tarea)  [$($par.Mundo)]"
        $marca  = if (Test-CyberDue $par.Id) { "  (repaso)" } else { "" }

        Write-Cyber "[$($reto.Tipo)]  -  en $($global:NombreMundo[$par.Mundo])$marca" $c.Cyan
        Write-Cyber "$($reto.Tarea)" $c.Yellow

        $resuelto = $false
        $fallosReto = 0
        $usoPista   = $false
        while (-not $resuelto) {
            $intento = (Read-Host "❯ Respuesta").Trim()

            if ($intento -eq "salir") {
                $abandonar = $true
                $resuelto  = $true
            }
            elseif ($intento -eq "pista") {
                $usoPista = $true
                if ($ej -match '\s') {
                    Write-Cyber "  💡 Pista: el comando principal empieza por '$(($ej -split '\s+')[0])'." $c.Cyan
                } else {
                    Write-Cyber "  💡 Pista: empieza por '$($ej.Substring(0,1))' y tiene $($ej.Length) caracteres." $c.Cyan
                }
            }
            elseif ($intento -eq "solucion") {
                Write-Cyber "  ⚡ Solución: $ej" $c.Magenta
                if ($reto.Exp) { Write-Cyber "  ℹ️  $($reto.Exp)" $c.Dim }
                $e = Register-CyberResultado -Id $par.Id -Resultado fail -Etiqueta $etiq
                Write-Cyber "  ↻ Te lo volveré a preguntar $(Format-CyberProximo $e)." $c.Dim
                $resuelto = $true
            }
            elseif (Test-DojoRespuesta $intento $acepta) {
                $puntos++
                $res = if ($usoPista -or $fallosReto -ge 2) { 'pista' } else { 'ok' }
                $e   = Register-CyberResultado -Id $par.Id -Resultado $res -Etiqueta $etiq
                Write-Cyber "  ✔ ¡CORRECTO!" $c.Green
                if ($reto.Exp) { Write-Cyber "  ℹ️  $($reto.Exp)" $c.Dim }
                Write-Cyber "  ↻ Próximo repaso: $(Format-CyberProximo $e)  (caja $($e.Caja)/5)" $c.Dim
                $resuelto = $true
            }
            else {
                $fallosReto++
                Write-Cyber "  ✘ Incorrecto. Prueba de nuevo, pide 'pista' o escribe 'solucion'." $c.Magenta
            }
        }
        Write-Host ""
    }

    Write-Cyber "Sesión terminada: $puntos/$total aciertos." $c.Green
    Write-Cyber "============================================================" $c.Magenta
    Write-Host ""
}

# ================================================================= #
#                        MOTOR DEL TATAMI                           #
# ================================================================= #
function Invoke-TatamiEngine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Misiones,
        [Parameter(Mandatory)][string]$Prefijo,
        [string]$Titulo = "TATAMI",
        [switch]$Repaso
    )

    $c = $global:CY
    if (-not $c) { $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" } }

    $pool = @(@($Misiones) | ForEach-Object {
        [pscustomobject]@{ M = $_; Id = "${Prefijo}:$($_.Id)" }
    })

    # Elección: pendiente de repaso > nueva > la de caja más baja
    $due = @($pool | Where-Object { Test-CyberDue $_.Id } |
             Sort-Object { ConvertTo-CyberFecha (Get-CyberEntrada $_.Id).Due })

    if ($Repaso -and $due.Count -eq 0) {
        Write-Cyber "Nada pendiente de repaso en $Prefijo. ¡Bien!  (prueba 'progreso' para ver tu estado)" $c.Green
        return
    }

    if ($due.Count -gt 0) {
        $sel = $due[0]
    } else {
        $nuevas = @($pool | Where-Object { -not (Get-CyberEntrada $_.Id) })
        if ($nuevas.Count -gt 0) {
            $sel = $nuevas | Get-Random
        } else {
            $minCaja = ($pool | ForEach-Object { (Get-CyberEntrada $_.Id).Caja } | Measure-Object -Minimum).Minimum
            $sel = @($pool | Where-Object { (Get-CyberEntrada $_.Id).Caja -eq $minCaja }) | Get-Random
        }
    }
    $mision   = $sel.M
    $misionId = $sel.Id
    $esRepaso = Test-CyberDue $misionId

    # Sandbox aislado temporal (multiplataforma)
    $sandboxPath = Join-Path ([System.IO.Path]::GetTempPath()) "${Prefijo}_Sandbox"
    if (Test-Path $sandboxPath) { Remove-Item $sandboxPath -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $sandboxPath -Force | Out-Null

    $dirAnterior = Get-Location
    $resultado   = $null   # ok | pista | fail

    # try/finally: la carpeta se restaura y el sandbox se borra SIEMPRE (Ctrl+C incluido)
    try {
        Set-Location $sandboxPath

        Write-Host ""
        Write-Cyber "============================================================" $c.Magenta
        Write-Cyber "  $Titulo" $c.Green
        Write-Cyber "============================================================" $c.Magenta
        $marca = if ($esRepaso) { "   (REPASO)" } else { "" }
        Write-Cyber "Misión:   $($mision.Titulo)$marca" $c.Yellow
        Write-Cyber "Objetivo: " $c.Yellow -NoNewline
        Write-Cyber $mision.Objetivo $c.Cyan
        Write-Cyber "Sandbox temporal: $sandboxPath" $c.Dim
        Write-Cyber "Comandos de control: 'pista', 'solucion' o 'salir'." $c.Dim
        Write-Host ""

        & $mision.Setup

        $completada = $false
        $usoPista   = $false
        $intentosMal = 0
        while (-not $completada) {
            $inputCmd = (Read-Host "TATAMI ❯").Trim()

            if ($inputCmd -eq "salir") {
                Write-Cyber "Abandonando tatami..." $c.Magenta
                # Salir sin haberlo intentado no cuenta como fallo
                $resultado = if ($intentosMal -gt 0 -or $usoPista) { 'fail' } else { $null }
                break
            }
            elseif ($inputCmd -eq "pista") {
                $usoPista = $true
                Write-Cyber "💡 Pista: $($mision.Pista)" $c.Cyan
                continue
            }
            elseif ($inputCmd -eq "solucion") {
                Write-Cyber "⚡ Solución esperada: $($mision.Ejemplo)" $c.Magenta
                $resultado = 'fail'
                break
            }
            elseif ([string]::IsNullOrWhiteSpace($inputCmd)) {
                continue
            }

            # Protección: nada de salir del sandbox (rutas absolutas, .., ~, cd...)
            if ($inputCmd -match '[A-Za-z]:[\\/]|\.\.|~|\$HOME|\$env:|Set-Location|\bcd\b|\bsl\b') {
                Write-Cyber "✘ Tatami solo permite comandos dentro del sandbox (sin rutas absolutas, '..' ni cd)." $c.Magenta
                continue
            }

            try {
                $salida = Invoke-Expression $inputCmd
                if ($salida) { $salida | Out-Host }
            } catch {
                Write-Cyber "Error de sintaxis: $_" $c.Magenta
                $intentosMal++
                continue
            }

            # Sin nulos: un comando sin salida llega como array vacío
            $salidaVal = @($salida | Where-Object { $null -ne $_ })
            $exito = $false
            try { $exito = [bool](& $mision.Validar $inputCmd $salidaVal) }
            catch { Write-Cyber "  (no pude validar la salida: $($_.Exception.Message))" $c.Dim }

            if ($exito) {
                Write-Host ""
                Write-Cyber "✔ ¡EJECUCIÓN CORRECTA! Desafío superado." $c.Green
                $completada = $true
                $resultado  = if ($usoPista -or $intentosMal -ge 3) { 'pista' } else { 'ok' }
            } else {
                $intentosMal++
                Write-Cyber "✘ Comando ejecutado, pero no cumple la condición requerida. Intenta otra vez." $c.Magenta
            }
        }
    }
    finally {
        Set-Location $dirAnterior
        Remove-Item $sandboxPath -Recurse -Force -ErrorAction SilentlyContinue

        if ($resultado) {
            $e = Register-CyberResultado -Id $misionId -Resultado $resultado -Etiqueta $mision.Titulo
            if ($resultado -eq 'fail') {
                Write-Cyber "↻ Te la volveré a poner $(Format-CyberProximo $e)." $c.Dim
            } else {
                Write-Cyber "↻ Próximo repaso: $(Format-CyberProximo $e)  (caja $($e.Caja)/5)" $c.Dim
            }
        }
        Write-Host ""
        Write-Cyber "============================================================" $c.Magenta
        Write-Host ""
    }
}

Set-Alias progreso Show-CyberStats
Set-Alias stats    Show-CyberStats
