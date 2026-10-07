# Ejercicio: Monta tu terminal profesional desde cero

**Módulo:** ASIR / DAM / DAW — Transversal
**Duración estimada:** 2-3 horas
**Requisitos:** Windows 10/11

---

## Objetivo

Configurar una terminal moderna y funcional en Windows paso a paso. Al terminar tendrás una terminal con prompt personalizado, iconos, autocompletado inteligente, y las herramientas básicas de un administrador de sistemas o desarrollador instaladas.

Este no es un ejercicio de copiar y pegar: cada paso incluye preguntas que debes responder para demostrar que entiendes qué estás haciendo y por qué.

---

## Parte 1 — Windows Terminal y fuente (20 min)

### 1.1. Instalar Windows Terminal

1. Abre la **Microsoft Store** y busca "Windows Terminal"
2. Instálalo
3. Ábrelo

> **Pregunta 1:** ¿Qué diferencia hay entre "Windows Terminal" y la ventana que se abre cuando escribes `cmd` en el menú Inicio? Nombra al menos 2 diferencias.

### 1.2. Instalar una Nerd Font

1. Ve a [nerdfonts.com/font-downloads](https://www.nerdfonts.com/font-downloads)
2. Descarga **Hack Nerd Font** (o la que prefieras)
3. Descomprime el .zip
4. Selecciona todos los archivos `.ttf`, clic derecho → "Instalar para todos los usuarios"
5. En Windows Terminal → Configuración → Perfil predeterminado → Apariencia → Tipo de letra → **Hack Nerd Font**

> **Pregunta 2:** ¿Por qué necesitamos una "Nerd Font" y no basta con la fuente que viene por defecto? ¿Qué pasaría si usamos Oh My Posh sin una Nerd Font instalada?

### 1.3. Ajustar la apariencia básica

En Windows Terminal → Configuración:

1. Cambia el **esquema de color** a "One Half Dark" o "Dark+"
2. Pon la **opacidad** entre 80-90% y activa el **efecto acrílico**
3. Oculta la barra de scroll si quieres (Apariencia → Estado de la barra de desplazamiento → Oculta)

> **Pregunta 3:** ¿Dónde se guarda toda esta configuración? Busca el archivo `settings.json` de Windows Terminal y pega aquí su ruta completa.
>
> **Pista:** `$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\`

---

## Parte 2 — PowerShell 7 y ejecución de scripts (15 min)

### 2.1. Instalar PowerShell 7

```powershell
winget install Microsoft.PowerShell
```

Cierra y vuelve a abrir Windows Terminal.

> **Pregunta 4:** Ahora tienes dos versiones de PowerShell. Ejecuta estos dos comandos en cada una y compara:
> ```powershell
> $PSVersionTable.PSVersion
> $PSVersionTable.PSEdition
> ```
> ¿Qué versión tiene cada una? ¿Cuál dice "Core" y cuál dice "Desktop"?

### 2.2. Permitir la ejecución de scripts

```powershell
Get-ExecutionPolicy
```

> **Pregunta 5:** ¿Qué política de ejecución tienes ahora? ¿Qué significa?

Cambia a `RemoteSigned`:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

> **Pregunta 6:** ¿Qué diferencia hay entre `Restricted`, `RemoteSigned` y `Unrestricted`? ¿Por qué NO usamos `Unrestricted`?

### 2.3. Configurar PowerShell 7 como perfil predeterminado

En Windows Terminal → Configuración → Inicio → Perfil predeterminado → selecciona "PowerShell" (el negro, no el azul).

---

## Parte 3 — Oh My Posh (20 min)

### 3.1. Instalar Oh My Posh

```powershell
winget install JanDeDobbeleer.OhMyPosh
```

Cierra y reabre la terminal.

### 3.2. Probar un tema

```powershell
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
```

> **Pregunta 7:** ¿Qué ha cambiado en tu prompt? Describe lo que ves ahora comparado con antes.

### 3.3. Explorar temas

```powershell
Get-PoshThemes
```

Esto muestra una vista previa de todos los temas disponibles. Elige el que más te guste.

> **Pregunta 8:** ¿Qué tema has elegido y por qué? ¿Qué información muestra en el prompt?

### 3.4. Hacerlo permanente

```powershell
# Crear el perfil si no existe:
if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force }

