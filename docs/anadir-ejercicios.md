# Cómo añadir tus propios ejercicios

Guía paso a paso para crear ejercicios nuevos en cada motor. Si no has leído [cómo funcionan los motores](motores.md), léelo primero para entender la estructura.

---

## Añadir un ejercicio al DOJO

### Dónde

Abre `Dojo.ps1` (o `Dojo2.ps1` para nivel 2). Busca la función `Get-DojoBanco`. Dentro hay un `@(` con todos los ejercicios. Añade el tuyo al final, antes del `)` de cierre.

### Plantilla

```powershell
@{ Tipo = "MiCategoría"; Tarea = "Texto que ve el alumno";
   R = @{ Linux = @('comando-linux'); PowerShell = @('Comando-PS','alias1','alias2'); Cmd = @('comando-cmd') };
   Exp = "Explicación que se muestra después de responder." },
```

### Ejemplo real: añadir "Ver el usuario actual"

```powershell
@{ Tipo = "Sistema"; Tarea = "Ver con qué usuario estás logueado";
   R = @{ Linux = @('whoami'); PowerShell = @('whoami','$env:USERNAME'); Cmd = @('whoami') };
   Exp = "En PowerShell también puedes usar [Environment]::UserName." },
```

### Reglas

1. **`Tipo`** — Categoría libre (texto). Solo para organizar.
2. **`Tarea`** — La pregunta que ve el alumno. Debe ser clara y concreta.
3. **`R`** — Diccionario de respuestas por plataforma. Cada plataforma es un array.
   - La primera respuesta de cada array es la "canónica" (se muestra en pistas).
   - Si un comando no existe en una plataforma, no pongas esa clave.
   - Las comparaciones son case-insensitive.
4. **`Exp`** — Explicación breve. Se muestra siempre, haya acertado o no.
5. **No olvides la coma** al final del `}` si no es el último ejercicio.

---

## Añadir una misión al TATAMI

### Dónde

Abre `Tatami1.ps1` (o `Tatami2.ps1` para nivel 2). Busca el banco de misiones y añade la tuya.

### Plantilla

```powershell
@{
    Id       = "mi-mision"          # Único, sin espacios
    Titulo   = "Nombre de la misión"
    Objetivo = "Lo que debe hacer el alumno."
    Pista    = "Una ayuda sin dar la respuesta."
    Ejemplo  = "El comando exacto que lo resuelve"

    Setup = {
        # Código que prepara los archivos de prueba
        'contenido' | Set-Content 'archivo.txt'
    }

    Validar = { param($cmd, $salida)
        # Devuelve $true si está bien hecho, $false si no
        Test-Path 'resultado-esperado.txt'
    }
}
```

### Ejemplo real: "Renombra el archivo"

```powershell
@{
    Id       = "renombrar-simple"
    Titulo   = "Renombra el archivo"
    Objetivo = "Cambia el nombre de 'borrador.txt' a 'final.txt'."
    Pista    = "Usa Rename-Item o el comando ren."
    Ejemplo  = "Rename-Item borrador.txt final.txt"

    Setup = {
        'Mi documento' | Set-Content 'borrador.txt'
    }

    Validar = { param($cmd, $salida)
        # El original no debe existir y el nuevo sí
        (-not (Test-Path 'borrador.txt')) -and (Test-Path 'final.txt')
    }
}
```

### Consejos para el Validar

- **Comprueba el estado, no el comando.** Nunca compruebes `$cmd -eq "Rename-Item..."`. El alumno puede usar cualquier método válido.
- **Usa `-ErrorAction SilentlyContinue`** en Get-ChildItem si puede no haber resultados.
- **Fuerza arrays con `@( )`** cuando uses `.Count` para evitar errores con 0 o 1 resultado.
- **Comprueba lo que NO debe pasar** además de lo que sí: archivos que no deben existir, carpetas que deben seguir ahí, etc.

---

## Añadir un reto al RETO

### Dónde

Abre `Reto.ps1`. Busca la función `Get-RetoBanco`. Dentro hay un `$b = @()` seguido de varios `$b += @{ ... }`. Añade el tuyo al final.

### Plantilla mínima

```powershell
$b += @{
    Id     = 'mi-reto'
    Nivel  = 1                    # 1 (fácil) a 5 (difícil)
    Titulo = 'Nombre del reto'
    Intro  = 'Texto narrativo de introducción.'
    Concepto = 'Qué concepto se practica'
    Inicio = 'nombre-carpeta'     # Carpeta raíz del reto

    Preparar = { param($Raiz)
        # Prepara archivos iniciales (si hacen falta)
        New-RetoArchivo $Raiz 'datos.txt' "línea 1`nlínea 2`nlínea 3"
    }

    Pasos = @(
        @{
            T   = 'Enunciado del paso 1.'
            C   = { param($Raiz)
                # Comprobación: devuelve $true o un string de error
                if (Test-Path (_rp $Raiz 'resultado')) { return $true }
                return 'No encuentro lo que esperaba.'
            }
            P   = 'Pista del paso 1.'
            Ps  = 'Solución en PowerShell'
            Cmd = 'Solución en CMD'
        },
        @{
            T   = '¿Cuántas líneas tiene datos.txt?'
            Esperada = { param($Raiz)
                return '3'
            }
            Modo = 'exacto'
            P  = 'Usa Get-Content y .Count'
            Ps = '(Get-Content datos.txt).Count'
        }
    )
}
```

