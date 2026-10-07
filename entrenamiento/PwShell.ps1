# ═══════════════════════════════════════════════════════════════════════
# PWSHELL · Practica scripting en PowerShell
# Sistema de retos interactivos con repaso espaciado (Leitner)
# Compatible con PowerShell 5.1+
# ═══════════════════════════════════════════════════════════════════════

# ── Progreso (Leitner: 5 cajas, intervalos 0/1/3/7/21 dias) ──────────

function Get-PwProgresoPath {
    Join-Path $HOME ".pwshell-progreso.json"
}

function Get-PwProgreso {
    $path = Get-PwProgresoPath
    if (Test-Path $path) {
        $raw = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $ht = @{}
        if ($null -ne $raw) {
            $raw.PSObject.Properties | ForEach-Object {
                $v = $_.Value
                $ht[$_.Name] = @{
                    caja     = [int]$v.caja
                    siguiente = [string]$v.siguiente
                    intentos = [int]$v.intentos
                    aciertos = [int]$v.aciertos
                }
            }
        }
        return $ht
    }
    return @{}
}

function Save-PwProgreso {
    param([hashtable]$Progreso)
    $obj = New-Object PSObject
    foreach ($k in ($Progreso.Keys | Sort-Object)) {
        $obj | Add-Member -MemberType NoteProperty -Name $k -Value $Progreso[$k]
    }
    $obj | ConvertTo-Json -Depth 5 | Set-Content (Get-PwProgresoPath) -Encoding UTF8
}

function Register-PwResultado {
    param([string]$Codigo, [bool]$Acierto)
    $prog = Get-PwProgreso
    $intervalos = @(0, 1, 3, 7, 21)
    $hoy = (Get-Date).ToString("yyyy-MM-dd")
    if (-not $prog.ContainsKey($Codigo)) {
        $prog[$Codigo] = @{ caja = 1; siguiente = $hoy; intentos = 0; aciertos = 0 }
    }
    $e = $prog[$Codigo]
    $e.intentos++
    if ($Acierto) {
        $e.aciertos++
        if ($e.caja -lt 5) { $e.caja++ }
    } else {
        $e.caja = 1
    }
    $e.siguiente = (Get-Date).AddDays($intervalos[$e.caja - 1]).ToString("yyyy-MM-dd")
    $prog[$Codigo] = $e
    Save-PwProgreso $prog
}

function Test-PwDue {
    param([string]$Codigo)
    $prog = Get-PwProgreso
    $hoy = (Get-Date).ToString("yyyy-MM-dd")
    if ($prog.ContainsKey($Codigo)) {
        return ([string]$prog[$Codigo].siguiente -le $hoy)
    }
    return $true
}

function Get-PwCaja {
    param([string]$Codigo)
    $prog = Get-PwProgreso
    if ($prog.ContainsKey($Codigo)) { return [int]$prog[$Codigo].caja }
    return 0
}

# ── Banco de retos ────────────────────────────────────────────────────

function Get-PwBanco {
    @(
    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 1 · ALIASES Y NAVEGACION (12 retos)
    # Objetivo: soltar la mano con los alias cortos de PowerShell
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "alias-gci"; nivel = 1; titulo = "Listar archivos (alias)"
        descripcion = "Escribe el alias CORTO de Get-ChildItem (2-3 letras)."
        patrones = @(
            '(?i)^gci\s*$'
        )
        errores = @(
            @{ patron = '(?i)^dir\s*$'; mensaje = "'dir' funciona en PowerShell pero es un alias de CMD. El alias propio de PowerShell es 'gci'." }
            @{ patron = '(?i)^ls\s*$'; mensaje = "'ls' funciona en PowerShell pero viene de Linux. El alias nativo de PowerShell es 'gci' (Get-ChildItem)." }
            @{ patron = '(?i)^Get-ChildItem\s*$'; mensaje = "Correcto pero queremos el alias CORTO. Son las iniciales: g-c-i." }
        )
        pista = "Son las iniciales de Get-ChildItem: g, c, i."
        solucion = "gci"
        explicacion = @"
Get-ChildItem tiene tres alias:
  gci  -> alias nativo de PowerShell (iniciales)
  dir  -> alias de compatibilidad con CMD
  ls   -> alias de compatibilidad con Linux
En PowerShell, la mayoria de alias nativos son las iniciales del cmdlet:
  Get-ChildItem = gci, Get-Process = gps, Get-Content = gc, etc.
"@
    },

    @{
        id = "alias-sl"; nivel = 1; titulo = "Cambiar directorio (alias)"
        descripcion = "Escribe el alias CORTO nativo de PowerShell para Set-Location."
        patrones = @(
            '(?i)^sl\s*$'
        )
        errores = @(
            @{ patron = '(?i)^cd\s*$'; mensaje = "'cd' funciona pero es el alias de compatibilidad. El nativo de PowerShell es 'sl' (Set-Location)." }
            @{ patron = '(?i)^Set-Location\s*$'; mensaje = "Queremos el alias corto, no el cmdlet completo. Iniciales: s-l." }
        )
        pista = "Iniciales de Set-Location."
        solucion = "sl"
        explicacion = @"
Set-Location = sl (nativo), cd (compatibilidad CMD), chdir (compatibilidad CMD).
La regla de los alias nativos de PowerShell: iniciales del verbo + sustantivo.
  Set-Location  -> sl
  Get-Location  -> gl  (equivale a pwd)
  Push-Location -> pushd
  Pop-Location  -> popd
"@
    },

    @{
        id = "alias-ni"; nivel = 1; titulo = "Crear archivo/carpeta (alias)"
        descripcion = "Escribe el alias corto para New-Item."
        patrones = @(
            '(?i)^ni\s*$'
        )
        errores = @(
            @{ patron = '(?i)^mkdir\s*$'; mensaje = "'mkdir' funciona para carpetas, pero el alias general para crear cualquier item es 'ni' (New-Item)." }
            @{ patron = '(?i)^touch\s*$'; mensaje = "'touch' es de Linux. En PowerShell el alias corto de New-Item es 'ni'." }
        )
        pista = "Iniciales de New-Item."
        solucion = "ni"
        explicacion = @"
New-Item crea archivos Y carpetas:
  ni archivo.txt                              -> crea archivo vacio
  ni MiCarpeta -ItemType Directory            -> crea carpeta
  ni config.json -Value '{"key":"value"}'     -> crea archivo con contenido
'mkdir' es un alias especial que equivale a 'ni -ItemType Directory'.
"@
    },

    @{
        id = "alias-gc"; nivel = 1; titulo = "Leer archivo (alias)"
        descripcion = "Escribe el alias corto para Get-Content."
        patrones = @(
            '(?i)^gc\s*$'
        )
        errores = @(
            @{ patron = '(?i)^cat\s*$'; mensaje = "'cat' funciona pero es alias de Linux. El nativo de PowerShell es 'gc'." }
            @{ patron = '(?i)^type\s*$'; mensaje = "'type' es de CMD. En PowerShell el alias corto de Get-Content es 'gc'." }
        )
        pista = "Iniciales de Get-Content."
        solucion = "gc"
        explicacion = @"
Get-Content = gc (nativo), cat (Linux), type (CMD).
Diferencia con CMD/Linux: en PowerShell, gc devuelve un ARRAY de lineas (objetos),
no un bloque de texto. Por eso puedes hacer cosas como:
  (gc archivo.txt).Count           -> numero de lineas
  (gc archivo.txt)[0]              -> primera linea
  gc archivo.txt | Select-Object -Last 5  -> ultimas 5 lineas
"@
    },

    @{
        id = "alias-ri"; nivel = 1; titulo = "Borrar (alias)"
        descripcion = "Escribe el alias corto para Remove-Item."
        patrones = @(
            '(?i)^ri\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(rm|del)\s*$'; mensaje = "'rm' y 'del' funcionan pero son alias de compatibilidad. El nativo de PowerShell es 'ri'." }
        )
        pista = "Iniciales de Remove-Item."
        solucion = "ri"
        explicacion = @"
Remove-Item = ri (nativo), rm (Linux), del (CMD), erase (CMD).
Parametros utiles:
  ri *.log                    -> borra archivos .log
  ri Carpeta -Recurse -Force  -> borra carpeta y contenido sin preguntar
  ri archivo.txt -WhatIf      -> SIMULA el borrado sin hacerlo (genial para probar)
"@
    },

    @{
        id = "alias-cpi"; nivel = 1; titulo = "Copiar (alias)"
        descripcion = "Escribe el alias corto nativo de PowerShell para Copy-Item."
        patrones = @(
            '(?i)^cpi\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(cp|copy)\s*$'; mensaje = "'cp' y 'copy' funcionan pero son de Linux/CMD. El nativo de PowerShell es 'cpi'." }
        )
        pista = "Iniciales de Copy-Item: c-p-i."
        solucion = "cpi"
        explicacion = @"
Copy-Item = cpi (nativo), cp (Linux), copy (CMD).
Ejemplos:
  cpi archivo.txt Backup\           -> copia archivo
  cpi *.log Backup\ -Recurse       -> copia recursiva
  cpi archivo.txt nuevo.txt         -> copia con nuevo nombre
"@
    },

    @{
        id = "alias-mi"; nivel = 1; titulo = "Mover (alias)"
        descripcion = "Escribe el alias corto nativo de PowerShell para Move-Item."
        patrones = @(
            '(?i)^mi\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(mv|move)\s*$'; mensaje = "'mv' y 'move' son de Linux/CMD. El alias nativo de PowerShell es 'mi'." }
        )
        pista = "Iniciales de Move-Item."
        solucion = "mi"
        explicacion = @"
Move-Item = mi (nativo), mv (Linux), move (CMD).
Tambien sirve para renombrar (igual que en CMD/Linux):
  mi archivo.txt nuevo_nombre.txt
Pero PowerShell tiene un cmdlet especifico para renombrar:
  Rename-Item archivo.txt nuevo_nombre.txt  (alias: rni, ren)
