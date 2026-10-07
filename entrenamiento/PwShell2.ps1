# ═══════════════════════════════════════════════════════════════════════
# PWSHELL2 · Practica scripting avanzado en PowerShell
# Variables, funciones, bucles, JSON, usuarios, servicios...
# Sistema de retos interactivos con repaso espaciado (Leitner)
# Compatible con PowerShell 5.1+
# ═══════════════════════════════════════════════════════════════════════

# ── Progreso (Leitner: 5 cajas, intervalos 0/1/3/7/21 dias) ──────────

function Get-Pw2ProgresoPath {
    Join-Path $HOME ".pwshell2-progreso.json"
}

function Get-Pw2Progreso {
    $path = Get-Pw2ProgresoPath
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

function Save-Pw2Progreso {
    param([hashtable]$Progreso)
    $obj = New-Object PSObject
    foreach ($k in ($Progreso.Keys | Sort-Object)) {
        $obj | Add-Member -MemberType NoteProperty -Name $k -Value $Progreso[$k]
    }
    $obj | ConvertTo-Json -Depth 5 | Set-Content (Get-Pw2ProgresoPath) -Encoding UTF8
}

function Register-Pw2Resultado {
    param([string]$Codigo, [bool]$Acierto)
    $prog = Get-Pw2Progreso
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
    Save-Pw2Progreso $prog
}

function Test-Pw2Due {
    param([string]$Codigo)
    $prog = Get-Pw2Progreso
    $hoy = (Get-Date).ToString("yyyy-MM-dd")
    if ($prog.ContainsKey($Codigo)) {
        return ([string]$prog[$Codigo].siguiente -le $hoy)
    }
    return $true
}

function Get-Pw2Caja {
    param([string]$Codigo)
    $prog = Get-Pw2Progreso
    if ($prog.ContainsKey($Codigo)) { return [int]$prog[$Codigo].caja }
    return 0
}

# ── Banco de retos ────────────────────────────────────────────────────

function Get-Pw2Banco {
    @(
    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 4 · VARIABLES, ESTRUCTURAS Y FUNCIONES (20 retos)
    # Objetivo: dominar los bloques basicos de scripting en PowerShell
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "var-string"; nivel = 4; titulo = "Declarar variable string"
        descripcion = "Declara una variable `$nombre con el valor 'Ana'."
        patrones = @(
            '(?i)^\$nombre\s*=\s*[''"]Ana[''"]$'
        )
        errores = @(
            @{ patron = '(?i)^set\s+nombre'; mensaje = "'set' es de CMD. En PowerShell se usa `$nombre = 'valor'." }
            @{ patron = '(?i)^nombre\s*='; mensaje = "Falta el `$ delante. Las variables en PowerShell siempre empiezan por `$." }
        )
        pista = "En PowerShell las variables empiezan por `$. Se asignan con =."
        solucion = "`$nombre = 'Ana'"
        explicacion = @"
Las variables en PowerShell siempre llevan `$ delante.
Se asignan con = y pueden contener cualquier tipo de dato.
  `$texto = 'Hola'       -> string
  `$numero = 42          -> int
  `$activo = `$true       -> boolean
Comillas simples: texto literal. Dobles: interpolan variables.
"@
    },

    @{
        id = "var-int"; nivel = 4; titulo = "Declarar variable numerica"
        descripcion = "Declara una variable `$edad con el valor 25."
        patrones = @(
            '(?i)^\$edad\s*=\s*25$'
        )
        errores = @(
            @{ patron = '(?i)^\$edad\s*=\s*[''"]25[''"]'; mensaje = "Sin comillas. Si pones comillas es un string, no un numero." }
        )
        pista = "Igual que un string pero sin comillas: `$edad = numero."
        solucion = "`$edad = 25"
        explicacion = @"
PowerShell detecta el tipo automaticamente:
  `$edad = 25          -> [int] (entero)
  `$edad = '25'        -> [string] (texto)
  `$precio = 19.99     -> [double] (decimal)
Si necesitas forzar el tipo: [int]`$edad = 25
"@
    },

    @{
        id = "var-interpolar"; nivel = 4; titulo = "Interpolar variable en string"
        descripcion = "Escribe un Write-Host que muestre: Hola Ana (usando la variable `$nombre)."
        patrones = @(
            '(?i)^Write-Host\s+["]Hola\s+\$nombre["]',
            '(?i)^Write-Host\s+["]Hola\s+\$nombre["]'
        )
        errores = @(
            @{ patron = "(?i)Write-Host\s+'Hola\s+\\\$nombre'"; mensaje = "Con comillas simples no se interpolan las variables. Usa comillas dobles." }
            @{ patron = '(?i)^echo\s'; mensaje = "Usa Write-Host, no echo. Write-Host permite colores y formato." }
        )
        pista = "Comillas dobles interpolan: `"Hola `$nombre`". Comillas simples no."
        solucion = 'Write-Host "Hola $nombre"'
        explicacion = @"
La diferencia clave entre comillas en PowerShell:
  "Hola `$nombre"  -> Hola Ana (INTERPOLA la variable)
  'Hola `$nombre'  -> Hola `$nombre (texto LITERAL)
Para propiedades o calculos dentro de un string, usa `$():
  "Tiene `$(`$frutas.Count) frutas"
"@
    },

    @{
        id = "var-array"; nivel = 4; titulo = "Crear un array"
        descripcion = "Crea un array `$frutas con tres elementos: manzana, pera, naranja."
        patrones = @(
            '(?i)^\$frutas\s*=\s*@\(\s*[''"]manzana[''"]',
            '(?i)^\$frutas\s*=\s*[''"]manzana[''"],\s*[''"]pera[''"],\s*[''"]naranja[''"]'
        )
        errores = @(
            @{ patron = '(?i)^\$frutas\s*=\s*\('; mensaje = "Para arrays usa @(...) con la arroba delante del parentesis." }
        )
        pista = "Los arrays se crean con @('elemento1', 'elemento2', 'elemento3')."
        solucion = "`$frutas = @('manzana', 'pera', 'naranja')"
        explicacion = @"
Arrays en PowerShell:
  `$frutas = @('manzana', 'pera', 'naranja')
  `$frutas[0]         -> manzana (primer elemento)
  `$frutas.Count      -> 3
  `$frutas += 'kiwi'  -> añade al final
  `$frutas -contains 'pera'  -> `$true
"@
    },

    @{
        id = "var-hashtable"; nivel = 4; titulo = "Crear un hashtable"
        descripcion = "Crea un hashtable `$persona con claves: nombre='Ana' y edad=25."
        patrones = @(
            '(?i)^\$persona\s*=\s*@\{\s*nombre\s*=\s*[''"]Ana[''"];\s*edad\s*=\s*25',
            '(?i)^\$persona\s*=\s*@\{\s*nombre\s*=\s*[''"]Ana[''"];\s*edad\s*=\s*25\s*\}'
        )
        errores = @(
            @{ patron = '(?i)^\$persona\s*=\s*@\('; mensaje = "@() es para arrays. Para hashtables (clave=valor) se usa @{}." }
            @{ patron = '(?i)^\$persona\s*=\s*\{'; mensaje = "Falta la @ delante de las llaves: @{ clave = valor }." }
        )
        pista = "Hashtable: @{ clave1 = valor1; clave2 = valor2 }. Punto y coma separa en una linea."
        solucion = "`$persona = @{ nombre = 'Ana'; edad = 25 }"
        explicacion = @"
Un hashtable es un diccionario clave-valor:
  `$persona = @{ nombre = 'Ana'; edad = 25 }
  `$persona.nombre        -> Ana
  `$persona['edad']       -> 25
  `$persona.ciudad = 'Zaragoza'  -> añadir clave
  `$persona.ContainsKey('nombre')  -> `$true
En varias lineas no necesitas punto y coma:
  `$persona = @{
      nombre = 'Ana'
      edad   = 25
  }
"@
    },

    @{
        id = "var-count"; nivel = 4; titulo = "Contar elementos de un array"
        descripcion = "Muestra cuantos elementos tiene el array `$frutas usando su propiedad."
        patrones = @(
            '(?i)^\$frutas\.Count$'
        )
        errores = @(
            @{ patron = '(?i)^\$frutas\.Length'; mensaje = ".Length funciona pero .Count es mas fiable en PowerShell. Usa .Count." }
            @{ patron = '(?i)^count\s*\$frutas'; mensaje = "No es un comando, es una propiedad del array: `$frutas.Count (con punto)." }
        )
        pista = "Es una propiedad del array: `$array.Count (con punto, sin parentesis)."
        solucion = "`$frutas.Count"
        explicacion = @"
Propiedades utiles de arrays:
  `$frutas.Count   -> numero de elementos
  `$frutas[0]      -> primer elemento
  `$frutas[-1]     -> ultimo elemento
  `$frutas[1..3]   -> del segundo al cuarto
.Count es mas fiable que .Length porque funciona con cualquier
tipo de coleccion en PowerShell.
"@
    },

    @{
        id = "if-basico"; nivel = 4; titulo = "Condicional if basico"
        descripcion = "Escribe un if que compruebe si `$edad es mayor o igual que 18."
        patrones = @(
            '(?i)^if\s*\(\s*\$edad\s+-ge\s+18\s*\)\s*\{',
            '(?i)^if\s*\(\s*\$edad\s+-ge\s+18\s*\)'
        )
        errores = @(
            @{ patron = '(?i)\$edad\s*>=\s*18'; mensaje = "En PowerShell no se usa >=. El operador es -ge (greater or equal)." }
            @{ patron = '(?i)\$edad\s*>\s*=\s*18'; mensaje = "El operador 'mayor o igual' en PowerShell es -ge, no >= ni > =." }
            @{ patron = '(?i)-gt\s+18'; mensaje = "-gt es 'mayor que' (greater than). Necesitas -ge (greater or equal) para 'mayor o IGUAL'." }
        )
        pista = "if (`$variable -ge valor) { }. El operador 'mayor o igual' es -ge."
        solucion = "if (`$edad -ge 18) { Write-Host 'Mayor de edad' }"
        explicacion = @"
Operadores de comparacion en PowerShell:
  -eq  (equal)            -ne  (not equal)
  -gt  (greater than)     -lt  (less than)
  -ge  (greater or equal) -le  (less or equal)
Siempre van con guion. NUNCA se usa ==, !=, >=, <=.
Estructura: if (condicion) { bloque }
"@
    },

    @{
        id = "if-else"; nivel = 4; titulo = "If con else"
        descripcion = "Escribe un if/else: si `$nota -ge 5, escribe 'Aprobado', si no 'Suspenso'."
        patrones = @(
            '(?i)^if\s*\(\s*\$nota\s+-ge\s+5\s*\)\s*\{[^}]*Aprobado[^}]*\}\s*else\s*\{[^}]*Suspenso'
        )
        errores = @(
            @{ patron = '(?i)else\s+if'; mensaje = "No pide elseif, solo if y else. Dos caminos: aprobado o suspenso." }
        )
        pista = "if (`$nota -ge 5) { Write-Host 'Aprobado' } else { Write-Host 'Suspenso' }"
        solucion = "if (`$nota -ge 5) { Write-Host 'Aprobado' } else { Write-Host 'Suspenso' }"
        explicacion = @"
Estructura if/else en una linea:
  if (condicion) { bloque1 } else { bloque2 }
En varias lineas (mas legible):
  if (`$nota -ge 5) {
      Write-Host 'Aprobado'
  } else {
      Write-Host 'Suspenso'
  }
La llave de else DEBE ir en la misma linea que el } anterior.
"@
    },

    @{
        id = "foreach-basico"; nivel = 4; titulo = "Foreach basico"
        descripcion = "Escribe un foreach que recorra `$frutas y muestre cada fruta con Write-Host."
        patrones = @(
            '(?i)^foreach\s*\(\s*\$\w+\s+in\s+\$frutas\s*\)\s*\{\s*Write-Host\s+\$\w+'
        )
        errores = @(
            @{ patron = '(?i)^for\s+each'; mensaje = "Se escribe junto: foreach, no for each." }
            @{ patron = '(?i)^for\s*\('; mensaje = "for() es un bucle con contador. Para recorrer una lista usa foreach (`$item in `$lista)." }
            @{ patron = '(?i)foreach.*\$frutas\s*\{'; mensaje = "Falta la variable iteradora: foreach (`$fruta in `$frutas) { ... }" }
        )
        pista = "foreach (`$fruta in `$frutas) { Write-Host `$fruta }"
        solucion = "foreach (`$fruta in `$frutas) { Write-Host `$fruta }"
        explicacion = @"
foreach recorre cada elemento de una coleccion:
  foreach (`$item in `$coleccion) {
      # `$item tiene el valor actual
  }
Tambien existe ForEach-Object para usarlo con pipeline:
  `$frutas | ForEach-Object { Write-Host `$_ }
La diferencia: foreach es una sentencia, ForEach-Object un cmdlet.
"@
    },

    @{
        id = "for-contador"; nivel = 4; titulo = "Bucle for con contador"
        descripcion = "Escribe un bucle for que cuente del 1 al 10."
        patrones = @(
            '(?i)^for\s*\(\s*\$\w+\s*=\s*1\s*;\s*\$\w+\s*-le\s+10\s*;\s*\$\w+\+\+\s*\)',
            '(?i)^for\s*\(\s*\$i\s*=\s*1\s*;\s*\$i\s*-le\s+10\s*;\s*\$i\+\+\s*\)\s*\{'
        )
        errores = @(
            @{ patron = '(?i)\$\w+\s*<=\s*10'; mensaje = "En PowerShell no se usa <=. El operador es -le (less or equal)." }
            @{ patron = '(?i)\$\w+\s*<\s*11'; mensaje = "Funciona, pero es mas claro usar -le 10 (menor o igual que 10)." }
        )
        pista = "for (`$i = 1; `$i -le 10; `$i++) { }"
        solucion = "for (`$i = 1; `$i -le 10; `$i++) { Write-Host `$i }"
        explicacion = @"
El for clasico tiene tres partes separadas por punto y coma:
  for (inicio; condicion; incremento) { bloque }
  for (`$i = 1; `$i -le 10; `$i++) { Write-Host `$i }
Alternativa rapida para rangos:
  1..10 | ForEach-Object { Write-Host `$_ }
"@
    },

    @{
        id = "while-basico"; nivel = 4; titulo = "Bucle while"
        descripcion = "Escribe un while que se repita mientras `$contador sea menor que 5."
        patrones = @(
            '(?i)^while\s*\(\s*\$contador\s+-lt\s+5\s*\)\s*\{'
        )
        errores = @(
            @{ patron = '(?i)\$contador\s*<\s*5'; mensaje = "En PowerShell no se usa <. El operador es -lt (less than)." }
        )
        pista = "while (`$condicion) { bloque }. Menor que = -lt."
        solucion = "while (`$contador -lt 5) { Write-Host `$contador; `$contador++ }"
        explicacion = @"
while ejecuta el bloque MIENTRAS la condicion sea verdadera:
  `$contador = 0
  while (`$contador -lt 5) {
      Write-Host `$contador
      `$contador++          # Importante: sin esto es bucle infinito!
  }
Cuidado: si olvidas incrementar la variable, el bucle nunca termina.
Usa Ctrl+C para salir de un bucle infinito.
"@
    },

    @{
        id = "func-basica"; nivel = 4; titulo = "Crear funcion basica"
        descripcion = "Crea una funcion llamada Saludo que haga Write-Host 'Hola mundo'."
        patrones = @(
            '(?i)^function\s+Saludo\s*\{\s*Write-Host\s+[''"]Hola\s+mundo[''"]'
        )
        errores = @(
            @{ patron = '(?i)^def\s+'; mensaje = "'def' es de Python. En PowerShell se usa 'function'." }
            @{ patron = '(?i)^func\s+'; mensaje = "Se escribe completo: 'function', no 'func'." }
        )
        pista = "function NombreFuncion { Write-Host 'texto' }"
        solucion = "function Saludo { Write-Host 'Hola mundo' }"
        explicacion = @"
Las funciones en PowerShell se declaran con 'function':
  function Saludo { Write-Host 'Hola mundo' }
  Saludo     # la ejecutas escribiendo su nombre
En varias lineas:
  function Saludo {
      Write-Host 'Hola mundo'
  }
"@
    },

    @{
        id = "func-param"; nivel = 4; titulo = "Funcion con parametro"
        descripcion = "Crea una funcion Saludo con un parametro `$Nombre que muestre 'Hola' seguido del nombre."
        patrones = @(
            '(?i)^function\s+Saludo\s*\{\s*param\s*\(\s*(\[string\])?\s*\$Nombre\s*\).*Write-Host.*\$Nombre',
            '(?i)^function\s+Saludo\s*\(\s*\$Nombre\s*\)\s*\{.*Write-Host.*\$Nombre'
        )
        errores = @(
            @{ patron = '(?i)function\s+Saludo\s+\$Nombre'; mensaje = "El parametro va dentro de param() o entre parentesis: function Saludo { param(`$Nombre) }" }
        )
        pista = "function Saludo { param(`$Nombre) Write-Host `"Hola `$Nombre`" }"
        solucion = 'function Saludo { param($Nombre) Write-Host "Hola $Nombre" }'
        explicacion = @"
Parametros con param():
  function Saludo {
      param([string]`$Nombre)
      Write-Host "Hola `$Nombre"
  }
  Saludo -Nombre 'Ana'   -> Hola Ana
Tambien se puede escribir asi:
  function Saludo(`$Nombre) { Write-Host "Hola `$Nombre" }
param() es la forma recomendada porque permite mas opciones
(tipos, valores por defecto, validacion, etc.).
"@
    },

    @{
        id = "func-return"; nivel = 4; titulo = "Funcion que devuelve valor"
        descripcion = "Crea una funcion Sumar con parametros `$A y `$B que devuelva la suma."
        patrones = @(
            '(?i)^function\s+Sumar\s*\{?\s*param\s*\(\s*(\[int\])?\s*\$A\s*,\s*(\[int\])?\s*\$B\s*\).*return\s+\$A\s*\+\s*\$B',
            '(?i)^function\s+Sumar\s*\(\s*\$A\s*,\s*\$B\s*\)\s*\{.*return\s+\$A\s*\+\s*\$B'
        )
        errores = @(
            @{ patron = '(?i)Write-Host.*\$A\s*\+\s*\$B'; mensaje = "Write-Host muestra en pantalla pero no devuelve el valor. Usa 'return' para devolver." }
        )
        pista = "function Sumar { param(`$A, `$B) return `$A + `$B }"
        solucion = "function Sumar { param(`$A, `$B) return `$A + `$B }"
        explicacion = @"
'return' devuelve un valor al que llamo la funcion:
  function Sumar { param(`$A, `$B) return `$A + `$B }
  `$resultado = Sumar -A 5 -B 3    # `$resultado = 8
Diferencia clave:
  Write-Host  -> muestra en pantalla, no se puede guardar
  return      -> devuelve el valor, se puede guardar en variable
"@
    },

    @{
        id = "func-switch-param"; nivel = 4; titulo = "Parametro switch (flag)"
        descripcion = "Declara un parametro [switch]`$Detalle dentro de un param()."
        patrones = @(
            '(?i)param\s*\(.*\[switch\]\s*\$Detalle.*\)'
        )
        errores = @(
            @{ patron = '(?i)\[bool\]\s*\$Detalle'; mensaje = "[bool] necesita `$true/`$false. [switch] se activa solo con nombrarlo: -Detalle." }
        )
        pista = "[switch] es un tipo especial para flags: param([switch]`$Detalle)."
        solucion = "param([switch]`$Detalle)"
        explicacion = @"
[switch] crea un parametro tipo flag (encendido/apagado):
  function Info {
      param([switch]`$Detalle)
      if (`$Detalle) { Write-Host 'Modo detallado' }
  }
  Info              -> no muestra nada
  Info -Detalle     -> 'Modo detallado'
No necesita valor, con nombrarlo se activa. Es lo que usan
cmdlets como Get-ChildItem -Recurse o Test-Connection -Quiet.
"@
    },

    @{
        id = "read-host"; nivel = 4; titulo = "Leer input del usuario"
        descripcion = "Lee un nombre del usuario y guardalo en `$nombre usando Read-Host."
        patrones = @(
            '(?i)^\$nombre\s*=\s*Read-Host'
        )
        errores = @(
            @{ patron = '(?i)^Read-Host'; mensaje = "Tienes que guardar el resultado: `$nombre = Read-Host 'texto'." }
            @{ patron = '(?i)^input\('; mensaje = "'input()' es de Python. En PowerShell se usa Read-Host." }
            @{ patron = '(?i)^scanf|^cin'; mensaje = "Eso es de C/C++. En PowerShell se usa: `$nombre = Read-Host 'Pregunta'." }
        )
        pista = "`$variable = Read-Host 'mensaje para el usuario'."
        solucion = "`$nombre = Read-Host '¿Como te llamas?'"
        explicacion = @"
Read-Host lee texto del teclado:
  `$nombre = Read-Host 'Como te llamas'
  `$pass = Read-Host 'Password' -AsSecureString  # oculta lo escrito
El texto entre comillas es el mensaje que ve el usuario.
Lo que escribe se guarda en la variable.
"@
    },

    @{
        id = "string-subexp"; nivel = 4; titulo = "Subexpresion en string"
        descripcion = "Escribe un string que muestre: Tiene 3 frutas, usando `$frutas.Count dentro del string."
        patrones = @(
            '(?i)["]Tiene\s+\$\(\s*\$frutas\.Count\s*\)\s+frutas["]'
        )
        errores = @(
            @{ patron = '(?i)["]Tiene\s+\$frutas\.Count\s+frutas["]'; mensaje = "Para propiedades dentro de un string necesitas `$(): `"Tiene `$(`$frutas.Count) frutas`"." }
        )
        pista = "Dentro de comillas dobles, para acceder a propiedades usa `$(): `$(`$var.Propiedad)."
        solucion = '"Tiene $($frutas.Count) frutas"'
        explicacion = @"
Dentro de comillas dobles:
  `"Hola `$nombre`"               -> interpola variables simples
  `"Tiene `$(`$frutas.Count) frutas`"  -> necesita `$() para propiedades
  `"Son `$(2 + 3) euros`"          -> tambien para calculos
`$() es la subexpresion: evalua lo de dentro y pone el resultado.
Sin `$(), PowerShell no sabe donde acaba la variable.
"@
    },

    @{
        id = "operador-and"; nivel = 4; titulo = "Operador logico AND"
        descripcion = "Escribe una condicion: `$edad mayor o igual que 18 Y `$permiso igual a `$true."
        patrones = @(
            '(?i)\$edad\s+-ge\s+18.*-and.*\$permiso(\s+-eq\s+\$true)?',
            '(?i)\$permiso.*-and.*\$edad\s+-ge\s+18'
        )
        errores = @(
            @{ patron = '(?i)\&\&'; mensaje = "&& es de Bash/JavaScript. En PowerShell el operador AND es -and." }
            @{ patron = '(?i)\band\b(?<!-and)'; mensaje = "El operador es -and (con guion delante), no 'and' solo." }
        )
        pista = "Los operadores logicos llevan guion: -and, -or, -not."
        solucion = "(`$edad -ge 18) -and (`$permiso -eq `$true)"
        explicacion = @"
Operadores logicos en PowerShell:
  -and   -> Y logico: ambas deben ser verdaderas
  -or    -> O logico: al menos una verdadera
  -not   -> negacion (tambien ! como atajo)
Ejemplo:
  if ((`$edad -ge 18) -and (`$permiso)) { Write-Host 'Acceso' }
Los parentesis no son obligatorios pero ayudan a leer.
"@
    },

    @{
        id = "range-rapido"; nivel = 4; titulo = "Rango rapido con .."
        descripcion = "Genera los numeros del 1 al 20 usando el operador de rango."
        patrones = @(
            '(?i)^1\.\.20$'
        )
        errores = @(
            @{ patron = '(?i)^seq\s'; mensaje = "'seq' es de Linux. En PowerShell el rango es: 1..20 (dos puntos)." }
            @{ patron = '(?i)^for\s'; mensaje = "Funciona, pero hay una forma mucho mas corta: el operador de rango (..)." }
        )
        pista = "El operador de rango son dos puntos: inicio..fin."
        solucion = "1..20"
        explicacion = @"
El operador de rango (..) genera una secuencia de numeros:
  1..10       -> 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
  5..1        -> 5, 4, 3, 2, 1 (inverso)
  1..10 | ForEach-Object { `$_ * 2 }  -> 2, 4, 6, 8...
Muy util para bucles rapidos:
  1..100 | ForEach-Object { Write-Host `$_ }
"@
    },

    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 5 · SCRIPTING APLICADO: ARCHIVOS, JSON, SYSADMIN (22 retos)
    # Objetivo: scripts utiles para administracion de sistemas
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "set-content"; nivel = 5; titulo = "Escribir texto en archivo"
        descripcion = "Escribe el texto 'Hola mundo' en un archivo llamado salida.txt."
        patrones = @(
            '(?i)^[''"]Hola\s+mundo[''"].*\|\s*Set-Content\s+[''"]?salida\.txt[''"]?',
            '(?i)^Set-Content\s+[''"]?salida\.txt[''"]?\s+-Value\s+[''"]Hola\s+mundo[''"]'
        )
        errores = @(
            @{ patron = '(?i)echo\s.*>\s'; mensaje = "'echo > archivo' es de CMD. En PowerShell: 'texto' | Set-Content archivo.txt." }
        )
        pista = "'texto' | Set-Content archivo.txt. El pipe envia el texto al archivo."
        solucion = "'Hola mundo' | Set-Content salida.txt"
        explicacion = @"
Escribir en archivos:
  'texto' | Set-Content archivo.txt       -> sobreescribe
  'texto' | Add-Content archivo.txt       -> añade al final
  Set-Content archivo.txt -Value 'texto'  -> forma alternativa
Set-Content SOBREESCRIBE todo el contenido.
Add-Content AÑADE al final sin borrar lo anterior.
"@
    },

    @{
        id = "get-content"; nivel = 5; titulo = "Leer archivo a variable"
        descripcion = "Lee el archivo datos.txt y guarda su contenido en `$datos."
        patrones = @(
            '(?i)^\$datos\s*=\s*Get-Content\s+[''"]?datos\.txt[''"]?'
        )
        errores = @(
            @{ patron = '(?i)^cat\s'; mensaje = "'cat' funciona como alias, pero aprende la forma nativa: `$datos = Get-Content datos.txt." }
            @{ patron = '(?i)^type\s'; mensaje = "'type' es de CMD. En PowerShell usa Get-Content." }
        )
        pista = "`$variable = Get-Content 'archivo.txt'."
        solucion = "`$datos = Get-Content datos.txt"
        explicacion = @"
Get-Content lee un archivo:
  `$datos = Get-Content datos.txt           -> array de lineas
  `$datos = Get-Content datos.txt -Raw      -> todo como un string
  `$datos = Get-Content datos.txt -Tail 5   -> ultimas 5 lineas
Sin -Raw, cada linea del archivo es un elemento del array:
  `$datos[0]      -> primera linea
  `$datos.Count   -> numero de lineas
"@
    },

    @{
        id = "test-path"; nivel = 5; titulo = "Comprobar si existe archivo"
        descripcion = "Comprueba si existe el archivo config.txt usando Test-Path."
        patrones = @(
            '(?i)^Test-Path\s+[''"]?config\.txt[''"]?$',
            '(?i)^if\s*\(\s*Test-Path\s+[''"]?config\.txt[''"]?\s*\)'
        )
        errores = @(
            @{ patron = '(?i)^if\s+exist\s'; mensaje = "'if exist' es de CMD. En PowerShell se usa Test-Path." }
            @{ patron = '(?i)File\.Exists'; mensaje = "Eso es C#/.NET. En PowerShell el cmdlet nativo es Test-Path." }
        )
        pista = "Test-Path devuelve `$true o `$false. Sirve para archivos Y carpetas."
        solucion = "Test-Path config.txt"
        explicacion = @"
Test-Path comprueba si algo existe:
  Test-Path 'archivo.txt'           -> `$true / `$false
  Test-Path 'C:\MiCarpeta'          -> funciona con carpetas tambien
  Test-Path 'C:\*.log'              -> acepta comodines
Uso tipico:
  if (Test-Path config.txt) {
      `$config = Get-Content config.txt
  } else {
      Write-Host 'No existe el archivo'
  }
"@
    },

    @{
        id = "json-guardar"; nivel = 5; titulo = "Guardar datos como JSON"
        descripcion = "Convierte `$datos a JSON y guardalo en datos.json (una linea con pipe)."
        patrones = @(
            '(?i)^\$datos\s*\|\s*ConvertTo-Json\s*\|\s*Set-Content\s+[''"]?datos\.json[''"]?'
        )
        errores = @(
            @{ patron = '(?i)json\.stringify'; mensaje = "JSON.stringify es de JavaScript. En PowerShell: ConvertTo-Json." }
            @{ patron = '(?i)ConvertTo-Json.*>\s'; mensaje = "Funciona, pero la forma PowerShell es con pipe: | Set-Content archivo.json." }
        )
        pista = "`$datos | ConvertTo-Json | Set-Content archivo.json. Dos pipes encadenados."
        solucion = "`$datos | ConvertTo-Json | Set-Content datos.json"
        explicacion = @"
Guardar datos estructurados como JSON:
  `$datos | ConvertTo-Json | Set-Content datos.json
El pipeline encadena tres pasos:
  1. `$datos              -> el objeto original
  2. ConvertTo-Json       -> lo convierte a texto JSON
  3. Set-Content          -> lo escribe en el archivo
Para JSON con objetos anidados, añade -Depth:
  `$datos | ConvertTo-Json -Depth 5 | Set-Content datos.json
"@
    },

    @{
        id = "json-cargar"; nivel = 5; titulo = "Cargar JSON desde archivo"
        descripcion = "Lee datos.json y conviertelo a objeto PowerShell, guardandolo en `$datos."
        patrones = @(
            '(?i)^\$datos\s*=\s*Get-Content\s+[''"]?datos\.json[''"]?\s+-Raw\s*\|\s*ConvertFrom-Json',
            '(?i)^\$datos\s*=\s*Get-Content\s+[''"]?datos\.json[''"]?\s*\|\s*ConvertFrom-Json'
        )
        errores = @(
            @{ patron = '(?i)json\.parse'; mensaje = "JSON.parse es de JavaScript. En PowerShell: ConvertFrom-Json." }
            @{ patron = '(?i)Import-Json'; mensaje = "Import-Json no existe. Se usa: Get-Content archivo | ConvertFrom-Json." }
        )
        pista = "`$datos = Get-Content datos.json -Raw | ConvertFrom-Json."
        solucion = "`$datos = Get-Content datos.json -Raw | ConvertFrom-Json"
        explicacion = @"
Cargar JSON:
  `$datos = Get-Content datos.json -Raw | ConvertFrom-Json
El -Raw es importante: lee todo como un solo string en vez
de un array de lineas, que es lo que ConvertFrom-Json espera.
Una vez cargado, accedes a los datos como propiedades:
  `$datos.nombre      -> valor de la clave 'nombre'
  `$datos.usuarios    -> array si era un array en el JSON
"@
    },

    @{
        id = "try-catch"; nivel = 5; titulo = "Try/Catch basico"
        descripcion = "Escribe un try/catch que intente leer noexiste.txt y capture el error."
        patrones = @(
            '(?i)^try\s*\{.*Get-Content\s+[''"]?noexiste\.txt[''"]?.*-ErrorAction\s+Stop.*\}\s*catch\s*\{'
        )
        errores = @(
            @{ patron = '(?i)^try\s*\{.*\}.*catch(?!.*\{)'; mensaje = "Falta la llave de apertura del catch: try { ... } catch { ... }." }
            @{ patron = '(?i)Get-Content(?!.*-ErrorAction)'; mensaje = "Sin -ErrorAction Stop el error no entra en el catch. Añade -ErrorAction Stop." }
        )
        pista = "try { Get-Content noexiste.txt -ErrorAction Stop } catch { Write-Host 'Error' }"
        solucion = "try { Get-Content noexiste.txt -ErrorAction Stop } catch { Write-Host `$_.Exception.Message }"
        explicacion = @"
try/catch captura errores:
  try {
      Get-Content noexiste.txt -ErrorAction Stop
  } catch {
      Write-Host "Error: `$(`$_.Exception.Message)"
  }
-ErrorAction Stop es CLAVE: sin el, PowerShell muestra el error
pero NO entra en el catch. Stop convierte el error en excepcion.
Dentro del catch, `$_ contiene el error:
  `$_.Exception.Message   -> texto del error
"@
    },

    @{
        id = "new-item-dir"; nivel = 5; titulo = "Crear carpeta"
        descripcion = "Crea una carpeta llamada Backup usando New-Item."
        patrones = @(
            '(?i)^New-Item\s+[''"]?Backup[''"]?\s+-ItemType\s+Directory',
            '(?i)^mkdir\s+[''"]?Backup[''"]?$',
            '(?i)^ni\s+[''"]?Backup[''"]?\s+-ItemType\s+Directory'
        )
        errores = @(
            @{ patron = '(?i)^md\s'; mensaje = "'md' es de CMD. En PowerShell usa New-Item -ItemType Directory o mkdir." }
        )
        pista = "New-Item NombreCarpeta -ItemType Directory. O el atajo: mkdir NombreCarpeta."
        solucion = "New-Item Backup -ItemType Directory"
        explicacion = @"
Crear carpetas:
  New-Item Backup -ItemType Directory
  mkdir Backup                              -> alias, mas corto
  New-Item 'C:\Datos\Backup' -ItemType Directory  -> ruta completa
-ItemType Directory es lo que indica que es una carpeta y no un archivo.
mkdir es un alias especial que ya incluye -ItemType Directory.
"@
    },

    @{
        id = "copy-item"; nivel = 5; titulo = "Copiar archivo"
        descripcion = "Copia el archivo original.txt a copia.txt."
        patrones = @(
            '(?i)^Copy-Item\s+[''"]?original\.txt[''"]?\s+[''"]?copia\.txt[''"]?',
            '(?i)^cp\s+[''"]?original\.txt[''"]?\s+[''"]?copia\.txt[''"]?',
            '(?i)^copy\s+[''"]?original\.txt[''"]?\s+[''"]?copia\.txt[''"]?'
        )
        errores = @()
        pista = "Copy-Item origen destino. El alias corto es cp."
        solucion = "Copy-Item original.txt copia.txt"
        explicacion = @"
Operaciones con archivos:
  Copy-Item origen destino    (alias: cp, copy)
  Move-Item origen destino    (alias: mv, move)
  Remove-Item archivo         (alias: rm, del)
  Rename-Item viejo nuevo     (alias: ren)
Copy-Item tambien copia carpetas con -Recurse:
  Copy-Item MiCarpeta Backup -Recurse
"@
    },

    @{
        id = "get-date-format"; nivel = 5; titulo = "Fecha con formato"
        descripcion = "Obtén la fecha actual en formato yyyy-MM-dd (ejemplo: 2026-10-04)."
        patrones = @(
            '(?i)^Get-Date\s+-Format\s+[''"]yyyy-MM-dd[''"]',
            '(?i)^\(Get-Date\)\.ToString\([''"]yyyy-MM-dd[''"]'
        )
        errores = @(
            @{ patron = '(?i)^date$'; mensaje = "'date' funciona pero devuelve formato largo. Usa Get-Date -Format 'yyyy-MM-dd'." }
            @{ patron = '(?i)Get-Date.*dd/MM'; mensaje = "Casi, pero el formato pedido es yyyy-MM-dd (con guiones, año primero)." }
        )
        pista = "Get-Date -Format 'yyyy-MM-dd'. Las letras del formato: y=año, M=mes, d=dia."
        solucion = "Get-Date -Format 'yyyy-MM-dd'"
        explicacion = @"
Formatos de fecha comunes:
  Get-Date -Format 'yyyy-MM-dd'          -> 2026-10-04
  Get-Date -Format 'dd/MM/yyyy'          -> 04/10/2026
  Get-Date -Format 'HH:mm:ss'           -> 14:30:25
  Get-Date -Format 'yyyy-MM-dd_HH-mm'   -> 2026-10-04_14-30
Muy util para nombres de archivos de backup o logs:
  `$fecha = Get-Date -Format 'yyyy-MM-dd'
  `$nombre = 'backup_' + `$fecha + '.zip'
"@
    },

    @{
        id = "secure-string"; nivel = 5; titulo = "Crear SecureString para password"
        descripcion = "Convierte el texto 'Pass123!' a SecureString y guardalo en `$pass."
        patrones = @(
            '(?i)^\$pass\s*=\s*ConvertTo-SecureString\s+[''"]Pass123![''"].*-AsPlainText.*-Force',
            '(?i)^\$pass\s*=\s*ConvertTo-SecureString.*-String\s+[''"]Pass123![''"].*-AsPlainText.*-Force'
        )
        errores = @(
            @{ patron = '(?i)ConvertTo-SecureString(?!.*-Force)'; mensaje = "Falta -Force. Sin el, PowerShell te advierte que no es seguro y no lo hace." }
            @{ patron = '(?i)ConvertTo-SecureString(?!.*-AsPlainText)'; mensaje = "Falta -AsPlainText. Indica que le estas pasando texto plano para convertir." }
        )
        pista = "ConvertTo-SecureString 'texto' -AsPlainText -Force. Necesita ambos flags."
        solucion = "`$pass = ConvertTo-SecureString 'Pass123!' -AsPlainText -Force"
        explicacion = @"
Muchos cmdlets de seguridad necesitan SecureString, no texto plano:
  `$pass = ConvertTo-SecureString 'Pass123!' -AsPlainText -Force
  -AsPlainText: le dices que el input es texto normal
  -Force: confirma que sabes que es inseguro en un script
Para leer password oculta del usuario (mas seguro):
  `$pass = Read-Host 'Password' -AsSecureString
"@
    },

    @{
        id = "new-localuser"; nivel = 5; titulo = "Crear usuario local"
        descripcion = "Crea un usuario local llamado alumno01 con password `$pass y nombre completo 'Alumno Uno'."
        patrones = @(
            '(?i)^New-LocalUser\s+-Name\s+[''"]?alumno01[''"]?\s+-Password\s+\$pass\s+-FullName\s+[''"]Alumno Uno[''"]',
            '(?i)^New-LocalUser.*alumno01.*-Password\s+\$pass.*-FullName\s+[''"]Alumno Uno[''"]',
            '(?i)^New-LocalUser.*-Name\s+[''"]?alumno01[''"]?.*-Password\s+\$pass'
        )
        errores = @(
            @{ patron = '(?i)^net\s+user'; mensaje = "'net user' es de CMD. En PowerShell usa New-LocalUser." }
            @{ patron = '(?i)^useradd'; mensaje = "'useradd' es de Linux. En Windows PowerShell: New-LocalUser." }
            @{ patron = '(?i)^New-ADUser'; mensaje = "New-ADUser es para Active Directory. Para usuarios locales: New-LocalUser." }
        )
        pista = "New-LocalUser -Name 'usuario' -Password `$pass -FullName 'Nombre Completo'."
        solucion = "New-LocalUser -Name 'alumno01' -Password `$pass -FullName 'Alumno Uno'"
        explicacion = @"
Gestion de usuarios locales:
  New-LocalUser -Name 'alumno01' -Password `$pass -FullName 'Alumno Uno'
  Get-LocalUser                          -> listar usuarios
  Set-LocalUser -Name 'x' -Password `$p  -> cambiar password
  Enable-LocalUser -Name 'x'            -> activar
  Disable-LocalUser -Name 'x'           -> desactivar
  Remove-LocalUser -Name 'x'            -> eliminar
Recuerda: `$pass tiene que ser SecureString, no texto plano.
"@
    },

    @{
        id = "new-localgroup"; nivel = 5; titulo = "Crear grupo local"
        descripcion = "Crea un grupo local llamado Alumnos."
        patrones = @(
            '(?i)^New-LocalGroup\s+-Name\s+[''"]?Alumnos[''"]?',
            '(?i)^New-LocalGroup\s+[''"]?Alumnos[''"]?'
        )
        errores = @(
            @{ patron = '(?i)^net\s+localgroup\s+/add'; mensaje = "'net localgroup /add' es de CMD. En PowerShell: New-LocalGroup." }
            @{ patron = '(?i)^groupadd'; mensaje = "'groupadd' es de Linux. En Windows PowerShell: New-LocalGroup." }
        )
        pista = "New-LocalGroup -Name 'NombreGrupo'."
        solucion = "New-LocalGroup -Name 'Alumnos'"
        explicacion = @"
Gestion de grupos locales:
  New-LocalGroup -Name 'Alumnos'
  Get-LocalGroup                          -> listar grupos
  Remove-LocalGroup -Name 'Alumnos'      -> eliminar grupo
  Get-LocalGroupMember -Group 'Alumnos'   -> ver miembros
"@
    },

    @{
        id = "add-groupmember"; nivel = 5; titulo = "Añadir usuario a grupo"
        descripcion = "Añade el usuario alumno01 al grupo Alumnos."
        patrones = @(
            '(?i)^Add-LocalGroupMember\s+-Group\s+[''"]?Alumnos[''"]?\s+-Member\s+[''"]?alumno01[''"]?'
        )
        errores = @(
            @{ patron = '(?i)^net\s+localgroup.*\/add'; mensaje = "'net localgroup /add' es de CMD. En PowerShell: Add-LocalGroupMember." }
            @{ patron = '(?i)^usermod'; mensaje = "'usermod' es de Linux. En Windows PowerShell: Add-LocalGroupMember." }
        )
        pista = "Add-LocalGroupMember -Group 'grupo' -Member 'usuario'."
        solucion = "Add-LocalGroupMember -Group 'Alumnos' -Member 'alumno01'"
        explicacion = @"
Gestion de miembros de grupo:
  Add-LocalGroupMember -Group 'Alumnos' -Member 'alumno01'
  Remove-LocalGroupMember -Group 'Alumnos' -Member 'alumno01'
  Get-LocalGroupMember -Group 'Alumnos'
Se pueden añadir varios a la vez:
  Add-LocalGroupMember -Group 'Alumnos' -Member 'alumno01','alumno02','alumno03'
"@
    },

    @{
        id = "get-service-filter"; nivel = 5; titulo = "Filtrar servicios parados"
        descripcion = "Lista los servicios que estan parados (Status 'Stopped')."
        patrones = @(
            '(?i)^Get-Service\s*\|\s*Where-Object\s*\{.*Status\s+-eq\s+[''"]Stopped[''"].*\}',
            '(?i)^Get-Service\s*\|\s*Where\s*\{.*Status\s+-eq\s+[''"]Stopped[''"].*\}',
            '(?i)^Get-Service\s*\|\s*\?\s*\{.*Status\s+-eq\s+[''"]Stopped[''"].*\}'
        )
        errores = @(
            @{ patron = '(?i)^Get-Service\s+-Status'; mensaje = "Get-Service no tiene parametro -Status. Usa pipeline: Get-Service | Where-Object { ... }." }
        )
        pista = "Get-Service | Where-Object { `$_.Status -eq 'Stopped' }. `$_ es el objeto actual."
        solucion = "Get-Service | Where-Object { `$_.Status -eq 'Stopped' }"
        explicacion = @"
