Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Persistence setup in %LOCALAPPDATA%\StudyFlow\sessions.json
$dataDir = Join-Path $env:LOCALAPPDATA "StudyFlow"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}
$dataFile = Join-Path $dataDir "sessions.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Always maintain a concrete ArrayList at script scope (avoids PS pipeline unrolling)
$script:allSessions = New-Object System.Collections.ArrayList

function Load-Sessions {
    $script:allSessions.Clear()
    if ([System.IO.File]::Exists($dataFile)) {
        try {
            $raw = [System.IO.File]::ReadAllText($dataFile, $utf8NoBom)
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $parsed = $raw | ConvertFrom-Json
                if ($null -ne $parsed) {
                    if ($parsed -is [System.Array]) {
                        foreach ($item in $parsed) {
                            if ($null -ne $item) {
                                [void]$script:allSessions.Add($item)
                            }
                        }
                    } else {
                        [void]$script:allSessions.Add($parsed)
                    }
                }
            }
        } catch {
        }
    }
}

function Save-Sessions {
    try {
        $arr = @($script:allSessions.ToArray())
        $json = ConvertTo-Json -InputObject $arr -Depth 4
        if ([string]::IsNullOrWhiteSpace($json)) { $json = "[]" }
        [System.IO.File]::WriteAllText($dataFile, $json, $utf8NoBom)
    } catch {
    }
}

Load-Sessions

$script:status = "IDLE" # IDLE, RUNNING, PAUSED, STOPPED
$script:stopwatch = [System.Diagnostics.Stopwatch]::new()
$script:currentStartTime = $null
$script:hasSavedCurrentSession = $false
$script:activeView = "TIMER" # TIMER or LOG
$script:isMinimizedBubble = $false