"@
    },

    @{
        id = "alias-ii"; nivel = 1; titulo = "Abrir archivo (alias)"
        descripcion = "Escribe el alias corto de Invoke-Item (abre un archivo con su programa asociado)."
        patrones = @(
            '(?i)^ii\s*$'
        )
        errores = @(
            @{ patron = '(?i)^start\s*$'; mensaje = "'start' es de CMD. El alias nativo de Invoke-Item es 'ii'. Aunque Start-Process (alias: saps) tambien abre programas." }
            @{ patron = '(?i)^open\s*$'; mensaje = "'open' es de macOS. En PowerShell es 'ii' (Invoke-Item)." }
        )
        pista = "Iniciales de Invoke-Item."
        solucion = "ii"
        explicacion = @"
Invoke-Item (ii) abre archivos con su programa por defecto:
  ii informe.docx     -> abre en Word
  ii .                -> abre el Explorador en la carpeta actual
  ii foto.png         -> abre en el visor de imagenes
Es el equivalente a hacer doble clic en el Explorador de Windows.
"@
    },

    @{
        id = "alias-gps"; nivel = 1; titulo = "Ver procesos (alias)"
        descripcion = "Escribe el alias corto nativo de PowerShell para Get-Process."
        patrones = @(
            '(?i)^gps\s*$'
        )
        errores = @(
            @{ patron = '(?i)^ps\s*$'; mensaje = "'ps' es de Linux. En PowerShell el alias nativo de Get-Process es 'gps'." }
            @{ patron = '(?i)^tasklist\s*$'; mensaje = "'tasklist' es de CMD. En PowerShell usa 'gps' (Get-Process)." }
        )
        pista = "Iniciales de Get-Process: g-p-s."
        solucion = "gps"
        explicacion = @"
Get-Process = gps (nativo), ps (Linux).
A diferencia de 'tasklist' de CMD, 'gps' devuelve OBJETOS:
  gps | Sort-Object CPU -Descending | Select-Object -First 5
  (gps chrome).Count         -> cuantos procesos de Chrome hay
  gps -Name chrome | Stop-Process   -> mata todos los Chrome
"@
    },

    @{
        id = "alias-where"; nivel = 1; titulo = "Filtrar con Where (alias)"
        descripcion = "Escribe el alias de UNA sola letra para Where-Object."
        patrones = @(
            '(?i)^\?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^where\s*$'; mensaje = "'where' es un alias pero tiene 5 letras. El de UNA sola letra es el signo de interrogacion: ?" }
            @{ patron = '(?i)^Where-Object\s*$'; mensaje = "Queremos el alias de UNA letra. Es el signo de interrogacion: ?" }
        )
        pista = "Es un signo de puntuacion que se usa para preguntar..."
        solucion = "?"
        explicacion = @"
Where-Object tiene dos alias: 'where' y '?'.
El ? es el mas rapido de escribir en el pipeline:
  gps | ? { $_.CPU -gt 100 }          -> procesos con CPU > 100
  gci | ? { $_.Length -gt 1MB }        -> archivos > 1MB
  1..100 | ? { $_ % 2 -eq 0 }         -> numeros pares del 1 al 100
El ? es Where-Object, no confundir con el operador ternario (que no existe en PS 5.1).
"@
    },

    @{
        id = "alias-foreach"; nivel = 1; titulo = "ForEach alias"
        descripcion = "Escribe el alias de UNA sola letra para ForEach-Object."
        patrones = @(
            '(?i)^%\s*$'
        )
        errores = @(
            @{ patron = '(?i)^foreach\s*$'; mensaje = "'foreach' funciona pero queremos el de UNA letra. Es el signo de porcentaje: %" }
        )
        pista = "Es un signo que en otros contextos significa 'porcentaje'."
        solucion = "%"
        explicacion = @"
ForEach-Object tiene dos alias: 'foreach' y '%'.
  gci *.txt | % { $_.Name.ToUpper() }     -> nombre de cada .txt en mayusculas
  1..5 | % { "Numero: $_" }               -> imprime cada numero
  gps | % { "$($_.Name): $($_.CPU)" }     -> nombre y CPU de cada proceso
El % es el 'map' de PowerShell: aplica una operacion a cada elemento del pipeline.
Los dos alias de 1 letra mas importantes: ? (Where) y % (ForEach).
"@
    },

    @{
        id = "alias-select"; nivel = 1; titulo = "Seleccionar propiedades"
        descripcion = "Escribe el alias corto para Select-Object."
        patrones = @(
            '(?i)^select\s*$'
        )
        errores = @(
            @{ patron = '(?i)^sel\s*$'; mensaje = "No es 'sel'. El alias de Select-Object es 'select' (la palabra completa pero sin Object)." }
        )
        pista = "Es la primera palabra del cmdlet, sin la segunda."
        solucion = "select"
        explicacion = @"
Select-Object (alias: select) elige QUE propiedades quieres ver:
  gps | select Name, CPU, WorkingSet      -> solo esas 3 columnas
  gps | select -First 5                   -> los 5 primeros
  gps | select -Last 3                    -> los 3 ultimos
  gps | select -Unique                    -> sin duplicados
Es como el SELECT de SQL: no filtra filas (eso es Where/?), elige columnas.
"@
    },

    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 2 · PIPELINE Y OBJETOS (12 retos)
    # Objetivo: dominar el pipeline y el trabajo con objetos
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "pipe-sort"; nivel = 2; titulo = "Ordenar procesos"
        descripcion = "Muestra los procesos ordenados por uso de CPU de mayor a menor. Usa el alias corto de Get-Process y el cmdlet Sort-Object."
        patrones = @(
            '(?i)^gps\s*\|\s*Sort-Object\s+(-Descending\s+)?CPU(\s+-Descending)?\s*$'
            '(?i)^gps\s*\|\s*sort\s+(-Descending\s+)?CPU(\s+-Descending)?\s*$'
            '(?i)^Get-Process\s*\|\s*Sort-Object\s+(-Descending\s+)?CPU(\s+-Descending)?\s*$'
        )
        errores = @(
            @{ patron = '(?i)Sort-Object.*-Ascending'; mensaje = "Con -Ascending ordenas de menor a mayor. Para mayor a menor necesitas -Descending." }
            @{ patron = '(?i)Sort-Object\s+CPU\s*$'; mensaje = "Sin -Descending ordena de menor a mayor (ascendente). Necesitas -Descending para ver los que mas CPU consumen arriba." }
            @{ patron = '(?i)tasklist.*sort'; mensaje = "Eso mezcla CMD con PowerShell. Usa gps (Get-Process) con Sort-Object." }
        )
        pista = "gps | Sort-Object [propiedad] -Descending"
        solucion = "gps | Sort-Object CPU -Descending"
        explicacion = @"
Sort-Object (alias: sort) ordena objetos por una propiedad:
  gps | Sort-Object CPU -Descending     -> mas CPU primero
  gps | Sort-Object WorkingSet          -> menos RAM primero (ascendente por defecto)
  gci | Sort-Object Length -Descending  -> archivos mas grandes primero
  gci | Sort-Object LastWriteTime       -> mas antiguos primero
