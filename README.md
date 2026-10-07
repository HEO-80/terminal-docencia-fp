# 🖥️ Terminal Docencia FP

**Material de enseñanza de terminal (PowerShell, CMD y Bash) para Formación Profesional.**

Repositorio público con scripts de entrenamiento interactivo, documentación y recursos para enseñar el uso profesional de la terminal en ciclos como ASIR, DAM, DAW y SMR.

---

## ¿Qué es esto?

Un conjunto de herramientas de práctica para que los alumnos aprendan a usar la terminal de verdad, no solo leyendo apuntes. Incluye:

- **Entrenamiento interactivo** con sistema de repaso espaciado (Leitner) que recuerda qué fallas y te lo vuelve a preguntar
- **Tres modos de práctica** distintos: preguntas rápidas, misiones en sandbox y retos por pasos
- **Multiplataforma**: ejercicios en PowerShell, CMD y Bash/Linux
- **Documentación para profesores** que quieran usarlo o adaptarlo

Todo funciona directamente en PowerShell 5.1 (el que viene con Windows 10/11), sin instalar nada extra.

---

## Estructura del repositorio

```
terminal-docencia-fp/
├── entrenamiento/              # Scripts de práctica interactiva
│   ├── Motor.ps1               # Motor de repaso espaciado (Leitner)
│   ├── Cyberpunk2077.ps1       # Cargador y tema visual
│   ├── Dojo.ps1                # Dojo nivel 1 — Q&A de comandos
│   ├── Dojo2.ps1               # Dojo nivel 2 — Q&A avanzado
│   ├── Tatami1.ps1             # Tatami nivel 1 — Misiones en sandbox
│   ├── Tatami2.ps1             # Tatami nivel 2 — Misiones avanzadas
│   ├── Reto.ps1                # Retos por pasos (archivos, permisos...)
│   ├── Forja.ps1               # Escribir scripts completos
│   ├── Santuario.ps1           # Práctica Linux/Bash (vía WSL2)
│   ├── PwShell.ps1             # Práctica PowerShell niveles 1-4
│   ├── PwShell2.ps1            # Práctica PowerShell niveles 4-5
│   ├── Comandos.ps1            # Práctica CMD
│   ├── Dev.ps1                 # Herramientas de desarrollo
│   └── Developer2077.ps1       # Herramientas de desarrollo v2
│
├── docs/                       # Documentación
│   ├── instalacion.md          # Cómo instalar y empezar
│   ├── motores.md              # Cómo funcionan los 3 motores de práctica
│   ├── anadir-ejercicios.md    # Cómo añadir tus propios ejercicios
│   ├── comandos-esenciales.md  # Guía de referencia de comandos
│   ├── modulos-entrenamiento.md # Qué hace cada uno de los 14 scripts
│   ├── personalizar-terminal.md # Guía de personalización de terminal
│   └── ejercicio-montar-terminal.md # Ejercicio: monta tu terminal profesional
│
├── ejemplos/                   # Scripts de ejemplo para clase
│   └── (próximamente)
│
├── LICENSE
└── README.md
```

---

## Los 3 motores de entrenamiento

### 🥋 Dojo — Preguntas y respuestas

> "¿Qué comando lista los procesos en ejecución?"

El alumno escribe el comando. Si acierta, sube de caja en el sistema Leitner y tarda más en volver a salir. Si falla o pide pista, baja y sale antes.

Cubre comandos de Linux, PowerShell y CMD en paralelo (tabla Rosetta).

### 🥊 Tatami — Misiones en sandbox

> "Borra todos los archivos .log sin tocar los .txt"

Se crea una carpeta temporal con archivos de prueba. El alumno ejecuta comandos reales. El motor comprueba el resultado (no el comando que has escrito, sino si el estado del sistema es correcto).

### ⚔️ Reto — Tareas por pasos

> Paso 1: "Crea una carpeta llamada proyecto"
> Paso 2: "Dentro, crea un archivo config.txt con tu nombre"
> Paso 3: "¿Cuántos archivos hay en la carpeta?"

Retos de 3-8 pasos donde cada paso puede ser una acción (ejecutar algo y escribir `comprobar`) o una pregunta (escribir `responder 3`). Simula tareas reales de administración de sistemas.