# Pure Black, Grey & White Floating Overlay Card XAML (Pure ASCII + crisp vector Path icons)
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="StudyFlow Timer"
        SizeToContent="WidthAndHeight"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="True"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        ShowInTaskbar="True">

    <Window.Resources>
        <Style x:Key="CardButtonStyle" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="12"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.88"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.72"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#141417"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#242429"/>
                                <Setter Property="Foreground" Value="#52525B"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="HeaderIconBtn" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="#18181B"/>
            <Setter Property="Foreground" Value="#D4D4D8"/>
            <Setter Property="BorderBrush" Value="#2E2E33"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#27272A"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#52525B"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <!-- FULL FLOATING CARD -->
        <Border x:Name="MainCardBorder"
                Width="330"
                Background="#000000"
                BorderBrush="#2E2E33"
                BorderThickness="1.5"
                CornerRadius="18"
                Margin="10"
                Visibility="Visible">
            <Border.Effect>
                <DropShadowEffect Color="#000000" BlurRadius="18" ShadowDepth="4" Opacity="0.8"/>
            </Border.Effect>

            <Grid Margin="16,12,16,16">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <!-- Top Drag Bar & Window Controls (Log, Minimize to Bubble, Close) -->
                <Grid Grid.Row="0" Background="Transparent" Margin="0,0,0,10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <!-- Status Pill -->
                    <Border Grid.Column="0" HorizontalAlignment="Left"
                            Background="#121214" BorderBrush="#2E2E33" BorderThickness="1"
                            CornerRadius="12" Padding="10,4">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Ellipse x:Name="StatusDot" Width="7" Height="7" Fill="#A1A1AA" Margin="0,0,6,0"/>
                            <TextBlock x:Name="StatusLabel" Text="READY"
                                       Foreground="#A1A1AA" FontSize="10" FontWeight="Bold"
                                       FontFamily="Segoe UI"/>
                        </StackPanel>
                    </Border>

                    <!-- Header Action Buttons: Log, Minimize, Close -->
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <!-- Log Button -->
                        <Button x:Name="ToggleLogButton"
                                Style="{StaticResource HeaderIconBtn}"
                                ToolTip="View Study Log"
                                Padding="9,4" Height="28" Margin="0,0,6,0">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Path x:Name="ToggleLogIcon"
                                      Data="M 1,2 L 10,2 M 1,5.5 L 10,5.5 M 1,9 L 7,9"
                                      Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                                      StrokeThickness="1.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                      Width="11" Height="11" VerticalAlignment="Center" Margin="0,0,5,0"/>
                                <TextBlock x:Name="ToggleLogLabel" Text="Log"
                                           FontSize="11" FontWeight="SemiBold" FontFamily="Segoe UI"
                                           VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>

                        <!-- Minimize to Floating Bubble Button -->
                        <Button x:Name="MinimizeButton"
                                Style="{StaticResource HeaderIconBtn}"
                                ToolTip="Minimize to Floating Bubble"
                                Width="28" Height="28" Margin="0,0,6,0">
                            <Path Data="M 1,6 L 11,6"
                                  Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                                  StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                  Width="12" Height="12" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                        </Button>

                        <!-- Close Button -->
                        <Button x:Name="CloseButton"
                                Style="{StaticResource HeaderIconBtn}"
                                ToolTip="Close Timer"
                                Width="28" Height="28">
                            <Path Data="M 2,2 L 10,10 M 10,2 L 2,10"
                                  Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                                  StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                  Width="12" Height="12" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                        </Button>
                    </StackPanel>
                </Grid>

                <!-- VIEW 1: Timer & Buttons Only -->
                <StackPanel x:Name="TimerViewPanel" Grid.Row="1" Visibility="Visible">
                    <!-- Digital Timer Display -->
                    <TextBlock x:Name="TimerText"
                               Text="00:00:00"
                               Foreground="#FFFFFF"
                               FontFamily="Consolas"
                               FontSize="46"
                               FontWeight="Bold"
                               HorizontalAlignment="Center"
                               Margin="0,8,0,18"/>

                    <!-- 2x2 Control Grid -->
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="10"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="10"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- START / RESUME -->
                        <Button x:Name="StartButton" Grid.Row="0" Grid.Column="0"
                                Style="{StaticResource CardButtonStyle}"
                                Background="#FFFFFF" Foreground="#000000" BorderBrush="#FFFFFF"
                                FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                                Height="46">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Path Data="M 1,0 L 10,5.5 L 1,11 Z"
                                      Fill="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                                      Width="11" Height="11" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                <TextBlock x:Name="StartButtonLabel" Text="START" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>

                        <!-- PAUSE -->
                        <Button x:Name="PauseButton" Grid.Row="0" Grid.Column="2"
                                Style="{StaticResource CardButtonStyle}"
                                Background="#222226" Foreground="#FFFFFF" BorderBrush="#E4E4E7"
                                FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                                Height="46" IsEnabled="False">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Path Data="M 1,0 L 4,0 L 4,11 L 1,11 Z M 7,0 L 10,0 L 10,11 L 7,11 Z"
                                      Fill="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                                      Width="11" Height="11" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                <TextBlock Text="PAUSE" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>

                        <!-- STOP -->
                        <Button x:Name="StopButton" Grid.Row="2" Grid.Column="0"
                                Style="{StaticResource CardButtonStyle}"
                                Background="#222226" Foreground="#FFFFFF" BorderBrush="#3F3F46"
                                FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                                Height="46" IsEnabled="False">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Path Data="M 1,1 L 10,1 L 10,10 L 1,10 Z"
                                      Fill="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                                      Width="11" Height="11" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                <TextBlock Text="STOP" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>

                        <!-- RESET -->
                        <Button x:Name="ResetButton" Grid.Row="2" Grid.Column="2"
                                Style="{StaticResource CardButtonStyle}"
                                Background="#121214" Foreground="#D4D4D8" BorderBrush="#2E2E33"
                                FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                                Height="46" IsEnabled="False">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Path Data="M 9.5,3.5 A 4.5,4.5 0 1,0 10,7 M 9.5,1 L 9.5,4 L 6.5,4"
                                      Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                                      StrokeThickness="1.6" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                      Width="12" Height="12" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                <TextBlock Text="RESET" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                </StackPanel>

                <!-- VIEW 2: Daily Study Log & Total Studied Today -->
                <StackPanel x:Name="LogViewPanel" Grid.Row="1" Visibility="Collapsed">
                    <!-- Daily Summary Card -->
                    <Border Background="#121214" BorderBrush="#2E2E33" BorderThickness="1"
                            CornerRadius="12" Padding="14" Margin="0,2,0,12">
                        <StackPanel>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Grid.Column="0" Text="TOTAL STUDIED TODAY"
                                           Foreground="#A1A1AA" FontSize="10" FontWeight="Bold"
                                           VerticalAlignment="Center"/>
                                <Border Grid.Column="1" Background="#222226" CornerRadius="6" Padding="8,3">
                                    <TextBlock x:Name="StartedCountText" Text="0 started"
                                               Foreground="#E4E4E7" FontSize="10" FontWeight="Bold"/>
                                </Border>
                            </Grid>
                            <TextBlock x:Name="TotalTodayText" Text="0s"
                                       Foreground="#FFFFFF" FontSize="26" FontWeight="Bold"
                                       FontFamily="Segoe UI" Margin="0,6,0,0"/>
                        </StackPanel>
                    </Border>

                    <TextBlock x:Name="SessionsHeaderText" Text="TODAY'S SESSIONS (0)"
                               Foreground="#A1A1AA" FontSize="10" FontWeight="Bold"
                               Margin="2,0,0,6"/>

                    <!-- Scrollable Session List -->
                    <ScrollViewer MaxHeight="200" VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="SessionsListPanel"/>
                    </ScrollViewer>
                </StackPanel>
            </Grid>
        </Border>

        <!-- MINIMIZED FLOATING DRAGGABLE BUBBLE -->
        <Border x:Name="BubbleBorder"
                Background="#000000"
                BorderBrush="#3F3F46"
                BorderThickness="1.5"
                CornerRadius="24"
                Padding="14,8,10,8"
                Margin="8"
                Cursor="SizeAll"
                Visibility="Collapsed">
            <Border.Effect>
                <DropShadowEffect Color="#000000" BlurRadius="14" ShadowDepth="3" Opacity="0.85"/>
            </Border.Effect>

            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                <Ellipse x:Name="BubbleDot" Width="8" Height="8" Fill="#FFFFFF" Margin="0,0,8,0"/>
                <TextBlock x:Name="BubbleTimerText"
                           Text="00:00:00"
                           Foreground="#FFFFFF"
                           FontFamily="Consolas"
                           FontSize="16"
                           FontWeight="Bold"
                           VerticalAlignment="Center"
                           Margin="0,0,10,0"/>
                <!-- Expand back to full card -->
                <Button x:Name="ExpandButton"
                        Style="{StaticResource HeaderIconBtn}"
                        ToolTip="Expand Timer Card"
                        Width="26" Height="26"
                        Cursor="Hand">
                    <Path Data="M 2,5 L 2,2 L 5,2 M 7,2 L 10,2 L 10,5 M 10,7 L 10,10 L 7,10 M 5,10 L 2,10 L 2,7"
                          Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                          StrokeThickness="1.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                          Width="12" Height="12" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                </Button>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Card Controls
