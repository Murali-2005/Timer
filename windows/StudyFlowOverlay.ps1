Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Persistence setup in %LOCALAPPDATA%\StudyFlow\sessions.json
$dataDir = Join-Path $env:LOCALAPPDATA "StudyFlow"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}
$dataFile = Join-Path $dataDir "sessions.json"

function Load-Sessions {
    if (Test-Path $dataFile) {
        try {
            $raw = Get-Content -Path $dataFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $parsed = $raw | ConvertFrom-Json
                if ($null -ne $parsed) {
                    return [System.Collections.ArrayList]@($parsed)
                }
            }
        } catch {
        }
    }
    return [System.Collections.ArrayList]::new()
}

function Save-Sessions($sessionsList) {
    try {
        $json = ConvertTo-Json -InputObject @($sessionsList) -Depth 4
        Set-Content -Path $dataFile -Value $json -Encoding UTF8
    } catch {
    }
}

$script:allSessions = Load-Sessions
$script:status = "IDLE" # IDLE, RUNNING, PAUSED, STOPPED
$script:stopwatch = [System.Diagnostics.Stopwatch]::new()
$script:currentStartTime = $null
$script:hasSavedCurrentSession = $false
$script:activeView = "TIMER" # TIMER or LOG

# Pure Black, Grey & White Floating Overlay Card XAML
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="StudyFlow Timer"
        Width="330"
        SizeToContent="Height"
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
                                <Setter TargetName="border" Property="Opacity" Value="0.35"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="HeaderIconBtn" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="#18181B"/>
            <Setter Property="Foreground" Value="#A1A1AA"/>
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
                                <Setter TargetName="border" Property="Background" Value="#222226"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <!-- Main Floating Card -->
    <Border x:Name="MainCardBorder"
            Background="#000000"
            BorderBrush="#2E2E33"
            BorderThickness="1.5"
            CornerRadius="18"
            Margin="10">
        <Border.Effect>
            <DropShadowEffect Color="#000000" BlurRadius="18" ShadowDepth="4" Opacity="0.75"/>
        </Border.Effect>

        <Grid Margin="16,12,16,16">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Top Drag Bar & Window Controls -->
            <Grid x:Name="HeaderDragBar" Grid.Row="0" Background="Transparent" Margin="0,0,0,10">
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

                <!-- View Toggle, Minimize, Close -->
                <StackPanel Grid.Column="1" Orientation="Horizontal">
                    <Button x:Name="ToggleLogButton" Content="Log"
                            Style="{StaticResource HeaderIconBtn}"
                            FontSize="11" FontWeight="SemiBold"
                            Padding="10,4" Margin="0,0,6,0"/>
                    <Button x:Name="MinimizeButton" Content="—"
                            Style="{StaticResource HeaderIconBtn}"
                            FontSize="11" FontWeight="Bold"
                            Width="26" Height="26" Margin="0,0,6,0"/>
                    <Button x:Name="CloseButton" Content="✕"
                            Style="{StaticResource HeaderIconBtn}"
                            FontSize="11" FontWeight="Bold"
                            Width="26" Height="26"/>
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
                            Content="START"
                            Style="{StaticResource CardButtonStyle}"
                            Background="#FFFFFF" Foreground="#000000" BorderBrush="#FFFFFF"
                            FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                            Height="44"/>

                    <!-- PAUSE -->
                    <Button x:Name="PauseButton" Grid.Row="0" Grid.Column="2"
                            Content="PAUSE"
                            Style="{StaticResource CardButtonStyle}"
                            Background="#222226" Foreground="#FFFFFF" BorderBrush="#E4E4E7"
                            FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                            Height="44" IsEnabled="False"/>

                    <!-- STOP -->
                    <Button x:Name="StopButton" Grid.Row="2" Grid.Column="0"
                            Content="STOP"
                            Style="{StaticResource CardButtonStyle}"
                            Background="#222226" Foreground="#FFFFFF" BorderBrush="#3F3F46"
                            FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                            Height="44" IsEnabled="False"/>

                    <!-- RESET -->
                    <Button x:Name="ResetButton" Grid.Row="2" Grid.Column="2"
                            Content="RESET"
                            Style="{StaticResource CardButtonStyle}"
                            Background="#121214" Foreground="#A1A1AA" BorderBrush="#2E2E33"
                            FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                            Height="44" IsEnabled="False"/>
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
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$headerDragBar = $window.FindName("HeaderDragBar")
$mainCardBorder = $window.FindName("MainCardBorder")
$statusDot = $window.FindName("StatusDot")
$statusLabel = $window.FindName("StatusLabel")
$toggleLogButton = $window.FindName("ToggleLogButton")
$minimizeButton = $window.FindName("MinimizeButton")
$closeButton = $window.FindName("CloseButton")

$timerViewPanel = $window.FindName("TimerViewPanel")
$logViewPanel = $window.FindName("LogViewPanel")
$timerText = $window.FindName("TimerText")
$startButton = $window.FindName("StartButton")
$pauseButton = $window.FindName("PauseButton")
$stopButton = $window.FindName("StopButton")
$resetButton = $window.FindName("ResetButton")

$startedCountText = $window.FindName("StartedCountText")
$totalTodayText = $window.FindName("TotalTodayText")
$sessionsHeaderText = $window.FindName("SessionsHeaderText")
$sessionsListPanel = $window.FindName("SessionsListPanel")

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
    $elapsed = Get-ElapsedSeconds
    if (-not $script:hasSavedCurrentSession -and $elapsed -gt 0 -and $null -ne $script:currentStartTime) {
        $script:hasSavedCurrentSession = $true
        $stopNow = Get-Date
        $record = [PSCustomObject]@{
            date = $script:currentStartTime.ToString("yyyy-MM-dd")
            startTime = $script:currentStartTime.ToString("h:mm tt")
            stopTime = $stopNow.ToString("h:mm tt")
            durationSeconds = $elapsed
        }
        [void]$script:allSessions.Add($record)
        Save-Sessions $script:allSessions
    }
}

