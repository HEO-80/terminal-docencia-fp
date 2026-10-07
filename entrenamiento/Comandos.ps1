# ═══════════════════════════════════════════════════════════════════════
# COMANDOS · Practica CMD y scripts .bat
# Sistema de retos interactivos con repaso espaciado (Leitner)
# Compatible con PowerShell 5.1+
# ═══════════════════════════════════════════════════════════════════════

# ── Progreso (Leitner: 5 cajas, intervalos 0/1/3/7/21 dias) ──────────

function Get-CmdProgresoPath {
    Join-Path $HOME ".comandos-progreso.json"
}

function Get-CmdProgreso {
    $path = Get-CmdProgresoPath
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

function Save-CmdProgreso {
    param([hashtable]$Progreso)
    $obj = New-Object PSObject
    foreach ($k in ($Progreso.Keys | Sort-Object)) {
        $obj | Add-Member -MemberType NoteProperty -Name $k -Value $Progreso[$k]
    }
    $obj | ConvertTo-Json -Depth 5 | Set-Content (Get-CmdProgresoPath) -Encoding UTF8
}

function Register-CmdResultado {
    param([string]$Codigo, [bool]$Acierto)
    $prog = Get-CmdProgreso
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
    Save-CmdProgreso $prog
}

function Test-CmdDue {
    param([string]$Codigo)
    $prog = Get-CmdProgreso
    $hoy = (Get-Date).ToString("yyyy-MM-dd")
    if ($prog.ContainsKey($Codigo)) {
        return ([string]$prog[$Codigo].siguiente -le $hoy)
    }
    return $true
}

function Get-CmdCaja {
    param([string]$Codigo)
    $prog = Get-CmdProgreso
    if ($prog.ContainsKey($Codigo)) { return [int]$prog[$Codigo].caja }
    return 0
}

# ── Banco de retos ────────────────────────────────────────────────────

function Get-CmdBanco {
    @(
    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 1 · COMANDOS BASICOS (15 retos)
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "dir-basico"; nivel = 1; titulo = "Listar directorio"
        descripcion = "Escribe el comando CMD que muestra el contenido del directorio actual."
        patrones = @('(?i)^dir\s*$')
        errores = @(
            @{ patron = '(?i)^(ls|gci|Get-ChildItem)'; mensaje = "Eso es PowerShell/Linux. En CMD se usa 'dir'." }
        )
        pista = "Es el comando mas basico de CMD. Tres letras."
        solucion = "dir"
        explicacion = @"
'dir' (directory) muestra archivos y carpetas del directorio actual.
En Linux seria 'ls', en PowerShell 'Get-ChildItem' (alias gci/ls/dir).
La diferencia: en CMD 'dir' devuelve TEXTO, en PowerShell devuelve OBJETOS.
"@
    },

    @{
        id = "dir-extension"; nivel = 1; titulo = "Filtrar por extension"
        descripcion = "Lista solo los archivos con extension .log del directorio actual."
        patrones = @(
            '(?i)^dir\s+"?\*\.log"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^dir\s+\*\.log\s+/'; mensaje = "Casi, pero no necesitas ningun modificador. Solo 'dir *.log'." }
            @{ patron = '(?i)^(ls|gci)'; mensaje = "Eso es PowerShell/Linux. Aqui usamos 'dir'." }
        )
        pista = "Usa el comodin * con la extension: dir *.(extension)"
        solucion = "dir *.log"
        explicacion = @"
El asterisco * es un comodin que significa 'cualquier nombre'.
'dir *.log' muestra todos los archivos cuyo nombre acaba en .log.
Otros ejemplos: 'dir *.txt', 'dir informe*.*' (empieza por 'informe').
"@
    },

    @{
        id = "dir-recursivo"; nivel = 1; titulo = "Busqueda recursiva"
        descripcion = "Busca todos los archivos .txt en el directorio actual y en todas sus subcarpetas."
        patrones = @(
            '(?i)^dir\s+(/s\s+"?\*\.txt"?|"?\*\.txt"?\s+/s)\s*$'
        )
        errores = @(
            @{ patron = '(?i)^dir\s+\*\.txt\s*$'; mensaje = "Eso solo mira la carpeta actual. Necesitas /s para buscar en subcarpetas." }
            @{ patron = '(?i)-[Rr]ecurs'; mensaje = "Eso es PowerShell (-Recurse). En CMD se usa /s." }
        )
        pista = "Necesitas el modificador /s (subdirectorios) junto con el comodin."
        solucion = "dir /s *.txt"
        explicacion = @"
/s hace que 'dir' busque recursivamente en todas las subcarpetas.
Es el equivalente a '-Recurse' de PowerShell o 'find' en Linux.
Otro modificador util: /b (bare) que muestra solo nombres, sin cabeceras.
"@
    },

    @{
        id = "cd-cambiar"; nivel = 1; titulo = "Cambiar directorio"
        descripcion = "Cambia al directorio C:\Windows\System32"
        patrones = @(
            '(?i)^cd\s+C:\\Windows\\System32\s*$'
            '(?i)^cd\s+"C:\\Windows\\System32"\s*$'
            '(?i)^chdir\s+C:\\Windows\\System32\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(sl|Set-Location)'; mensaje = "Eso es PowerShell. En CMD se usa 'cd' o 'chdir'." }
            @{ patron = '(?i)^cd\s+/[dD]'; mensaje = "Con /d cambias de unidad a la vez, pero aqui no hace falta porque ya estamos en C:." }
        )
        pista = "cd seguido de la ruta. Las barras en Windows van hacia atras: \"
        solucion = "cd C:\Windows\System32"
        explicacion = @"
'cd' (change directory) cambia la carpeta de trabajo.
En CMD, 'cd' sin /d no cambia de unidad (si estas en C: y pones cd D:\algo, no pasa nada).
Para cambiar de unidad a la vez: 'cd /d D:\carpeta'.
'cd ..' sube un nivel, 'cd \' va a la raiz de la unidad.
"@
    },

    @{
        id = "mkdir-crear"; nivel = 1; titulo = "Crear carpeta"
        descripcion = "Crea una carpeta llamada 'Proyectos' en el directorio actual."
        patrones = @(
            '(?i)^mkdir\s+"?Proyectos"?\s*$'
            '(?i)^md\s+"?Proyectos"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)New-Item'; mensaje = "Eso es PowerShell (New-Item). En CMD se usa 'mkdir' o 'md'." }
        )
        pista = "mkdir o md seguido del nombre."
        solucion = "mkdir Proyectos"
        explicacion = @"
'mkdir' (make directory) crea carpetas. El atajo es 'md'.
Si la ruta tiene espacios, usa comillas: mkdir "Mi Carpeta".
mkdir crea carpetas intermedias automaticamente: 'mkdir A\B\C' crea las tres.
"@
    },

    @{
        id = "copy-archivo"; nivel = 1; titulo = "Copiar archivo"
        descripcion = "Copia el archivo informe.docx a la carpeta Backup (que ya existe)."
        patrones = @(
            '(?i)^copy\s+"?informe\.docx"?\s+"?Backup\\?"?\s*$'
            '(?i)^copy\s+"?informe\.docx"?\s+"?\.\\Backup\\?"?\s*$'
            '(?i)^copy\s+"?informe\.docx"?\s+"?Backup\\informe\.docx"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(cp|Copy-Item|cpi)'; mensaje = "Eso es PowerShell/Linux. En CMD se usa 'copy'." }
            @{ patron = '(?i)^xcopy'; mensaje = "xcopy funciona pero es para copias mas complejas. Para un solo archivo, 'copy' es suficiente." }
            @{ patron = '(?i)^robocopy'; mensaje = "robocopy es para carpetas enteras. Para un archivo usa 'copy'." }
        )
        pista = "copy origen destino"
        solucion = "copy informe.docx Backup\"
        explicacion = @"