$mainCardBorder = $window.FindName("MainCardBorder")
$statusDot = $window.FindName("StatusDot")
$statusLabel = $window.FindName("StatusLabel")
$toggleLogButton = $window.FindName("ToggleLogButton")
$toggleLogLabel = $window.FindName("ToggleLogLabel")
$minimizeButton = $window.FindName("MinimizeButton")
$closeButton = $window.FindName("CloseButton")

$timerViewPanel = $window.FindName("TimerViewPanel")
$logViewPanel = $window.FindName("LogViewPanel")
$timerText = $window.FindName("TimerText")
$startButton = $window.FindName("StartButton")
$startButtonLabel = $window.FindName("StartButtonLabel")
$pauseButton = $window.FindName("PauseButton")
$stopButton = $window.FindName("StopButton")
$resetButton = $window.FindName("ResetButton")

$startedCountText = $window.FindName("StartedCountText")
$totalTodayText = $window.FindName("TotalTodayText")
$sessionsHeaderText = $window.FindName("SessionsHeaderText")
$sessionsListPanel = $window.FindName("SessionsListPanel")

# Bubble Controls
$bubbleBorder = $window.FindName("BubbleBorder")
$bubbleDot = $window.FindName("BubbleDot")
$bubbleTimerText = $window.FindName("BubbleTimerText")
$expandButton = $window.FindName("ExpandButton")