$brushConverter = New-Object System.Windows.Media.BrushConverter
$brushWhite = [System.Windows.Media.Brushes]::White
$brushGrey400 = $brushConverter.ConvertFromString("#A1A1AA")
$brushGrey500 = $brushConverter.ConvertFromString("#71717A")
$brushGrey700 = $brushConverter.ConvertFromString("#2E2E33")
$brushGrey800 = $brushConverter.ConvertFromString("#222226")
$brushGrey850 = $brushConverter.ConvertFromString("#18181B")
$brushGrey900 = $brushConverter.ConvertFromString("#121214")

function Refresh-LogView {
    $todayStr = (Get-Date).ToString("yyyy-MM-dd")
    $todayList = @($script:allSessions | Where-Object { $_.date -eq $todayStr })

    [long]$savedSeconds = 0
    foreach ($item in $todayList) {
        $savedSeconds += [long]$item.durationSeconds
    }

    $liveExtra = if ($script:status -eq "RUNNING" -or $script:status -eq "PAUSED") { Get-ElapsedSeconds } else { 0 }
    $totalSeconds = $savedSeconds + $liveExtra

    $startedCountText.Text = "$($todayList.Count) started"
    $totalTodayText.Text = Format-DurationLabel $totalSeconds
    $sessionsHeaderText.Text = "TODAY'S SESSIONS ($($todayList.Count))"

    $sessionsListPanel.Children.Clear()
    if ($todayList.Count -eq 0) {
        $emptyBlock = New-Object System.Windows.Controls.TextBlock
        $emptyBlock.Text = "No study sessions recorded today yet."
        $emptyBlock.Foreground = $brushGrey500
        $emptyBlock.FontSize = 12
        $emptyBlock.HorizontalAlignment = "Center"
        $emptyBlock.Margin = New-Object System.Windows.Thickness(0, 16, 0, 16)
        [void]$sessionsListPanel.Children.Add($emptyBlock)
    } else {
        # Show newest first
        for ($i = $todayList.Count - 1; $i -ge 0; $i--) {
            $sess = $todayList[$i]
            $num = $i + 1

            $card = New-Object System.Windows.Controls.Border
            $card.Background = $brushGrey900
            $card.BorderBrush = $brushGrey800
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
            $t1.Text = "#$num  Started: $($sess.startTime)"
            $t1.Foreground = $brushWhite
            $t1.FontSize = 12
            $t1.FontWeight = "SemiBold"

            $t2 = New-Object System.Windows.Controls.TextBlock
            $t2.Text = "Stopped: $($sess.stopTime)"
            $t2.Foreground = $brushGrey400
            $t2.FontSize = 11

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
            $durText.Text = Format-DurationLabel ([long]$sess.durationSeconds)
            $durText.Foreground = $brushWhite
            $durText.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
            $durText.FontSize = 11
            $durText.FontWeight = "Bold"
            $durPill.Child = $durText

            [System.Windows.Controls.Grid]::SetColumn($durPill, 1)
            [void]$grid.Children.Add($durPill)

            $card.Child = $grid
            [void]$sessionsListPanel.Children.Add($card)
        }
    }
}

function Update-UI {
    $elapsed = Get-ElapsedSeconds
    $timerText.Text = Format-Time $elapsed

    $isIdle = ($script:status -eq "IDLE")
    $isRunning = ($script:status -eq "RUNNING")
    $isPaused = ($script:status -eq "PAUSED")

    $statusLabel.Text = if ($isIdle) { "READY" } else { $script:status }
    if ($isRunning) {
        $statusDot.Fill = $brushWhite
        $statusLabel.Foreground = $brushWhite
    } else {
        $statusDot.Fill = $brushGrey400
        $statusLabel.Foreground = $brushGrey400
    }

    $startButton.IsEnabled = (-not $isRunning)
    $startButton.Content = if ($isPaused) { "RESUME" } else { "START" }
    $pauseButton.IsEnabled = $isRunning
    $stopButton.IsEnabled = ($isRunning -or $isPaused)
    $resetButton.IsEnabled = (-not $isIdle -and -not $isRunning)

    if ($script:activeView -eq "LOG") {
        Refresh-LogView
    }
}

# Drag card anywhere on empty card background or header
$mainCardBorder.Add_MouseLeftButtonDown({
    try {
        if ($_.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
            $window.DragMove()
        }
    } catch {
    }
})

# Window Header Actions
$minimizeButton.Add_Click({ $window.WindowState = "Minimized" })
$closeButton.Add_Click({
    Save-CurrentSessionIfEligible
    $window.Close()
})

$toggleLogButton.Add_Click({
    if ($script:activeView -eq "TIMER") {
        $script:activeView = "LOG"
        $timerViewPanel.Visibility = "Collapsed"
        $logViewPanel.Visibility = "Visible"
        $toggleLogButton.Content = "Timer"
        Refresh-LogView
    } else {
        $script:activeView = "TIMER"
        $logViewPanel.Visibility = "Collapsed"
        $timerViewPanel.Visibility = "Visible"
        $toggleLogButton.Content = "Log"
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
        $timerText.Text = Format-Time (Get-ElapsedSeconds)
        if ($script:activeView -eq "LOG") {
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