'copy' copia archivos. Sintaxis: copy [origen] [destino].
Si el destino es una carpeta, se copia con el mismo nombre.
Para copiar varios: 'copy *.txt Backup\'.
'xcopy' y 'robocopy' son para copias mas complejas (carpetas enteras, con subdirectorios).
"@
    },

    @{
        id = "move-mover"; nivel = 1; titulo = "Mover archivos"
        descripcion = "Mueve todos los archivos .tmp del directorio actual a la carpeta Temporal."
        patrones = @(
            '(?i)^move\s+"?\*\.tmp"?\s+"?Temporal\\?"?\s*$'
            '(?i)^move\s+"?\*\.tmp"?\s+"?\.\\Temporal\\?"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(mv|Move-Item)'; mensaje = "Eso es PowerShell/Linux. En CMD se usa 'move'." }
        )
        pista = "move [patron] [destino]. Usa el comodin * para todos los .tmp."
        solucion = "move *.tmp Temporal\"
        explicacion = @"
'move' mueve archivos o carpetas (cortar y pegar).
Tambien sirve para renombrar carpetas: 'move CarpetaVieja CarpetaNueva'.
A diferencia de 'ren', 'move' puede mover entre directorios distintos.
"@
    },

    @{
        id = "del-borrar"; nivel = 1; titulo = "Borrar archivos"
        descripcion = "Borra todos los archivos .bak del directorio actual."
        patrones = @(
            '(?i)^del\s+"?\*\.bak"?\s*$'
            '(?i)^del\s+/[qQ]\s+"?\*\.bak"?\s*$'
            '(?i)^erase\s+"?\*\.bak"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(rm|Remove-Item|ri)'; mensaje = "Eso es PowerShell/Linux. En CMD se usa 'del' o 'erase'." }
            @{ patron = '(?i)^rmdir'; mensaje = "'rmdir' borra carpetas, no archivos. Para archivos usa 'del'." }
        )
        pista = "del [patron]. Usa * como comodin."
        solucion = "del *.bak"
        explicacion = @"
'del' (o 'erase') borra archivos. NO borra carpetas (para eso: 'rmdir').
Cuidado: 'del *.*' borra TODO. No hay papelera de reciclaje desde CMD.
Modificadores utiles: /q (quiet, no pregunta), /f (force, borra solo-lectura).
Para borrar una carpeta entera con todo dentro: 'rmdir /s /q carpeta'.
"@
    },

    @{
        id = "ren-renombrar"; nivel = 1; titulo = "Renombrar"
        descripcion = "Renombra el archivo datos.csv a datos_backup.csv"
        patrones = @(
            '(?i)^ren\s+"?datos\.csv"?\s+"?datos_backup\.csv"?\s*$'
            '(?i)^rename\s+"?datos\.csv"?\s+"?datos_backup\.csv"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(mv|move)\s'; mensaje = "'move' funciona para renombrar, pero el comando especifico es 'ren' (rename)." }
            @{ patron = '(?i)Rename-Item'; mensaje = "Eso es PowerShell. En CMD se usa 'ren' o 'rename'." }
        )
        pista = "ren [nombre_actual] [nombre_nuevo]"
        solucion = "ren datos.csv datos_backup.csv"
        explicacion = @"
'ren' (rename) cambia el nombre de un archivo o carpeta SIN moverlo.
El segundo argumento es SOLO el nombre nuevo, no una ruta.
Esto NO vale: 'ren archivo.txt C:\otra\carpeta\nuevo.txt' (para eso usa 'move').
Puedes renombrar en lote: 'ren *.txt *.bak' cambia la extension de todos los .txt.
"@
    },

    @{
        id = "type-ver"; nivel = 1; titulo = "Ver contenido"
        descripcion = "Muestra el contenido del archivo notas.txt por pantalla."
        patrones = @(
            '(?i)^type\s+"?notas\.txt"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^(cat|gc|Get-Content)'; mensaje = "Eso es PowerShell/Linux. En CMD se usa 'type'." }
            @{ patron = '(?i)^more\s'; mensaje = "'more' muestra pagina a pagina. 'type' muestra todo de golpe. Ambos valen, pero el basico es 'type'." }
        )
        pista = "type [archivo]"
        solucion = "type notas.txt"
        explicacion = @"
'type' muestra el contenido de un archivo de texto en la consola.
Equivalente a 'cat' en Linux o 'Get-Content' en PowerShell.
Para archivos largos usa 'more': 'type archivo.txt | more' (pagina a pagina).
"@
    },

    @{
        id = "findstr-buscar"; nivel = 1; titulo = "Buscar texto"
        descripcion = "Busca las lineas que contengan la palabra ERROR dentro del archivo server.log"
        patrones = @(
            '(?i)^findstr\s+(/[iIcC]\s+)?"?ERROR"?\s+"?server\.log"?\s*$'
            '(?i)^findstr\s+"?ERROR"?\s+"?server\.log"?\s*$'
            '(?i)^find\s+"ERROR"\s+"?server\.log"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^grep\s'; mensaje = "Eso es Linux. En CMD se usa 'findstr' (o 'find' para busquedas simples)." }
            @{ patron = '(?i)Select-String'; mensaje = "Eso es PowerShell. En CMD se usa 'findstr'." }
        )
        pista = "findstr [texto] [archivo]. Es el grep de CMD."
        solucion = "findstr ERROR server.log"
        explicacion = @"
'findstr' busca texto dentro de archivos. Es el 'grep' de Windows.
Diferencia entre 'find' y 'findstr':
  - find: busqueda simple de texto literal (requiere comillas: find "ERROR" archivo)
  - findstr: mas potente, soporta expresiones regulares y multiples archivos
Modificadores: /i (ignorar mayusculas), /s (buscar en subcarpetas), /n (mostrar numero de linea).
"@
    },

    @{
        id = "redireccion-crear"; nivel = 1; titulo = "Redirigir a archivo"
        descripcion = "Guarda la lista de archivos del directorio actual en un archivo llamado listado.txt (sobrescribiendo si existe)."
        patrones = @(
            '(?i)^dir\s*>\s*"?listado\.txt"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)>>'; mensaje = ">> anade al final del archivo. > sobrescribe. Aqui queremos sobrescribir." }
            @{ patron = '(?i)Out-File|Set-Content'; mensaje = "Eso es PowerShell. En CMD se usa > para redirigir." }
            @{ patron = '(?i)^echo.*dir'; mensaje = "No necesitas echo. Redirige directamente la salida de dir con >." }
        )
        pista = "Usa > entre el comando y el nombre del archivo."
        solucion = "dir > listado.txt"
        explicacion = @"
> redirige la salida de un comando a un archivo, sobrescribiendo el contenido anterior.
>> hace lo mismo pero ANADE al final sin borrar lo que habia.
Ejemplos:
  echo Hola > saludo.txt     (crea o sobrescribe)
  echo Adios >> saludo.txt   (anade al final)
  dir /s > todo.txt          (guarda un listado recursivo)
"@
    },

    @{
        id = "redireccion-append"; nivel = 1; titulo = "Anadir a archivo"
        descripcion = "Anade el texto 'Proceso completado' al final del archivo log.txt SIN borrar lo que ya tiene."
        patrones = @(
            '(?i)^echo\s+Proceso completado\s*>>\s*"?log\.txt"?\s*$'
            '(?i)^echo\s+"Proceso completado"\s*>>\s*"?log\.txt"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)\s+>\s+'; mensaje = "Con un solo > sobrescribes el archivo entero. Usa >> para anadir al final." }
            @{ patron = '(?i)Add-Content'; mensaje = "Eso es PowerShell. En CMD se usa >> para anadir." }
        )
        pista = "echo [texto] >> [archivo]. Dos angulos >> para anadir."
        solucion = 'echo Proceso completado >> log.txt'
        explicacion = @"
