# ================================================================= #
#          FORJA: APRENDE A ESCRIBIR SCRIPTS (PowerShell)            #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).
#
# Cómo funciona:
#   1. `forja` te da una misión y abre un archivo de plantilla en tu editor.
#   2. Escribes tu función/script y guardas.
#   3. Vuelves a la terminal y pulsas Enter (o escribes 'probar'): Forja
#      ejecuta tu código en un entorno aislado contra varios casos de
#      prueba y te dice cuáles pasan y cuáles no.
#   4. Los fallos entran en el mismo repaso espaciado que Dojo y Tatami.
#
# No se compara tu código con una solución: se comprueba que HACE lo que
# debe con las entradas de prueba (hay mil formas correctas de resolverlo).
# Las misiones que tocan servicios usan simulaciones (mocks): nunca se
# para un servicio real.
#
# El motor de tests está separado de las misiones (Invoke-ForjaTests recibe
# el runner), para poder reutilizarlo en Santuario (bash vía WSL).

# Por si se carga este archivo suelto (sin el tema)
if (-not (Get-Command Write-Cyber -ErrorAction SilentlyContinue)) {
    function Write-Cyber {
        param([string]$Text, [string]$Color, [switch]$NoNewline)
        Write-Host $Text -NoNewline:$NoNewline
    }
}

# ================================================================= #
#                       MOTOR DE PRUEBAS                            #
# ================================================================= #

# Código que se ejecuta DENTRO del runspace aislado. Recibe las variables
# File, Sandbox y Tests. Devuelve un JSON con el resultado de cada caso.
$script:ForjaRunner = @'
$out = New-Object System.Collections.ArrayList

function Format-Obt($v) {
    $items = @($v | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) { return '(sin salida)' }
    $prim = $true
    foreach ($i in $items) { if (-not (($i -is [string]) -or ($i -is [ValueType]))) { $prim = $false } }
    if ($prim) { $s = ($items | ForEach-Object { "$_" }) -join ', ' }
    else { $s = ($items | Out-String).Trim() }
    if ($s.Length -gt 160) { $s = $s.Substring(0, 160) + '...' }
    return $s
}

Set-Location -Path $Sandbox
[Environment]::CurrentDirectory = $Sandbox
$ScriptPath = $File

$loadErr = $null
$tok = $null; $perr = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$tok, [ref]$perr)
if ($perr -and $perr.Count -gt 0) {
    $loadErr = (@($perr | Select-Object -First 3 | ForEach-Object { "línea $($_.Extent.StartLineNumber): $($_.Message)" })) -join ' | '
}
else {
    try { . $File | Out-Null } catch { $loadErr = $_.Exception.Message }
}
if ($loadErr) {
    [void]$out.Add(@{ Nombre = 'Cargar tu script'; Ok = $false; Esperado = 'que compile y se cargue sin errores'; Obtenido = "Error al cargar: $loadErr" })
    ConvertTo-Json -InputObject @($out) -Compress -Depth 4
    return
}

foreach ($t in $Tests) {
    Get-ChildItem -Path $Sandbox -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $r = $null; $thrown = $false; $errMsg = ''
    try {
        if ($t.Prep) { . ([scriptblock]::Create($t.Prep)) | Out-Null }
        $r = & ([scriptblock]::Create($t.Run))
    } catch {
        $thrown = $true
        $errMsg = $_.Exception.Message
    }

    $ok  = $false
    $obt = ''
    if ($thrown) {
        if ($t.ExpectError) { $ok = $true; $obt = "lanzó un error (correcto): $errMsg" }
        else { $obt = "ERROR: $errMsg" }
    }
    elseif ($t.ExpectError) {
        $obt = 'no lanzó ningún error; devolvió: ' + (Format-Obt $r)
    }
    else {
        $obt = Format-Obt $r
        if ($t.Check) {
            try { $ok = [bool](& ([scriptblock]::Create($t.Check)) $r) }
            catch { $ok = $false; $obt += " (no pude comprobarlo: $($_.Exception.Message))" }
        }
        else {
            $a = (@($r | Where-Object { $null -ne $_ }) | ForEach-Object { "$_" }) -join ','
            $b = (@($t.Esperado) | ForEach-Object { "$_" }) -join ','
            $ok = ($a -ceq $b)
        }
    }

    if ($t.ExpectError) { $esp = 'un error (el valor no es válido)' }
    elseif ($t.Desc)    { $esp = "$($t.Desc)" }
    else {
        $esp = (@($t.Esperado) | ForEach-Object { "$_" }) -join ', '
        if ($esp -eq '') { $esp = '(sin salida)' }
    }

    [void]$out.Add(@{ Nombre = $t.Nombre; Ok = $ok; Esperado = $esp; Obtenido = $obt })
}
ConvertTo-Json -InputObject @($out) -Compress -Depth 4
'@

function Get-ForjaWorkspace {
    $dir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "CyberProfile\forja" } else { Join-Path $HOME ".cache/cyberprofile/forja" }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

