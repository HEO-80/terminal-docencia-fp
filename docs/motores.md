# Cómo funcionan los motores de entrenamiento

Esta guía explica cómo está programado cada motor por dentro, empezando por la sintaxis básica de PowerShell para que cualquier persona pueda entenderlo.

---

## Primero: sintaxis de PowerShell que necesitas conocer

### Variables (`$`)

En PowerShell las variables empiezan siempre por `$`:

```powershell
$nombre = "Hector"          # Variable de texto (string)
$edad = 46                  # Variable numérica
$activo = $true             # Variable booleana (verdadero/falso)
```

### Comentarios (`#`)

Todo lo que va después de `#` en una línea es un comentario que PowerShell ignora:

```powershell
# Esto es un comentario, no se ejecuta
$nombre = "Hector"  # Esto de aquí tampoco
```

### Hashtable (`@{ }`) — Diccionario de clave = valor

Es como un objeto o diccionario en otros lenguajes. Guardas pares de `Clave = Valor` separados por `;` o por saltos de línea:

```powershell
# En una línea (separado por ;)
$persona = @{ Nombre = "Hector"; Edad = 46; Profesor = $true }

# En varias líneas (más legible, no necesita ;)
$persona = @{
    Nombre   = "Hector"
    Edad     = 46
    Profesor = $true
}

# Para acceder a un valor:
$persona.Nombre      # → "Hector"
$persona["Edad"]     # → 46
```

**Así es como se definen los ejercicios en este proyecto.** Cada ejercicio es un hashtable con sus datos: el título, la pista, la solución, la comprobación, etc.

### Array (`@( )`) — Lista ordenada

Es una lista de elementos, como un array en JavaScript:

```powershell
# Array de textos
$frutas = @('manzana', 'pera', 'plátano')

# Acceder por posición (empieza en 0)
$frutas[0]    # → "manzana"
$frutas[2]    # → "plátano"

# Contar cuántos hay
$frutas.Count # → 3
```

**Así es como se agrupan los ejercicios.** El "banco" de cada motor es un array de hashtables: una lista de ejercicios.

### ScriptBlock (`{ }`) — Bloque de código guardado

Un trozo de código que **no se ejecuta todavía**, se guarda para ejecutarlo después. Es como una función anónima (lambda) en JavaScript o Python:

```powershell
# Esto NO se ejecuta ahora, solo se guarda
$miCodigo = {
    Write-Host "¡Hola!"
}

# Esto SÍ lo ejecuta (con el operador &)
& $miCodigo    # → Imprime "¡Hola!"
```

**Así es como se definen las comprobaciones y las preparaciones de los ejercicios.** El motor guarda el código de "preparar el escenario" y "comprobar si el alumno lo hizo bien" como ScriptBlocks, y los ejecuta en el momento adecuado.

### Parámetros (`param()`)

Define qué datos recibe una función o un ScriptBlock:

```powershell
# En un ScriptBlock
$saludar = { param($nombre)
    Write-Host "Hola, $nombre"
}

& $saludar "Hector"   # → "Hola, Hector"

# En una función
function Sumar {
    param([int]$a, [int]$b)
    return ($a + $b)
}

Sumar -a 3 -b 5   # → 8
```

### Pipeline (`|`) — Encadenar comandos

Pasa la salida de un comando como entrada del siguiente:

```powershell
# "Dame los archivos .log y cuéntalos"
Get-ChildItem *.log | Measure-Object

# "Coge este texto y escríbelo en un archivo"
'error 1' | Set-Content 'app.log'
```

### Comparaciones

PowerShell usa operadores con guion, no los símbolos `>`, `<`, `==`:

```powershell
5 -eq 5    # igual → $true
5 -ne 3    # no igual → $true
5 -gt 3    # mayor que → $true
3 -lt 5    # menor que → $true
```

### Lógicos (`-and`, `-or`)

```powershell
# Las DOS condiciones tienen que ser verdad
(Test-Path 'a.txt') -and (Test-Path 'b.txt')

# Al menos UNA tiene que ser verdad
($edad -gt 18) -or ($permiso -eq $true)
```

---

## Motor 1: DOJO — Preguntas y respuestas

### Qué hace