Filtrar servicios con pipeline:
  Get-Service | Where-Object { `$_.Status -eq 'Stopped' }
  Get-Service | Where-Object { `$_.Status -eq 'Running' }
Gestion de servicios:
  Start-Service 'NombreServicio'
  Stop-Service 'NombreServicio'
  Restart-Service 'NombreServicio'
`$_ dentro del Where-Object es cada servicio que pasa por el pipeline.
"@
    },

    @{
        id = "start-service"; nivel = 5; titulo = "Arrancar un servicio"
        descripcion = "Arranca el servicio Spooler (cola de impresion)."
        patrones = @(
            '(?i)^Start-Service\s+[''"]?Spooler[''"]?$',
            '(?i)^Start-Service\s+-Name\s+[''"]?Spooler[''"]?$'
        )
        errores = @(
            @{ patron = '(?i)^net\s+start'; mensaje = "'net start' es de CMD. En PowerShell: Start-Service." }
            @{ patron = '(?i)^systemctl\s+start'; mensaje = "'systemctl' es de Linux. En Windows PowerShell: Start-Service." }
        )
        pista = "Start-Service 'NombreDelServicio'. Asi de simple."
        solucion = "Start-Service Spooler"
        explicacion = @"
Gestion de servicios:
  Start-Service Spooler       -> arrancar
  Stop-Service Spooler        -> parar
  Restart-Service Spooler     -> reiniciar
  Get-Service Spooler         -> ver estado
  Set-Service Spooler -StartupType Automatic  -> arranque automatico
Equivalencias con CMD:
  net start Spooler    ->  Start-Service Spooler
  net stop Spooler     ->  Stop-Service Spooler
"@
    },

    @{
        id = "stop-process"; nivel = 5; titulo = "Matar proceso por nombre"
        descripcion = "Mata todos los procesos de notepad."
        patrones = @(
            '(?i)^Stop-Process\s+-Name\s+[''"]?notepad[''"]?$',
            '(?i)^Get-Process\s+[''"]?notepad[''"]?\s*\|\s*Stop-Process'
        )
        errores = @(
            @{ patron = '(?i)^kill\s'; mensaje = "'kill' es de Linux. En PowerShell: Stop-Process -Name notepad." }
            @{ patron = '(?i)^taskkill'; mensaje = "'taskkill' es de CMD. En PowerShell: Stop-Process." }
        )
        pista = "Stop-Process -Name 'nombreProceso'."
        solucion = "Stop-Process -Name notepad"
        explicacion = @"
Gestion de procesos:
  Get-Process                     -> listar todos
  Get-Process notepad             -> uno concreto
  Stop-Process -Name notepad      -> matar por nombre
  Stop-Process -Id 1234           -> matar por PID
Tambien con pipeline:
  Get-Process notepad | Stop-Process
"@
    },

    @{
        id = "test-connection"; nivel = 5; titulo = "Hacer ping"
        descripcion = "Haz ping a google.com con 4 paquetes."
        patrones = @(
            '(?i)^Test-Connection\s+[''"]?google\.com[''"]?\s+-Count\s+4',
            '(?i)^Test-Connection\s+-ComputerName\s+[''"]?google\.com[''"]?\s+-Count\s+4'
        )
        errores = @(
            @{ patron = '(?i)^ping\s'; mensaje = "'ping' funciona pero es el comando de CMD. El cmdlet PowerShell es Test-Connection." }
        )
        pista = "Test-Connection google.com -Count 4. Count es el numero de paquetes."
        solucion = "Test-Connection google.com -Count 4"
        explicacion = @"
Test-Connection es el ping de PowerShell:
  Test-Connection google.com -Count 4
  Test-Connection google.com -Quiet        -> solo `$true/`$false
  Test-Connection servidor1,servidor2      -> ping a varios
-Quiet es muy util en scripts: devuelve `$true si responde,
`$false si no. Perfecto para comprobar conectividad en un if.
"@
    },

    @{
        id = "get-volume"; nivel = 5; titulo = "Ver espacio en disco"
        descripcion = "Muestra informacion de los volumenes/particiones del sistema."
        patrones = @(
            '(?i)^Get-Volume$'
        )
        errores = @(
            @{ patron = '(?i)^Get-Disk$'; mensaje = "Get-Disk muestra discos fisicos. Para ver particiones y espacio libre: Get-Volume." }
            @{ patron = '(?i)^df\s'; mensaje = "'df' es de Linux. En PowerShell: Get-Volume." }
        )
        pista = "Get-Volume muestra todas las particiones con su espacio libre."
        solucion = "Get-Volume"
        explicacion = @"
Almacenamiento:
  Get-Volume        -> volumenes con letra, tamaño y espacio libre
  Get-Disk          -> discos fisicos
  Get-Partition     -> particiones de cada disco
Para ver solo el espacio libre formateado:
  Get-Volume | Where-Object { `$_.DriveLetter } |
    Select-Object DriveLetter,
      @{N='LibreGB';E={[math]::Round(`$_.SizeRemaining/1GB,1)}}
"@
    },

    @{
        id = "export-csv"; nivel = 5; titulo = "Exportar a CSV"
        descripcion = "Exporta los procesos a un archivo procesos.csv."
        patrones = @(
            '(?i)^Get-Process\s*\|\s*Export-Csv\s+[''"]?procesos\.csv[''"]?',
            '(?i)^Get-Process\s*\|\s*Export-Csv\s+[''"]?procesos\.csv[''"]?\s+-NoTypeInformation'
        )
        errores = @(
            @{ patron = '(?i)ConvertTo-Csv.*Set-Content'; mensaje = "Funciona, pero Export-Csv es mas directo: Get-Process | Export-Csv procesos.csv." }
        )
        pista = "Get-Process | Export-Csv procesos.csv. Directo con pipeline."
        solucion = "Get-Process | Export-Csv procesos.csv -NoTypeInformation"
        explicacion = @"
Exportar datos:
  Get-Process | Export-Csv procesos.csv -NoTypeInformation
  -NoTypeInformation quita la primera linea con el tipo de objeto.
  Sin este flag, el CSV empieza con #TYPE System.Diagnostics.Process
Importar CSV:
  `$datos = Import-Csv procesos.csv
  `$datos[0].Name       -> nombre del primer proceso
Export-Csv e Import-Csv son la pareja para mover datos entre
PowerShell y Excel/herramientas que lean CSV.
"@
    },

    @{
        id = "set-alias"; nivel = 5; titulo = "Crear un alias personalizado"
        descripcion = "Crea un alias llamado procesos que ejecute Get-Process."
        patrones = @(
            '(?i)^Set-Alias\s+[''"]?procesos[''"]?\s+Get-Process',
            '(?i)^Set-Alias\s+-Name\s+[''"]?procesos[''"]?\s+-Value\s+Get-Process'
        )
        errores = @(
            @{ patron = '(?i)^alias\s'; mensaje = "'alias' es de Linux. En PowerShell se usa Set-Alias." }
            @{ patron = '(?i)^New-Alias'; mensaje = "New-Alias existe pero da error si ya existe. Set-Alias crea o sobreescribe. Usa Set-Alias." }
        )
        pista = "Set-Alias nombreCorto ComandoReal."
        solucion = "Set-Alias procesos Get-Process"
        explicacion = @"
Alias personalizados:
  Set-Alias procesos Get-Process
  procesos    # ahora esto ejecuta Get-Process
Para que sea permanente, añadelo a tu `$PROFILE:
  Set-Alias procesos Get-Process -Scope Global
Ver todos los alias: Get-Alias
Ver un alias concreto: Get-Alias procesos
Borrar alias: Remove-Item Alias:\procesos
"@
    }

    )
}

