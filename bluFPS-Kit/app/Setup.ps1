# bluFPS Setup - per-user installer (no admin rights needed)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$here = if ($PSScriptRoot) { $PSScriptRoot } else { $env:BLUFPS_HOME }
$ver = '1.2.0.1'
$verShow = $ver; if (($ver.Split('.')).Count -ge 4 -and [int]$ver.Split('.')[3] -gt 0) { $verShow = $ver.Substring(0, $ver.LastIndexOf('.')) + ' (build ' + $ver.Split('.')[3] + ')' }
$hasExe = Test-Path (Join-Path $here 'bluFPS.exe')
$files = 'bluFPS.ps1', 'bluFPS.vbs', 'bluFPS.ico', 'bluFPS.png', 'update-source.txt', 'Uninstall.ps1'
if ($hasExe) { $files += 'bluFPS.exe' }
if ($files | Where-Object { -not (Test-Path (Join-Path $here $_)) }) {
    [Windows.MessageBox]::Show('Some installer files are missing. Please extract the whole zip first, then run Setup.bat again.', 'bluFPS Setup', 'OK', 'Warning') | Out-Null
    return
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="bluFPS Setup" Width="520" Height="580" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        FontFamily="Segoe UI" Foreground="White">
  <Window.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#070B18" Offset="0"/><GradientStop Color="#0C1738" Offset="1"/></LinearGradientBrush></Window.Background>
  <Window.Resources>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Background" Value="#1B2A55"/><Setter Property="Foreground" Value="White"/><Setter Property="FontSize" Value="13"/>
      <Setter Property="Padding" Value="22,9"/><Setter Property="Margin" Value="0,0,10,0"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.8"/></Trigger></ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
  </Window.Resources>
  <StackPanel Margin="34,28">
    <StackPanel Orientation="Horizontal" Margin="0,0,0,20">
      <Image x:Name="logoImg" Width="76" Height="76" RenderOptions.BitmapScalingMode="HighQuality"><Image.Effect><DropShadowEffect Color="#2F7BFF" BlurRadius="18" ShadowDepth="0" Opacity="0.6"/></Image.Effect></Image>
      <StackPanel Margin="18,0,0,0" VerticalAlignment="Center">
        <TextBlock FontSize="32" FontWeight="Bold"><Run Text="blu" Foreground="#4DA3FF"/><Run Text="FPS"/></TextBlock>
        <TextBlock x:Name="verText" Text="SETUP" FontSize="11" Foreground="#6C7CA3"/>
      </StackPanel>
    </StackPanel>
    <TextBlock TextWrapping="Wrap" Foreground="#9FB0D0" Margin="0,0,0,20"
      Text="This installs bluFPS for your Windows account. Setup itself does not need administrator rights. bluFPS asks for admin permission each time you open it, because it changes Windows gaming settings."/>
    <TextBlock Text="INSTALL FOLDER" FontSize="11" Foreground="#6C7CA3" Margin="0,0,0,4"/>
    <TextBox x:Name="path" Background="#131B33" Foreground="White" CaretBrush="White" BorderThickness="0" Padding="10,8" FontSize="13" Margin="0,0,0,18"/>
    <CheckBox x:Name="chkDesk" IsChecked="True" Content="Create a desktop shortcut" Foreground="White" Margin="0,0,0,8"/>
    <CheckBox x:Name="chkMenu" IsChecked="True" Content="Add bluFPS to the Start menu" Foreground="White" Margin="0,0,0,8"/>
    <CheckBox x:Name="chkRun" IsChecked="True" Content="Launch bluFPS when setup finishes" Foreground="White"/>
    <ProgressBar x:Name="bar" Height="6" Maximum="100" Foreground="#2F7BFF" Background="#1E2A4D" BorderThickness="0" Margin="0,26,0,8"/>
    <TextBlock x:Name="msg" Text="Ready to install." Foreground="#6C7CA3" FontSize="12" TextWrapping="Wrap"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
      <Button x:Name="btnCancel" Style="{StaticResource Btn}" Content="Cancel"/>
      <Button x:Name="btnInstall" Style="{StaticResource Btn}" Background="#2F7BFF" Margin="0" Content="Install"/>
    </StackPanel>
  </StackPanel>
</Window>
'@

$win = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml]$xaml))
$c = @{}
[regex]::Matches($xaml, 'x:Name="(\w+)"') | ForEach-Object { $c[$_.Groups[1].Value] = $win.FindName($_.Groups[1].Value) }
$c.path.Text = Join-Path $env:LOCALAPPDATA 'Programs\bluFPS'
try {
    $bmp = New-Object Windows.Media.Imaging.BitmapImage
    $bmp.BeginInit(); $bmp.UriSource = New-Object Uri (Join-Path $here 'bluFPS.png'); $bmp.CacheOption = 'OnLoad'; $bmp.EndInit()
    $c.logoImg.Source = $bmp; $win.Icon = $bmp
} catch {}
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\bluFPS'
$cur = Get-ItemProperty $reg -ErrorAction SilentlyContinue
if ($cur -and $cur.DisplayVersion) {
    $isNewer = $false
    try { $isNewer = ([version]$cur.DisplayVersion) -gt ([version]$ver) } catch {}
    if ($isNewer) {
        $c.verText.Text = "VERSION $verShow  -  REPLACING NEWER VERSION $($cur.DisplayVersion)"
        $c.msg.Text = "A newer bluFPS ($($cur.DisplayVersion)) is installed. Setup will replace it with version $verShow."
    } else {
        $c.verText.Text = "VERSION $verShow  -  UPDATING FROM $($cur.DisplayVersion)"
        $c.msg.Text = "bluFPS $($cur.DisplayVersion) is installed. Setup will update it to $verShow."
        $c.btnInstall.Content = 'Update'
    }
    if ($cur.InstallLocation) { $c.path.Text = $cur.InstallLocation }
} else { $c.verText.Text = "VERSION $verShow  -  SETUP" }
$script:done = $false