Le muestra al alumno una tarea (ej: "Listar el contenido de una carpeta") y le pide que escriba el comando correcto. Acepta varias respuestas válidas por plataforma (Linux, PowerShell, CMD).

### Estructura de un ejercicio

```powershell
@{
    Tipo  = "Listar"
    # Categoría del ejercicio. Solo para organizar, no afecta a la mecánica.

    Tarea = "Listar el contenido de una carpeta"
    # El enunciado que ve el alumno.

    R = @{
        # R = Respuestas aceptadas, organizadas por plataforma.
        # Cada plataforma tiene un array de respuestas válidas.
        # La primera de cada array es la "canónica" (la que se muestra como ejemplo).

        Linux      = @('ls')
        PowerShell = @('Get-ChildItem', 'ls', 'dir', 'gci')
        Cmd        = @('dir')
    }

    Exp = "Get-ChildItem devuelve objetos. Aliases: ls, dir, gci."
    # Explicación que se muestra después de responder (acierte o falle).
}
```

### Cómo funciona el motor

```
Alumno escribe: dojo
    ↓
El motor elige un ejercicio (prioridad: repaso > nuevo > caja baja)
    ↓
Muestra: "Listar el contenido de una carpeta [PowerShell]"
    ↓
El alumno escribe: Get-ChildItem
    ↓
¿Está en la lista R.PowerShell?
    SÍ → ✅ Acierto → sube de caja Leitner
    NO → ❌ Fallo → baja a caja 1
    ↓
Muestra la Exp (explicación)
    ↓
Siguiente pregunta...
```

### Dónde está el código

- **Banco de ejercicios:** función `Get-DojoBanco` en `Dojo.ps1` (y `Dojo2.ps1` para nivel 2)
- **Motor de juego:** función `Invoke-DojoEngine` en `Motor.ps1`
- **Registro de progreso:** función `Register-CyberResultado` en `Motor.ps1`

---

## Motor 2: TATAMI — Misiones en sandbox

### Qué hace

Crea una carpeta temporal (sandbox) con archivos de prueba. El alumno ejecuta comandos reales dentro de esa carpeta. El motor no comprueba qué comando ha escrito, sino si el resultado final es correcto (los archivos correctos existen, los incorrectos han desaparecido, etc.).

### Estructura de un ejercicio

```powershell
@{
    Id = "borrar-logs"
    # Identificador único. El sistema Leitner lo usa para guardar
    # el progreso del alumno. No se puede repetir entre misiones.

    Titulo = "Limpia los logs viejos"
    # Nombre de la misión que ve el alumno.

    Objetivo = "Borra todos los archivos .log de la carpeta actual."
    # La instrucción completa.

    Pista = "Usa Remove-Item con un comodín *.log"
    # Sale cuando el alumno escribe "pista".

    Ejemplo = "Remove-Item *.log"
    # La solución. Sale cuando el alumno escribe "solucion".
    # Si la pide, cuenta como FALLO en Leitner.

    Setup = {
        # ── ScriptBlock que se ejecuta ANTES de empezar ──
        # Prepara el escenario creando archivos de prueba
        # dentro del sandbox (carpeta temporal segura).

        'error 1' | Set-Content 'app.log'
        # Crea un archivo app.log con el texto "error 1" dentro.

        'error 2' | Set-Content 'sistema.log'
        # Crea otro archivo .log

        'datos' | Set-Content 'datos.txt'
        # Crea un .txt que el alumno NO debe borrar.
    }

    Validar = { param($cmd, $salida)
        # ── ScriptBlock que se ejecuta DESPUÉS de cada comando ──
        #
        # $cmd    → lo que escribió el alumno (ej: "Remove-Item *.log")
        # $salida → lo que devolvió ese comando
        #
        # Debe devolver $true si la misión está cumplida, o $false si no.

        # ¿Quedan cero archivos .log?
        $sinLogs = (@(Get-ChildItem *.log -ErrorAction SilentlyContinue).Count -eq 0)

        # ¿Sigue existiendo datos.txt?
        $datosIntacto = (Test-Path 'datos.txt')

        # Las dos cosas tienen que ser verdad
        $sinLogs -and $datosIntacto
    }
}
```

### Desglose del Validar línea por línea