Se pueden encadenar: gps | sort CPU -Descending | select -First 10
"@
    },

    @{
        id = "pipe-where-gt"; nivel = 2; titulo = "Filtrar con Where"
        descripcion = "Filtra los procesos que usen mas de 100MB de RAM. La propiedad de memoria es WorkingSet (en bytes). Usa el alias ? y el bloque { }."
        patrones = @(
            '(?i)^gps\s*\|\s*\?\s*\{\s*\$_\.WorkingSet\s+-(gt|GT)\s+100MB\s*\}\s*$'
            '(?i)^gps\s*\|\s*\?\s*\{\s*\$_\.WorkingSet\s+-(gt|GT)\s+104857600\s*\}\s*$'
            '(?i)^gps\s*\|\s*Where-Object\s*\{\s*\$_\.WorkingSet\s+-(gt|GT)\s+100MB\s*\}\s*$'
            '(?i)^Get-Process\s*\|\s*\?\s*\{\s*\$_\.WorkingSet\s+-(gt|GT)\s+100MB\s*\}\s*$'
        )
        errores = @(
            @{ patron = '(?i)>\s*100'; mensaje = "En PowerShell no se usa > para comparar (es redireccion). Usa -gt (greater than)." }
            @{ patron = '(?i)\$_\.WorkingSet\s+-(gt|GT)\s+100\s*\}'; mensaje = "WorkingSet esta en bytes. 100 bytes es nada. Usa 100MB (PowerShell entiende MB como multiplicador)." }
            @{ patron = '(?i)\$_\.Memory'; mensaje = "La propiedad no se llama Memory. Es WorkingSet (o WS como shortcut)." }
        )
        pista = '$_ es el objeto actual del pipeline. La propiedad es WorkingSet. PowerShell entiende 100MB como numero.'
        solucion = "gps | ? { `$_.WorkingSet -gt 100MB }"
        explicacion = @"
Where-Object (alias: ?) filtra objetos del pipeline con una condicion:
  gps | ? { $_.WorkingSet -gt 100MB }   -> procesos con > 100MB RAM
$_ es el objeto actual del pipeline (como 'this' en JavaScript).
PowerShell entiende unidades de tamaño: KB, MB, GB, TB, PB.
  1MB = 1048576 (1024 * 1024)
  100MB = 104857600
Esto evita tener que escribir numeros enormes.
"@
    },

    @{
        id = "pipe-select-props"; nivel = 2; titulo = "Elegir columnas"
        descripcion = "De los procesos, muestra SOLO el nombre (Name) y la memoria en bytes (WorkingSet). Usa select."
        patrones = @(
            '(?i)^gps\s*\|\s*select\s+Name\s*,\s*WorkingSet\s*$'
            '(?i)^gps\s*\|\s*Select-Object\s+Name\s*,\s*WorkingSet\s*$'
            '(?i)^Get-Process\s*\|\s*select\s+Name\s*,\s*WorkingSet\s*$'
        )
        errores = @(
            @{ patron = '(?i)select\s+-Property'; mensaje = "-Property es opcional. Se puede escribir directamente: select Name, WorkingSet" }
        )
        pista = "gps | select [propiedad1], [propiedad2]"
        solucion = "gps | select Name, WorkingSet"
        explicacion = @"
Select-Object (alias: select) elige que propiedades (columnas) ver:
  gps | select Name, CPU, WorkingSet
Para saber que propiedades tiene un objeto, usa Get-Member:
  gps | Get-Member              -> lista todas las propiedades y metodos
  gps | Get-Member -MemberType Property  -> solo propiedades
El alias de Get-Member es 'gm': gps | gm
"@
    },

    @{
        id = "pipe-first"; nivel = 2; titulo = "Primeros N resultados"
        descripcion = "Muestra solo los 5 archivos mas grandes del directorio actual. Necesitas ordenar por Length descendente y quedarte con los 5 primeros."
        patrones = @(
            '(?i)^gci\s*\|\s*sort\s+(-Descending\s+)?Length(\s+-Descending)?\s*\|\s*select\s+-First\s+5\s*$'
            '(?i)^gci\s*\|\s*Sort-Object\s+(-Descending\s+)?Length(\s+-Descending)?\s*\|\s*Select-Object\s+-First\s+5\s*$'
            '(?i)^Get-ChildItem\s*\|\s*Sort-Object\s+(-Descending\s+)?Length(\s+-Descending)?\s*\|\s*Select-Object\s+-First\s+5\s*$'
        )
        errores = @(
            @{ patron = '(?i)head\s'; mensaje = "'head' es de Linux. En PowerShell usa select -First N." }
            @{ patron = '(?i)select\s+5'; mensaje = "No es 'select 5'. Necesitas el parametro -First: select -First 5" }
        )
        pista = "Encadena tres pasos: listar | ordenar por tamaño descendente | quedarte con los primeros 5."
        solucion = "gci | sort Length -Descending | select -First 5"
        explicacion = @"
Este patron de tres pasos es MUY comun en PowerShell:
  1. Obtener datos:   gci, gps, Get-Service, etc.
  2. Filtrar/Ordenar: ? (where), sort
  3. Seleccionar:     select -First, select Name,Size
Otros selectores utiles:
  select -Last 5       -> los 5 ultimos
  select -Skip 10      -> salta los 10 primeros
  select -Unique       -> elimina duplicados
"@
    },

    @{
        id = "pipe-foreach"; nivel = 2; titulo = "ForEach en pipeline"
        descripcion = "Recorre todos los archivos .txt del directorio actual y muestra el nombre de cada uno en mayusculas. Usa el alias % y el metodo .ToUpper() del string."
        patrones = @(
            '(?i)^gci\s+\*\.txt\s*\|\s*%\s*\{\s*\$_\.Name\.ToUpper\(\)\s*\}\s*$'
            '(?i)^gci\s+\*\.txt\s*\|\s*ForEach-Object\s*\{\s*\$_\.Name\.ToUpper\(\)\s*\}\s*$'
            '(?i)^Get-ChildItem\s+\*\.txt\s*\|\s*%\s*\{\s*\$_\.Name\.ToUpper\(\)\s*\}\s*$'
        )
        errores = @(
            @{ patron = '(?i)foreach\s*\(\s*\$'; mensaje = "Eso es la sentencia foreach(). Aqui queremos ForEach-Object (alias %) en el PIPELINE con { }." }
            @{ patron = '(?i)\.Name\.ToUpper\s*\}'; mensaje = "Falta los parentesis del metodo: .ToUpper() con parentesis." }
        )
        pista = 'gci *.txt | % { $_.[propiedad].[metodo]() }'
        solucion = "gci *.txt | % { `$_.Name.ToUpper() }"
        explicacion = @"
ForEach-Object (alias: %) ejecuta un bloque de codigo para CADA objeto del pipeline.
$_ dentro del bloque es el objeto actual.
Los objetos en PowerShell tienen METODOS (como en C# o JavaScript):
  $_.Name.ToUpper()       -> nombre en mayusculas
  $_.Name.ToLower()       -> nombre en minusculas
  $_.Name.Replace('.txt','.bak')  -> reemplazar texto
  $_.Name.StartsWith('log')       -> true/false
Esto es posible porque PowerShell trabaja con OBJETOS .NET, no texto plano.
"@
    },

    @{
        id = "pipe-measure"; nivel = 2; titulo = "Contar y medir"
        descripcion = "Cuenta cuantos archivos .log hay en el directorio actual. Usa Measure-Object."
        patrones = @(
            '(?i)^(gci|Get-ChildItem)\s+\*\.log\s*\|\s*Measure-Object\s*$'
            '(?i)^(gci|Get-ChildItem)\s+\*\.log\s*\|\s*measure\s*$'
            '(?i)^\((gci|Get-ChildItem)\s+\*\.log\)\.Count\s*$'
        )
        errores = @(
            @{ patron = '(?i)wc\s'; mensaje = "'wc' es de Linux. En PowerShell usa Measure-Object (alias: measure)." }
        )
        pista = "Pipe a Measure-Object, o usa la propiedad .Count del resultado."
        solucion = "gci *.log | Measure-Object"
        explicacion = @"
Measure-Object (alias: measure) cuenta y calcula estadisticas:
  gci *.log | measure                       -> Count de archivos
  gci *.log | measure -Property Length -Sum -> tamaño total
  1,5,3,8,2 | measure -Average -Maximum    -> media y maximo
Atajo: (gci *.log).Count accede directamente al conteo.
Esto funciona porque PowerShell envuelve el resultado en un array automaticamente.
"@
    },

    @{
        id = "pipe-export-csv"; nivel = 2; titulo = "Exportar a CSV"
        descripcion = "Exporta la lista de procesos (nombre y CPU) a un archivo llamado procesos.csv. Usa select y Export-Csv."
        patrones = @(
            '(?i)^gps\s*\|\s*select\s+Name\s*,\s*CPU\s*\|\s*Export-Csv\s+(-NoTypeInformation\s+)?-?("?procesos\.csv"?|"?-Path\s+"?procesos\.csv"?)(\s+-NoTypeInformation)?\s*$'
            '(?i)^gps\s*\|\s*select\s+Name\s*,\s*CPU\s*\|\s*Export-Csv\s+"?procesos\.csv"?\s*(-NoTypeInformation)?\s*$'
            '(?i)^Get-Process\s*\|\s*Select-Object\s+Name\s*,\s*CPU\s*\|\s*Export-Csv\s+"?procesos\.csv"?\s*(-NoTypeInformation)?\s*$'
        )
        errores = @(
            @{ patron = '(?i)>\s*procesos\.csv'; mensaje = "Con > rediriges TEXTO. Export-Csv genera un archivo CSV bien formateado con cabeceras. Usa Export-Csv." }
            @{ patron = '(?i)Out-File'; mensaje = "Out-File guarda texto plano. Export-Csv crea un CSV estructurado con columnas y cabeceras." }
        )
        pista = "gps | select [columnas] | Export-Csv [archivo]"
        solucion = "gps | select Name, CPU | Export-Csv procesos.csv"
        explicacion = @"
Export-Csv genera un archivo CSV con cabeceras a partir de objetos:
  gps | select Name, CPU | Export-Csv procesos.csv
En PS 5.1 anade una linea de tipo al principio (#TYPE...). Para evitarla:
  Export-Csv procesos.csv -NoTypeInformation
Complemento: Import-Csv lee un CSV y devuelve objetos:
  Import-Csv procesos.csv | ? { $_.CPU -gt 10 }
El ciclo completo: obtener -> filtrar -> exportar -> importar -> analizar.
"@
    },

    @{
        id = "pipe-format-table"; nivel = 2; titulo = "Formatear tabla"
        descripcion = "Muestra los servicios del sistema (Get-Service) formateados como tabla, con columnas auto-ajustadas. Usa Format-Table con -AutoSize."
        patrones = @(
            '(?i)^Get-Service\s*\|\s*(Format-Table|ft)\s+-AutoSize\s*$'
            '(?i)^gsv\s*\|\s*(Format-Table|ft)\s+-AutoSize\s*$'
        )
        errores = @(
            @{ patron = '(?i)Format-List|fl\b'; mensaje = "Format-List muestra una propiedad por linea (vertical). Para tabla horizontal usa Format-Table (ft)." }
        )
        pista = "Get-Service | ft -AutoSize. El alias de Format-Table es ft."
        solucion = "Get-Service | ft -AutoSize"
        explicacion = @"
Cmdlets de formato (siempre van AL FINAL del pipeline):
  Format-Table (ft)  -> tabla horizontal (como un DataFrame)
  Format-List (fl)   -> una propiedad por linea (para ver todo el detalle)
  Format-Wide (fw)   -> solo una propiedad en multiples columnas
-AutoSize ajusta el ancho de cada columna al contenido.
IMPORTANTE: los cmdlets Format-* son para MOSTRAR. Si los pones antes
de Export-Csv o un filtro, pierdes los datos de los objetos.
"@
    },

    @{
        id = "pipe-get-member"; nivel = 2; titulo = "Descubrir propiedades"
        descripcion = "Muestra todas las propiedades y metodos que tiene un objeto de Get-Process. Usa Get-Member."
        patrones = @(
            '(?i)^gps\s*\|\s*(Get-Member|gm)\s*$'
            '(?i)^Get-Process\s*\|\s*(Get-Member|gm)\s*$'
        )
        errores = @(
            @{ patron = '(?i)\.GetType\(\)'; mensaje = ".GetType() da el tipo del objeto, no sus propiedades. Usa Get-Member (gm) para ver todo." }
        )
        pista = "Pipe el resultado a Get-Member (alias: gm)."
        solucion = "gps | gm"
        explicacion = @"
Get-Member (alias: gm) es TU MEJOR AMIGO en PowerShell.
Te dice exactamente que puedes hacer con un objeto:
  gps | gm                          -> todo (propiedades + metodos)
  gps | gm -MemberType Property     -> solo propiedades
  gps | gm -MemberType Method       -> solo metodos
Cuando no sepas que propiedades tiene algo, haz | gm.
Es como la documentacion interactiva del objeto.
"@
    },

    @{
        id = "pipe-combo"; nivel = 2; titulo = "Pipeline completo"
        descripcion = @"
Escribe un pipeline que haga todo esto en una linea:
1. Lista los archivos del directorio actual
2. Filtra solo los mayores de 1MB
3. Ordena por tamaño descendente
4. Muestra solo Name y Length
Usa aliases cortos donde puedas.
"@
        patrones = @(
            '(?i)^gci\s*\|\s*\?\s*\{\s*\$_\.Length\s+-(gt|GT)\s+1MB\s*\}\s*\|\s*sort\s+(-Descending\s+)?Length(\s+-Descending)?\s*\|\s*select\s+Name\s*,\s*Length\s*$'
            '(?i)^gci\s*\|\s*Where-Object\s*\{\s*\$_\.Length\s+-(gt|GT)\s+1MB\s*\}\s*\|\s*Sort-Object\s+(-Descending\s+)?Length(\s+-Descending)?\s*\|\s*Select-Object\s+Name\s*,\s*Length\s*$'
        )
        errores = @(
            @{ patron = '(?i)gci.*sort.*\?'; mensaje = "El orden importa: primero filtra (?), luego ordena (sort). Filtrar antes es mas eficiente." }
        )
        pista = "gci | ? { condicion } | sort propiedad -Descending | select columnas"
        solucion = "gci | ? { `$_.Length -gt 1MB } | sort Length -Descending | select Name, Length"
        explicacion = @"
Este es el patron clasico de PowerShell:
  OBTENER | FILTRAR | ORDENAR | SELECCIONAR
Es como una query SQL pero escrita como pipeline:
  SELECT Name, Length        -> select Name, Length
  FROM directorio            -> gci
  WHERE Length > 1MB         -> ? { $_.Length -gt 1MB }
  ORDER BY Length DESC       -> sort Length -Descending
Si piensas en SQL, el pipeline de PowerShell te resultara natural.
"@
    },

    @{
        id = "pipe-string"; nivel = 2; titulo = "Select-String (grep)"
        descripcion = "Busca la palabra 'ERROR' dentro de todos los archivos .log del directorio actual. Usa Select-String."
        patrones = @(
            '(?i)^Select-String\s+(-Pattern\s+)?"?ERROR"?\s+(-Path\s+)?"?\*\.log"?\s*$'
            '(?i)^Select-String\s+"?ERROR"?\s+"?\*\.log"?\s*$'
            '(?i)^(gci|Get-ChildItem)\s+\*\.log\s*\|\s*Select-String\s+(-Pattern\s+)?"?ERROR"?\s*$'
            '(?i)^sls\s+"?ERROR"?\s+"?\*\.log"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^findstr\s'; mensaje = "'findstr' es de CMD. En PowerShell usa Select-String (alias: sls)." }
            @{ patron = '(?i)^grep\s'; mensaje = "'grep' es de Linux. En PowerShell usa Select-String (alias: sls)." }
        )
        pista = "Select-String es el grep de PowerShell. Alias: sls."
        solucion = "Select-String ERROR *.log"
        explicacion = @"
Select-String (alias: sls) busca texto con expresiones regulares:
  sls ERROR *.log                -> busca en todos los .log
  sls -Pattern '\d{3}-\d{4}' archivo.txt  -> regex: numeros de telefono
  gc archivo.txt | sls 'patron'  -> buscar en el contenido de un archivo
A diferencia de grep/findstr, devuelve OBJETOS con propiedades:
  .Filename, .LineNumber, .Line, .Matches
Esto permite: sls ERROR *.log | select Filename, LineNumber
"@
    },

    @{
        id = "pipe-tnc"; nivel = 2; titulo = "Test de conexion"
        descripcion = "Comprueba si el puerto 443 esta abierto en google.com. Usa Test-NetConnection."
        patrones = @(
            '(?i)^(Test-NetConnection|tnc)\s+google\.com\s+-Port\s+443\s*$'
        )
        errores = @(
            @{ patron = '(?i)^ping\s'; mensaje = "'ping' solo prueba ICMP. Para probar un puerto concreto usa Test-NetConnection -Port." }
            @{ patron = '(?i)telnet'; mensaje = "'telnet' no esta instalado por defecto. Test-NetConnection (tnc) es la herramienta moderna de PowerShell." }
        )
        pista = "Test-NetConnection (alias: tnc) con el parametro -Port."
        solucion = "tnc google.com -Port 443"
        explicacion = @"
Test-NetConnection (alias: tnc) es la navaja suiza de red en PowerShell:
  tnc google.com              -> ping basico
  tnc google.com -Port 443    -> comprobar puerto HTTPS
  tnc google.com -Port 22     -> comprobar SSH
  tnc -TraceRoute google.com  -> traceroute
Devuelve un objeto con TcpTestSucceeded (true/false), muy util en scripts:
  if ((tnc server -Port 3389).TcpTestSucceeded) { echo "RDP abierto" }
"@
    },

    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 3 · OPERADORES Y SINTAXIS (10 retos)
    # Objetivo: dominar la sintaxis propia de PowerShell
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "op-eq"; nivel = 3; titulo = "Comparar con -eq"
        descripcion = @"
Escribe la condicion del IF que comprueba si la variable `$estado tiene el valor 'activo'.
Solo la linea del if con la llave de apertura.
"@
        patrones = @(
            '(?i)^if\s*\(\s*\$estado\s+-eq\s+[''"]activo[''"]\s*\)\s*\{\s*$'
        )
        errores = @(
            @{ patron = '(?i)=='; mensaje = "En PowerShell no se usa ==. Se usa -eq (equal). Los operadores de comparacion empiezan por guion." }
            @{ patron = '(?i)!='; mensaje = "En PowerShell no se usa !=. Se usa -ne (not equal)." }
            @{ patron = '(?i)-eq\s+activo\s*\)'; mensaje = 'Los strings necesitan comillas: -eq ''activo'' o -eq "activo".' }
        )
        pista = "if ($variable -eq 'valor') {"
        solucion = "if (`$estado -eq 'activo') {"
        explicacion = @"
Operadores de comparacion en PowerShell (todos empiezan por -):
  -eq   equal (==)          -ne   not equal (!=)
  -gt   greater than (>)    -ge   greater or equal (>=)
  -lt   less than (<)       -le   less or equal (<=)
  -like     comodin (* ?)   -notlike
  -match    regex           -notmatch
  -contains contiene        -in    esta en
Son CASE-INSENSITIVE por defecto. Para case-sensitive: -ceq, -cgt, etc.
  'Hola' -eq 'hola'    -> True (case-insensitive)
  'Hola' -ceq 'hola'   -> False (case-sensitive)
"@
    },

    @{
        id = "op-like"; nivel = 3; titulo = "Comparar con -like"
        descripcion = "Filtra los archivos cuyo nombre EMPIECE por 'log'. Usa -like con comodin."
        patrones = @(
            '(?i)^gci\s*\|\s*\?\s*\{\s*\$_\.Name\s+-like\s+[''"]log\*[''"]\s*\}\s*$'
            '(?i)^Get-ChildItem\s*\|\s*\?\s*\{\s*\$_\.Name\s+-like\s+[''"]log\*[''"]\s*\}\s*$'
            '(?i)^gci\s*\|\s*Where-Object\s*\{\s*\$_\.Name\s+-like\s+[''"]log\*[''"]\s*\}\s*$'
        )
        errores = @(
            @{ patron = '(?i)-match\s+[''"]log'; mensaje = "-match usa REGEX. -like usa comodines simples (* y ?). Aqui queremos -like con comodin *." }
            @{ patron = '(?i)\*log'; mensaje = "El * al principio significa 'acaba en log'. Para 'empieza por log' el * va al final: 'log*'." }
        )
        pista = "gci | ? { $_.Name -like 'patron*' }"
        solucion = "gci | ? { `$_.Name -like 'log*' }"
        explicacion = @"
-like usa comodines simples (como dir de CMD):
  'logfile.txt' -like 'log*'      -> True (empieza por log)
  'error.log' -like '*.log'       -> True (acaba en .log)
  'ab' -like '?b'                 -> True (? = un solo caracter)
-match usa REGEX (expresiones regulares):
  'logfile' -match '^log'          -> True (empieza por log)
  'error123' -match '\d+'         -> True (contiene digitos)
Regla: -like para comodines simples, -match para regex.
"@
    },

    @{
        id = "op-match"; nivel = 3; titulo = "Regex con -match"
        descripcion = @"
Comprueba si el string '192.168.1.100' coincide con un patron de IP simple.
Usa -match con una regex que busque 4 grupos de digitos separados por puntos.
Regex: \d+ = uno o mas digitos, \. = punto literal.
"@
        patrones = @(
            '(?i)^[''"]192\.168\.1\.100[''"]\s+-match\s+[''"]\\d\+\.\\d\+\.\\d\+\.\\d\+[''"]\s*$'
            '(?i)^[''"]192\.168\.1\.100[''"]\s+-match\s+[''"]\^\d\+\\.\d\+\\.\d\+\\.\d\+\$?[''"]\s*$'
            '(?i)^[''"]192\.168\.1\.100[''"]\s+-match\s+[''"]\\d\+\\\.\\d\+\\\.\\d\+\\\.\\d\+[''"]\s*$'
        )
        errores = @(
            @{ patron = '(?i)-like'; mensaje = "-like usa comodines simples (* ?). Para expresiones regulares necesitas -match." }
        )
        pista = "'texto' -match 'regex'. Los digitos son \\d+, el punto literal es \\."
        solucion = "'192.168.1.100' -match '\\d+\\.\\d+\\.\\d+\\.\\d+'"
        explicacion = @"
-match evalua una expresion regular contra un string:
  '192.168.1.100' -match '\d+\.\d+\.\d+\.\d+'  -> True
Cuando -match acierta, la variable automatica `$Matches guarda el resultado:
  `$Matches[0]  -> el texto completo que coincidio
Si usas grupos de captura: '(\d+)\.(\d+)...'
  `$Matches[1]  -> primer grupo
Regex basicas en PowerShell:
  \d = digito, \w = letra/digito, \s = espacio
  + = uno o mas, * = cero o mas, ? = cero o uno
  ^ = inicio, $ = final
"@
    },

    @{
        id = "syntax-array"; nivel = 3; titulo = "Crear array"
        descripcion = "Crea un array llamado `$servidores con tres valores: 'web01', 'db01', 'api01'. Usa el operador @()."
        patrones = @(
            '(?i)^\$servidores\s*=\s*@\(\s*[''"]web01[''"]\s*,\s*[''"]db01[''"]\s*,\s*[''"]api01[''"]\s*\)\s*$'
        )
        errores = @(
            @{ patron = '(?i)^\$servidores\s*=\s*[''"]web01'; mensaje = "Sin @() solo guardas un string. Para un array explicito usa @('web01', 'db01', 'api01')." }
            @{ patron = '(?i)^\$servidores\s*=\s*\('; mensaje = "Falta la @ antes del parentesis. El array explicito es @(...), no (...)." }
            @{ patron = '(?i)@\{'; mensaje = "@{} es un hashtable (diccionario). @() es un array. Necesitas parentesis, no llaves." }
        )
        pista = "$variable = @('valor1', 'valor2', 'valor3')"
        solucion = "`$servidores = @('web01', 'db01', 'api01')"
        explicacion = @"
@() crea un array (lista ordenada):
  `$nums = @(1, 2, 3)
  `$mix = @('texto', 42, `$true)
  `$vacio = @()              -> array vacio
Acceso por indice (base 0):
  `$servidores[0]            -> 'web01'
  `$servidores[-1]           -> 'api01' (ultimo)
  `$servidores.Count         -> 3
Diferencia con @{}:
  @() = array (lista)       -> acceso por indice: [0], [1]
  @{} = hashtable (dict)    -> acceso por clave: ['nombre']
"@
    },

    @{
        id = "syntax-hashtable"; nivel = 3; titulo = "Crear hashtable"
        descripcion = "Crea un hashtable llamado `$config con dos claves: 'puerto' con valor 8080 y 'host' con valor 'localhost'. Usa @{}."
        patrones = @(
            '(?i)^\$config\s*=\s*@\{\s*puerto\s*=\s*8080\s*;\s*host\s*=\s*[''"]localhost[''"]\s*\}\s*$'
            '(?i)^\$config\s*=\s*@\{\s*host\s*=\s*[''"]localhost[''"]\s*;\s*puerto\s*=\s*8080\s*\}\s*$'
            '(?i)^\$config\s*=\s*@\{\s*[''"]?puerto[''"]?\s*=\s*8080\s*;\s*[''"]?host[''"]?\s*=\s*[''"]localhost[''"]\s*\}\s*$'
        )
        errores = @(
            @{ patron = '(?i)@\('; mensaje = "@() es un array. Para un diccionario clave=valor usa @{} con llaves." }
            @{ patron = '(?i):\s'; mensaje = "En PowerShell los hashtable usan = (no : como en JSON). @{ clave = valor }" }
        )
        pista = "`$variable = @{ clave1 = valor1; clave2 = valor2 }"
        solucion = "`$config = @{ puerto = 8080; host = 'localhost' }"
        explicacion = @"
@{} crea un hashtable (diccionario/mapa):
  `$config = @{ puerto = 8080; host = 'localhost' }
Acceso: `$config.puerto o `$config['puerto']
Separadores: ; en una linea, o saltos de linea:
  `$config = @{
      puerto = 8080
      host   = 'localhost'
  }
Uso muy comun: splatting (pasar parametros a cmdlets):
  `$params = @{ Path = 'C:\'; Recurse = `$true; Filter = '*.log' }
  Get-ChildItem @params     -> equivale a: gci -Path C:\ -Recurse -Filter *.log
"@
    },

    @{
        id = "syntax-interpolacion"; nivel = 3; titulo = "Interpolacion de strings"
        descripcion = @"
Dado `$nombre = 'Hector' y `$edad = 40, escribe el comando echo/Write-Output que muestre:
  Hola, me llamo Hector y tengo 40 anos
Usa interpolacion con comillas dobles.
"@
        patrones = @(
            '(?i)^(echo|Write-Output)\s+"Hola, me llamo \$nombre y tengo \$edad anos"\s*$'
        )
        errores = @(
            @{ patron = '(?i)''Hola.*\$nombre'; mensaje = "Con comillas simples NO hay interpolacion. Usa comillas dobles para que $nombre y $edad se sustituyan." }
            @{ patron = '(?i)\+\s*\$nombre'; mensaje = 'La concatenacion con + funciona pero es mas fea. En comillas dobles puedes poner las variables directamente: "texto $variable texto".' }
        )
        pista = 'Con comillas dobles, las $variables se sustituyen automaticamente: "Hola $nombre"'
        solucion = 'echo "Hola, me llamo $nombre y tengo $edad anos"'
        explicacion = @"
Comillas en PowerShell:
  'texto simple'    -> literal, SIN interpolacion ($nombre queda como texto)
  "texto `$nombre"   -> CON interpolacion (sustituye la variable por su valor)
Para propiedades de objetos, usa `$():
  "Tengo `$(`$archivos.Count) archivos"
  "Hoy es `$(Get-Date -Format 'dd/MM/yyyy')"
Regla: comillas simples para texto fijo, dobles cuando necesites variables.
"@
    },

    @{
        id = "op-replace"; nivel = 3; titulo = "Reemplazar texto"
        descripcion = "Reemplaza todas las ocurrencias de '.txt' por '.bak' en el string `$archivo. Usa el operador -replace."
        patrones = @(
            '(?i)^\$archivo\s+-replace\s+[''"]\\?\.txt[''"]\s*,\s*[''"]\.bak[''"]\s*$'
        )
        errores = @(
            @{ patron = '(?i)\.Replace\('; mensaje = ".Replace() funciona pero es un metodo .NET (case-sensitive). El operador -replace es mas PowerShell y es case-insensitive por defecto." }
        )
        pista = "$variable -replace 'viejo', 'nuevo'"
        solucion = "`$archivo -replace '\\.txt', '.bak'"
        explicacion = @"
-replace usa REGEX para reemplazar texto:
  'informe.txt' -replace '\.txt', '.bak'    -> 'informe.bak'
  'Hola mundo' -replace 'mundo', 'PowerShell'
El primer argumento es una REGEX (por eso el punto necesita \. para ser literal).
Diferencia con .Replace():
  -replace: regex, case-insensitive por defecto
  .Replace(): texto literal, case-sensitive
Para case-sensitive: -creplace
Para grupos de captura: 'nombre.apellido' -replace '(\w+)\.(\w+)', '`$2_`$1'
"@
    },

    @{
        id = "op-split-join"; nivel = 3; titulo = "Split y Join"
        descripcion = "Dado `$csv = 'uno,dos,tres', divide el string por comas y luego unelo con punto y coma. Escribe el comando completo en una linea."
        patrones = @(
            '(?i)^\$csv\s+-split\s+[''"],[''"]?\s*-join\s+[''"];[''"]\s*$'
            '(?i)^\(\s*\$csv\s+-split\s+[''"],[''"]\s*\)\s+-join\s+[''"];[''"]\s*$'
        )
        errores = @(
            @{ patron = '(?i)\.Split\('; mensaje = ".Split() funciona pero el operador -split es mas idiomatico en PowerShell." }
        )
        pista = "($variable -split ',') -join ';'"
        solucion = "(`$csv -split ',') -join ';'"
        explicacion = @"
-split y -join son operadores nativos de PowerShell:
  'a,b,c' -split ','          -> @('a', 'b', 'c')  (string a array)
  @('a', 'b', 'c') -join ';'  -> 'a;b;c'            (array a string)
-split usa REGEX como patron:
  'uno  dos   tres' -split '\s+'  -> @('uno', 'dos', 'tres')
Combinados son muy utiles para transformar datos:
  (gc datos.csv | select -Skip 1) | % { (`$_ -split ',')[2] }  -> tercera columna
"@
    },

    @{
        id = "syntax-subexpresion"; nivel = 3; titulo = "Subexpresion $()"
        descripcion = @"
Dentro de un string con comillas dobles, muestra cuantos archivos tiene el directorio actual.
El resultado debe ser: 'Hay X archivos en esta carpeta'
Usa `$() para evaluar una expresion dentro del string.
"@
        patrones = @(
            '(?i)^(echo|Write-Output|Write-Host)\s+"Hay\s+\$\(\s*\(gci\)\.Count\s*\)\s+archivos en esta carpeta"\s*$'
            '(?i)^(echo|Write-Output|Write-Host)\s+"Hay\s+\$\(\s*\(Get-ChildItem\)\.Count\s*\)\s+archivos en esta carpeta"\s*$'
            '(?i)^"Hay\s+\$\(\s*\(gci\)\.Count\s*\)\s+archivos en esta carpeta"\s*$'
        )
        errores = @(
            @{ patron = '(?i)\$\(gci\)\.Count'; mensaje = "Necesitas que .Count este DENTRO del $(). Todo lo que quieras evaluar va dentro: $((gci).Count)." }
            @{ patron = '(?i)gci\.Count'; mensaje = "gci devuelve archivos, no tiene .Count directamente. Envuelvelo: (gci).Count, y dentro de un string: $((gci).Count)." }
        )
        pista = '"Texto $( expresion ) mas texto"'
        solucion = '"Hay $((gci).Count) archivos en esta carpeta"'
        explicacion = @"
`$() dentro de comillas dobles evalua una expresion:
  "Hola `$nombre"                      -> variable simple
  "Son las `$(Get-Date -Format HH:mm)" -> expresion compleja
  "Hay `$((gci).Count) archivos"       -> propiedad de resultado
Sin `$(), solo se interpolan variables simples (`$nombre).
Con `$(), puedes poner CUALQUIER codigo PowerShell dentro de un string.
"@
    },

    @{
        id = "syntax-dotnet"; nivel = 3; titulo = "Acceder a .NET"
        descripcion = "Usa la clase Math de .NET para redondear el numero 3.14159 a 2 decimales."
        patrones = @(
            '(?i)^\[Math\]::Round\(\s*3\.14159\s*,\s*2\s*\)\s*$'
            '(?i)^\[System\.Math\]::Round\(\s*3\.14159\s*,\s*2\s*\)\s*$'
        )
        errores = @(
            @{ patron = '(?i)Math\.Round'; mensaje = "En PowerShell las clases .NET van entre corchetes: [Math]::Round(), no Math.Round()." }
            @{ patron = '(?i)(?<!::)round\('; mensaje = "En PowerShell no hay funcion round() suelta. Se accede via .NET: [Math]::Round()" }
        )
        pista = "[NombreClase]::Metodo(argumentos). La clase es Math."
        solucion = "[Math]::Round(3.14159, 2)"
        explicacion = @"
PowerShell tiene acceso completo a .NET Framework:
  [Math]::Round(3.14159, 2)    -> 3.14
  [Math]::PI                   -> 3.14159265...
  [Math]::Sqrt(16)             -> 4
  [DateTime]::Now              -> fecha y hora actual
  [Environment]::UserName      -> usuario actual
  [IO.File]::ReadAllText('f')  -> leer archivo entero
Sintaxis: [Clase]::MetodoEstatico() o [Clase]::PropiedadEstatica
Esto es lo que hace a PowerShell tan potente: tienes toda la libreria .NET disponible.
"@
    },

    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 4 · SCRIPTS REALES (8 retos)
    # Objetivo: escribir scripts utiles y profesionales
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "script-irm"; nivel = 4; titulo = "Consumir API REST"
        descripcion = "Descarga y muestra el JSON de la URL https://api.github.com/zen usando Invoke-RestMethod. Usa el alias corto."
        patrones = @(
            '(?i)^irm\s+[''"]?https://api\.github\.com/zen[''"]?\s*$'
            '(?i)^Invoke-RestMethod\s+[''"]?https://api\.github\.com/zen[''"]?\s*$'
            '(?i)^irm\s+-Uri\s+[''"]?https://api\.github\.com/zen[''"]?\s*$'
        )
        errores = @(
            @{ patron = '(?i)curl\s'; mensaje = "'curl' en PowerShell es un alias de Invoke-WebRequest, NO el curl real. Usa 'irm' (Invoke-RestMethod) para APIs." }
            @{ patron = '(?i)Invoke-WebRequest|iwr'; mensaje = "Invoke-WebRequest devuelve la respuesta HTTP completa. Invoke-RestMethod (irm) parsea el JSON automaticamente." }
            @{ patron = '(?i)wget'; mensaje = "'wget' no existe en PowerShell por defecto. Usa 'irm' (Invoke-RestMethod)." }
        )
        pista = "irm es el alias de Invoke-RestMethod. Solo necesita la URL."
        solucion = "irm https://api.github.com/zen"
        explicacion = @"
Invoke-RestMethod (alias: irm) es perfecto para APIs REST:
  irm https://api.github.com/zen              -> GET simple
  irm https://api.com/data -Method POST -Body `$json
El resultado ya viene parseado como objeto PowerShell (no necesitas ConvertFrom-Json).
Diferencia con Invoke-WebRequest (iwr):
  irm  -> devuelve el CONTENIDO parseado (objetos)
  iwr  -> devuelve la RESPUESTA HTTP completa (headers, status, etc.)
"@
    },

    @{
        id = "script-param"; nivel = 4; titulo = "Funcion con parametros"
        descripcion = @"
Escribe la primera linea de una funcion llamada Test-Puerto que tenga dos parametros:
  - `$Servidor (string, obligatorio)
  - `$Puerto (int, por defecto 80)
Solo la linea function con param().
"@
        patrones = @(
            '(?i)^function\s+Test-Puerto\s*\{\s*param\(\s*\[Parameter\(Mandatory(=\$true)?\)\]\s*\[string\]\s*\$Servidor\s*,\s*\[int\]\s*\$Puerto\s*=\s*80\s*\)\s*$'
            '(?i)^function\s+Test-Puerto\s*\(\s*\[Parameter\(Mandatory(=\$true)?\)\]\s*\[string\]\s*\$Servidor\s*,\s*\[int\]\s*\$Puerto\s*=\s*80\s*\)\s*\{\s*$'
            '(?i)^function\s+Test-Puerto\s*\{\s*param\(\s*\[string\]\s*\$Servidor\s*,\s*\[int\]\s*\$Puerto\s*=\s*80\s*\)\s*$'
        )
        errores = @(
            @{ patron = '(?i)function\s+test-puerto\s*\((?!\s*\[P)'; mensaje = "Puedes poner los parametros despues de param() dentro de la funcion, con tipos entre corchetes." }
            @{ patron = '(?i)def\s|func\s'; mensaje = "En PowerShell las funciones se declaran con 'function', no 'def' o 'func'." }
        )
        pista = "function Nombre { param([tipo]`$Param1, [tipo]`$Param2 = valorDefecto)"
        solucion = "function Test-Puerto { param([Parameter(Mandatory)][string]`$Servidor, [int]`$Puerto = 80)"
        explicacion = @"
Funciones con param() tipado y valores por defecto:
  function Test-Puerto {
      param(
          [Parameter(Mandatory)]
          [string]`$Servidor,

          [int]`$Puerto = 80
      )
      # ... codigo ...
  }
Llamada: Test-Puerto -Servidor google.com -Puerto 443
Si Mandatory no lleva `$true, PowerShell lo pide interactivamente.
Otros atributos utiles: [ValidateRange(1,65535)], [ValidateSet('TCP','UDP')]
"@
    },

    @{
        id = "script-trycatch"; nivel = 4; titulo = "Try/Catch"
        descripcion = @"
Escribe un bloque try/catch que intente leer el archivo 'config.json' con Get-Content
y, si falla, muestre un mensaje de error con Write-Warning. Escribe la estructura completa.
"@
        patrones = @(
            '(?i)^try\s*\{\s*(gc|Get-Content)\s+[''"]?config\.json[''"]?(\s+-ErrorAction\s+Stop)?\s*\}\s*catch\s*\{\s*Write-Warning\s+.+\}\s*$'
        )
        errores = @(
            @{ patron = '(?i)try\s*\{[^}]*\}\s*$'; mensaje = "Un try sin catch no tiene sentido. Necesitas: try { ... } catch { ... }" }
            @{ patron = '(?i)catch\s*\(\s*Exception'; mensaje = "En PowerShell el catch no necesita tipo entre parentesis. Se puede poner catch { } directamente." }
        )
        pista = "try { comando } catch { Write-Warning 'mensaje' }"
        solucion = "try { gc config.json -ErrorAction Stop } catch { Write-Warning 'No se pudo leer config.json' }"
        explicacion = @"
try/catch en PowerShell:
  try {
      gc config.json -ErrorAction Stop
  } catch {
      Write-Warning "Error: `$(`$_.Exception.Message)"
  }
IMPORTANTE: -ErrorAction Stop es necesario para que los errores
no-terminantes (la mayoria en PowerShell) se capturen con catch.
Sin -ErrorAction Stop, muchos errores NO lanzan excepcion.
`$_ dentro del catch es el objeto de error completo.
"@
    },

    @{
        id = "script-csv-top-ram"; nivel = 4; titulo = "Top RAM a CSV"
        descripcion = @"
Escribe el pipeline completo que:
1. Obtiene los procesos
2. Ordena por WorkingSet descendente
3. Selecciona los 10 primeros
4. Muestra solo Name y WorkingSet
5. Exporta a top_ram.csv sin la linea de tipo
Todo en una sola linea.
"@
        patrones = @(
            '(?i)^gps\s*\|\s*sort\s+(-Descending\s+)?WorkingSet(\s+-Descending)?\s*\|\s*select\s+-First\s+10\s*\|\s*select\s+Name\s*,\s*WorkingSet\s*\|\s*Export-Csv\s+"?top_ram\.csv"?\s+-NoTypeInformation\s*$'
            '(?i)^gps\s*\|\s*sort\s+(-Descending\s+)?WorkingSet(\s+-Descending)?\s*\|\s*select\s+-First\s+10\s+(-Property\s+)?Name\s*,\s*WorkingSet\s*\|\s*Export-Csv\s+"?top_ram\.csv"?\s+-NoTypeInformation\s*$'
            '(?i)^gps\s*\|\s*Sort-Object\s+(-Descending\s+)?WorkingSet(\s+-Descending)?\s*\|\s*Select-Object\s+-First\s+10\s*\|\s*Select-Object\s+Name\s*,\s*WorkingSet\s*\|\s*Export-Csv\s+"?top_ram\.csv"?\s+-NoTypeInformation\s*$'
        )
        errores = @(
            @{ patron = '(?i)Export-Csv\s+[^-]*$'; mensaje = "En PS 5.1, Export-Csv anade una linea #TYPE al principio. Usa -NoTypeInformation para quitarla." }
        )
        pista = "gps | sort ... | select -First 10 | select Name, WorkingSet | Export-Csv archivo -NoTypeInformation"
        solucion = "gps | sort WorkingSet -Descending | select -First 10 | select Name, WorkingSet | Export-Csv top_ram.csv -NoTypeInformation"
        explicacion = @"
Este es un script real que puedes usar en el dia a dia:
  gps | sort WorkingSet -Descending | select -First 10 |
    select Name, WorkingSet | Export-Csv top_ram.csv -NoTypeInformation
Flujo: Obtener -> Ordenar -> Limitar -> Elegir columnas -> Exportar
Variantes utiles:
  - Cambiar WorkingSet por CPU para top CPU
  - Cambiar -First 10 por -First 20 para mas resultados
  - Anadir | % { [PSCustomObject]@{Name=`$_.Name; MB=[math]::Round(`$_.WorkingSet/1MB)} }
    para mostrar MB en vez de bytes
"@
    },

    @{
        id = "script-rename-bulk"; nivel = 4; titulo = "Renombrar en lote"
        descripcion = @"
Renombra todos los archivos .jpeg del directorio actual a .jpg.
Usa Get-ChildItem (alias) y Rename-Item con el operador -replace.
"@
        patrones = @(
            '(?i)^gci\s+\*\.jpeg\s*\|\s*Rename-Item\s+-NewName\s*\{\s*\$_\.Name\s+-replace\s+[''"]\.jpeg[''"]\s*,\s*[''"]\.jpg[''"]\s*\}\s*$'
            '(?i)^gci\s+\*\.jpeg\s*\|\s*(rni|Rename-Item)\s+-NewName\s*\{\s*\$_\.Name\s+-replace\s+[''"]\\?\.jpeg[''"]\s*,\s*[''"]\.jpg[''"]\s*\}\s*$'
            '(?i)^Get-ChildItem\s+\*\.jpeg\s*\|\s*Rename-Item\s+-NewName\s*\{\s*\$_\.Name\s+-replace\s+[''"]\\?\.jpeg[''"]\s*,\s*[''"]\.jpg[''"]\s*\}\s*$'
        )
        errores = @(
            @{ patron = '(?i)ren\s+\*\.jpeg\s+\*\.jpg'; mensaje = "Eso es CMD (ren *.jpeg *.jpg). En PowerShell usamos el pipeline: gci *.jpeg | Rename-Item -NewName { ... }" }
            @{ patron = '(?i)Move-Item|mi\s'; mensaje = "Move-Item mueve archivos. Para renombrar en lote usa Rename-Item con un bloque de script." }
        )
        pista = "gci *.jpeg | Rename-Item -NewName { $_.Name -replace patron, reemplazo }"
        solucion = "gci *.jpeg | Rename-Item -NewName { `$_.Name -replace '\\.jpeg', '.jpg' }"
        explicacion = @"
Rename-Item con -NewName acepta un bloque de script { }:
  gci *.jpeg | Rename-Item -NewName { `$_.Name -replace '\.jpeg', '.jpg' }
Dentro del bloque, `$_ es cada archivo del pipeline.
Otros ejemplos de renombrado masivo:
  # Poner prefijo
  gci *.txt | Rename-Item -NewName { "backup_`$(`$_.Name)" }
  # Quitar espacios
  gci | Rename-Item -NewName { `$_.Name -replace ' ', '_' }
  # Anadir fecha
  gci *.log | Rename-Item -NewName { "`$(Get-Date -f yyyyMMdd)_`$(`$_.Name)" }
Tip: usa -WhatIf para simular sin renombrar realmente.
"@
    },

    @{
        id = "script-splatting"; nivel = 4; titulo = "Splatting"
        descripcion = @"
Crea un hashtable llamado `$params con estas claves y despues usalo con Get-ChildItem:
  Path = 'C:\Logs'
  Filter = '*.log'
  Recurse = `$true
Escribe las dos lineas (hashtable y llamada con @).
"@
        patrones = @(
            '(?i)^\$params\s*=\s*@\{\s*Path\s*=\s*[''"]C:\\Logs[''"]\s*;\s*Filter\s*=\s*[''"]\*\.log[''"]\s*;\s*Recurse\s*=\s*\$true\s*\}\s*;\s*(gci|Get-ChildItem)\s+@params\s*$'
            '(?i)^\$params\s*=\s*@\{\s*(Path|Filter|Recurse)\s*=\s*.+;\s*(Path|Filter|Recurse)\s*=\s*.+;\s*(Path|Filter|Recurse)\s*=\s*.+\}\s*;\s*(gci|Get-ChildItem)\s+@params\s*$'
        )
        errores = @(
            @{ patron = '(?i)\$params\s*$'; mensaje = "Falta la llamada al cmdlet con @params despues del hashtable." }
            @{ patron = '(?i)gci\s+\$params'; mensaje = "Para splatting se usa @params (arroba), no $params (dolar). @params desempaqueta el hashtable como parametros." }
        )
        pista = "$params = @{ clave = valor; ... }; gci @params (con arroba, no dolar)"
        solucion = "`$params = @{ Path = 'C:\\Logs'; Filter = '*.log'; Recurse = `$true }; gci @params"
        explicacion = @"
Splatting pasa un hashtable como parametros a un cmdlet:
  `$params = @{
      Path    = 'C:\Logs'
      Filter  = '*.log'
      Recurse = `$true
  }
  Get-ChildItem @params
Es equivalente a: gci -Path 'C:\Logs' -Filter '*.log' -Recurse
Ventajas:
  - Lineas mas cortas y legibles
  - Puedes construir los parametros condicionalmente:
    if (`$buscarSubcarpetas) { `$params.Recurse = `$true }
  - Muy util en funciones wrapper
CLAVE: se usa @params (arroba), no `$params (dolar).
"@
    },

    @{
        id = "script-pscustomobject"; nivel = 4; titulo = "Crear objeto personalizado"
        descripcion = @"
Crea un objeto con [PSCustomObject] que tenga tres propiedades:
  Nombre = 'Servidor01'
  IP = '192.168.1.10'
  Estado = 'Online'
"@
        patrones = @(
            '(?i)^\[PSCustomObject\]@\{\s*Nombre\s*=\s*[''"]Servidor01[''"]\s*;\s*IP\s*=\s*[''"]192\.168\.1\.10[''"]\s*;\s*Estado\s*=\s*[''"]Online[''"]\s*\}\s*$'
            '(?i)^\[PSCustomObject\]@\{\s*(Nombre|IP|Estado)\s*=\s*.+;\s*(Nombre|IP|Estado)\s*=\s*.+;\s*(Nombre|IP|Estado)\s*=\s*.+\}\s*$'
        )
        errores = @(
            @{ patron = '(?i)New-Object\s+PSObject'; mensaje = "New-Object PSObject funciona pero [PSCustomObject]@{} es mas moderno, rapido y legible." }
            @{ patron = '(?i)^\$\w+\s*=\s*@\{'; mensaje = "Un @{} solo es un hashtable. Para crear un OBJETO con propiedades tipadas usa [PSCustomObject]@{ }." }
        )
        pista = "[PSCustomObject]@{ Propiedad = valor; ... }"
        solucion = "[PSCustomObject]@{ Nombre = 'Servidor01'; IP = '192.168.1.10'; Estado = 'Online' }"
        explicacion = @"
[PSCustomObject]@{} crea objetos con propiedades:
  [PSCustomObject]@{
      Nombre = 'Servidor01'
      IP     = '192.168.1.10'
      Estado = 'Online'
  }
Ventaja sobre un hashtable normal: mantiene el orden de las propiedades
y se comporta como un objeto real (funciona bien con Export-Csv, Format-Table, etc.)
Patron comun para generar tablas de datos:
  `$servidores = @('web01','db01') | % {
      [PSCustomObject]@{ Nombre = `$_; Ping = (tnc `$_ -InformationLevel Quiet) }
  }
  `$servidores | Export-Csv estado.csv
"@
    },

    @{
        id = "script-erroraction"; nivel = 4; titulo = "ErrorAction"
        descripcion = @"
Intenta obtener informacion del servicio 'NoExiste' con Get-Service, pero que no muestre
el error rojo en pantalla. Usa el parametro -ErrorAction con el valor que SILENCIA errores.
"@
        patrones = @(
            '(?i)^Get-Service\s+[''"]?NoExiste[''"]?\s+-ErrorAction\s+SilentlyContinue\s*$'
            '(?i)^gsv\s+[''"]?NoExiste[''"]?\s+-ErrorAction\s+SilentlyContinue\s*$'
        )
        errores = @(
            @{ patron = '(?i)2>\s*\$null'; mensaje = "2>$null funciona para redirigir errores, pero -ErrorAction SilentlyContinue es mas idiomatico en PowerShell." }
            @{ patron = '(?i)-ErrorAction\s+Stop'; mensaje = "-ErrorAction Stop FUERZA el error (para atraparlo con try/catch). Para SILENCIARLO usa SilentlyContinue." }
            @{ patron = '(?i)-ErrorAction\s+Ignore'; mensaje = "'Ignore' silencia y descarta el error completamente. 'SilentlyContinue' silencia pero guarda en `$Error. Ambos valen, pero SilentlyContinue es mas usado." }
        )
        pista = "-ErrorAction SilentlyContinue"
        solucion = "Get-Service NoExiste -ErrorAction SilentlyContinue"
        explicacion = @"
-ErrorAction controla que pasa cuando un cmdlet falla:
  Continue          -> muestra el error y sigue (por defecto)
  SilentlyContinue  -> oculta el error y sigue (el mas comun en scripts)
  Stop              -> convierte en error terminante (para try/catch)
  Ignore            -> oculta y ni lo guarda en `$Error
  Inquire           -> pregunta que hacer
Atajo: -ea en vez de -ErrorAction:
  Get-Service NoExiste -ea SilentlyContinue
Variable global: `$ErrorActionPreference = 'Stop' (aplica a todo el script)
"@
    }
    )
}

# ── Motor ─────────────────────────────────────────────────────────────

$global:PwActivo = $null
$global:PwIntentos = 0

function Show-PwBanner {
    param([hashtable]$Reto)
    $nivelNombre = switch ($Reto.nivel) {
        1 { "Aliases y navegacion" }
        2 { "Pipeline y objetos" }
        3 { "Operadores y sintaxis" }
        4 { "Scripts reales" }
    }
    $caja = Get-PwCaja $Reto.id
    $cajaStr = if ($caja -gt 0) { " [caja $caja/5]" } else { " [nuevo]" }
    Write-Host ""
    Write-Host "  +============================================+" -ForegroundColor DarkMagenta
    Write-Host "  |  PWSHELL  ·  PowerShell scripting          |" -ForegroundColor Magenta
    Write-Host "  |  Nivel $($Reto.nivel) · $nivelNombre$(' ' * (26 - $nivelNombre.Length))|" -ForegroundColor Magenta
    Write-Host "  |  > $($Reto.titulo)$(' ' * (37 - $Reto.titulo.Length))$cajaStr |" -ForegroundColor Yellow
    Write-Host "  +============================================+" -ForegroundColor DarkMagenta
    Write-Host ""
}

function Show-PwDescripcion {
    param([hashtable]$Reto)
    $lineas = $Reto.descripcion -split "`n"
    foreach ($linea in $lineas) {
        Write-Host "  $($linea.TrimEnd())" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  Escribe el comando directamente. Ayuda: " -ForegroundColor DarkGray -NoNewline
    Write-Host "p (pista)  s (solucion)  salir  ayuda" -ForegroundColor Gray
    Write-Host ""
}

function Get-PwSiguiente {
    $banco = Get-PwBanco
    $prog = Get-PwProgreso
    $repasos = $banco | Where-Object { Test-PwDue $_.id } | Where-Object {
        $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0 -and $prog[$_.id].caja -lt 5
    }
    if ($repasos.Count -gt 0) {
        return ($repasos | Sort-Object { (Get-PwCaja $_.id) } | Select-Object -First 1)
    }
    $nuevo = $banco | Where-Object { -not $prog.ContainsKey($_.id) } | Select-Object -First 1
    return $nuevo
}

function Enter-PwLoop {
    param([hashtable]$Reto)

    $global:PwActivo = $Reto
    $global:PwIntentos = 0
    Show-PwBanner $Reto
    Show-PwDescripcion $Reto

    while ($global:PwActivo) {
        Write-Host "  PS> " -NoNewline -ForegroundColor DarkMagenta
        try {
            $resp = Read-Host
        } catch {
            $global:PwActivo = $null
            break
        }
        if ($null -eq $resp) { $global:PwActivo = $null; break }
        $resp = $resp.Trim()
        if ($resp -eq '') { continue }

        $lower = $resp.ToLower()
        if ($lower -eq 'p' -or $lower -eq 'pista') {
            Show-PwPista
        } elseif ($lower -eq 's' -or $lower -eq 'solucion') {
            Show-PwSolucion
            $sig = Get-PwSiguiente
            if ($sig) {
                $global:PwActivo = $sig
                $global:PwIntentos = 0
                Show-PwBanner $sig
                Show-PwDescripcion $sig
            } else {
                Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
                Write-Host "  Usa 'pwshell -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
            }
        } elseif ($lower -eq 'salir' -or $lower -eq 'exit' -or $lower -eq 'q') {
            Exit-Pw
        } elseif ($lower -eq 'ayuda') {
            Write-Host ""
            Write-Host "  Escribe el comando PowerShell directamente como respuesta." -ForegroundColor Gray
            Write-Host ""
            Write-Host "  p / pista      Ver pista" -ForegroundColor DarkGray
            Write-Host "  s / solucion   Ver solucion (cuenta como fallo)" -ForegroundColor DarkGray
            Write-Host "  salir          Abandonar el reto actual" -ForegroundColor DarkGray
            Write-Host "  lista          Ver todos los retos" -ForegroundColor DarkGray
            Write-Host "  stats          Ver estadisticas" -ForegroundColor DarkGray
            Write-Host ""
        } elseif ($lower -eq 'lista') {
            Invoke-PwShell -Lista
        } elseif ($lower -eq 'stats') {
            Show-PwStats
        } else {
            Invoke-PwResponder $resp
            if (-not $global:PwActivo) {
                $sig = Get-PwSiguiente
                if ($sig) {
                    $global:PwActivo = $sig
                    $global:PwIntentos = 0
                    Show-PwBanner $sig
                    Show-PwDescripcion $sig
                } else {
                    Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
                    Write-Host "  Usa 'pwshell -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
                }
            }
        }
    }
}

function Invoke-PwShell {
    [CmdletBinding()]
    param(
        [int]$Nivel,
        [string]$Id,
        [switch]$Lista,
        [switch]$Repaso,
        [switch]$Reiniciar,
        [switch]$Stats
    )

    $banco = Get-PwBanco

    if ($Reiniciar) {
        $path = Get-PwProgresoPath
        if (Test-Path $path) { Remove-Item $path -Force }
        Write-Host "`n  Progreso reiniciado.`n" -ForegroundColor Yellow
        return
    }

    if ($Stats) {
        Show-PwStats
        return
    }

    if ($Lista) {
        $filtrados = if ($Nivel -gt 0) { $banco | Where-Object { $_.nivel -eq $Nivel } } else { $banco }
        $prog = Get-PwProgreso
        $hoy = (Get-Date).ToString("yyyy-MM-dd")

        $nivelActual = 0
        foreach ($r in $filtrados) {
            if ($r.nivel -ne $nivelActual) {
                $nivelActual = $r.nivel
                $nombre = switch ($nivelActual) {
                    1 { "ALIASES Y NAVEGACION" }
                    2 { "PIPELINE Y OBJETOS" }
                    3 { "OPERADORES Y SINTAXIS" }
                    4 { "SCRIPTS REALES" }
                }
                Write-Host "`n  === NIVEL $nivelActual · $nombre ===" -ForegroundColor Magenta
            }
            $caja = 0; $estado = "  "
            if ($prog.ContainsKey($r.id)) {
                $caja = $prog[$r.id].caja
                $due = ($prog[$r.id].siguiente -le $hoy)
                if ($caja -ge 5) { $estado = [char]0x2713 + " " }
                elseif ($due) { $estado = "> " }
                else { $estado = "- " }
            }
            $color = switch ($true) {
                ($estado.StartsWith([string][char]0x2713)) { "Green" }
                ($estado.StartsWith(">")) { "Yellow" }
                ($estado.StartsWith("-")) { "DarkGray" }
                default { "Gray" }
            }
            Write-Host "    $estado" -ForegroundColor $color -NoNewline
            Write-Host "$($r.id)" -ForegroundColor $color -NoNewline
            Write-Host " - $($r.titulo)" -ForegroundColor DarkGray -NoNewline
            if ($caja -gt 0) { Write-Host " [caja $caja]" -ForegroundColor DarkGray -NoNewline }
            Write-Host ""
        }
        Write-Host ""
        $total = $filtrados.Count
        $dominados = ($filtrados | Where-Object { (Get-PwCaja $_.id) -ge 5 }).Count
        $pendientes = ($filtrados | Where-Object { Test-PwDue $_.id }).Count
        Write-Host "  $dominados/$total dominados · $pendientes pendientes de repaso" -ForegroundColor DarkMagenta
        Write-Host ""
        return
    }

    if ($Id) {
        $reto = $banco | Where-Object { $_.id -eq $Id }
        if (-not $reto) {
            Write-Host "`n  Reto '$Id' no encontrado. Usa 'pwshell -Lista' para ver todos.`n" -ForegroundColor Red
            return
        }
        Enter-PwLoop $reto
        return
    }

    if ($Repaso) {
        $prog = Get-PwProgreso
        $pendientes = $banco | Where-Object { Test-PwDue $_.id } | Where-Object {
            $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0
        }
        if ($pendientes.Count -eq 0) {
            Write-Host "`n  No tienes retos pendientes de repaso. Buen trabajo!" -ForegroundColor Green
            Write-Host "  Usa 'pwshell' sin -Repaso para seguir avanzando.`n" -ForegroundColor DarkGray
            return
        }
        $elegido = $pendientes | Sort-Object { (Get-PwCaja $_.id) } | Select-Object -First 1
        Write-Host "`n  REPASO" -ForegroundColor Cyan
        Enter-PwLoop $elegido
        return
    }

    # Sin parametros: siguiente reto
    $prog = Get-PwProgreso
    $repasosPendientes = $banco | Where-Object { Test-PwDue $_.id } | Where-Object {
        $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0 -and $prog[$_.id].caja -lt 5
    }
    if ($repasosPendientes.Count -gt 0) {
        $elegido = $repasosPendientes | Sort-Object { (Get-PwCaja $_.id) } | Select-Object -First 1
        Write-Host "`n  REPASO pendiente" -ForegroundColor Cyan
        Enter-PwLoop $elegido
        return
    }

    $filtro = if ($Nivel -gt 0) { $banco | Where-Object { $_.nivel -eq $Nivel } } else { $banco }
    $nuevo = $filtro | Where-Object { -not $prog.ContainsKey($_.id) } | Select-Object -First 1
    if ($nuevo) {
        Enter-PwLoop $nuevo
        return
    }

    Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
    Write-Host "  Usa 'pwshell -Repaso' para repasar los que toquen." -ForegroundColor DarkGray
    Write-Host "  Usa 'pwshell -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
}

function Invoke-PwResponder {
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Palabras
    )
    if (-not $global:PwActivo) {
        Write-Host "`n  No hay ningun reto activo. Usa 'pwshell' para empezar.`n" -ForegroundColor Yellow
        return
    }
    $respuesta = ($Palabras -join " ").Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($respuesta)) {
        Write-Host "`n  Escribe tu respuesta directamente.`n" -ForegroundColor Yellow
        return
    }

    $reto = $global:PwActivo
    $global:PwIntentos++

    if ($reto.errores) {
        foreach ($err in $reto.errores) {
            if ($respuesta -match $err.patron) {
                Write-Host ""
                Write-Host "  X  Incorrecto" -ForegroundColor Red
                Write-Host "  $($err.mensaje)" -ForegroundColor Yellow
                Write-Host ""
                return
            }
        }
    }

    $acierto = $false
    foreach ($p in $reto.patrones) {
        if ($respuesta -match $p) {
            $acierto = $true
            break
        }
    }

    if ($acierto) {
        Register-PwResultado -Codigo $reto.id -Acierto $true
        $cajaNew = Get-PwCaja $reto.id
        Write-Host ""
        Write-Host "  OK  Correcto!" -ForegroundColor Green
        if ($reto.explicacion) {
            Write-Host ""
            $lineas = $reto.explicacion -split "`n"
            foreach ($l in $lineas) {
                Write-Host "  $($l.TrimEnd())" -ForegroundColor DarkCyan
            }
        }
        Write-Host ""
        Write-Host "  Caja: $cajaNew/5`n" -ForegroundColor DarkGray
        $global:PwActivo = $null
    } else {
        Write-Host ""
        Write-Host "  X  Incorrecto" -ForegroundColor Red
        if ($global:PwIntentos -ge 2) {
            Write-Host "  Prueba con 'p' para una pista o 's' para ver la solucion." -ForegroundColor DarkGray
        } else {
            Write-Host "  Intentalo otra vez. 'p' te da una pista." -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

function Show-PwPista {
    if (-not $global:PwActivo) {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "  PISTA: $($global:PwActivo.pista)" -ForegroundColor Cyan
    Write-Host ""
}

function Show-PwSolucion {
    if (-not $global:PwActivo) {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor Yellow
        return
    }
    $reto = $global:PwActivo
    Register-PwResultado -Codigo $reto.id -Acierto $false

    Write-Host ""
    Write-Host "  SOLUCION: " -ForegroundColor Yellow -NoNewline
    Write-Host $reto.solucion -ForegroundColor White
    if ($reto.explicacion) {
        Write-Host ""
        $lineas = $reto.explicacion -split "`n"
        foreach ($l in $lineas) {
            Write-Host "  $($l.TrimEnd())" -ForegroundColor DarkCyan
        }
    }
    Write-Host ""
    Write-Host "  Se ha registrado como fallo (volvera a aparecer pronto).`n" -ForegroundColor DarkGray
    $global:PwActivo = $null
}

function Exit-Pw {
    if ($global:PwActivo) {
        $reto = $global:PwActivo
        Register-PwResultado -Codigo $reto.id -Acierto $false
        Write-Host "`n  Saliste de '$($reto.titulo)'. Registrado como no completado.`n" -ForegroundColor DarkGray
    } else {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor DarkGray
    }
    $global:PwActivo = $null
}

function Show-PwStats {
    $banco = Get-PwBanco
    $prog = Get-PwProgreso
    $total = $banco.Count
    $intentados = 0; $dominados = 0; $totalIntentos = 0; $totalAciertos = 0

    foreach ($r in $banco) {
        if ($prog.ContainsKey($r.id)) {
            $intentados++
            $totalIntentos += $prog[$r.id].intentos
            $totalAciertos += $prog[$r.id].aciertos
            if ($prog[$r.id].caja -ge 5) { $dominados++ }
        }
    }

    $pctIntentados = if ($total -gt 0) { [math]::Round(($intentados / $total) * 100) } else { 0 }
    $pctDominados = if ($total -gt 0) { [math]::Round(($dominados / $total) * 100) } else { 0 }
    $pctAcierto = if ($totalIntentos -gt 0) { [math]::Round(($totalAciertos / $totalIntentos) * 100) } else { 0 }

    Write-Host ""
    Write-Host "  +============================================+" -ForegroundColor DarkMagenta
    Write-Host "  |  PWSHELL · Estadisticas                    |" -ForegroundColor Magenta
    Write-Host "  +============================================+" -ForegroundColor DarkMagenta
    Write-Host ""
    Write-Host "  Retos:      $intentados/$total intentados ($pctIntentados%)" -ForegroundColor White
    Write-Host "  Dominados:  $dominados/$total ($pctDominados%)" -ForegroundColor Green
    Write-Host "  Intentos:   $totalIntentos totales" -ForegroundColor Gray
    Write-Host "  Aciertos:   $totalAciertos ($pctAcierto%)" -ForegroundColor Gray
    Write-Host ""

    foreach ($n in 1..4) {
        $nivelRetos = $banco | Where-Object { $_.nivel -eq $n }
        $nivelNombre = switch ($n) { 1 { "Aliases " } 2 { "Pipeline" } 3 { "Operador" } 4 { "Scripts " } }
        $nivelDominados = ($nivelRetos | Where-Object { (Get-PwCaja $_.id) -ge 5 }).Count
        $barra = ""
        foreach ($r in $nivelRetos) {
            $c = Get-PwCaja $r.id
            if ($c -ge 5) { $barra += [char]0x2588 }
            elseif ($c -ge 3) { $barra += [char]0x2593 }
            elseif ($c -ge 1) { $barra += [char]0x2591 }
            else { $barra += [char]0x2500 }
        }
        Write-Host "  N$n $nivelNombre : " -ForegroundColor DarkMagenta -NoNewline
        Write-Host "$barra " -ForegroundColor Magenta -NoNewline
        Write-Host "$nivelDominados/$($nivelRetos.Count)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Show-PwHelp {
    Write-Host ""
    Write-Host "  PWSHELL · Practica PowerShell" -ForegroundColor Magenta
    Write-Host "  =============================" -ForegroundColor DarkMagenta
    Write-Host ""
    $ayuda = @(
        @{ cmd = "pwshell";            desc = "Siguiente reto (prioriza repasos)" }
        @{ cmd = "pwshell -Lista";     desc = "Ver todos los retos y su estado" }
        @{ cmd = "pwshell -Nivel 3";   desc = "Retos de un nivel concreto" }
        @{ cmd = "pwshell -Id X";      desc = "Ir a un reto concreto por su id" }
        @{ cmd = "pwshell -Repaso";    desc = "Solo retos que toca repasar" }
        @{ cmd = "pwshell -Stats";     desc = "Ver estadisticas de progreso" }
        @{ cmd = "pwshell -Reiniciar"; desc = "Borrar todo el progreso" }
        @{ cmd = "(tu comando)";         desc = "Escribe directamente en el prompt PS>" }
        @{ cmd = "p / pista";           desc = "Ver pista del reto activo" }
        @{ cmd = "s / solucion";        desc = "Ver solucion (cuenta como fallo)" }
        @{ cmd = "salir / exit";        desc = "Salir del reto activo" }
    )
    foreach ($h in $ayuda) {
        Write-Host "  $($h.cmd)" -ForegroundColor Yellow -NoNewline
        $pad = 28 - $h.cmd.Length
        if ($pad -lt 2) { $pad = 2 }
        Write-Host "$(' ' * $pad)$($h.desc)" -ForegroundColor Gray
    }
    Write-Host ""
}

# ── Aliases ───────────────────────────────────────────────────────────

Set-Alias pwshell     Invoke-PwShell     -Scope Global
Set-Alias pw-ayuda    Show-PwHelp        -Scope Global
Set-Alias pw-stats    Show-PwStats       -Scope Global
