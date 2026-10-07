# ================================================================= #
#             CYBER-DOJO 2: NIVEL INTERMEDIO (comandos reales)       #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).
#
# Aquí ya no basta con el nombre del comando: hay que escribir el
# comando COMPLETO. Se acepta cualquier variante equivalente (orden de
# parámetros, alias, mayúsculas/minúsculas y comillas da igual).
# Cada mundo: @{ Ej = 'ejemplo mostrado'; Rx = @('regex aceptada', ...) }
# (las regex se aplican sobre el texto sin comillas y sin espacios dobles)

function Get-DojoBanco2 {
    @(
        @{ Id = 'contar-lineas'; Tipo = "Texto"; Tarea = "Contar las líneas del archivo datos.txt";
           R = @{
               Linux      = @{ Ej = 'wc -l datos.txt'; Rx = @('^wc\s+-l\s+datos\.txt$', '^cat\s+datos\.txt\s*\|\s*wc\s+-l$') }
               PowerShell = @{ Ej = '(Get-Content datos.txt).Count'; Rx = @('^\(\s*(get-content|gc|cat|type)\s+datos\.txt\s*\)\.count$', '^(get-content|gc|cat|type)\s+datos\.txt\s*\|\s*(measure|measure-object)(\s+-line)?$') }
               Cmd        = @{ Ej = 'find /c /v "" datos.txt'; Rx = @('^find\s+/c\s+/v\s+datos\.txt$') }
           };
           Exp = "En PowerShell, (Get-Content f).Count cuenta el array de líneas. En cmd, find /c /v `"`" cuenta todas las líneas (las que NO contienen la cadena vacía, es decir, todas)." },

        @{ Id = 'tail-seguir'; Tipo = "Logs"; Tarea = "Ver el final de app.log y seguir viendo las líneas nuevas en vivo";
           R = @{
               Linux      = @{ Ej = 'tail -f app.log'; Rx = @('^tail\s+(-n\s*\d+\s+)?-f\s+app\.log$', '^tail\s+-f\s+-n\s*\d+\s+app\.log$') }
               PowerShell = @{ Ej = 'Get-Content app.log -Wait -Tail 20'; Rx = @('^(get-content|gc|cat|type)\s+(-path\s+)?app\.log\s+(-tail\s+\d+\s+)?-wait(\s+-tail\s+\d+)?$') }
           };
           Exp = "tail -f (Linux) y Get-Content -Wait (PowerShell) son lo que usas al depurar un servicio en vivo. Ctrl+C para salir." },

        @{ Id = 'buscar-recursivo'; Tipo = "Texto"; Tarea = "Buscar la palabra error, sin distinguir mayúsculas, en todos los archivos de la carpeta logs y sus subcarpetas";
           R = @{
               Linux      = @{ Ej = 'grep -ri error logs'; Rx = @('^grep\s+-[a-z]*(r[a-z]*i|i[a-z]*r)[a-z]*\s+error\s+logs/?$', '^grep\s+-r\s+-i\s+error\s+logs/?$', '^grep\s+-i\s+-r\s+error\s+logs/?$') }
               PowerShell = @{ Ej = 'Get-ChildItem logs -Recurse | Select-String error'; Rx = @('^(get-childitem|gci|ls|dir)\s+(-path\s+)?logs\s+(-recurse|-rec|-r)\s*\|\s*(select-string|sls)\s+(-pattern\s+)?error$') }
               Cmd        = @{ Ej = 'findstr /s /i error logs\*.*'; Rx = @('^findstr\s+(/s\s+/i|/i\s+/s|/si|/is)\s+error\s+logs\\\*\.\*$') }
           };
           Exp = "Select-String ya ignora mayúsculas por defecto; grep necesita -i, findstr necesita /i." },

        @{ Id = 'contar-ips'; Tipo = "Texto"; Tarea = "ips.txt tiene una IP por línea. Muestra cuántas veces aparece cada una, de la más repetida a la menos";
           R = @{
               Linux      = @{ Ej = 'sort ips.txt | uniq -c | sort -rn'; Rx = @('^(sort\s+ips\.txt|cat\s+ips\.txt\s*\|\s*sort)\s*\|\s*uniq\s+-c\s*\|\s*sort\s+-(rn|nr|r\s+-n|n\s+-r)$') }
               PowerShell = @{ Ej = 'Get-Content ips.txt | Group-Object | Sort-Object Count -Descending'; Rx = @('^(get-content|gc|cat|type)\s+ips\.txt\s*\|\s*(group-object|group)\s*\|\s*(sort-object|sort)\s+(-property\s+)?count\s+-desc(ending)?$') }
           };
           Exp = "sort | uniq -c | sort -rn es la receta clásica de Linux para contar repeticiones. uniq necesita la entrada ordenada." },

        @{ Id = 'top-cpu'; Tipo = "Procesos"; Tarea = "Ver los procesos que más CPU consumen (los 5 primeros)";
           R = @{
               Linux      = @{ Ej = 'ps aux --sort=-%cpu | head'; Rx = @('^ps\s+aux\s+--sort[= ]-%cpu\s*\|\s*head(\s+-n?\s*\d+)?$') }
               PowerShell = @{ Ej = 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 5'; Rx = @('^(get-process|ps|gps)\s*\|\s*(sort-object|sort)\s+(-property\s+)?cpu\s+-desc(ending)?\s*\|\s*(select-object|select)\s+-first\s+5$') }
           };
           Exp = "En Linux, head deja las 10 primeras líneas (la 1ª es la cabecera). Alternativa interactiva: top / htop." },

        @{ Id = 'servicio-estado'; Tipo = "Servicios"; Tarea = "Ver el estado del servicio SSH (en Windows el servicio se llama sshd)";
           R = @{
               Linux      = @{ Ej = 'systemctl status ssh'; Rx = @('^(sudo\s+)?systemctl\s+status\s+ssh(d)?(\.service)?$') }
               PowerShell = @{ Ej = 'Get-Service sshd'; Rx = @('^(get-service|gsv)\s+(-name\s+)?ssh(d)?$') }
               Cmd        = @{ Ej = 'sc query sshd'; Rx = @('^sc(\.exe)?\s+query\s+ssh(d)?$') }
           };
           Exp = "En Debian/Ubuntu el servicio es 'ssh'; en RedHat y en Windows es 'sshd'." },

        @{ Id = 'servicio-reiniciar'; Tipo = "Servicios"; Tarea = "Reiniciar un servicio (nginx en Linux, Spooler en Windows)";
           R = @{
               Linux      = @{ Ej = 'sudo systemctl restart nginx'; Rx = @('^(sudo\s+)?systemctl\s+restart\s+nginx(\.service)?$') }
               PowerShell = @{ Ej = 'Restart-Service Spooler'; Rx = @('^restart-service\s+(-name\s+)?spooler$') }
               Cmd        = @{ Ej = 'net stop spooler && net start spooler'; Rx = @('^net\s+stop\s+spooler\s*(&&|&)\s*net\s+start\s+spooler$') }
           };
           Exp = "cmd no tiene 'restart': hay que parar y arrancar. En PowerShell y Linux es un solo comando." },

        @{ Id = 'servicios-parados'; Tipo = "Servicios"; Tarea = "Listar los servicios que están detenidos";
           R = @{
               Linux      = @{ Ej = 'systemctl list-units --type=service --state=inactive'; Rx = @('^(sudo\s+)?systemctl\s+list-units\s+(--type=service\s+--state=(inactive|failed)|--state=(inactive|failed)\s+--type=service)$') }
               PowerShell = @{ Ej = 'Get-Service | Where-Object Status -eq Stopped'; Rx = @('^(get-service|gsv)\s*\|\s*(where-object|where|\?)\s+(status\s+-eq\s+stopped|\{\s*\$_\.status\s+-eq\s+stopped\s*\})$') }
           };
           Exp = "En PowerShell filtras objetos por propiedad; en Linux le pasas el filtro a systemctl." },

        @{ Id = 'journal-nginx'; Tipo = "Logs"; Tarea = "Ver los logs del servicio nginx con systemd";
           R = @{ Linux = @{ Ej = 'journalctl -u nginx'; Rx = @('^(sudo\s+)?journalctl\s+(-u\s+nginx(\.service)?|--unit[= ]nginx(\.service)?)(\s+.*)?$') } };
           Exp = "journalctl -u <servicio> -f los sigue en vivo; --since today limita por fecha." },

        @{ Id = 'eventos-system'; Tipo = "Logs"; Tarea = "Ver los últimos 10 eventos del registro System de Windows";
           R = @{ PowerShell = @{ Ej = 'Get-WinEvent -LogName System -MaxEvents 10'; Rx = @('^get-winevent\s+(-logname\s+system\s+-maxevents\s+10|-maxevents\s+10\s+-logname\s+system)$') } };
           Exp = "Get-WinEvent es el moderno; Get-EventLog solo existe en Windows PowerShell 5.1." },

        @{ Id = 'tamano-carpeta'; Tipo = "Disco"; Tarea = "Ver el tamaño total de la carpeta logs";
           R = @{
               Linux      = @{ Ej = 'du -sh logs'; Rx = @('^du\s+(-sh|-hs|-s\s+-h|-h\s+-s)\s+logs/?$') }
               PowerShell = @{ Ej = '(Get-ChildItem logs -Recurse | Measure-Object Length -Sum).Sum / 1MB'; Rx = @('^\(\s*(get-childitem|gci|ls|dir)\s+(-path\s+)?logs\s+(-recurse|-rec|-r)(\s+-file)?\s*\|\s*(measure-object|measure)\s+(-property\s+)?length\s+-sum\s*\)\.sum(\s*/\s*1(mb|gb|kb))?$') }
           };
           Exp = "du -sh = disk usage, summary, human-readable. En PowerShell no hay un equivalente directo: se suma Length." },

        @{ Id = 'find-conf'; Tipo = "Buscar"; Tarea = "Buscar todos los archivos .conf dentro de /etc";
           R = @{ Linux = @{ Ej = 'find /etc -name "*.conf"'; Rx = @('^(sudo\s+)?find\s+/etc\s+-name\s+\*\.conf(\s+-type\s+f)?$', '^(sudo\s+)?find\s+/etc\s+-type\s+f\s+-name\s+\*\.conf$') } };
           Exp = "Las comillas evitan que la shell expanda *.conf antes de que find lo vea. Con sudo evitas los 'Permission denied'." },

        @{ Id = 'gci-ini'; Tipo = "Buscar"; Tarea = "Buscar todos los archivos .ini dentro de C:\Windows y sus subcarpetas";
           R = @{ PowerShell = @{ Ej = 'Get-ChildItem C:\Windows -Recurse -Filter *.ini'; Rx = @('^(get-childitem|gci|ls|dir)\s+(-path\s+)?c:\\windows\s+(-recurse|-rec|-r)\s+-filter\s+\*\.ini$', '^(get-childitem|gci|ls|dir)\s+(-path\s+)?c:\\windows\s+-filter\s+\*\.ini\s+(-recurse|-rec|-r)$') } };
           Exp = "-Filter lo filtra el propio sistema de archivos (rápido); -Include filtra después (más lento). Añade -ErrorAction SilentlyContinue para saltar carpetas sin permiso." },

        @{ Id = 'scp-copiar'; Tipo = "SSH"; Tarea = "Copiar file.txt al Beelink (usuario heo) a su carpeta personal, por SSH";
           R = @{ Linux = @{ Ej = 'scp file.txt heo@beelink:~'; Rx = @('^scp\s+file\.txt\s+heo@beelink:(~|~/|/home/heo/?)?$') } };
           Exp = "scp funciona igual en Linux, PowerShell y cmd (OpenSSH). Con Host beelink en ~/.ssh/config te ahorras puerto y IP." },

        @{ Id = 'ssh-comando'; Tipo = "SSH"; Tarea = "Ejecutar el comando uptime en el Beelink sin abrir una sesión interactiva";
           R = @{ Linux = @{ Ej = 'ssh heo@beelink uptime'; Rx = @('^ssh\s+(heo@)?beelink\s+uptime$') } };
           Exp = "ssh host comando ejecuta y vuelve. Es la base para automatizar tareas en servidores desde scripts." },

        @{ Id = 'anexar-fecha'; Tipo = "Redirección"; Tarea = "Añadir la fecha actual al final de registro.txt sin borrar lo que ya tiene";
           R = @{
               Linux      = @{ Ej = 'date >> registro.txt'; Rx = @('^date\s*>>\s*registro\.txt$') }
               PowerShell = @{ Ej = 'Get-Date | Add-Content registro.txt'; Rx = @('^get-date\s*>>\s*registro\.txt$', '^get-date\s*\|\s*add-content\s+(-path\s+)?registro\.txt$') }
               Cmd        = @{ Ej = 'date /t >> registro.txt'; Rx = @('^date\s+/t\s*>>\s*registro\.txt$') }
           };
           Exp = ">> añade al final; > sobrescribe el archivo entero. La diferencia de un solo carácter te puede costar un archivo." },

        @{ Id = 'redir-errores'; Tipo = "Redirección"; Tarea = "Ejecutar un comando y guardar SOLO sus errores en errores.txt (usa ls noexiste como ejemplo)";
           R = @{
               Linux      = @{ Ej = 'ls noexiste 2> errores.txt'; Rx = @('^.+\s2>\s*errores\.txt$') }
               PowerShell = @{ Ej = 'ls noexiste 2> errores.txt'; Rx = @('^.+\s2>\s*errores\.txt$') }
               Cmd        = @{ Ej = 'dir noexiste 2> errores.txt'; Rx = @('^.+\s2>\s*errores\.txt$') }
           };
           Exp = "El descriptor 2 es stderr y el 1 es stdout. 2>&1 los junta; > solo captura stdout." },

        @{ Id = 'usuario-linux'; Tipo = "Usuarios"; Tarea = "Crear el usuario ana con su carpeta personal";
           R = @{ Linux = @{ Ej = 'sudo useradd -m ana'; Rx = @('^(sudo\s+)?(useradd\s+-m\s+ana|useradd\s+ana\s+-m|adduser\s+ana)$') } };
           Exp = "useradd sin -m NO crea el home. adduser (Debian/Ubuntu) es el asistente interactivo que lo hace todo." },

        @{ Id = 'usuario-windows'; Tipo = "Usuarios"; Tarea = "Crear el usuario local ana en Windows (solo el alta, sin contraseña)";
           R = @{
               PowerShell = @{ Ej = 'New-LocalUser -Name ana -NoPassword'; Rx = @('^new-localuser\s+(-name\s+)?ana\s+-nopassword$', '^new-localuser\s+-nopassword\s+-name\s+ana$') }
               Cmd        = @{ Ej = 'net user ana /add'; Rx = @('^net\s+user\s+ana\s+/add$') }
           };
           Exp = "Necesita consola de administrador. Luego Add-LocalGroupMember / net localgroup para darle grupos." },

        @{ Id = 'permiso-exec'; Tipo = "Permisos"; Tarea = "Dar permiso de ejecución solo al propietario de script.sh";
           R = @{ Linux = @{ Ej = 'chmod u+x script.sh'; Rx = @('^(sudo\s+)?chmod\s+(u\+x|700|740|750|744|754|755)\s+script\.sh$') } };
           Exp = "u = usuario propietario, g = grupo, o = otros, a = todos. chmod +x sin letra lo da a todos." },

        @{ Id = 'test-puerto'; Tipo = "Red"; Tarea = "Comprobar si el puerto 22 de beelink responde";
           R = @{
               Linux      = @{ Ej = 'nc -zv beelink 22'; Rx = @('^nc\s+(-zv|-vz|-z\s+-v|-v\s+-z)\s+beelink\s+22$') }
               PowerShell = @{ Ej = 'Test-NetConnection beelink -Port 22'; Rx = @('^(test-netconnection|tnc)\s+(-computername\s+)?beelink\s+-port\s+22$') }
           };
           Exp = "Un ping puede pasar y el servicio estar caído: comprobar el puerto es más fiable." },

        @{ Id = 'trazar-ruta'; Tipo = "Red"; Tarea = "Ver por qué saltos pasan los paquetes hasta google.com";
           R = @{
               Linux      = @{ Ej = 'traceroute google.com'; Rx = @('^traceroute(\s+google\.com)?$') }
               PowerShell = @{ Ej = 'Test-NetConnection google.com -TraceRoute'; Rx = @('^(test-netconnection|tnc)\s+(-computername\s+)?google\.com\s+-traceroute$') }
               Cmd        = @{ Ej = 'tracert google.com'; Rx = @('^tracert(\s+google\.com)?$') }
           };
           Exp = "Cada mundo tiene el suyo: traceroute / tracert / Test-NetConnection -TraceRoute." },

        @{ Id = 'dns-mx'; Tipo = "Red"; Tarea = "Consultar los registros MX (correo) de google.com";
           R = @{
               Linux      = @{ Ej = 'dig google.com MX'; Rx = @('^dig\s+(google\.com\s+MX|MX\s+google\.com)$', '^dig\s+-t\s+MX\s+google\.com$', '^host\s+-t\s+MX\s+google\.com$', '^nslookup\s+-type=mx\s+google\.com$') }
               PowerShell = @{ Ej = 'Resolve-DnsName google.com -Type MX'; Rx = @('^resolve-dnsname\s+(-name\s+)?google\.com\s+-type\s+mx$', '^resolve-dnsname\s+-type\s+mx\s+(-name\s+)?google\.com$') }
               Cmd        = @{ Ej = 'nslookup -type=mx google.com'; Rx = @('^nslookup\s+-(type|q)=mx\s+google\.com$') }
           };
           Exp = "Esto lo verás en SRI: los MX indican qué servidores reciben el correo del dominio." },

        @{ Id = 'errorstop'; Tipo = "Errores"; Tarea = "¿Qué parámetro común convierte un error no terminante en terminante, para que try/catch lo capture?";
           R = @{ PowerShell = @{ Ej = '-ErrorAction Stop'; Rx = @('^-(erroraction|ea)\s+stop$', '^\$erroractionpreference\s*=\s*stop$') } };
           Exp = "Sin -ErrorAction Stop, un error no terminante no salta al catch. También sirve `$ErrorActionPreference = 'Stop'` para todo el script." },

        @{ Id = 'invoke-command'; Tipo = "Remoto"; Tarea = "Nombre del cmdlet para ejecutar un bloque de comandos en otro equipo por PowerShell remoto (o su alias)";
           R = @{ PowerShell = @{ Ej = 'Invoke-Command'; Ok = @('icm') } };
           Exp = "Invoke-Command -ComputerName srv1 -ScriptBlock { Get-Service }. Es la base de administrar muchos equipos a la vez." }
    )
}

# ── Dojo nivel 2 ──────────────────────────────────────────────────
function Invoke-CyberDojo2 {
    [CmdletBinding()]
    param(
        [Alias('Ronda')]
        [int]$Preguntas = 5,

        [ValidateSet('Mix', 'Linux', 'PowerShell', 'Cmd')]
        [string]$Modo = 'Mix',

        # Solo los retos que toca repasar hoy
        [switch]$Repaso
    )
    Invoke-DojoEngine -Banco (Get-DojoBanco2) -Prefijo 'dojo2' -Titulo 'CYBER-DOJO 2  -  nivel intermedio' -Preguntas $Preguntas -Modo $Modo -Repaso:$Repaso
}

Set-Alias dojo2 Invoke-CyberDojo2