### Ejemplo real: "Organiza los archivos por extensión"

```powershell
$b += @{
    Id     = 'organizar-extension'
    Nivel  = 2
    Titulo = 'Organiza archivos por extensión'
    Intro  = 'Un compañero ha dejado todos los archivos sueltos. Organízalos en carpetas por tipo.'
    Concepto = 'Mover archivos y crear carpetas'
    Inicio = 'desordenado'

    Preparar = { param($Raiz)
        New-RetoArchivo $Raiz 'foto1.jpg' 'img'
        New-RetoArchivo $Raiz 'foto2.jpg' 'img'
        New-RetoArchivo $Raiz 'informe.pdf' 'pdf'
        New-RetoArchivo $Raiz 'notas.txt' 'txt'
        New-RetoArchivo $Raiz 'carta.txt' 'txt'
    }

    Pasos = @(
        @{
            T   = 'Crea las carpetas imagenes, documentos y textos.'
            C   = { param($Raiz)
                $esperadas = @('imagenes','documentos','textos')
                foreach ($c in $esperadas) {
                    if (-not (Test-Path (_rp $Raiz $c))) {
                        return "Falta la carpeta '$c'."
                    }
                }
                return $true
            }
            P   = 'Usa mkdir imagenes, documentos, textos'
            Ps  = 'mkdir imagenes, documentos, textos'
            Cmd = 'mkdir imagenes & mkdir documentos & mkdir textos'
        },
        @{
            T   = 'Mueve los .jpg a imagenes, el .pdf a documentos y los .txt a textos.'
            C   = { param($Raiz)
                $checks = @(
                    @{ Path = 'imagenes\foto1.jpg'; Msg = 'Falta foto1.jpg en imagenes.' }
                    @{ Path = 'imagenes\foto2.jpg'; Msg = 'Falta foto2.jpg en imagenes.' }
                    @{ Path = 'documentos\informe.pdf'; Msg = 'Falta informe.pdf en documentos.' }
                    @{ Path = 'textos\notas.txt'; Msg = 'Falta notas.txt en textos.' }
                    @{ Path = 'textos\carta.txt'; Msg = 'Falta carta.txt en textos.' }
                )
                foreach ($ch in $checks) {
                    if (-not (Test-Path (_rp $Raiz $ch.Path))) {
                        return $ch.Msg
                    }
                }
                return $true
            }
            P   = 'Usa Move-Item *.jpg imagenes'
            Ps  = "Move-Item *.jpg imagenes`nMove-Item *.pdf documentos`nMove-Item *.txt textos"
            Cmd = "move *.jpg imagenes`nmove *.pdf documentos`nmove *.txt textos"
        },
        @{
            T   = '¿Cuántos archivos hay en total en las tres carpetas?'
            Esperada = { param($Raiz)
                return '5'
            }
            Modo = 'exacto'
            P  = 'Usa Get-ChildItem -Recurse -File y cuenta.'
            Ps = '(Get-ChildItem -Recurse -File).Count'
        }
    )
}
```

### Tipos de paso: acción vs respuesta

**Paso de acción** (con `C`):
```powershell
@{
    T   = 'Texto del enunciado'
    C   = { param($Raiz)
        # Devuelve $true si correcto, o un string de error
    }
    P   = 'Pista'
    Ps  = 'Solución PowerShell'
    Cmd = 'Solución CMD'       # Opcional
    Alt = 'Alternativa'        # Opcional
}
```

**Paso de respuesta** (con `Esperada`):
```powershell
@{
    T   = 'Pregunta para el alumno'
    Esperada = { param($Raiz)
        return 'valor-correcto'
    }
    Modo = 'exacto'   # exacto | bool | regex | enTexto
    P    = 'Pista'
    Ps   = 'Cómo encontrar la respuesta'
}
```

### Modos de comparación para `Esperada`

| Modo | Qué hace | Ejemplo |
|------|----------|---------|
| `exacto` | La respuesta debe coincidir exactamente (sin importar mayúsculas) | "3" acepta "3", no "tres" |
| `bool` | Solo acepta sí/no, true/false, s/n | Preguntas de verdadero/falso |
| `regex` | La respuesta del alumno se compara como regex contra el valor | Patrones flexibles |
| `enTexto` | El valor esperado debe aparecer dentro de la respuesta del alumno | Respuestas parciales |

---

## Checklist antes de publicar tu ejercicio

- [ ] **¿El `Id` es único?** No se repite con ningún otro ejercicio del mismo motor.
- [ ] **¿El enunciado es claro?** Un alumno que no ha visto el ejercicio antes entiende qué tiene que hacer.
- [ ] **¿La pista ayuda sin dar la respuesta?** Orienta, no resuelve.
- [ ] **¿La comprobación valida el resultado, no el método?** No compruebes qué comando usó, sino si el estado final es correcto.
- [ ] **¿Has probado que funciona?** Carga el script, haz el ejercicio y verifica que valida correctamente.
- [ ] **¿El archivo está guardado como UTF-8 con BOM?** Si usas PowerShell 5.1, los acentos se rompen sin BOM.
