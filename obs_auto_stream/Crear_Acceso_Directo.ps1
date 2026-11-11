$desktop = [Environment]::GetFolderPath("Desktop")
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$vbsPath = Join-Path $scriptDir "Iniciar_AutoStream_Silencioso.vbs"
$shortcutPath = Join-Path $desktop "Pan Bendito AutoStream OBS.lnk"

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = "`"$vbsPath`""
$shortcut.WorkingDirectory = $scriptDir
$shortcut.Description = "Control y Monitor Automático de Directo para OBS - Iglesia Pan Bendito"

# Buscar icono en el sistema o biblioteca de iconos
if (Test-Path "$env:SystemRoot\System32\shell32.dll") {
    $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll, 220" # Icono de pantalla/video
}

$shortcut.Save()
Write-Host "✅ Acceso directo creado en el Escritorio: $shortcutPath"
