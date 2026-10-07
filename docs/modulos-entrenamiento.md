# Módulos de entrenamiento — Qué hace cada uno

El sistema tiene **14 scripts** organizados en módulos de práctica progresivos. Cada uno entrena un aspecto diferente de la terminal. Todos comparten el mismo sistema de repaso espaciado (Leitner), así que el progreso se acumula.

---

## Visión general

```
NIVEL 1 — Conocer los comandos
├── Dojo.ps1          → Q&A: ¿qué comando hace X? (nombre suelto)
├── Tatami1.ps1       → Sandbox: ejecuta el comando en un entorno real
└── Reto.ps1          → Retos por pasos: tareas de administración guiadas

NIVEL 2 — Usar los comandos con soltura
├── Dojo2.ps1         → Q&A: escribe el comando COMPLETO con parámetros
├── Tatami2.ps1       → Sandbox: misiones más complejas (pipelines, CSV, regex)
└── Reto.ps1          → Retos de nivel 2-3 (permisos, redirecciones, scripts)

NIVEL 3 — Escribir scripts
├── PwShell.ps1       → Retos de scripting PowerShell (niveles 1-4)
├── PwShell2.ps1      → Retos de scripting avanzado (niveles 4-5)
├── Comandos.ps1      → Retos de scripting CMD / .bat
├── Forja.ps1         → Escribe scripts completos con tests automáticos
└── Santuario.ps1     → Lo mismo que Forja, pero en Bash (vía WSL2)

SOPORTE
├── Motor.ps1         → Motor Leitner compartido + motores de Dojo y Tatami
├── Cyberpunk2077.ps1 → Cargador principal + tema visual (colores, banner)
├── Developer2077.ps1 → Cargador alternativo con herramientas de desarrollo
└── Dev.ps1           → Herramientas de desarrollo (git, Docker, API, proyectos)
```

---

## Dojo.ps1 — Q&A de comandos (nivel 1)

**Qué entrena:** Que el alumno sepa el nombre del comando para cada tarea, en Linux, PowerShell y CMD.

**Cómo funciona:** Te muestra una tarea ("Listar el contenido de una carpeta") y una plataforma ([PowerShell]). Escribes el nombre del comando. Si aciertas, sube de caja Leitner. Si fallas o pides pista, baja.

**Contenido:** ~26 tareas cubriendo las operaciones fundamentales:
- Sistema de archivos: listar, leer, copiar, mover, borrar, crear carpeta
- Búsqueda: grep/Select-String/findstr
- Procesos: listar, matar
- Red: IP, puertos, DNS, ping
- Sistema: ubicación, ayuda, limpiar pantalla, disco
- Pipeline de PowerShell: Where-Object (`?`), ForEach-Object (`%`), operadores, Select-Object

**Comando:** `dojo` o `dojo -Preguntas 10 -Modo Linux`

**Bonus:** `rosetta` muestra una tabla comparativa de todos los comandos Linux/PowerShell/CMD.

---

## Dojo2.ps1 — Q&A de comandos completos (nivel 2)

**Qué entrena:** Que el alumno sepa escribir el comando COMPLETO con parámetros, no solo el nombre.

**Diferencia con Dojo 1:** En el Dojo 1 basta con escribir `grep`. En el Dojo 2 tienes que escribir `grep -ri error logs` con los parámetros correctos.

**Cómo funciona:** El motor usa regex para aceptar variantes equivalentes (distinto orden de parámetros, alias, comillas opcionales). La validación es flexible pero exige el comando real.

**Contenido:** Tareas de nivel intermedio:
- Contar líneas de un archivo
- Seguir un log en vivo (tail -f / Get-Content -Wait)
- Buscar texto recursivamente
- Agrupar y contar ocurrencias
- Ordenar por columna, extraer campos
- Encontrar archivos por tamaño o fecha
- Permisos, usuarios, espacio en disco

**Comando:** `dojo2` o `dojo2 -Modo PowerShell`

---

## Tatami1.ps1 — Misiones en sandbox (nivel 1)

**Qué entrena:** Ejecutar comandos reales en un entorno seguro, comprobando el resultado (no el comando que escribes).

**Cómo funciona:** Se crea una carpeta temporal con archivos de prueba. Ejecutas los comandos que quieras. El motor comprueba si el estado final del sistema de archivos es correcto.

**Contenido:** Misiones básicas:
- Filtrar archivos por extensión (`.log`, `.txt`)
- Encontrar archivos pesados (filtro por tamaño con `-gt`)
- Crear estructura de carpetas
- Borrar selectivamente
- Renombrar archivos
- Copiar con filtros