# Ejecuta tu archivo contra los casos de la misión. Devuelve:
#   @{ Resultados = <lista>; Aviso = <texto o vacío> }
function Invoke-ForjaTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Mision,
        [Parameter(Mandatory)][string]$File,
        [int]$TimeoutSec = 20
    )

    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) "Forja_Sandbox"
    $cwdAntes = [Environment]::CurrentDirectory
    $rs = $null; $ps = $null
    $aviso = ''
    $resultados = @()

    try {
        if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $sandbox -Force | Out-Null

        $tests = @($Mision.Tests | ForEach-Object {
            @{
                Nombre      = $_.Nombre
                Prep        = $(if ($_.Prep)  { $_.Prep.ToString() }  else { '' })
                Run         = $_.Run.ToString()
                Check       = $(if ($_.Check) { $_.Check.ToString() } else { '' })
                Esperado    = $_.Esperado
                ExpectError = [bool]$_.ExpectError
                Desc        = $_.Desc
            }
        })

        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('File', $File)
        $rs.SessionStateProxy.SetVariable('Sandbox', $sandbox)
        $rs.SessionStateProxy.SetVariable('Tests', $tests)

        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript($script:ForjaRunner)
        $async = $ps.BeginInvoke()

        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutSec * 1000)) {
            $ps.Stop()
            $aviso = "Tiempo agotado ($TimeoutSec s): tu código no termina. ¿Bucle infinito o esperando entrada (Read-Host)?"
        }
        else {
            $res  = $ps.EndInvoke($async)
            $json = @($res | ForEach-Object { "$_" }) | Select-Object -Last 1
            if ($json) {
                $resultados = @($json | ConvertFrom-Json | ForEach-Object { $_ })
            } else {
                $aviso = "No obtuve resultados. Errores internos: $(@($ps.Streams.Error | ForEach-Object { "$_" }) -join ' | ')"
            }
        }
    }
    catch {
        $aviso = "Error interno al probar: $($_.Exception.Message)"
    }
    finally {
        try { if ($ps) { $ps.Dispose() } } catch {}
        try { if ($rs) { $rs.Dispose() } } catch {}
        try { [Environment]::CurrentDirectory = $cwdAntes } catch {}
        Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }

    return @{ Resultados = $resultados; Aviso = $aviso }
}

function Open-ForjaEditor {
    param([string]$File)
    try {
        if ($env:FORJA_EDITOR) { & $env:FORJA_EDITOR $File; return $true }
        if (Get-Command code -ErrorAction SilentlyContinue) { & code $File; return $true }
        if ($env:OS -eq 'Windows_NT') { Start-Process notepad $File; return $true }
    } catch {}
    return $false
}

function Show-ForjaResultados {
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
        }
    }
    return $bien
}