>> es la redireccion de APPEND (anadir al final).
La diferencia con >:
  echo linea1 > archivo.txt   -> archivo solo tiene 'linea1'
  echo linea2 >> archivo.txt  -> archivo tiene 'linea1' y 'linea2'
Esto es muy util para escribir logs desde scripts .bat.
"@
    },

    @{
        id = "pipe-filtrar"; nivel = 1; titulo = "Pipe con findstr"
        descripcion = "Muestra los procesos del sistema y filtra solo los que contengan 'chrome' en su nombre."
        patrones = @(
            '(?i)^tasklist\s*\|\s*findstr\s+(/[iI]\s+)?"?chrome"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)Get-Process|gps'; mensaje = "Eso es PowerShell. En CMD se usa 'tasklist' para ver procesos." }
            @{ patron = '(?i)^tasklist.*findstr.*tasklist'; mensaje = "No necesitas repetir tasklist. Usa el pipe: tasklist | findstr chrome" }
            @{ patron = '(?i)^findstr.*tasklist'; mensaje = "El orden importa: primero el comando que genera datos, luego el filtro. tasklist | findstr chrome" }
        )
        pista = "tasklist genera la lista. El pipe | la pasa a findstr que filtra."
        solucion = "tasklist | findstr chrome"
        explicacion = @"
El pipe | pasa la SALIDA de un comando como ENTRADA del siguiente.
En CMD todo es texto, asi que findstr busca texto plano en la salida.
Otros ejemplos utiles:
  dir | findstr ".txt"           (filtrar listado por extension)
  ipconfig | findstr "IPv4"      (sacar solo la IP)
  systeminfo | findstr "OS"      (sacar solo info del SO)
"@
    },

    @{
        id = "silenciar"; nivel = 1; titulo = "Silenciar salida"
        descripcion = "Ejecuta 'dir' pero que no muestre NADA por pantalla: ni la salida normal ni los errores."
        patrones = @(
            '(?i)^dir\s*>\s*nul\s+2>\s*&?\s*1\s*$'
            '(?i)^dir\s*>\s*nul\s+2>&1\s*$'
            '(?i)^dir\s+>nul\s+2>&1\s*$'
        )
        errores = @(
            @{ patron = '(?i)>\s*nul\s*$'; mensaje = "Con >nul ocultas la salida normal, pero los errores seguirian apareciendo. Necesitas tambien 2>&1." }
            @{ patron = '(?i)Out-Null|\$null'; mensaje = "Eso es PowerShell. En CMD se redirige a 'nul' con > nul 2>&1." }
        )
        pista = "nul es el 'agujero negro' de CMD. > nul oculta la salida, 2>&1 oculta los errores."
        solucion = "dir >nul 2>&1"
        explicacion = @"
En CMD hay dos salidas:
  1 = stdout (salida normal)
  2 = stderr (errores)
'>nul' redirige stdout a la nada.
'2>&1' redirige stderr al mismo sitio que stdout (que ya va a nul).
Resultado: silencio total. Muy usado en scripts .bat para no llenar la pantalla.
"@
    },

    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 2 · SCRIPTING .BAT (12 retos)
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "set-variable"; nivel = 2; titulo = "Declarar variable"
        descripcion = "Declara una variable llamada 'servidor' con el valor 'produccion'. Recuerda: en CMD los espacios importan."
        patrones = @(
            '(?i)^set\s+servidor=produccion\s*$'
            '(?i)^set\s+"servidor=produccion"\s*$'
        )
        errores = @(
            @{ patron = '(?i)^set\s+servidor\s+='; mensaje = "Error clasico: el espacio antes del = hace que la variable se llame 'servidor ' (con espacio). Pega el nombre al =." }
            @{ patron = '(?i)^set\s+servidor=\s+produccion'; mensaje = "El espacio despues del = se guarda como parte del valor. Seria ' produccion'. Pega el valor al =." }
            @{ patron = '(?i)^\$'; mensaje = "En CMD las variables se declaran con 'set', no con $. El $ es de PowerShell/Bash." }
        )
        pista = "set nombre=valor. SIN ESPACIOS alrededor del =. Es la regla mas importante de las variables en CMD."
        solucion = "set servidor=produccion"
        explicacion = @"
En CMD, 'set' declara variables. La regla de oro:
  set nombre=valor    -> CORRECTO
  set nombre = valor  -> MAL (variable se llama 'nombre ', valor es ' valor')