$brushConverter = New-Object System.Windows.Media.BrushConverter
$brushWhite = [System.Windows.Media.Brushes]::White
$brushGrey400 = $brushConverter.ConvertFromString("#A1A1AA")
$brushGrey500 = $brushConverter.ConvertFromString("#71717A")
$brushGrey700 = $brushConverter.ConvertFromString("#2E2E33")
$brushGrey800 = $brushConverter.ConvertFromString("#222226")
$brushGrey850 = $brushConverter.ConvertFromString("#18181B")
$brushGrey900 = $brushConverter.ConvertFromString("#121214")

function Format-Time([long]$totalSeconds) {
    $h = [math]::Floor($totalSeconds / 3600)
    $m = [math]::Floor(($totalSeconds % 3600) / 60)
    $s = $totalSeconds % 60
    return "{0:00}:{1:00}:{2:00}" -f $h, $m, $s
}

function Format-DurationLabel([long]$totalSeconds) {
    $h = [math]::Floor($totalSeconds / 3600)
    $m = [math]::Floor(($totalSeconds % 3600) / 60)
    $s = $totalSeconds % 60
    if ($h -gt 0) {
        return "{0}h {1:00}m {2:00}s" -f $h, $m, $s
    } elseif ($m -gt 0) {
        return "{0}m {1:00}s" -f $m, $s
    } else {
        return "{0}s" -f $s
    }
}

function Get-ElapsedSeconds {
    return [long][math]::Floor($script:stopwatch.Elapsed.TotalSeconds)
}

function Save-CurrentSessionIfEligible {
    $elapsedMs = $script:stopwatch.ElapsedMilliseconds
    if (-not $script:hasSavedCurrentSession -and $elapsedMs -gt 0 -and $null -ne $script:currentStartTime) {
        $script:hasSavedCurrentSession = $true
        $durSec = [long][math]::Max(1, [math]::Round($script:stopwatch.Elapsed.TotalSeconds))
        $stopNow = Get-Date
        $record = [PSCustomObject]@{
            date = $script:currentStartTime.ToString("yyyy-MM-dd")
            startTime = $script:currentStartTime.ToString("h:mm:ss tt")
            stopTime = $stopNow.ToString("h:mm:ss tt")
            durationSeconds = $durSec
        }
        [void]$script:allSessions.Add($record)
        Save-Sessions
    }
}

function New-SessionRowCard($badgeText, $line1Text, $line2Text, $pillText, $isActive) {
    $card = New-Object System.Windows.Controls.Border
    $card.Background = $brushGrey900
    $card.BorderBrush = if ($isActive) { $brushGrey400 } else { $brushGrey800 }
    $card.BorderThickness = New-Object System.Windows.Thickness(1)
    $card.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $card.Padding = New-Object System.Windows.Thickness(10)
    $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)

    $grid = New-Object System.Windows.Controls.Grid
    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = "*"
    $col2 = New-Object System.Windows.Controls.ColumnDefinition
    $col2.Width = "Auto"
    [void]$grid.ColumnDefinitions.Add($col1)
    [void]$grid.ColumnDefinitions.Add($col2)

    $leftStack = New-Object System.Windows.Controls.StackPanel
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = "$badgeText  $line1Text"
    $t1.Foreground = $brushWhite
    $t1.FontSize = 11.5
    $t1.FontWeight = "SemiBold"

    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = $line2Text
    $t2.Foreground = $brushGrey400
    $t2.FontSize = 10.5

    [void]$leftStack.Children.Add($t1)
    [void]$leftStack.Children.Add($t2)
    [System.Windows.Controls.Grid]::SetColumn($leftStack, 0)
    [void]$grid.Children.Add($leftStack)

    $durPill = New-Object System.Windows.Controls.Border
    $durPill.Background = $brushGrey850
    $durPill.BorderBrush = $brushGrey700
    $durPill.BorderThickness = New-Object System.Windows.Thickness(1)
    $durPill.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $durPill.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
    $durPill.VerticalAlignment = "Center"

    $durText = New-Object System.Windows.Controls.TextBlock
    $durText.Text = $pillText
    $durText.Foreground = $brushWhite
    $durText.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
    $durText.FontSize = 11
    $durText.FontWeight = "Bold"
    $durPill.Child = $durText

    [System.Windows.Controls.Grid]::SetColumn($durPill, 1)
    [void]$grid.Children.Add($durPill)

    $card.Child = $grid
    return $card
}