# ================================================================= #
#                    BUCLE COMÚN DE UNA MISIÓN                      #
# ================================================================= #
function Invoke-ForjaMision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Mision,
        [Parameter(Mandatory)][string]$MisionId,
        [string]$Titulo = 'FORJA',
        [switch]$SinEditor,
        [switch]$Continuar
    )

    $c = $global:CY
    if (-not $c) { $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" } }

    $ws   = Get-ForjaWorkspace
    $file = Join-Path $ws "$($Mision.Id).ps1"
    $plantilla = ($Mision.Plantilla -replace "`r`n", "`n").TrimEnd() + "`n"

    if ((Test-Path $file) -and $Continuar) {
        $nota = "Continuando con tu código anterior."
    } else {
        if (Test-Path $file) { Copy-Item $file (Join-Path $ws "$($Mision.Id).prev.ps1") -Force }
        Set-Content -Path $file -Value $plantilla -Encoding UTF8
        $nota = ""
    }

    $esRepaso = Test-CyberDue $MisionId
    $marca = if ($esRepaso) { "   (REPASO)" } else { "" }

    Write-Host ""
    Write-Cyber "============================================================" $c.Magenta
    Write-Cyber "  $Titulo" $c.Green
    Write-Cyber "============================================================" $c.Magenta
    Write-Cyber "Misión [nivel $($Mision.Nivel)]: $($Mision.Titulo)$marca" $c.Yellow
    Write-Host ""
    Write-Cyber $Mision.Enunciado $c.Cyan
    Write-Host ""
    Write-Cyber "Tu archivo: $file" $c.Dim
    if ($nota) { Write-Cyber $nota $c.Dim }
    Write-Cyber "Casos de prueba: $(@($Mision.Tests).Count)   |   Enter o 'probar' = ejecutar   |   'pista', 'ver', 'editar', 'plantilla', 'solucion', 'salir'" $c.Dim
    Write-Host ""

    if (-not $SinEditor) {
        if (-not (Open-ForjaEditor $file)) {
            Write-Cyber "No pude abrir un editor. Abre ese archivo con el tuyo (o define `$env:FORJA_EDITOR)." $c.Dim
        }
    }

    $resultado  = $null     # ok | pista | fail
    $usoPista   = $false
    $intentos   = 0
    $superada   = $false

    while (-not $superada) {
        $cmd = (Read-Host "FORJA ❯").Trim()

        if ($cmd -eq 'salir') {
            Write-Cyber "Saliendo de la forja... (tu código queda en el archivo; 'forja -Id $($Mision.Id) -Continuar' para seguir)" $c.Magenta
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
            if (-not (Open-ForjaEditor $file)) { Write-Cyber "Abre a mano: $file" $c.Dim }
            continue
        }
        elseif ($cmd -eq 'plantilla') {
            Copy-Item $file (Join-Path $ws "$($Mision.Id).prev.ps1") -Force
            Set-Content -Path $file -Value $plantilla -Encoding UTF8
            Write-Cyber "Plantilla restaurada (tu versión anterior está en $($Mision.Id).prev.ps1)." $c.Dim
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
        Write-Cyber "  Ejecutando tu código en el entorno aislado..." $c.Dim
        $res  = Invoke-ForjaTests -Mision $Mision -File $file
        $bien = Show-ForjaResultados $res
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
#                     BANCO DE MISIONES (PowerShell)                #
# ================================================================= #
function Get-ForjaMisiones {
    @(
        # ───────────────────────── NIVEL 1 ─────────────────────────
        @{
            Id = 'saludo'; Nivel = 1; Titulo = "Tu primera función: un saludo"
            Enunciado = @"
Escribe una función llamada Get-Saludo que reciba un parámetro -Nombre y
DEVUELVA el texto:  Hola, <Nombre>!
Ejemplo:  Get-Saludo -Nombre 'Ana'   ->   Hola, Ana!
"@
            Plantilla = @'
# Misión: una función que devuelve un saludo
function Get-Saludo {
    param(
        [string]$Nombre
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "Saluda a Ana";    Run = { Get-Saludo -Nombre 'Ana' };    Esperado = 'Hola, Ana!' }
                @{ Nombre = "Saluda a Hector"; Run = { Get-Saludo -Nombre 'Hector' }; Esperado = 'Hola, Hector!' }
            )
            Pista = "Lo que una función deja en la salida es su resultado (no hace falta 'return'). Usa comillas dobles para que se sustituya la variable: `"Hola, `$Nombre!`""
            Solucion = @'
function Get-Saludo {
    param(
        [string]$Nombre
    )
    "Hola, $Nombre!"
}
'@
            Concepto = "Comillas dobles interpolan variables; una función devuelve todo lo que 'sale' por la salida, sin necesidad de return."
        },
        @{
            Id = 'par-impar'; Nivel = 1; Titulo = "¿Par o impar? (operador módulo)"
            Enunciado = @"
Escribe Test-EsPar, con un parámetro [int]`$Numero, que devuelva `$true si el
número es par y `$false si es impar.
Ejemplo:  Test-EsPar -Numero 4   ->   True
"@
            Plantilla = @'
# Misión: decidir si un número es par
function Test-EsPar {
    param(
        [int]$Numero
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "4 es par";       Run = { Test-EsPar -Numero 4 };  Esperado = $true }
                @{ Nombre = "7 es impar";     Run = { Test-EsPar -Numero 7 };  Esperado = $false }
                @{ Nombre = "0 es par";       Run = { Test-EsPar -Numero 0 };  Esperado = $true }
                @{ Nombre = "-2 es par";      Run = { Test-EsPar -Numero -2 }; Esperado = $true }
            )
            Pista = "El operador % devuelve el resto de una división. Un número es par si su resto entre 2 es 0. Una comparación (-eq) ya devuelve `$true o `$false."
            Solucion = @'
function Test-EsPar {
    param(
        [int]$Numero
    )
    $Numero % 2 -eq 0
}
'@
            Concepto = "% es el resto de la división; las comparaciones (-eq, -gt...) devuelven booleanos que puedes devolver directamente."
        },
        @{
            Id = 'suma-lista'; Nivel = 1; Titulo = "Sumar una lista (bucle foreach)"
            Enunciado = @"
Escribe Get-Suma, con un parámetro [int[]]`$Numeros, que devuelva la suma de
todos los números recorriéndolos con un bucle foreach.
Una lista vacía debe dar 0 (no 'nada').
Ejemplo:  Get-Suma -Numeros 1,2,3   ->   6
"@
            Plantilla = @'
# Misión: sumar los números de una lista con foreach
function Get-Suma {
    param(
        [int[]]$Numeros
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "1+2+3";             Run = { Get-Suma -Numeros 1,2,3 };      Esperado = 6 }
                @{ Nombre = "lista vacía = 0";   Run = { Get-Suma -Numeros @() };        Esperado = 0 }
                @{ Nombre = "con negativos";     Run = { Get-Suma -Numeros -1,1,10 };    Esperado = 10 }
            )
            Pista = "Crea una variable acumuladora empezando en 0 (`$total = 0), súmale cada número dentro del foreach (`$total += `$n) y al final deja `$total en la salida."
            Solucion = @'
function Get-Suma {
    param(
        [int[]]$Numeros
    )
    $total = 0
    foreach ($n in $Numeros) {
        $total += $n
    }
    $total
}
'@
            Concepto = "Patrón acumulador: inicializar, recorrer y devolver. Inicializar en 0 evita devolver 'nada' cuando la lista está vacía."
        },
        @{
            Id = 'fizzbuzz'; Nivel = 1; Titulo = "FizzBuzz (bucles + condicionales)"
            Enunciado = @"
Escribe Get-FizzBuzz con un parámetro [int]`$Hasta. Debe devolver, del 1 al
`$Hasta, un elemento por número:
  - 'FizzBuzz' si es múltiplo de 3 y de 5
  - 'Fizz'     si es múltiplo de 3
  - 'Buzz'     si es múltiplo de 5
  - el propio número en cualquier otro caso
Ejemplo:  Get-FizzBuzz -Hasta 5   ->   1, 2, Fizz, 4, Buzz
"@
            Plantilla = @'
# Misión: FizzBuzz
function Get-FizzBuzz {
    param(
        [int]$Hasta
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "hasta 5";  Run = { Get-FizzBuzz -Hasta 5 };  Esperado = @('1','2','Fizz','4','Buzz') }
                @{ Nombre = "hasta 15"; Run = { Get-FizzBuzz -Hasta 15 }; Esperado = @('1','2','Fizz','4','Buzz','Fizz','7','8','Fizz','Buzz','11','Fizz','13','14','FizzBuzz') }
                @{ Nombre = "hasta 1";  Run = { Get-FizzBuzz -Hasta 1 };  Esperado = @('1') }
            )
            Pista = "Recorre 1..`$Hasta. El orden de las condiciones importa: comprueba primero el caso 'múltiplo de 3 Y de 5' (o `$i % 15 -eq 0)."
            Solucion = @'
function Get-FizzBuzz {
    param(
        [int]$Hasta
    )
    foreach ($i in 1..$Hasta) {
        if     ($i % 15 -eq 0) { 'FizzBuzz' }
        elseif ($i % 3  -eq 0) { 'Fizz' }
        elseif ($i % 5  -eq 0) { 'Buzz' }
        else                   { $i }
    }
}
'@
            Concepto = "if / elseif / else con el caso más específico primero. 1..N genera el rango y foreach lo recorre."
        },
        @{
            Id = 'contar-errores'; Nivel = 1; Titulo = "Contar errores en un log"
            Enunciado = @"
Escribe Get-CantidadErrores con un parámetro [string]`$Ruta (un archivo de log).
Debe devolver CUÁNTAS líneas contienen la palabra ERROR.
Un log sin errores, o vacío, debe dar 0.
"@
            Plantilla = @'
# Misión: contar líneas con ERROR en un log
function Get-CantidadErrores {
    param(
        [string]$Ruta
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "log con 3 errores"
                   Prep = { $script:log = Join-Path $Sandbox 'app.log'; @('INFO arranque','ERROR disco','INFO ok','ERROR red','WARN lento','ERROR db') | Set-Content -Path $script:log }
                   Run  = { Get-CantidadErrores -Ruta $script:log }; Esperado = 3 }
                @{ Nombre = "log vacío"
                   Prep = { $script:log = Join-Path $Sandbox 'vacio.log'; New-Item -ItemType File -Path $script:log | Out-Null }
                   Run  = { Get-CantidadErrores -Ruta $script:log }; Esperado = 0 }
                @{ Nombre = "log sin errores"
                   Prep = { $script:log = Join-Path $Sandbox 'ok.log'; @('INFO a','INFO b') | Set-Content -Path $script:log }
                   Run  = { Get-CantidadErrores -Ruta $script:log }; Esperado = 0 }
            )
            Pista = "Get-Content lee las líneas; Where-Object { `$_ -match 'ERROR' } las filtra; envuélvelo en @( ... ) y usa .Count para contar."
            Solucion = @'
function Get-CantidadErrores {
    param(
        [string]$Ruta
    )
    @(Get-Content -Path $Ruta | Where-Object { $_ -match 'ERROR' }).Count
}
'@
            Concepto = "Get-Content | Where-Object | .Count. Envolver en @() garantiza que sea un array aunque haya 0 o 1 resultados."
        },
        @{
            Id = 'archivos-grandes'; Nivel = 1; Titulo = "Archivos por encima de un tamaño"
            Enunciado = @"
Escribe Get-ArchivosGrandes con los parámetros [string]`$Carpeta y [int]`$MinKB.
Debe devolver SOLO LOS NOMBRES (texto) de los archivos de esa carpeta cuyo
tamaño sea ESTRICTAMENTE MAYOR que MinKB kilobytes (uno de exactamente
MinKB KB NO cuenta), ordenados alfabéticamente.
Si no hay ninguno, no devuelve nada.
"@
            Plantilla = @'
# Misión: archivos más grandes que N KB
function Get-ArchivosGrandes {
    param(
        [string]$Carpeta,
        [int]$MinKB
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "mayores de 10 KB"
                   Prep = { foreach ($k in @{ 'a.bin' = 5; 'b.bin' = 40; 'c.bin' = 12; 'd.bin' = 90; 'e.bin' = 10 }.GetEnumerator()) { [System.IO.File]::WriteAllBytes((Join-Path $Sandbox $k.Key), (New-Object byte[] ($k.Value * 1024))) } }
                   Run  = { Get-ArchivosGrandes -Carpeta $Sandbox -MinKB 10 }; Esperado = @('b.bin','c.bin','d.bin') }
                @{ Nombre = "mayores de 50 KB"
                   Prep = { foreach ($k in @{ 'a.bin' = 5; 'b.bin' = 40; 'c.bin' = 12; 'd.bin' = 90; 'e.bin' = 10 }.GetEnumerator()) { [System.IO.File]::WriteAllBytes((Join-Path $Sandbox $k.Key), (New-Object byte[] ($k.Value * 1024))) } }
                   Run  = { Get-ArchivosGrandes -Carpeta $Sandbox -MinKB 50 }; Esperado = @('d.bin') }
                @{ Nombre = "ninguno supera 100 KB"
                   Prep = { [System.IO.File]::WriteAllBytes((Join-Path $Sandbox 'a.bin'), (New-Object byte[] (5 * 1024))) }
                   Run  = { Get-ArchivosGrandes -Carpeta $Sandbox -MinKB 100 }; Esperado = @() }
            )
            Pista = "Get-ChildItem -File da los archivos; en Where-Object compara `$_.Length -gt (`$MinKB * 1KB); ordena con Sort-Object Name y quédate con el texto usando Select-Object -ExpandProperty Name."
            Solucion = @'
function Get-ArchivosGrandes {
    param(
        [string]$Carpeta,
        [int]$MinKB
    )
    Get-ChildItem -Path $Carpeta -File |
        Where-Object { $_.Length -gt ($MinKB * 1KB) } |
        Sort-Object Name |
        Select-Object -ExpandProperty Name
}
'@
            Concepto = "Pipeline completo: obtener, filtrar, ordenar, proyectar. -ExpandProperty devuelve el valor (texto) en vez de un objeto con una propiedad."
        },

        # ───────────────────────── NIVEL 2 ─────────────────────────
        @{
            Id = 'validar-puerto'; Nivel = 2; Titulo = "Validar parámetros (ValidateRange)"
            Enunciado = @"
Escribe Set-PuertoServicio con un parámetro [int]`$Puerto que SOLO acepte
valores de 1 a 65535 (la propia función debe rechazar el resto con un error,
sin que tú escribas un if).
Si es válido, devuelve el texto:  Puerto <n> configurado
Ejemplo:  Set-PuertoServicio -Puerto 22   ->   Puerto 22 configurado
"@
            Plantilla = @'
# Misión: aceptar solo puertos válidos
function Set-PuertoServicio {
    param(
        [int]$Puerto
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "puerto 22";        Run = { Set-PuertoServicio -Puerto 22 };    Esperado = 'Puerto 22 configurado' }
                @{ Nombre = "puerto 65535";     Run = { Set-PuertoServicio -Puerto 65535 }; Esperado = 'Puerto 65535 configurado' }
                @{ Nombre = "puerto 0 rechazado";     Run = { Set-PuertoServicio -Puerto 0 };     ExpectError = $true }
                @{ Nombre = "puerto 70000 rechazado"; Run = { Set-PuertoServicio -Puerto 70000 }; ExpectError = $true }
            )
            Pista = "Los atributos de validación van encima del parámetro: [ValidateRange(1,65535)][int]`$Puerto"
            Solucion = @'
function Set-PuertoServicio {
    param(
        [ValidateRange(1,65535)]
        [int]$Puerto
    )
    "Puerto $Puerto configurado"
}
'@
            Concepto = "Los atributos [Validate...] rechazan valores inválidos antes de que entre tu código: menos ifs y mensajes de error consistentes."
        },
        @{
            Id = 'objeto-usuario'; Nivel = 2; Titulo = "Devolver objetos, no texto"
            Enunciado = @"
Escribe New-Usuario con los parámetros -Nombre y -Rol (por defecto 'usuario').
Debe DEVOLVER UN OBJETO (no un texto) con tres propiedades:
  Nombre, Rol y Activo (siempre `$true).
Así luego se podrá filtrar:  New-Usuario -Nombre ana | Where-Object Activo
"@
            Plantilla = @'
# Misión: crear un objeto usuario
function New-Usuario {
    param(
        [string]$Nombre,
        [string]$Rol = 'usuario'
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "con rol admin"
                   Run = { New-Usuario -Nombre 'ana' -Rol 'admin' }
                   Check = { param($r) ($r -isnot [string]) -and ($r.Nombre -eq 'ana') -and ($r.Rol -eq 'admin') -and ($r.Activo -eq $true) }
                   Desc = "un objeto con Nombre=ana, Rol=admin, Activo=True" }
                @{ Nombre = "rol por defecto"
                   Run = { New-Usuario -Nombre 'luis' }
                   Check = { param($r) ($r -isnot [string]) -and ($r.Nombre -eq 'luis') -and ($r.Rol -eq 'usuario') -and ($r.Activo -eq $true) }
                   Desc = "un objeto con Nombre=luis, Rol=usuario, Activo=True" }
            )
            Pista = "[pscustomobject]@{ Propiedad = valor; Otra = valor } crea un objeto. No lo conviertas a texto."
            Solucion = @'
function New-Usuario {
    param(
        [string]$Nombre,
        [string]$Rol = 'usuario'
    )
    [pscustomobject]@{
        Nombre = $Nombre
        Rol    = $Rol
        Activo = $true
    }
}
'@
            Concepto = "PowerShell brilla cuando pasas OBJETOS por el pipeline: se pueden filtrar, ordenar y exportar sin parsear texto."
        },
        @{
            Id = 'servicios-parados'; Nivel = 2; Titulo = "Informe de servicios parados (con simulación)"
            Enunciado = @"
Escribe Get-ServiciosParados, que use Get-Service y devuelva SOLO LOS NOMBRES
de los servicios con Status 'Stopped', ordenados alfabéticamente.
(Forja simula Get-Service con servicios falsos: tu código se prueba sin
tocar los servicios reales de tu equipo.)
"@
            Plantilla = @'
# Misión: nombres de los servicios detenidos
function Get-ServiciosParados {
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "mezcla de servicios"
                   Prep = {
                       function Get-Service {
                           @(
                               [pscustomobject]@{ Name = 'Spooler'; Status = 'Stopped' }
                               [pscustomobject]@{ Name = 'W32Time'; Status = 'Running' }
                               [pscustomobject]@{ Name = 'sshd';    Status = 'Stopped' }
                               [pscustomobject]@{ Name = 'Dhcp';    Status = 'Running' }
                               [pscustomobject]@{ Name = 'BITS';    Status = 'Stopped' }
                           )
                       }
                   }
                   Run = { Get-ServiciosParados }; Esperado = @('BITS','Spooler','sshd') }
                @{ Nombre = "todos en marcha"
                   Prep = {
                       function Get-Service {
                           @(
                               [pscustomobject]@{ Name = 'Dhcp';    Status = 'Running' }
                               [pscustomobject]@{ Name = 'W32Time'; Status = 'Running' }
                           )
                       }
                   }
                   Run = { Get-ServiciosParados }; Esperado = @() }
            )
            Pista = "Get-Service | Where-Object Status -eq 'Stopped' | Sort-Object Name | y quédate solo con el texto del nombre (Select-Object -ExpandProperty Name)."
            Solucion = @'
function Get-ServiciosParados {
    Get-Service |
        Where-Object Status -eq 'Stopped' |
        Sort-Object Name |
        Select-Object -ExpandProperty Name
}
'@
            Concepto = "Una función que llama a Get-Service se puede probar sustituyendo Get-Service por una simulación (mock): así se prueban scripts de administración sin riesgo."
        },
        @{
            Id = 'csv-activos'; Nivel = 2; Titulo = "Leer un CSV y filtrar"
            Enunciado = @"
Escribe Get-UsuariosActivos con un parámetro [string]`$Ruta (un CSV con las
columnas nombre,rol,activo). Debe devolver SOLO LOS NOMBRES de los usuarios
cuyo campo activo vale 'si', en el orden del archivo.
"@
            Plantilla = @'
# Misión: usuarios activos desde un CSV
function Get-UsuariosActivos {
    param(
        [string]$Ruta
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "CSV mixto"
                   Prep = { $script:csv = Join-Path $Sandbox 'usuarios.csv'; @('nombre,rol,activo','ana,admin,si','luis,usuario,no','marta,admin,si','pedro,usuario,si') | Set-Content -Path $script:csv }
                   Run  = { Get-UsuariosActivos -Ruta $script:csv }; Esperado = @('ana','marta','pedro') }
                @{ Nombre = "nadie activo"
                   Prep = { $script:csv = Join-Path $Sandbox 'usuarios.csv'; @('nombre,rol,activo','ana,admin,no','luis,usuario,no') | Set-Content -Path $script:csv }
                   Run  = { Get-UsuariosActivos -Ruta $script:csv }; Esperado = @() }
            )
            Pista = "Import-Csv convierte cada fila en un objeto con las columnas como propiedades. Después Where-Object y Select-Object -ExpandProperty nombre."
            Solucion = @'
function Get-UsuariosActivos {
    param(
        [string]$Ruta
    )
    Import-Csv -Path $Ruta |
        Where-Object { $_.activo -eq 'si' } |
        Select-Object -ExpandProperty nombre
}
'@
            Concepto = "Import-Csv te da objetos: filtras por columnas con Where-Object igual que con cualquier otro objeto."
        },
        @{
            Id = 'pipeline-mayus'; Nivel = 2; Titulo = "Aceptar datos del pipeline (process)"
            Enunciado = @"
Escribe ConvertTo-Mayus con un parámetro [string]`$Texto que:
  - funcione con el parámetro:   ConvertTo-Mayus -Texto 'abc'      ->  ABC
  - Y reciba datos por el pipeline:   'hola','mundo' | ConvertTo-Mayus  ->  HOLA, MUNDO
"@
            Plantilla = @'
# Misión: una función que acepta pipeline
function ConvertTo-Mayus {
    param(
        [string]$Texto
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "con parámetro";  Run = { ConvertTo-Mayus -Texto 'abc' };            Esperado = 'ABC' }
                @{ Nombre = "desde el pipeline"; Run = { 'hola','mundo' | ConvertTo-Mayus };     Esperado = @('HOLA','MUNDO') }
            )
            Pista = "Añade [Parameter(ValueFromPipeline)] al parámetro y pon el código dentro de un bloque process { ... }: se ejecuta una vez por cada elemento que llega."
            Solucion = @'
function ConvertTo-Mayus {
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Texto
    )
    process {
        $Texto.ToUpper()
    }
}
'@
            Concepto = "ValueFromPipeline + bloque process: así tus funciones se comportan como los cmdlets nativos dentro de un pipeline."
        },
        @{
            Id = 'try-catch-leer'; Nivel = 2; Titulo = "Leer sin romperse (try/catch)"
            Enunciado = @"
Escribe Read-Seguro con un parámetro [string]`$Ruta. Debe devolver el texto
del archivo. Si el archivo NO existe, debe devolver exactamente NO_EXISTE
y NO mostrar ningún error rojo (usa try/catch).
"@
            Plantilla = @'
# Misión: leer un archivo sin que falle si no existe
function Read-Seguro {
    param(
        [string]$Ruta
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "archivo que existe"
                   Prep = { $script:f = Join-Path $Sandbox 'nota.txt'; Set-Content -Path $script:f -Value 'hola mundo' }
                   Run  = { Read-Seguro -Ruta $script:f }
                   Check = { param($r) (@($r) -join '').Trim() -eq 'hola mundo' }
                   Desc = "hola mundo" }
                @{ Nombre = "archivo que NO existe"
                   Run  = { Read-Seguro -Ruta (Join-Path $Sandbox 'no-existe.txt') }
                   Check = { param($r) (@($r) -join '').Trim() -ceq 'NO_EXISTE' }
                   Desc = "NO_EXISTE" }
            )
            Pista = "try { Get-Content ... -ErrorAction Stop } catch { 'NO_EXISTE' }. Sin -ErrorAction Stop el error no es 'terminante' y el catch no salta."
            Solucion = @'
function Read-Seguro {
    param(
        [string]$Ruta
    )
    try {
        Get-Content -Path $Ruta -ErrorAction Stop
    }
    catch {
        'NO_EXISTE'
    }
}
'@
            Concepto = "-ErrorAction Stop convierte un error normal en terminante para que try/catch lo capture."
        },
        @{
            Id = 'whatif-viejos'; Nivel = 2; Titulo = "Borrado seguro con -WhatIf"
            Enunciado = @"
Escribe Remove-Viejos con los parámetros [string]`$Carpeta y [int]`$Dias.
Debe borrar los archivos de la carpeta modificados hace MÁS de `$Dias días.
Tiene que soportar -WhatIf: con -WhatIf no borra nada, solo simula.
"@
            Plantilla = @'
# Misión: borrar archivos antiguos con soporte de -WhatIf
function Remove-Viejos {
    param(
        [string]$Carpeta,
        [int]$Dias
    )
    # TU CÓDIGO AQUÍ
}
'@
            Tests = @(
                @{ Nombre = "con -WhatIf no borra nada"
                   Prep = {
                       $script:v = Join-Path $Sandbox 'vieja.log';    Set-Content -Path $script:v -Value 'x'; (Get-Item $script:v).LastWriteTime = (Get-Date).AddDays(-60)
                       $script:n = Join-Path $Sandbox 'reciente.log'; Set-Content -Path $script:n -Value 'x'
                   }
                   Run = { Remove-Viejos -Carpeta $Sandbox -Dias 30 -WhatIf | Out-Null; 'hecho' }
                   Check = { param($r) (Test-Path $script:v) -and (Test-Path $script:n) }
                   Desc = "ambos archivos siguen existiendo" }
                @{ Nombre = "sin -WhatIf borra solo lo viejo"
                   Prep = {
                       $script:v = Join-Path $Sandbox 'vieja.log';    Set-Content -Path $script:v -Value 'x'; (Get-Item $script:v).LastWriteTime = (Get-Date).AddDays(-60)
                       $script:n = Join-Path $Sandbox 'reciente.log'; Set-Content -Path $script:n -Value 'x'
                   }
                   Run = { Remove-Viejos -Carpeta $Sandbox -Dias 30 | Out-Null; 'hecho' }
                   Check = { param($r) (-not (Test-Path $script:v)) -and (Test-Path $script:n) }
                   Desc = "vieja.log borrada, reciente.log intacta" }
            )
            Pista = "Añade [CmdletBinding(SupportsShouldProcess)] encima de param(...): las funciones con ese atributo heredan -WhatIf y los cmdlets de dentro (Remove-Item) lo respetan solos. Fecha límite: (Get-Date).AddDays(-`$Dias)."
            Solucion = @'
function Remove-Viejos {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Carpeta,
        [int]$Dias
    )
    $limite = (Get-Date).AddDays(-$Dias)
    Get-ChildItem -Path $Carpeta -File |
        Where-Object { $_.LastWriteTime -lt $limite } |
        Remove-Item
}
'@
            Concepto = "SupportsShouldProcess da -WhatIf y -Confirm gratis. Todo script que borre o modifique cosas debería tenerlo."
        }
    )
}

# ================================================================= #
#                          COMANDO PRINCIPAL                        #
# ================================================================= #
function Invoke-Forja {
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

        # Sigue con tu código anterior en vez de restaurar la plantilla
        [switch]$Continuar,

        # No abre el editor (lo abres tú)
        [switch]$SinEditor
    )

    $c = $global:CY
    if (-not $c) { $c = @{ Green="#39FF14"; Yellow="#FCEE0A"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" } }

    $todas = @(Get-ForjaMisiones)
    $pool  = @($todas | ForEach-Object { [pscustomobject]@{ M = $_; Id = "forja:$($_.Id)" } })
    if ($PSBoundParameters.ContainsKey('Nivel')) { $pool = @($pool | Where-Object { $_.M.Nivel -eq $Nivel }) }

    if ($Lista) {
        Write-Host ""
        Write-Cyber "  $("NIV".PadRight(5)) $("ID".PadRight(20)) $("MISIÓN".PadRight(46)) ESTADO" $c.Green
        Write-Cyber "  $("-" * 88)" $c.Magenta
        foreach ($p in $pool) {
            $e = Get-CyberEntrada $p.Id
            if (-not $e) { $estado = "nueva" }
            elseif (Test-CyberDue $p.Id) { $estado = "caja $($e.Caja)  ·  REPASO HOY" }
            else { $estado = "caja $($e.Caja)  ·  $(Format-CyberProximo $e)" }
            Write-Cyber "  $("$($p.M.Nivel)".PadRight(5)) " $c.Cyan -NoNewline
            Write-Cyber "$($p.M.Id.PadRight(20)) " $c.Yellow -NoNewline
            Write-Cyber "$($p.M.Titulo.PadRight(46).Substring(0,46)) " $c.Cyan -NoNewline
            Write-Cyber $estado $c.Dim
        }
        Write-Host ""
        Write-Cyber "  forja -Id <id>  para una misión concreta   |   forja -Repaso  para lo pendiente" $c.Dim
        Write-Host ""
        return
    }

    if ($Id) {
        $sel = @($pool | Where-Object { $_.M.Id -eq $Id }) | Select-Object -First 1
        if (-not $sel) {
            Write-Cyber "No existe la misión '$Id'. Mira las ids con:  forja -Lista" $c.Magenta
            return
        }
    }
    else {
        $due = @($pool | Where-Object { Test-CyberDue $_.Id } |
                 Sort-Object { ConvertTo-CyberFecha (Get-CyberEntrada $_.Id).Due })

        if ($Repaso -and $due.Count -eq 0) {
            Write-Cyber "Nada pendiente de repaso en Forja. ¡Bien!  (prueba 'progreso' para ver tu estado)" $c.Green
            return
        }

        if ($due.Count -gt 0) {
            $sel = $due[0]
        } else {
            $nuevas = @($pool | Where-Object { -not (Get-CyberEntrada $_.Id) })
            if ($nuevas.Count -gt 0) {
                # Las nuevas van en orden: primero las de nivel bajo
                $sel = $nuevas[0]
            } else {
                $minCaja = ($pool | ForEach-Object { (Get-CyberEntrada $_.Id).Caja } | Measure-Object -Minimum).Minimum
                $sel = @($pool | Where-Object { (Get-CyberEntrada $_.Id).Caja -eq $minCaja }) | Get-Random
            }
        }
    }

    Invoke-ForjaMision -Mision $sel.M -MisionId $sel.Id -Titulo 'FORJA: ESCRIBE TU PROPIO SCRIPT (PowerShell)' -SinEditor:$SinEditor -Continuar:$Continuar
}

Set-Alias forja Invoke-Forja