function Step($text, $pct) {
    $c.msg.Text = $text; $c.bar.Value = $pct
    $win.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{})
}

function New-Shortcut($lnk, $dest) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    if ($hasExe) { $s.TargetPath = "$dest\bluFPS.exe" }
    else { $s.TargetPath = "$env:WINDIR\System32\wscript.exe"; $s.Arguments = "`"$dest\bluFPS.vbs`"" }
    $s.WorkingDirectory = $dest
    $s.IconLocation = "$dest\bluFPS.ico"
    $s.Description = 'bluFPS gaming optimizer'
    $s.Save()
}

$c.btnCancel.Add_Click({ $win.Close() })
$c.btnInstall.Add_Click({
    if ($script:done) {
        if ($c.chkRun.IsChecked) {
            if ($hasExe) { Start-Process "$($script:dest)\bluFPS.exe" }
            else { Start-Process "$env:WINDIR\System32\wscript.exe" -ArgumentList "`"$($script:dest)\bluFPS.vbs`"" }
        }
        $win.Close(); return
    }
    $dest = $c.path.Text.Trim(); $script:dest = $dest
    try {
        $c.btnInstall.IsEnabled = $false; $c.btnCancel.IsEnabled = $false; $c.path.IsEnabled = $false
        $c.msg.Foreground = '#6C7CA3'
        # a running bluFPS locks its own files: close it first (it runs as admin, so this may need the user)
        Step 'Checking that bluFPS is closed...' 8
        $run = @(Get-Process -Name bluFPS -ErrorAction SilentlyContinue)
        if ($run.Count) {
            foreach ($p in $run) { try { [void]$p.CloseMainWindow() } catch {} }
            Start-Sleep -Milliseconds 1500
            foreach ($p in @(Get-Process -Name bluFPS -ErrorAction SilentlyContinue)) { try { $p.Kill() } catch {} }
            Start-Sleep -Milliseconds 1000
            if (@(Get-Process -Name bluFPS -ErrorAction SilentlyContinue).Count) {
                throw 'bluFPS is still running and Setup cannot close it (it runs as administrator). Close bluFPS yourself - the X in its window, or End task on "bluFPS" in Task Manager - then press Install again.'
            }
        }
        Step 'Copying files...' 20
        New-Item $dest -ItemType Directory -Force | Out-Null
        foreach ($f in $files) {
            $ok = $false
            for ($try = 0; $try -lt 5 -and -not $ok; $try++) {
                try { Copy-Item (Join-Path $here $f) $dest -Force -ErrorAction Stop; $ok = $true }
                catch { if ($try -eq 4) { throw "Could not replace $f in $dest ($($_.Exception.Message))" }; Start-Sleep -Milliseconds 700 }
            }
        }
        Get-ChildItem $dest | Unblock-File -ErrorAction SilentlyContinue

        Step 'Creating shortcuts...' 55
        if ($c.chkDesk.IsChecked) { New-Shortcut (Join-Path ([Environment]::GetFolderPath('Desktop')) 'bluFPS.lnk') $dest }
        if ($c.chkMenu.IsChecked) { New-Shortcut (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\bluFPS.lnk') $dest }

        Step 'Registering with Windows (Settings > Apps)...' 80
        $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\bluFPS'
        New-Item $k -Force | Out-Null
        $vals = @{
            DisplayName = 'bluFPS'; DisplayVersion = $ver; Publisher = 'bluFPS'; InstallLocation = $dest
            DisplayIcon = "$dest\bluFPS.ico"
            UninstallString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$dest\Uninstall.ps1`""
        }
        foreach ($e in $vals.GetEnumerator()) { New-ItemProperty $k -Name $e.Key -Value $e.Value -PropertyType String -Force | Out-Null }
        New-ItemProperty $k -Name NoModify -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty $k -Name NoRepair -Value 1 -PropertyType DWord -Force | Out-Null

        Step "bluFPS $verShow is installed." 100
        $script:done = $true
        $c.btnInstall.Content = 'Finish'; $c.btnInstall.IsEnabled = $true
    } catch {
        $c.msg.Foreground = '#FF8A8A'; Step "Install failed: $($_.Exception.Message)" 0
        $c.btnInstall.IsEnabled = $true; $c.btnCancel.IsEnabled = $true; $c.path.IsEnabled = $true
    }
})

[void]$win.ShowDialog()