**Comando:** `tatami`

**Seguridad:** El sandbox impide que el alumno salga de la carpeta temporal (`cd ..` o rutas absolutas se bloquean).

---

## Tatami2.ps1 — Misiones de nivel intermedio

**Qué entrena:** Combinar comandos con pipelines, manipular texto, exportar datos, renombrar en masa.

**Contenido:** Misiones más complejas:
- Ordenar y quedarte con los top 3 (Sort-Object + Select-Object)
- Buscar texto dentro de un log (Select-String)
- Exportar datos a CSV
- Renombrar archivos en masa con patrones
- Crear usuarios desde un CSV
- Manejo de errores con Try/Catch

**Comando:** `tatami2`

---

## Reto.ps1 — Retos por pasos (niveles 1-5)

**Qué entrena:** Tareas reales de administración de sistemas, divididas en pasos guiados. El alumno practica un flujo completo, no un comando suelto.

**Cómo funciona:** Cada reto tiene 3-8 pasos. Cada paso puede ser:
- **Acción:** Haces algo y escribes `comprobar` — el motor verifica si lo hiciste bien
- **Pregunta:** Investigas y escribes `responder <valor>` — el motor compara tu respuesta

**Contenido por nivel:**
- **Nivel 1:** Estructura de carpetas, archivos ocultos, permisos de solo lectura, mover/copiar/renombrar, redirecciones
- **Nivel 2:** Permisos avanzados, búsqueda con comodines, conteo de archivos, scripting básico
- **Nivel 3-5:** Tareas más complejas de administración

**Comandos:** `reto`, `comprobar`, `responder <valor>`, `pista`, `solucion`, `pasos`, `paso`, `reto-salir`

---

## PwShell.ps1 — Scripting PowerShell (niveles 1-4)

**Qué entrena:** Escribir scripts de PowerShell desde cero: variables, operadores, condicionales, bucles, funciones, arrays, hashtables.

**Cómo funciona:** Te da un reto de scripting con enunciado y pistas. Escribes el script en tu editor, lo pruebas y lo verificas. Usa su propio sistema Leitner independiente.

**Contenido (~40 retos):**
- **Nivel 1:** Variables, tipos, operadores, strings
- **Nivel 2:** If/else, switch, bucles (for, foreach, while), arrays
- **Nivel 3:** Funciones con parámetros, hashtables, pipeline, Where/ForEach/Select
- **Nivel 4:** Archivos (Get-Content, Set-Content), regex, manejo de errores, módulos

**Comando:** `pwshell`

---

## PwShell2.ps1 — Scripting avanzado (niveles 4-5)

**Qué entrena:** Scripting avanzado de PowerShell para administración de sistemas: JSON, CSV, servicios, usuarios, registro de Windows, tareas programadas.

**Contenido (~42 retos):**
- **Nivel 4:** JSON (ConvertFrom-Json, ConvertTo-Json), CSV (Import-Csv, Export-Csv), XML
- **Nivel 5:** Gestión de servicios, usuarios locales, registro de Windows, tareas programadas, inventario de sistema, logs de eventos

**Comando:** `pwshell2`

---

## Comandos.ps1 — Scripting CMD / .bat

**Qué entrena:** Escribir scripts por lotes de CMD (.bat): variables con `%`, `set`, `if`, `for`, `goto`, redirecciones, pipes y atajos de cmd.

**Cómo funciona:** Igual que PwShell, pero los retos son de CMD/batch. Útil para entornos Windows Server donde solo tienes cmd.

**Comando:** `comandos`

---

## Forja.ps1 — Escribir scripts completos (PowerShell)

**Qué entrena:** Escribir funciones y scripts completos de PowerShell y verificarlos con tests automáticos.

**Cómo funciona:**
1. `forja` te asigna una misión y abre un archivo de plantilla en tu editor (VS Code o el que tengas)
2. Escribes tu función/script y guardas
3. Vuelves a la terminal y pulsas Enter: Forja ejecuta tu código contra varios casos de prueba
4. Te dice cuáles pasan y cuáles no. No compara tu código con una solución: comprueba que FUNCIONA

**Diferencia con PwShell:** En PwShell escribes fragmentos cortos. En Forja escribes funciones completas con múltiples casos de prueba, simulando el flujo real de desarrollo (editar → guardar → testear → corregir).

**Comando:** `forja`

---

## Santuario.ps1 — Escribir scripts en Bash (vía WSL2)

**Qué entrena:** Lo mismo que Forja, pero en Bash. El código se ejecuta en tu Linux (WSL2).

