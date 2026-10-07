# ================================================================= #
#                TATAMI 1: SANDBOX DE MISIONES REALES               #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).
# El bucle del sandbox y el registro de fallos viven en Motor.ps1.

function Get-TatamiMisiones1 {
    @(
        @{
            Id          = "logs-extension"
            Titulo      = "Infiltración de Logs (Filtrar por extensión)"
            Objetivo    = "Lista únicamente los archivos con extensión '.log' en el sandbox."
            Setup       = {
                New-Item -ItemType File -Name "system.log" -Value "log data" -Force | Out-Null
                New-Item -ItemType File -Name "error.log" -Value "err" -Force | Out-Null
                New-Item -ItemType File -Name "config.json" -Value "{}" -Force | Out-Null
                New-Item -ItemType File -Name "app.exe" -Force | Out-Null
            }
            Validar     = {
                param($cmdStr, $salida)
                $archivos = @($salida | ForEach-Object { if ($_ -is [System.IO.FileInfo]) { $_.Name } else { "$_" } })
                ($archivos -match "system\.log") -and ($archivos -match "error\.log") -and ($archivos -notmatch "config\.json")
            }
            Ejemplo     = "ls *.log  (o bien: ls | ? Extension -eq '.log')"
            Pista       = "Prueba usando comodines directos: ls *.log"
        },
        @{
            Id          = "pesados-tamano"
            Titulo      = "Caza de Archivos Pesados (Filtrado por tamaño)"
            Objetivo    = "Encuentra los archivos cuyo tamaño sea MAYOR a 10KB usando el pipeline (Length y -gt)."
            Setup       = {
                $bufPeque   = New-Object byte[] (2 * 1024)
                $bufGrande1 = New-Object byte[] (15 * 1024)
                $bufGrande2 = New-Object byte[] (50 * 1024)
                [System.IO.File]::WriteAllBytes((Join-Path (Get-Location).Path "peque.txt"), $bufPeque)
                [System.IO.File]::WriteAllBytes((Join-Path (Get-Location).Path "payload_alpha.bin"), $bufGrande1)
                [System.IO.File]::WriteAllBytes((Join-Path (Get-Location).Path "payload_beta.bin"), $bufGrande2)
            }
            Validar     = {
                param($cmdStr, $salida)
                $nombres = @($salida | ForEach-Object { if ($_ -is [System.IO.FileInfo]) { $_.Name } else { "$_" } })
                ($nombres -match "payload_alpha\.bin") -and ($nombres -match "payload_beta\.bin") -and ($nombres -notmatch "peque\.txt")
            }
            Ejemplo     = "ls | ? Length -gt 10KB"
            Pista       = "Usa tubería y filtro: ls | ? Length -gt 10KB"
        },
        @{
            Id          = "select-propiedades"
            Titulo      = "Extracción Selectiva (Select-Object)"
            Objetivo    = "Lista los archivos proyectando ÚNICAMENTE las propiedades 'Name' y 'Length'."
            Setup       = {
                New-Item -ItemType File -Name "token.jwt" -Force | Out-Null
                New-Item -ItemType File -Name "key.pem" -Force | Out-Null
            }
            Validar     = {
                param($cmdStr, $salida)
                if (-not $salida) { return $false }
                $primero = @($salida)[0]
                ($primero.PSObject.Properties.Name -contains "Name") -and
                ($primero.PSObject.Properties.Name -contains "Length") -and
                ($primero.PSObject.Properties.Name -notcontains "CreationTime")
            }
            Ejemplo     = "ls | select Name, Length"
            Pista       = "Pasa la salida por pipeline a select: ls | select Name, Length"
        },
        @{
            Id          = "limpieza-tmp"
            Titulo      = "Protocolo de Limpieza (Purga automatizada)"
            Objetivo    = "Elimina todos los archivos temporales con extensión '.tmp' de una sola vez."
            Setup       = {
                New-Item -ItemType File -Name "cache_1.tmp" -Force | Out-Null
                New-Item -ItemType File -Name "cache_2.tmp" -Force | Out-Null
                New-Item -ItemType File -Name "important.data" -Force | Out-Null
            }
            Validar     = {
                param($cmdStr, $salida)
                (-not (Test-Path "cache_1.tmp")) -and (-not (Test-Path "cache_2.tmp")) -and (Test-Path "important.data")
            }
            Ejemplo     = "rm *.tmp  (o bien: ls *.tmp | rm)"
            Pista       = "Puedes usar el alias de borrado con comodín: rm *.tmp"
        }
    )
}

function Invoke-Tatami {
    [CmdletBinding()]
    param(
        # Solo misiones que toca repasar hoy
        [switch]$Repaso
    )
    Invoke-TatamiEngine -Misiones (Get-TatamiMisiones1) -Prefijo 'tatami1' -Titulo 'TATAMI-1: COMBATE PRÁCTICO EN CONSOLA' -Repaso:$Repaso
}

# Alias para invocar Tatami
Set-Alias tatami  Invoke-Tatami
Set-Alias tatami1 Invoke-Tatami