```powershell
@(Get-ChildItem *.log -ErrorAction SilentlyContinue)
#  │                    │
#  │                    └─ Si no hay ningún .log, no muestra error rojo,
#  │                       simplemente devuelve vacío.
#  │
#  └─ @( ) fuerza a que sea un array (aunque no encuentre nada,
#     devuelve un array vacío con .Count = 0, no $null).

.Count -eq 0
# ¿Hay cero archivos .log? Si sí → $true (los ha borrado todos).

-and
# Y además...

(Test-Path 'datos.txt')
# ¿Sigue existiendo datos.txt? Si sí → $true.
# Así comprobamos que no ha borrado todo indiscriminadamente.
```

### Cómo funciona el motor

```
Alumno escribe: tatami
    ↓
El motor elige una misión
    ↓
Crea una carpeta temporal (sandbox): C:\Users\...\Tatami_Sandbox
    ↓
Se mueve dentro: Set-Location $sandbox
    ↓
Ejecuta el Setup → se crean los archivos de prueba
    ↓
Muestra el Objetivo al alumno
    ↓
BUCLE: espera comandos del alumno
    ├─ "pista"    → muestra $mision.Pista
    ├─ "solucion" → muestra $mision.Ejemplo + cuenta como fallo
    ├─ otro       → ejecuta el comando
    │              → llama al Validar con lo que escribió y lo que salió
    │              → si devuelve $true → ✅ misión superada
    │              → si devuelve $false → sigue intentando
    ↓
Limpia el sandbox y registra en Leitner
```

### Dónde está el código

- **Banco de misiones:** cada archivo `Tatami1.ps1`, `Tatami2.ps1` tiene su banco
- **Motor de juego:** función `Invoke-TatamiEngine` en `Motor.ps1`
- **Seguridad:** el motor impide que el alumno salga del sandbox con `cd ..` o rutas absolutas

---

## Motor 3: RETO — Tareas por pasos

### Qué hace

Retos de 3-8 pasos que simulan tareas reales de administración. Cada paso puede ser:
- **Paso de acción** — El alumno hace algo y escribe `comprobar`
- **Paso de respuesta** — El alumno investiga y escribe `responder <valor>`

### Estructura de un ejercicio

```powershell
@{
    Id     = 'estructura'
    # Identificador único para el progreso Leitner.

    Nivel  = 1
    # Nivel de dificultad (1-5).

    Titulo = 'Crea la estructura de un proyecto'
    # Nombre del reto.

    Intro  = 'Un cliente te pide organizar las carpetas de su proyecto.'
    # Texto narrativo que se muestra al empezar.

    Concepto = 'Estructura de carpetas y archivos'
    # Concepto que se practica (para estadísticas).

    Inicio = 'proyecto'
    # Nombre de la carpeta raíz que se crea para el reto.

    Preparar = { param($Raiz)
        # ── ScriptBlock que prepara el escenario ──
        # $Raiz es la ruta completa de la carpeta de práctica.
        # Aquí creas archivos o carpetas iniciales si los necesitas.

        # (En este caso no necesitamos nada, el alumno lo crea todo)
    }

    Pasos = @(
        # ── Array de pasos ──
        # Cada paso es un hashtable con sus propios campos.

        # ─── PASO 1: paso de ACCIÓN ───
        @{
            T   = 'Crea las carpetas src, docs y tests dentro del proyecto.'
            # T = Texto del enunciado que ve el alumno.

            C   = { param($Raiz)
                # C = Comprobación (ScriptBlock).
                # $Raiz = carpeta del reto.
                # Debe devolver $true si está bien,
                # o un string con el mensaje de error si no.

                $esperadas = @('src', 'docs', 'tests')
                $existentes = Get-ChildItem $Raiz -Directory | Select-Object -ExpandProperty Name

                foreach ($c in $esperadas) {
                    if ($c -notin $existentes) {
                        return "Falta la carpeta '$c'."
                    }
                }
                return $true
            }

            P   = 'Usa mkdir tres veces, o mkdir src, docs, tests.'
            # P = Pista. Sale al escribir "pista".

            Ps  = 'mkdir src, docs, tests'
            # Ps = Solución en PowerShell.

            Cmd = 'mkdir src & mkdir docs & mkdir tests'
            # Cmd = Solución en CMD.
        },

        # ─── PASO 2: paso de RESPUESTA ───
        @{
            T   = '¿Cuántas carpetas has creado en total?'

            Esperada = { param($Raiz)
                # Esperada = ScriptBlock que devuelve la respuesta correcta.
                # El motor compara lo que diga el alumno con este valor.
                return '3'
            }

            Modo = 'exacto'
            # Modo de comparación:
            #   'exacto'  → debe coincidir exactamente (sin importar mayúsculas)
            #   'bool'    → solo sí/no, true/false
            #   'regex'   → se usa como expresión regular
            #   'enTexto' → la respuesta del alumno debe contener el valor

            P   = 'Cuenta las carpetas con (Get-ChildItem -Directory).Count'
            Ps  = '(Get-ChildItem -Directory).Count'
        }
    )
}
```