---

## Sistema de repaso espaciado (Leitner)

Todos los motores comparten un sistema que recuerda tu progreso:

| Caja | Intervalo | Significado |
|------|-----------|-------------|
| 1    | 0 días    | Nuevo o fallado → sale siempre |
| 2    | 1 día     | Acertado una vez |
| 3    | 3 días    | Lo vas dominando |
| 4    | 7 días    | Repaso semanal |
| 5    | 21 días   | Dominado, repaso mensual |

- **Acierto** → sube una caja (se pregunta menos)
- **Pista/fallo** → baja a caja 1 (se pregunta enseguida)

El progreso se guarda en `%LOCALAPPDATA%\CyberProfile\progreso.json`.

---

## Instalación rápida

### Requisitos

- Windows 10/11 con PowerShell 5.1 (ya viene instalado)
- Windows Terminal (recomendado, se instala desde la Microsoft Store)

### Pasos

1. **Clona el repositorio:**
   ```powershell
   git clone https://github.com/HEO-80/terminal-docencia-fp.git
   ```

2. **Abre PowerShell y permite la ejecución de scripts** (solo la primera vez):
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Carga el entrenamiento:**
   ```powershell
   cd terminal-docencia-fp/entrenamiento
   . .\Cyberpunk2077.ps1
   ```

4. **Empieza a practicar:**
   ```powershell
   dojo              # Preguntas de comandos
   tatami             # Misiones en sandbox
   reto               # Retos por pasos
   rosetta            # Tabla de referencia de comandos
   ```

> 📖 Guía detallada en [docs/instalacion.md](docs/instalacion.md)

---

## Para profesores

Si quieres usar esto con tus alumnos o añadir tus propios ejercicios:

- **[Cómo funcionan los motores](docs/motores.md)** — Explicación técnica de cómo está programado cada motor, con ejemplos de sintaxis PowerShell desde cero
- **[Cómo añadir ejercicios](docs/anadir-ejercicios.md)** — Guía paso a paso para crear tus propios ejercicios en cada motor
- **[Guía de comandos esenciales](docs/comandos-esenciales.md)** — Referencia cruzada Linux / PowerShell / CMD
- **[Descripción de los 14 módulos](docs/modulos-entrenamiento.md)** — Qué hace cada script, qué entrena y ruta de aprendizaje recomendada

### Para alumnos

- **[Personalizar tu terminal](docs/personalizar-terminal.md)** — Guía completa: Windows Terminal, Oh My Posh, Nerd Fonts, módulos, herramientas CLI y $PROFILE
- **[Ejercicio: Monta tu terminal profesional](docs/ejercicio-montar-terminal.md)** — Práctica guiada con 16 preguntas para configurar tu terminal desde cero

---

## ¿Para quién es?

- **Alumnos de FP** (ASIR, DAM, DAW, SMR) que necesitan aprender a usar la terminal
- **Profesores de FP** que buscan material práctico de terminal
- **Cualquier persona** que quiera aprender PowerShell, CMD o Bash de forma práctica
- **Administradores de sistemas** que quieran repasar o cambiar de plataforma

---

## Compatibilidad

- ✅ PowerShell 5.1 (Windows 10/11)
- ✅ PowerShell 7.x
- ✅ Windows Terminal
- ✅ Terminal integrado de VS Code
- ⚠️ Los archivos deben guardarse como **UTF-8 con BOM** y con saltos de línea **CRLF** si se usan en PowerShell 5.1

---

## Contribuir

¿Quieres añadir ejercicios, corregir algo o traducir? Las Pull Requests son bienvenidas.

Lee [docs/anadir-ejercicios.md](docs/anadir-ejercicios.md) para ver cómo se estructura un ejercicio en cada motor.

---

## Licencia

Este proyecto está bajo la licencia [MIT](LICENSE). Úsalo, modifícalo y compártelo libremente.

---

## Autor

**Hector Eduardo Oviedo** — Profesor de FP (DAM, DAW, SMR, ASIR) en Zaragoza

- GitHub: [@HEO-80](https://github.com/HEO-80)
- LinkedIn: [Hector Eduardo Oviedo](https://www.linkedin.com/in/hectoreduardooviedo/)