function Refresh-LogView {
    $todayStr = (Get-Date).ToString("yyyy-MM-dd")
    $todayList = @($script:allSessions | Where-Object { $_.date -eq $todayStr })

    [long]$savedSeconds = 0
    foreach ($item in $todayList) {
        $savedSeconds += [long]$item.durationSeconds
    }

    $hasLiveSession = (($script:status -eq "RUNNING" -or $script:status -eq "PAUSED") -and -not $script:hasSavedCurrentSession -and $null -ne $script:currentStartTime)
    $liveExtra = if ($hasLiveSession) { Get-ElapsedSeconds } else { 0 }
    $totalSeconds = $savedSeconds + $liveExtra
    $startedTotal = $todayList.Count + $(if ($hasLiveSession) { 1 } else { 0 })

    $startedCountText.Text = "$startedTotal started"
    $totalTodayText.Text = Format-DurationLabel $totalSeconds
    $sessionsHeaderText.Text = "TODAY'S SESSIONS ($startedTotal)"

    $sessionsListPanel.Children.Clear()

    if ($hasLiveSession) {
        $liveBadge = if ($script:status -eq "RUNNING") { "LIVE" } else { "PAUSED" }
        $liveRow = New-SessionRowCard `
            -badgeText "[$liveBadge]" `
            -line1Text "Started: $($script:currentStartTime.ToString('h:mm:ss tt'))" `
            -line2Text "Session in progress..." `
            -pillText (Format-DurationLabel $liveExtra) `
            -isActive $true
        [void]$sessionsListPanel.Children.Add($liveRow)
    }

    if ($todayList.Count -eq 0 -and -not $hasLiveSession) {
        $emptyBlock = New-Object System.Windows.Controls.TextBlock
        $emptyBlock.Text = "No study sessions recorded today yet."
        $emptyBlock.Foreground = $brushGrey500
        $emptyBlock.FontSize = 12
        $emptyBlock.HorizontalAlignment = "Center"
        $emptyBlock.Margin = New-Object System.Windows.Thickness(0, 16, 0, 16)
        [void]$sessionsListPanel.Children.Add($emptyBlock)
    } else {
        # Show newest saved sessions first
        for ($i = $todayList.Count - 1; $i -ge 0; $i--) {
            $sess = $todayList[$i]
            $num = $i + 1
            $row = New-SessionRowCard `
                -badgeText "#$num" `
                -line1Text "Started: $($sess.startTime)" `
                -line2Text "Stopped: $($sess.stopTime)" `
                -pillText (Format-DurationLabel ([long]$sess.durationSeconds)) `
                -isActive $false
            [void]$sessionsListPanel.Children.Add($row)
        }
    }
}

function Update-UI {
    $elapsed = Get-ElapsedSeconds
    $formatted = Format-Time $elapsed
    $timerText.Text = $formatted
    $bubbleTimerText.Text = $formatted

    $isIdle = ($script:status -eq "IDLE")
    $isRunning = ($script:status -eq "RUNNING")
    $isPaused = ($script:status -eq "PAUSED")

    $statusLabel.Text = if ($isIdle) { "READY" } else { $script:status }
    if ($isRunning) {
        $statusDot.Fill = $brushWhite
        $statusLabel.Foreground = $brushWhite
        $bubbleDot.Fill = $brushWhite
    } else {
        $statusDot.Fill = $brushGrey400
        $statusLabel.Foreground = $brushGrey400
        $bubbleDot.Fill = $brushGrey400
    }

    $startButton.IsEnabled = (-not $isRunning)
    $startButtonLabel.Text = if ($isPaused) { "RESUME" } else { "START" }
    $pauseButton.IsEnabled = $isRunning
    $stopButton.IsEnabled = ($isRunning -or $isPaused)
    $resetButton.IsEnabled = (-not $isIdle -and -not $isRunning)

    if ($script:activeView -eq "LOG" -and -not $script:isMinimizedBubble) {
        Refresh-LogView
    }
}

