<#
================================================================================
  IGLESIA EVANGÉLICA PAN BENDITO — MONITOR AUTOMÁTICO DE DIRECTO (OBS)
  Aplicación de escritorio independiente para Windows.
  Monitorea el fichero generado por OBS, activa el directo en la app y web,
  y al finalizar guarda automáticamente el culto como "Culto Anterior".
================================================================================
#>

# Forzar STA (Single Threaded Apartment) requerido por WPF
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    Write-Warning "Reiniciando en modo STA..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Sta -File `"$PSCommandPath`""
    $psi.UseShellExecute = $false
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Exit
}

# Cargar ensamblados de interfaz
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Habilitar TLS 1.2 para peticiones HTTPS seguras
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

# Rutas del script y configuración
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SettingsFile = Join-Path $ScriptDir "settings.json"

# Valores por defecto de configuración
$defaultSettings = @{
    obsFilePath          = (Join-Path $ScriptDir "directo_obs.txt")
    githubToken          = ""
    githubUser           = "manasesmg2000"
    githubRepo           = "live-stream-site"
    githubBranch         = "main"
    autoStart            = $true
    autoStop             = $true
    stopDelaySeconds     = 5
    minimizeToTray       = $true
    lastKnownVideoId     = ""
    lastRecordedVideoId  = "fvek_M_BWXs"
}

# Cargar o crear configuración
$settings = $defaultSettings
if (Test-Path $SettingsFile) {
    try {
        $loaded = Get-Content $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $loaded.PSObject.Properties) {
            $settings[$prop.Name] = $prop.Value
        }
    } catch {
        Write-Warning "No se pudo leer settings.json, usando valores por defecto."
    }
}

# Si no hay token configurado, intentar detectarlo automáticamente desde GitHub CLI
if ([string]::IsNullOrWhiteSpace($settings["githubToken"])) {
    $ghExe = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $ghExe) {
        try {
            $autoToken = (& $ghExe auth token 2>$null).Trim()
            if (![string]::IsNullOrWhiteSpace($autoToken)) {
                $settings["githubToken"] = $autoToken
            }
        } catch {}
    }
}

function Save-Settings {
    try {
        $settings | ConvertTo-Json -Depth 5 | Set-Content $SettingsFile -Encoding UTF8
    } catch {
        Write-Warning "Error al guardar settings: $_"
    }
}

# Variables de estado en tiempo de ejecución
$script:isLive = $false
$script:currentLiveVideoId = ""
$script:lastRecordedVideoId = [string]$settings["lastRecordedVideoId"]
$script:emptyFileDetectionTime = $null
$script:lastFileContent = ""
$script:lastCheckedStatus = ""

# ─────────────────────────────────────────────────────────────────────────────
# DISEÑO DE INTERFAZ WPF EN XAML
# ─────────────────────────────────────────────────────────────────────────────
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Pan Bendito — Monitor OBS AutoStream"
        Height="720" Width="840" MinHeight="620" MinWidth="740"
        WindowStartupLocation="CenterScreen"
        Background="#0f172a" Foreground="#f8fafc"
        FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1e293b"/>
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="PasswordBox">
            <Setter Property="Background" Value="#1e293b"/>
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="12,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Cabecera & Estado -->
            <RowDefinition Height="Auto"/> <!-- Fichero OBS -->
            <RowDefinition Height="Auto"/> <!-- Controles Manuales & Ajustes -->
            <RowDefinition Height="*"/>    <!-- Registro de Actividad (Log) -->
            <RowDefinition Height="Auto"/> <!-- Barra Inferior -->
        </Grid.RowDefinitions>

        <!-- 1. CABECERA & TARJETA DE ESTADO -->
        <Border Grid.Row="0" Background="#1e293b" CornerRadius="12" BorderBrush="#334155" BorderThickness="1" Padding="16" Margin="0,0,0,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                        <TextBlock Text="✝️ IGLESIA PAN BENDITO" FontSize="18" FontWeight="Bold" Foreground="#38bdf8"/>
                        <TextBlock Text="  •  AutoStream OBS" FontSize="18" FontWeight="Light" Foreground="#94a3b8"/>
                    </StackPanel>
                    <TextBlock x:Name="TxtSubStatus" Text="Sincronizando estado con GitHub..." FontSize="13" Foreground="#94a3b8"/>
                    <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                        <TextBlock Text="Culto anterior guardado: " FontSize="12" Foreground="#64748b"/>
                        <TextBlock x:Name="TxtLastVideo" Text="Ninguno" FontSize="12" FontWeight="Bold" Foreground="#f59e0b"/>
                    </StackPanel>
                </StackPanel>

                <!-- Insignia Principal de Estado -->
                <Border x:Name="BadgeLiveStatus" Grid.Column="1" Background="#334155" CornerRadius="10" Padding="18,10" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Ellipse x:Name="DotIndicator" Width="14" Height="14" Fill="#94a3b8" Margin="0,0,10,0"/>
                        <TextBlock x:Name="TxtMainStatus" Text="SIN DIRECTO" FontSize="15" FontWeight="Bold" Foreground="#ffffff"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <!-- 2. MONITOR DEL FICHERO OBS -->
        <Border Grid.Row="1" Background="#1e293b" CornerRadius="12" BorderBrush="#334155" BorderThickness="1" Padding="16" Margin="0,0,0,14">
            <StackPanel>
                <TextBlock Text="📁 FICHERO GENERADO POR OBS" FontSize="13" FontWeight="Bold" Foreground="#cbd5e1" Margin="0,0,0,8"/>
                
                <Grid Margin="0,0,0,10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBox x:Name="TxtFilePath" Grid.Column="0" Margin="0,0,8,0" IsReadOnly="False"/>
                    <Button x:Name="BtnBrowseFile" Grid.Column="1" Content="Examinar..." Background="#0284c7" Margin="0,0,8,0"/>
                    <Button x:Name="BtnOpenNotepad" Grid.Column="2" Content="📝 Abrir Fichero" Background="#475569"/>
                </Grid>

                <Grid Margin="0,0,0,6">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="Estado del archivo: " FontSize="12" Foreground="#94a3b8"/>
                        <TextBlock x:Name="TxtFileStatus" Text="Comprobando..." FontSize="12" FontWeight="SemiBold" Foreground="#38bdf8"/>
                    </StackPanel>
                    <TextBlock x:Name="TxtCountdown" Grid.Column="1" Text="" FontSize="12" FontWeight="Bold" Foreground="#f43f5e"/>
                </Grid>

                <!-- Checkboxes de automatización -->
                <WrapPanel Margin="0,8,0,0">
                    <CheckBox x:Name="ChkAutoStart" Content="Auto-iniciar directo al detectar URL en el archivo" IsChecked="True" Foreground="#e2e8f0" Margin="0,0,20,4"/>
                    <CheckBox x:Name="ChkAutoStop" Content="Auto-finalizar directo cuando se borre la URL" IsChecked="True" Foreground="#e2e8f0" Margin="0,0,20,4"/>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                        <TextBlock Text="Margen de espera: " FontSize="12" Foreground="#94a3b8" VerticalAlignment="Center"/>
                        <TextBox x:Name="TxtGracePeriod" Width="40" Text="5" TextAlignment="Center" Margin="4,0,4,0"/>
                        <TextBlock Text="segundos" FontSize="12" Foreground="#94a3b8" VerticalAlignment="Center"/>
                    </StackPanel>
                </WrapPanel>
            </StackPanel>
        </Border>

        <!-- 3. ACCIONES MANUALES & ENLACES -->
        <Border Grid.Row="2" Background="#1e293b" CornerRadius="12" BorderBrush="#334155" BorderThickness="1" Padding="14,12" Margin="0,0,0,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="URL Manual: " FontSize="12" Foreground="#94a3b8" VerticalAlignment="Center" Margin="0,0,8,0"/>
                    <TextBox x:Name="TxtManualUrl" Width="260" Margin="0,0,10,0"/>
                    <Button x:Name="BtnForceStart" Content="🔴 Forzar Inicio" Background="#dc2626" Margin="0,0,8,0"/>
                    <Button x:Name="BtnForceStop" Content="⏹ Forzar Fin" Background="#334155" Margin="0,0,8,0"/>
                </StackPanel>

                <StackPanel Grid.Column="1" Orientation="Horizontal">
                    <Button x:Name="BtnSync" Content="🔄 Sincronizar" Background="#2563eb" Margin="0,0,8,0"/>
                    <Button x:Name="BtnOpenWeb" Content="🌐 Ver Web" Background="#059669" Margin="0,0,8,0"/>
                    <Button x:Name="BtnOpenAdmin" Content="⚙️ Admin" Background="#475569"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- 4. REGISTRO DE ACTIVIDAD (LOG) -->
        <Border Grid.Row="3" Background="#020617" CornerRadius="12" BorderBrush="#334155" BorderThickness="1" Padding="12" Margin="0,0,0,10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Grid Grid.Row="0" Margin="4,0,4,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="📋 REGISTRO DE EVENTOS EN TIEMPO REAL" FontSize="12" FontWeight="Bold" Foreground="#64748b"/>
                    <Button x:Name="BtnClearLog" Grid.Column="1" Content="🧹 Limpiar" Background="#1e293b" Foreground="#94a3b8" Padding="8,3" FontSize="11"/>
                </Grid>

                <ScrollViewer x:Name="LogScroller" Grid.Row="1" VerticalScrollBarVisibility="Auto">
                    <TextBox x:Name="TxtLog" Background="Transparent" Foreground="#38bdf8" BorderThickness="0" 
                             FontFamily="Consolas" FontSize="12" TextWrapping="Wrap" IsReadOnly="True"/>
                </ScrollViewer>
            </Grid>
        </Border>

        <!-- 5. BARRA INFERIOR / AJUSTES RÁPIDOS -->
        <Grid Grid.Row="4">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtFooter" Text="Pan Bendito AutoStream listo. Minimizando la ventana pasará a la bandeja del sistema." FontSize="11" Foreground="#64748b" VerticalAlignment="Center"/>
            <Button x:Name="BtnSaveConfig" Grid.Column="1" Content="💾 Guardar Configuración" Background="#1e293b" Foreground="#cbd5e1" Padding="10,4" FontSize="12"/>
        </Grid>
    </Grid>
</Window>
"@

# Leer XAML y crear ventana
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Enlazar elementos del XAML
$TxtMainStatus   = $window.FindName("TxtMainStatus")
$TxtSubStatus    = $window.FindName("TxtSubStatus")
$TxtLastVideo    = $window.FindName("TxtLastVideo")
$BadgeLiveStatus = $window.FindName("BadgeLiveStatus")
$DotIndicator    = $window.FindName("DotIndicator")
$TxtFilePath     = $window.FindName("TxtFilePath")
$BtnBrowseFile   = $window.FindName("BtnBrowseFile")
$BtnOpenNotepad  = $window.FindName("BtnOpenNotepad")
$TxtFileStatus   = $window.FindName("TxtFileStatus")
$TxtCountdown    = $window.FindName("TxtCountdown")
$ChkAutoStart    = $window.FindName("ChkAutoStart")
$ChkAutoStop     = $window.FindName("ChkAutoStop")
$TxtGracePeriod  = $window.FindName("TxtGracePeriod")
$TxtManualUrl    = $window.FindName("TxtManualUrl")
$BtnForceStart   = $window.FindName("BtnForceStart")
$BtnForceStop    = $window.FindName("BtnForceStop")
$BtnSync         = $window.FindName("BtnSync")
$BtnOpenWeb      = $window.FindName("BtnOpenWeb")
$BtnOpenAdmin    = $window.FindName("BtnOpenAdmin")
$BtnClearLog     = $window.FindName("BtnClearLog")
$TxtLog          = $window.FindName("TxtLog")
$LogScroller     = $window.FindName("LogScroller")
$BtnSaveConfig   = $window.FindName("BtnSaveConfig")
$TxtFooter       = $window.FindName("TxtFooter")

# ─────────────────────────────────────────────────────────────────────────────
# BANDEJA DEL SISTEMA (NOTIFY ICON)
# ─────────────────────────────────────────────────────────────────────────────
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Text = "Pan Bendito AutoStream"
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenu
$menuOpen = $contextMenu.MenuItems.Add("Abrir Ventana")
$contextMenu.MenuItems.Add("-") | Out-Null
$menuForceStart = $contextMenu.MenuItems.Add("🔴 Iniciar Directo")
$menuForceStop  = $contextMenu.MenuItems.Add("⏹ Finalizar Directo")
$contextMenu.MenuItems.Add("-") | Out-Null
$menuExit = $contextMenu.MenuItems.Add("Salir")
$notifyIcon.ContextMenu = $contextMenu

$menuOpen.add_Click({
    $window.Show()
    $window.WindowState = [System.Windows.WindowState]::Normal
    $window.Activate()
})
$notifyIcon.add_DoubleClick({
    $window.Show()
    $window.WindowState = [System.Windows.WindowState]::Normal
    $window.Activate()
})
$menuForceStart.add_Click({ $BtnForceStart.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) })
$menuForceStop.add_Click({ $BtnForceStop.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) })
$menuExit.add_Click({
    $notifyIcon.Visible = $false
    $window.Close()
    [System.Windows.Forms.Application]::Exit()
})

$window.add_StateChanged({
    if ($window.WindowState -eq [System.Windows.WindowState]::Minimized) {
        $window.Hide()
        $notifyIcon.ShowBalloonTip(2000, "Pan Bendito AutoStream", "Ejecutándose en segundo plano. Haz doble clic para abrir.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})

$window.add_Closed({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
})

# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES DE UTILIDAD Y REGISTRO
# ─────────────────────────────────────────────────────────────────────────────
function Add-Log([string]$message) {
    $time = (Get-Date).ToString("HH:mm:ss")
    $logLine = "[$time] $message`r`n"
    $TxtLog.AppendText($logLine)
    $LogScroller.ScrollToEnd()
}

function Extract-VideoId([string]$raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return "" }
    $clean = $raw.Trim()

    if ($clean -match '^[a-zA-Z0-9_-]{11}$') {
        return $clean
    }
    $patterns = @(
        '[?&]v=([a-zA-Z0-9_-]{11})',
        'youtu\.be\/([a-zA-Z0-9_-]{11})',
        'embed\/([a-zA-Z0-9_-]{11})',
        'live\/([a-zA-Z0-9_-]{11})'
    )
    foreach ($p in $patterns) {
        if ($clean -match $p) {
            return $Matches[1]
        }
    }
    return ""
}

# Servidores ntfy para emisión en tiempo real
$NTFY_SERVERS = @(
    "https://ntfy.projectsegfau.lt",
    "https://ntfy.envs.net",
    "https://ntfy.sh"
)

function Send-RealtimeSignal([string]$signal, [hashtable]$headers) {
    foreach ($server in $NTFY_SERVERS) {
        $url = "$server/iglesia-pan-bendito-live-channel-v1"
        try {
            $req = [System.Net.WebRequest]::Create($url)
            $req.Method = "POST"
            $req.Timeout = 4000
            if ($headers) {
                foreach ($k in $headers.Keys) {
                    $req.Headers.Add($k, [string]$headers[$k])
                }
            }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($signal)
            $req.ContentLength = $bytes.Length
            $stream = $req.GetRequestStream()
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Close()
            $resp = $req.GetResponse()
            $resp.Close()
        } catch {
            # Servidor no disponible o limitado, se continúa con el siguiente
        }
    }
}

function Get-GitHubConfig {
    $token = [string]$settings["githubToken"]
    $user  = [string]$settings["githubUser"]
    $repo  = [string]$settings["githubRepo"]
    $branch= [string]$settings["githubBranch"]

    $url = "https://api.github.com/repos/$user/$repo/contents/config.json?ref=$branch&_t=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
    $headers = @{
        "Accept"     = "application/vnd.github.v3+json"
        "User-Agent" = "PanBendito-AutoStream"
    }
    if (![string]::IsNullOrWhiteSpace($token)) {
        $headers["Authorization"] = "token $token"
    }

    try {
        $res = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -TimeoutSec 6
        $jsonStr = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($res.content))
        $cfg = $jsonStr | ConvertFrom-Json
        return @{
            sha    = $res.sha
            config = $cfg
        }
    } catch {
        Add-Log "⚠️ Error al consultar config.json en GitHub: $_"
        return $null
    }
}

function Update-GitHubConfig([hashtable]$newConfig, [string]$commitMessage) {
    $token = [string]$settings["githubToken"]
    $user  = [string]$settings["githubUser"]
    $repo  = [string]$settings["githubRepo"]
    $branch= [string]$settings["githubBranch"]

    if ([string]::IsNullOrWhiteSpace($token)) {
        Add-Log "❌ Error: No se ha configurado el token de GitHub."
        return $false
    }

    $existing = Get-GitHubConfig
    if (-not $existing -or -not $existing.sha) {
        Add-Log "❌ No se pudo obtener el SHA actual de config.json."
        return $false
    }

    $jsonPayload = $newConfig | ConvertTo-Json -Depth 3
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload + "`n")
    $b64 = [System.Convert]::ToBase64String($bytes)

    $bodyObj = @{
        message = $commitMessage
        content = $b64
        sha     = $existing.sha
        branch  = $branch
    }
    $bodyJson = $bodyObj | ConvertTo-Json -Compress

    $url = "https://api.github.com/repos/$user/$repo/contents/config.json"
    $headers = @{
        "Authorization" = "token $token"
        "Accept"        = "application/vnd.github.v3+json"
        "User-Agent"    = "PanBendito-AutoStream"
    }

    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tempFile, $bodyJson, [System.Text.Encoding]::UTF8)

        $res = Invoke-RestMethod -Uri $url -Headers $headers -Method Put -InFile $tempFile -ContentType "application/json" -TimeoutSec 10
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

        # Actualizar copia local de config.json si existe en workspace
        $localCfgPath = Join-Path (Split-Path -Parent $ScriptDir) "config.json"
        if (Test-Path $localCfgPath) {
            $jsonPayload | Set-Content -Path $localCfgPath -Encoding UTF8
        }
        return $true
    } catch {
        Add-Log "❌ Error actualizando config.json en GitHub: $_"
        return $false
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# CONTROL DE ESTADOS: INICIAR DIRECTO / FINALIZAR DIRECTO
# ─────────────────────────────────────────────────────────────────────────────
function Set-LiveStateUI([bool]$live, [string]$videoId, [string]$lastVideo) {
    if ($live) {
        $TxtMainStatus.Text = "🔴 ¡EN DIRECTO!"
        $BadgeLiveStatus.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#b91c1c")
        $DotIndicator.Fill = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#f87171")
        $TxtSubStatus.Text = "Transmitiendo en vivo • Vídeo ID: $videoId"
        $TxtSubStatus.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#fca5a5")
    } else {
        $TxtMainStatus.Text = "⚪ SIN DIRECTO"
        $BadgeLiveStatus.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#334155")
        $DotIndicator.Fill = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#94a3b8")
        $TxtSubStatus.Text = "Esperando a que OBS genere la URL del directo..."
        $TxtSubStatus.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#94a3b8")
    }

    if (![string]::IsNullOrWhiteSpace($lastVideo)) {
        $TxtLastVideo.Text = $lastVideo
    }
}

function Start-LiveBroadcast([string]$videoId) {
    if ([string]::IsNullOrWhiteSpace($videoId)) {
        Add-Log "⚠️ No se especificó ID de vídeo para iniciar el directo."
        return
    }

    $lastVideo = $script:lastRecordedVideoId
    if ([string]::IsNullOrWhiteSpace($lastVideo)) {
        $lastVideo = $videoId
    }

    Add-Log "🚀 Iniciando retransmisión con ID: $videoId..."

    # 1. Notificación Push Instantánea a Apps y Web
    $headers = @{
        "Title"    = "🔴 ¡Estamos EN DIRECTO!"
        "Priority" = "high"
        "Tags"     = "red_circle,tv"
        "Click"    = "https://manasesmg2000.github.io/live-stream-site/"
    }
    Send-RealtimeSignal "LIVE:$videoId|$lastVideo" $headers
    Add-Log "📡 Señal en tiempo real y notificación push enviadas a las apps."

    # 2. Guardar en GitHub config.json
    $cfgData = @{
        live        = $true
        videoId     = $videoId
        lastVideoId = $lastVideo
    }
    $ok = Update-GitHubConfig $cfgData "🔴 Activar directo: $videoId (OBS AutoStream)"
    if ($ok) {
        $script:isLive = $true
        $script:currentLiveVideoId = $videoId
        $settings["lastKnownVideoId"] = $videoId
        Save-Settings

        Set-LiveStateUI -live $true -videoId $videoId -lastVideo $lastVideo
        Add-Log "✅ ¡DIRECTO ACTIVO! Visualizándose en la web y app oficial."
        $notifyIcon.ShowBalloonTip(4000, "🔴 ¡Estamos EN DIRECTO!", "El culto ha comenzado. Vídeo: $videoId", [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        Add-Log "⚠️ Se emitió la señal en tiempo real pero falló la actualización de GitHub."
    }
}

function Stop-LiveBroadcast {
    $lastVideo = $script:currentLiveVideoId
    if ([string]::IsNullOrWhiteSpace($lastVideo)) {
        $lastVideo = $script:lastRecordedVideoId
    }

    Add-Log "⏹ Finalizando directo. El vídeo ($lastVideo) se guardará como 'Culto Anterior'..."

    # 1. Notificación Push de Fin de Culto
    $headers = @{
        "Title"    = "⏹ Culto finalizado"
        "Priority" = "default"
        "Tags"     = "stop_button,church"
        "Message"  = "El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior."
        "Click"    = "https://manasesmg2000.github.io/live-stream-site/"
    }
    Send-RealtimeSignal "OFFLINE|$lastVideo" $headers
    Add-Log "📡 Notificación de fin de culto enviada."

    # 2. Guardar en GitHub config.json
    $cfgData = @{
        live        = $false
        videoId     = ""
        lastVideoId = $lastVideo
    }
    $ok = Update-GitHubConfig $cfgData "⏹ Terminar directo (OBS AutoStream)"
    if ($ok) {
        $script:isLive = $false
        $script:currentLiveVideoId = ""
        $script:lastRecordedVideoId = $lastVideo
        $settings["lastRecordedVideoId"] = $lastVideo
        Save-Settings

        Set-LiveStateUI -live $false -videoId "" -lastVideo $lastVideo
        Add-Log "✅ Culto finalizado correctamente. Culto anterior disponible: $lastVideo"
        $notifyIcon.ShowBalloonTip(4000, "⏹ Culto finalizado", "El directo ha terminado y se ha guardado como culto anterior.", [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        Add-Log "⚠️ Falló la actualización en GitHub al finalizar el directo."
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# SINCRONIZACIÓN INICIAL CON GITHUB
# ─────────────────────────────────────────────────────────────────────────────
function Sync-StateFromGitHub {
    Add-Log "🔄 Consultando estado actual en GitHub..."
    $res = Get-GitHubConfig
    if ($res -and $res.config) {
        $cfg = $res.config
        $script:isLive = [bool]$cfg.live
        $script:currentLiveVideoId = [string]$cfg.videoId
        if (![string]::IsNullOrWhiteSpace($cfg.lastVideoId)) {
            $script:lastRecordedVideoId = [string]$cfg.lastVideoId
            $settings["lastRecordedVideoId"] = [string]$cfg.lastVideoId
            Save-Settings
        }

        Set-LiveStateUI -live $script:isLive -videoId $script:currentLiveVideoId -lastVideo $script:lastRecordedVideoId
        Add-Log "✅ Estado sincronizado: $(if($script:isLive){"EN DIRECTO ($($script:currentLiveVideoId))"}else{"SIN DIRECTO"}). Culto anterior: $($script:lastRecordedVideoId)"
    } else {
        Add-Log "⚠️ No se pudo obtener la configuración de GitHub. Usando valores locales."
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# LÓGICA DE MONITOREO CONTINUO DEL FICHERO OBS
# ─────────────────────────────────────────────────────────────────────────────
function Check-ObsFile {
    $filePath = $TxtFilePath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($filePath)) {
        $TxtFileStatus.Text = "⚠️ Ruta de archivo no configurada."
        $TxtFileStatus.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#f59e0b")
        return
    }

    if (-not (Test-Path $filePath)) {
        $TxtFileStatus.Text = "Esperando que OBS cree el archivo..."
        $TxtFileStatus.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#94a3b8")
        $fileContent = ""
    } else {
        try {
            # Lectura no bloqueante para no interferir con OBS si está escribiendo
            $fileStream = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $streamReader = New-Object System.IO.StreamReader($fileStream, [System.Text.Encoding]::UTF8)
            $fileContent = $streamReader.ReadToEnd()
            $streamReader.Close()
            $fileStream.Close()
        } catch {
            $fileContent = ""
        }
    }

    $detectedVideoId = Extract-VideoId $fileContent

    # 1. Caso: El archivo contiene una URL válida
    if (![string]::IsNullOrWhiteSpace($detectedVideoId)) {
        $script:emptyFileDetectionTime = $null
        $TxtCountdown.Text = ""
        $TxtFileStatus.Text = "URL encontrada: $detectedVideoId"
        $TxtFileStatus.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#4ade80")

        # Si no estamos en directo, o si el ID del directo cambió:
        if ($ChkAutoStart.IsChecked -and (-not $script:isLive -or $script:currentLiveVideoId -ne $detectedVideoId)) {
            Add-Log "🔍 OBS ha generado enlace de emisión: $detectedVideoId"
            Start-LiveBroadcast -videoId $detectedVideoId
        }
    }
    # 2. Caso: El archivo está vacío o no existe (OBS terminó el directo)
    else {
        $TxtFileStatus.Text = if (Test-Path $filePath) { "Archivo presente pero vacío (Sin URL)" } else { "Archivo no existe (OBS cerrado)" }
        $TxtFileStatus.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#94a3b8")

        # Si estábamos en directo, activar cuenta atrás de finalización
        if ($script:isLive -and $ChkAutoStop.IsChecked) {
            $grace = 5
            [int]::TryParse($TxtGracePeriod.Text, [ref]$grace) | Out-Null
            if ($grace -lt 0) { $grace = 0 }

            if ($null -eq $script:emptyFileDetectionTime) {
                $script:emptyFileDetectionTime = [DateTime]::Now
                Add-Log "⏳ La URL ha sido eliminada del archivo. Esperando $grace segundos antes de finalizar el directo..."
            }

            $elapsed = ([DateTime]::Now - $script:emptyFileDetectionTime).TotalSeconds
            $remaining = [Math]::Max(0, [int]($grace - $elapsed))

            if ($remaining -gt 0) {
                $TxtCountdown.Text = "⏱ Finalizando directo en ${remaining}s..."
            } else {
                $TxtCountdown.Text = ""
                $script:emptyFileDetectionTime = $null
                Add-Log "⌛ Tiempo de espera completado. Procediendo a finalizar el directo..."
                Stop-LiveBroadcast
            }
        } else {
            $script:emptyFileDetectionTime = $null
            $TxtCountdown.Text = ""
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURAR EVENTOS DE LA INTERFAZ
# ─────────────────────────────────────────────────────────────────────────────
# Rellenar campos iniciales con la configuración
$TxtFilePath.Text     = [string]$settings["obsFilePath"]
$ChkAutoStart.IsChecked = [bool]$settings["autoStart"]
$ChkAutoStop.IsChecked  = [bool]$settings["autoStop"]
$TxtGracePeriod.Text  = [string]$settings["stopDelaySeconds"]

# Botón Seleccionar Fichero
$BtnBrowseFile.add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "Archivos de texto (*.txt)|*.txt|Todos los archivos (*.*)|*.*"
    $dlg.Title = "Selecciona el fichero donde OBS guarda la URL del directo"
    if (Test-Path $TxtFilePath.Text) {
        $dlg.InitialDirectory = Split-Path -Parent $TxtFilePath.Text
    }
    if ($dlg.ShowDialog() -eq $true) {
        $TxtFilePath.Text = $dlg.FileName
        $settings["obsFilePath"] = $dlg.FileName
        Save-Settings
        Add-Log "📁 Archivo de monitoreo cambiado a: $($dlg.FileName)"
        Check-ObsFile
    }
})

# Botón Abrir Bloc de Notas
$BtnOpenNotepad.add_Click({
    $filePath = $TxtFilePath.Text.Trim()
    if (![string]::IsNullOrWhiteSpace($filePath)) {
        if (-not (Test-Path $filePath)) {
            $dir = Split-Path -Parent $filePath
            if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            "" | Set-Content -Path $filePath -Encoding UTF8
        }
        [System.Diagnostics.Process]::Start("notepad.exe", "`"$filePath`"") | Out-Null
    }
})

# Botón Forzar Inicio
$BtnForceStart.add_Click({
    $url = $TxtManualUrl.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($url)) {
        $url = $TxtFilePath.Text.Trim()
        if (Test-Path $url) {
            $url = Get-Content $url -Raw
        }
    }
    $vid = Extract-VideoId $url
    if ([string]::IsNullOrWhiteSpace($vid)) {
        [System.Windows.MessageBox]::Show("Por favor escribe una URL o ID de YouTube válida en el campo manual.", "URL Requerida", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    Start-LiveBroadcast -videoId $vid
})

# Botón Forzar Fin
$BtnForceStop.add_Click({
    Stop-LiveBroadcast
})

# Botón Sincronizar
$BtnSync.add_Click({
    Sync-StateFromGitHub
})

# Botones Enlaces Web & Admin
$BtnOpenWeb.add_Click({
    [System.Diagnostics.Process]::Start("https://manasesmg2000.github.io/live-stream-site/") | Out-Null
})
$BtnOpenAdmin.add_Click({
    [System.Diagnostics.Process]::Start("https://manasesmg2000.github.io/live-stream-site/admin.html") | Out-Null
})

# Botón Limpiar Log
$BtnClearLog.add_Click({
    $TxtLog.Clear()
})

# Botón Guardar Configuración
$BtnSaveConfig.add_Click({
    $settings["obsFilePath"] = $TxtFilePath.Text.Trim()
    $settings["autoStart"]   = [bool]$ChkAutoStart.IsChecked
    $settings["autoStop"]    = [bool]$ChkAutoStop.IsChecked
    $grace = 5
    [int]::TryParse($TxtGracePeriod.Text, [ref]$grace) | Out-Null
    $settings["stopDelaySeconds"] = $grace
    Save-Settings
    Add-Log "💾 Configuración guardada correctamente en settings.json."
    [System.Windows.MessageBox]::Show("Configuración guardada correctamente.", "Ajustes Guardados", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
})

# ─────────────────────────────────────────────────────────────────────────────
# TEMPORIZADOR DE MONITOREO (1.5 SEGUNDOS)
# ─────────────────────────────────────────────────────────────────────────────
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(1500)
$timer.add_Tick({
    Check-ObsFile
})

# Inicialización al cargar la ventana
$window.add_Loaded({
    Add-Log "✝️ Aplicación Pan Bendito AutoStream iniciada."
    Add-Log "📁 Monitoreando: $($TxtFilePath.Text)"
    Sync-StateFromGitHub
    $timer.Start()
})

# Mostrar Ventana Principal
$window.ShowDialog() | Out-Null
