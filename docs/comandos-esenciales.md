# Guía de comandos esenciales — Linux / PowerShell / CMD

Referencia cruzada de los comandos más usados en administración de sistemas. Para cada tarea, se muestra el comando equivalente en cada plataforma.

---

## Navegación y sistema de archivos

| Tarea | Linux | PowerShell | CMD |
|-------|-------|------------|-----|
| Ver carpeta actual | `pwd` | `Get-Location` (alias `pwd`, `gl`) | `cd` (sin argumentos) |
| Listar contenido | `ls` | `Get-ChildItem` (alias `ls`, `dir`, `gci`) | `dir` |
| Listar con detalle | `ls -la` | `Get-ChildItem | Format-List` | `dir /a` |
| Listar solo carpetas | `ls -d */` | `Get-ChildItem -Directory` | `dir /ad` |
| Listar recursivo | `ls -R` | `Get-ChildItem -Recurse` | `dir /s` |
| Cambiar de carpeta | `cd ruta` | `Set-Location ruta` (alias `cd`) | `cd ruta` |
| Ir al home | `cd ~` | `Set-Location ~` | `cd %USERPROFILE%` |
| Ir a la raíz | `cd /` | `Set-Location C:\` | `cd \` |
| Limpiar pantalla | `clear` | `Clear-Host` (alias `cls`) | `cls` |

---

## Archivos y carpetas

| Tarea | Linux | PowerShell | CMD |
|-------|-------|------------|-----|
| Crear carpeta | `mkdir nombre` | `mkdir nombre` o `New-Item -ItemType Directory` | `mkdir nombre` |
| Crear archivo vacío | `touch archivo` | `New-Item archivo` | `type nul > archivo` |
| Crear archivo con texto | `echo "texto" > archivo` | `'texto' \| Set-Content archivo` | `echo texto > archivo` |
| Copiar archivo | `cp origen destino` | `Copy-Item origen destino` | `copy origen destino` |
| Copiar carpeta | `cp -r origen destino` | `Copy-Item origen destino -Recurse` | `xcopy origen destino /E /I` |
| Mover/renombrar | `mv origen destino` | `Move-Item origen destino` | `move origen destino` |
| Renombrar | `mv viejo nuevo` | `Rename-Item viejo nuevo` | `ren viejo nuevo` |
| Borrar archivo | `rm archivo` | `Remove-Item archivo` | `del archivo` |
| Borrar carpeta | `rm -r carpeta` | `Remove-Item carpeta -Recurse` | `rmdir /s /q carpeta` |
| Ver contenido archivo | `cat archivo` | `Get-Content archivo` (alias `cat`, `gc`) | `type archivo` |
| Ver últimas líneas | `tail -n 5 archivo` | `Get-Content archivo -Tail 5` | — |
| Ver primeras líneas | `head -n 5 archivo` | `Get-Content archivo -TotalCount 5` | — |
| Buscar texto en archivo | `grep "texto" archivo` | `Select-String "texto" archivo` | `findstr "texto" archivo` |
| Buscar archivos por nombre | `find . -name "*.log"` | `Get-ChildItem -Recurse -Filter *.log` | `dir /s *.log` |
| Ver tamaño archivo | `ls -lh archivo` | `(Get-Item archivo).Length` | `dir archivo` |
| Permisos (ver) | `ls -l` | `Get-Acl archivo` | `icacls archivo` |
| Permisos (cambiar) | `chmod 755 archivo` | `Set-Acl` o `icacls` | `icacls archivo /grant ...` |
| Ocultar archivo | `mv archivo .archivo` | `(Get-Item archivo).Attributes = 'Hidden'` | `attrib +h archivo` |

---

## Procesos y servicios

| Tarea | Linux | PowerShell | CMD |
|-------|-------|------------|-----|
| Listar procesos | `ps aux` | `Get-Process` (alias `ps`) | `tasklist` |
| Buscar proceso por nombre | `ps aux \| grep nombre` | `Get-Process nombre` | `tasklist /FI "IMAGENAME eq nombre.exe"` |
| Matar proceso por PID | `kill PID` | `Stop-Process -Id PID` | `taskkill /PID PID` |
| Matar proceso por nombre | `pkill nombre` | `Stop-Process -Name nombre` | `taskkill /IM nombre.exe` |
| Listar servicios | `systemctl list-units` | `Get-Service` | `sc query` |
| Estado de un servicio | `systemctl status nombre` | `Get-Service nombre` | `sc query nombre` |
| Iniciar servicio | `systemctl start nombre` | `Start-Service nombre` | `net start nombre` |
| Detener servicio | `systemctl stop nombre` | `Stop-Service nombre` | `net stop nombre` |

---

## Red

| Tarea | Linux | PowerShell | CMD |
|-------|-------|------------|-----|
| Ver IP | `ip a` o `ifconfig` | `Get-NetIPAddress` | `ipconfig` |
| Ver IP detallada | `ip a` | `Get-NetIPAddress \| Format-Table` | `ipconfig /all` |
| Ping | `ping -c 4 host` | `Test-Connection host` | `ping host` |
| Comprobar puerto | `nc -zv host puerto` | `Test-NetConnection host -Port puerto` | — |
| Ver puertos abiertos | `ss -tlnp` | `Get-NetTCPConnection -State Listen` | `netstat -ano` |
| Consulta DNS | `dig dominio` o `nslookup` | `Resolve-DnsName dominio` | `nslookup dominio` |
| Ver tabla de rutas | `ip route` | `Get-NetRoute` | `route print` |
| Ver conexiones activas | `ss -tna` | `Get-NetTCPConnection` | `netstat -an` |
| Vaciar caché DNS | `sudo systemd-resolve --flush-caches` | `Clear-DnsClientCache` | `ipconfig /flushdns` |
| Ver caché ARP | `ip neigh` o `arp -a` | `Get-NetNeighbor` | `arp -a` |

---

## Sistema

| Tarea | Linux | PowerShell | CMD |
|-------|-------|------------|-----|
| Usuario actual | `whoami` | `whoami` o `$env:USERNAME` | `whoami` |
| Nombre del equipo | `hostname` | `$env:COMPUTERNAME` | `hostname` |
| Info del sistema | `uname -a` | `Get-ComputerInfo` | `systeminfo` |
| Espacio en disco | `df -h` | `Get-PSDrive -PSProvider FileSystem` | `wmic logicaldisk get size,freespace` |
| Uso de memoria | `free -h` | `Get-Process \| Measure-Object WorkingSet -Sum` | `systeminfo \| findstr Memoria` |
| Variables de entorno | `env` o `printenv` | `Get-ChildItem Env:` | `set` |
| Ver una variable | `echo $HOME` | `$env:HOME` o `$env:USERPROFILE` | `echo %USERPROFILE%` |
| Fecha y hora | `date` | `Get-Date` | `date /t & time /t` |
| Apagar equipo | `shutdown -h now` | `Stop-Computer` | `shutdown /s /t 0` |
| Reiniciar equipo | `reboot` | `Restart-Computer` | `shutdown /r /t 0` |
| Ver historial de comandos | `history` | `Get-History` (alias `h`) | `doskey /history` |

---

## Redirección y pipelines

| Tarea | Linux | PowerShell | CMD |
|-------|-------|------------|-----|
| Redirigir salida a archivo | `comando > archivo` | `comando \| Set-Content archivo` o `comando > archivo` | `comando > archivo` |
| Añadir a archivo | `comando >> archivo` | `comando \| Add-Content archivo` o `comando >> archivo` | `comando >> archivo` |
| Pipeline (encadenar) | `cmd1 \| cmd2` | `cmd1 \| cmd2` | `cmd1 \| cmd2` |
| Descartar errores | `comando 2>/dev/null` | `comando -ErrorAction SilentlyContinue` | `comando 2>nul` |
| Redirigir errores a archivo | `comando 2> errores.txt` | `comando 2> errores.txt` | `comando 2> errores.txt` |

---

## PowerShell: operadores de comparación

PowerShell no usa `>`, `<`, `==` como otros lenguajes. Usa operadores con guion:

| Operador | Significado | Ejemplo |
|----------|-------------|---------|
| `-eq` | Igual | `5 -eq 5` → `$true` |
| `-ne` | No igual | `5 -ne 3` → `$true` |
| `-gt` | Mayor que | `5 -gt 3` → `$true` |
| `-lt` | Menor que | `3 -lt 5` → `$true` |
| `-ge` | Mayor o igual | `5 -ge 5` → `$true` |
| `-le` | Menor o igual | `3 -le 5` → `$true` |
| `-like` | Coincide con comodín | `"hola" -like "h*"` → `$true` |
| `-match` | Coincide con regex | `"hola" -match "^h"` → `$true` |
| `-contains` | El array contiene el valor | `@(1,2,3) -contains 2` → `$true` |
| `-in` | El valor está en el array | `2 -in @(1,2,3)` → `$true` |
| `-and` | Y lógico | `$true -and $true` → `$true` |
| `-or` | O lógico | `$false -or $true` → `$true` |
| `-not` / `!` | Negación | `-not $false` → `$true` |

---

## PowerShell: cmdlets más útiles para sysadmin

| Cmdlet | Qué hace | Ejemplo |
|--------|----------|---------|
| `Get-ChildItem` | Listar archivos/carpetas | `Get-ChildItem -Recurse -Filter *.log` |
| `Get-Content` | Leer archivo | `Get-Content log.txt -Tail 20` |
| `Set-Content` | Escribir archivo (sobrescribe) | `'hola' \| Set-Content saludo.txt` |
| `Add-Content` | Añadir a archivo | `'nueva línea' \| Add-Content log.txt` |
| `Select-String` | Buscar texto (como grep) | `Select-String "error" *.log` |
| `Select-Object` | Elegir propiedades | `Get-Process \| Select-Object Name, CPU -First 5` |
| `Where-Object` | Filtrar (alias `?`) | `Get-Process \| Where-Object CPU -gt 10` |
| `ForEach-Object` | Ejecutar por cada uno (alias `%`) | `1..5 \| ForEach-Object { $_ * 2 }` |
| `Sort-Object` | Ordenar | `Get-Process \| Sort-Object CPU -Descending` |
| `Measure-Object` | Contar, sumar, promediar | `Get-ChildItem \| Measure-Object Length -Sum` |
| `Get-Member` | Ver propiedades de un objeto | `Get-Process \| Get-Member` |
| `Format-Table` | Mostrar como tabla | `Get-Service \| Format-Table Name, Status` |
| `Format-List` | Mostrar como lista detallada | `Get-Process code \| Format-List *` |
| `Export-Csv` | Exportar a CSV | `Get-Process \| Export-Csv procesos.csv` |
| `ConvertTo-Json` | Convertir a JSON | `Get-Process \| ConvertTo-Json` |
| `Test-Path` | Comprobar si existe | `Test-Path 'C:\Users'` → `$true` |
| `Test-Connection` | Ping | `Test-Connection google.com -Count 2` |
| `Test-NetConnection` | Ping + puerto | `Test-NetConnection google.com -Port 443` |
| `Invoke-WebRequest` | HTTP (como curl) | `Invoke-WebRequest https://api.github.com` |