Para usar la variable despues: %servidor%
Para borrarla: set servidor=  (sin valor)
"@
    },

    @{
        id = "set-input"; nivel = 2; titulo = "Pedir dato al usuario"
        descripcion = "Pide al usuario que escriba su nombre y guardalo en la variable 'nombre'. Usa como texto del prompt: 'Tu nombre: '"
        patrones = @(
            '(?i)^set\s+/p\s+nombre=Tu nombre:\s*$'
            '(?i)^set\s+/p\s+"?nombre=Tu nombre:\s*"?\s*$'
        )
        errores = @(
            @{ patron = '(?i)^set\s+nombre='; mensaje = "Sin /p no pides nada al usuario, simplemente asignas un valor fijo. Necesitas: set /p" }
            @{ patron = '(?i)Read-Host|Read-Line'; mensaje = "Eso es PowerShell. En CMD se usa 'set /p' para pedir input." }
        )
        pista = "set /p variable=texto del prompt"
        solucion = "set /p nombre=Tu nombre: "
        explicacion = @"
'set /p' (prompt) para el script y espera a que el usuario escriba algo.
Lo que escriba se guarda en la variable.
  set /p edad=Cuantos anos tienes?
  echo Tienes %edad% anos
El texto despues del = es lo que ve el usuario como pregunta.
"@
    },

    @{
        id = "set-aritmetica"; nivel = 2; titulo = "Aritmetica"
        descripcion = "Calcula 25 * 4 y guarda el resultado en la variable 'total'."
        patrones = @(
            '(?i)^set\s+/a\s+total\s*=\s*25\s*\*\s*4\s*$'
        )
        errores = @(
            @{ patron = '(?i)^set\s+total=25'; mensaje = "Sin /a no hace calculo, guarda el texto literal '25 * 4'. Necesitas: set /a" }
            @{ patron = '(?i)^\[Math\]|Measure'; mensaje = "Eso es PowerShell. En CMD se usa 'set /a' para calcular." }
        )
        pista = "set /a variable=expresion. Con /a, CMD hace la cuenta en vez de guardar el texto."
        solucion = "set /a total=25*4"
        explicacion = @"
'set /a' activa el modo aritmetico. Sin /a, 'set total=25*4' guarda el TEXTO '25*4'.
Operadores disponibles: + - * / %% (modulo)
Cuidado: en un .bat, el porcentaje se escapa con %%: set /a resto=10 %% 3
'set /a' solo trabaja con numeros enteros, no decimales.
"@
    },

    @{
        id = "echo-variable"; nivel = 2; titulo = "Mostrar variable"
        descripcion = "Muestra por pantalla el valor de la variable 'usuario'."
        patrones = @(
            '(?i)^echo\s+%usuario%\s*$'
        )
        errores = @(
            @{ patron = '(?i)\$usuario'; mensaje = "En CMD las variables van entre %porcentajes%, no con $. El $ es de PowerShell/Bash." }
            @{ patron = '(?i)%usuario[^%]'; mensaje = "Las variables en CMD van entre DOS signos de porcentaje: %variable%. Te falta el segundo %." }
            @{ patron = '(?i)echo\s+usuario\s*$'; mensaje = "Sin los %% simplemente escribe la palabra 'usuario'. Necesitas: echo %usuario%" }
        )
        pista = "echo %variable%. Las variables van envueltas entre signos de porcentaje."
        solucion = "echo %usuario%"
        explicacion = @"
En CMD, para acceder al valor de una variable se envuelve en %%:
  set animal=gato
  echo Mi animal es %animal%    -> 'Mi animal es gato'
Diferencias con otros lenguajes:
  CMD:        %variable%
  PowerShell: $variable
  Bash:       $variable o ${variable}
"@
    },

    @{
        id = "if-comparar"; nivel = 2; titulo = "Comparar texto con IF"
        descripcion = @"
Escribe la linea del IF que compara si la variable 'entorno' es igual a 'produccion'.
Solo la linea del if, con el parentesis de apertura.
Ejemplo de estructura:
  if "valor1"=="valor2" (
      echo son iguales
  )
"@
        patrones = @(
            '(?i)^if\s+"%entorno%"\s*==\s*"produccion"\s*\(\s*$'
            '(?i)^if\s+"%entorno%"=="produccion"\s*\(\s*$'
        )
        errores = @(
            @{ patron = '(?i)-eq'; mensaje = "'-eq' es PowerShell. En CMD se usa == para comparar texto." }
            @{ patron = '(?i)^if\s+%entorno%\s*=='; mensaje = 'Casi, pero las comparaciones de texto deben ir entre comillas para evitar errores si la variable esta vacia: if "%entorno%"=="produccion"' }
            @{ patron = '(?i)^if\s+\('; mensaje = "En CMD el parentesis va DESPUES de la condicion, no antes: if condicion ( ... )" }
        )
        pista = 'if "%variable%"=="valor" ('
        solucion = 'if "%entorno%"=="produccion" ('
        explicacion = @"
Para comparar texto en CMD se usa ==. SIEMPRE pon comillas alrededor:
  if "%variable%"=="valor" ( ... )
Las comillas evitan un error si la variable esta vacia (sin comillas,
CMD veria: if ==produccion y fallaria).
Para ignorar mayusculas: if /i "%var%"=="VALOR" ( ... )
"@
    },

    @{
        id = "if-exist"; nivel = 2; titulo = "Comprobar si existe"
        descripcion = "Escribe el comando que comprueba si existe el archivo config.ini y, si existe, lo muestra con type."
        patrones = @(
            '(?i)^if\s+exist\s+"?config\.ini"?\s+type\s+"?config\.ini"?\s*$'
            '(?i)^if\s+exist\s+"?config\.ini"?\s*\(\s*type\s+"?config\.ini"?\s*\)\s*$'
        )
        errores = @(
            @{ patron = '(?i)exists\b'; mensaje = "Casi: es 'if exist' sin la s. No es 'exists'." }
            @{ patron = '(?i)Test-Path'; mensaje = "Eso es PowerShell (Test-Path). En CMD se usa 'if exist'." }
        )
        pista = "if exist archivo comando"
        solucion = "if exist config.ini type config.ini"
        explicacion = @"
'if exist' comprueba si un archivo o carpeta existe.
Dos formas de usarlo:
  Inline:    if exist config.ini type config.ini
  En bloque: if exist config.ini (
                 echo Encontrado
                 type config.ini
             )
Tambien funciona con carpetas: if exist C:\Backup\  (la barra final es opcional).
"@
    },

    @{
        id = "if-errorlevel"; nivel = 2; titulo = "Comprobar errorlevel"
        descripcion = @"
Despues de ejecutar un ping, comprueba si hubo error.
Escribe la linea del IF que detecta si el comando anterior fallo (errorlevel distinto de 0):
  ping -n 1 google.com >nul 2>&1
  ______________________________
      echo Sin conexion
  )
"@
        patrones = @(
            '(?i)^if\s+%errorlevel%\s+NEQ\s+0\s*\(\s*$'
            '(?i)^if\s+errorlevel\s+1\s*\(\s*$'
            '(?i)^if\s+not\s+%errorlevel%\s*==\s*0\s*\(\s*$'
            '(?i)^if\s+not\s+"%errorlevel%"\s*==\s*"0"\s*\(\s*$'
        )
        errores = @(
            @{ patron = '(?i)\$LASTEXITCODE|\$\?'; mensaje = "Eso es PowerShell. En CMD se usa %ERRORLEVEL% o 'if errorlevel N'." }
            @{ patron = '(?i)%errorlevel%\s*!='; mensaje = "En CMD no existe !=. Usa NEQ (Not Equal) o 'if not %errorlevel%==0'." }
            @{ patron = '(?i)%errorlevel%\s*>\s*0'; mensaje = "En CMD no se usa > para comparar numeros (> es redireccion). Usa NEQ, GTR, etc." }
        )
        pista = "Dos formas: 'if %errorlevel% NEQ 0 (' o la forma clasica 'if errorlevel 1 ('"
        solucion = "if %errorlevel% NEQ 0 ("
        explicacion = @"
%ERRORLEVEL% guarda el codigo de salida del ultimo comando (0 = exito, otro = error).
Dos formas de comprobarlo:
  Moderna:  if %errorlevel% NEQ 0 (echo fallo)
  Clasica:  if errorlevel 1 (echo fallo)  <- si errorlevel >= 1