### La diferencia entre los dos tipos de paso

| | Paso de acción (`C`) | Paso de respuesta (`Esperada`) |
|---|---|---|
| **El alumno...** | Ejecuta un comando y escribe `comprobar` | Investiga y escribe `responder <valor>` |
| **El motor...** | Ejecuta el ScriptBlock `C` y mira si devuelve `$true` | Compara el valor con lo que devuelve `Esperada` |
| **Ejemplo** | "Crea la carpeta proyecto" → `comprobar` | "¿Cuántos archivos hay?" → `responder 3` |

### Funciones auxiliares disponibles en los retos

Dentro de los ScriptBlocks `Preparar` y `C`, puedes usar estas funciones que el motor proporciona:

```powershell
# Crear un archivo con contenido
New-RetoArchivo $Raiz 'config.txt' 'Contenido del archivo'

# Crear una carpeta
New-RetoCarpeta $Raiz 'subcarpeta'

# Unir rutas de forma segura
$ruta = _rp $Raiz 'src' 'main.py'  # → C:\...\proyecto\src\main.py

# Leer las líneas de un archivo (para comprobar contenido)
$lineas = Get-RetoLineas $Raiz 'config.txt'

# Listar nombres de archivos/carpetas
$nombres = Get-RetoNombres $Raiz  # solo carpeta raíz
$nombres = Get-RetoNombres $Raiz -Recurse  # recursivo

# Comparar si dos conjuntos son iguales (orden no importa)
Test-RetoMismoConjunto @('a','b','c') @('c','a','b')  # → $true
```

### Dónde está el código

- **Banco de retos:** función `Get-RetoBanco` en `Reto.ps1`
- **Motor de juego:** la lógica principal está en `Reto.ps1`
- **Sandbox:** el motor crea y limpia la carpeta de práctica automáticamente

---

## El sistema Leitner (Motor.ps1)

El archivo `Motor.ps1` contiene el motor de repaso espaciado que comparten los tres sistemas.

### Cómo funciona

```
Cada ejercicio tiene una "caja" (1 a 5) y una fecha de último intento.

    Caja 1 ──→ Caja 2 ──→ Caja 3 ──→ Caja 4 ──→ Caja 5
    (siempre)   (1 día)    (3 días)   (7 días)   (21 días)
        ↑                                            │
        └───────── si fallas, vuelves a caja 1 ──────┘

Al elegir qué ejercicio toca:
1. Primero: los que toca repasar (caja > 1 y han pasado los días)
2. Después: ejercicios nuevos (nunca hechos)
3. Por último: los de caja más baja (los que peor llevas)
```

### Funciones clave

| Función | Qué hace |
|---------|----------|
| `Register-CyberResultado` | Registra si acertaste ('ok'), pediste pista ('pista') o fallaste ('fail') |
| `Test-CyberDue` | Comprueba si un ejercicio toca hoy según su caja e intervalo |
| `Get-CyberEntrada` | Lee el progreso de un ejercicio desde el JSON |
| `Show-CyberStats` | Muestra estadísticas generales |

### Dónde se guarda el progreso

```
%LOCALAPPDATA%\CyberProfile\progreso.json
```

Estructura del JSON:

```json
{
    "dojo1:Listar": {
        "Caja": 3,
        "Ultimo": "2024-03-15T10:30:00"
    },
    "tatami1:borrar-logs": {
        "Caja": 1,
        "Ultimo": "2024-03-16T08:00:00"
    }
}
```

La clave es `prefijo:id` donde el prefijo identifica qué motor/nivel y el id es el ejercicio concreto.
