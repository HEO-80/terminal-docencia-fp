# Instalación y primeros pasos

## Requisitos

- **Windows 10 o 11** — PowerShell 5.1 ya viene instalado
- **Windows Terminal** — Recomendado para mejor experiencia visual (colores, fuentes). Se instala gratis desde la Microsoft Store.
- **Git** — Para clonar el repositorio. Si no lo tienes: [git-scm.com](https://git-scm.com/download/win)

### Opcional

- **Oh My Posh** — Para el prompt personalizado con iconos y colores: [ohmyposh.dev](https://ohmyposh.dev/)
- **Una fuente Nerd Font** — Para que los iconos se vean bien. Recomendada: Cascadia Mono + BlexMono Nerd Font
- **WSL2** — Si quieres practicar también con Bash/Linux: [docs.microsoft.com/wsl](https://learn.microsoft.com/es-es/windows/wsl/install)

---

## Instalación paso a paso

### 1. Clonar el repositorio

Abre PowerShell (o Windows Terminal) y ejecuta:

```powershell
cd ~\Documents
git clone https://github.com/HEO-80/terminal-docencia-fp.git
```

### 2. Permitir ejecución de scripts

PowerShell bloquea la ejecución de scripts por defecto. Para desbloquearlo (solo necesitas hacerlo una vez):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Esto permite ejecutar scripts locales pero sigue bloqueando scripts descargados de internet que no estén firmados.

### 3. Cargar el entrenamiento

```powershell
cd ~\Documents\terminal-docencia-fp\entrenamiento
. .\Cyberpunk2077.ps1
```

> **Importante:** El punto y el espacio (`. .`) antes de la ruta son necesarios. Esto se llama "dot-sourcing" y hace que las funciones y variables del script queden disponibles en tu sesión actual. Si lo ejecutas sin el punto (`.\Cyberpunk2077.ps1`), el script se ejecuta en un ámbito separado y las funciones no quedan accesibles.

### 4. Probar que funciona

```powershell
dojo           # Empieza una ronda de preguntas de comandos
tatami         # Empieza una misión en sandbox
reto           # Empieza un reto por pasos
rosetta        # Muestra la tabla de referencia de comandos
```

---

## Carga automática (opcional)

Si quieres que se cargue automáticamente cada vez que abres PowerShell, añade estas líneas a tu perfil de PowerShell:

```powershell
# Abre tu perfil en el bloc de notas:
notepad $PROFILE

# Añade esta línea al final del archivo:
. "$HOME\Documents\terminal-docencia-fp\entrenamiento\Cyberpunk2077.ps1"
```

> Si el archivo `$PROFILE` no existe, créalo primero:
> ```powershell
> New-Item -Path $PROFILE -ItemType File -Force
> ```

---

## Comandos disponibles tras cargar

| Comando | Qué hace |
|---------|----------|
| `dojo` | Ronda de preguntas Q&A de comandos (Linux/PowerShell/CMD) |
| `dojo -Preguntas 10` | Ronda de 10 preguntas en vez de 5 |
| `dojo -Modo Linux` | Solo preguntas de Linux |
| `dojo -Repaso` | Solo preguntas que toca repasar hoy |
| `tatami` | Misión en sandbox (ejecutar comandos reales) |
| `reto` | Reto por pasos (tareas de administración) |
| `rosetta` | Tabla de referencia cruzada de comandos |
| `comprobar` | (Dentro de un reto) Comprueba si el paso actual está hecho |
| `responder <valor>` | (Dentro de un reto) Responde a una pregunta del reto |
| `pista` | (Dentro de dojo/tatami/reto) Muestra una pista |
| `solucion` | (Dentro de dojo/tatami/reto) Muestra la solución (cuenta como fallo) |
| `pasos` | (Dentro de un reto) Muestra todos los pasos del reto actual |
| `paso` | (Dentro de un reto) Muestra el paso actual |
| `reto-salir` | (Dentro de un reto) Sale del reto actual |

---

## Problemas comunes

### "No se puede cargar el archivo porque la ejecución de scripts está deshabilitada"

Ejecuta:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Los colores o iconos no se ven bien

- Instala Windows Terminal desde la Microsoft Store
- Instala una fuente Nerd Font (ej: `Hack Nerd Font` o `CaskaydiaCove Nerd Font`)
- En Windows Terminal → Configuración → Perfil → Apariencia → Tipo de letra → Selecciona la Nerd Font

### Los caracteres especiales (tildes, ñ) se ven mal

Los archivos deben estar guardados como **UTF-8 con BOM**. Si editas algún archivo:
- En VS Code: abajo a la derecha, clic en "UTF-8" → "Save with Encoding" → "UTF-8 with BOM"
- En Notepad++: Menú Codificación → Codificar en UTF-8-BOM

### El progreso no se guarda

Comprueba que exista la carpeta `%LOCALAPPDATA%\CyberProfile\`. El motor la crea automáticamente la primera vez, pero si no tiene permisos puede fallar. Puedes crearla manualmente:

```powershell
mkdir "$env:LOCALAPPDATA\CyberProfile" -Force
```
