
param(
    [Parameter(Mandatory = $true)]
    [int]$GamePid,

    [Parameter(Mandatory = $true)]
    [string]$InstallDir,

    [Parameter(Mandatory = $true)]
    [string]$StagingDir,

    [Parameter(Mandatory = $true)]
    [string]$Executable
)

$ErrorActionPreference = "Stop"

$BackupDir = $null
$NewDir = $null
$FailedDir = $null
$InstallMoved = $false
$NewInstalled = $false

try {
    # 1. Validar argumentos
    if ($GamePid -le 1) {
        throw "El PID del juego no es válido."
    }

    if ([string]::IsNullOrWhiteSpace($Executable)) {
        throw "No se ha indicado el ejecutable."
    }

    if ([System.IO.Path]::IsPathRooted($Executable) -or
        $Executable -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "La ruta relativa del ejecutable no es válida."
    }

    $InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
    $StagingDir = [System.IO.Path]::GetFullPath($StagingDir)

    if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
        throw "No existe la carpeta de instalación: $InstallDir"
    }

    if (-not (Test-Path -LiteralPath $StagingDir -PathType Container)) {
        throw "No existe la carpeta temporal: $StagingDir"
    }

    $InstallDir = (Resolve-Path -LiteralPath $InstallDir).Path
    $StagingDir = (Resolve-Path -LiteralPath $StagingDir).Path

    # Evitar instalar en la raíz de una unidad.
    $Root = [System.IO.Path]::GetPathRoot($InstallDir)

    if ($InstallDir.TrimEnd('\') -eq $Root.TrimEnd('\')) {
        throw "No se permite instalar directamente en la raíz de una unidad."
    }

    # La carpeta temporal no debe estar dentro de la instalación.
    $InstallPrefix = $InstallDir.TrimEnd('\') + '\'

    if ($StagingDir.StartsWith(
        $InstallPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "La carpeta temporal no puede estar dentro de la instalación."
    }

    # 2. Esperar a que se cierre el juego.
    Write-Output "Esperando a que Tamagochi se cierre..."

    while (Get-Process -Id $GamePid -ErrorAction SilentlyContinue) {
        Start-Sleep -Milliseconds 500
    }

    # 3. Crear carpetas temporales junto a la instalación.
    $ParentDir = Split-Path -Parent $InstallDir
    $DirName = Split-Path -Leaf $InstallDir
    $Id = [guid]::NewGuid().ToString("N")

    $NewDir = Join-Path $ParentDir ".$DirName-new-$Id"
    $BackupDir = Join-Path $ParentDir ".$DirName-backup-$Id"
    $FailedDir = Join-Path $ParentDir ".$DirName-failed-$Id"

    # 4. Copiar todos los archivos de staging, incluidos los ocultos.
    Write-Output "Preparando la nueva versión..."

    New-Item -ItemType Directory -Path $NewDir | Out-Null

    Get-ChildItem -LiteralPath $StagingDir -Force |
        Copy-Item -Destination $NewDir -Recurse -Force

    # 5. Comprobar que existe el ejecutable esperado.
    $NewExecutable = Join-Path $NewDir $Executable
    $NewExecutableFull = [System.IO.Path]::GetFullPath($NewExecutable)
    $NewPrefix = $NewDir.TrimEnd('\') + '\'

    if (-not $NewExecutableFull.StartsWith(
        $NewPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "El ejecutable indicado queda fuera de la carpeta nueva."
    }

    if (-not (Test-Path -LiteralPath $NewExecutableFull -PathType Leaf)) {
        throw "No se encuentra el ejecutable esperado: $Executable"
    }

    # 6. Mover la instalación anterior a la copia de seguridad.
    Write-Output "Guardando la instalación anterior..."

    Move-Item -LiteralPath $InstallDir -Destination $BackupDir
    $InstallMoved = $true

    # 7. Colocar la nueva versión.
    Write-Output "Instalando la nueva versión..."

    Move-Item -LiteralPath $NewDir -Destination $InstallDir
    $NewInstalled = $true

    # 8. Comprobar e iniciar la nueva versión.
    $NewExecutable = Join-Path $InstallDir $Executable

    if (-not (Test-Path -LiteralPath $NewExecutable -PathType Leaf)) {
        throw "El ejecutable no está disponible después de la instalación."
    }

    Write-Output "Iniciando Tamagochi..."

    Start-Process `
        -FilePath $NewExecutable `
        -WorkingDirectory $InstallDir

    Write-Output "Actualización instalada correctamente."
    Write-Output "Copia de seguridad conservada en: $BackupDir"
}
catch {
    Write-Error "Error durante la instalación: $_"

    # 9. Intentar restaurar la versión anterior.
    try {
        if ($NewInstalled -and (Test-Path -LiteralPath $InstallDir)) {
            Move-Item -LiteralPath $InstallDir -Destination $FailedDir
            $NewInstalled = $false
        }

        if ($InstallMoved -and (Test-Path -LiteralPath $BackupDir)) {
            Move-Item -LiteralPath $BackupDir -Destination $InstallDir
            $InstallMoved = $false
        }

        if (Test-Path -LiteralPath $NewDir) {
            Remove-Item -LiteralPath $NewDir -Recurse -Force
        }

        Write-Output "Se ha intentado restaurar la instalación anterior."

        if (Test-Path -LiteralPath $FailedDir) {
            Write-Output "La versión fallida se conserva en: $FailedDir"
        }
    }
    catch {
        Write-Error "No se pudo completar la restauración: $_"

        if ($BackupDir -and (Test-Path -LiteralPath $BackupDir)) {
            Write-Error "La copia de seguridad sigue disponible en: $BackupDir"
        }
    }

    exit 1
}
