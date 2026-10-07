# ================================================================= #
#          TATAMI 2: MISIONES DE NIVEL INTERMEDIO (PowerShell)       #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).
# Combinar comandos, tratar texto, exportar, renombrar en masa,
# CSV de usuarios y manejo de errores. El motor está en Motor.ps1.
#
# Nota: este tatami se ejecuta en PowerShell. Las misiones de Linux
# viven en Dojo 2 (comandos completos); un tatami de bash necesitaría
# WSL o un contenedor.

function Get-TatamiMisiones2 {
    @(
        @{
            Id       = "top3-grandes"
            Titulo   = "Podio de pesos (ordenar y recortar)"
            Objetivo = "Muestra los 3 archivos más grandes, de mayor a menor."
            Setup    = {
                $kb = @{ "a.bin" = 5; "b.bin" = 40; "c.bin" = 12; "d.bin" = 90; "e.bin" = 1; "f.bin" = 63 }
                foreach ($k in $kb.Keys) {
                    [System.IO.File]::WriteAllBytes((Join-Path (Get-Location).Path $k), (New-Object byte[] ($kb[$k] * 1024)))
                }
            }
            Validar  = {
                param($cmdStr, $salida)
                $n = Get-CyberNombres $salida
                ($n -join ',') -eq 'd.bin,f.bin,b.bin'
            }
            Ejemplo  = "ls | sort Length -desc | select -first 3"
            Pista    = "Sort-Object Length -Descending ordena; Select-Object -First 3 recorta."
        },
        @{
            Id       = "grep-errores"
            Titulo   = "Cazador de errores (buscar texto en un log)"
            Objetivo = "Muestra solo las líneas de app.log que contienen ERROR."
            Setup    = {
                @(
                    "2026-09-29 08:00:01 INFO  servicio arrancado",
                    "2026-09-29 08:03:10 ERROR fallo de conexion con la base de datos",
                    "2026-09-29 08:03:15 WARN  reintentando",
                    "2026-09-29 08:04:02 ERROR timeout en /api/usuarios",
                    "2026-09-29 08:10:44 INFO  usuario ana autenticado",
                    "2026-09-29 08:15:20 ERROR disco casi lleno"
                ) | Set-Content -Path "app.log" -Encoding ASCII
            }
            Validar  = {
                param($cmdStr, $salida)
                $lineas = @($salida | ForEach-Object { if ($_.PSObject.Properties['Line']) { $_.Line } else { "$_" } })
                ($lineas.Count -eq 3) -and (@($lineas | Where-Object { $_ -notmatch 'ERROR' }).Count -eq 0)
            }
            Ejemplo  = "sls ERROR app.log   (o bien: gc app.log | ? { `$_ -match 'ERROR' })"
            Pista    = "Select-String (alias sls) busca texto dentro de archivos: sls PATRON archivo"
        },
        @{
            Id       = "agrupar-extension"
            Titulo   = "Censo de extensiones (agrupar y contar)"
            Objetivo = "Muestra cuántos archivos hay de cada extensión."
            Setup    = {
                foreach ($n in "a.txt","b.txt","c.txt","x.log","y.log","z.csv") {
                    New-Item -ItemType File -Name $n -Force | Out-Null
                }
            }
            Validar  = {
                param($cmdStr, $salida)
                $m = @{}
                foreach ($o in @($salida)) {
                    if ($o.PSObject.Properties['Count'] -and $o.PSObject.Properties['Name']) {
                        $m["$($o.Name)".ToLower()] = [int]$o.Count
                    }
                }
                ($m['.txt'] -eq 3) -and ($m['.log'] -eq 2) -and ($m['.csv'] -eq 1)
            }
            Ejemplo  = "ls | group Extension"
            Pista    = "Group-Object (alias group) agrupa por una propiedad y devuelve Name y Count."
        },
        @{
            Id       = "csv-inventario"
            Titulo   = "Inventario a CSV (exportar)"
            Objetivo = "Crea inventario.csv con las columnas Name y Length, SOLO de los archivos .txt."
            Setup    = {
                foreach ($k in @{ "informe.txt" = 2; "notas.txt" = 1; "lista.txt" = 3; "datos.csv" = 4; "foto.png" = 8 }.GetEnumerator()) {
                    [System.IO.File]::WriteAllBytes((Join-Path (Get-Location).Path $k.Key), (New-Object byte[] ($k.Value * 1024)))
                }
            }
            Validar  = {
                param($cmdStr, $salida)
                if (-not (Test-Path "inventario.csv")) { return $false }
                $rows = @(Import-Csv "inventario.csv")
                if ($rows.Count -ne 3) { return $false }
                $cols = $rows[0].PSObject.Properties.Name
                ($cols -contains 'Name') -and ($cols -contains 'Length') -and
                (@($rows | Where-Object { $_.Name -notlike '*.txt' }).Count -eq 0)
            }
            Ejemplo  = "ls *.txt | select Name, Length | Export-Csv inventario.csv -NoTypeInformation"
            Pista    = "Select-Object elige columnas, Export-Csv guarda. En PowerShell 5.1 añade -NoTypeInformation."
        },
        @{
            Id       = "renombrar-masa"
            Titulo   = "Cambio de extensión en masa (renombrar)"
            Objetivo = "Cambia la extensión de TODOS los .txt a .bak, sin tocar leeme.md."
            Setup    = {
                foreach ($i in 1..5) { New-Item -ItemType File -Name "nota$i.txt" -Force | Out-Null }
                New-Item -ItemType File -Name "leeme.md" -Force | Out-Null
            }
            Validar  = {
                param($cmdStr, $salida)
                (@(Get-ChildItem *.txt -ErrorAction SilentlyContinue).Count -eq 0) -and
                (@(Get-ChildItem *.bak -ErrorAction SilentlyContinue).Count -eq 5) -and
                (Test-Path "leeme.md") -and
                ((1..5 | ForEach-Object { Test-Path "nota$_.bak" }) -notcontains $false)
            }
            Ejemplo  = "ls *.txt | Rename-Item -NewName { `$_.Name -replace '\.txt`$','.bak' }"
            Pista    = "Rename-Item acepta un scriptblock en -NewName: { `$_.Name -replace '...','...' }"
        },
        @{
            Id       = "usuarios-admin"
            Titulo   = "Auditoría de cuentas (CSV y filtros combinados)"
            Objetivo = "Muestra solo los nombres de los usuarios que son admin Y están activos (usuarios.csv)."
            Setup    = {
                @(
                    "nombre,rol,activo",
                    "ana,admin,si",
                    "luis,usuario,si",
                    "marta,admin,no",
                    "pedro,admin,si",
                    "sofia,usuario,no"
                ) | Set-Content -Path "usuarios.csv" -Encoding ASCII
            }
            Validar  = {
                param($cmdStr, $salida)
                $n = Get-CyberNombres $salida 'nombre'
                (($n | Sort-Object) -join ',') -eq 'ana,pedro'
            }
            Ejemplo  = "Import-Csv usuarios.csv | ? { `$_.rol -eq 'admin' -and `$_.activo -eq 'si' } | select -expand nombre"
            Pista    = "Import-Csv convierte cada fila en un objeto. Filtra con Where-Object y combina condiciones con -and."
        },
        @{
            Id       = "suma-tamano"
            Titulo   = "Contable de bytes (sumar y convertir)"
            Objetivo = "Calcula el tamaño total, en KB, de los archivos .bin (que salga un número)."
            Setup    = {
                foreach ($k in @{ "a.bin" = 10; "b.bin" = 20; "c.bin" = 30; "nota.txt" = 5 }.GetEnumerator()) {
                    [System.IO.File]::WriteAllBytes((Join-Path (Get-Location).Path $k.Key), (New-Object byte[] ($k.Value * 1024)))
                }
            }
            Validar  = {
                param($cmdStr, $salida)
                $v = "$(@($salida)[-1])" -as [double]
                ($null -ne $v) -and ([math]::Abs($v - 60) -lt 0.01)
            }
            Ejemplo  = "(ls *.bin | measure Length -Sum).Sum / 1KB"
            Pista    = "Measure-Object -Sum suma en bytes; entre paréntesis y .Sum sacas el número; divide entre 1KB."
        },
        @{
            Id       = "try-catch"
            Titulo   = "Fallar con elegancia (try/catch)"
            Objetivo = "Intenta leer missing.txt (no existe) sin que salga el error rojo: en su lugar debe imprimirse: no existe"
            Setup    = { }
            Validar  = {
                param($cmdStr, $salida)
                "$salida" -match 'no existe'
            }
            Ejemplo  = "try { gc missing.txt -ErrorAction Stop } catch { 'no existe' }"
            Pista    = "try { comando -ErrorAction Stop } catch { ... }  (sin Stop, el catch no salta)."
        }
    )
}

function Invoke-Tatami2 {
    [CmdletBinding()]
    param(
        # Solo misiones que toca repasar hoy
        [switch]$Repaso
    )
    Invoke-TatamiEngine -Misiones (Get-TatamiMisiones2) -Prefijo 'tatami2' -Titulo 'TATAMI-2: ADMINISTRACIÓN EN CONSOLA (nivel intermedio)' -Repaso:$Repaso
}

Set-Alias tatami2 Invoke-Tatami2