Operadores para numeros en CMD: EQU NEQ LSS GTR LEQ GEQ
(NO se pueden usar los simbolos < > porque se confunden con redirecciones).
"@
    },

    @{
        id = "for-numerico"; nivel = 2; titulo = "Bucle numerico"
        descripcion = "Escribe un bucle FOR en un .bat que cuente del 1 al 5 mostrando cada numero con echo. Recuerda: dentro de un .bat se usa %% doble."
        patrones = @(
            '(?i)^for\s+/[lL]\s+%%[a-zA-Z]\s+in\s+\(\s*1\s*,\s*1\s*,\s*5\s*\)\s+do\s+echo\s+%%[a-zA-Z]\s*$'
            '(?i)^for\s+/[lL]\s+%%[a-zA-Z]\s+in\s+\(1,\s*1,\s*5\)\s+do\s+echo\s+%%[a-zA-Z]\s*$'
        )
        errores = @(
            @{ patron = '(?i)for\s+/[lL]\s+%[a-zA-Z][^%]'; mensaje = "Dentro de un .bat se usa %%N (doble porcentaje). Un solo % es para la consola directa." }
            @{ patron = '(?i)foreach|ForEach'; mensaje = "Eso es PowerShell. En CMD se usa 'for /L' para bucles numericos." }
            @{ patron = '(?i)for\s+/[lL]\s+%%[a-zA-Z]\s+in\s+\(1\s+1\s+5\)'; mensaje = "Los valores del rango van separados por COMAS, no espacios: (1, 1, 5)." }
        )
        pista = "for /L %%N in (inicio, incremento, fin) do comando"
        solucion = "for /L %%N in (1, 1, 5) do echo %%N"
        explicacion = @"
'for /L' crea un bucle numerico. La L es de Loop.
Sintaxis: for /L %%VARIABLE in (inicio, paso, fin) do comando
  for /L %%i in (1, 1, 10) do echo %%i     -> 1,2,3...10
  for /L %%i in (0, 2, 10) do echo %%i     -> 0,2,4,6,8,10
  for /L %%i in (10, -1, 1) do echo %%i    -> 10,9,8...1
REGLA: en un .bat siempre %%N. En la consola directa solo %N.
"@
    },

    @{
        id = "for-archivos"; nivel = 2; titulo = "Bucle sobre archivos"
        descripcion = "Escribe un bucle FOR en un .bat que recorra todos los archivos .txt del directorio actual y muestre el nombre de cada uno."
        patrones = @(
            '(?i)^for\s+%%[a-zA-Z]\s+in\s+\(\s*\*\.txt\s*\)\s+do\s+echo\s+%%[a-zA-Z]\s*$'
        )
        errores = @(
            @{ patron = '(?i)for\s+%[a-zA-Z][^%].*in'; mensaje = "En un .bat usa %%F (doble porcentaje), no %F." }
            @{ patron = '(?i)/[fF]\s'; mensaje = "Para iterar sobre archivos no necesitas /F. Eso es para parsear texto. Sin modificador ya itera sobre archivos." }
            @{ patron = '(?i)gci|Get-ChildItem'; mensaje = "Eso es PowerShell. En CMD el for simple ya itera sobre archivos." }
        )
        pista = "for %%F in (patron) do comando. Sin /L ni /F: el for basico ya recorre archivos."
        solucion = "for %%F in (*.txt) do echo %%F"
        explicacion = @"
El 'for' basico (sin modificador) recorre archivos que coincidan con un patron:
  for %%F in (*.txt) do echo %%F        -> cada archivo .txt
  for %%F in (*.jpg *.png) do echo %%F  -> cada imagen
No confundir con:
  for /L -> bucle numerico
  for /D -> solo carpetas
  for /F -> parsear texto
  for /R -> recursivo
"@
    },

    @{
        id = "for-parsear"; nivel = 2; titulo = "Leer archivo linea a linea"
        descripcion = "Escribe un bucle FOR en un .bat que lea el archivo datos.txt linea por linea y muestre cada linea completa."
        patrones = @(
            '(?i)^for\s+/[fF]\s+"?tokens=\*"?\s+%%[a-zA-Z]\s+in\s+\(\s*"?datos\.txt"?\s*\)\s+do\s+echo\s+%%[a-zA-Z]\s*$'
            '(?i)^for\s+/[fF]\s+"tokens=\*"\s+%%[a-zA-Z]\s+in\s+\(datos\.txt\)\s+do\s+echo\s+%%[a-zA-Z]\s*$'
        )
        errores = @(
            @{ patron = '(?i)^for\s+%%[a-zA-Z]\s+in\s+\(datos\.txt\)'; mensaje = "Sin /F, el for busca ARCHIVOS llamados 'datos.txt', no lee su contenido. Necesitas 'for /F'." }
            @{ patron = '(?i)Get-Content|gc '; mensaje = "Eso es PowerShell. En CMD se usa 'for /F' para leer archivos." }
            @{ patron = '(?i)for\s+/[fF]\s+%%'; mensaje = "Necesitas las opciones 'tokens=*' para capturar la linea completa. Sin eso, solo captura la primera palabra." }
        )
        pista = 'for /F "tokens=*" %%L in (archivo) do echo %%L'
        solucion = 'for /F "tokens=*" %%L in (datos.txt) do echo %%L'
        explicacion = @"
'for /F' parsea texto: puede leer archivos, salida de comandos o cadenas.
Sin 'tokens=*', solo captura la primera palabra de cada linea (separada por espacios).
Con 'tokens=*' captura la linea entera.
Otras opciones utiles:
  "delims=;"         -> separa por punto y coma en vez de espacio
  "tokens=1,3"       -> captura la primera y tercera columna
  "skip=2"           -> salta las 2 primeras lineas
  "usebackq"         -> permite comillas en el nombre del archivo
"@
    },

    @{
        id = "argumentos-bat"; nivel = 2; titulo = "Argumentos del script"
        descripcion = @"
Escribe la linea de echo que muestra el primer y segundo argumento que se le pasan a un script .bat.
Si ejecutas: script.bat datos.csv informe.pdf
Debe mostrar: Procesando datos.csv hacia informe.pdf
"@
        patrones = @(
            '(?i)^echo\s+Procesando\s+%1\s+hacia\s+%2\s*$'
            '(?i)^echo\s+Procesando\s+%~1\s+hacia\s+%~2\s*$'
            '(?i)^echo\s+Procesando\s+"%~?1"\s+hacia\s+"%~?2"\s*$'
        )
        errores = @(
            @{ patron = '(?i)\$args|\$1|\$2'; mensaje = "Eso es PowerShell/Bash. En CMD los argumentos son %1, %2, %3, etc." }
            @{ patron = '(?i)%%1'; mensaje = "Los argumentos usan un solo %, no doble. El %% doble es solo para variables de FOR." }
        )
        pista = "Los argumentos son %1, %2, %3... %0 es el nombre del propio script."
        solucion = "echo Procesando %1 hacia %2"
        explicacion = @"
Cuando ejecutas: mi_script.bat uno dos tres
  %0 = mi_script.bat (el propio script)
  %1 = uno
  %2 = dos
  %3 = tres (hasta %9)
Modificadores utiles (se ponen entre % y el numero):
  %~1  = quita las comillas del argumento
  %~f1 = ruta completa del archivo
  %~n1 = solo el nombre sin extension
  %~x1 = solo la extension
  %~dp0 = la carpeta donde esta el script (muy util)
"@
    },

    # ═══════════════════════════════════════════════════════════════════
    # NIVEL 3 · SCRIPTS REALES (6 retos)
    # ═══════════════════════════════════════════════════════════════════

    @{
        id = "fecha-variable"; nivel = 3; titulo = "Fecha en variable"
        descripcion = "Guarda la fecha de hoy en una variable llamada 'hoy', pero reemplazando las barras / por guiones - para poder usarla en nombres de archivo. Usa la variable %date% y el comando set."
        patrones = @(
            '(?i)^set\s+hoy=%date:/=-%\s*$'
            '(?i)^set\s+"hoy=%date:/=-%"\s*$'
        )
        errores = @(
            @{ patron = '(?i)Get-Date'; mensaje = "Eso es PowerShell. En CMD se usa %date% y sustitucion de cadenas." }
            @{ patron = '(?i)%date%'; mensaje = "Vas bien con %date%. Para reemplazar / por -, la sintaxis es: %date:/=-%" }
        )
        pista = "CMD puede sustituir texto en variables con esta sintaxis: %variable:viejo=nuevo%"
        solucion = "set hoy=%date:/=-%"
        explicacion = @"
CMD tiene sustitucion de cadenas integrada:
  %variable:texto_viejo=texto_nuevo%
Ejemplos:
  set saludo=Hola Mundo
  echo %saludo:Mundo=CMD%     -> 'Hola CMD'
  set fecha=%date:/=-%         -> '03-10-2024' en vez de '03/10/2024'
Esto es vital para crear nombres de archivo con fecha:
  mkdir Backup_%date:/=-%      -> crea 'Backup_03-10-2024'
"@
    },

    @{
        id = "errorlevel-ping"; nivel = 3; titulo = "Test de conexion"
        descripcion = @"
Escribe la linea que ejecuta un ping silencioso (1 solo paquete, sin mostrar nada) a google.com.
Debe redirigir toda la salida (normal y errores) a nul.
"@
        patrones = @(
            '(?i)^ping\s+(-n\s+1\s+google\.com|google\.com\s+-n\s+1)\s*>\s*nul\s+2>\s*&?\s*1\s*$'
            '(?i)^ping\s+(-n\s+1\s+google\.com|google\.com\s+-n\s+1)\s+>nul\s+2>&1\s*$'
        )
        errores = @(
            @{ patron = '(?i)Test-NetConnection|tnc'; mensaje = "Eso es PowerShell. En CMD se usa 'ping'." }
            @{ patron = '(?i)ping\s+google\.com\s*$'; mensaje = "Casi, pero falta -n 1 (un solo paquete) y la redireccion a nul para silenciarlo." }
            @{ patron = '(?i)-c\s+1'; mensaje = "En Linux es -c. En Windows CMD es -n (number)." }
        )
        pista = "ping -n 1 destino >nul 2>&1"
        solucion = "ping -n 1 google.com >nul 2>&1"
        explicacion = @"
Esta linea es la base de cualquier script que necesite comprobar conexion:
  ping -n 1 google.com >nul 2>&1
  if %errorlevel% NEQ 0 (
      echo Sin conexion
      exit /b 1
  )
-n 1: un solo paquete (no esperar a los 4 por defecto).
>nul 2>&1: que no se vea nada en pantalla.
Despues se comprueba %errorlevel% para saber si hubo respuesta.
"@
    },

    @{
        id = "dp0-ruta"; nivel = 3; titulo = "Ruta del script"
        descripcion = @"
Escribe la linea que cambia el directorio de trabajo a la carpeta donde esta el propio script .bat.
Esto es vital para que el script funcione igual sin importar desde donde lo ejecutes.
"@
        patrones = @(
            '(?i)^cd\s+/d\s+"%~dp0"\s*$'
            '(?i)^cd\s+/d\s+%~dp0\s*$'
            '(?i)^pushd\s+"%~dp0"\s*$'
            '(?i)^pushd\s+%~dp0\s*$'
        )
        errores = @(
            @{ patron = '(?i)^cd\s+%~dp0\s*$'; mensaje = 'Casi. Necesitas /d por si el script esta en otra unidad (D:, E:, etc). Usa: cd /d "%~dp0"' }
            @{ patron = '(?i)\$PSScriptRoot'; mensaje = "Eso es PowerShell ($PSScriptRoot). En CMD se usa %~dp0." }
        )
        pista = "cd /d con la variable especial que da la ruta del script. Esa variable empieza por %~ y acaba en 0."
        solucion = 'cd /d "%~dp0"'
        explicacion = @"
%~dp0 es una de las herramientas mas importantes de BAT:
  %0  = ruta del script tal como se escribio
  %~0 = ruta sin comillas
  %~d0 = solo la unidad (C:)
  %~p0 = solo la carpeta (\Users\edu\scripts\)
  %~dp0 = unidad + carpeta (C:\Users\edu\scripts\)
  %~n0 = nombre del script sin extension
'cd /d' cambia de directorio Y de unidad a la vez.
Las comillas protegen contra espacios en la ruta.
"@
    },

    @{
        id = "setlocal-scope"; nivel = 3; titulo = "Aislar variables"
        descripcion = @"
Escribe la linea que activa el aislamiento de variables Y la expansion retardada.
Se pone al principio de un .bat para que las variables del script no contaminen la sesion
y para poder usar !variable! dentro de bucles FOR.
"@
        patrones = @(
            '(?i)^setlocal\s+enabledelayedexpansion\s*$'
            '(?i)^setlocal\s+EnableDelayedExpansion\s*$'
        )
        errores = @(
            @{ patron = '(?i)^setlocal\s*$'; mensaje = "setlocal solo aisla las variables. Para la expansion retardada necesitas: setlocal enabledelayedexpansion" }
            @{ patron = '(?i)enabledelayed[^e]'; mensaje = "Se escribe todo junto: enabledelayedexpansion (enable + delayed + expansion)." }
        )
        pista = "setlocal seguido de una palabra larga que empieza por 'enable'..."
        solucion = "setlocal enabledelayedexpansion"
        explicacion = @"
'setlocal' aisla las variables del script: al acabar (o con 'endlocal'),
las variables vuelven a su valor original. El sistema no queda 'sucio'.

'enabledelayedexpansion' resuelve un problema clasico de CMD:
  for /L %%i in (1,1,5) do (
      set contador=%%i
      echo %contador%        <- SIEMPRE muestra el valor ANTES del for
      echo !contador!        <- Muestra el valor ACTUAL de cada vuelta
  )
Sin expansion retardada, %variable% se evalua ANTES de ejecutar el bloque.
Con expansion retardada, !variable! se evalua EN CADA ITERACION.
"@
    },

    @{
        id = "exit-b"; nivel = 3; titulo = "Salir con codigo"
        descripcion = "Escribe la linea que sale del script devolviendo un codigo de error 1, pero SIN cerrar la ventana de CMD si el usuario ejecuto el script desde la consola."
        patrones = @(
            '(?i)^exit\s+/b\s+1\s*$'
        )
        errores = @(
            @{ patron = '(?i)^exit\s+1\s*$'; mensaje = "'exit 1' cierra la ventana de CMD entera. Con /b solo sale del script sin cerrar la consola." }
            @{ patron = '(?i)^exit\s*$'; mensaje = "'exit' sin parametros cierra la ventana. Necesitas /b para solo salir del script y un numero para el codigo de error." }
            @{ patron = '(?i)return|throw'; mensaje = "Eso es PowerShell. En CMD se usa 'exit /b N' para salir de un script." }
        )
        pista = "exit /b [codigo]. La /b es de batch: sale del script pero no cierra la ventana."
        solucion = "exit /b 1"
        explicacion = @"
Tres formas de salir en CMD:
  exit       -> cierra la ventana de CMD entera (peligroso en scripts)
  exit /b    -> sale del script, vuelve a la consola (codigo 0)
  exit /b 1  -> sale del script con codigo de error 1
El codigo queda en %ERRORLEVEL% para que el proceso que llamo al script
pueda saber si fue bien (0) o mal (distinto de 0).
"@
    },

    @{
        id = "call-label"; nivel = 3; titulo = "Llamar a subrutina"
        descripcion = @"
Escribe la linea que llama a la subrutina :procesar pasandole dos argumentos: el archivo datos.csv y el numero 10.
Ejemplo de subrutina:
  :procesar
  echo Archivo: %1, Lineas: %2
  exit /b
"@
        patrones = @(
            '(?i)^call\s+:procesar\s+"?datos\.csv"?\s+10\s*$'
        )
        errores = @(
            @{ patron = '(?i)^goto\s+:?procesar'; mensaje = "'goto' salta a la etiqueta pero NO vuelve. Para llamar y volver necesitas 'call'." }
            @{ patron = '(?i)^:procesar'; mensaje = "Eso define la etiqueta. Para LLAMARLA usa: call :procesar argumentos" }
            @{ patron = '(?i)^call\s+procesar'; mensaje = "Casi. Las etiquetas llevan dos puntos al llamarlas: call :procesar" }
        )
        pista = "call :etiqueta argumento1 argumento2"
        solucion = "call :procesar datos.csv 10"
        explicacion = @"
'call' es como una llamada a funcion en BAT:
  call :etiqueta arg1 arg2    -> salta a :etiqueta, ejecuta, y VUELVE
  goto :etiqueta              -> salta a :etiqueta y NO vuelve
Dentro de la subrutina, los argumentos son %1, %2, etc.
'exit /b' al final de la subrutina devuelve el control al punto de llamada.
Esto permite estructurar scripts largos como si tuvieras funciones:
  call :validar %1
  call :procesar %1
  call :limpiar
"@
    }
    )
}