# ── UI del reto ───────────────────────────────────────────────────────

$global:Pw2Activo = $null
$global:Pw2Intentos = 0

function Show-Pw2Banner {
    param([hashtable]$Reto)
    $nivelNombre = switch ($Reto.nivel) {
        4 { "Variables y funciones" }
        5 { "Scripting aplicado" }
    }
    $caja = Get-Pw2Caja $Reto.id
    $cajaStr = if ($caja -gt 0) { " [caja $caja/5]" } else { " [nuevo]" }
    Write-Host ""
    Write-Host "  +============================================+" -ForegroundColor DarkGreen
    Write-Host "  |  PWSHELL2 ·  Scripting avanzado            |" -ForegroundColor Green
    Write-Host "  |  Nivel $($Reto.nivel) · $nivelNombre$(' ' * (26 - $nivelNombre.Length))|" -ForegroundColor Green
    Write-Host "  |  > $($Reto.titulo)$(' ' * (37 - $Reto.titulo.Length))$cajaStr |" -ForegroundColor Yellow
    Write-Host "  +============================================+" -ForegroundColor DarkGreen
    Write-Host ""
}

function Show-Pw2Descripcion {
    param([hashtable]$Reto)
    $lineas = $Reto.descripcion -split "`n"
    foreach ($linea in $lineas) {
        Write-Host "  $($linea.TrimEnd())" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  Escribe el codigo directamente. Ayuda: " -ForegroundColor DarkGray -NoNewline
    Write-Host "p (pista)  s (solucion)  salir  ayuda" -ForegroundColor Gray
    Write-Host ""
}

function Get-Pw2Siguiente {
    $banco = Get-Pw2Banco
    $prog = Get-Pw2Progreso
    $repasos = $banco | Where-Object { Test-Pw2Due $_.id } | Where-Object {
        $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0 -and $prog[$_.id].caja -lt 5
    }
    if ($repasos.Count -gt 0) {
        return ($repasos | Sort-Object { (Get-Pw2Caja $_.id) } | Select-Object -First 1)
    }
    $nuevo = $banco | Where-Object { -not $prog.ContainsKey($_.id) } | Select-Object -First 1
    return $nuevo
}

function Enter-Pw2Loop {
    param([hashtable]$Reto)

    $global:Pw2Activo = $Reto
    $global:Pw2Intentos = 0
    Show-Pw2Banner $Reto
    Show-Pw2Descripcion $Reto

    while ($global:Pw2Activo) {
        Write-Host "  PS2> " -NoNewline -ForegroundColor DarkGreen
        try {
            $resp = Read-Host
        } catch {
            $global:Pw2Activo = $null
            break
        }
        if ($null -eq $resp) { $global:Pw2Activo = $null; break }
        $resp = $resp.Trim()
        if ($resp -eq '') { continue }

        $lower = $resp.ToLower()
        if ($lower -eq 'p' -or $lower -eq 'pista') {
            Show-Pw2Pista
        } elseif ($lower -eq 's' -or $lower -eq 'solucion') {
            Show-Pw2Solucion
            $sig = Get-Pw2Siguiente
            if ($sig) {
                $global:Pw2Activo = $sig
                $global:Pw2Intentos = 0
                Show-Pw2Banner $sig
                Show-Pw2Descripcion $sig
            } else {
                Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
                Write-Host "  Usa 'pwshell2 -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
            }
        } elseif ($lower -eq 'salir' -or $lower -eq 'exit' -or $lower -eq 'q') {
            Exit-Pw2
        } elseif ($lower -eq 'ayuda') {
            Write-Host ""
            Write-Host "  Escribe el codigo PowerShell directamente como respuesta." -ForegroundColor Gray
            Write-Host ""
            Write-Host "  p / pista      Ver pista" -ForegroundColor DarkGray
            Write-Host "  s / solucion   Ver solucion (cuenta como fallo)" -ForegroundColor DarkGray
            Write-Host "  salir          Abandonar el reto actual" -ForegroundColor DarkGray
            Write-Host "  lista          Ver todos los retos" -ForegroundColor DarkGray
            Write-Host "  stats          Ver estadisticas" -ForegroundColor DarkGray
            Write-Host ""
        } elseif ($lower -eq 'lista') {
            Invoke-PwShell2 -Lista
        } elseif ($lower -eq 'stats') {
            Show-Pw2Stats
        } else {
            Invoke-Pw2Responder $resp
            if (-not $global:Pw2Activo) {
                $sig = Get-Pw2Siguiente
                if ($sig) {
                    $global:Pw2Activo = $sig
                    $global:Pw2Intentos = 0
                    Show-Pw2Banner $sig
                    Show-Pw2Descripcion $sig
                } else {
                    Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
                    Write-Host "  Usa 'pwshell2 -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
                }
            }
        }
    }
}

function Invoke-PwShell2 {
    [CmdletBinding()]
    param(
        [int]$Nivel,
        [string]$Id,
        [switch]$Lista,
        [switch]$Repaso,
        [switch]$Reiniciar,
        [switch]$Stats
    )

    $banco = Get-Pw2Banco

    if ($Reiniciar) {
        $path = Get-Pw2ProgresoPath
        if (Test-Path $path) { Remove-Item $path -Force }
        Write-Host "`n  Progreso reiniciado.`n" -ForegroundColor Yellow
        return
    }

    if ($Stats) {
        Show-Pw2Stats
        return
    }

    if ($Lista) {
        $filtrados = if ($Nivel -gt 0) { $banco | Where-Object { $_.nivel -eq $Nivel } } else { $banco }
        $prog = Get-Pw2Progreso
        $hoy = (Get-Date).ToString("yyyy-MM-dd")

        $nivelActual = 0
        foreach ($r in $filtrados) {
            if ($r.nivel -ne $nivelActual) {
                $nivelActual = $r.nivel
                $nombre = switch ($nivelActual) {
                    4 { "VARIABLES Y FUNCIONES" }
                    5 { "SCRIPTING APLICADO" }
                }
                Write-Host "`n  === NIVEL $nivelActual · $nombre ===" -ForegroundColor Green
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
        $dominados = ($filtrados | Where-Object { (Get-Pw2Caja $_.id) -ge 5 }).Count
        $pendientes = ($filtrados | Where-Object { Test-Pw2Due $_.id }).Count
        Write-Host "  $dominados/$total dominados · $pendientes pendientes de repaso" -ForegroundColor DarkGreen
        Write-Host ""
        return
    }

    if ($Id) {
        $reto = $banco | Where-Object { $_.id -eq $Id }
        if (-not $reto) {
            Write-Host "`n  Reto '$Id' no encontrado. Usa 'pwshell2 -Lista' para ver todos.`n" -ForegroundColor Red
            return
        }
        Enter-Pw2Loop $reto
        return
    }

    if ($Repaso) {
        $prog = Get-Pw2Progreso
        $pendientes = $banco | Where-Object { Test-Pw2Due $_.id } | Where-Object {
            $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0
        }
        if ($pendientes.Count -eq 0) {
            Write-Host "`n  No tienes retos pendientes de repaso. Buen trabajo!" -ForegroundColor Green
            Write-Host "  Usa 'pwshell2' sin -Repaso para seguir avanzando.`n" -ForegroundColor DarkGray
            return
        }
        $elegido = $pendientes | Sort-Object { (Get-Pw2Caja $_.id) } | Select-Object -First 1
        Write-Host "`n  REPASO" -ForegroundColor Cyan
        Enter-Pw2Loop $elegido
        return
    }

    # Sin parametros: siguiente reto
    $prog = Get-Pw2Progreso
    $repasosPendientes = $banco | Where-Object { Test-Pw2Due $_.id } | Where-Object {
        $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0 -and $prog[$_.id].caja -lt 5
    }
    if ($repasosPendientes.Count -gt 0) {
        $elegido = $repasosPendientes | Sort-Object { (Get-Pw2Caja $_.id) } | Select-Object -First 1
        Write-Host "`n  REPASO pendiente" -ForegroundColor Cyan
        Enter-Pw2Loop $elegido
        return
    }

    $filtro = if ($Nivel -gt 0) { $banco | Where-Object { $_.nivel -eq $Nivel } } else { $banco }
    $nuevo = $filtro | Where-Object { -not $prog.ContainsKey($_.id) } | Select-Object -First 1
    if ($nuevo) {
        Enter-Pw2Loop $nuevo
        return
    }

    Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
    Write-Host "  Usa 'pwshell2 -Repaso' para repasar los que toquen." -ForegroundColor DarkGray
    Write-Host "  Usa 'pwshell2 -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
}

# ── Responder ─────────────────────────────────────────────────────────

function Invoke-Pw2Responder {
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Palabras
    )
    if (-not $global:Pw2Activo) {
        Write-Host "`n  No hay ningun reto activo. Usa 'pwshell2' para empezar.`n" -ForegroundColor Yellow
        return
    }
    $respuesta = ($Palabras -join " ").Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($respuesta)) {
        Write-Host "`n  Escribe tu respuesta directamente.`n" -ForegroundColor Yellow
        return
    }

    $reto = $global:Pw2Activo
    $global:Pw2Intentos++

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
        Register-Pw2Resultado -Codigo $reto.id -Acierto $true
        $cajaNew = Get-Pw2Caja $reto.id
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
        $global:Pw2Activo = $null
    } else {
        Write-Host ""
        Write-Host "  X  Incorrecto" -ForegroundColor Red
        if ($global:Pw2Intentos -ge 2) {
            Write-Host "  Prueba con 'p' para una pista o 's' para ver la solucion." -ForegroundColor DarkGray
        } else {
            Write-Host "  Intentalo otra vez. 'p' te da una pista." -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

function Show-Pw2Pista {
    if (-not $global:Pw2Activo) {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor DarkGray
        return
    }
    if ($global:Pw2Activo.pista) {
        Write-Host "`n  PISTA: $($global:Pw2Activo.pista)`n" -ForegroundColor DarkYellow
    } else {
        Write-Host "`n  Este reto no tiene pista.`n" -ForegroundColor DarkGray
    }
}

function Show-Pw2Solucion {
    if (-not $global:Pw2Activo) {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor DarkGray
        return
    }
    $reto = $global:Pw2Activo
    Register-Pw2Resultado -Codigo $reto.id -Acierto $false

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
    $global:Pw2Activo = $null
}

function Exit-Pw2 {
    if ($global:Pw2Activo) {
        $reto = $global:Pw2Activo
        Register-Pw2Resultado -Codigo $reto.id -Acierto $false
        Write-Host "`n  Saliste de '$($reto.titulo)'. Registrado como no completado.`n" -ForegroundColor DarkGray
    } else {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor DarkGray
    }
    $global:Pw2Activo = $null
}

function Show-Pw2Stats {
    $banco = Get-Pw2Banco
    $prog = Get-Pw2Progreso
    $total = $banco.Count
    $intentados = ($banco | Where-Object { $prog.ContainsKey($_.id) }).Count
    $dominados = ($banco | Where-Object { (Get-Pw2Caja $_.id) -ge 5 }).Count
    $pendientes = ($banco | Where-Object { Test-Pw2Due $_.id } | Where-Object {
        $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0 -and $prog[$_.id].caja -lt 5
    }).Count

    Write-Host ""
    Write-Host "  +==============================+" -ForegroundColor DarkGreen
    Write-Host "  |  PWSHELL2 · Estadisticas     |" -ForegroundColor Green
    Write-Host "  +==============================+" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "  Total de retos:       $total" -ForegroundColor Gray
    Write-Host "  Intentados:           $intentados" -ForegroundColor Gray
    Write-Host "  Dominados (caja 5):   $dominados" -ForegroundColor Green
    Write-Host "  Pendientes de repaso: $pendientes" -ForegroundColor Yellow
    Write-Host "  Sin empezar:          $($total - $intentados)" -ForegroundColor DarkGray

    $cajas = @(0, 0, 0, 0, 0, 0)
    foreach ($r in $banco) {
        $c = Get-Pw2Caja $r.id
        $cajas[$c]++
    }
    Write-Host ""
    Write-Host "  Distribucion por cajas:" -ForegroundColor Gray
    Write-Host "    Nueva:  $($cajas[0])" -ForegroundColor DarkGray
    Write-Host "    Caja 1: $($cajas[1])" -ForegroundColor Red
    Write-Host "    Caja 2: $($cajas[2])" -ForegroundColor Yellow
    Write-Host "    Caja 3: $($cajas[3])" -ForegroundColor DarkYellow
    Write-Host "    Caja 4: $($cajas[4])" -ForegroundColor Cyan
    Write-Host "    Caja 5: $($cajas[5])" -ForegroundColor Green
    Write-Host ""
}

function Show-Pw2Help {
    Write-Host ""
    Write-Host "  =============================" -ForegroundColor DarkGreen
    Write-Host "  PWSHELL2 · Scripting avanzado" -ForegroundColor Green
    Write-Host "  =============================" -ForegroundColor DarkGreen
    Write-Host ""
    $ayuda = @(
        @{ cmd = "pwshell2";            desc = "Siguiente reto (prioriza repasos)" }
        @{ cmd = "pwshell2 -Lista";     desc = "Ver todos los retos y su estado" }
        @{ cmd = "pwshell2 -Nivel 5";   desc = "Retos de un nivel concreto" }
        @{ cmd = "pwshell2 -Id X";      desc = "Ir a un reto concreto por su id" }
        @{ cmd = "pwshell2 -Repaso";    desc = "Solo retos que toca repasar" }
        @{ cmd = "pwshell2 -Stats";     desc = "Ver estadisticas de progreso" }
        @{ cmd = "pwshell2 -Reiniciar"; desc = "Borrar todo el progreso" }
        @{ cmd = "(tu codigo)";         desc = "Escribe directamente en el prompt PS2>" }
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

Set-Alias pwshell2    Invoke-PwShell2    -Scope Global
Set-Alias pw2-ayuda   Show-Pw2Help       -Scope Global
Set-Alias pw2-stats   Show-Pw2Stats      -Scope Global