**Cómo funciona:** Se lanza desde PowerShell, pero el script se ejecuta dentro de WSL2 Ubuntu. Maneja automáticamente la conversión de rutas Windows ↔ Linux y de saltos de línea CRLF → LF.

**Requisito:** WSL2 con una distribución de Linux instalada (Ubuntu recomendado).

**Comando:** `santuario`

---

## Motor.ps1 — El cerebro del sistema

**Qué es:** El motor compartido que gestiona:
- El sistema de repaso espaciado **Leitner** (5 cajas, intervalos 0/1/3/7/21 días)
- El guardado de progreso en JSON
- El motor de ejecución del **Dojo** (Invoke-DojoEngine)
- El motor de ejecución del **Tatami** (Invoke-TatamiEngine)
- Las estadísticas de progreso (Show-CyberStats)

**No se ejecuta directamente.** Se carga automáticamente al cargar el tema (Cyberpunk2077.ps1 o Developer2077.ps1).

---

## Cyberpunk2077.ps1 — Cargador principal

**Qué hace:** Carga todo el sistema:
1. Define la función `Write-Cyber` (colores ANSI)
2. Define la paleta de colores del tema Cyberpunk 2077
3. Carga Motor.ps1, Dojo.ps1, Dojo2.ps1, Tatami1.ps1, Tatami2.ps1, Reto.ps1, Forja.ps1, Santuario.ps1
4. Muestra el banner de bienvenida
5. Crea los alias (`dojo`, `tatami`, `reto`, `rosetta`, etc.)

**Uso:** `. .\Cyberpunk2077.ps1` (dot-source desde tu perfil de PowerShell)

---

## Developer2077.ps1 — Cargador para desarrolladores

**Qué es:** Una variante del cargador principal que añade herramientas de desarrollo (DAM/DAW) además del sistema de entrenamiento:
- Todo lo de Cyberpunk2077.ps1 (entrenamiento, motores, tema)
- **Más** las herramientas de Dev.ps1

**Uso:** `. .\Developer2077.ps1` (en vez de Cyberpunk2077.ps1 si eres desarrollador)

---

## Dev.ps1 — Herramientas de desarrollo

**Qué es:** Funciones útiles para el día a día de un desarrollador (DAM/DAW). No es entrenamiento, son herramientas reales:
- **Entorno:** Info del sistema, versiones instaladas (Node, Python, .NET)
- **Git:** Atajos para log, status, push, stash
- **Compilar:** Ejecutar proyectos (Node, Python, .NET)
- **Red:** Ver puertos en uso, matar procesos por puerto
- **Docker:** Atajos para contenedores y bases de datos
- **API:** Servidor web rápido, tests HTTP
- **Proyectos:** Scaffolding para proyectos nuevos
- **Seguridad:** Buscar secretos expuestos, revisar .env
- **Limpieza:** Borrar node_modules, __pycache__, .vs, etc.

**No se ejecuta solo.** Se carga a través de Developer2077.ps1.

---

## Diagrama de dependencias

```
Cyberpunk2077.ps1 ──────┐
   (o Developer2077.ps1 ─┤── carga Dev.ps1)
                         │
                         ├── Motor.ps1 (Leitner + motores Dojo/Tatami)
                         ├── Dojo.ps1
                         ├── Dojo2.ps1
                         ├── Tatami1.ps1
                         ├── Tatami2.ps1
                         ├── Reto.ps1
                         ├── Forja.ps1
                         ├── Santuario.ps1 (necesita WSL2)
                         ├── PwShell.ps1
                         ├── PwShell2.ps1
                         └── Comandos.ps1
```

---

## Ruta de aprendizaje recomendada

| Semana | Módulos | Objetivo |
|--------|---------|----------|
| 1-2 | `dojo` + `tatami` | Conocer los comandos básicos de las 3 plataformas |
| 3-4 | `reto` (nivel 1) + `dojo2` | Hacer tareas reales de archivos/carpetas, comandos completos |
| 5-6 | `tatami2` + `reto` (nivel 2) | Pipelines, filtros, exportar datos |
| 7-8 | `pwshell` | Empezar a escribir scripts de PowerShell |
| 9-10 | `pwshell2` + `forja` | Scripting avanzado y scripts completos con tests |
| 11-12 | `comandos` + `santuario` | CMD/.bat y Bash para completar las 3 plataformas |

> Esta es una sugerencia. Los alumnos pueden empezar por donde les interese más. El sistema Leitner se encarga de repasar lo que van olvidando.