# ── Motor ─────────────────────────────────────────────────────────────

# Estado global
$global:CmdActivo = $null    # Reto actual
$global:CmdIntentos = 0      # Intentos en el reto actual

function Show-CmdBanner {
    param([hashtable]$Reto)
    $nivelNombre = switch ($Reto.nivel) {
        1 { "Comandos basicos" }
        2 { "Scripting .bat" }
        3 { "Scripts reales" }
    }
    $caja = Get-CmdCaja $Reto.id
    $cajaStr = if ($caja -gt 0) { " [caja $caja/5]" } else { " [nuevo]" }
    Write-Host ""
    Write-Host "  +============================================+" -ForegroundColor DarkCyan
    Write-Host "  |  COMANDOS  ·  CMD & .bat                   |" -ForegroundColor Cyan
    Write-Host "  |  Nivel $($Reto.nivel) · $nivelNombre$(' ' * (26 - $nivelNombre.Length))|" -ForegroundColor Cyan
    Write-Host "  |  > $($Reto.titulo)$(' ' * (37 - $Reto.titulo.Length))$cajaStr |" -ForegroundColor Yellow
    Write-Host "  +============================================+" -ForegroundColor DarkCyan
    Write-Host ""
}

function Show-CmdDescripcion {
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

function Get-CmdSiguiente {
    $banco = Get-CmdBanco
    $prog = Get-CmdProgreso
    # Primero: repasos pendientes
    $repasos = $banco | Where-Object { Test-CmdDue $_.id } | Where-Object {
        $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0 -and $prog[$_.id].caja -lt 5
    }
    if ($repasos.Count -gt 0) {
        return ($repasos | Sort-Object { (Get-CmdCaja $_.id) } | Select-Object -First 1)
    }
    # Despues: siguiente reto nuevo
    $nuevo = $banco | Where-Object { -not $prog.ContainsKey($_.id) } | Select-Object -First 1
    return $nuevo
}

function Enter-CmdLoop {
    param([hashtable]$Reto)

    $global:CmdActivo = $Reto
    $global:CmdIntentos = 0
    Show-CmdBanner $Reto
    Show-CmdDescripcion $Reto

    while ($global:CmdActivo) {
        Write-Host "  CMD> " -NoNewline -ForegroundColor DarkCyan
        try {
            $resp = Read-Host
        } catch {
            $global:CmdActivo = $null
            break
        }
        if ($null -eq $resp) { $global:CmdActivo = $null; break }
        $resp = $resp.Trim()
        if ($resp -eq '') { continue }

        $lower = $resp.ToLower()
        if ($lower -eq 'p' -or $lower -eq 'pista') {
            Show-CmdPista
        } elseif ($lower -eq 's' -or $lower -eq 'solucion') {
            Show-CmdSolucion
            $sig = Get-CmdSiguiente
            if ($sig) {
                $global:CmdActivo = $sig
                $global:CmdIntentos = 0
                Show-CmdBanner $sig
                Show-CmdDescripcion $sig
            } else {
                Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
                Write-Host "  Usa 'comandos -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
            }
        } elseif ($lower -eq 'salir' -or $lower -eq 'exit' -or $lower -eq 'q') {
            Exit-Cmd
        } elseif ($lower -eq 'ayuda') {
            Write-Host ""
            Write-Host "  Escribe el comando CMD directamente como respuesta." -ForegroundColor Gray
            Write-Host ""
            Write-Host "  p / pista      Ver pista" -ForegroundColor DarkGray
            Write-Host "  s / solucion   Ver solucion (cuenta como fallo)" -ForegroundColor DarkGray
            Write-Host "  salir          Abandonar el reto actual" -ForegroundColor DarkGray
            Write-Host "  lista          Ver todos los retos" -ForegroundColor DarkGray
            Write-Host "  stats          Ver estadisticas" -ForegroundColor DarkGray
            Write-Host ""
        } elseif ($lower -eq 'lista') {
            Invoke-Comandos -Lista
        } elseif ($lower -eq 'stats') {
            Show-CmdStats
        } else {
            Invoke-CmdResponder $resp
            if (-not $global:CmdActivo) {
                $sig = Get-CmdSiguiente
                if ($sig) {
                    $global:CmdActivo = $sig
                    $global:CmdIntentos = 0
                    Show-CmdBanner $sig
                    Show-CmdDescripcion $sig
                } else {
                    Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
                    Write-Host "  Usa 'comandos -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
                }
            }
        }
    }
}

function Invoke-Comandos {
    [CmdletBinding()]
    param(
        [int]$Nivel,
        [string]$Id,
        [switch]$Lista,
        [switch]$Repaso,
        [switch]$Reiniciar,
        [switch]$Stats
    )

    $banco = Get-CmdBanco

    # ── Reiniciar progreso ──
    if ($Reiniciar) {
        $path = Get-CmdProgresoPath
        if (Test-Path $path) { Remove-Item $path -Force }
        Write-Host "`n  Progreso reiniciado.`n" -ForegroundColor Yellow
        return
    }

    # ── Estadisticas ──
    if ($Stats) {
        Show-CmdStats
        return
    }

    # ── Listar retos ──
    if ($Lista) {
        $filtrados = if ($Nivel -gt 0) { $banco | Where-Object { $_.nivel -eq $Nivel } } else { $banco }
        $prog = Get-CmdProgreso
        $hoy = (Get-Date).ToString("yyyy-MM-dd")

        $nivelActual = 0
        foreach ($r in $filtrados) {
            if ($r.nivel -ne $nivelActual) {
                $nivelActual = $r.nivel
                $nombre = switch ($nivelActual) { 1 { "COMANDOS BASICOS" } 2 { "SCRIPTING .BAT" } 3 { "SCRIPTS REALES" } }
                Write-Host "`n  === NIVEL $nivelActual · $nombre ===" -ForegroundColor Cyan
            }
            $caja = 0; $estado = "  "
            if ($prog.ContainsKey($r.id)) {
                $caja = $prog[$r.id].caja
                $due = ($prog[$r.id].siguiente -le $hoy)
                if ($caja -ge 5) { $estado = [char]0x2713 + " " }        # check mark
                elseif ($due) { $estado = "> " }                          # due
                else { $estado = "- " }                                   # waiting
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
        $dominados = ($filtrados | Where-Object { (Get-CmdCaja $_.id) -ge 5 }).Count
        $pendientes = ($filtrados | Where-Object { Test-CmdDue $_.id }).Count
        Write-Host "  $dominados/$total dominados · $pendientes pendientes de repaso" -ForegroundColor DarkCyan
        Write-Host ""
        return
    }

    # ── Ir a un reto concreto ──
    if ($Id) {
        $reto = $banco | Where-Object { $_.id -eq $Id }
        if (-not $reto) {
            Write-Host "`n  Reto '$Id' no encontrado. Usa 'comandos -Lista' para ver todos.`n" -ForegroundColor Red
            return
        }
        Enter-CmdLoop $reto
        return
    }

    # ── Repaso: elegir el mas urgente ──
    if ($Repaso) {
        $prog = Get-CmdProgreso
        $pendientes = $banco | Where-Object { Test-CmdDue $_.id } | Where-Object {
            $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0
        }
        if ($pendientes.Count -eq 0) {
            Write-Host "`n  No tienes retos pendientes de repaso. Buen trabajo!" -ForegroundColor Green
            Write-Host "  Usa 'comandos' sin -Repaso para seguir avanzando.`n" -ForegroundColor DarkGray
            return
        }
        # Elegir el de caja mas baja (mas urgente)
        $elegido = $pendientes | Sort-Object { (Get-CmdCaja $_.id) } | Select-Object -First 1
        Write-Host "`n  REPASO" -ForegroundColor Magenta
        Enter-CmdLoop $elegido
        return
    }

    # ── Sin parametros: siguiente reto ──
    # Primero: repasos pendientes
    $prog = Get-CmdProgreso
    $repasosPendientes = $banco | Where-Object { Test-CmdDue $_.id } | Where-Object {
        $prog.ContainsKey($_.id) -and $prog[$_.id].caja -gt 0 -and $prog[$_.id].caja -lt 5
    }
    if ($repasosPendientes.Count -gt 0) {
        $elegido = $repasosPendientes | Sort-Object { (Get-CmdCaja $_.id) } | Select-Object -First 1
        Write-Host "`n  REPASO pendiente" -ForegroundColor Magenta
        Enter-CmdLoop $elegido
        return
    }

    # Segundo: siguiente reto nuevo (filtrar por nivel si se pide)
    $filtro = if ($Nivel -gt 0) { $banco | Where-Object { $_.nivel -eq $Nivel } } else { $banco }
    $nuevo = $filtro | Where-Object { -not $prog.ContainsKey($_.id) } | Select-Object -First 1
    if ($nuevo) {
        Enter-CmdLoop $nuevo
        return
    }

    # Tercero: todo hecho
    Write-Host "`n  Has completado todos los retos!" -ForegroundColor Green
    Write-Host "  Usa 'comandos -Repaso' para repasar los que toquen." -ForegroundColor DarkGray
    Write-Host "  Usa 'comandos -Stats' para ver tus estadisticas.`n" -ForegroundColor DarkGray
}

function Invoke-CmdResponder {
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Palabras
    )
    if (-not $global:CmdActivo) {
        Write-Host "`n  No hay ningun reto activo. Usa 'comandos' para empezar.`n" -ForegroundColor Yellow
        return
    }
    $respuesta = ($Palabras -join " ").Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($respuesta)) {
        Write-Host "`n  Escribe tu respuesta directamente.`n" -ForegroundColor Yellow
        return
    }

    $reto = $global:CmdActivo
    $global:CmdIntentos++

    # Comprobar errores comunes primero (feedback especifico)
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

    # Comprobar patrones correctos
    $acierto = $false
    foreach ($p in $reto.patrones) {
        if ($respuesta -match $p) {
            $acierto = $true
            break
        }
    }

    if ($acierto) {
        Register-CmdResultado -Codigo $reto.id -Acierto $true
        $cajaNew = Get-CmdCaja $reto.id
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
        $global:CmdActivo = $null
    } else {
        Write-Host ""
        Write-Host "  X  Incorrecto" -ForegroundColor Red
        if ($global:CmdIntentos -ge 2) {
            Write-Host "  Prueba con 'p' para una pista o 's' para ver la solucion." -ForegroundColor DarkGray
        } else {
            Write-Host "  Intentalo otra vez. 'p' te da una pista." -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

function Show-CmdPista {
    if (-not $global:CmdActivo) {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "  PISTA: $($global:CmdActivo.pista)" -ForegroundColor Cyan
    Write-Host ""
}

function Show-CmdSolucion {
    if (-not $global:CmdActivo) {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor Yellow
        return
    }
    $reto = $global:CmdActivo
    Register-CmdResultado -Codigo $reto.id -Acierto $false

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
    $global:CmdActivo = $null
}

function Exit-Cmd {
    if ($global:CmdActivo) {
        $reto = $global:CmdActivo
        # Registrar como fallo si no se ha respondido correctamente
        Register-CmdResultado -Codigo $reto.id -Acierto $false
        Write-Host "`n  Saliste de '$($reto.titulo)'. Registrado como no completado.`n" -ForegroundColor DarkGray
    } else {
        Write-Host "`n  No hay ningun reto activo.`n" -ForegroundColor DarkGray
    }
    $global:CmdActivo = $null
}

function Show-CmdStats {
    $banco = Get-CmdBanco
    $prog = Get-CmdProgreso
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
    Write-Host "  +============================================+" -ForegroundColor DarkCyan
    Write-Host "  |  COMANDOS · Estadisticas                   |" -ForegroundColor Cyan
    Write-Host "  +============================================+" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Retos:      $intentados/$total intentados ($pctIntentados%)" -ForegroundColor White
    Write-Host "  Dominados:  $dominados/$total ($pctDominados%)" -ForegroundColor Green
    Write-Host "  Intentos:   $totalIntentos totales" -ForegroundColor Gray
    Write-Host "  Aciertos:   $totalAciertos ($pctAcierto%)" -ForegroundColor Gray
    Write-Host ""

    # Por nivel
    foreach ($n in 1..3) {
        $nivelRetos = $banco | Where-Object { $_.nivel -eq $n }
        $nivelNombre = switch ($n) { 1 { "Basicos" } 2 { "Scripting" } 3 { "Reales" } }
        $nivelDominados = ($nivelRetos | Where-Object { (Get-CmdCaja $_.id) -ge 5 }).Count
        $barra = ""
        $len = $nivelRetos.Count
        foreach ($r in $nivelRetos) {
            $c = Get-CmdCaja $r.id
            if ($c -ge 5) { $barra += [char]0x2588 }      # full block
            elseif ($c -ge 3) { $barra += [char]0x2593 }  # dark shade
            elseif ($c -ge 1) { $barra += [char]0x2591 }  # light shade
            else { $barra += [char]0x2500 }                # line
        }
        Write-Host "  N$n $nivelNombre : " -ForegroundColor DarkCyan -NoNewline
        Write-Host "$barra " -ForegroundColor Cyan -NoNewline
        Write-Host "$nivelDominados/$len" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ── Ayuda integrada ───────────────────────────────────────────────────

$global:CmdAyuda = @(
    @{ cmd = "comandos";           desc = "Iniciar siguiente reto (modo interactivo)" }
    @{ cmd = "comandos -Lista";    desc = "Ver todos los retos y su estado" }
    @{ cmd = "comandos -Nivel 2";  desc = "Retos de un nivel concreto" }
    @{ cmd = "comandos -Id X";     desc = "Ir a un reto concreto por su id" }
    @{ cmd = "comandos -Repaso";   desc = "Solo retos que toca repasar" }
    @{ cmd = "comandos -Stats";    desc = "Ver estadisticas de progreso" }
    @{ cmd = "comandos -Reiniciar"; desc = "Borrar todo el progreso" }
    @{ cmd = "--- Dentro del reto ---"; desc = "" }
    @{ cmd = "(tu comando)";       desc = "Escribe directamente el comando CMD" }
    @{ cmd = "p / pista";          desc = "Ver pista" }
    @{ cmd = "s / solucion";       desc = "Ver solucion (cuenta como fallo)" }
    @{ cmd = "salir";              desc = "Abandonar el reto actual" }
    @{ cmd = "ayuda / ?";          desc = "Ver comandos disponibles" }
)

function Show-CmdHelp {
    Write-Host ""
    Write-Host "  COMANDOS · Practica CMD y .bat" -ForegroundColor Cyan
    Write-Host "  ===============================" -ForegroundColor DarkCyan
    Write-Host ""
    foreach ($h in $global:CmdAyuda) {
        Write-Host "  $($h.cmd)" -ForegroundColor Yellow -NoNewline
        $pad = 28 - $h.cmd.Length
        if ($pad -lt 2) { $pad = 2 }
        Write-Host "$(' ' * $pad)$($h.desc)" -ForegroundColor Gray
    }
    Write-Host ""
}

# ── Aliases ───────────────────────────────────────────────────────────

Set-Alias comandos    Invoke-Comandos     -Scope Global
Set-Alias cmd-ayuda   Show-CmdHelp        -Scope Global
Set-Alias cmd-stats   Show-CmdStats       -Scope Global