# Abrirlo en el bloc de notas:
notepad $PROFILE
```

Añade la línea de Oh My Posh con tu tema elegido:

```powershell
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\NOMBRE_DEL_TEMA.omp.json" | Invoke-Expression
```

Guarda, cierra y reabre la terminal.

> **Pregunta 9:** ¿Qué es el archivo `$PROFILE`? ¿Cuál es su ruta completa en tu sistema? ¿Cuándo se ejecuta?

---

## Parte 4 — Módulos de PowerShell (20 min)

### 4.1. Terminal-Icons

```powershell
Install-Module Terminal-Icons -Scope CurrentUser -Force
Import-Module Terminal-Icons
Get-ChildItem
```

> **Pregunta 10:** ¿Qué diferencia ves ahora al hacer `Get-ChildItem` comparado con antes de instalar Terminal-Icons?

Añade a tu `$PROFILE`:
```powershell
Import-Module Terminal-Icons
```

### 4.2. PSReadLine — Predicción inteligente

Añade a tu `$PROFILE`:
```powershell
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
```

Guarda, reabre la terminal y empieza a escribir un comando que hayas usado antes.

> **Pregunta 11:** ¿Qué pasa ahora cuando empiezas a escribir un comando? ¿De dónde saca las sugerencias?

### 4.3. Módulo z (salto rápido a carpetas)

```powershell
Install-Module z -Scope CurrentUser -Force
```

Añade a tu `$PROFILE`:
```powershell
Import-Module z
```

Navega a varias carpetas (Documents, Desktop, algún proyecto...) para que `z` las aprenda. Después prueba:

```powershell
z Documents
z Desktop
```

> **Pregunta 12:** ¿Cómo sabe `z` a qué carpeta ir? ¿Funcionará la primera vez que lo instales sin haber navegado a ningún sitio?

---

## Parte 5 — Herramientas esenciales (30 min)

### 5.1. Git

```powershell
winget install Git.Git
```

Cierra y reabre la terminal. Verifica:
```powershell
git --version
```

> **Pregunta 13:** Entra en una carpeta que sea un repositorio git (o crea uno con `git init`). ¿Qué muestra ahora tu prompt de Oh My Posh que antes no mostraba?

### 5.2. Visual Studio Code

```powershell
winget install Microsoft.VisualStudioCode
```

Verifica que puedes abrirlo desde la terminal:
```powershell
code .
```

> **Pregunta 14:** ¿Qué terminal integrada usa VS Code por defecto? ¿Es la misma versión de PowerShell que estás usando en Windows Terminal?

### 5.3. WSL2 (Windows Subsystem for Linux)

```powershell
wsl --install
```

Reinicia Windows cuando lo pida. Después de reiniciar, se abrirá Ubuntu y te pedirá un usuario y contraseña.

```powershell
# Verificar que funciona:
wsl -l -v
```

> **Pregunta 15:** Ejecuta `uname -a` dentro de WSL. ¿Qué kernel de Linux está usando? ¿Es un Linux "real" o una emulación?

### 5.4. Herramientas extra (elige al menos 2)

Instala al menos 2 de estas y pruébalas:

| Herramienta | Instalar | Probar |
|-------------|----------|--------|
| `bat` (cat con colores) | `winget install sharkdp.bat` | `bat $PROFILE` |
| `fzf` (buscador fuzzy) | `winget install junegunn.fzf` | `Get-ChildItem -Recurse \| fzf` |
| `ripgrep` (grep rápido) | `winget install BurntSushi.ripgrep.MSVC` | `rg "function" $PROFILE` |
| `jq` (procesar JSON) | `winget install jqlang.jq` | `'{"nombre":"test"}' \| jq .nombre` |

> **Pregunta 16:** ¿Qué dos herramientas has instalado? Para cada una, explica qué ventaja tiene sobre el comando nativo equivalente (bat vs cat/type, rg vs Select-String, etc.)

---

## Parte 6 — Perfil final y documentación (30 min)

### 6.1. Tu perfil completo

Abre tu `$PROFILE` y asegúrate de que tiene todo lo que has configurado. Debería ser algo parecido a esto (adaptado con tus elecciones):

```powershell
# Tu tema de Oh My Posh
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\tu-tema.omp.json" | Invoke-Expression

# Módulos
Import-Module Terminal-Icons
Import-Module z

# Autocompletado
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# Alias personales (añade los que quieras)
Set-Alias ll Get-ChildItem
Set-Alias g git
```

### 6.2. Captura de pantalla

Haz una captura de pantalla de tu terminal final mostrando:
- Tu prompt personalizado
- Los iconos de Terminal-Icons al hacer `Get-ChildItem`
- El autocompletado predictivo funcionando

### 6.3. Documento de configuración

Escribe un documento breve (1-2 páginas) con:
1. **Qué has instalado** — Lista de todo lo que has configurado
2. **Tu archivo `$PROFILE` completo** — Copia y pega el contenido
3. **Tu `settings.json` de Windows Terminal** — Las partes que has modificado
4. **Las respuestas a las 16 preguntas** de este ejercicio

---

## Entrega

- El documento con las respuestas y configuración
- La captura de pantalla de tu terminal
- (Opcional) Una captura del archivo `$PROFILE` abierto en VS Code

---

## Rúbrica orientativa

| Criterio | Peso | Excelente | Suficiente | Insuficiente |
|----------|------|-----------|------------|--------------|
| **Instalación completa** | 30% | Todo instalado y funcionando: WT, fuente, OMP, módulos, herramientas | Falta algún componente menor | Falta Windows Terminal, OMP o la fuente |
| **Perfil de PowerShell** | 25% | Perfil completo, bien organizado, con comentarios | Perfil funcional pero desordenado | No tiene perfil o no carga al abrir |
| **Respuestas a preguntas** | 30% | Respuestas correctas que demuestran comprensión real | Respuestas correctas pero superficiales | Respuestas incorrectas o copiadas |
| **Captura y documentación** | 15% | Captura clara mostrando todo, documento bien estructurado | Captura borrosa o documento incompleto | Sin captura o documento |