function Enter-BubbleMode {
    $script:isMinimizedBubble = $true
    $mainCardBorder.Visibility = "Collapsed"
    $bubbleBorder.Visibility = "Visible"
}

function Exit-BubbleMode {
    $script:isMinimizedBubble = $false
    $bubbleBorder.Visibility = "Collapsed"
    $mainCardBorder.Visibility = "Visible"
    if ($script:activeView -eq "LOG") {
        Refresh-LogView
    }
}

# Drag card anywhere on background/header
$mainCardBorder.Add_MouseLeftButtonDown({
    try {
        if ($_.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
            $window.DragMove()
        }
    } catch {
    }
})

# Drag bubble anywhere on screen; double-click bubble to expand
$bubbleBorder.Add_MouseLeftButtonDown({
    if ($_.ClickCount -eq 2) {
        Exit-BubbleMode
        return
    }
    try {
        if ($_.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
            $window.DragMove()
        }
    } catch {
    }
})

# Window Header & Bubble Actions
$minimizeButton.Add_Click({ Enter-BubbleMode })
$expandButton.Add_Click({ Exit-BubbleMode })

$closeButton.Add_Click({
    Save-CurrentSessionIfEligible
    $window.Close()
})

$toggleLogButton.Add_Click({
    if ($script:activeView -eq "TIMER") {
        $script:activeView = "LOG"
        $timerViewPanel.Visibility = "Collapsed"
        $logViewPanel.Visibility = "Visible"
        $toggleLogLabel.Text = "Timer"
        Refresh-LogView
    } else {
        $script:activeView = "TIMER"
        $logViewPanel.Visibility = "Collapsed"
        $timerViewPanel.Visibility = "Visible"
        $toggleLogLabel.Text = "Log"
    }
})

# Timer Control Buttons
$startButton.Add_Click({
    if ($script:status -eq "RUNNING") { return }
    if ($null -eq $script:currentStartTime -or $script:hasSavedCurrentSession) {
        if ($script:status -eq "STOPPED") {
            $script:stopwatch.Reset()
        }
        $script:currentStartTime = Get-Date
        $script:hasSavedCurrentSession = $false
    }
    $script:stopwatch.Start()
    $script:status = "RUNNING"
    Update-UI
})

$pauseButton.Add_Click({
    if ($script:status -ne "RUNNING") { return }
    $script:stopwatch.Stop()
    $script:status = "PAUSED"
    Update-UI
})

$stopButton.Add_Click({
    if ($script:status -eq "IDLE") { return }
    $script:stopwatch.Stop()
    Save-CurrentSessionIfEligible
    $script:status = "STOPPED"
    Update-UI
})

$resetButton.Add_Click({
    $script:stopwatch.Stop()
    Save-CurrentSessionIfEligible
    $script:stopwatch.Reset()
    $script:currentStartTime = $null
    $script:hasSavedCurrentSession = $false
    $script:status = "IDLE"
    Update-UI
})

# Live UI refresh timer
$uiTimer = New-Object System.Windows.Threading.DispatcherTimer
$uiTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$uiTimer.Add_Tick({
    if ($script:status -eq "RUNNING") {
        $formatted = Format-Time (Get-ElapsedSeconds)
        $timerText.Text = $formatted
        $bubbleTimerText.Text = $formatted
        if ($script:activeView -eq "LOG" -and -not $script:isMinimizedBubble) {
            Refresh-LogView
        }
    }
})
$uiTimer.Start()

$window.Add_Closing({
    $uiTimer.Stop()
    Save-CurrentSessionIfEligible
})

Update-UI
[void]$window.ShowDialog()
