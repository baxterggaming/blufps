# bluFPS - gaming optimizer for Windows (WPF UI, every change reversible)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $env:BLUFPS_HOME) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`""
    return
}
# folder that holds the app files (bluFPS.exe sets BLUFPS_HOME when it hosts the app)
$script:AppRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($env:BLUFPS_HOME) { $env:BLUFPS_HOME } else { (Get-Location).Path }

# ---------- animated startup splash ----------
$script:splash = $null; $script:splashT0 = Get-Date
function Pump-Early { [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{}) }
function Set-Splash($text) {
    if ($script:splash) { try { $script:splashStat.Text = $text; Pump-Early } catch {} }
}
function Start-Anim($target, $prop, $from, $to, $ms, $delay = 0, $ease = $null, $loop = $false, $rev = $false) {
    $a = New-Object Windows.Media.Animation.DoubleAnimation
    $a.From = $from; $a.To = $to
    $a.Duration = New-Object Windows.Duration ([TimeSpan]::FromMilliseconds($ms))
    $a.BeginTime = [TimeSpan]::FromMilliseconds($delay)
    if ($ease) { $a.EasingFunction = $ease }
    if ($loop) { $a.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever }
    if ($rev) { $a.AutoReverse = $true }
    $target.BeginAnimation($prop, $a)
}
function Finish-Splash {
    $spl = $script:splash
    if (-not $spl) { return }
    $script:splash = $null
    try {
        $left = 2300 - ((Get-Date) - $script:splashT0).TotalMilliseconds
        while ($left -gt 0) { Pump-Early; Start-Sleep -Milliseconds 25; $left = 2300 - ((Get-Date) - $script:splashT0).TotalMilliseconds }
        $a = New-Object Windows.Media.Animation.DoubleAnimation
        $a.From = 1; $a.To = 0; $a.Duration = New-Object Windows.Duration ([TimeSpan]::FromMilliseconds(450))
        $script:splashClosing = $spl
        $a.Add_Completed({ try { $script:splashClosing.Close() } catch {} })
        $spl.BeginAnimation([Windows.UIElement]::OpacityProperty, $a)
    } catch { try { $spl.Close() } catch {} }
}
if ($env:BLUFPS_ARGS -notmatch '/minimized') {
    try {
        $spx = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize" ShowInTaskbar="False" Topmost="True"
        WindowStartupLocation="CenterScreen" Width="560" Height="520" Title="bluFPS"
        FontFamily="Segoe UI Variable Display, Segoe UI" Foreground="White">
  <Grid Margin="30">
    <Border x:Name="card" CornerRadius="22" BorderThickness="1" BorderBrush="#402F7BFF" Opacity="0">
      <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#070B18" Offset="0"/><GradientStop Color="#0D1A42" Offset="1"/></LinearGradientBrush>
      </Border.Background>
      <Border.Effect><DropShadowEffect Color="#2F7BFF" BlurRadius="40" ShadowDepth="0" Opacity="0.55"/></Border.Effect>
      <Grid>
        <Ellipse x:Name="glow" Width="320" Height="320" VerticalAlignment="Top" Margin="0,10,0,0" IsHitTestVisible="False" Opacity="0.35">
          <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#662F7BFF" Offset="0"/><GradientStop Color="#002F7BFF" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
        </Ellipse>
        <Grid x:Name="ringWrap" Width="196" Height="196" VerticalAlignment="Top" Margin="0,62,0,0" RenderTransformOrigin="0.5,0.5" Opacity="0">
          <Grid.RenderTransform><RotateTransform x:Name="spin" Angle="0"/></Grid.RenderTransform>
          <Ellipse Stroke="#4DA3FF" StrokeThickness="3" StrokeDashArray="5 12" StrokeDashCap="Round"/>
        </Grid>
        <Image x:Name="logo" Width="150" Height="150" VerticalAlignment="Top" Margin="0,85,0,0" RenderTransformOrigin="0.5,0.5" Opacity="0" RenderOptions.BitmapScalingMode="HighQuality">
          <Image.RenderTransform><ScaleTransform x:Name="logoScale" ScaleX="0.45" ScaleY="0.45"/></Image.RenderTransform>
        </Image>
        <StackPanel VerticalAlignment="Bottom" Margin="44,0,44,34">
          <TextBlock x:Name="title" HorizontalAlignment="Center" FontSize="34" FontWeight="Bold" Opacity="0">
            <TextBlock.RenderTransform><TranslateTransform x:Name="titleMove" Y="16"/></TextBlock.RenderTransform>
            <Run Text="blu" Foreground="#4DA3FF"/><Run Text="FPS"/>
          </TextBlock>
          <TextBlock x:Name="tag" Text="GAMING OPTIMIZER" HorizontalAlignment="Center" FontSize="11" Foreground="#6C7CA3" Opacity="0" Margin="0,2,0,18"/>
          <Border Height="4" CornerRadius="2" Background="#1B2750" ClipToBounds="True">
            <Border x:Name="bar" Width="130" HorizontalAlignment="Left" CornerRadius="2">
              <Border.Background><LinearGradientBrush><GradientStop Color="#002F7BFF" Offset="0"/><GradientStop Color="#2F7BFF" Offset="0.5"/><GradientStop Color="#0056CCF2" Offset="1"/></LinearGradientBrush></Border.Background>
              <Border.RenderTransform><TranslateTransform x:Name="barMove" X="-130"/></Border.RenderTransform>
            </Border>
          </Border>
          <TextBlock x:Name="stat" Text="Starting up..." HorizontalAlignment="Center" FontSize="12" Foreground="#6C7CA3" Margin="0,10,0,0"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
'@
        $spl = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml]$spx))
        $e = @{}
        foreach ($n in 'card', 'logo', 'logoScale', 'spin', 'ringWrap', 'glow', 'title', 'titleMove', 'tag', 'barMove', 'stat') { $e[$n] = $spl.FindName($n) }
        $logoFile = Join-Path $script:AppRoot 'bluFPS.png'
        if (Test-Path $logoFile) {
            $bm = New-Object Windows.Media.Imaging.BitmapImage
            $bm.BeginInit(); $bm.UriSource = New-Object Uri $logoFile; $bm.CacheOption = 'OnLoad'; $bm.EndInit()
            $e.logo.Source = $bm
        }
        $script:splashStat = $e.stat
        $script:splash = $spl
        $spl.Show(); Pump-Early
        $op = [Windows.UIElement]::OpacityProperty
        $easeOut = New-Object Windows.Media.Animation.CubicEase -Property @{ EasingMode = 'EaseOut' }
        $easeBack = New-Object Windows.Media.Animation.BackEase -Property @{ EasingMode = 'EaseOut'; Amplitude = 0.45 }
        $easeSine = New-Object Windows.Media.Animation.SineEase -Property @{ EasingMode = 'EaseInOut' }
        Start-Anim $e.card $op 0 1 350 0 $easeOut
        Start-Anim $e.logo $op 0 1 600 150 $easeOut
        Start-Anim $e.logoScale ([Windows.Media.ScaleTransform]::ScaleXProperty) 0.45 1 950 150 $easeBack
        Start-Anim $e.logoScale ([Windows.Media.ScaleTransform]::ScaleYProperty) 0.45 1 950 150 $easeBack
        Start-Anim $e.ringWrap $op 0 1 700 400 $easeOut
        Start-Anim $e.spin ([Windows.Media.RotateTransform]::AngleProperty) 0 360 3200 0 $null $true
        Start-Anim $e.glow $op 0.35 1 1200 0 $easeSine $true $true
        Start-Anim $e.title $op 0 1 600 750 $easeOut
        Start-Anim $e.titleMove ([Windows.Media.TranslateTransform]::YProperty) 16 0 600 750 $easeOut
        Start-Anim $e.tag $op 0 1 500 1050 $easeOut
        Start-Anim $e.barMove ([Windows.Media.TranslateTransform]::XProperty) -130 430 1300 0 $easeSine $true
    } catch { $script:splash = $null }
}

# ---------- fast native helper (compiled in the background while the splash plays) ----------
$script:nativeOk = $null
$script:nativeCode = @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
namespace Blu {
    public static class Native {
        [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool CloseHandle(IntPtr h);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool QueryFullProcessImageName(IntPtr h, int flags, StringBuilder sb, ref int size);
        [DllImport("psapi.dll", SetLastError = true)] private static extern bool EmptyWorkingSet(IntPtr h);
        public static string GetPath(int pid) {
            IntPtr h = OpenProcess(0x1000, false, pid);
            if (h == IntPtr.Zero) return null;
            try {
                StringBuilder sb = new StringBuilder(1024);
                int n = sb.Capacity;
                if (QueryFullProcessImageName(h, 0, sb, ref n)) return sb.ToString();
                return null;
            } finally { CloseHandle(h); }
        }
        public static void Trim(int pid) {
            IntPtr h = OpenProcess(0x0500, false, pid);
            if (h == IntPtr.Zero) return;
            try { EmptyWorkingSet(h); } finally { CloseHandle(h); }
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct IO_COUNTERS { public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; }
        [DllImport("kernel32.dll")] private static extern bool GetProcessIoCounters(IntPtr h, out IO_COUNTERS c);
        public static ulong IoBytes(int pid) {
            IntPtr h = OpenProcess(0x1000, false, pid);
            if (h == IntPtr.Zero) return 0;
            try { IO_COUNTERS c; if (GetProcessIoCounters(h, out c)) return c.ReadBytes + c.WriteBytes; return 0; }
            finally { CloseHandle(h); }
        }
        private static bool ExtOk(string name, string[] exts) {
            if (exts == null || exts.Length == 0) return true;
            string e = Path.GetExtension(name);
            foreach (string x in exts) { if (string.Equals(e, x, StringComparison.OrdinalIgnoreCase)) return true; }
            return false;
        }
        private static void Walk(DirectoryInfo dir, int olderDays, string[] exts, bool delete, ref long total) {
            DateTime cutoff = DateTime.UtcNow.AddDays(-olderDays);
            FileInfo[] files = null;
            try { files = dir.GetFiles(); } catch (Exception) { return; }
            foreach (FileInfo f in files) {
                try {
                    if (!ExtOk(f.Name, exts)) continue;
                    if (olderDays > 0 && f.LastWriteTimeUtc > cutoff) continue;
                    long len = f.Length;
                    if (delete) { f.Attributes = FileAttributes.Normal; f.Delete(); }
                    total += len;
                } catch (Exception) { }
            }
            DirectoryInfo[] subs = null;
            try { subs = dir.GetDirectories(); } catch (Exception) { return; }
            foreach (DirectoryInfo d in subs) {
                try {
                    if ((d.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    Walk(d, olderDays, exts, delete, ref total);
                    if (delete && exts == null) { try { d.Delete(false); } catch (Exception) { } }
                } catch (Exception) { }
            }
        }
        // size (delete=false) or remove (delete=true) the files inside the given folders; skips links, never touches the folders' parents
        public static long Many(string[] paths, int olderDays, string extList, bool delete) {
            string[] exts = null;
            if (!string.IsNullOrEmpty(extList)) exts = extList.Split(';');
            long total = 0;
            foreach (string p in paths) {
                try {
                    if (string.IsNullOrEmpty(p) || p.Length < 10 || Path.GetPathRoot(p) == p) continue;
                    if (Directory.Exists(p)) Walk(new DirectoryInfo(p), olderDays, exts, delete, ref total);
                } catch (Exception) { }
            }
            return total;
        }
    }
}
'@
try {
    $script:nativePs = [powershell]::Create()
    [void]$script:nativePs.AddScript('param($code) Add-Type -TypeDefinition $code -Language CSharp').AddArgument($script:nativeCode)
    $script:nativeAr = $script:nativePs.BeginInvoke()
} catch { $script:nativeAr = $null }
function Test-Native {
    if ($null -ne $script:nativeOk) { return $script:nativeOk }
    if ($script:nativeAr) {
        [void]$script:nativeAr.AsyncWaitHandle.WaitOne(10000)
        try { [void]$script:nativePs.EndInvoke($script:nativeAr) } catch {}
        try { $script:nativePs.Dispose() } catch {}
        $script:nativeAr = $null
    }
    $script:nativeOk = [bool]('Blu.Native' -as [type])
    $script:nativeOk
}

$script:powerCode = @'
using System;
using System.Runtime.InteropServices;
namespace Blu {
    public static class Power {
        [StructLayout(LayoutKind.Sequential)] private struct THROTTLE { public uint Version; public uint ControlMask; public uint StateMask; }
        [StructLayout(LayoutKind.Sequential)] private struct MEMPRI { public uint Priority; }
        [StructLayout(LayoutKind.Sequential, Pack = 1)] private struct TOKPRIV { public int Count; public long Luid; public int Attr; }
        [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool CloseHandle(IntPtr h);
        [DllImport("kernel32.dll")] private static extern IntPtr GetCurrentProcess();
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetProcessInformation(IntPtr h, int cls, ref THROTTLE info, int size);
        [DllImport("kernel32.dll", SetLastError = true, EntryPoint = "SetProcessInformation")] private static extern bool SetMemInformation(IntPtr h, int cls, ref MEMPRI info, int size);
        [DllImport("ntdll.dll")] private static extern int NtSetInformationProcess(IntPtr h, int cls, ref int info, int size);
        [DllImport("ntdll.dll")] private static extern int NtSetSystemInformation(int cls, ref int info, int size);
        [DllImport("advapi32.dll", SetLastError = true)] private static extern bool OpenProcessToken(IntPtr p, uint access, out IntPtr token);
        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool LookupPrivilegeValue(string sys, string name, out long luid);
        [DllImport("advapi32.dll", SetLastError = true)] private static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TOKPRIV n, int len, IntPtr prev, IntPtr retLen);

        // Efficiency mode (EcoQoS): background work moves to efficient cores / lower clocks. on=false hands control back to Windows.
        public static bool Eco(int pid, bool on) {
            IntPtr h = OpenProcess(0x0200, false, pid);
            if (h == IntPtr.Zero) return false;
            try { THROTTLE t = new THROTTLE(); t.Version = 1; t.ControlMask = on ? 1u : 0u; t.StateMask = on ? 1u : 0u; return SetProcessInformation(h, 4, ref t, 12); }
            finally { CloseHandle(h); }
        }
        // Protect the game: power throttling explicitly OFF.
        public static bool NoThrottle(int pid) {
            IntPtr h = OpenProcess(0x0200, false, pid);
            if (h == IntPtr.Zero) return false;
            try { THROTTLE t = new THROTTLE(); t.Version = 1; t.ControlMask = 1; t.StateMask = 0; return SetProcessInformation(h, 4, ref t, 12); }
            finally { CloseHandle(h); }
        }
        // I/O priority: 0 = very low, 2 = normal
        public static bool IoPrio(int pid, int level) {
            IntPtr h = OpenProcess(0x0200, false, pid);
            if (h == IntPtr.Zero) return false;
            try { int v = level; return NtSetInformationProcess(h, 33, ref v, 4) == 0; }
            finally { CloseHandle(h); }
        }
        // Memory priority: 1 = lowest, 5 = normal
        public static bool MemPrio(int pid, int level) {
            IntPtr h = OpenProcess(0x0200, false, pid);
            if (h == IntPtr.Zero) return false;
            try { MEMPRI m = new MEMPRI(); m.Priority = (uint)level; return SetMemInformation(h, 0, ref m, 4); }
            finally { CloseHandle(h); }
        }
        private static bool Priv(string name) {
            IntPtr tok;
            if (!OpenProcessToken(GetCurrentProcess(), 0x28, out tok)) return false;
            try {
                long luid;
                if (!LookupPrivilegeValue(null, name, out luid)) return false;
                TOKPRIV tp = new TOKPRIV(); tp.Count = 1; tp.Luid = luid; tp.Attr = 2;
                AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                return true;
            } finally { CloseHandle(tok); }
        }
        [DllImport("gdi32.dll")] private static extern int D3DKMTSetProcessSchedulingPriorityClass(IntPtr hProcess, int priorityClass);
        // GPU scheduling priority class: 1 = below normal, 2 = normal, 4 = high
        public static bool GpuPrio(int pid, int cls) {
            IntPtr h = OpenProcess(0x1F0FFF, false, pid);
            if (h == IntPtr.Zero) return false;
            try { return D3DKMTSetProcessSchedulingPriorityClass(h, cls) == 0; }
            catch (Exception) { return false; }
            finally { CloseHandle(h); }
        }
        // Empties the standby list and flushes modified pages: cures stutter when memory looks free but is full of stale cache.
        public static bool Purge() {
            if (!Priv("SeProfileSingleProcessPrivilege")) return false;
            int a = 4; int b = 3;
            int r1 = NtSetSystemInformation(80, ref a, 4);
            int r2 = NtSetSystemInformation(80, ref b, 4);
            return r1 == 0 || r2 == 0;
        }
    }
}
'@
$script:powerOk = $null
try {
    $script:powerPs = [powershell]::Create()
    [void]$script:powerPs.AddScript('param($code) Add-Type -TypeDefinition $code -Language CSharp').AddArgument($script:powerCode)
    $script:powerAr = $script:powerPs.BeginInvoke()
} catch { $script:powerAr = $null }
function Test-Power {
    if ($null -ne $script:powerOk) { return $script:powerOk }
    if ($script:powerAr) {
        [void]$script:powerAr.AsyncWaitHandle.WaitOne(10000)
        try { [void]$script:powerPs.EndInvoke($script:powerAr) } catch {}
        try { $script:powerPs.Dispose() } catch {}
        $script:powerAr = $null
    }
    $script:powerOk = [bool]('Blu.Power' -as [type])
    $script:powerOk
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="bluFPS" Width="980" Height="660" WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="CanMinimize"
        FontFamily="Segoe UI Variable Display, Segoe UI" Foreground="White">
  <Window.Background>
    <LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#070B18" Offset="0"/><GradientStop Color="#0C1738" Offset="1"/></LinearGradientBrush>
  </Window.Background>
  <Window.Resources>
    <Style x:Key="Nav" TargetType="Button">
      <Setter Property="Foreground" Value="#8FA2CC"/><Setter Property="Height" Value="44"/><Setter Property="FontSize" Value="14"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Grid Margin="10,2">
          <Border x:Name="bg" CornerRadius="10" Background="Transparent"/>
          <Border x:Name="bar" Width="3" Height="20" CornerRadius="2" Background="#4DA3FF" HorizontalAlignment="Left" Visibility="Collapsed"/>
          <ContentPresenter VerticalAlignment="Center" Margin="16,0,0,0"/>
        </Grid>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bg" Property="Background" Value="#141E3E"/></Trigger>
          <Trigger Property="Tag" Value="on"><Setter TargetName="bg" Property="Background" Value="#1A2755"/><Setter TargetName="bar" Property="Visibility" Value="Visible"/><Setter Property="Foreground" Value="White"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Background" Value="#182452"/><Setter Property="BorderBrush" Value="#2A3A6B"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Foreground" Value="White"/><Setter Property="FontSize" Value="13"/><Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="20,10"/><Setter Property="Margin" Value="0,0,10,0"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="TextBlock.TextAlignment" Value="Center"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.82"/></Trigger></ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Go" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Background"><Setter.Value><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#2F7BFF" Offset="0"/><GradientStop Color="#7A5CFF" Offset="1"/></LinearGradientBrush></Setter.Value></Setter>
      <Setter Property="Effect"><Setter.Value><DropShadowEffect Color="#2F7BFF" BlurRadius="20" ShadowDepth="0" Opacity="0.45"/></Setter.Value></Setter>
    </Style>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="#111A33"/><Setter Property="BorderBrush" Value="#1F2C55"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="14"/><Setter Property="Padding" Value="18"/><Setter Property="Margin" Value="0,0,14,14"/>
      <Setter Property="Effect"><Setter.Value><DropShadowEffect Color="#000000" Opacity="0.35" BlurRadius="18" ShadowDepth="3" Direction="270"/></Setter.Value></Setter>
    </Style>
    <Style x:Key="Title" TargetType="TextBlock"><Setter Property="FontSize" Value="26"/><Setter Property="FontWeight" Value="Bold"/></Style>
    <Style x:Key="Sub" TargetType="TextBlock"><Setter Property="FontSize" Value="13"/><Setter Property="Foreground" Value="#7E90BC"/><Setter Property="Margin" Value="0,2,0,16"/><Setter Property="TextWrapping" Value="Wrap"/></Style>
    <Style x:Key="Lbl" TargetType="TextBlock"><Setter Property="FontSize" Value="11"/><Setter Property="Foreground" Value="#6C7CA3"/></Style>
    <Style x:Key="Val" TargetType="TextBlock"><Setter Property="FontSize" Value="32"/><Setter Property="FontWeight" Value="Bold"/></Style>
    <Style TargetType="ProgressBar">
      <Setter Property="Height" Value="6"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ProgressBar">
        <Grid><Border Background="#1B2750" CornerRadius="3"/><Border x:Name="PART_Track"/>
          <Border x:Name="PART_Indicator" HorizontalAlignment="Left" CornerRadius="3">
            <Border.Background><LinearGradientBrush><GradientStop Color="#2F7BFF" Offset="0"/><GradientStop Color="#56CCF2" Offset="1"/></LinearGradientBrush></Border.Background></Border>
        </Grid>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox">
        <StackPanel Orientation="Horizontal" Background="Transparent">
          <Grid Width="42" Height="22" Margin="0,0,14,0" VerticalAlignment="Center">
            <Border x:Name="track" CornerRadius="11" Background="#26345F"/>
            <Ellipse x:Name="knob" Width="16" Height="16" Fill="White" HorizontalAlignment="Left" Margin="3,0,0,0"/>
          </Grid>
          <ContentPresenter VerticalAlignment="Center"/>
        </StackPanel>
        <ControlTemplate.Triggers>
          <Trigger Property="IsChecked" Value="True"><Setter TargetName="track" Property="Background" Value="#2F7BFF"/><Setter TargetName="knob" Property="HorizontalAlignment" Value="Right"/><Setter TargetName="knob" Property="Margin" Value="0,0,3,0"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="LB" TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="#C8D3F0"/><Setter Property="Padding" Value="12,8"/><Setter Property="Margin" Value="0,0,0,4"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem">
        <Border x:Name="b" Background="#16203F" CornerRadius="8" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#1D2A52"/></Trigger>
          <Trigger Property="IsSelected" Value="True"><Setter TargetName="b" Property="Background" Value="#2F7BFF"/><Setter Property="Foreground" Value="White"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
  </Window.Resources>
  <Border x:Name="rootBorder" BorderBrush="#22315C" BorderThickness="1">
  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <Ellipse Grid.Column="1" Width="460" Height="460" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,-200,-140,0" IsHitTestVisible="False">
      <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#442F7BFF" Offset="0"/><GradientStop Color="#002F7BFF" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
    </Ellipse>
    <Border Background="#CC080D1E" BorderBrush="#18244A" BorderThickness="0,0,1,0">
      <DockPanel>
        <TextBlock x:Name="verText" DockPanel.Dock="Bottom" Text="v1.1.9" Style="{StaticResource Lbl}" Cursor="Hand" ToolTip="Click to see what is new" Margin="26,0,0,18"/>
        <StackPanel>
          <StackPanel Orientation="Horizontal" Margin="24,28,0,30">
            <Image x:Name="logoImg" Width="52" Height="52" RenderOptions.BitmapScalingMode="HighQuality"><Image.Effect><DropShadowEffect Color="#2F7BFF" BlurRadius="16" ShadowDepth="0" Opacity="0.6"/></Image.Effect></Image>
            <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock FontSize="22" FontWeight="Bold"><Run Text="blu" Foreground="#4DA3FF"/><Run Text="FPS"/></TextBlock>
              <TextBlock Text="GAMING OPTIMIZER" Style="{StaticResource Lbl}" FontSize="9"/>
            </StackPanel>
          </StackPanel>
          <TextBlock Text="MENU" Style="{StaticResource Lbl}" FontSize="10" Margin="26,0,0,8"/>
          <Button x:Name="navDash" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE80F;" FontSize="16" Width="32"/><TextBlock Text="Dashboard"/></StackPanel></Button>
          <Button x:Name="navBoost" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE945;" FontSize="16" Width="32"/><TextBlock Text="Boost"/></StackPanel></Button>
          <Button x:Name="navGame" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7FC;" FontSize="16" Width="32"/><TextBlock Text="Games"/></StackPanel></Button>
          <Button x:Name="navNet" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE774;" FontSize="16" Width="32"/><TextBlock Text="Network"/></StackPanel></Button>
          <Button x:Name="navApps" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE71D;" FontSize="16" Width="32"/><TextBlock Text="Apps"/></StackPanel></Button>
          <Button x:Name="navTools" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE90F;" FontSize="16" Width="32"/><TextBlock Text="Tools"/></StackPanel></Button>
          <Button x:Name="navPerf" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE9D9;" FontSize="16" Width="32"/><TextBlock Text="Performance"/></StackPanel></Button>
          <Button x:Name="navUpd" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE895;" FontSize="16" Width="32"/><TextBlock Text="Updates"/></StackPanel></Button>
          <Button x:Name="navSet" Style="{StaticResource Nav}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE713;" FontSize="16" Width="32"/><TextBlock Text="Settings"/></StackPanel></Button>
        </StackPanel>
      </DockPanel>
    </Border>
    <Grid Grid.Column="1">
      <Grid.RowDefinitions><RowDefinition Height="40"/><RowDefinition Height="*"/><RowDefinition Height="32"/></Grid.RowDefinitions>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="btnMin" Style="{StaticResource Btn}" Background="Transparent" BorderThickness="0" Padding="18,8" Margin="0" FontFamily="Segoe MDL2 Assets" FontSize="10" Content="&#xE921;"/>
        <Button x:Name="btnX" Style="{StaticResource Btn}" Background="Transparent" BorderThickness="0" Padding="18,8" Margin="0" FontFamily="Segoe MDL2 Assets" FontSize="10" Content="&#xE8BB;"/>
      </StackPanel>
      <Grid Grid.Row="1" Margin="30,6,16,4">
        <!-- Dashboard -->
        <Grid x:Name="pgDash">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Dashboard" Style="{StaticResource Title}"/><TextBlock x:Name="sysInfo" Style="{StaticResource Sub}"/>
            <Border x:Name="updBanner" Visibility="Collapsed" Background="#17306B" BorderBrush="#2F7BFF" BorderThickness="1" CornerRadius="10" Padding="14,8" Margin="0,-4,14,12">
              <DockPanel><Button x:Name="btnBannerUpd" DockPanel.Dock="Right" Style="{StaticResource Go}" Padding="14,5" Margin="12,0,0,0" Content="Update..."/>
                <TextBlock x:Name="updBannerText" VerticalAlignment="Center" FontSize="13"/></DockPanel>
            </Border></StackPanel>
          <UniformGrid Grid.Row="1" Columns="4">
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="CPU LOAD" Style="{StaticResource Lbl}"/><TextBlock x:Name="valCpu" Text="--" Style="{StaticResource Val}" Margin="0,4,0,12"/><ProgressBar x:Name="barCpu" Maximum="100"/></StackPanel></Border>
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="MEMORY" Style="{StaticResource Lbl}"/><TextBlock x:Name="valRam" Text="--" Style="{StaticResource Val}" Margin="0,4,0,12"/><ProgressBar x:Name="barRam" Maximum="100"/></StackPanel></Border>
            <Border Style="{StaticResource Card}"><StackPanel>
              <TextBlock Text="GAME PING" Style="{StaticResource Lbl}"/>
              <StackPanel Orientation="Horizontal" Margin="0,4,0,0"><TextBlock x:Name="valPing" Text="--" Style="{StaticResource Val}"/><TextBlock x:Name="pingNote" Style="{StaticResource Lbl}" VerticalAlignment="Bottom" Margin="8,0,0,8"/></StackPanel>
              <Canvas x:Name="spark" Height="34" Margin="0,6,0,0" ClipToBounds="True"><Polyline x:Name="sparkLine" Stroke="#4DA3FF" StrokeThickness="2" StrokeLineJoin="Round"/></Canvas>
              <TextBlock x:Name="pingSrc" Style="{StaticResource Lbl}" FontSize="10" TextTrimming="CharacterEllipsis" Margin="0,6,0,0" Text="measuring..."/>
            </StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel><TextBlock Text="BOOST STATUS" Style="{StaticResource Lbl}"/><TextBlock x:Name="valBoost" Text="OFF" Style="{StaticResource Val}" Margin="0,4,0,2"/><TextBlock Text="tweaks active" Style="{StaticResource Lbl}"/></StackPanel></Border>
          </UniformGrid>
          <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,14,0">
            <DockPanel>
              <Button x:Name="btnBoost" DockPanel.Dock="Left" Style="{StaticResource Go}" Width="220" FontSize="20" FontWeight="Bold" Margin="0,0,20,0" Content="BOOST NOW"/>
              <DockPanel>
                <TextBlock DockPanel.Dock="Top" Text="ACTIVITY" Style="{StaticResource Lbl}" Margin="0,0,0,6"/>
                <TextBox x:Name="log" IsReadOnly="True" Background="#0B1226" Foreground="#7EE0A8" BorderThickness="0" FontFamily="Consolas" FontSize="12" Padding="12" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
              </DockPanel>
            </DockPanel>
          </Border>
        </Grid>
        <!-- Boost -->
        <Grid x:Name="pgBoost" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Boost" Style="{StaticResource Title}"/><TextBlock Text="Switch on the tweaks you want, then apply. Everything can be reverted." Style="{StaticResource Sub}"/></StackPanel>
          <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,14,14"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="tweakPanel"/></ScrollViewer></Border>
          <StackPanel Grid.Row="2" Orientation="Horizontal">
            <Button x:Name="btnApply" Style="{StaticResource Go}" Content="Apply selected"/>
            <Button x:Name="btnRevert" Style="{StaticResource Btn}" Content="Revert all"/>
          </StackPanel>
        </Grid>
        <!-- Game -->
        <Grid x:Name="pgGame" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Games" Style="{StaticResource Title}"/><TextBlock Text="Pick a game and press Boost and Play. bluFPS frees up your PC, launches the game, and puts everything back when you quit." Style="{StaticResource Sub}" Margin="0,2,0,12"/></StackPanel>
          <StackPanel Grid.Row="1" Margin="0,0,14,12">
            <DockPanel>
              <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" Margin="10,0,0,0">
                <Button x:Name="btnGameScan" Style="{StaticResource Btn}" Padding="14,7" Content="Rescan"/>
                <Button x:Name="btnGameFolder" Style="{StaticResource Btn}" Padding="14,7" Content="Scan a folder..."/>
                <Button x:Name="btnGameAdd" Style="{StaticResource Btn}" Padding="14,7" Margin="0" Content="Add games..."/>
              </StackPanel>
              <TextBox x:Name="gameSearch" Background="#0B1226" Foreground="White" CaretBrush="White" BorderBrush="#2A3A6B" Padding="10,7" FontSize="13" ToolTip="Search your games"/>
            </DockPanel>
            <ProgressBar x:Name="scanBar" Height="4" Margin="0,8,0,0" Minimum="0" Maximum="100" Foreground="#2F7BFF" Background="#16224A" BorderThickness="0" Visibility="Collapsed"/>
            <TextBlock x:Name="scanText" Style="{StaticResource Sub}" Margin="0,6,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
          </StackPanel>
          <Grid Grid.Row="2" Margin="0,0,14,14">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="310"/></Grid.ColumnDefinitions>
            <Border Style="{StaticResource Card}" Margin="0,0,14,0">
              <DockPanel>
                <TextBlock x:Name="gameCount" DockPanel.Dock="Bottom" Style="{StaticResource Lbl}" Margin="0,8,0,0" TextWrapping="Wrap"/>
                <ListBox x:Name="gameList" Background="Transparent" BorderThickness="0" ItemContainerStyle="{StaticResource LB}" ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
              </DockPanel>
            </Border>
            <Border Grid.Column="1" Style="{StaticResource Card}" Margin="0">
              <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel>
                <Border x:Name="gameHero" Height="152" CornerRadius="10" Margin="0,0,0,10" Background="#16203F">
                  <TextBlock x:Name="gameHeroText" HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" FontSize="18" FontWeight="Bold" Foreground="#7FB2FF" Margin="12"/>
                </Border>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,12">
                  <Button x:Name="btnGameArt" Style="{StaticResource Btn}" Padding="12,5" FontSize="11" Content="Change picture..."/>
                  <Button x:Name="btnGameArtReset" Style="{StaticResource Btn}" Padding="12,5" Margin="0" FontSize="11" Content="Reset picture"/>
                </StackPanel>
                <TextBlock x:Name="gameName" Text="Pick a game" FontSize="20" FontWeight="Bold" TextWrapping="Wrap"/>
                <TextBlock x:Name="gameSrc" Style="{StaticResource Lbl}" FontSize="12" Foreground="#4DA3FF" Margin="0,2,0,0"/>
                <TextBlock x:Name="gamePathTxt" Style="{StaticResource Lbl}" Margin="0,4,0,14" TextWrapping="Wrap"/>
                <TextBlock Text="WHEN YOU BOOST" Style="{StaticResource Lbl}"/>
                <TextBlock x:Name="gamePlan" Foreground="#C8D3F0" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,16"/>
                <Button x:Name="btnPlay" Style="{StaticResource Go}" FontSize="16" FontWeight="Bold" Padding="0,14" Margin="0,0,0,10" Content="BOOST AND PLAY"/>
                <Button x:Name="btnBoostOnly" Style="{StaticResource Btn}" Margin="0,0,0,10" Content="Boost (game already running)"/>
                <Button x:Name="btnRestore" Style="{StaticResource Btn}" Visibility="Collapsed" Margin="0,0,0,10" Content="Restore my PC now"/>
                <Button x:Name="btnGameProfile" Style="{StaticResource Btn}" Visibility="Collapsed" Margin="0,0,0,10" Content="Profile for this game"/>
                <Button x:Name="btnLocate" Style="{StaticResource Btn}" Visibility="Collapsed" Margin="0,0,0,10" Content="Locate game .exe..."/>
                <Button x:Name="btnOpenDir" Style="{StaticResource Btn}" Visibility="Collapsed" Margin="0,0,0,10" Content="Open game folder"/>
                <Button x:Name="btnRemoveGame" Style="{StaticResource Btn}" Visibility="Collapsed" Margin="0,0,0,10" Content="Remove from list"/>
                <TextBlock x:Name="gameNet" Style="{StaticResource Lbl}" FontSize="12" Foreground="#4DA3FF" TextWrapping="Wrap" Margin="0,0,0,6" Text="Live server ping: boost a game to see it here"/>
                <TextBlock x:Name="sessState" Style="{StaticResource Lbl}" FontSize="12" TextWrapping="Wrap" Text="No boost active."/>
              </StackPanel></ScrollViewer>
            </Border>
          </Grid>
        </Grid>
        <!-- Network -->
        <Grid x:Name="pgNet" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Network" Style="{StaticResource Title}"/><TextBlock Text="Game regions tests the cloud regions most online games run on. Pick the closest one in your game settings." Style="{StaticResource Sub}" Margin="0,2,0,12"/></StackPanel>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,12">
            <Button x:Name="btnRegions" Style="{StaticResource Go}" Content="Test game regions"/>
            <Button x:Name="btnPing" Style="{StaticResource Btn}" Content="Test DNS providers"/>
            <Button x:Name="btnFlush" Style="{StaticResource Btn}" Content="Flush DNS"/>
          </StackPanel>
          <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,14,14">
            <TextBox x:Name="pingOut" IsReadOnly="True" Background="Transparent" Foreground="#DCE6FF" BorderThickness="0" FontFamily="Consolas" FontSize="13" VerticalScrollBarVisibility="Auto"/>
          </Border>
          <StackPanel Grid.Row="3" Margin="0,0,0,8">
            <TextBlock Text="DNS SERVER (applies to active connections)" Style="{StaticResource Lbl}" Margin="0,0,0,6"/>
            <StackPanel Orientation="Horizontal">
              <Button x:Name="dnsCf" Style="{StaticResource Btn}" Content="Cloudflare 1.1.1.1"/>
              <Button x:Name="dnsGg" Style="{StaticResource Btn}" Content="Google 8.8.8.8"/>
              <Button x:Name="dnsAuto" Style="{StaticResource Btn}" Content="Automatic"/>
            </StackPanel>
          </StackPanel>
        </Grid>
        <!-- Settings -->
        <Grid x:Name="pgSet" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Settings" Style="{StaticResource Title}"/><TextBlock Text="Choose what a game boost does. Changes save automatically." Style="{StaticResource Sub}"/>
            <StackPanel Orientation="Horizontal" Margin="0,0,0,12"><TextBlock Text="PROFILE" Style="{StaticResource Lbl}" VerticalAlignment="Center" Margin="0,0,10,0"/>
              <Button x:Name="btnLvAuto" Style="{StaticResource Btn}" Padding="14,6" Content="Auto" ToolTip="Recommended. bluFPS chooses the tweaks for your hardware and each game (using your last Analyze result), and skips tweaks your PC cannot benefit from. Changing a switch below switches to manual (Custom)."/><Button x:Name="btnLvLight" Style="{StaticResource Btn}" Padding="14,6" Content="Balanced" ToolTip="Safe everyday: power plan, Game Mode, High priority for the game, quiet notifications, DNS flush."/><Button x:Name="btnLvBal" Style="{StaticResource Btn}" Padding="14,6" Content="Performance" ToolTip="Balanced plus: lower priority and efficiency mode for other apps, ProBalance, scheduler and GPU priority for the game, memory pressure relief."/><Button x:Name="btnLvMax" Style="{StaticResource Go}" Padding="14,6" Margin="0" Content="Extreme" ToolTip="Performance plus: politely close chosen background apps, pause Windows Search and telemetry, free RAM when nearly full. Everything is reversible; security features are never touched."/></StackPanel></StackPanel>
          <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,14,14">
            <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel>
              <StackPanel x:Name="setPanel"/>
              <TextBlock Text="ADD AN APP TO CLOSE  (its process name, for example Discord)" Style="{StaticResource Lbl}" Margin="0,14,0,6"/>
              <DockPanel>
                <Button x:Name="btnKillAdd" DockPanel.Dock="Right" Style="{StaticResource Btn}" Padding="16,8" Margin="8,0,0,0" Content="Add"/>
                <TextBox x:Name="killAdd" Background="#0B1226" Foreground="White" CaretBrush="White" BorderBrush="#2A3A6B" Padding="10,8" FontSize="13"/>
              </DockPanel>
              <TextBlock Text="DATA" Style="{StaticResource Lbl}" Margin="0,26,0,8"/>
              <StackPanel Orientation="Horizontal">
                <Button x:Name="btnSetReset" Style="{StaticResource Btn}" Content="Reset settings"/>
                <Button x:Name="btnOpenData" Style="{StaticResource Btn}" Content="Open data folder"/>
              </StackPanel>
            </StackPanel></ScrollViewer>
          </Border>
        </Grid>
        <!-- Performance -->
        <Grid x:Name="pgPerf" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Performance" Style="{StaticResource Title}"/><TextBlock Text="Understand your PC, see real frame rates, and test whether bluFPS actually helps. Nothing here is estimated." Style="{StaticResource Sub}" Margin="0,2,0,12" TextWrapping="Wrap"/></StackPanel>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"><StackPanel Margin="0,0,14,14">
            <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel>
              <TextBlock Text="YOUR PC AND WHAT LIMITS IT" Style="{StaticResource Lbl}"/>
              <TextBlock x:Name="perfHw" Text="Press Analyze to read your hardware and find what limits your frame rate. For the real answer, start a game first." Foreground="White" FontSize="13" TextWrapping="Wrap" Margin="0,8,0,10"/>
              <WrapPanel><Button x:Name="btnAnalyze" Style="{StaticResource Go}" Padding="14,7" Margin="0,0,8,8" Content="Analyze my PC"/><Button x:Name="btnApplyRec" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Visibility="Collapsed" Content="Apply recommended profile"/></WrapPanel>
              <ProgressBar x:Name="perfBar" Height="4" Minimum="0" Maximum="100" Foreground="#2F7BFF" Background="#16224A" BorderThickness="0" Visibility="Collapsed"/>
              <TextBlock x:Name="perfDiag" Style="{StaticResource Sub}" Margin="0,8,0,0" TextWrapping="Wrap"/>
            </StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel>
              <TextBlock Text="LIVE FRAME RATE" Style="{StaticResource Lbl}"/>
              <TextBlock x:Name="pmStatus" Style="{StaticResource Sub}" Margin="0,6,0,8" TextWrapping="Wrap"/>
              <WrapPanel Margin="0,0,0,4"><Border Style="{StaticResource Card}" Padding="14,10" Margin="0,0,10,10" MinWidth="118"><StackPanel><TextBlock Text="FPS NOW" Style="{StaticResource Lbl}"/><TextBlock x:Name="fpsCur" Text="--" FontSize="22" FontWeight="Bold" Foreground="White"/></StackPanel></Border><Border Style="{StaticResource Card}" Padding="14,10" Margin="0,0,10,10" MinWidth="118"><StackPanel><TextBlock Text="AVERAGE" Style="{StaticResource Lbl}"/><TextBlock x:Name="fpsAvg" Text="--" FontSize="22" FontWeight="Bold" Foreground="White"/></StackPanel></Border><Border Style="{StaticResource Card}" Padding="14,10" Margin="0,0,10,10" MinWidth="118"><StackPanel><TextBlock Text="1% LOW" Style="{StaticResource Lbl}"/><TextBlock x:Name="fpsLow" Text="--" FontSize="22" FontWeight="Bold" Foreground="White"/></StackPanel></Border><Border Style="{StaticResource Card}" Padding="14,10" Margin="0,0,10,10" MinWidth="118"><StackPanel><TextBlock Text="WORST FRAME FPS" Style="{StaticResource Lbl}"/><TextBlock x:Name="fpsMin" Text="--" FontSize="22" FontWeight="Bold" Foreground="White"/></StackPanel></Border><Border Style="{StaticResource Card}" Padding="14,10" Margin="0,0,10,10" MinWidth="118"><StackPanel><TextBlock Text="FRAME TIME" Style="{StaticResource Lbl}"/><TextBlock x:Name="fpsFt" Text="--" FontSize="22" FontWeight="Bold" Foreground="White"/></StackPanel></Border><Border Style="{StaticResource Card}" Padding="14,10" Margin="0,0,10,10" MinWidth="118"><StackPanel><TextBlock Text="VARIATION / SPIKES" Style="{StaticResource Lbl}"/><TextBlock x:Name="fpsStab" Text="--" FontSize="22" FontWeight="Bold" Foreground="White"/></StackPanel></Border></WrapPanel>
              <TextBlock x:Name="perfLive" Style="{StaticResource Sub}" Margin="0,0,0,10" TextWrapping="Wrap"/>
              <WrapPanel>
                <Button x:Name="btnFpsStart" Style="{StaticResource Go}" Padding="14,7" Margin="0,0,8,8" Content="Start live monitor"/>
                <Button x:Name="btnFpsStop" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Visibility="Collapsed" Content="Stop"/>
                <Button x:Name="btnPmSelect" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Select PresentMon..."/>
                <Button x:Name="btnPmGet" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Download PresentMon"/>
              </WrapPanel>
            </StackPanel></Border>
            <Border Style="{StaticResource Card}"><StackPanel>
              <TextBlock Text="DID BLUFPS HELP?  BEFORE AND AFTER TEST" Style="{StaticResource Lbl}"/>
              <TextBlock Text="Start a game, get into a scene you can repeat, then press Start test. bluFPS measures real frame times once without boost, applies your current profile, and measures again. Results are only what was measured." Style="{StaticResource Sub}" Margin="0,6,0,10" TextWrapping="Wrap"/>
              <WrapPanel>
                <Button x:Name="btnBenchStart" Style="{StaticResource Go}" Padding="14,7" Margin="0,0,8,8" Content="Start test"/>
                <Button x:Name="btnBenchCancel" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Visibility="Collapsed" Content="Cancel test"/>
                <Button x:Name="btnBenchDur" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Each run: 60 s"/>
              </WrapPanel>
              <ProgressBar x:Name="benchBar" Height="4" Minimum="0" Maximum="100" Foreground="#2F7BFF" Background="#16224A" BorderThickness="0" Visibility="Collapsed"/>
              <TextBlock x:Name="benchText" Foreground="White" FontSize="13" Margin="0,8,0,0" TextWrapping="Wrap"/>
            </StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0,14,0,0"><StackPanel>
              <TextBlock Text="SELF-CHECK  (tests bluFPS itself on this PC)" Style="{StaticResource Lbl}"/>
              <TextBlock Text="Checks permissions, helpers, counters, game detection logic, frame statistics, profiles and restore, and PresentMon. Takes about 10 seconds and changes nothing." Style="{StaticResource Sub}" Margin="0,6,0,10" TextWrapping="Wrap"/>
              <WrapPanel><Button x:Name="btnSelfCheck" Style="{StaticResource Go}" Padding="14,7" Margin="0,0,8,8" Content="Run self-check"/><Button x:Name="btnSelfCopy" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Copy results"/></WrapPanel>
              <TextBlock x:Name="selfText" Foreground="White" FontFamily="Consolas" FontSize="12" Margin="0,6,0,0" TextWrapping="Wrap"/>
            </StackPanel></Border>
          </StackPanel></ScrollViewer>
        </Grid>
        <!-- Tools -->
        <Grid x:Name="pgTools" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Tools" Style="{StaticResource Title}"/><TextBlock Text="Clean up junk, speed up startup, remove programs, see what slows your PC, and back up before you change anything." Style="{StaticResource Sub}" Margin="0,2,0,12"/></StackPanel>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,12">
            <Button x:Name="tabClean" Style="{StaticResource Btn}" Padding="14,7" Content="Cleaner"/>
            <Button x:Name="tabStart" Style="{StaticResource Btn}" Padding="14,7" Content="Startup"/>
            <Button x:Name="tabUninst" Style="{StaticResource Btn}" Padding="14,7" Content="Uninstaller"/>
            <Button x:Name="tabMon" Style="{StaticResource Btn}" Padding="14,7" Content="Monitor"/>
            <Button x:Name="tabBackup" Style="{StaticResource Btn}" Padding="14,7" Content="Backup"/>
          </StackPanel>
          <Grid Grid.Row="2">
            <!-- Cleaner -->
            <Grid x:Name="tpClean">
              <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
              <Border Style="{StaticResource Card}" Margin="0,0,14,12"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="cleanPanel"/></ScrollViewer></Border>
              <DockPanel Grid.Row="1" Margin="0,0,14,14">
                <TextBlock x:Name="cleanTotal" DockPanel.Dock="Right" VerticalAlignment="Center" FontSize="14" Foreground="#4DA3FF"/>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="btnCleanScan" Style="{StaticResource Btn}" Content="Scan"/>
                  <Button x:Name="btnCleanRun" Style="{StaticResource Go}" Content="Clean selected"/>
                  <Button x:Name="btnStorageSense" Style="{StaticResource Btn}" Content="Windows Storage Sense"/>
                </StackPanel>
              </DockPanel>
            </Grid>
            <!-- Startup -->
            <Grid x:Name="tpStart" Visibility="Collapsed">
              <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
              <Border Style="{StaticResource Card}" Margin="0,0,14,12"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="startPanel"/></ScrollViewer></Border>
              <DockPanel Grid.Row="1" Margin="0,0,14,14">
                <Button x:Name="btnStartRefresh" DockPanel.Dock="Left" Style="{StaticResource Btn}" Content="Refresh"/>
                <TextBlock x:Name="startNote" Style="{StaticResource Lbl}" FontSize="12" TextWrapping="Wrap" VerticalAlignment="Center"/>
              </DockPanel>
            </Grid>
            <!-- Uninstaller -->
            <Grid x:Name="tpUninst" Visibility="Collapsed">
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
              <TextBox x:Name="unSearch" Margin="0,0,14,10" Background="#0B1226" Foreground="White" CaretBrush="White" BorderBrush="#2A3A6B" Padding="10,7" FontSize="13" ToolTip="Search your programs"/>
              <Grid Grid.Row="1" Margin="0,0,14,14">
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="320"/></Grid.ColumnDefinitions>
                <Border Style="{StaticResource Card}" Margin="0,0,14,0"><ListBox x:Name="unList" Background="Transparent" BorderThickness="0" ItemContainerStyle="{StaticResource LB}" ScrollViewer.HorizontalScrollBarVisibility="Disabled"/></Border>
                <Border Grid.Column="1" Style="{StaticResource Card}" Margin="0">
                  <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel>
                    <TextBlock x:Name="unName" Text="Pick a program" FontSize="18" FontWeight="Bold" TextWrapping="Wrap"/>
                    <TextBlock x:Name="unInfo" Style="{StaticResource Lbl}" Margin="0,4,0,12" TextWrapping="Wrap"/>
                    <Button x:Name="btnUnRun" Style="{StaticResource Go}" Margin="0,0,0,8" Content="Uninstall"/>
                    <Button x:Name="btnUnLeft" Style="{StaticResource Btn}" Visibility="Collapsed" Margin="0,0,0,8" Content="Look for leftovers"/>
                    <TextBlock x:Name="unStatus" Style="{StaticResource Lbl}" FontSize="12" Foreground="#9FB0D0" TextWrapping="Wrap" Margin="0,0,0,10"/>
                    <StackPanel x:Name="unLeft"/>
                    <Button x:Name="btnUnClean" Style="{StaticResource Go}" Visibility="Collapsed" Margin="0,8,0,0" Content="Remove selected leftovers"/>
                  </StackPanel></ScrollViewer>
                </Border>
              </Grid>
            </Grid>
            <!-- Monitor -->
            <Grid x:Name="tpMon" Visibility="Collapsed">
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
              <UniformGrid Columns="3" Margin="0,0,0,0">
                <Border Style="{StaticResource Card}" Padding="14"><StackPanel><TextBlock Text="CPU" Style="{StaticResource Lbl}"/><TextBlock x:Name="monCpu" Text="--" FontSize="24" FontWeight="Bold" Margin="0,2,0,8"/><ProgressBar x:Name="monCpuBar" Maximum="100"/></StackPanel></Border>
                <Border Style="{StaticResource Card}" Padding="14"><StackPanel><TextBlock Text="MEMORY" Style="{StaticResource Lbl}"/><TextBlock x:Name="monRam" Text="--" FontSize="24" FontWeight="Bold" Margin="0,2,0,8"/><ProgressBar x:Name="monRamBar" Maximum="100"/></StackPanel></Border>
                <Border Style="{StaticResource Card}" Padding="14" Margin="0,0,0,14"><StackPanel><TextBlock Text="DISK ACTIVITY" Style="{StaticResource Lbl}"/><TextBlock x:Name="monDisk" Text="--" FontSize="24" FontWeight="Bold" Margin="0,2,0,8"/><ProgressBar x:Name="monDiskBar" Maximum="100"/></StackPanel></Border>
              </UniformGrid>
              <DockPanel Grid.Row="1" Margin="0,0,14,8">
                <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                  <TextBlock Text="SORT BY" Style="{StaticResource Lbl}" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <Button x:Name="monSortCpu" Style="{StaticResource Btn}" Padding="12,5" FontSize="11" Content="CPU"/>
                  <Button x:Name="monSortMem" Style="{StaticResource Btn}" Padding="12,5" FontSize="11" Content="Memory"/>
                  <Button x:Name="monSortIo" Style="{StaticResource Btn}" Padding="12,5" Margin="0" FontSize="11" Content="Disk"/>
                </StackPanel>
                <TextBlock x:Name="monVerdict" Foreground="#4DA3FF" FontSize="12" TextWrapping="Wrap" VerticalAlignment="Center"/>
              </DockPanel>
              <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,14,10">
                <DockPanel>
                  <Grid DockPanel.Dock="Top" Margin="0,0,0,8">
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="80"/><ColumnDefinition Width="90"/><ColumnDefinition Width="90"/></Grid.ColumnDefinitions>
                    <TextBlock Text="APP" Style="{StaticResource Lbl}"/><TextBlock Grid.Column="1" Text="CPU" Style="{StaticResource Lbl}"/>
                    <TextBlock Grid.Column="2" Text="MEMORY" Style="{StaticResource Lbl}"/><TextBlock Grid.Column="3" Text="DISK I/O" Style="{StaticResource Lbl}"/>
                  </Grid>
                  <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="monRows"/></ScrollViewer>
                </DockPanel>
              </Border>
              <TextBlock Grid.Row="3" x:Name="monDrives" Style="{StaticResource Lbl}" FontSize="12" TextWrapping="Wrap" Margin="0,0,14,8"/>
            </Grid>
            <!-- Backup -->
            <Grid x:Name="tpBackup" Visibility="Collapsed">
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
              <WrapPanel Margin="0,0,14,6">
                <Button x:Name="btnRestorePoint" Style="{StaticResource Go}" Margin="0,0,10,8" Content="Create restore point"/>
                <Button x:Name="btnRegBackup" Style="{StaticResource Btn}" Margin="0,0,10,8" Content="Back up registry now"/>
                <Button x:Name="btnRestoreBk" Style="{StaticResource Btn}" Margin="0,0,10,8" Content="Restore selected"/>
                <Button x:Name="btnDelBk" Style="{StaticResource Btn}" Margin="0,0,10,8" Content="Delete selected"/>
                <Button x:Name="btnOpenRst" Style="{StaticResource Btn}" Margin="0,0,10,8" Content="Open System Restore"/>
                <Button x:Name="btnOpenBk" Style="{StaticResource Btn}" Margin="0,0,10,8" Content="Open folder"/>
              </WrapPanel>
              <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,14,14">
                <DockPanel>
                  <TextBlock x:Name="bkNote" DockPanel.Dock="Bottom" Style="{StaticResource Lbl}" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"/>
                  <ListBox x:Name="bkList" Background="Transparent" BorderThickness="0" ItemContainerStyle="{StaticResource LB}"/>
                </DockPanel>
              </Border>
            </Grid>
          </Grid>
        </Grid>
        <!-- Updates -->
        <Grid x:Name="pgUpd" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Updates" Style="{StaticResource Title}"/><TextBlock Text="bluFPS checks for new versions and always asks before installing one." Style="{StaticResource Sub}"/></StackPanel>
          <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,14,14">
            <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel>
              <TextBlock Text="INSTALLED VERSION" Style="{StaticResource Lbl}"/>
              <TextBlock x:Name="updCur" Text="v1.1.9" Style="{StaticResource Val}" FontSize="28" Margin="0,2,0,6"/>
              <TextBlock x:Name="updMsg" Foreground="#9FB0D0" TextWrapping="Wrap" FontSize="13" Text="Not checked yet."/>
              <TextBox x:Name="updNotes" Visibility="Collapsed" IsReadOnly="True" Height="90" Margin="0,10,0,0" Background="#0B1226" Foreground="#C8D3F0" BorderThickness="0" Padding="10" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" FontSize="12"/>
              <StackPanel Orientation="Horizontal" Margin="0,14,0,0">
                <Button x:Name="btnUpdCheck" Style="{StaticResource Btn}" Content="Check for updates"/>
                <Button x:Name="btnUpdInstall" Style="{StaticResource Go}" Visibility="Collapsed" Content="Install update..."/>
              </StackPanel>
              <TextBlock x:Name="updSrcLbl" Text="UPDATE ADDRESS  (set automatically in released builds - normally nothing to type here)" Style="{StaticResource Lbl}" Margin="0,22,0,6" TextWrapping="Wrap"/>
              <DockPanel x:Name="updSrcRow">
                <Button x:Name="btnUpdSave" DockPanel.Dock="Right" Style="{StaticResource Btn}" Padding="16,8" Margin="8,0,0,0" Content="Save and check"/>
                <TextBox x:Name="updSrc" Background="#0B1226" Foreground="White" CaretBrush="White" BorderBrush="#2A3A6B" Padding="10,8" FontSize="13"/>
              </DockPanel>
              <CheckBox x:Name="chkAutoCheck" IsChecked="True" Margin="0,20,0,12"><StackPanel>
                <TextBlock Text="Check for updates automatically" FontSize="14"/>
                <TextBlock Text="On startup and every 6 hours while bluFPS is open." Style="{StaticResource Lbl}" FontSize="12"/></StackPanel></CheckBox>
              <Border x:Name="pubCard" Visibility="Collapsed" Background="#0B1226" BorderBrush="#2A3A6B" BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,22,0,10">
                <StackPanel>
                  <TextBlock Text="RELEASING UPDATES  (only for the person who publishes new versions)" Style="{StaticResource Lbl}" TextWrapping="Wrap"/>
                  <TextBlock x:Name="pubStatus" Style="{StaticResource Sub}" Margin="0,6,0,10" TextWrapping="Wrap"/>
                  <WrapPanel>
                    <Button x:Name="btnPubTarget" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Publish to: Testing"/>
                    <Button x:Name="btnPubSetup" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Set up publishing"/>
                    <Button x:Name="btnPubFile" Style="{StaticResource Go}" Padding="14,7" Margin="0,0,8,8" Content="Publish an update file..."/>
                    <Button x:Name="btnPubThis" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Publish this installed version"/>
                  </WrapPanel>
                </StackPanel>
              </Border>
              <TextBlock Text="bluFPS always asks before installing an update." Style="{StaticResource Lbl}" FontSize="12"/>
            </StackPanel></ScrollViewer>
          </Border>
        </Grid>
        <!-- Apps -->
        <Grid x:Name="pgApps" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <StackPanel><TextBlock Text="Apps" Style="{StaticResource Title}"/><TextBlock Text="Free up resources: close heavy background apps or give a game top priority." Style="{StaticResource Sub}"/></StackPanel>
          <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,14,14"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="appPanel"/></ScrollViewer></Border>
          <StackPanel Grid.Row="2" Orientation="Horizontal">
            <Button x:Name="btnKill" Style="{StaticResource Go}" Content="Close selected"/>
            <Button x:Name="btnPrio" Style="{StaticResource Btn}" Content="Set High priority"/>
            <Button x:Name="btnRefresh" Style="{StaticResource Btn}" Content="Refresh"/>
          </StackPanel>
        </Grid>
      </Grid>
      <TextBlock x:Name="status" Grid.Row="2" Foreground="#6C7CA3" FontSize="12" Margin="32,0,0,0" VerticalAlignment="Center" Text="Ready."/>
    </Grid>
    <Grid x:Name="updOverlay" Visibility="Collapsed" Grid.ColumnSpan="2" Margin="0,40,0,0" Background="#B3050815">
      <Border Width="470" HorizontalAlignment="Center" VerticalAlignment="Center" Style="{StaticResource Card}" Margin="0" Padding="26,22" BorderBrush="#2F7BFF">
        <StackPanel>
          <StackPanel Orientation="Horizontal">
            <Image x:Name="ovLogo" Width="46" Height="46" Margin="0,0,14,0" RenderOptions.BitmapScalingMode="HighQuality"/>
            <StackPanel VerticalAlignment="Center">
              <TextBlock Text="Update available" FontSize="20" FontWeight="Bold"/>
              <TextBlock x:Name="ovVer" Style="{StaticResource Lbl}" FontSize="13"/>
            </StackPanel>
          </StackPanel>
          <TextBlock Text="Do you want to update bluFPS now?" FontSize="17" Margin="0,20,0,0"/>
          <TextBlock Text="bluFPS will close and reopen by itself. Your settings are kept." Style="{StaticResource Lbl}" FontSize="12" Margin="0,3,0,0"/>
          <TextBox x:Name="ovNotes" Visibility="Collapsed" IsReadOnly="True" Height="90" Margin="0,14,0,0" Background="#0B1226" Foreground="#C8D3F0" BorderThickness="0" Padding="10" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" FontSize="12"/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,22,0,0">
            <Button x:Name="ovSkip" Style="{StaticResource Btn}" Content="Skip this version"/>
            <Button x:Name="ovLater" Style="{StaticResource Btn}" Content="Not now"/>
            <Button x:Name="ovNow" Style="{StaticResource Go}" Margin="0" Content="Yes, update"/>
          </StackPanel>
        </StackPanel>
      </Border>
    </Grid>
    <Grid x:Name="addOverlay" Visibility="Collapsed" Grid.ColumnSpan="2" Margin="0,40,0,0" Background="#B3050815">
      <Border Width="640" HorizontalAlignment="Center" VerticalAlignment="Center" Style="{StaticResource Card}" Margin="0" Padding="24,20" BorderBrush="#2F7BFF">
        <StackPanel>
          <TextBlock Text="Add games to Game Boost" FontSize="20" FontWeight="Bold" Foreground="White"/>
          <TextBlock x:Name="addInfo" Style="{StaticResource Sub}" Margin="0,4,0,10" TextWrapping="Wrap"/>
          <ProgressBar x:Name="addBar" Height="6" Minimum="0" Maximum="100" Foreground="#2F7BFF" Background="#16224A" BorderThickness="0"/>
          <TextBlock x:Name="addText" Style="{StaticResource Sub}" Margin="0,6,0,8" TextWrapping="Wrap"/>
          <ScrollViewer Height="270" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="addList"/></ScrollViewer>
          <WrapPanel Margin="0,14,0,0">
            <Button x:Name="btnAddScan" Style="{StaticResource Go}" Padding="14,7" Margin="0,0,8,8" Content="Scan now"/>
            <Button x:Name="btnAddSel" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Add selected"/>
            <Button x:Name="btnAddAll" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Add all new"/>
            <Button x:Name="btnAddExe" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Browse for .exe..."/>
            <Button x:Name="btnAddFolder" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Content="Scan a folder..."/>
            <Button x:Name="btnAddClear" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,8,8" Visibility="Collapsed" Content="Forget extra folders"/>
            <Button x:Name="btnAddClose" Style="{StaticResource Btn}" Padding="14,7" Margin="0,0,0,8" Content="Close"/>
          </WrapPanel>
        </StackPanel>
      </Border>
    </Grid>
  </Grid>
  </Border>
</Window>
'@

Set-Splash 'Loading interface...'
$win = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml]$xaml))
$c = @{}
[regex]::Matches($xaml, 'x:Name="(\w+)"') | ForEach-Object { $c[$_.Groups[1].Value] = $win.FindName($_.Groups[1].Value) }

# ---------- helpers ----------
function Invoke-Native($file, $arguments) {
    $psi = New-Object Diagnostics.ProcessStartInfo $file, $arguments
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd(); [void]$p.StandardError.ReadToEnd(); $p.WaitForExit()
    $global:LASTEXITCODE = $p.ExitCode
    $out
}
function Pump { $win.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{}) }
function Log($m) { $c.log.AppendText("$m`r`n"); $c.log.ScrollToEnd(); $c.status.Text = $m; Pump }

$dir = Join-Path $env:APPDATA 'bluFPS'
New-Item $dir -ItemType Directory -Force | Out-Null
$bak = Join-Path $dir 'backup.json'
$backup = @{}
if (Test-Path $bak) { try { (Get-Content $bak -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $backup[$_.Name] = $_.Value } } catch {} }
function Save-Backup { $backup | ConvertTo-Json -Depth 4 | Set-Content $bak }

function Set-Reg($path, $name, $value, $kind = 'DWord') {
    $key = "$path|$name"
    if (-not $backup.ContainsKey($key)) {
        $old = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        $backup[$key] = @{ Existed = [bool]$old; Value = if ($old) { $old.$name } else { $null }; Kind = $kind }
        Save-Backup
    }
    if (-not (Test-Path $path)) { New-Item $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $kind
}

$mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$hp = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$tweaks = @(
    @{ Name = 'High Performance power plan'; Desc = 'Stops the CPU from down-clocking while you play.'; On = $true; Run = {
        if (-not $backup.ContainsKey('powerplan')) { $backup['powerplan'] = @{ Value = [regex]::Match((Invoke-Native 'powercfg' '/getactivescheme'), '[0-9a-fA-F-]{36}').Value }; Save-Backup }
        [void](Invoke-Native 'powercfg' "/setactive $hp")
        if ($LASTEXITCODE -ne 0) { [void](Invoke-Native 'powercfg' ('/setactive ' + [regex]::Match((Invoke-Native 'powercfg' "-duplicatescheme $hp"), '[0-9a-fA-F-]{36}').Value)) } } },
    @{ Name = 'Windows Game Mode'; Desc = 'Tells Windows to prioritize the game you are running.'; On = $true; Run = {
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 } },
    @{ Name = 'Turn off Game DVR recording'; Desc = 'Stops background capture that costs frames.'; On = $true; Run = {
        Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 } },
    @{ Name = 'Game CPU/GPU scheduling priority'; Desc = 'Gives games higher priority in the Windows scheduler.'; On = $true; Run = {
        Set-Reg $mm 'SystemResponsiveness' 0
        Set-Reg "$mm\Tasks\Games" 'GPU Priority' 8
        Set-Reg "$mm\Tasks\Games" 'Priority' 6
        Set-Reg "$mm\Tasks\Games" 'Scheduling Category' 'High' 'String'
        Set-Reg "$mm\Tasks\Games" 'SFIO Priority' 'High' 'String' } },
    @{ Name = 'Remove network throttling'; Desc = 'Lifts the packet-rate cap Windows applies for multimedia.'; On = $true; Run = { Set-Reg $mm 'NetworkThrottlingIndex' 0xffffffff } },
    @{ Name = 'Flush DNS cache'; Desc = 'Clears stale lookups so servers resolve fresh.'; On = $true; Run = { [void](Invoke-Native 'ipconfig' '/flushdns') } },
    @{ Name = 'Hardware GPU scheduling'; Desc = 'Optional. Needs a restart and a recent GPU + driver.'; On = $false; Run = {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 } },
    @{ Name = 'Disable mouse acceleration'; Desc = 'Optional. 1:1 mouse movement. Sign out and back in to apply.'; On = $false; Run = {
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String' } },
    @{ Name = 'Turn off window transparency'; Desc = 'Optional. Frees a little GPU for games.'; On = $false; Run = {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 } },
    @{ Name = 'Stop Store apps running in the background'; Desc = 'Optional. Less background CPU and network use.'; On = $false; Run = {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 } }
)

function Update-Boost {
    if ($backup.Count -gt 0) {
        $c.valBoost.Text = 'ON'; $c.valBoost.Foreground = '#3DDC97'
        $c.btnBoost.Content = "BOOST ACTIVE`nclick to revert"; $c.btnBoost.Background = '#1FA971'
    } else {
        $c.valBoost.Text = 'OFF'; $c.valBoost.Foreground = '#FFFFFF'
        $c.btnBoost.Content = 'BOOST NOW'; $c.btnBoost.Background = $script:goBrush
    }
}

function Apply-Tweaks($list) {
    try { Ensure-RegBackup 'tweaks' } catch {}
    foreach ($t in $list) {
        try { & $t.Run; Log "OK    $($t.Name)" } catch { Log "FAIL  $($t.Name): $($_.Exception.Message)" }; Pump
    }
    Update-Boost; Log 'Done. Restart your PC for every change to take effect.'
}

function Undo-All($only = $null) {
    foreach ($k in @($backup.Keys)) {
        if ($only -and -not $k.EndsWith("|$only")) { continue }
        try {
            if ($k -eq 'powerplan') { [void](Invoke-Native 'powercfg' "/setactive $($backup[$k].Value)"); continue }
            $p, $n = $k -split '\|', 2
            $b = $backup[$k]
            if ($b.Existed) { Set-ItemProperty -Path $p -Name $n -Value $b.Value -Type $b.Kind } else { Remove-ItemProperty -Path $p -Name $n -ErrorAction SilentlyContinue }
        } catch { Log "Could not revert ${k}: $($_.Exception.Message)" }
    }
    if ($only) {
        foreach ($k in @($backup.Keys)) { if ($k.EndsWith("|$only")) { $backup.Remove($k) } }
        Save-Backup
    } else { $backup.Clear(); Remove-Item $bak -ErrorAction SilentlyContinue }
    Update-Boost; Log $(if ($only) { 'Game settings reverted.' } else { 'Reverted to your original settings.' })
}

function Ping-Host($h, $n = 5) {
    $p = New-Object Net.NetworkInformation.Ping; $t = @()
    1..$n | ForEach-Object { try { $r = $p.Send($h, 800); if ($r.Status -eq 'Success') { $t += $r.RoundtripTime } } catch {}; Pump }
    , $t
}

function Set-Dns($servers) {
    Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
        if ($servers) { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses $servers } else { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses }
    }
}

function Load-Apps {
    $c.appPanel.Children.Clear()
    $skip = 'explorer', 'powershell', 'pwsh', 'ApplicationFrameHost', 'TextInputHost', 'SystemSettings', 'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost', 'dwm'
    Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $skip -notcontains $_.ProcessName -and $_.Id -ne $PID } |
        Sort-Object WorkingSet64 -Descending | Select-Object -First 30 | ForEach-Object {
            $cb = New-Object Windows.Controls.CheckBox -Property @{ Tag = $_; Foreground = '#FFFFFF'; Margin = '0,0,0,10'
                Content = ('{0}  ({1} MB)  {2}' -f $_.ProcessName, [int]($_.WorkingSet64 / 1MB), $_.MainWindowTitle) }
            [void]$c.appPanel.Children.Add($cb)
        }
}

function Show-Page($name) {
    foreach ($p in 'Dash', 'Boost', 'Game', 'Net', 'Apps', 'Perf', 'Tools', 'Upd', 'Set') {
        $on = ($p -eq $name)
        $c["pg$p"].Visibility = if ($on) { 'Visible' } else { 'Collapsed' }
        $c["nav$p"].Tag = if ($on) { 'on' } else { '' }
    }
    if ($name -eq 'Apps') { Load-Apps }
    if ($name -eq 'Game') { Load-Games }
    if ($name -eq 'Set') { Sync-StartupBox }
    if ($name -eq 'Perf') { Update-PmStatus }
    if ($name -eq 'Upd') { Update-PubStatus }
    if ($name -eq 'Tools') { Set-ToolTab $script:toolTab } else { try { $script:monTimer.Stop() } catch {} }
}

# ---------- settings, game library and per-game boost (Cortex-style) ----------
$script:dataDir = Join-Path $env:APPDATA 'bluFPS'
$script:setPath = Join-Path $script:dataDir 'settings.json'
$script:gamesPath = Join-Path $script:dataDir 'games.json'
$script:gameExe = $null; $script:watchName = $null
$script:library = @(); $script:libView = @(); $script:selGame = $null
$script:sess = $null; $script:autoBlock = $null; $script:setBoxes = @{}; $script:killBoxes = @()

$script:protectedProcs = 'explorer', 'winlogon', 'csrss', 'services', 'lsass', 'svchost', 'dwm', 'System', 'Idle', 'smss', 'wininit',
    'powershell', 'pwsh', 'bluFPS', 'conhost', 'fontdrvhost', 'ShellExperienceHost', 'StartMenuExperienceHost', 'SearchHost',
    'TextInputHost', 'taskhostw', 'RuntimeBroker', 'ctfmon', 'sihost', 'MsMpEng', 'audiodg', 'steam', 'EpicGamesLauncher', 'GalaxyClient'
# friendly name, process name, closed by default
$script:knownApps = @(
    @('OneDrive', 'OneDrive', $true), @('Microsoft Teams', 'ms-teams', $true), @('Teams (classic)', 'Teams', $true), @('Skype', 'Skype', $true),
    @('Slack', 'slack', $true), @('Zoom', 'Zoom', $true), @('Dropbox', 'Dropbox', $true), @('Google Drive', 'GoogleDriveFS', $true),
    @('Adobe Creative Cloud', 'Creative Cloud', $true), @('Phone Link', 'PhoneExperienceHost', $true), @('Widgets', 'Widgets', $true), @('Wallpaper Engine', 'wallpaper64', $true), @('Wallpaper Engine (32-bit)', 'wallpaper32', $true), @('Spotify', 'Spotify', $false), @('Discord', 'Discord', $false),
    @('Google Chrome', 'chrome', $false), @('Microsoft Edge', 'msedge', $false), @('Firefox', 'firefox', $false))

function Get-Settings {
    $d = @{ AutoBoost = $false; AutoRestore = $true; RestoreApps = $true; Prio = $true; Plan = $true; CloseApps = $false
            Ram = $true; Dns = $true; GameMode = $true; Gpu = $true; Svc = $true; BgPrio = $true; Sched = $true; Notify = $true; Eco = $true; ProBal = $true; MemKeep = $true; BoostPlan = ''; BoostPlanVer = 0; GpuPrio = $true; Excl = $false; Mig = 0; AutoAdd = $true; ScanFolders = @(); Level = 'Auto'; PresentMon = ''; CustomApps = @()
            KillApps = @($script:knownApps | Where-Object { $_[2] } | ForEach-Object { $_[1] }) }
    if (Test-Path $script:setPath) {
        try {
            $j = Get-Content $script:setPath -Raw | ConvertFrom-Json
            foreach ($k in @($d.Keys)) { if ($j.PSObject.Properties.Name -contains $k) { $d[$k] = $j.$k } }
        } catch {}
    }
    $d.KillApps = @($d.KillApps); $d.CustomApps = @($d.CustomApps)
    if ([int]$d.Mig -lt 1) { foreach ($n in 'wallpaper64', 'wallpaper32') { if ($d.KillApps -notcontains $n) { $d.KillApps += $n } }; $d.Mig = 1 }
    if ([int]$d.Mig -lt 2) { $d.CloseApps = $false; $d.Mig = 2 }
    $d
}
function Save-Settings {
    New-Item $script:dataDir -ItemType Directory -Force | Out-Null
    ConvertTo-Json -InputObject $script:S -Depth 3 | Set-Content $script:setPath
}
$script:S = Get-Settings

# ----- library -----
# The library is the list of games bluFPS manages. Detected = everything the last scan found.
# Removed = games the user took out (they are not added back automatically).
$script:libPath = Join-Path $script:dataDir 'library.json'
$script:library = @(); $script:detected = @(); $script:removed = @()
$script:scanCtx = $null; $script:scanPs = $null; $script:scanAsync = $null; $script:scanTimer = $null
$script:iconCache = @{}; $script:addBoxes = @(); $script:lastScanErrors = @(); $script:lastReport = @()
$script:junkExe = '(?i)^(unins|setup|install|crash|report|redist|vc_?redist|dxsetup|dxwebsetup|dotnet|ndp|ue4prereq|unitycrash|unrealcef|easyanticheat|beservice|battleye|uninst|notification|updater|patch|helper|cef|webview|python|7z|oalinst|physx)'

function Get-Manual {
    if (Test-Path $script:gamesPath) { try { return @(Get-Content $script:gamesPath -Raw | ConvertFrom-Json) } catch {} }
    return @()
}
function Set-Prop($o, $n, $v) { $o | Add-Member -NotePropertyName $n -NotePropertyValue $v -Force }

# --- same-game test (also used inside the background scan, so it only uses its own parameters) ---
function Norm-Path { param($p)
    if (-not $p) { return '' }
    return ("$p".Trim().TrimEnd('\', '/')).ToLowerInvariant()
}
function Norm-Game { param($n) return ((("$n").ToLowerInvariant()) -replace '[^a-z0-9]', '') }
function Test-Under { param($child, $parent)
    if (-not $child -or -not $parent) { return $false }
    if ($parent.Split('\').Count -lt 3) { return $false }
    return $child.StartsWith($parent + '\')
}
function Test-SameGame { param($a, $b)
    if ($a.Key -and $a.Key -eq $b.Key) { return $true }
    $da = Norm-Path $a.Dir; $db = Norm-Path $b.Dir; $ea = Norm-Path $a.Exe; $eb = Norm-Path $b.Exe
    if ($ea -and $ea -eq $eb) { return $true }
    if ($da -and $db -and ($da -eq $db -or (Test-Under $da $db) -or (Test-Under $db $da))) { return $true }
    if ($ea -and (Test-Under $ea $db)) { return $true }
    if ($eb -and (Test-Under $eb $da)) { return $true }
    $na = Norm-Game $a.Name; $nb = Norm-Game $b.Name
    if ($na.Length -ge 4 -and $na -eq $nb) { return $true }
    return $false
}

# --- the scan engine: runs in the background and reports real progress through $ctx ---
function Invoke-GameScan { param($ctx)
    $ErrorActionPreference = 'SilentlyContinue'
    $found = New-Object System.Collections.ArrayList
    $known = @{}
    $junkExe = '(?i)^(unins|setup|install|crash|report|redist|vc_?redist|dxsetup|dxwebsetup|dotnet|ndp|ue4prereq|unitycrash|unrealcef|easyanticheat|beservice|battleye|uninst|notification|updater|patch|helper|cef|webview|python|7z|oalinst|physx)'
    $junkDir = '(?i)^(common files|microsoft|windows|windowsapps|program files|program files \(x86\)|steam|steamapps|epic games launcher|launcher|redist|_commonredist|directx|vcredist|dotnet|\$recycle\.bin|system volume information|temp|tmp|cache|downloads|installers?|ubisoft game launcher|battle\.net|origin|ea app|ea desktop|gog galaxy|riot client|gaming services|nvidia|amd|intel|7-zip|google|mozilla|adobe|java|python|nodejs|git|visual studio|windows kits|msbuild|dism)$'
    $steps = New-Object System.Collections.ArrayList
    $si = 0; $total = 1

    function Hash10 { param($s) $h = [Security.Cryptography.SHA1]::Create(); return ((([BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes(("$s").ToLowerInvariant())))) -replace '-', '').Substring(0, 10).ToLower()) }
    function Err { param($m) [void]$ctx.Errors.Add("$m") }
    function Prog { param($frac, $msg)
        $f = [math]::Max(0, [math]::Min(1, [double]$frac))
        $ctx.Pct = [int][math]::Min(99, [math]::Floor(100 * ($si + $f) / $total))
        if ($msg) { $ctx.Msg = "$msg" }
    }
    function Tidy { param($n) return (("$n") -replace '_+', ' ').Trim() }
    function Find-MainExe { param($dir)
        $skipDir = '(?i)^(redist|_commonredist|directx|vcredist|__installer|support|tools|thirdparty|content|paks|movies|videos|video|audio|sounds|sound|music|localization|locales|shaders|saved|logs|mods|screenshots|cache|crashes|assets|engine)$'
        $best = $null; $size = 0L
        $level = @($dir)
        for ($depth = 0; $depth -le 3 -and $level.Count; $depth++) {
            $next = New-Object System.Collections.ArrayList
            foreach ($d in $level) {
                try {
                    foreach ($f in [IO.Directory]::EnumerateFiles($d, '*.exe')) {
                        if ([IO.Path]::GetFileName($f) -match $junkExe) { continue }
                        $len = (New-Object IO.FileInfo $f).Length
                        if ($len -gt $size) { $best = $f; $size = $len }
                    }
                } catch {}
                if ($depth -lt 3) {
                    try { foreach ($sd in [IO.Directory]::EnumerateDirectories($d)) { if ([IO.Path]::GetFileName($sd) -notmatch $skipDir) { [void]$next.Add($sd) } } } catch {}
                }
            }
            if ($best -and $size -ge 3MB) { break }
            $level = @($next)
        }
        return $best
    }
    function Add-G { param($name, $launcher, $launch, $dir, $exe, $key, $extra)
        if (-not $name -or -not $dir) { return }
        $dir = "$dir".Trim().Trim('"').TrimEnd('\')
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return }
        $o = [pscustomobject]@{ Name = "$name".Trim(); Launcher = $launcher; Launch = $launch; Dir = $dir; Exe = $exe; Key = $key; AppId = $null; CatalogItemId = $null; GogId = $null; LaunchArgs = $null; Alt = $null; IsNew = $false }
        if ($extra) { foreach ($k in $extra.Keys) { $o.$k = $extra[$k] } }
        [void]$found.Add($o); $known[(Norm-Path $dir)] = $true; $ctx.Count = $found.Count
    }

    function Scan-Steam {
        $steam = $null
        foreach ($k in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
            $v = Get-ItemProperty $k
            if ($v) { foreach ($n in 'SteamPath', 'InstallPath') { if ($v.$n -and (Test-Path -LiteralPath ("$($v.$n)" -replace '/', '\'))) { $steam = ("$($v.$n)" -replace '/', '\'); break } } }
            if ($steam) { break }
        }
        if (-not $steam) { [void]$ctx.Report.Add('Steam is not installed (no Steam entry in the registry)'); return }
        $libs = @($steam)
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace '\\\\', '\') }
        }
        foreach ($lib in ($libs | Select-Object -Unique)) {
            $apps = Join-Path $lib 'steamapps'
            if (-not (Test-Path -LiteralPath $apps)) { Err "Steam library $lib could not be read (missing drive or access denied)."; continue }
            foreach ($f in (Get-ChildItem -LiteralPath $apps -Filter 'appmanifest_*.acf' -File)) {
                $txt = Get-Content -LiteralPath $f.FullName -Raw
                $id = [regex]::Match($txt, '"appid"\s+"(\d+)"').Groups[1].Value
                $name = [regex]::Match($txt, '"name"\s+"([^"]+)"').Groups[1].Value
                $dir = [regex]::Match($txt, '"installdir"\s+"([^"]+)"').Groups[1].Value
                $flags = [regex]::Match($txt, '"StateFlags"\s+"(\d+)"').Groups[1].Value
                if (-not $id -or -not $name -or -not $dir) { continue }
                if ($flags -and (([int]$flags -band 4) -eq 0)) { continue }
                if ($name -match '^(Steamworks Common|Steam Linux Runtime|Proton |SteamVR$|Steam Controller)|Redistributable') { continue }
                Add-G $name 'Steam' "steam://rungameid/$id" (Join-Path (Join-Path $apps 'common') $dir) $null "steam-$id" @{ AppId = $id }
            }
        }
    }
    function Scan-Epic {
        $md = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
        if (Test-Path -LiteralPath $md) {
            foreach ($f in (Get-ChildItem -LiteralPath $md -Filter *.item -File)) {
                try {
                    $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
                    if (-not $j.DisplayName -or -not $j.InstallLocation -or $j.bIsIncompleteInstall) { continue }
                    if ($j.MainGameAppName -and $j.MainGameAppName -ne $j.AppName) { continue }
                    $cats = @($j.AppCategories)
                    if ($cats.Count -and ($cats -notcontains 'games')) { continue }
                    $uri = "com.epicgames.launcher://apps/$($j.CatalogNamespace)%3A$($j.CatalogItemId)%3A$($j.AppName)?action=launch&silent=true"
                    Add-G $j.DisplayName 'Epic' $uri $j.InstallLocation $null (("epic-$($j.AppName)") -replace '[^\w.-]', '_') @{ CatalogItemId = $j.CatalogItemId }
                } catch {}
            }
        }
        $dat = Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
        if (Test-Path -LiteralPath $dat) {
            try {
                $j = Get-Content -LiteralPath $dat -Raw | ConvertFrom-Json
                foreach ($i in @($j.InstallationList)) {
                    if (-not $i.InstallLocation -or "$($i.AppName)" -match '^(UE_|UnrealEngine)') { continue }
                    Add-G (Tidy (Split-Path "$($i.InstallLocation)".TrimEnd('\') -Leaf)) 'Epic' "com.epicgames.launcher://apps/$($i.AppName)?action=launch&silent=true" $i.InstallLocation $null (("epic-$($i.AppName)") -replace '[^\w.-]', '_')
                }
            } catch {}
        }
    }
    function Scan-GOG {
        foreach ($root in 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games', 'HKLM:\SOFTWARE\GOG.com\Games') {
            foreach ($k in (Get-ChildItem $root)) {
                $p = Get-ItemProperty $k.PSPath
                if ($p.gameName -and $p.path -and $p.exe -and -not $p.dependsOn) { Add-G $p.gameName 'GOG' $p.exe $p.path $p.exe "gog-$($k.PSChildName)" @{ GogId = $k.PSChildName } }
            }
        }
    }
    function Scan-Xbox {
        $seen = @{}
        $pkgs = @()
        try { $pkgs = @(Get-AppxPackage -ErrorAction Stop) } catch { Err "Xbox / Microsoft Store games could not be listed: $("$($_.Exception.Message)" -replace '\r?\n', ' ')" }
        $n = 0
        foreach ($a in $pkgs) {
            $n++; if ($n % 15 -eq 0) { Prog ($n / [math]::Max(1, $pkgs.Count)) 'Checking Xbox / Microsoft Store apps...' }
            if ($a.IsFramework -or $a.IsResourcePackage -or -not $a.InstallLocation) { continue }
            $loc = "$($a.InstallLocation)"
            $cfgPath = Join-Path $loc 'MicrosoftGame.config'
            if (-not (($loc -match '(?i)\\XboxGames\\') -or (Test-Path -LiteralPath $cfgPath))) { continue }
            $name = $null; $exe = $null
            if (Test-Path -LiteralPath $cfgPath) {
                try {
                    $x = [xml](Get-Content -LiteralPath $cfgPath -Raw)
                    $dn = "$($x.Game.ShellVisuals.DefaultDisplayName)"
                    if ($dn -and $dn -notlike 'ms-resource*') { $name = $dn }
                    $en = "$(@($x.Game.ExecutableList.Executable)[0].Name)"
                    if ($en) { $cand = Join-Path $loc $en; if (Test-Path -LiteralPath $cand) { $exe = $cand } }
                } catch {}
            }
            $appId = 'App'
            try {
                $m = Get-AppxPackageManifest -Package $a
                $app = @($m.Package.Applications.Application)[0]
                if ($app.Id) { $appId = "$($app.Id)" }
                if (-not $name) { $dn = "$($m.Package.Properties.DisplayName)"; if ($dn -and $dn -notlike 'ms-resource*') { $name = $dn } }
            } catch {}
            if (-not $name) {
                if ($loc -match '(?i)\\XboxGames\\([^\\]+)\\') { $name = $Matches[1] }
                else { $name = (($a.Name -split '\.')[-1] -creplace '([a-z0-9])([A-Z])', '$1 $2') }
            }
            if (-not $exe) { $exe = Find-MainExe $loc }
            Add-G $name 'Xbox' "shell:AppsFolder\$($a.PackageFamilyName)!$appId" $loc $exe ("xbox-" + ("$($a.PackageFamilyName)" -replace '[^\w.-]', '_'))
            $seen[(Norm-Path $loc)] = $true
        }
        foreach ($dr in $drives) {
            $xg = Join-Path $dr 'XboxGames'
            if (-not (Test-Path -LiteralPath $xg)) { continue }
            foreach ($d in (Get-ChildItem -LiteralPath $xg -Directory)) {
                $content = Join-Path $d.FullName 'Content'
                if (-not (Test-Path -LiteralPath $content)) { $content = $d.FullName }
                if ($seen.ContainsKey((Norm-Path $content))) { continue }
                $exe = Find-MainExe $content
                if ($exe) { Add-G (Tidy $d.Name) 'Xbox' $exe $content $exe "xbox-$(Hash10 $content)" }
            }
        }
    }
    function Scan-Other {
        foreach ($root in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs') {
            foreach ($k in (Get-ChildItem $root)) {
                $p = Get-ItemProperty $k.PSPath
                $d = ("$($p.InstallDir)" -replace '/', '\').TrimEnd('\')
                if ($d -and (Test-Path -LiteralPath $d)) { Add-G (Tidy (Split-Path $d -Leaf)) 'Ubisoft' "uplay://launch/$($k.PSChildName)/0" $d $null "ubisoft-$($k.PSChildName)" }
            }
        }
        foreach ($root in 'HKLM:\SOFTWARE\WOW6432Node\EA Games', 'HKLM:\SOFTWARE\EA Games', 'HKLM:\SOFTWARE\WOW6432Node\Electronic Arts', 'HKLM:\SOFTWARE\Electronic Arts') {
            foreach ($k in (Get-ChildItem $root)) {
                $p = Get-ItemProperty $k.PSPath; $d = $null
                foreach ($n in 'Install Dir', 'InstallDir', 'InstallLocation') { if ($p.$n) { $d = "$($p.$n)"; break } }
                if ($d -and (Test-Path -LiteralPath $d)) {
                    $nm = $k.PSChildName; if ($p.DisplayName) { $nm = "$($p.DisplayName)" }
                    $exe = Find-MainExe $d
                    Add-G $nm 'EA' $exe $d $exe "ea-$(Hash10 $d)"
                }
            }
        }
        foreach ($root in 'HKLM:\SOFTWARE\WOW6432Node\Rockstar Games', 'HKLM:\SOFTWARE\Rockstar Games') {
            foreach ($k in (Get-ChildItem $root)) {
                $p = Get-ItemProperty $k.PSPath
                $d = "$($p.InstallFolder)".TrimEnd('\')
                if ($d -and (Test-Path -LiteralPath $d)) { $exe = Find-MainExe $d; Add-G $k.PSChildName 'Rockstar' $exe $d $exe "rockstar-$(Hash10 $d)" }
            }
        }
        $meta = Join-Path $env:ProgramData 'Riot Games\Metadata'
        if (Test-Path -LiteralPath $meta) {
            foreach ($f in (Get-ChildItem -LiteralPath $meta -Recurse -Filter '*.product_settings.yaml' -File)) {
                $txt = Get-Content -LiteralPath $f.FullName -Raw
                $m = [regex]::Match($txt, '(?m)^product_install_full_path:\s*"?([^"\r\n]+?)"?\s*$')
                if (-not $m.Success) { continue }
                $gd = (($m.Groups[1].Value -replace '\\\\', '\') -replace '/', '\').TrimEnd('\')
                if ((Split-Path $gd -Leaf) -match '^(live|pbe|ptr)$') { $gd = Split-Path $gd }
                $parts = $f.Name -split '\.'
                $prod = $parts[0]; $patch = 'live'; if ($parts.Count -gt 3) { $patch = $parts[1] }
                $client = Join-Path (Split-Path $gd) 'Riot Client\RiotClientServices.exe'
                $launch = $null; if (Test-Path -LiteralPath $client) { $launch = $client }
                $nice = (Get-Culture).TextInfo.ToTitleCase(($prod -replace '_', ' ')) -replace ' Of ', ' of '
                Add-G $nice 'Riot' $launch $gd $null "riot-$prod" @{ LaunchArgs = "--launch-product=$prod --launch-patchline=$patch" }
            }
        }
    }
    function Scan-Installed {
        $pub = '(?i)blizzard|activision|bethesda|rockstar|ubisoft|electronic arts|2k games|2k sports|valve|riot games|epic games|cd projekt|square enix|capcom|bandai|sega|warner|take-two|paradox|devolver|team17|thq|konami|krafton|mihoyo|hoyoverse|wargaming|gaijin|mojang|hi-rez|behaviour interactive|netease|nexon|smilegate|pearl abyss|innersloth|re-logic|facepunch|wube|grinding gear|frontier developments|crytek|gearbox|obsidian|larian|fromsoftware|remedy|io interactive|digital extremes|sony interactive|xbox game studios|microsoft studios|bohemia|firaxis|techland|respawn|id software|arkane|zenimax|iron gate|keen software|kinetic games|supergiant|klei'
        $notGame = '(?i)^(steam|epic games launcher|battle\.net|ubisoft connect|uplay|ea app|ea desktop|origin|gog galaxy|riot client|xbox|microsoft (edge|visual|office|teams|onedrive|windows|\.net)|nvidia|geforce|amd |intel|visual c\+\+|\.net|directx|java|python|7-zip|vlc|discord|obs|blufps|google|mozilla)'
        foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall') {
            foreach ($k in (Get-ChildItem $root)) {
                $p = Get-ItemProperty $k.PSPath
                $name = "$($p.DisplayName)"; $loc = ("$($p.InstallLocation)").Trim('"').TrimEnd('\')
                if (-not $name -or -not $loc -or $name -match $notGame) { continue }
                if ("$($p.SystemComponent)" -eq '1' -or $p.ParentKeyName) { continue }
                if ($loc -match '(?i)^[a-z]:\\(windows|program files|program files \(x86\))?$') { continue }
                if ($known.ContainsKey((Norm-Path $loc))) { continue }
                if (-not (Test-Path -LiteralPath $loc -PathType Container)) { continue }
                $byPub = ("$($p.Publisher)" -match $pub)
                $byPath = ($loc -match '(?i)\\(games|steamlibrary|epic games|riot games|gog games|origin games|ea games)\\')
                if (-not ($byPub -or $byPath)) { continue }
                $exe = Find-MainExe $loc
                if ($exe) { Add-G $name 'Installed app' $exe $loc $exe "app-$(Hash10 $loc)" }
            }
        }
    }
    function Scan-Root { param($root, $custom, $base, $span)
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { if ($custom) { Err "Folder not found: $root" }; return }
        $kids = @()
        try { $kids = @(Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction Stop) } catch { Err "Could not read $root ($("$($_.Exception.Message)" -replace '\r?\n', ' '))"; return }
        $before = $found.Count; $n = 0
        foreach ($d in $kids) {
            $n++
            Prog ($base + $span * ($n / [math]::Max(1, $kids.Count))) "Scanning $root  ($n of $($kids.Count))"
            if ($d.Name -match $junkDir) { continue }
            if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($known.ContainsKey((Norm-Path $d.FullName))) { continue }
            $exe = Find-MainExe $d.FullName
            if ($exe) { Add-G (Tidy $d.Name) 'Folder' $exe $d.FullName $exe "folder-$(Hash10 $d.FullName)" }
        }
        if ($custom -and $found.Count -eq $before -and -not $known.ContainsKey((Norm-Path $root))) {
            $exe = Find-MainExe $root
            if ($exe) { Add-G (Tidy (Split-Path $root.TrimEnd('\') -Leaf)) 'Folder' $exe $root $exe "folder-$(Hash10 $root)" }
        }
    }
    function Scan-Drive { param($dr)
        $rels = 'Games', 'Game', 'SteamLibrary\steamapps\common', 'Steam\steamapps\common', 'Program Files (x86)\Steam\steamapps\common', 'Program Files\Steam\steamapps\common', 'Epic Games', 'Program Files\Epic Games', 'Program Files (x86)\Epic Games', 'Riot Games', 'GOG Games', 'GOG Galaxy\Games', 'Program Files (x86)\GOG Galaxy\Games', 'Origin Games', 'Program Files (x86)\Origin Games', 'EA Games', 'Program Files\EA Games', 'Program Files (x86)\EA Games', 'Ubisoft\Ubisoft Game Launcher\games', 'Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games', 'Program Files\Ubisoft\Ubisoft Game Launcher\games', 'Rockstar Games', 'Program Files\Rockstar Games', 'Program Files (x86)\Rockstar Games', 'Blizzard Entertainment', 'Program Files (x86)\Blizzard Entertainment', 'Program Files\Blizzard Entertainment'
        $roots = @($rels | ForEach-Object { Join-Path $dr $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
        if (-not $roots.Count) { return }
        for ($i = 0; $i -lt $roots.Count; $i++) { Scan-Root $roots[$i] $false ($i / $roots.Count) (1 / $roots.Count) }
    }

    try {
        $drives = @([IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.RootDirectory.FullName })
        foreach ($s in @(@('Steam', 'steam', $null), @('Epic Games', 'epic', $null), @('GOG', 'gog', $null), @('Xbox app / Microsoft Store', 'xbox', $null), @('EA, Ubisoft, Riot and Rockstar', 'other', $null), @('Installed programs', 'installed', $null))) { [void]$steps.Add(@{ Label = "Scanning $($s[0])..."; Kind = $s[1]; Arg = $s[2] }) }
        foreach ($dr in $drives) { [void]$steps.Add(@{ Label = "Scanning game folders on $dr"; Kind = 'drive'; Arg = $dr }) }
        foreach ($f in @($ctx.Folders)) { if ($f) { [void]$steps.Add(@{ Label = "Scanning $f"; Kind = 'custom'; Arg = $f }) } }
        $total = [math]::Max(1, $steps.Count)
        for ($si = 0; $si -lt $steps.Count; $si++) {
            $s = $steps[$si]
            Prog 0 $s.Label
            $before = $found.Count
            try {
                switch ($s.Kind) {
                    'steam' { Scan-Steam }
                    'epic' { Scan-Epic }
                    'gog' { Scan-GOG }
                    'xbox' { Scan-Xbox }
                    'other' { Scan-Other }
                    'installed' { Scan-Installed }
                    'drive' { Scan-Drive $s.Arg }
                    'custom' { Scan-Root $s.Arg $true 0 1 }
                }
            } catch { Err "$($s.Label) $($_.Exception.Message)" }
            [void]$ctx.Report.Add("$("$($s.Label)".TrimEnd('.')) $($found.Count - $before)")
        }
        # one game, one entry - even when several launchers or folders point at it
        $ctx.Msg = 'Removing duplicates...'
        $prio = @{ Steam = 1; Epic = 1; GOG = 1; Xbox = 1; Ubisoft = 2; EA = 2; Riot = 2; Rockstar = 2; 'Installed app' = 3; Folder = 4 }
        $sorted = @($found | Sort-Object @{ Expression = { $prio["$($_.Launcher)"] } }, @{ Expression = { if ($_.AppId -or $_.CatalogItemId -or $_.GogId) { 0 } else { 1 } } }, Name)
        $out = New-Object System.Collections.ArrayList
        foreach ($g in $sorted) {
            $hit = $null
            foreach ($e in $out) { if (Test-SameGame $e $g) { $hit = $e; break } }
            if ($hit) {
                if ($hit.Launcher -ne $g.Launcher) {
                    $alts = @("$($hit.Alt)".Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                    if ($alts -notcontains $g.Launcher) { $hit.Alt = (@($alts) + $g.Launcher) -join ', ' }
                }
                if (-not $hit.Exe -and $g.Exe) { $hit.Exe = $g.Exe }
                continue
            }
            [void]$out.Add($g)
        }
        $ctx.Result = @($out | Sort-Object Name)
    } catch { Err "The scan stopped early: $($_.Exception.Message)" }
    finally { $ctx.Pct = 100; $ctx.Done = $true }
}

# --- library: load, save, add ---
function New-ManualGame($name, $exe) {
    [pscustomobject]@{ Name = "$name"; Launcher = 'Added'; Launch = $exe; Dir = (Split-Path $exe); Exe = $exe; Key = ('added-' + (Get-ShortHash $exe)); AppId = $null; CatalogItemId = $null; GogId = $null; LaunchArgs = $null; Alt = $null; IsNew = $false }
}
function Load-Library {
    $script:library = @(); $script:detected = @(); $script:removed = @()
    $ok = $false
    if (Test-Path $script:libPath) {
        try {
            $j = [IO.File]::ReadAllText($script:libPath) | ConvertFrom-Json
            $script:library = @($j.Library | Where-Object { $_ })
            $script:detected = @($j.Detected | Where-Object { $_ })
            $script:removed = @($j.Removed | Where-Object { $_ } | ForEach-Object { "$_" })
            $ok = $true
        } catch {}
    }
    if (-not $ok) {
        foreach ($g in @(Get-Manual)) { if ($g.Exe) { $script:library += (New-ManualGame $g.Name $g.Exe) } }
    }
    foreach ($g in $script:library) { Set-Prop $g 'IsNew' $false }
    $script:library = @($script:library | Sort-Object Name)
}
function Save-Library {
    try {
        New-Item $script:dataDir -ItemType Directory -Force | Out-Null
        $json = ConvertTo-Json -InputObject @{ Library = @($script:library); Detected = @($script:detected); Removed = @($script:removed) } -Depth 4
        [IO.File]::WriteAllText($script:libPath, $json, (New-Object Text.UTF8Encoding $false))
    } catch { Log "Could not save your game list: $($_.Exception.Message)" }
}
function Test-InLibrary($g) {
    foreach ($e in $script:library) { if (Test-SameGame $e $g) { return $true } }
    return $false
}
function Add-ToLibrary($games) {
    $n = 0
    foreach ($g in @($games)) {
        if (-not $g -or (Test-InLibrary $g)) { continue }
        Set-Prop $g 'IsNew' $true
        $script:library += $g; $n++
        $nk = 'name:' + (Norm-Game $g.Name)
        $script:removed = @($script:removed | Where-Object { $_ -ne $g.Key -and $_ -ne $nk })
    }
    $script:library = @($script:library | Sort-Object Name)
    return $n
}

# --- status, icons ---
function Get-GameStatus($g) {
    $l = "$($g.Launch)"
    $isUri = ($l -match '^[A-Za-z.]+://' -or $l -like 'shell:*')
    if ($g.Dir -and -not (Test-Path -LiteralPath $g.Dir)) { return 'Not found - moved or uninstalled (press Locate)' }
    if (-not $l -or (-not $isUri -and -not (Test-Path -LiteralPath $l))) { return 'Needs its .exe (press Locate)' }
    return 'Ready for Game Boost'
}
function Get-ExeIcon($path) {
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $null }
    if ($script:iconCache.ContainsKey($path)) { return $script:iconCache[$path] }
    $src = $null
    try {
        Add-Type -AssemblyName System.Drawing
        $ic = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
        $src = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($ic.Handle, [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
        $src.Freeze()
    } catch {}
    $script:iconCache[$path] = $src
    return $src
}
function Get-GameIconPath($g) {
    if ($g.Exe -and (Test-Path -LiteralPath $g.Exe)) { return $g.Exe }
    $k = "dir:$($g.Dir)"
    if ($script:iconCache.ContainsKey($k)) { return $script:iconCache[$k] }
    $p = $null
    if ($g.Dir -and (Test-Path -LiteralPath $g.Dir -PathType Container)) {
        foreach ($sub in '', 'Binaries\Win64', 'bin', 'bin\x64', 'x64') {
            $d = $g.Dir; if ($sub) { $d = Join-Path $g.Dir $sub }
            if (-not (Test-Path -LiteralPath $d -PathType Container)) { continue }
            $f = Get-ChildItem -LiteralPath $d -Filter *.exe -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $script:junkExe } | Sort-Object Length -Descending | Select-Object -First 1
            if ($f) { $p = $f.FullName; break }
        }
    }
    $script:iconCache[$k] = $p
    return $p
}

# --- guard: a failing button shows the real error on the Games page and in the log instead of doing nothing ---
function Guard($what, [scriptblock]$sb) {
    try { & $sb }
    catch {
        $m = "$what failed: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
        try { Log $m } catch {}
        try {
            $c.scanText.Text = $m; $c.scanText.Foreground = '#FF8A8A'; $c.scanText.Visibility = 'Visible'; $c.scanBar.Visibility = 'Collapsed'
            foreach ($b in $c.btnGameScan, $c.btnGameFolder, $c.btnAddScan, $c.btnAddFolder) { $b.IsEnabled = $true }
            if ($script:scanPs -and ($null -eq $script:scanTimer -or -not $script:scanTimer.IsEnabled)) { try { $script:scanPs.Dispose() } catch {}; $script:scanPs = $null; $script:scanAsync = $null }
            $dir = Join-Path $env:APPDATA 'bluFPS'; New-Item $dir -ItemType Directory -Force | Out-Null
            Add-Content (Join-Path $dir 'crash.log') ("[{0}] {1}`n{2}`n" -f (Get-Date), $m, $_.ScriptStackTrace)
        } catch {}
    }
}
# --- scan control (UI side) ---
function Set-ScanUi($pct, $msg, $busy) {
    $c.scanBar.Value = $pct; $c.addBar.Value = $pct
    $c.scanText.Text = $msg; $c.addText.Text = $msg
    try { $c.scanText.ClearValue([Windows.Controls.TextBlock]::ForegroundProperty) } catch {}
    $c.scanText.Visibility = 'Visible'
    $c.scanBar.Visibility = if ($busy) { 'Visible' } else { 'Collapsed' }
    foreach ($b in $c.btnGameScan, $c.btnGameFolder, $c.btnAddScan, $c.btnAddFolder) { $b.IsEnabled = (-not $busy) }
}
function Start-GameScan($mode) {
    if ($script:scanPs) { return }
    $ctx = [hashtable]::Synchronized(@{ Pct = 0; Msg = 'Starting...'; Count = 0; Done = $false; Errors = (New-Object System.Collections.ArrayList); Result = @(); Report = (New-Object System.Collections.ArrayList); Folders = @($script:S.ScanFolders | Where-Object { $_ }); Mode = $mode })
    $script:scanCtx = $ctx; $script:scanStart = Get-Date
    $fns = foreach ($n in 'Norm-Path', 'Norm-Game', 'Test-Under', 'Test-SameGame', 'Invoke-GameScan') { "function $n {`n" + (Get-Command $n -CommandType Function).ScriptBlock.ToString() + "`n}" }
    $script:scanPs = [powershell]::Create()
    [void]$script:scanPs.AddScript("param(`$ctxArg)`n" + ($fns -join "`n") + "`nInvoke-GameScan `$ctxArg").AddArgument($ctx)
    $script:scanAsync = $script:scanPs.BeginInvoke()
    Set-ScanUi 0 'Starting scan...' $true
    if (-not $script:scanTimer) {
        $script:scanTimer = New-Object Windows.Threading.DispatcherTimer
        $script:scanTimer.Interval = [TimeSpan]::FromMilliseconds(250)
        $script:scanTimer.Add_Tick({ Guard 'Scan update' { Poll-GameScan } })
    }
    $script:scanTimer.Start()
}
function Poll-GameScan {
    $ctx = $script:scanCtx
    if (-not $ctx) { return }
    if (-not $ctx.Done) {
        if ($script:scanAsync -and $script:scanAsync.IsCompleted) {
            $why = @($script:scanPs.Streams.Error | ForEach-Object { "$_" } | Select-Object -First 2) -join ' | '
            [void]$ctx.Errors.Add("The scan engine stopped unexpectedly. $why"); $ctx.Done = $true
        }
        elseif (((Get-Date) - $script:scanStart).TotalMinutes -gt 10) {
            try { $script:scanPs.Stop() } catch {}
            [void]$ctx.Errors.Add('The scan took longer than 10 minutes and was cut short.'); $ctx.Done = $true
        }
        else { Set-ScanUi $ctx.Pct ("$($ctx.Msg)   -   $($ctx.Count) found so far") $true; return }
    }
    $script:scanTimer.Stop()
    try { if ($script:scanAsync.IsCompleted) { [void]$script:scanPs.EndInvoke($script:scanAsync) } } catch { [void]$ctx.Errors.Add("Scan engine error: $($_.Exception.Message)") }
    try { $script:scanPs.Dispose() } catch {}
    $script:scanPs = $null; $script:scanAsync = $null
    Finish-GameScan $ctx
}
function Finish-GameScan($ctx) {
    $res = @($ctx.Result | Where-Object { $_ })
    $errs = @($ctx.Errors | ForEach-Object { "$_" })
    $script:lastScanErrors = $errs
    $script:lastReport = @($ctx.Report | ForEach-Object { "$_" })
    $script:detected = $res
    # keep library entries up to date (a game may have moved or got a new launch path)
    foreach ($e in $script:library) {
        $m = $res | Where-Object { $_.Key -eq $e.Key } | Select-Object -First 1
        if ($m -and $e.Launcher -ne 'Added') { Set-Prop $e 'Dir' $m.Dir; Set-Prop $e 'Launch' $m.Launch; Set-Prop $e 'LaunchArgs' $m.LaunchArgs; Set-Prop $e 'Alt' $m.Alt; if ($m.Exe) { Set-Prop $e 'Exe' $m.Exe } }
    }
    $new = @()
    foreach ($g in $res) {
        $gone = ($script:removed -contains $g.Key) -or ($script:removed -contains ('name:' + (Norm-Game $g.Name)))
        if (-not $gone -and -not (Test-InLibrary $g)) { $new += $g }
    }
    $added = 0
    if ($script:S.AutoAdd) { $added = Add-ToLibrary $new }
    $waiting = $new.Count - $added
    if ($res.Count -eq 0) { $msg = 'No games were found. Use "Scan a folder" to point bluFPS at the folder where your games are installed, or "Add games" and browse to the game .exe.' }
    else {
        $msg = "Scan finished: $($res.Count) games found, $added new added to your library."
        if ($waiting -gt 0) { $msg += " $waiting more are waiting - open Add games to pick them." }
    }
    if ($errs.Count) { $msg += "  $($errs.Count) place(s) could not be read." }
    Save-Library
    Load-Games; Show-GameDetail
    Set-ScanUi 100 $msg $false
    Log $msg
    foreach ($e in ($errs | Select-Object -First 3)) { Log $e }
    foreach ($r in $script:lastReport) { Log "  scan: $r" }
    if ($c.addOverlay.Visibility -eq 'Visible') { Build-AddList }
    Start-ArtRefresh $false
}

# --- "Add games" panel ---
function Build-AddList {
    $c.addList.Children.Clear(); $script:addBoxes = @()
    $info = 'bluFPS looks at Steam, Epic, GOG, the Xbox app, EA, Ubisoft, Riot, Rockstar, installed programs and the usual game folders on every drive.'
    $extra = @($script:S.ScanFolders | Where-Object { $_ })
    if ($extra.Count) { $info += "  Extra folders: " + ($extra -join '; ') + '.' }
    if ($script:lastScanErrors.Count) { $info += "  Could not read: " + ((@($script:lastScanErrors) | Select-Object -First 3) -join ' | ') }
    if ($script:lastReport.Count) { $info += '  Last scan: ' + ($script:lastReport -join '; ') + '.' }
    $c.addInfo.Text = $info
    $c.btnAddClear.Visibility = if ($extra.Count) { 'Visible' } else { 'Collapsed' }
    $rows = @($script:detected | Sort-Object Name)
    if (-not $rows.Count) {
        [void]$c.addList.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = 'Nothing detected yet. Press Scan now, scan a folder, or browse for a game .exe.'; Foreground = '#8FA0C9'; TextWrapping = 'Wrap'; Margin = '0,8,0,0' }))
        return
    }
    foreach ($g in $rows) {
        $inLib = Test-InLibrary $g
        $row = New-Object Windows.Controls.DockPanel -Property @{ Margin = '0,0,0,8'; LastChildFill = $true }
        $cb = New-Object Windows.Controls.CheckBox -Property @{ VerticalAlignment = 'Center'; Margin = '0,0,10,0'; IsChecked = $false; IsEnabled = (-not $inLib) }
        [Windows.Controls.DockPanel]::SetDock($cb, 'Left'); [void]$row.Children.Add($cb)
        $st = New-Object Windows.Controls.TextBlock -Property @{ VerticalAlignment = 'Center'; FontSize = 12; Margin = '10,0,0,0'; Text = $(if ($inLib) { 'In library' } else { 'Not added' }); Foreground = $(if ($inLib) { '#3DDC97' } else { '#8FA0C9' }) }
        [Windows.Controls.DockPanel]::SetDock($st, 'Right'); [void]$row.Children.Add($st)
        $sp = New-Object Windows.Controls.StackPanel
        $sub = "$($g.Launcher)"; if ($g.Alt) { $sub += " + $($g.Alt)" }
        [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = "$($g.Name)"; FontSize = 14; Foreground = 'White'; TextTrimming = 'CharacterEllipsis' }))
        [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = "$sub  -  $($g.Dir)"; FontSize = 11; Foreground = '#6C7CA3'; TextTrimming = 'CharacterEllipsis'; ToolTip = "$($g.Dir)" }))
        [void]$row.Children.Add($sp)
        [void]$c.addList.Children.Add($row)
        $script:addBoxes += @{ Box = $cb; Game = $g }
    }
}
function Select-Game($key) {
    for ($i = 0; $i -lt $script:libView.Count; $i++) { if ($script:libView[$i].Key -eq $key) { $c.gameList.SelectedIndex = $i; $c.gameList.ScrollIntoView($c.gameList.SelectedItem); return } }
}
function Add-ManualExe {
    $d = New-Object Microsoft.Win32.OpenFileDialog -Property @{ Filter = 'Game executable (*.exe)|*.exe'; Title = 'Select the game .exe' }
    if ($d.ShowDialog() -ne $true) { return }
    $exe = $d.FileName
    $def = Get-PrettyName $exe
    $probe = New-ManualGame $def $exe
    foreach ($e in $script:library) {
        if (Test-SameGame $e $probe) { Log "$($e.Name) is already in your list."; $c.addText.Text = "$($e.Name) is already in your list."; $c.gameSearch.Text = ''; Load-Games; Select-Game $e.Key; return }
    }
    $nm = $def
    try { $nm = [Microsoft.VisualBasic.Interaction]::InputBox('What is this game called? bluFPS uses the name to find its picture.', 'Add game', $def) } catch {}
    if (-not "$nm".Trim()) { $nm = $def }
    $probe.Name = "$nm".Trim()
    [void](Add-ToLibrary @($probe))
    Save-Library; $c.gameSearch.Text = ''; Load-Games; Select-Game $probe.Key
    Log "Added $($probe.Name)  ($exe)"; $c.addText.Text = "Added $($probe.Name)."
    if ($c.addOverlay.Visibility -eq 'Visible') { Build-AddList }
    Start-ArtRefresh $false
}
function Add-ScanFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    $f.Description = 'Pick the folder that contains your games (or a single game folder)'
    $f.ShowNewFolderButton = $false
    if ($f.ShowDialog() -ne 'OK') { return }
    $list = @($script:S.ScanFolders | Where-Object { $_ })
    if ($list -notcontains $f.SelectedPath) { $list += $f.SelectedPath }
    $script:S.ScanFolders = $list; Save-Settings
    Start-GameScan 'manual'
}

function Get-PlanText {
    $cfg = $script:S; $l = @()
    if ($cfg.CloseApps) { $n = @(@($cfg.KillApps) + @($cfg.CustomApps) | Select-Object -Unique).Count; $l += "- Close up to $n background apps" }
    if ($cfg.Ram) { $l += '- Free up RAM' }
    if ($cfg.Plan) { $l += '- Tuned power plan (no core parking)' }
    if ($cfg.GameMode) { $l += '- Game Mode on, game recording off' }
    if ($cfg.BgPrio) { $l += '- Lower the priority of other apps' }
    if ($cfg.Eco) { $l += '- Efficiency mode + low I/O for other apps' }
    if ($cfg.ProBal) { $l += '- ProBalance: stop CPU hogs mid-game' }
    if ($cfg.MemKeep) { $l += '- Keep memory smooth while playing' }
    if ($cfg.GpuPrio) { $l += '- GPU priority for the game' }
    if ($cfg.Excl) { $l += '- Defender skips the game folder while playing' }
    if ($cfg.Svc) { $l += '- Pause SysMain, Search and telemetry' }
    if ($cfg.Sched) { $l += '- Favor the game in the scheduler' }
    if ($cfg.Notify) { $l += '- Silence notification pop-ups' }
    if ($cfg.Dns) { $l += '- Flush the DNS cache' }
    if ($cfg.Prio) { $l += '- High CPU priority for the game' }
    if ($cfg.Gpu) { $l += '- High-performance GPU' }
    if ($l.Count) { if ($cfg.AutoRestore) { $l += '- Everything is put back when you quit' } else { $l += '- Press Restore when you are done' } }
    if ($l.Count) { $l -join "`n" } else { 'Nothing selected. Turn things on in Settings.' }
}
function Update-SessionUi {
    $sn = $script:sess
    if ($sn) {
        $c.btnPlay.IsEnabled = $false; $c.btnBoostOnly.IsEnabled = $false; $c.btnRestore.Visibility = 'Visible'
        $state = if ($sn.Waiting) { 'waiting for the game to start...' } elseif ($sn.Proc) { 'boost active. It ends when you quit the game.' } else { 'game closed. Press Restore.' }
        $c.sessState.Text = "$($sn.Game.Name): $state"; $c.sessState.Foreground = '#3DDC97'
    } else {
        $c.btnPlay.IsEnabled = [bool]$script:selGame; $c.btnBoostOnly.IsEnabled = [bool]$script:selGame; $c.btnRestore.Visibility = 'Collapsed'
        $c.sessState.Text = 'No boost active.'; $c.sessState.Foreground = '#6C7CA3'
    }
}
function Show-GameDetail {
    $g = $script:selGame
    $hb = $null; if ($g) { $hb = Get-ArtBrush $g.Key 640 }
    if ($hb) { $c.gameHero.Background = $hb; $c.gameHeroText.Text = '' }
    else { $c.gameHero.Background = $script:phBrush; $c.gameHeroText.Text = $(if ($g) { "$($g.Name)" } else { 'Pick a game' }) }
    $c.btnGameArt.IsEnabled = [bool]$g; $c.btnGameArtReset.IsEnabled = [bool]$g
    if ($g) {
        $src = "$($g.Launcher)"; if ($g.Alt) { $src += " (also $($g.Alt))" }
        $c.gameName.Text = $g.Name; $c.gameSrc.Text = "$src  -  $(Get-GameStatus $g)"; $c.gamePathTxt.Text = "$($g.Dir)"
        $pl = "$($g.Profile)"; if (-not $pl -or $pl -eq 'Default') { $pl = 'same as Settings' } elseif ($pl -eq 'Off') { $pl = 'off (never optimize)' } elseif ($pl -eq 'Auto') { $pl = 'auto (picked for your PC)' }
        $c.btnGameProfile.Content = "Profile for this game: $pl"; $c.btnGameProfile.Visibility = 'Visible'
        $c.btnRemoveGame.Visibility = 'Visible'; $c.btnLocate.Visibility = 'Visible'
        $c.btnOpenDir.Visibility = if ($g.Dir -and (Test-Path -LiteralPath $g.Dir)) { 'Visible' } else { 'Collapsed' }
    } else { $c.gameName.Text = 'Pick a game'; $c.gameSrc.Text = ''; $c.gamePathTxt.Text = ''; $c.btnRemoveGame.Visibility = 'Collapsed'; $c.btnLocate.Visibility = 'Collapsed'; $c.btnOpenDir.Visibility = 'Collapsed'; $c.btnGameProfile.Visibility = 'Collapsed' }
    if ($g -and "$($g.Profile)" -eq 'Off') { $c.gamePlan.Text = 'Profile is Off for this game: bluFPS will not change anything while it runs.' }
    else {
        $origCfg = @{}; if ($g -and -not $script:sess) { $origCfg = Apply-GameProfile $g }
        $c.gamePlan.Text = Get-PlanText
        if ($g -and -not $script:sess) {
            $why = ''; if ($g.LastVerdict) { $why = " and this game's last analysis ($($g.LastVerdict))" }
            if ($script:lastAutoPick) { $c.gamePlan.Text = "Auto profile: using $($script:lastAutoPick) settings, chosen for your PC$why`n" + $c.gamePlan.Text }
            if (@($script:lastSkips).Count) { $c.gamePlan.Text += "`nSkipped for your PC: " + (@($script:lastSkips) -join '; ') }
        }
        foreach ($k in @($origCfg.Keys)) { $script:S[$k] = $origCfg[$k] }
    }
    if ($g -and (Test-KnownAntiCheat $g.Name)) { $c.gamePlan.Text += "`nAnti-cheat game: bluFPS only optimizes the rest of your PC and never touches the game itself." }
    Update-SessionUi
}
function Load-Games {
    $q = $c.gameSearch.Text.Trim()
    $keep = $null; if ($script:selGame) { $keep = $script:selGame.Key }
    $script:libView = @($script:library | Where-Object { -not $q -or $_.Name.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    $c.gameList.Items.Clear()
    $sel = -1; $i = 0
    foreach ($g in $script:libView) {
        try { [void]$c.gameList.Items.Add((New-GameRow $g)) }
        catch { Log "Could not draw $($g.Name): $($_.Exception.Message)"; [void]$c.gameList.Items.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = "$($g.Name)"; Foreground = 'White' })) }
        if ($keep -and $g.Key -eq $keep) { $sel = $i }
        $i++
    }
    if ($sel -ge 0) { $c.gameList.SelectedIndex = $sel }
    $notReady = @($script:library | Where-Object { (Get-GameStatus $_) -notlike 'Ready*' }).Count
    $c.gameCount.Text = if ($script:library.Count) { "$($script:libView.Count) of $($script:library.Count) games" + $(if ($notReady) { "  -  $notReady need attention" } else { '  -  all ready for Game Boost' }) } else { 'No games yet. Press Rescan, Add games, or Scan a folder.' }
}

# ---------- game pictures (cached on disk, refreshed in the background) ----------
$script:artDir = Join-Path $script:dataDir 'art'
$script:artCache = @{}; $script:artAsync = $null; $script:artPs = $null; $script:artQueued = $false
$script:phBrush = [Windows.Markup.XamlReader]::Parse('<LinearGradientBrush xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#1B2A55" Offset="0"/><GradientStop Color="#3A2F8F" Offset="1"/></LinearGradientBrush>')

function Get-ShortHash($text) {
    $h = [Security.Cryptography.SHA1]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes("$text"))
    ([BitConverter]::ToString($h) -replace '-', '').Substring(0, 10).ToLower()
}
function Get-PrettyName($exe) {
    $n = [IO.Path]::GetFileNameWithoutExtension($exe)
    $n = $n -replace '(-Win64-Shipping|-Win32-Shipping|-Shipping|_x64|_x86|-x64)$', '' -replace 'Client$', '' -replace '([a-z0-9])([A-Z])', '$1 $2' -replace '[_-]+', ' '
    $n.Trim()
}
function Get-ArtPath($key) { Join-Path $script:artDir "$key.img" }
function Clear-ArtCache($key) {
    foreach ($ck in @($script:artCache.Keys)) { if ($ck.StartsWith("$key|")) { $script:artCache.Remove($ck) } }
}
function Get-ArtBrush($key, $width) {
    $ck = "$key|$width"
    if ($script:artCache.ContainsKey($ck)) { return $script:artCache[$ck] }
    $path = Get-ArtPath $key; $br = $null
    if (Test-Path -LiteralPath $path) {
        try {
            $bm = New-Object Windows.Media.Imaging.BitmapImage
            $bm.BeginInit(); $bm.UriSource = New-Object Uri $path; $bm.CacheOption = 'OnLoad'; $bm.DecodePixelWidth = $width; $bm.EndInit(); $bm.Freeze()
            $br = New-Object Windows.Media.ImageBrush $bm
            $br.Stretch = 'UniformToFill'; $br.Freeze()
        } catch { $br = $null }
    }
    $script:artCache[$ck] = $br
    $br
}
function New-GameRow($g) {
    $thumb = New-Object Windows.Controls.Border -Property @{ Width = 84; Height = 47; CornerRadius = '6'; Margin = '0,0,12,0' }
    $br = Get-ArtBrush $g.Key 200
    if ($br) { $thumb.Background = $br }
    else {
        $thumb.Background = $script:phBrush
        $ico = Get-ExeIcon (Get-GameIconPath $g)
        if ($ico) { $thumb.Child = New-Object Windows.Controls.Image -Property @{ Source = $ico; Width = 32; Height = 32; HorizontalAlignment = 'Center'; VerticalAlignment = 'Center' } }
        else { $thumb.Child = New-Object Windows.Controls.TextBlock -Property @{ Text = ("$($g.Name)" + '?').Substring(0, 1).ToUpper(); FontSize = 20; FontWeight = 'Bold'; Foreground = '#7FB2FF'; HorizontalAlignment = 'Center'; VerticalAlignment = 'Center' } }
    }
    $st = Get-GameStatus $g
    $ready = ($st -like 'Ready*')
    $sp = New-Object Windows.Controls.StackPanel -Property @{ VerticalAlignment = 'Center' }
    [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = "$($g.Name)"; FontSize = 14; TextTrimming = 'CharacterEllipsis' }))
    $sub = "$($g.Launcher)"; if ($g.Alt) { $sub += " + $($g.Alt)" }; if ($g.IsNew) { $sub += '   NEW' }
    [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $sub; FontSize = 11; Foreground = '#6C7CA3' }))
    [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $(if ($ready) { 'Ready for Game Boost' } else { $st }); FontSize = 11; Foreground = $(if ($ready) { '#3DDC97' } else { '#F5C542' }) }))
    $row = New-Object Windows.Controls.StackPanel -Property @{ Orientation = 'Horizontal'; ToolTip = "$($g.Dir)" }
    [void]$row.Children.Add($thumb); [void]$row.Children.Add($sp)
    return $row
}

# runs in a background runspace: finds each game's main picture, re-downloads it when a new one appears
function Get-ArtWork {
    param($items, $dir, $force)
    $ErrorActionPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    function Fetch($url, $etag) {
        try {
            $req = [Net.HttpWebRequest]::Create($url)
            $req.UserAgent = 'bluFPS-art'; $req.Timeout = 8000; $req.ReadWriteTimeout = 8000
            if ($etag) { $req.Headers['If-None-Match'] = $etag }
            $resp = $req.GetResponse()
            try {
                $ms = New-Object IO.MemoryStream
                $resp.GetResponseStream().CopyTo($ms)
                return @{ Status = 200; Bytes = $ms.ToArray(); ETag = $resp.Headers['ETag'] }
            } finally { $resp.Close() }
        } catch [Net.WebException] {
            $r = $_.Exception.Response
            if ($r -and [int]$r.StatusCode -eq 304) { return @{ Status = 304 } }
            return @{ Status = 0 }
        } catch { return @{ Status = 0 } }
    }
    function Get-Json($url) {
        $r = Fetch $url $null
        if ($r.Status -eq 200) { try { return ([Text.Encoding]::UTF8.GetString($r.Bytes) | ConvertFrom-Json) } catch {} }
        return $null
    }
    function Is-Image($b) {
        if (-not $b -or $b.Length -lt 2048 -or $b.Length -gt 8000000) { return $false }
        return (($b[0] -eq 0xFF -and $b[1] -eq 0xD8) -or ($b[0] -eq 0x89 -and $b[1] -eq 0x50) -or ($b[0] -eq 0x47 -and $b[1] -eq 0x49))
    }
    function Norm($x) { return ("$x".ToLower() -replace '[^a-z0-9]', '') }
    function Try-Url($url, $key) {
        $file = Join-Path $dir "$key.img"
        $ent = $idx[$key]
        $etag = $null; if ($ent -and $ent.Url -eq $url -and (Test-Path $file)) { $etag = $ent.ETag }
        $r = Fetch $url $etag
        if ($r.Status -eq 304) { $idx[$key] = @{ Url = $url; ETag = $ent.ETag; Checked = (Get-Date).ToString('o') }; return 'same' }
        if ($r.Status -eq 200 -and (Is-Image $r.Bytes)) {
            [IO.File]::WriteAllBytes($file, $r.Bytes)
            $idx[$key] = @{ Url = $url; ETag = "$($r.ETag)"; Checked = (Get-Date).ToString('o') }
            return 'new'
        }
        return $null
    }

    $idxPath = Join-Path $dir 'art.json'
    $idx = @{}
    if (Test-Path $idxPath) {
        try { $j = Get-Content $idxPath -Raw | ConvertFrom-Json; foreach ($p in $j.PSObject.Properties) { $idx[$p.Name] = @{ Url = "$($p.Value.Url)"; ETag = "$($p.Value.ETag)"; Checked = "$($p.Value.Checked)" } } } catch {}
    }
    $changed = @(); $epic = $null
    foreach ($it in @($items)) {
        $key = $it.Key
        if (-not $key -or (Test-Path (Join-Path $dir "$key.custom"))) { continue }
        $file = Join-Path $dir "$key.img"
        $ent = $idx[$key]
        if (-not $force -and $ent -and (Test-Path $file)) {
            $age = 999; try { $age = ((Get-Date) - [datetime]$ent.Checked).TotalHours } catch {}
            if ($age -lt 6) { continue }
        }
        $cands = @()
        if ($it.Launcher -eq 'Steam' -and $it.AppId) {
            $cands += "https://cdn.cloudflare.steamstatic.com/steam/apps/$($it.AppId)/header.jpg", "https://cdn.akamai.steamstatic.com/steam/apps/$($it.AppId)/header.jpg"
        }
        if ($it.Launcher -eq 'Epic' -and $it.CatalogItemId) {
            if ($null -eq $epic) {
                $epic = @{}
                $cp = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Catalog\catcache.bin'
                if (Test-Path $cp) {
                    try {
                        Add-Type -AssemblyName System.Web.Extensions
                        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((Get-Content $cp -Raw).Trim()))
                        $js = New-Object Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue
                        foreach ($o in $js.DeserializeObject($json)) {
                            $best = $null
                            foreach ($ty in 'DieselGameBox', 'OfferImageWide', 'DieselStoreFrontWide', 'Thumbnail', 'DieselGameBoxTall') {
                                foreach ($im in @($o['keyImages'])) { if ($im['type'] -eq $ty -and $im['url']) { $best = $im['url']; break } }
                                if ($best) { break }
                            }
                            if ($best) { $epic[$o['id']] = $best }
                        }
                    } catch {}
                }
            }
            if ($epic[$it.CatalogItemId]) { $cands += $epic[$it.CatalogItemId] }
        }
        if ($it.Launcher -eq 'GOG' -and $it.GogId) {
            $gg = Get-Json "https://api.gog.com/products/$($it.GogId)"
            foreach ($u in @($gg.images.logo2x, $gg.images.background)) { if ($u) { $cands += ("$u" -replace '^//', 'https://') } }
        }
        $res = $null
        foreach ($u in $cands) { $res = Try-Url $u $key; if ($res) { break } }
        if (-not $res -and $it.Name) {
            # not on a store we can read: look the game up by name (Steam store search, then Wikipedia)
            $nm = Norm $it.Name
            $ss = Get-Json ('https://store.steampowered.com/api/storesearch/?term=' + [uri]::EscapeDataString("$($it.Name)") + '&l=english&cc=us')
            foreach ($x in @($ss.items)) {
                if ($x.id -and (Norm $x.name) -eq $nm) { $res = Try-Url "https://cdn.cloudflare.steamstatic.com/steam/apps/$($x.id)/header.jpg" $key; break }
            }
            if (-not $res) {
                foreach ($title in @("$($it.Name) (video game)", "$($it.Name)")) {
                    $w = Get-Json ('https://en.wikipedia.org/api/rest_v1/page/summary/' + [uri]::EscapeDataString(($title -replace ' ', '_')))
                    if ($w -and $w.type -eq 'standard') {
                        $u = $w.thumbnail.source
                        if ($w.originalimage -and $w.originalimage.width -le 2000 -and "$($w.originalimage.source)" -notmatch '\.svg$') { $u = $w.originalimage.source }
                        if ($u) { $res = Try-Url $u $key; if ($res) { break } }
                    }
                }
            }
        }
        if ($res -eq 'new') { $changed += $key }
    }
    try { $idx | ConvertTo-Json -Depth 4 | Set-Content $idxPath } catch {}
    return $changed
}

function Start-ArtRefresh($force) {
    if (-not $script:library.Count) { return }
    if ($script:artAsync) { $script:artQueued = $true; return }
    New-Item $script:artDir -ItemType Directory -Force | Out-Null
    $items = @($script:library | ForEach-Object { @{ Key = $_.Key; Launcher = $_.Launcher; Name = $_.Name; AppId = $_.AppId; CatalogItemId = $_.CatalogItemId; GogId = $_.GogId } })
    $fn = ${function:Get-ArtWork}.ToString()
    $script:artPs = [powershell]::Create()
    [void]$script:artPs.AddScript("param(`$a, `$d, `$f)`nfunction Get-ArtWork {`n$fn`n}`nGet-ArtWork `$a `$d `$f").AddArgument($items).AddArgument($script:artDir).AddArgument([bool]$force)
    $script:artAsync = $script:artPs.BeginInvoke()
    $script:artTimer.Start()
}
function Poll-Art {
    if (-not $script:artAsync -or -not $script:artAsync.IsCompleted) { return }
    $script:artTimer.Stop()
    $ps = $script:artPs; $ar = $script:artAsync; $script:artAsync = $null; $script:artPs = $null
    try {
        $keys = @($ps.EndInvoke($ar) | ForEach-Object { "$_" } | Where-Object { $_ })
        if ($keys.Count) {
            foreach ($k in $keys) { Clear-ArtCache $k }
            Load-Games; Show-GameDetail
            Log "Updated the picture for $($keys.Count) game(s)."
        }
    } catch {} finally { try { $ps.Dispose() } catch {} }
    if ($script:artQueued) { $script:artQueued = $false; Start-ArtRefresh $true }
}
$script:artTimer = New-Object Windows.Threading.DispatcherTimer
$script:artTimer.Interval = [TimeSpan]::FromMilliseconds(700)
$script:artTimer.Add_Tick({ Poll-Art })
$script:artEvery = New-Object Windows.Threading.DispatcherTimer
$script:artEvery.Interval = [TimeSpan]::FromHours(6)
$script:artEvery.Add_Tick({ Start-ArtRefresh $false })

$c.btnGameArt.Add_Click({
    $g = $script:selGame
    if (-not $g) { return }
    $d = New-Object Microsoft.Win32.OpenFileDialog -Property @{ Filter = 'Pictures (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png'; Title = "Choose a picture for $($g.Name)" }
    if ($d.ShowDialog() -ne $true) { return }
    try {
        New-Item $script:artDir -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $d.FileName (Get-ArtPath $g.Key) -Force
        Set-Content -Path (Join-Path $script:artDir "$($g.Key).custom") -Value 'custom'
        Clear-ArtCache $g.Key; Load-Games; Show-GameDetail; Log "Picture set for $($g.Name)."
    } catch { Log "Could not set the picture: $($_.Exception.Message)" }
})
$c.btnGameArtReset.Add_Click({
    $g = $script:selGame
    if (-not $g) { return }
    Remove-Item (Join-Path $script:artDir "$($g.Key).custom") -ErrorAction SilentlyContinue
    Remove-Item (Get-ArtPath $g.Key) -ErrorAction SilentlyContinue
    Clear-ArtCache $g.Key; Load-Games; Show-GameDetail
    Start-ArtRefresh $true; Log "Looking for the latest picture for $($g.Name)..."
})

# ----- boost engine -----
$script:sessPath = Join-Path $script:dataDir 'session.json'
$script:keepPrio = 'Discord', 'DiscordPTB', 'TeamSpeak', 'ts3client_win64', 'Mumble', 'obs64', 'obs32', 'Streamlabs OBS', 'Medal', 'Overwolf', 'Teams', 'ms-teams', 'Zoom', 'Skype',
    'EasyAntiCheat', 'EasyAntiCheat_EOS', 'EasyAntiCheat_Launcher', 'BEService', 'BEDaisy', 'vgc', 'vgtray', 'faceit', 'FACEITClient', 'EAAntiCheat.GameService', 'Javelin', 'ESEADriver2', 'Steam', 'steamwebhelper', 'EpicGamesLauncher', 'GalaxyClient'
try { Add-Type -AssemblyName Microsoft.VisualBasic; $script:ci = New-Object Microsoft.VisualBasic.Devices.ComputerInfo } catch { $script:ci = $null }

# fast process list (id, exe path, memory) - native when available, WMI as a fallback
function Get-ProcList {
    if (Test-Native) {
        foreach ($p in [Diagnostics.Process]::GetProcesses()) {
            $path = $null; try { $path = [Blu.Native]::GetPath($p.Id) } catch {}
            if ($path) { $m = 0; try { $m = $p.WorkingSet64 } catch {}; [pscustomobject]@{ Id = $p.Id; Path = $path; Mem = $m } }
        }
    } else {
        foreach ($w in Get-CimInstance Win32_Process -Property ProcessId, ExecutablePath, WorkingSetSize -ErrorAction SilentlyContinue) {
            if ($w.ExecutablePath) { [pscustomobject]@{ Id = [int]$w.ProcessId; Path = $w.ExecutablePath; Mem = [long]$w.WorkingSetSize } }
        }
    }
}
function Find-GameProcess($g) {
    $dir = "$($g.Dir)".TrimEnd('\')
    if (-not $dir) { return }
    $pre = $dir + '\'; $best = $null
    foreach ($w in Get-ProcList) {
        if ($w.Path.StartsWith($pre, [StringComparison]::OrdinalIgnoreCase) -and (-not $best -or $w.Mem -gt $best.Mem)) { $best = $w }
    }
    if ($best) { Get-Process -Id $best.Id -ErrorAction SilentlyContinue }
}
function Get-FreeMB {
    if ($script:ci) { return [int]($script:ci.AvailablePhysicalMemory / 1MB) }
    [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
}
function Trim-Memory($skipId) {
    if (-not (Test-Native)) { return }
    foreach ($p in [Diagnostics.Process]::GetProcesses()) {
        if ($p.Id -le 4 -or $p.Id -eq $skipId -or $p.Id -eq $PID -or $script:protectedProcs -contains $p.ProcessName) { continue }
        try { [Blu.Native]::Trim($p.Id) } catch {}
    }
}
function Sess-Reg($path, $name, $value, $kind = 'DWord') {
    $old = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
    $script:sess.Regs += , @($path, $name, [bool]$old, $(if ($old) { $old.$name } else { $null }), $kind)
    if (-not (Test-Path $path)) { New-Item $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $kind
}
function Launch-Game($g) {
    try {
        $l = "$($g.Launch)"
        if (-not $l) { Log "$($g.Name) has no start file yet. Press Locate and pick its .exe."; return }
        if ($l -match '^[A-Za-z.]+://') { Start-Process explorer.exe -ArgumentList $l }
        elseif ($l -like 'shell:*') { Start-Process explorer.exe -ArgumentList "`"$l`"" }
        elseif ($g.LaunchArgs) {
            $cmd = "`"$l`" $($g.LaunchArgs)"
            try { Start-Process runas.exe -ArgumentList ('/trustlevel:0x20000 "' + ($cmd -replace '"', '\"') + '"') -WindowStyle Hidden }
            catch { Start-Process -FilePath $l -ArgumentList "$($g.LaunchArgs)" }
        }
        else { Start-Process explorer.exe -ArgumentList "`"$l`"" }
    } catch { Log "Could not start $($g.Name): $($_.Exception.Message)" }
}
# games with anti-cheat: bluFPS never opens the game process itself, it only optimizes everything around it
$script:acGames = 'valorant', 'league of legends', 'fortnite', 'apex legends', 'call of duty', 'warzone', 'rainbow six', 'pubg', 'battlegrounds', 'destiny 2', 'escape from tarkov', 'fall guys', 'dead by daylight', 'halo infinite', 'the finals', 'marvel rivals', 'faceit', 'rust'
function Test-KnownAntiCheat($name) {
    $n = "$name".ToLower()
    foreach ($k in $script:acGames) { if ($n.Contains($k)) { return $true } }
    return $false
}
function Get-GameProfile($g) {
    $reason = $null
    if (Test-KnownAntiCheat $g.Name) { $reason = 'known anti-cheat game' }
    if (-not $reason -and $g.Dir -and (Test-Path -LiteralPath $g.Dir -PathType Container)) {
        try {
            $ac = '(?i)^(EasyAntiCheat|BattlEye|BEService|BEDaisy|EAAntiCheat|Ricochet|Vanguard|faceit)'
            $l1 = @(Get-ChildItem -LiteralPath $g.Dir -Force -ErrorAction SilentlyContinue)
            $hit = $l1 | Where-Object { $_.Name -match $ac } | Select-Object -First 1
            if (-not $hit) {
                foreach ($d in ($l1 | Where-Object { $_.PSIsContainer } | Select-Object -First 60)) {
                    $hit = Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $ac } | Select-Object -First 1
                    if ($hit) { break }
                }
            }
            if ($hit) { $reason = $hit.Name }
        } catch {}
    }
    if (-not $reason -and (Get-Process -Name vgc, vgtray, faceit -ErrorAction SilentlyContinue)) { $reason = 'Vanguard / FACEIT is running' }
    return @{ Protected = [bool]$reason; Reason = $reason }
}
function Apply-ProcessTweaks {
    $sn = $script:sess; $p = $sn.Proc; $cfg = $script:S
    if ($sn.Protected) { Log 'Anti-cheat game: the game itself is left untouched. Everything around it is still optimized.' }
    else {
        if ($cfg.Prio) { try { $p.PriorityClass = 'High'; $p.PriorityBoostEnabled = $true; Log "High priority set for $($p.ProcessName)" } catch {} }
        if (Test-Power) { try { [void][Blu.Power]::NoThrottle($p.Id); [void][Blu.Power]::MemPrio($p.Id, 5); if ($cfg.GpuPrio) { if ([Blu.Power]::GpuPrio($p.Id, 4)) { Log 'GPU priority raised for the game.' } } } catch {} }
    }
    if ($cfg.Gpu) {
        try { $exe = $p.Path; if ($exe) { Set-Reg 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' $exe 'GpuPreference=2;' 'String' } } catch {}
    }
    Log "Boost active for $($sn.Game.Name). Have fun!"
}

# what must be undone is also written to disk, so a crash or power cut can be repaired next start
function Save-SessionState {
    $sn = $script:sess
    if (-not $sn) { return }
    New-Item $script:dataDir -ItemType Directory -Force | Out-Null
    ConvertTo-Json -InputObject @{ Excl = $sn.Excl; Plan = $sn.Plan; TempPlan = $sn.TempPlan; Services = @($sn.Services); Regs = @($sn.Regs); Closed = @($sn.Closed | ForEach-Object { $_.Path }) } -Depth 5 | Set-Content $script:sessPath
}
function Clean-OldPlans {
    foreach ($l in @((Invoke-Native 'powercfg' '/list') -split "`r?`n")) {
        if ($l -match '([0-9a-fA-F-]{36})\s+\(bluFPS Boost\)') {
            $g = $Matches[1]
            if ($l -notmatch '\*\s*$' -and $g -ne "$($script:S.BoostPlan)") { [void](Invoke-Native 'powercfg' "/delete $g") }
        }
    }
}
function Recover-Session {
    if (-not (Test-Path $script:sessPath)) { return }
    try {
        $j = Get-Content $script:sessPath -Raw | ConvertFrom-Json
        $regs = @(); if ($j.Regs) { $regs = @($j.Regs) }
        $script:sess = @{ Game = @{ Name = 'your last game' }; Proc = $null; Waiting = $false; Excl = $j.Excl; Plan = $j.Plan; TempPlan = $j.TempPlan
            Services = @($j.Services | Where-Object { $_ }); Regs = $regs; Prio = @()
            Closed = @(@($j.Closed) | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Name = ''; Path = $_ } }) }
        Log 'bluFPS was closed during a boost last time. Restoring your PC...'
        End-Boost
    } catch { Remove-Item $script:sessPath -ErrorAction SilentlyContinue }
}

$script:sTick = 0; $script:pbPrev = @{}; $script:pbT = $null; $script:memAt = $null; $script:freeC = $null
# less CPU time + efficiency mode + low I/O + low memory priority for one app; remembered so it can be put back
$script:browserProcs = 'chrome', 'msedge', 'firefox', 'brave', 'opera', 'vivaldi'
function Throttle-Process($p, $sn) {
    if ($script:browserProcs -contains $p.ProcessName) { return $false }
    try {
        $old = "$($p.PriorityClass)"
        if ($old -ne 'Normal' -and $old -ne 'AboveNormal') { return $false }
        $p.PriorityClass = 'BelowNormal'
    } catch { return $false }
    if ($script:S.Eco -and (Test-Power)) { try { [void][Blu.Power]::Eco($p.Id, $true); [void][Blu.Power]::IoPrio($p.Id, 0); [void][Blu.Power]::MemPrio($p.Id, 1) } catch {} }
    $sn.Prio += [pscustomobject]@{ Id = $p.Id; Name = $p.ProcessName; Old = $old }
    return $true
}
function Restore-Process($pr) {
    try { $p = Get-Process -Id $pr.Id -ErrorAction Stop } catch { return }
    if ($p.ProcessName -ne $pr.Name) { return }
    try { $p.PriorityClass = $pr.Old } catch {}
    if (Test-Power) { try { [void][Blu.Power]::Eco($pr.Id, $false); [void][Blu.Power]::IoPrio($pr.Id, 2); [void][Blu.Power]::MemPrio($pr.Id, 5); [void][Blu.Power]::GpuPrio($pr.Id, 2) } catch {} }
}
# ProBalance: while you play, any other app that starts hogging the CPU is throttled on the spot
function Invoke-ProBalance($sn) {
    $now = Get-Date; $dt = 0.0; if ($script:pbT) { $dt = ($now - $script:pbT).TotalSeconds }
    $cores = [Environment]::ProcessorCount; $cur = @{}
    $gdir = "$($sn.Game.Dir)".TrimEnd('\') + '\'
    foreach ($p in [Diagnostics.Process]::GetProcesses()) {
        $id = $p.Id; if ($id -le 4) { continue }
        $t = $null; try { $t = $p.TotalProcessorTime.TotalSeconds } catch { continue }
        $cur[$id] = $t
        if ($dt -gt 0 -and $script:pbPrev.ContainsKey($id)) {
            $cpu = ($t - $script:pbPrev[$id]) / $dt / $cores * 100
            if ($cpu -gt 10 -and $id -ne $PID -and $id -ne $sn.Proc.Id) {
                $n = $p.ProcessName
                if ($script:protectedProcs -contains $n -or $script:keepPrio -contains $n -or $n -eq $sn.Proc.ProcessName) { continue }
                if (@($sn.Prio) | Where-Object { $_.Id -eq $id }) { continue }
                $path = $null; if (Test-Native) { try { $path = [Blu.Native]::GetPath($id) } catch {} }
                if ($path -and $path.StartsWith($gdir, [StringComparison]::OrdinalIgnoreCase)) { continue }
                if (Throttle-Process $p $sn) { Log "Kept $n from taking CPU from the game." }
            }
        }
    }
    $script:pbPrev = $cur; $script:pbT = $now
}
# keeps memory smooth: when the truly free list runs low but cache is large, purge the stale standby cache
function Keep-Memory {
    if (-not $script:ci -or -not (Test-Power)) { return }
    if ($script:memAt -and ((Get-Date) - $script:memAt).TotalSeconds -lt 45) { return }
    if ($null -eq $script:freeC) { try { $script:freeC = New-Object Diagnostics.PerformanceCounter -ArgumentList 'Memory', 'Free & Zero Page List Bytes'; [void]$script:freeC.NextValue() } catch { $script:freeC = $false } }
    if (-not $script:freeC) { return }
    $free = [double]$script:freeC.NextValue(); $avail = [double]$script:ci.AvailablePhysicalMemory; $tot = [double]$script:ci.TotalPhysicalMemory
    if ($free -lt [math]::Max(1GB, $tot * 0.06) -and ($avail - $free) -gt 1.5GB) {
        $script:memAt = Get-Date
        if ([Blu.Power]::Purge()) { Log 'Cleared stale cached memory to keep the game smooth.' }
    }
}

$script:planVer = 3
function Get-ActivePlan { try { return "$((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' -ErrorAction Stop).ActivePowerScheme)" } catch { return '' } }
function Test-PlanExists($g) { return [bool]($g -and (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$g")) }
# the tuned plan is built ONCE and reused, so a boost only has to switch to it
function Ensure-BoostPlan {
    $g = "$($script:S.BoostPlan)"
    if ($g -and $script:S.BoostPlanVer -eq $script:planVer -and (Test-PlanExists $g)) { return $g }
    if ($g -and (Test-PlanExists $g)) { [void](Invoke-Native 'powercfg' "/delete $g") }
    $cur = Get-ActivePlan
    $dup = [regex]::Match((Invoke-Native 'powercfg' "-duplicatescheme $hp"), '[0-9a-fA-F-]{36}').Value
    if (-not $dup -and $cur) { $dup = [regex]::Match((Invoke-Native 'powercfg' "-duplicatescheme $cur"), '[0-9a-fA-F-]{36}').Value }
    if (-not $dup) { return '' }
    $tune = @('SUB_PROCESSOR PROCTHROTTLEMIN 100', 'SUB_PROCESSOR PROCTHROTTLEMAX 100', 'SUB_PROCESSOR CPMINCORES 100', 'SUB_PROCESSOR PERFBOOSTMODE 2',
              'SUB_PCIEXPRESS ASPM 0', '2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0', 'SUB_VIDEO VIDEOIDLE 0', 'SUB_PROCESSOR PERFEPP 0', 'SUB_PROCESSOR PERFBOOSTPOL 100')
    $chain = @("powercfg /changename $dup `"bluFPS Boost`"")
    foreach ($tv in $tune) { $chain += "powercfg /setacvalueindex $dup $tv"; $chain += "powercfg /setdcvalueindex $dup $tv" }
    [void](Invoke-Native 'cmd.exe' ('/c ' + ($chain -join ' & ')))
    $script:S.BoostPlan = $dup; $script:S.BoostPlanVer = $script:planVer; Save-Settings
    return $dup
}
# runs a hidden command line without waiting for it
function Start-Hidden($line) {
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo 'cmd.exe', ('/c ' + $line)
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
        [void][Diagnostics.Process]::Start($psi)
    } catch {}
}

function Boost-Safe($g, $launch) {
    if (-not $g) { Log 'Pick a game in the list first.'; return }
    try { Start-Boost $g $launch }
    catch {
        Log "Boost stopped: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
        try { End-Boost } catch {}
        $script:sess = $null
        throw
    }
}
function Start-Boost($g, $launch) {
    if ("$($g.Profile)" -eq 'Off') { Log "$($g.Name) is set to Off - bluFPS leaves it alone."; if ($launch) { Launch-Game $g }; return }
    if ($script:sess) { Log 'A boost is already active. Press Restore first.'; return }
    $cfg = $script:S
    $t0 = Get-Date
    $p0 = Find-GameProcess $g
    if (-not $launch -and -not $p0) { Log "$($g.Name) is not running. Start it first, or use Boost and Play."; return }
    if ($p0) { $launch = $false }
    $script:sess = @{ Game = $g; Proc = $null; Closed = @(); Plan = $null; TempPlan = $null; Services = @(); Regs = @(); Prio = @(); Waiting = $true; Deadline = (Get-Date).AddMinutes(4) }
    $sn = $script:sess
    $script:pbPrev = @{}; $script:pbT = $null; $script:sTick = 0; $script:memAt = $null
    $prof = Get-GameProfile $g; $sn.Protected = $prof.Protected
    $sn.CfgBackup = Apply-GameProfile $g
    if ($script:lastAutoPick) { Log "Auto profile: using $($script:lastAutoPick) settings for $($g.Name)." }
    foreach ($sk in @($script:lastSkips)) { Log "Skipped - $sk" }
    if ($prof.Protected) { Log "Anti-cheat detected ($($prof.Reason)): game-process tweaks are skipped to keep your account safe." }
    Log "Boosting $($g.Name)..."
    $before = Get-FreeMB
    $nClosed = 0; $nSvc = 0; $nLow = 0

    # 1) system commands go out in ONE hidden helper that nothing waits for (power plan, DNS, services)
    $fast = @()
    if ($cfg.Plan) {
        $bp = Ensure-BoostPlan
        $cur = Get-ActivePlan
        if ($bp -and $cur -and $cur -ne $bp) { $sn.Plan = $cur; $fast += "powercfg /setactive $bp" }
    }
    if ($cfg.Dns) { $fast += 'ipconfig /flushdns' }
    if ($cfg.Svc) {
        try {
            foreach ($sv in @(Get-Service -Name 'SysMain', 'WSearch', 'DiagTrack' -ErrorAction SilentlyContinue | Where-Object { -not ($_.Name -eq 'SysMain' -and (Test-HddDrive $g.Dir)) })) {
                if ($sv.Status -eq 'Running' -and $sv.CanStop) { $fast += "sc.exe stop $($sv.Name)"; $sn.Services += $sv.Name; $nSvc++ }
            }
        } catch {}
    }
    if ($fast.Count) { Start-Hidden ($fast -join ' & ') }

    # 2) Windows settings that are put back afterwards (registry: instant)
    if ($cfg.GameMode) {
        Sess-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
        Sess-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
        Sess-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    }
    if ($cfg.Sched) {
        Sess-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38
        Sess-Reg $mm 'SystemResponsiveness' 0
        Sess-Reg $mm 'NetworkThrottlingIndex' 0xffffffff
        Sess-Reg "$mm\Tasks\Games" 'GPU Priority' 8
        Sess-Reg "$mm\Tasks\Games" 'Priority' 6
        Sess-Reg "$mm\Tasks\Games" 'Scheduling Category' 'High' 'String'
        Sess-Reg "$mm\Tasks\Games" 'SFIO Priority' 'High' 'String'
    }
    if ($cfg.Excl) {
        $gd = "$($g.Dir)".TrimEnd('\')
        if ($gd -and (Test-Path -LiteralPath $gd)) {
            try {
                $have = @((Get-MpPreference -ErrorAction Stop).ExclusionPath)
                if ($have -notcontains $gd) { Add-MpPreference -ExclusionPath $gd -ErrorAction Stop; $sn.Excl = $gd; Log 'Windows Defender will skip the game folder while you play.' }
            } catch {}
        }
    }
    if ($cfg.Notify) { Sess-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' 'ToastEnabled' 0 }

    # 3) close background apps: ask them all at once, give them a moment, end whatever is left
    if ($cfg.CloseApps) {
        $names = @(@($cfg.KillApps) + @($cfg.CustomApps) | Select-Object -Unique | Where-Object { $_ -and $script:protectedProcs -notcontains $_ })
        $procs = @(); if ($names.Count) { $procs = @(Get-Process -Name $names -ErrorAction SilentlyContinue) }
        $waitFor = @()
        $browsers = 'chrome', 'msedge', 'firefox', 'brave', 'opera', 'vivaldi'
        foreach ($p in $procs) {
            $isBrowser = ($browsers -contains $p.ProcessName)
            if ($isBrowser -and $p.MainWindowHandle -eq 0) { continue }
            $path = $null; try { $path = if (Test-Native) { [Blu.Native]::GetPath($p.Id) } else { $p.Path } } catch {}
            $asked = $false; try { $asked = $p.CloseMainWindow() } catch {}
            if ($asked) { $waitFor += $p; if ($path) { $sn.Closed += [pscustomobject]@{ Name = $p.ProcessName; Path = $path } } }
        }
        $limit = (Get-Date).AddMilliseconds(1200)
        while ($waitFor.Count -and (Get-Date) -lt $limit) {
            Start-Sleep -Milliseconds 40; Pump
            $waitFor = @($waitFor | Where-Object { try { -not $_.HasExited } catch { $false } })
        }
        $nClosed = @($sn.Closed).Count
        if ($nClosed) { Log "Closed (asked politely): $((@($sn.Closed | ForEach-Object { $_.Name }) | Select-Object -Unique) -join ', ')" }
    }
    Save-SessionState

    # 4) START THE GAME NOW - the rest of the boost finishes while it loads
    if ($launch) { Launch-Game $g; Log "Launching $($g.Name)..." }
    Pump

    # 5) everything else you have open: less CPU, efficiency mode, low I/O and memory priority
    if ($cfg.BgPrio) {
        foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
            if ($p.MainWindowHandle -eq 0 -or $p.Id -eq $PID -or ($p0 -and $p.Id -eq $p0.Id)) { continue }
            if ($script:protectedProcs -contains $p.ProcessName -or $script:keepPrio -contains $p.ProcessName) { continue }
            if (Throttle-Process $p $sn) { $nLow++ }
        }
    }

    # 6) memory
    if ($cfg.Ram) {
        $usedPct = 0; if ($script:ci) { $usedPct = 100 * (1 - ([double]$script:ci.AvailablePhysicalMemory / [double]$script:ci.TotalPhysicalMemory)) }
        if ($usedPct -ge 80) { $skip = 0; if ($p0) { $skip = $p0.Id }; Trim-Memory $skip; Log "Memory was $([int]$usedPct)% full: trimmed idle memory held by other programs." }
        else { Log "Memory is only $([int]$usedPct)% used, so nothing was cleared (clearing RAM does not add FPS by itself)." }
    }
    $freed = [math]::Max(0, (Get-FreeMB) - $before)
    Save-SessionState
    Log ('Boost ready in {0:N1}s: freed about {1} MB RAM, closed {2} process(es), paused {3} service(s), eased {4} app(s).' -f ((Get-Date) - $t0).TotalSeconds, $freed, $nClosed, $nSvc, $nLow)
    if ($p0) { $sn.Proc = $p0; $sn.Waiting = $false; $script:watchName = $p0.ProcessName; Apply-ProcessTweaks }
    Update-SessionUi
}
function End-BoostCore {
    $sn = $script:sess
    if (-not $sn) { return }
    $script:sess = $null
    $script:autoBlock = (Get-Date).AddSeconds(90)
    try {
        $chain = @()
        if ($sn.Plan) { $chain += "powercfg /setactive $($sn.Plan)" }
        if ($sn.TempPlan) { $chain += "powercfg /delete $($sn.TempPlan)" }
        foreach ($svc in @($sn.Services)) { $chain += "sc.exe start $svc" }
        if ($chain.Count) { [void](Invoke-Native 'cmd.exe' ('/c ' + ($chain -join ' & '))) }
    } catch {}
    foreach ($r in @($sn.Regs)) {
        try {
            if ($r[2]) { Set-ItemProperty -Path $r[0] -Name $r[1] -Value $r[3] -Type $(if (@($r).Count -gt 4 -and $r[4]) { $r[4] } else { 'DWord' }) }
            else { Remove-ItemProperty -Path $r[0] -Name $r[1] -ErrorAction SilentlyContinue }
        } catch {}
    }
    foreach ($pr in @($sn.Prio)) { Restore-Process $pr }
    if ($script:S.RestoreApps -and @($sn.Closed).Count) {
        $paths = @($sn.Closed | ForEach-Object { $_.Path } | Select-Object -Unique)
        foreach ($path in $paths) { try { Start-Process explorer.exe -ArgumentList "`"$path`"" } catch {} }
        Log "Reopened $($paths.Count) app(s)."
    }
    if ($sn.Excl) { try { Remove-MpPreference -ExclusionPath $sn.Excl -ErrorAction Stop } catch {} }
    Remove-Item $script:sessPath -ErrorAction SilentlyContinue
    $script:watchName = $null
    Log "Restored your PC after $($sn.Game.Name)."
    Update-SessionUi
}
function Check-AutoBoost {
    if ($script:autoBlock -and (Get-Date) -lt $script:autoBlock) { return }
    if (-not $script:library.Count) { return }
    $dirs = @($script:library | Where-Object { $_.Dir } | ForEach-Object { @{ G = $_; D = ("$($_.Dir)".TrimEnd('\') + '\') } })
    foreach ($w in Get-ProcList) {
        foreach ($e in $dirs) {
            if ($w.Path.StartsWith($e.D, [StringComparison]::OrdinalIgnoreCase)) {
                $proc = Get-Process -Id $w.Id -ErrorAction SilentlyContinue
                if ($proc -and $proc.MainWindowHandle -ne 0) { Log "Auto-boost: $($e.G.Name) detected."; Start-Boost $e.G $false; return }
            }
        }
    }
}
function Update-Session {
    $sn = $script:sess
    if (-not $sn) {
        if ($script:S.AutoBoost -and ($script:tick % 5 -eq 0)) { Check-AutoBoost }
        return
    }
    if ($sn.Waiting) {
        $p = Find-GameProcess $sn.Game
        if ($p) { $sn.Proc = $p; $sn.Waiting = $false; $script:watchName = $p.ProcessName; Apply-ProcessTweaks }
        elseif ((Get-Date) -gt $sn.Deadline) { Log "Could not find $($sn.Game.Name) running, so the boost was ended."; End-Boost; return }
    } elseif ($sn.Proc) {
        $alive = $true
        try { $alive = -not $sn.Proc.HasExited } catch { $alive = $false }
        if ($alive) {
            if ($script:S.Prio -and -not $sn.Protected) { try { if ($sn.Proc.PriorityClass -ne 'High') { $sn.Proc.PriorityClass = 'High' } } catch {} }
            $script:sTick++
            if ($script:S.ProBal -and ($script:sTick % 4 -eq 0)) { try { Invoke-ProBalance $sn } catch {} }
            if ($script:S.MemKeep -and ($script:sTick % 5 -eq 0)) { try { Keep-Memory } catch {} }
        } else {
            $next = Find-GameProcess $sn.Game
            if ($next) { $sn.Proc = $next; $script:watchName = $next.ProcessName; Apply-ProcessTweaks }
            elseif ($script:S.AutoRestore) { Log "$($sn.Game.Name) closed."; End-Boost; return }
            else { $sn.Proc = $null }
        }
    }
    Update-SessionUi
}

# ----- settings page -----
function New-SwitchRow($title, $desc) {
    $sp = New-Object Windows.Controls.StackPanel
    [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $title; FontSize = 14 }))
    if ($desc) { [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $desc; FontSize = 12; Foreground = '#6C7CA3'; TextWrapping = 'Wrap' })) }
    New-Object Windows.Controls.CheckBox -Property @{ Content = $sp; Margin = '0,0,0,14' }
}
function Save-SettingsFromUi {
    $cfg = $script:S
    foreach ($k in $script:levelKeys) { if ([bool]$cfg[$k] -ne [bool]$script:setBoxes[$k].IsChecked) { $cfg.Level = 'Custom'; break } }
    foreach ($k in 'AutoBoost', 'AutoRestore', 'RestoreApps', 'Prio', 'Plan', 'CloseApps', 'Ram', 'Dns', 'GameMode', 'Gpu', 'Svc', 'BgPrio', 'Sched', 'Notify', 'Eco', 'ProBal', 'MemKeep', 'GpuPrio', 'Excl', 'AutoAdd') { $cfg[$k] = [bool]$script:setBoxes[$k].IsChecked }
    $cfg.KillApps = @($script:killBoxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
    Save-Settings
    Show-GameDetail
}
function Set-StartupTask {
    $exe = Join-Path $script:AppRoot 'bluFPS.exe'
    $box = $script:setBoxes['StartWithWindows']
    if ($box.IsChecked) {
        if (-not (Test-Path $exe)) { $box.IsChecked = $false; Log 'Start with Windows needs the installed bluFPS.exe (use the Setup installer).'; return }
        $tr = '\"' + $exe + '\" /minimized'
        [void](Invoke-Native 'schtasks' ('/Create /TN "bluFPS" /TR "' + $tr + '" /SC ONLOGON /RL HIGHEST /F'))
        if ($LASTEXITCODE -eq 0) { Log 'bluFPS will start with Windows.' } else { $box.IsChecked = $false; Log 'Could not create the startup task.' }
    } else {
        [void](Invoke-Native 'schtasks' '/Delete /TN "bluFPS" /F'); Log 'bluFPS will no longer start with Windows.'
    }
}
function Sync-StartupBox {
    try { [void](Invoke-Native 'schtasks' '/Query /TN "bluFPS"'); $script:setBoxes['StartWithWindows'].IsChecked = ($LASTEXITCODE -eq 0) } catch {}
}
function Load-SettingsUi {
    $cfg = $script:S
    $c.setPanel.Children.Clear(); $script:setBoxes = @{}; $script:killBoxes = @()
    $sections = @(
        @{ Head = 'GENERAL'; Items = @(
            @('StartWithWindows', 'Start bluFPS with Windows', 'Opens bluFPS minimized when you sign in.'),
            @('AutoBoost', 'Auto-boost when a game starts', 'If you start a game from your library any other way, bluFPS boosts it automatically.'),
            @('AutoRestore', 'Restore everything when the game closes', 'Puts your settings back the moment the game quits.'),
            @('RestoreApps', 'Reopen the apps I closed', 'After the game, apps that bluFPS closed are opened again.'),
            @('AutoAdd', 'Add games I install automatically', 'New games found by a scan go straight into your library. Turn off to pick them yourself in Add games.')) },
        @{ Head = 'WHAT A BOOST DOES'; Items = @(
            @('Prio', 'High CPU priority for the game', 'Gives the game first pick of the processor.'),
            @('Plan', 'Tuned power plan while playing', 'A temporary plan: no core parking, max CPU boost, PCIe and USB power saving off. Your old plan comes back afterwards.'),
            @('CloseApps', 'Close background apps', 'Closes the apps ticked below, all at once, to free CPU, RAM and network.'),
            @('BgPrio', 'Lower the priority of other open apps', 'Everything else you have open gets less CPU time while you play. Voice chat and streaming apps are left alone.'),
            @('Svc', 'Pause background services', 'Pauses Windows Search and telemetry while you play (and SysMain, except on hard drives where it helps), then starts them again. Only in the Extreme profile.'),
            @('Sched', 'Favor the game in the Windows scheduler', 'Gives the foreground game longer, stronger time slices. Put back afterwards.'),
            @('Ram', 'Free memory when RAM is nearly full', 'Only acts when 80% or more of your RAM is used. Clearing RAM does not add FPS by itself - it only helps when memory is the problem.'),
            @('Notify', 'Silence notification pop-ups', 'No toast pop-ups stealing focus while you play. Put back afterwards.'),
            @('Dns', 'Flush the DNS cache', 'Clears stale lookups so game servers resolve fresh.'),
            @('GameMode', 'Game Mode on, game recording off', 'Switched on while you play, then put back.'),
            @('Gpu', 'Use the high-performance GPU', 'For laptops with two GPUs. Stays set for that game and applies the next time it starts.'),
            @('Eco', 'Efficiency mode for other apps', 'Other apps move to efficient cores with low disk and memory priority, leaving the fast cores to the game. Put back afterwards.'),
            @('ProBal', 'Stop CPU hogs while you play (ProBalance)', 'If another app suddenly hogs the processor during a game, it is slowed down on the spot.'),
            @('MemKeep', 'Keep memory smooth while playing', 'Clears stale cached memory when free memory runs low, which cures sudden stutters.'),
            @('GpuPrio', 'GPU priority for the game', 'The game gets first call on the graphics card; other apps get a lower GPU priority. Helps when browsers, video or overlays share the GPU.'),
            @('Excl', 'Let Windows Defender skip the game folder while playing', 'Lowers antivirus protection for that one folder while you play, then removes the exclusion. Leave this off unless you understand the trade-off - it is never part of a profile.')) })
    foreach ($sec in $sections) {
        [void]$c.setPanel.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $sec.Head; Foreground = '#6C7CA3'; FontSize = 11; Margin = '0,4,0,10' }))
        foreach ($it in $sec.Items) {
            $cb = New-SwitchRow $it[1] $it[2]
            if ($it[0] -eq 'StartWithWindows') { $cb.IsChecked = $false; $cb.Add_Click({ Set-StartupTask }) }
            else { $cb.IsChecked = [bool]$cfg[$it[0]]; $cb.Add_Click({ Save-SettingsFromUi }) }
            $script:setBoxes[$it[0]] = $cb
            [void]$c.setPanel.Children.Add($cb)
        }
    }
    [void]$c.setPanel.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = 'APPS TO CLOSE DURING A BOOST'; Foreground = '#6C7CA3'; FontSize = 11; Margin = '0,8,0,10' }))
    $apps = @(); foreach ($a in $script:knownApps) { $apps += , @($a[0], $a[1]) }; foreach ($n in @($cfg.CustomApps)) { $apps += , @($n, $n) }
    foreach ($a in $apps) {
        $cb = New-SwitchRow "$($a[0])" $null
        $cb.Tag = $a[1]; $cb.IsChecked = (@($cfg.KillApps) -contains $a[1]); $cb.Margin = '0,0,0,8'
        $cb.Add_Click({ Save-SettingsFromUi })
        $script:killBoxes += $cb; [void]$c.setPanel.Children.Add($cb)
    }
}

# ----- events -----
$c.navGame.Add_Click({ Show-Page 'Game' })
$c.navSet.Add_Click({ Show-Page 'Set' })
$c.gameSearch.Add_TextChanged({ Load-Games })
$c.gameList.Add_SelectionChanged({
    $i = $c.gameList.SelectedIndex
    if ($i -ge 0 -and $i -lt $script:libView.Count) { $script:selGame = $script:libView[$i]; Show-GameDetail }
})
$c.btnGameScan.Add_Click({ Guard 'btnGameScan' { Start-GameScan 'manual' } })
$c.btnGameFolder.Add_Click({ Guard 'btnGameFolder' { Add-ScanFolder } })
$c.btnGameAdd.Add_Click({ Guard 'btnGameAdd' {
    $c.addOverlay.Visibility = 'Visible'
    Build-AddList
    if (-not $script:detected.Count -and -not $script:scanPs) { Start-GameScan 'overlay' }
} })
$c.btnAddClose.Add_Click({ Guard 'btnAddClose' { $c.addOverlay.Visibility = 'Collapsed' } })
$c.btnAddScan.Add_Click({ Guard 'btnAddScan' { Start-GameScan 'overlay' } })
$c.btnAddExe.Add_Click({ Guard 'btnAddExe' { Add-ManualExe } })
$c.btnAddFolder.Add_Click({ Guard 'btnAddFolder' { Add-ScanFolder } })
$c.btnAddClear.Add_Click({ Guard 'btnAddClear' { $script:S.ScanFolders = @(); Save-Settings; Build-AddList; $c.addText.Text = 'Extra scan folders forgotten. Games already in your library stay.' } })
$c.btnAddSel.Add_Click({ Guard 'btnAddSel' {
    $pick = @(); foreach ($b in $script:addBoxes) { if ($b.Box.IsChecked) { $pick += $b.Game } }
    if (-not $pick.Count) { $c.addText.Text = 'Tick the games you want first, or press Add all new.'; return }
    $n = Add-ToLibrary $pick
    Save-Library; Load-Games; Build-AddList; Start-ArtRefresh $false
    $c.addText.Text = "$n game(s) added to Game Boost."; Log "$n game(s) added."
} })
$c.btnAddAll.Add_Click({ Guard 'btnAddAll' {
    $n = Add-ToLibrary @($script:detected)
    Save-Library; Load-Games; Build-AddList; Start-ArtRefresh $false
    $c.addText.Text = $(if ($n) { "$n game(s) added to Game Boost." } else { 'Everything that was found is already in your library.' }); if ($n) { Log "$n game(s) added." }
} })
$c.btnLocate.Add_Click({ Guard 'btnLocate' {
    $g = $script:selGame; if (-not $g) { return }
    $d = New-Object Microsoft.Win32.OpenFileDialog -Property @{ Filter = 'Game executable (*.exe)|*.exe'; Title = "Select the .exe for $($g.Name)" }
    if ($g.Dir -and (Test-Path -LiteralPath $g.Dir)) { $d.InitialDirectory = $g.Dir }
    if ($d.ShowDialog() -eq $true) {
        Set-Prop $g 'Exe' $d.FileName; Set-Prop $g 'Dir' (Split-Path $d.FileName)
        if ("$($g.Launch)" -notmatch '^[A-Za-z.]+://|^shell:') { Set-Prop $g 'Launch' $d.FileName }
        Save-Library; Load-Games; Show-GameDetail; Log "$($g.Name) now points to $($d.FileName)"
    }
} })
$c.btnOpenDir.Add_Click({ Guard 'btnOpenDir' {
    $g = $script:selGame
    if ($g -and $g.Dir -and (Test-Path -LiteralPath $g.Dir)) { Start-Process explorer.exe -ArgumentList "`"$($g.Dir)`"" }
    else { Log 'That folder does not exist any more. Press Locate to point bluFPS at the game.' }
} })
$c.btnRemoveGame.Add_Click({ Guard 'btnRemoveGame' {
    $g = $script:selGame
    if (-not $g) { return }
    $script:library = @($script:library | Where-Object { $_.Key -ne $g.Key })
    $script:removed = @(@($script:removed) + $g.Key + ('name:' + (Norm-Game $g.Name)) | Select-Object -Unique)
    Save-Library; $script:selGame = $null; Load-Games; Show-GameDetail
    Log "Removed $($g.Name) from your list. It stays out until you add it again in Add games."
} })
$c.btnPlay.Add_Click({ Guard 'Boost and Play' { Boost-Safe $script:selGame $true } })
$c.btnBoostOnly.Add_Click({ Guard 'Boost' { Boost-Safe $script:selGame $false } })
$c.btnRestore.Add_Click({ Guard 'Restore' { try { End-Boost } finally { $script:sess = $null } } })
$c.btnKillAdd.Add_Click({
    $n = ("$($c.killAdd.Text)".Trim() -replace '\.exe$', '')
    if ($n -notmatch '^[\w .()-]+$') { Log 'Type a process name such as Discord.'; return }
    if ($script:protectedProcs -contains $n) { Log "$n is a Windows or bluFPS process and cannot be closed."; return }
    if ((@($script:S.CustomApps) -contains $n) -or ($script:knownApps | Where-Object { $_[1] -eq $n })) { Log "$n is already in the list."; return }
    $script:S.CustomApps = @($script:S.CustomApps) + $n
    $script:S.KillApps = @($script:S.KillApps) + $n
    Save-Settings; $c.killAdd.Text = ''; Load-SettingsUi; Show-GameDetail; Log "Added $n to the apps to close."
})
$c.btnSetReset.Add_Click({
    Remove-Item $script:setPath -ErrorAction SilentlyContinue
    $script:S = Get-Settings; Load-SettingsUi; Sync-StartupBox; Show-GameDetail; Log 'Settings reset to defaults.'
})
$c.btnOpenData.Add_Click({ New-Item $script:dataDir -ItemType Directory -Force | Out-Null; Start-Process explorer.exe -ArgumentList "`"$($script:dataDir)`"" })

# ---------- Tools: cleaner, startup manager, uninstaller, monitor, backup & restore ----------
$script:toolTab = 'Clean'
function Format-Size($b) {
    $b = [double]$b
    if ($b -ge 1GB) { return ('{0:N1} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N0} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0:N0} KB' -f ($b / 1KB)) }
    return ('{0:N0} B' -f $b)
}
function New-Txt($text, $size, $color) {
    New-Object Windows.Controls.TextBlock -Property @{ Text = "$text"; FontSize = $size; Foreground = $color; TextTrimming = 'CharacterEllipsis' }
}

# ----- background jobs, so big tasks never freeze the window -----
$script:bgJobs = New-Object System.Collections.ArrayList
function Start-Bg($scriptText, $argList, $onDone) {
    $ps = [powershell]::Create()
    [void]$ps.AddScript($scriptText)
    foreach ($a in @($argList)) { [void]$ps.AddArgument($a) }
    [void]$script:bgJobs.Add(@{ Ps = $ps; Ar = $ps.BeginInvoke(); Done = $onDone })
    $script:bgTimer.Start()
}
function Poll-Bg {
    foreach ($j in @($script:bgJobs)) {
        if (-not $j.Ar.IsCompleted) { continue }
        [void]$script:bgJobs.Remove($j)
        $res = @(); $err = $null
        try { $res = @($j.Ps.EndInvoke($j.Ar)) } catch { $err = $_ }
        try { $j.Ps.Dispose() } catch {}
        try { & $j.Done $res $err } catch { Log "Background task error: $($_.Exception.Message)" }
    }
    if ($script:bgJobs.Count -eq 0) { $script:bgTimer.Stop() }
}
$script:bgTimer = New-Object Windows.Threading.DispatcherTimer
$script:bgTimer.Interval = [TimeSpan]::FromMilliseconds(400)
$script:bgTimer.Add_Tick({ Poll-Bg })

# ----- Backup & restore -----
$script:bkDir = Join-Path $script:dataDir 'backups'
$script:regDone = @{}
$script:regSets = @{
    startup = @('HKCU\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved', 'HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved')
    tweaks = @('HKCU\System\GameConfigStore', 'HKCU\Software\Microsoft\GameBar', 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR',
        'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile', 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers',
        'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl', 'HKCU\Control Panel\Mouse', 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications')
}
function New-RegBackup($label, $keys) {
    New-Item $script:bkDir -ItemType Directory -Force | Out-Null
    $dir = Join-Path $script:bkDir ((Get-Date).ToString('yyyy-MM-dd_HH-mm-ss') + '_' + ("$label" -replace '[^\w-]', '_'))
    New-Item $dir -ItemType Directory -Force | Out-Null
    $n = 0; $files = @()
    foreach ($k in $keys) {
        $f = Join-Path $dir ('{0:D2}.reg' -f $n)
        [void](Invoke-Native 'reg.exe' ('export "' + $k + '" "' + $f + '" /y'))
        if ($LASTEXITCODE -eq 0 -and (Test-Path $f)) { $files += (Split-Path $f -Leaf); $n++ }
    }
    if (-not $files.Count) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue; return $null }
    ConvertTo-Json -InputObject @{ Label = "$label"; Created = (Get-Date).ToString('o'); Keys = @($keys); Files = $files } -Depth 3 | Set-Content (Join-Path $dir 'backup.json')
    return $dir
}
function Ensure-RegBackup($set) {
    if ($script:regDone[$set]) { return }
    $script:regDone[$set] = $true
    try { $d = New-RegBackup $set @($script:regSets[$set]); if ($d) { Log "Registry backup saved before changing $set (Tools > Backup)." } } catch {}
}
function Load-BackupList {
    $c.bkList.Items.Clear(); $script:bkView = @()
    if (Test-Path $script:bkDir) {
        foreach ($d in @(Get-ChildItem $script:bkDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
            $label = $d.Name; $n = 0
            try { $j = Get-Content (Join-Path $d.FullName 'backup.json') -Raw | ConvertFrom-Json; $label = "$($j.Label)"; $n = @($j.Files).Count } catch {}
            $sp = New-Object Windows.Controls.StackPanel
            [void]$sp.Children.Add((New-Txt $label 14 '#FFFFFF'))
            [void]$sp.Children.Add((New-Txt ("{0}   -   {1} registry file(s)" -f ($d.Name -replace '_', ' ' -replace '^(\d{4}-\d\d-\d\d) (\d\d)-(\d\d)-(\d\d).*', '$1  $2:$3:$4'), $n) 11 '#6C7CA3'))
            [void]$c.bkList.Items.Add($sp); $script:bkView += $d
        }
    }
    $c.bkNote.Text = if ($script:bkView.Count) { 'Pick a backup and press Restore to put those registry settings back. bluFPS makes one automatically before it changes startup items, tweaks or removes leftovers.' } else { 'No registry backups yet. They are made automatically before changes, or press Back up registry now.' }
}
function Restore-RegBackup($dir) {
    $ok = 0
    foreach ($f in @(Get-ChildItem $dir -Filter '*.reg' -ErrorAction SilentlyContinue)) {
        [void](Invoke-Native 'reg.exe' ('import "' + $f.FullName + '"'))
        if ($LASTEXITCODE -eq 0) { $ok++ }
    }
    $ok
}
$script:rpScript = @'
$ErrorActionPreference = 'Stop'
try {
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $old = $null
    try { $old = (Get-ItemProperty $k -Name SystemRestorePointCreationFrequency -ErrorAction Stop).SystemRestorePointCreationFrequency } catch {}
    Set-ItemProperty $k -Name SystemRestorePointCreationFrequency -Value 0 -Type DWord
    try { Enable-ComputerRestore -Drive ($env:SystemDrive + '\') } catch {}
    Checkpoint-Computer -Description 'bluFPS safety point' -RestorePointType MODIFY_SETTINGS
    if ($null -ne $old) { Set-ItemProperty $k -Name SystemRestorePointCreationFrequency -Value $old -Type DWord } else { Remove-ItemProperty $k -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue }
    'OK'
} catch { 'ERR: ' + $_.Exception.Message }
'@
$c.btnRestorePoint.Add_Click({
    $c.bkNote.Text = 'Creating a Windows restore point. This can take up to a minute; you can keep using bluFPS...'
    $c.btnRestorePoint.IsEnabled = $false
    Start-Bg $script:rpScript @() {
        param($res, $err)
        $c.btnRestorePoint.IsEnabled = $true
        $r = "$($res | Select-Object -First 1)"
        if ($r -eq 'OK') { Log 'Windows restore point created. You can roll back with Open System Restore.'; $c.bkNote.Text = 'Restore point created.' }
        else { $msg = if ($r) { $r } elseif ($err) { "$($err.Exception.Message)" } else { 'unknown error' }; Log "Could not create a restore point: $msg"; $c.bkNote.Text = "Could not create a restore point ($msg). Check that System Protection is turned on for your system drive." }
    }
})
$c.btnRegBackup.Add_Click({
    $d = New-RegBackup 'manual' (@($script:regSets.startup) + @($script:regSets.tweaks))
    if ($d) { Log 'Registry backup saved.' } else { Log 'Could not save a registry backup.' }
    Load-BackupList
})
$c.btnRestoreBk.Add_Click({
    $i = $c.bkList.SelectedIndex
    if ($i -lt 0 -or $i -ge $script:bkView.Count) { Log 'Pick a backup in the list first.'; return }
    $d = $script:bkView[$i]
    $ans = [Windows.MessageBox]::Show("Put the registry settings saved in this backup back?`n`n$($d.Name)`n`nThis restores those keys. Settings added later are not removed.", 'Restore backup', 'YesNo', 'Question')
    if ($ans -eq 'Yes') { $n = Restore-RegBackup $d.FullName; Log "Restored $n registry file(s). Restart Windows for everything to apply." }
})
$c.btnDelBk.Add_Click({
    $i = $c.bkList.SelectedIndex
    if ($i -ge 0 -and $i -lt $script:bkView.Count) { Remove-Item $script:bkView[$i].FullName -Recurse -Force -ErrorAction SilentlyContinue; Load-BackupList }
})
$c.btnOpenRst.Add_Click({ try { Start-Process rstrui.exe } catch { Log 'Could not open System Restore.' } })
$c.btnOpenBk.Add_Click({ New-Item $script:bkDir -ItemType Directory -Force | Out-Null; Start-Process explorer.exe -ArgumentList "`"$($script:bkDir)`"" })

# ----- Junk file cleaner -----
$script:cleanRows = $null
function Get-BrowserCachePaths($userData) {
    $out = @()
    if (Test-Path $userData) {
        foreach ($prof in @(Get-ChildItem $userData -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })) {
            foreach ($sub in 'Cache', 'Code Cache', 'GPUCache') { $out += (Join-Path $prof.FullName $sub) }
        }
    }
    $out
}
function Get-CleanCats {
    $cats = @()
    $cats += @{ Id = 'utemp'; Name = 'Your temporary files'; Desc = 'Leftovers apps no longer need (only files older than a day).'; Paths = @($env:TEMP, (Join-Path $env:LOCALAPPDATA 'Temp') | Select-Object -Unique); Days = 1; Exts = ''; On = $true }
    $cats += @{ Id = 'wtemp'; Name = 'Windows temporary files'; Desc = 'The system temp folder (files older than 2 days).'; Paths = @((Join-Path $env:WINDIR 'Temp')); Days = 2; Exts = ''; On = $true }
    foreach ($b in @(@('chrome', 'Google Chrome cache', (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data')),
                     @('edge', 'Microsoft Edge cache', (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data')),
                     @('brave', 'Brave cache', (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data')))) {
        $p = @(Get-BrowserCachePaths $b[2])
        if ($p.Count) { $cats += @{ Id = $b[0]; Name = $b[1]; Desc = 'Saved web pages and images. Passwords, cookies and history are NOT touched.'; Paths = $p; Days = 0; Exts = ''; On = $true } }
    }
    $ff = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path $ff) {
        $p = @(Get-ChildItem $ff -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'cache2' })
        if ($p.Count) { $cats += @{ Id = 'firefox'; Name = 'Firefox cache'; Desc = 'Saved web pages and images. Passwords, cookies and history are NOT touched.'; Paths = $p; Days = 0; Exts = ''; On = $true } }
    }
    $cats += @{ Id = 'dumps'; Name = 'Crash dumps and error reports'; Desc = 'Memory dumps and reports left after program crashes.'; Paths = @((Join-Path $env:LOCALAPPDATA 'CrashDumps'), (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive'), (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue'), (Join-Path $env:WINDIR 'Minidump')); Days = 0; Exts = ''; On = $true }
    $cats += @{ Id = 'logs'; Name = 'Old system logs'; Desc = 'Log files older than 14 days from the Windows Logs folder.'; Paths = @((Join-Path $env:WINDIR 'Logs')); Days = 14; Exts = '.log;.etl'; On = $true }
    $cats += @{ Id = 'recycle'; Name = 'Recycle Bin'; Desc = 'Files you deleted. Look inside before emptying it!'; Paths = @(); Days = 0; Exts = ''; On = $false }
    $cats
}
function Update-CleanTotal {
    $sum = 0.0; foreach ($r in @($script:cleanRows)) { if ($r.Box.IsChecked) { $sum += $r.Bytes } }
    $c.cleanTotal.Text = if ($sum -gt 0) { 'Selected: ' + (Format-Size $sum) } else { 'Press Scan to see how much can be cleaned.' }
}
function Load-CleanUi {
    $c.cleanPanel.Children.Clear(); $script:cleanRows = @()
    foreach ($cat in (Get-CleanCats)) {
        $dock = New-Object Windows.Controls.DockPanel -Property @{ Margin = '0,0,0,14'; LastChildFill = $true }
        $size = New-Object Windows.Controls.TextBlock -Property @{ Text = ''; FontSize = 14; Foreground = '#4DA3FF'; VerticalAlignment = 'Center'; Margin = '12,0,0,0' }
        [Windows.Controls.DockPanel]::SetDock($size, 'Right')
        $cb = New-SwitchRow $cat.Name $cat.Desc
        $cb.IsChecked = [bool]$cat.On; $cb.Margin = '0'
        $cb.Add_Click({ Update-CleanTotal })
        [void]$dock.Children.Add($size); [void]$dock.Children.Add($cb)
        [void]$c.cleanPanel.Children.Add($dock)
        $script:cleanRows += @{ Cat = $cat; Box = $cb; Size = $size; Bytes = 0.0 }
    }
    Update-CleanTotal
}
function Get-RecycleSize {
    try { $sh = New-Object -ComObject Shell.Application; $t = 0.0; foreach ($i in $sh.NameSpace(10).Items()) { $t += [double]$i.Size }; return $t } catch { return 0.0 }
}
$script:cleanScript = @'
param($items, $del)
foreach ($k in $items) {
    $n = [Blu.Native]::Many([string[]]$k.Paths, [int]$k.Days, [string]$k.Exts, [bool]$del)
    [pscustomobject]@{ Id = $k.Id; Bytes = $n }
}
'@
function Get-CleanPayload($onlyChecked) {
    @($script:cleanRows | Where-Object { $_.Cat.Id -ne 'recycle' -and (-not $onlyChecked -or $_.Box.IsChecked) } | ForEach-Object {
        @{ Id = $_.Cat.Id; Paths = [string[]]$_.Cat.Paths; Days = [int]$_.Cat.Days; Exts = [string]$_.Cat.Exts } })
}
$c.btnCleanScan.Add_Click({
    if (-not (Test-Native)) { Log 'The cleaning engine could not start on this PC.'; return }
    $c.cleanTotal.Text = 'Scanning...'; $c.btnCleanScan.IsEnabled = $false; $c.btnCleanRun.IsEnabled = $false
    $payload = Get-CleanPayload $false
    Start-Bg $script:cleanScript @($payload, $false) {
        param($res, $err)
        $c.btnCleanScan.IsEnabled = $true; $c.btnCleanRun.IsEnabled = $true
        foreach ($r in $res) {
            $row = $script:cleanRows | Where-Object { $_.Cat.Id -eq $r.Id } | Select-Object -First 1
            if ($row) { $row.Bytes = [double]$r.Bytes; $row.Size.Text = Format-Size $r.Bytes }
        }
        $rb = $script:cleanRows | Where-Object { $_.Cat.Id -eq 'recycle' } | Select-Object -First 1
        if ($rb) { $rb.Bytes = Get-RecycleSize; $rb.Size.Text = Format-Size $rb.Bytes }
        Update-CleanTotal
    }
})
$c.btnCleanRun.Add_Click({
    $sel = @($script:cleanRows | Where-Object { $_.Box.IsChecked })
    if (-not $sel.Count) { Log 'Switch on what you want to clean first.'; return }
    if (-not (Test-Native)) { Log 'The cleaning engine could not start on this PC.'; return }
    $total = 0.0; foreach ($r in $sel) { $total += $r.Bytes }
    $ask = if ($total -gt 0) { 'about ' + (Format-Size $total) } else { 'the selected junk' }
    $ans = [Windows.MessageBox]::Show("Remove $ask from the selected categories?`n`nbluFPS never touches your documents, passwords, cookies or browsing history. Files that are in use are skipped.", 'Clean up', 'YesNo', 'Question')
    if ($ans -ne 'Yes') { return }
    $c.cleanTotal.Text = 'Cleaning...'; $c.btnCleanScan.IsEnabled = $false; $c.btnCleanRun.IsEnabled = $false
    $script:cleanBin = [bool](@($sel | Where-Object { $_.Cat.Id -eq 'recycle' }).Count)
    Start-Bg $script:cleanScript @((Get-CleanPayload $true), $true) {
        param($res, $err)
        $freed = 0.0; foreach ($r in $res) { $freed += [double]$r.Bytes }
        if ($script:cleanBin) { try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {} }
        foreach ($row in @($script:cleanRows)) { if ($row.Box.IsChecked) { $row.Bytes = 0.0; $row.Size.Text = '' } }
        $c.btnCleanScan.IsEnabled = $true; $c.btnCleanRun.IsEnabled = $true
        Update-CleanTotal
        Log ('Cleaned up: freed about {0}.' -f (Format-Size $freed))
        $c.cleanTotal.Text = 'Freed about ' + (Format-Size $freed)
    }
})
$c.btnStorageSense.Add_Click({ try { Start-Process 'ms-settings:storagesense' } catch { Log 'Could not open Storage Sense.' } })

# ----- Startup manager -----
function Get-StartupItems {
    $items = @()
    $sa = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $defs = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKCU:\$sa\Run"; Where = 'Your account' },
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$sa\Run"; Where = 'All users' },
        @{ Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$sa\Run32"; Where = 'All users (32-bit)' })
    foreach ($d in $defs) {
        $k = Get-Item $d.Path -ErrorAction SilentlyContinue
        if ($k) { foreach ($n in $k.GetValueNames()) { if ($n) { $items += [pscustomobject]@{ Name = $n; Command = "$($k.GetValue($n))"; Where = $d.Where; Approved = $d.Approved } } } }
    }
    $folders = @(
        @{ Dir = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'); Approved = "HKCU:\$sa\StartupFolder"; Where = 'Your account (Startup folder)' },
        @{ Dir = (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp'); Approved = "HKLM:\$sa\StartupFolder"; Where = 'All users (Startup folder)' })
    foreach ($f in $folders) {
        if (Test-Path $f.Dir) {
            foreach ($file in @(Get-ChildItem $f.Dir -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) {
                $items += [pscustomobject]@{ Name = $file.Name; Command = $file.FullName; Where = $f.Where; Approved = $f.Approved }
            }
        }
    }
    $items
}
function Test-StartupEnabled($it) {
    try {
        $b = (Get-ItemProperty -Path $it.Approved -Name $it.Name -ErrorAction Stop).($it.Name)
        if ($b -is [byte[]] -and $b.Length -gt 0) { return (($b[0] -band 1) -eq 0) }
    } catch {}
    return $true
}
function Set-StartupEnabled($it, $on) {
    Ensure-RegBackup 'startup'
    if (-not (Test-Path $it.Approved)) { New-Item $it.Approved -Force | Out-Null }
    $bytes = New-Object byte[] 12
    if ($on) { $bytes[0] = 2 } else { $bytes[0] = 3; [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc()).CopyTo($bytes, 4) }
    Set-ItemProperty -Path $it.Approved -Name $it.Name -Value $bytes -Type Binary
}
function Update-StartupNote {
    $boxes = @($c.startPanel.Children)
    $on = @($boxes | Where-Object { $_.IsChecked }).Count
    $c.startNote.Text = "$on of $($boxes.Count) startup items are on. Switch off what you do not need; it takes effect the next time Windows starts. A registry backup is saved first."
}
function Load-StartupUi {
    $c.startPanel.Children.Clear()
    foreach ($it in @(Get-StartupItems | Sort-Object Name)) {
        $sp = New-Object Windows.Controls.StackPanel
        $title = $it.Name; if ($it.Name -match 'SecurityHealth|Defender|bluFPS') { $title += '   (recommended: keep on)' }
        [void]$sp.Children.Add((New-Txt $title 14 '#FFFFFF'))
        [void]$sp.Children.Add((New-Txt $it.Command 11 '#6C7CA3'))
        [void]$sp.Children.Add((New-Txt $it.Where 11 '#4DA3FF'))
        $cb = New-Object Windows.Controls.CheckBox -Property @{ Content = $sp; Margin = '0,0,0,14'; IsChecked = (Test-StartupEnabled $it); Tag = $it }
        $cb.Add_Click({
            $b = $args[0]
            try {
                Set-StartupEnabled $b.Tag ([bool]$b.IsChecked)
                Log ('{0}: {1} at startup.' -f $b.Tag.Name, $(if ($b.IsChecked) { 'on' } else { 'off' }))
                Update-StartupNote
            } catch { $b.IsChecked = -not $b.IsChecked; Log "Could not change $($b.Tag.Name): $($_.Exception.Message)" }
        })
        [void]$c.startPanel.Children.Add($cb)
    }
    Update-StartupNote
}
$c.btnStartRefresh.Add_Click({ Load-StartupUi })

# ----- Uninstaller with leftover cleanup -----
$script:instApps = $null; $script:instView = @(); $script:unSel = $null; $script:unApp = $null; $script:unProc = $null; $script:unItems = @()
function Get-InstalledApps {
    $roots = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $apps = @(); $seen = @{}
    foreach ($root in $roots) {
        foreach ($k in @(Get-ChildItem $root -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
            if (-not $p -or -not $p.DisplayName -or -not $p.UninstallString) { continue }
            if ($p.SystemComponent -eq 1 -or $p.ParentKeyName -or "$($p.ReleaseType)" -match 'Update|Hotfix' -or "$($p.DisplayName)" -eq 'bluFPS') { continue }
            $id = "$($p.DisplayName)|$($p.DisplayVersion)"
            if ($seen.ContainsKey($id)) { continue }
            $seen[$id] = $true
            $apps += [pscustomobject]@{ Name = "$($p.DisplayName)"; Version = "$($p.DisplayVersion)"; Publisher = "$($p.Publisher)"; Location = "$($p.InstallLocation)".Trim('"').TrimEnd('\')
                Cmd = "$($p.UninstallString)"; SizeKB = [int]$p.EstimatedSize; Key = $k.PSPath }
        }
    }
    $apps | Sort-Object Name
}
function Filter-Installed {
    $q = $c.unSearch.Text.Trim()
    $script:instView = @($script:instApps | Where-Object { -not $q -or $_.Name.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    $c.unList.Items.Clear()
    foreach ($a in $script:instView) {
        $sub = (@($a.Publisher, $a.Version, $(if ($a.SizeKB) { Format-Size ($a.SizeKB * 1KB) })) | Where-Object { $_ }) -join '   -   '
        $sp = New-Object Windows.Controls.StackPanel
        [void]$sp.Children.Add((New-Txt $a.Name 14 '#FFFFFF')); [void]$sp.Children.Add((New-Txt $sub 11 '#6C7CA3'))
        [void]$c.unList.Items.Add($sp)
    }
}
function Load-Installed($reload) {
    if ($reload -or -not $script:instApps) { $c.unStatus.Text = 'Reading your installed programs...'; Pump; $script:instApps = @(Get-InstalledApps); $c.unStatus.Text = '' }
    Filter-Installed
}
function Split-Command($cmd) {
    $cmd = "$cmd".Trim()
    if ($cmd -match '^"([^"]+)"\s*(.*)$') { return @($Matches[1], $Matches[2]) }
    if ($cmd -match '^(.+?\.exe)\s*(.*)$') { return @($Matches[1], $Matches[2]) }
    return @($cmd, '')
}
function Norm-Name($s) {
    $t = "$s" -replace '(?i)\s*[\(\[]?(x64|x86|amd64|64-bit|32-bit|64bit|32bit)[\)\]]?', '' -replace '\s+v?\d+(\.\d+)+.*$', '' -replace '\s+\d+(\.\d+)*$', ''
    ($t.ToLower() -replace '[^a-z0-9]', '')
}
function Test-SafeDelete($p) {
    $p = "$p".TrimEnd('\')
    if (-not $p -or $p -match '\.\.') { return $false }
    if ($script:AppRoot -and ($p -ieq $script:AppRoot -or $script:AppRoot.StartsWith($p + '\', [StringComparison]::OrdinalIgnoreCase))) { return $false }
    if ($p.StartsWith($env:WINDIR, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA, $env:APPDATA, $env:ProgramData,
        [Environment]::GetFolderPath('CommonStartMenu'), [Environment]::GetFolderPath('StartMenu'), [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory')) | Where-Object { $_ }
    foreach ($r in $roots) { $rr = $r.TrimEnd('\'); if ($p.Length -gt $rr.Length + 1 -and $p.StartsWith($rr + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}
function Test-SafeReg($p) {
    return (("$p" -match '^(HKCU|HKLM):\\Software\\(WOW6432Node\\)?[^\\]+(\\[^\\]+)?$') -and ("$p" -notmatch '\\(Microsoft|Windows|Classes|Policies|WOW6432Node)(\\[^\\]+)?$'))
}
function Find-Leftovers($app) {
    $c.unLeft.Children.Clear(); $script:unItems = @(); $c.btnUnClean.Visibility = 'Collapsed'
    $generic = 'microsoft', 'windows', 'common', 'programs', 'packages', 'temp', 'cache', 'data', 'software', 'google', 'intel', 'nvidia', 'amd', 'adobe', 'apps', 'system', 'users', 'default', 'local', 'roaming'
    $want = @(Norm-Name $app.Name)
    if ($app.Location) { $want += (Norm-Name (Split-Path $app.Location -Leaf)) }
    $want = @($want | Where-Object { $_.Length -ge 4 -and $generic -notcontains $_ } | Select-Object -Unique)
    $pub = Norm-Name $app.Publisher
    $found = @()
    if ($app.Location -and (Test-Path -LiteralPath $app.Location)) { $found += @{ Type = 'Dir'; Path = $app.Location; Label = 'Program folder' } }
    if ($want.Count) {
        $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA, $env:APPDATA, $env:ProgramData, (Join-Path $env:LOCALAPPDATA 'Programs')) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
        foreach ($r in $roots) {
            foreach ($d in @(Get-ChildItem $r -Directory -Force -ErrorAction SilentlyContinue)) {
                if ($want -contains (Norm-Name $d.Name)) { $found += @{ Type = 'Dir'; Path = $d.FullName; Label = 'Folder' } }
            }
            Pump
        }
        foreach ($base in 'HKCU:\Software', 'HKLM:\Software', 'HKLM:\Software\WOW6432Node') {
            foreach ($k in @(Get-ChildItem $base -ErrorAction SilentlyContinue)) {
                $kn = Norm-Name $k.PSChildName
                if ($want -contains $kn) { $found += @{ Type = 'Reg'; Path = "$base\$($k.PSChildName)"; Label = 'Registry key' } }
                elseif ($pub.Length -ge 4 -and $generic -notcontains $pub -and $kn -eq $pub) {
                    foreach ($k2 in @(Get-ChildItem $k.PSPath -ErrorAction SilentlyContinue)) {
                        if ($want -contains (Norm-Name $k2.PSChildName)) { $found += @{ Type = 'Reg'; Path = "$base\$($k.PSChildName)\$($k2.PSChildName)"; Label = 'Registry key' } }
                    }
                }
            }
        }
        foreach ($m in @((Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))) {
            foreach ($d in @(Get-ChildItem $m -Directory -ErrorAction SilentlyContinue)) { if ($want -contains (Norm-Name $d.Name)) { $found += @{ Type = 'Dir'; Path = $d.FullName; Label = 'Start menu folder' } } }
            foreach ($l in @(Get-ChildItem $m -Filter '*.lnk' -ErrorAction SilentlyContinue)) { if ($want -contains (Norm-Name $l.BaseName)) { $found += @{ Type = 'Link'; Path = $l.FullName; Label = 'Shortcut' } } }
        }
        foreach ($dsk in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'))) {
            foreach ($l in @(Get-ChildItem $dsk -Filter '*.lnk' -ErrorAction SilentlyContinue)) { if ($want -contains (Norm-Name $l.BaseName)) { $found += @{ Type = 'Link'; Path = $l.FullName; Label = 'Desktop shortcut' } } }
        }
    }
    if ($app.Location.Length -gt 8) {
        foreach ($rk in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run') {
            $k = Get-Item $rk -ErrorAction SilentlyContinue
            if ($k) { foreach ($n in $k.GetValueNames()) { if ("$($k.GetValue($n))".IndexOf($app.Location, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $found += @{ Type = 'RunValue'; Path = $rk; Name = $n; Label = 'Startup entry' } } } }
        }
    }
    $seen = @{}; $keep = @()
    foreach ($f in $found) {
        $ok = switch ($f.Type) { 'Dir' { Test-SafeDelete $f.Path } 'Link' { Test-SafeDelete $f.Path } 'Reg' { Test-SafeReg $f.Path } default { $true } }
        $id = "$($f.Type)|$($f.Path)|$($f.Name)"
        if ($ok -and -not $seen.ContainsKey($id)) { $seen[$id] = $true; $keep += $f }
    }
    $script:unItems = $keep
    if (-not $keep.Count) { $c.unStatus.Text = "$($app.Name) was removed and no leftovers were found. Nice and clean."; return }
    $c.unStatus.Text = "$($app.Name) was removed. Review these leftovers; untick anything you want to keep."
    foreach ($f in $keep) {
        $size = ''
        if ($f.Type -eq 'Dir' -and (Test-Native)) { try { $size = '  (' + (Format-Size ([Blu.Native]::Many([string[]]@($f.Path), 0, '', $false))) + ')' } catch {} }
        $sp = New-Object Windows.Controls.StackPanel
        [void]$sp.Children.Add((New-Txt ($f.Label + $size) 13 '#FFFFFF')); [void]$sp.Children.Add((New-Txt ("$($f.Path) $($f.Name)").Trim() 10 '#6C7CA3'))
        $cb = New-Object Windows.Controls.CheckBox -Property @{ Content = $sp; IsChecked = $true; Margin = '0,0,0,8'; Tag = $f }
        [void]$c.unLeft.Children.Add($cb)
    }
    $c.btnUnClean.Visibility = 'Visible'
}
function Remove-Leftovers($items) {
    $regKeys = @()
    foreach ($i in $items) { if ($i.Type -eq 'Reg' -or $i.Type -eq 'RunValue') { $regKeys += ($i.Path -replace '^(HKCU|HKLM):\\', '$1\') } }
    $bk = $null
    if ($regKeys.Count) { $bk = New-RegBackup ('uninstall-' + $script:unApp.Name) @($regKeys | Select-Object -Unique) }
    $freed = 0.0; $n = 0
    foreach ($i in $items) {
        try {
            switch ($i.Type) {
                'Dir' { if (Test-SafeDelete $i.Path) { if (Test-Native) { $freed += [Blu.Native]::Many([string[]]@($i.Path), 0, '', $true) }; Remove-Item -LiteralPath $i.Path -Recurse -Force -ErrorAction SilentlyContinue; $n++ } }
                'Link' { if (Test-SafeDelete $i.Path) { Remove-Item -LiteralPath $i.Path -Force -ErrorAction SilentlyContinue; $n++ } }
                'Reg' { if (Test-SafeReg $i.Path) { Remove-Item -Path $i.Path -Recurse -Force -ErrorAction SilentlyContinue; $n++ } }
                'RunValue' { Remove-ItemProperty -Path $i.Path -Name $i.Name -ErrorAction SilentlyContinue; $n++ }
            }
        } catch {}
        Pump
    }
    $msg = "Removed $n leftover item(s), freed about $(Format-Size $freed)."
    if ($bk) { $msg += ' A registry backup was saved (Tools > Backup).' }
    Log $msg; $c.unStatus.Text = $msg
    $c.unLeft.Children.Clear(); $c.btnUnClean.Visibility = 'Collapsed'; $script:unItems = @()
}
function Check-Leftovers {
    $app = $script:unApp
    if (-not $app) { return }
    if (Test-Path -LiteralPath $app.Key) {
        $c.unStatus.Text = "$($app.Name) is still listed as installed. If its uninstaller is still working, let it finish, then press Look for leftovers."
        $c.btnUnLeft.Visibility = 'Visible'; return
    }
    $c.btnUnLeft.Visibility = 'Collapsed'
    $c.unStatus.Text = "$($app.Name) was removed. Looking for leftovers..."; Pump
    Find-Leftovers $app
    $script:instApps = $null; Load-Installed $true
}
function Poll-Uninstall {
    if (-not $script:unProc) { $script:unTimer.Stop(); return }
    $done = $true; try { $done = $script:unProc.HasExited } catch {}
    if (-not $done) { return }
    $script:unTimer.Stop(); $script:unProc = $null
    Check-Leftovers
}
$script:unTimer = New-Object Windows.Threading.DispatcherTimer
$script:unTimer.Interval = [TimeSpan]::FromSeconds(1)
$script:unTimer.Add_Tick({ Poll-Uninstall })
$c.unSearch.Add_TextChanged({ Filter-Installed })
$c.unList.Add_SelectionChanged({
    $i = $c.unList.SelectedIndex
    if ($i -ge 0 -and $i -lt $script:instView.Count) {
        $a = $script:instView[$i]; $script:unSel = $a
        $c.unName.Text = $a.Name
        $c.unInfo.Text = (@($a.Publisher, $a.Version, $a.Location) | Where-Object { $_ }) -join "`n"
        $c.btnUnLeft.Visibility = 'Collapsed'; $c.unLeft.Children.Clear(); $c.btnUnClean.Visibility = 'Collapsed'; $c.unStatus.Text = ''
    }
})
$c.btnUnRun.Add_Click({
    $a = $script:unSel
    if (-not $a) { Log 'Pick a program first.'; return }
    if ($script:unProc) { Log 'An uninstaller is already running.'; return }
    $ans = [Windows.MessageBox]::Show("Uninstall $($a.Name)?`n`nIts own uninstaller opens first. Afterwards bluFPS looks for leftover folders and registry entries and lets you review them before anything is removed.", 'Uninstall', 'YesNo', 'Question')
    if ($ans -ne 'Yes') { return }
    $parts = Split-Command $a.Cmd
    $file = $parts[0]; $argLine = $parts[1]
    if ($file -match 'msiexec' -and $argLine -match '/[iI]\s*\{') { $argLine = $argLine -replace '/[iI]', '/X' }
    $script:unApp = $a
    try {
        if ($argLine) { $script:unProc = Start-Process -FilePath $file -ArgumentList $argLine -PassThru } else { $script:unProc = Start-Process -FilePath $file -PassThru }
        $c.unStatus.Text = "The uninstaller for $($a.Name) is running. Finish it; bluFPS then looks for leftovers."
        $script:unTimer.Start()
    } catch { Log "Could not start the uninstaller: $($_.Exception.Message)"; $c.unStatus.Text = 'Could not start the uninstaller.' }
})
$c.btnUnLeft.Add_Click({ Check-Leftovers })
$c.btnUnClean.Add_Click({
    $sel = @($c.unLeft.Children | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
    if (-not $sel.Count) { Log 'Nothing ticked.'; return }
    $ans = [Windows.MessageBox]::Show("Remove $($sel.Count) leftover item(s)?`n`nA registry backup is saved first, so you can undo registry changes from Tools > Backup.", 'Remove leftovers', 'YesNo', 'Question')
    if ($ans -eq 'Yes') { Remove-Leftovers $sel }
})

# ----- System resource monitor -----
$script:monSort = 'Cpu'; $script:monPrev = @{}; $script:monT = $null; $script:monCpuC = $null; $script:monDiskC = $null; $script:monInit = $false
function Sample-Processes {
    $now = Get-Date; $dt = 0.0; if ($script:monT) { $dt = ($now - $script:monT).TotalSeconds }
    $cores = [Environment]::ProcessorCount; $native = Test-Native
    $cur = @{}; $rows = @()
    foreach ($p in [Diagnostics.Process]::GetProcesses()) {
        $id = $p.Id; if ($id -le 4) { continue }
        $cpuT = $null; try { $cpuT = $p.TotalProcessorTime.TotalSeconds } catch {}
        $io = [double]0; if ($native) { try { $io = [double][Blu.Native]::IoBytes($id) } catch {} }
        $mem = 0; try { $mem = $p.WorkingSet64 } catch {}
        $cur[$id] = @($cpuT, $io)
        $cpu = 0.0; $rate = 0.0
        if ($dt -gt 0 -and $script:monPrev.ContainsKey($id)) {
            $pv = $script:monPrev[$id]
            if ($null -ne $cpuT -and $null -ne $pv[0]) { $cpu = [math]::Max(0.0, ($cpuT - $pv[0]) / $dt / $cores * 100) }
            $rate = [math]::Max(0.0, ($io - $pv[1]) / $dt / 1MB)
        }
        $rows += [pscustomobject]@{ Name = $p.ProcessName; Cpu = $cpu; MemMB = [int]($mem / 1MB); Io = $rate }
    }
    $script:monPrev = $cur; $script:monT = $now
    $rows
}
function New-MonRow($r) {
    $g = New-Object Windows.Controls.Grid -Property @{ Margin = '0,0,0,7' }
    foreach ($w in @(@(1, 'Star'), @(80, 'Pixel'), @(90, 'Pixel'), @(90, 'Pixel'))) {
        $cd = New-Object Windows.Controls.ColumnDefinition
        $cd.Width = [Windows.GridLength]::new($w[0], [Windows.GridUnitType]::($w[1]))
        [void]$g.ColumnDefinitions.Add($cd)
    }
    $hot = '#FF6B6B'; $warm = '#F5C542'; $ok = '#C8D3F0'
    $cc = if ($r.Cpu -gt 25) { $hot } elseif ($r.Cpu -gt 8) { $warm } else { $ok }
    $mc = if ($r.MemMB -gt 2000) { $hot } elseif ($r.MemMB -gt 800) { $warm } else { $ok }
    $ic = if ($r.Io -gt 20) { $hot } elseif ($r.Io -gt 4) { $warm } else { $ok }
    $cells = @((New-Txt $r.Name 13 '#FFFFFF'), (New-Txt ('{0:N1}%' -f $r.Cpu) 13 $cc), (New-Txt ('{0:N0} MB' -f $r.MemMB) 13 $mc), (New-Txt ('{0:N1} MB/s' -f $r.Io) 13 $ic))
    for ($i = 0; $i -lt 4; $i++) { [Windows.Controls.Grid]::SetColumn($cells[$i], $i); [void]$g.Children.Add($cells[$i]) }
    $g
}
function Set-MonSortUi {
    $c.monSortCpu.Background = if ($script:monSort -eq 'Cpu') { '#2F7BFF' } else { '#182452' }
    $c.monSortMem.Background = if ($script:monSort -eq 'MemMB') { '#2F7BFF' } else { '#182452' }
    $c.monSortIo.Background = if ($script:monSort -eq 'Io') { '#2F7BFF' } else { '#182452' }
}
function Sample-Monitor {
    if (-not $script:monInit) {
        $script:monInit = $true
        try { $script:monCpuC = New-Object Diagnostics.PerformanceCounter -ArgumentList 'Processor', '% Processor Time', '_Total'; [void]$script:monCpuC.NextValue() } catch {}
        try { $script:monDiskC = New-Object Diagnostics.PerformanceCounter -ArgumentList 'PhysicalDisk', '% Disk Time', '_Total'; [void]$script:monDiskC.NextValue() } catch {}
    }
    $rows = @(Sample-Processes)
    $groups = @($rows | Group-Object Name | ForEach-Object {
        $g = $_.Group
        [pscustomobject]@{ Name = $(if ($_.Count -gt 1) { "$($_.Name) ($($_.Count))" } else { $_.Name })
            Cpu = [double]($g | Measure-Object Cpu -Sum).Sum; MemMB = [int]($g | Measure-Object MemMB -Sum).Sum; Io = [double]($g | Measure-Object Io -Sum).Sum }
    })
    $c.monRows.Children.Clear()
    foreach ($r in @($groups | Sort-Object -Property $script:monSort -Descending | Select-Object -First 14)) { [void]$c.monRows.Children.Add((New-MonRow $r)) }
    $cpu = 0; try { $cpu = [int]$script:monCpuC.NextValue() } catch { $cpu = [int](($groups | Measure-Object Cpu -Sum).Sum) }
    $cpu = [math]::Min(100, $cpu); $c.monCpu.Text = "$cpu%"; $c.monCpuBar.Value = $cpu
    $ram = 0; if ($script:ci) { $ram = [int](100 - 100 * $script:ci.AvailablePhysicalMemory / $script:ci.TotalPhysicalMemory) }
    $c.monRam.Text = "$ram%"; $c.monRamBar.Value = $ram
    $disk = -1; try { $disk = [math]::Min(100, [int]$script:monDiskC.NextValue()) } catch {}
    if ($disk -ge 0) { $c.monDisk.Text = "$disk%"; $c.monDiskBar.Value = $disk } else { $c.monDisk.Text = ('{0:N1} MB/s' -f (($groups | Measure-Object Io -Sum).Sum)); $c.monDiskBar.Value = 0 }
    $topC = $groups | Sort-Object Cpu -Descending | Select-Object -First 1
    $topM = $groups | Sort-Object MemMB -Descending | Select-Object -First 1
    $topI = $groups | Sort-Object Io -Descending | Select-Object -First 1
    if ($topC) { $c.monVerdict.Text = ('Biggest CPU user: {0} ({1:N1}%)   |   Most memory: {2} ({3:N0} MB)   |   Busiest disk: {4} ({5:N1} MB/s)' -f $topC.Name, $topC.Cpu, $topM.Name, $topM.MemMB, $topI.Name, $topI.Io) }
    $lines = @()
    foreach ($d in [IO.DriveInfo]::GetDrives()) {
        if ($d.DriveType -eq 'Fixed' -and $d.IsReady) { $lines += ('{0}  {1} free of {2}  ({3:N0}% used)' -f $d.Name, (Format-Size $d.AvailableFreeSpace), (Format-Size $d.TotalSize), (100 - 100 * $d.AvailableFreeSpace / $d.TotalSize)) }
    }
    $c.monDrives.Text = $lines -join "`n"
}
$script:monTimer = New-Object Windows.Threading.DispatcherTimer
$script:monTimer.Interval = [TimeSpan]::FromSeconds(2)
$script:monTimer.Add_Tick({ try { Sample-Monitor } catch {} })
$c.monSortCpu.Add_Click({ $script:monSort = 'Cpu'; Set-MonSortUi; Sample-Monitor })
$c.monSortMem.Add_Click({ $script:monSort = 'MemMB'; Set-MonSortUi; Sample-Monitor })
$c.monSortIo.Add_Click({ $script:monSort = 'Io'; Set-MonSortUi; Sample-Monitor })

# ----- Tools tab switching -----
function Set-ToolTab($name) {
    $script:toolTab = $name
    foreach ($t in 'Clean', 'Start', 'Uninst', 'Mon', 'Backup') {
        $c["tp$t"].Visibility = if ($t -eq $name) { 'Visible' } else { 'Collapsed' }
        $c["tab$t"].Background = if ($t -eq $name) { '#2F7BFF' } else { '#182452' }
    }
    if ($name -eq 'Mon') { Set-MonSortUi; $script:monT = $null; $script:monTimer.Start(); try { Sample-Monitor } catch {} } else { $script:monTimer.Stop() }
    switch ($name) {
        'Clean' { if (-not $script:cleanRows) { Load-CleanUi } }
        'Start' { Load-StartupUi }
        'Uninst' { Load-Installed $false }
        'Backup' { Load-BackupList }
    }
}
$c.navTools.Add_Click({ Show-Page 'Tools' })
$c.tabClean.Add_Click({ Set-ToolTab 'Clean' }); $c.tabStart.Add_Click({ Set-ToolTab 'Start' }); $c.tabUninst.Add_Click({ Set-ToolTab 'Uninst' })
$c.tabMon.Add_Click({ Set-ToolTab 'Mon' }); $c.tabBackup.Add_Click({ Set-ToolTab 'Backup' })

function Set-Level($lv) {
    if ($lv -eq 'Light') { $lv = 'Balanced' } elseif ($lv -eq 'Maximum') { $lv = 'Extreme' }
    if ($lv -eq 'Auto') { $script:S.Level = 'Auto'; Save-Settings; Show-GameDetail; Log 'Profile set to Auto: bluFPS picks the tweaks for your PC and each game.'; return }
    if (-not $script:levelOn.ContainsKey($lv)) { return }
    $cfg = $script:S
    foreach ($k in $script:levelKeys) { $cfg[$k] = ($script:levelOn[$lv] -contains $k) }
    $cfg.Level = $lv
    Save-Settings; Load-SettingsUi; Show-GameDetail; Log "Profile set to $lv."
}
$c.btnLvAuto.Add_Click({ Set-Level 'Auto' }); $c.btnLvLight.Add_Click({ Set-Level 'Balanced' }); $c.btnLvBal.Add_Click({ Set-Level 'Performance' }); $c.btnLvMax.Add_Click({ Set-Level 'Extreme' })

# ---------- performance: hardware analysis, bottleneck diagnosis, real FPS capture, before/after test ----------
function Format-Gb { param($bytes)
    if (-not $bytes) { return '?' }
    return ('{0:N0} GB' -f ([double]$bytes / 1GB))
}
function Get-HwInfo {
    $h = @{ Text = ''; Threads = 0; RamGb = 0; Modules = 0; HasHdd = $false; Laptop = $false; GpuCount = 0; CpuName = '' }
    $l = @()
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $h.Threads = [int]$cpu.NumberOfLogicalProcessors; $h.CpuName = "$($cpu.Name)".Trim()
        $l += "CPU: $("$($cpu.Name)".Trim())  -  $($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads, up to $([math]::Round($cpu.MaxClockSpeed / 1000, 1)) GHz"
    } catch { $l += 'CPU: could not be read' }
    try {
        $found = 0
        foreach ($g in @(Get-CimInstance Win32_VideoController)) {
            if (-not $g.Name -or $g.Name -match 'Basic|Remote|Virtual|Parsec|Meta') { continue }
            $found++; $h.GpuCount++
            $vram = $null
            try {
                $k = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*' -ErrorAction SilentlyContinue | Where-Object { $_.DriverDesc -eq $g.Name } | Select-Object -First 1
                if ($k) { $vram = $k.'HardwareInformation.qwMemorySize'; if ($vram -is [byte[]]) { $vram = [BitConverter]::ToUInt64($vram, 0) } }
            } catch {}
            if (-not $vram) { $vram = $g.AdapterRAM }
            $l += "GPU: $($g.Name)  -  $(Format-Gb $vram) video memory, driver $($g.DriverVersion)"
        }
        if (-not $found) { $l += 'GPU: not detected' }
    } catch { $l += 'GPU: could not be read' }
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $h.RamGb = [math]::Round([double]$os.TotalVisibleMemorySize * 1KB / 1GB)
        $mods = @(Get-CimInstance Win32_PhysicalMemory)
        $h.Modules = $mods.Count
        $spd = ($mods | Measure-Object -Property ConfiguredClockSpeed -Maximum).Maximum
        $line = "RAM: $($h.RamGb) GB in $($mods.Count) module(s)"
        if ($spd) { $line += " at $spd MHz" }
        if ($mods.Count -eq 1) { $line += '  (one module = single-channel memory, which can lower FPS in CPU-heavy games)' }
        $l += $line
        $l += "Windows: $($os.Caption) (build $($os.BuildNumber))"
    } catch { $l += 'RAM / Windows: could not be read' }
    try {
        foreach ($pd in @(Get-PhysicalDisk -ErrorAction Stop)) {
            if ("$($pd.MediaType)" -eq 'HDD') { $h.HasHdd = $true }
            $l += "Drive: $($pd.FriendlyName)  -  $($pd.MediaType), $(Format-Gb $pd.Size)"
        }
    } catch { $l += 'Drives: could not be read' }
    try { if (Get-CimInstance Win32_Battery) { $h.Laptop = $true; $l += 'Laptop: yes - plug in the charger while gaming for full performance' } } catch {}
    $l += 'Temperatures: GPU temperature is read from the NVIDIA driver when present. Windows has no reliable CPU temperature reading, so bluFPS watches CPU clock speed instead - a CPU running far below its maximum under load is the real sign of heat or power limiting.'
    $h.Text = $l -join "`n"
    return $h
}
# runs in a background runspace: samples CPU / busiest game thread / GPU 3D / RAM / disk once per second
function Invoke-PerfSampler { param($ctx)
    $ErrorActionPreference = 'SilentlyContinue'
    $cores = [math]::Max(1, [int]$env:NUMBER_OF_PROCESSORS)
    if ($ctx.Delay -gt 0) { for ($i = 0; $i -lt ($ctx.Delay * 5) -and -not $ctx.Stop; $i++) { Start-Sleep -Milliseconds 200 } }
    $gp = $null; if ($ctx.GamePid) { $gp = Get-Process -Id $ctx.GamePid }
    function Test-Ctr { param($p) try { $null = Get-Counter -Counter $p -MaxSamples 1 -ErrorAction Stop; return $true } catch { return $false } }
    $hasGpu = Test-Ctr '\GPU Engine(*)\Utilization Percentage'
    $hasFreq = Test-Ctr '\Processor Information(_Total)\% of Maximum Frequency'
    $paths = @('\Processor(*)\% Processor Time', '\Memory\% Committed Bytes In Use', '\PhysicalDisk(_Total)\Avg. Disk Queue Length')
    if ($hasGpu) { $paths += '\GPU Engine(*engtype_3D)\Utilization Percentage' }
    if ($hasFreq) { $paths += '\Processor Information(_Total)\% of Maximum Frequency' }
    $nv = $null
    foreach ($cand in "$env:SystemRoot\System32\nvidia-smi.exe", "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe") { if (Test-Path -LiteralPath $cand) { $nv = $cand; break } }
    $nvField = 'clocks_throttle_reasons.active'; $lastTemp = $null; $lastThermal = $false; $lastAcpi = $null; $iter = 0
    $snap0 = @{}
    foreach ($p in Get-Process) { try { $snap0[$p.Id] = @($p.ProcessName, $p.TotalProcessorTime.TotalSeconds) } catch {} }
    $t0 = Get-Date; $prevThr = @{}; $prevAt = $null
    while (-not $ctx.Stop) {
        $now = Get-Date
        if ($ctx.Seconds -gt 0 -and ($now - $t0).TotalSeconds -ge $ctx.Seconds) { break }
        $s = @{ Cpu = $null; MaxCore = $null; Commit = $null; DiskQ = $null; Gpu3d = $null; GameGpu = $null; Ram = $null; Thread = $null; Freq = $null; GpuTemp = $null; GpuThermal = $false; AcpiTemp = $null }
        $r = $null
        try { $r = (Get-Counter -Counter $paths -ErrorAction Stop).CounterSamples } catch {}
        $gRows = @()
        if ($r) {
            foreach ($x in $r) {
                $pth = "$($x.Path)"
                if ($pth -like '*\processor(*') {
                    if ($x.InstanceName -eq '_total') { $s.Cpu = $x.CookedValue }
                    elseif ($null -eq $s.MaxCore -or $x.CookedValue -gt $s.MaxCore) { $s.MaxCore = $x.CookedValue }
                }
                elseif ($pth -like '*committed bytes in use') { $s.Commit = $x.CookedValue }
                elseif ($pth -like '*avg. disk queue length') { $s.DiskQ = $x.CookedValue }
                elseif ($pth -like '*% of maximum frequency') { $s.Freq = $x.CookedValue }
                elseif ($hasGpu -and $pth -like '*gpu engine*') { $gRows += @{ N = "$($x.InstanceName)"; V = [double]$x.CookedValue } }
            }
        }
        if (-not $hasGpu) { try { foreach ($x in @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine)) { if ("$($x.Name)" -match 'engtype_3D') { $gRows += @{ N = "$($x.Name)"; V = [double]$x.UtilizationPercentage } } } } catch {} }
        if ($gRows.Count) {
            $byLuid = @{}; $game = 0.0
            foreach ($row in $gRows) {
                if ($row.N -match 'pid_(\d+)_luid_(0x[0-9a-fA-F]+_0x[0-9a-fA-F]+)') {
                    $byLuid[$Matches[2]] += $row.V
                    if ($ctx.GamePid -and [int]$Matches[1] -eq $ctx.GamePid) { $game += $row.V }
                }
            }
            if ($byLuid.Count) { $s.Gpu3d = [math]::Min(100, ($byLuid.Values | Measure-Object -Maximum).Maximum) }
            if ($ctx.GamePid) { $s.GameGpu = [math]::Min(100, $game) }
        }
        if ($null -eq $s.DiskQ) { try { $s.DiskQ = [double](Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'").AvgDiskQueueLength } catch {} }
        if ($null -eq $s.Commit) { try { $s.Commit = [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).PercentCommittedBytesInUse } catch {} }
        try { $os = Get-CimInstance Win32_OperatingSystem; $s.Ram = 100 * (1 - [double]$os.FreePhysicalMemory / [double]$os.TotalVisibleMemorySize) } catch {}
        if ($null -eq $s.Cpu) { try { $s.Cpu = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime } catch {} }
        if ($nv -and ($iter % 3 -eq 0)) {
            try {
                $out = & $nv "--query-gpu=temperature.gpu,$nvField" '--format=csv,noheader,nounits' 2>$null
                if (-not $out -or "$out" -match 'not a valid|Field|rror') { $nvField = 'clocks_event_reasons.active'; $out = & $nv "--query-gpu=temperature.gpu,$nvField" '--format=csv,noheader,nounits' 2>$null }
                $parts = "$(@($out)[0])".Split(',')
                if ($parts.Count -ge 2) {
                    $tv = 0.0; if ([double]::TryParse($parts[0].Trim(), [ref]$tv)) { $lastTemp = $tv }
                    try { $bits = [Convert]::ToInt64(($parts[1].Trim() -replace '^0x', ''), 16); $lastThermal = [bool]($bits -band 0x68) } catch {}
                }
            } catch {}
        }
        if ($iter % 5 -eq 0) {
            try { $z = @(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature | ForEach-Object { $_.CurrentTemperature / 10 - 273.15 } | Where-Object { $_ -gt 10 -and $_ -lt 120 }); if ($z.Count) { $lastAcpi = ($z | Measure-Object -Maximum).Maximum } } catch {}
        }
        $s.GpuTemp = $lastTemp; $s.GpuThermal = $lastThermal; $s.AcpiTemp = $lastAcpi; $iter++
        if ($gp) {
            try {
                $gp.Refresh(); $cur = @{}
                foreach ($th in $gp.Threads) { try { $cur[$th.Id] = $th.TotalProcessorTime.TotalSeconds } catch {} }
                if ($prevAt) {
                    $dt = ($now - $prevAt).TotalSeconds; $best = 0
                    foreach ($k in $cur.Keys) { if ($prevThr.ContainsKey($k) -and $dt -gt 0) { $u = 100 * ($cur[$k] - $prevThr[$k]) / $dt; if ($u -gt $best) { $best = $u } } }
                    $s.Thread = [math]::Min(100, $best)
                }
                $prevThr = $cur; $prevAt = $now
            } catch {}
        }
        [void]$ctx.Samples.Add($s); $ctx.Last = $s
        Start-Sleep -Milliseconds 150
    }
    if ($ctx.WantHogs) {
        $dur = [math]::Max(1, ((Get-Date) - $t0).TotalSeconds); $list = @()
        foreach ($p in Get-Process) {
            try {
                if ($p.Id -eq $ctx.GamePid -or -not $snap0.ContainsKey($p.Id)) { continue }
                $pct = 100 * ($p.TotalProcessorTime.TotalSeconds - $snap0[$p.Id][1]) / $dur / $cores
                if ($pct -ge 1.0) { $list += [pscustomobject]@{ Name = $p.ProcessName; Pct = $pct } }
            } catch {}
        }
        $ctx.Hogs = @($list | Where-Object { $_.Name -notmatch '^(Idle|System|Registry|MsMpEng|dwm|csrss|audiodg|bluFPS|powershell)$' } | Group-Object Name | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Pct = [math]::Round(($_.Group | Measure-Object Pct -Sum).Sum, 1) } } | Sort-Object Pct -Descending | Select-Object -First 5)
    }
}
function Get-Avg($samples, $key) {
    $v = @($samples | ForEach-Object { $_[$key] } | Where-Object { $null -ne $_ })
    if ($v.Count) { return ($v | Measure-Object -Average).Average }
    return $null
}
function Pct-Text($v) { if ($null -eq $v) { return '?' }; return ('{0:N0}%' -f $v) }
function Get-Diagnosis($ctx) {
    $S = @($ctx.Samples); $hw = $ctx.Hw; $game = [bool]$ctx.GamePid
    $o = @{ Text = ''; Rec = $null; Kind = $null }
    if ($S.Count -lt 4) { $o.Text = 'Not enough measurements were collected (Windows performance counters may be unavailable). Nothing was changed.'; return $o }
    $cpu = Get-Avg $S 'Cpu'; $thr = Get-Avg $S 'Thread'; $ram = Get-Avg $S 'Ram'; $commit = Get-Avg $S 'Commit'; $dq = Get-Avg $S 'DiskQ'
    $g1 = Get-Avg $S 'Gpu3d'; $g2 = Get-Avg $S 'GameGpu'; $gpu = $g1
    if ($null -ne $g2 -and ($null -eq $gpu -or $g2 -gt $gpu)) { $gpu = $g2 }
    $L = @()
    if (-not $game) {
        $L += 'No game was running, so this is a check of your PC at rest.'
        $L += "Measured: CPU $(Pct-Text $cpu), RAM $(Pct-Text $ram)."
        if ($null -ne $cpu -and $cpu -ge 25) { $L += 'Your CPU is busy even without a game - the programs listed below are the cause.' }
        elseif ($null -ne $ram -and $ram -ge 80) { $L += 'RAM is already 80%+ used before a game starts. Closing programs you do not need will help.' }
        else { $L += 'Nothing unusual at rest. Start a game, switch back here and press Analyze again to find what limits your FPS.' }
    } else {
        $L += "Measured while $($ctx.GameName) was running:  CPU $(Pct-Text $cpu), busiest game thread $(Pct-Text $thr) of one core, GPU 3D $(Pct-Text $gpu), RAM $(Pct-Text $ram), disk queue $(if ($null -ne $dq) { '{0:N1}' -f $dq } else { '?' })."
        $gpuB = ($null -ne $gpu -and $gpu -ge 90)
        $cpuB = (($null -ne $thr -and $thr -ge 85) -or ($null -ne $cpu -and $cpu -ge 88))
        $memB = (($null -ne $ram -and $ram -ge 92) -or ($null -ne $commit -and $commit -ge 92))
        $dskB = ($null -ne $dq -and $dq -ge 2)
        $hogTotal = 0.0; foreach ($hg in @($ctx.Hogs)) { $hogTotal += $hg.Pct }
        if ($gpuB -and $cpuB) { $o.Kind = 'Both'; $L += 'VERDICT: both CPU and GPU are heavily used. Reducing background CPU use can still help frame-time consistency.'; $o.Rec = 'Performance' }
        elseif ($gpuB) { $o.Kind = 'GPU'; $L += 'VERDICT: GPU-limited. Your graphics card sets the frame rate here, so bluFPS cannot add much FPS. The real gains are lowering resolution or graphics settings, or DLSS/FSR. The Balanced profile is enough.'; $o.Rec = 'Balanced' }
        elseif ($cpuB) {
            $o.Kind = 'CPU'
            if ($null -ne $thr -and $thr -ge 85) { $L += 'VERDICT: CPU-limited by one main game thread (single-core speed). No tweak can raise that speed, but removing background CPU use leaves it more headroom and steadier frame times.' }
            else { $L += 'VERDICT: CPU-limited - your CPU is nearly fully used. Less background CPU use gives the game more of it.' }
            $o.Rec = 'Performance'; if ($hogTotal -ge 10 -or ($hw -and $hw.Threads -gt 0 -and $hw.Threads -le 6)) { $o.Rec = 'Extreme' }
        }
        elseif ($memB) { $o.Kind = 'Memory'; $L += 'VERDICT: memory-limited. RAM is nearly full, which causes stutter. Closing programs you do not need helps more than any setting.'; $o.Rec = 'Extreme' }
        elseif ($dskB) { $o.Kind = 'Storage'; $L += 'VERDICT: storage-limited. The drive is queuing requests, which causes hitching. Keep the game on an SSD if you can.'; $o.Rec = 'Balanced' }
        else { $o.Kind = 'None'; $L += 'VERDICT: no hardware limit was reached in this test. FPS may be capped by V-Sync, an FPS limiter or the game engine - check those first; an optimizer will not help there.'; $o.Rec = 'Balanced' }
    }
    $freq = Get-Avg $S 'Freq'
    if ($null -ne $freq -and $null -ne $cpu -and $cpu -ge 70 -and $freq -lt 80) { $L += "Note: while the CPU was busy it ran at only $(Pct-Text $freq) of its maximum speed. That points to heat or power limiting - check cooling, dust and the Windows power mode." }
    $gtVals = @($S | ForEach-Object { $_['GpuTemp'] } | Where-Object { $null -ne $_ }); $gtMax = $null
    if ($gtVals.Count) { $gtMax = ($gtVals | Measure-Object -Maximum).Maximum }
    if (@($S | Where-Object { $_['GpuThermal'] }).Count -gt 0) { $L += 'Note: the NVIDIA driver reported thermal slowdown during the test - the GPU is lowering its speed because it is too hot.' }
    elseif ($null -ne $gtMax -and $gtMax -ge 85) { $L += "Note: the GPU reached $([int]$gtMax) C, which is hot and may make it lower its speed." }
    elseif ($null -ne $gtMax) { $L += "GPU temperature stayed at or below $([int]$gtMax) C - no sign of heat limiting." }
    if (@($ctx.Hogs).Count) { $L += 'Background CPU use: '  + ((@($ctx.Hogs) | ForEach-Object { "$($_.Name) $($_.Pct)%" }) -join ', ') }
    if ($hw -and $hw.Modules -eq 1) { $L += 'Note: only one RAM module is installed (single channel). A second matching module is one of the biggest FPS upgrades for CPU-heavy games.' }
    if ($hw -and $hw.Laptop) { $L += 'Note: this is a laptop - results are best when plugged in with a performance power mode.' }
    $o.Text = $L -join "`n"
    return $o
}
function Get-ActiveGame {
    $order = @(); if ($script:selGame) { $order += $script:selGame }; $order += @($script:library)
    $procs = @(Get-ProcList)
    foreach ($g in $order) {
        $dir = "$($g.Dir)".TrimEnd('\'); if (-not $dir) { continue }
        $pre = $dir + '\'; $best = $null
        foreach ($w in $procs) { if ($w.Path.StartsWith($pre, [StringComparison]::OrdinalIgnoreCase) -and (-not $best -or $w.Mem -gt $best.Mem)) { $best = $w } }
        if ($best) { $p = Get-Process -Id $best.Id -ErrorAction SilentlyContinue; if ($p) { return @{ Game = $g; Proc = $p } } }
    }
    return $null
}
function Start-Analyze {
    if ($script:anaPs) { return }
    $ag = Get-ActiveGame
    $ctx = [hashtable]::Synchronized(@{ Stop = $false; Seconds = 12; Delay = 0; WantHogs = $true; GamePid = 0; GameName = ''; Samples = (New-Object System.Collections.ArrayList); Last = $null; Hogs = @(); Hw = $null; Done = $false })
    if ($ag) { $ctx.GamePid = $ag.Proc.Id; $ctx.GameName = $ag.Game.Name; $ctx.Delay = 8 }
    $script:anaCtx = $ctx; $script:anaStart = Get-Date
    $script:anaGame = $null; if ($ag) { $script:anaGame = $ag.Game }
    $fns = foreach ($n in 'Format-Gb', 'Get-HwInfo', 'Invoke-PerfSampler') { "function $n {`n" + (Get-Command $n -CommandType Function).ScriptBlock.ToString() + "`n}" }
    $script:anaPs = [powershell]::Create()
    [void]$script:anaPs.AddScript("param(`$ctxArg)`n" + ($fns -join "`n") + "`ntry { `$ctxArg.Hw = Get-HwInfo; Invoke-PerfSampler `$ctxArg } finally { `$ctxArg.Done = `$true }").AddArgument($ctx)
    $script:anaAsync = $script:anaPs.BeginInvoke()
    $c.btnAnalyze.IsEnabled = $false; $c.btnApplyRec.Visibility = 'Collapsed'
    $c.perfBar.Value = 0; $c.perfBar.Visibility = 'Visible'
    $c.perfDiag.Text = 'Starting...'
    if (-not $script:anaTimer) {
        $script:anaTimer = New-Object Windows.Threading.DispatcherTimer
        $script:anaTimer.Interval = [TimeSpan]::FromMilliseconds(500)
        $script:anaTimer.Add_Tick({ Guard 'Analyze' { Poll-Analyze } })
    }
    $script:anaTimer.Start()
}
function Poll-Analyze {
    $ctx = $script:anaCtx; if (-not $ctx) { return }
    $el = ((Get-Date) - $script:anaStart).TotalSeconds
    $done = $ctx.Done -or ($script:anaAsync -and $script:anaAsync.IsCompleted)
    if (-not $done) {
        if ($el -lt $ctx.Delay) { $c.perfBar.Value = 0; $c.perfDiag.Text = "Switch back to $($ctx.GameName) now and keep playing - measuring starts in $([int]($ctx.Delay - $el)) s..." }
        else { $c.perfBar.Value = [math]::Min(99, 100 * ($el - $ctx.Delay) / $ctx.Seconds); $c.perfDiag.Text = "Measuring...  $($ctx.Samples.Count) measurements so far" }
        if ($el -gt ($ctx.Delay + $ctx.Seconds + 40)) { $ctx.Stop = $true }
        return
    }
    $script:anaTimer.Stop()
    try { [void]$script:anaPs.EndInvoke($script:anaAsync) } catch {}
    try { $script:anaPs.Dispose() } catch {}
    $script:anaPs = $null; $script:anaAsync = $null
    $c.perfBar.Visibility = 'Collapsed'; $c.btnAnalyze.IsEnabled = $true
    if ($ctx.Hw) { $c.perfHw.Text = $ctx.Hw.Text }
    $d = Get-Diagnosis $ctx
    if ($ctx.Hw) { Save-HwCache $ctx.Hw }
    if ($script:anaGame -and $d.Kind) { Set-Prop $script:anaGame 'LastVerdict' $d.Kind; Save-Library; $d.Text += "`nSaved for this game: the Auto profile now uses this result." }
    $c.perfDiag.Text = $d.Text
    $script:recProfile = $d.Rec
    if ($d.Rec) { $c.btnApplyRec.Content = "Apply recommended profile: $($d.Rec)"; $c.btnApplyRec.Visibility = 'Visible' }
    Log 'PC analysis finished.'
}

# --- real FPS through PresentMon (free tool by Intel). bluFPS never shows estimated FPS. ---
function Find-PresentMon {
    $cands = @()
    if ($script:S.PresentMon) { $cands += "$($script:S.PresentMon)" }
    $td = Join-Path $script:AppRoot 'tools'
    $td2 = Join-Path $script:dataDir 'tools'
    if (Test-Path $td2) { $cands += @(Get-ChildItem $td2 -Filter 'PresentMon*.exe' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
    if (Test-Path $td) { $cands += @(Get-ChildItem $td -Filter 'PresentMon*.exe' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
    foreach ($d in "$env:ProgramFiles\Intel\PresentMon", "${env:ProgramFiles(x86)}\Intel\PresentMon", "$env:ProgramFiles\PresentMon") {
        if ($d -and (Test-Path $d)) { $cands += @(Get-ChildItem $d -Filter 'PresentMon*.exe' -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
    }
    foreach ($x in $cands) { if ($x -and (Test-Path -LiteralPath $x)) { return $x } }
    return $null
}
function Update-PmStatus {
    $pm = Find-PresentMon
    if ($pm) { $c.pmStatus.Text = "PresentMon found: $pm" }
    else { $c.pmStatus.Text = 'Real FPS needs PresentMon, a free tool by Intel. Press Get PresentMon, download the 64-bit .exe, then press Select PresentMon and pick it. Until then bluFPS shows no FPS rather than made-up numbers.' }
}
function Launch-Capture($cap) {
    $d = '-'; if ($cap.Style -eq 2) { $d = '--' }
    $a = "$($d)process_name `"$($cap.Proc)`" $($d)output_file `"$($cap.Csv)`" $($d)stop_existing_session"
    if ($cap.Seconds -gt 0) { $a += " $($d)timed $($cap.Seconds) $($d)terminate_after_timed" }
    $cap.Ps = Start-Process -FilePath $cap.Pm -ArgumentList $a -WindowStyle Hidden -PassThru
}
function Start-Capture($procName, $seconds, $label) {
    $pm = Find-PresentMon
    if (-not $pm) { throw 'PresentMon was not found.' }
    $dir = Join-Path $script:dataDir 'captures'; New-Item $dir -ItemType Directory -Force | Out-Null
    Get-ChildItem $dir -Filter *.csv -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -Skip 12 | Remove-Item -ErrorAction SilentlyContinue
    $csv = Join-Path $dir ("$label-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.csv')
    $cap = @{ Pm = $pm; Csv = $csv; Proc = $procName; Seconds = $seconds; Pos = 0L; Idx = -1; Frames = (New-Object 'System.Collections.Generic.List[double]'); Started = (Get-Date); LastTick = (Get-Date); Style = (Get-PresentMonStyle $pm); Ps = $null }
    Launch-Capture $cap
    return $cap
}
function Read-Capture($cap) {
    if (-not (Test-Path -LiteralPath $cap.Csv)) { return 0 }
    $txt = $null
    try {
        $fs = New-Object IO.FileStream($cap.Csv, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try { [void]$fs.Seek($cap.Pos, [IO.SeekOrigin]::Begin); $txt = (New-Object IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Dispose() }
    } catch { return 0 }
    if (-not $txt) { return 0 }
    $cut = $txt.LastIndexOf("`n")
    if ($cut -lt 0) { return 0 }
    $done = $txt.Substring(0, $cut + 1)
    $cap.Pos += [Text.Encoding]::UTF8.GetByteCount($done)
    $added = 0
    foreach ($line in $done.Split("`n")) {
        $line = $line.TrimEnd("`r")
        if (-not $line) { continue }
        $f = $line.Split(',')
        if ($cap.Idx -lt 0) {
            for ($i = 0; $i -lt $f.Count; $i++) { $nm = $f[$i].Trim().ToLower(); if ($nm -eq 'msbetweenpresents' -or $nm -eq 'frametime') { $cap.Idx = $i; break } }
            continue
        }
        if ($cap.Idx -lt $f.Count) {
            $v = 0.0
            if ([double]::TryParse($f[$cap.Idx], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v) -and $v -gt 0) { $cap.Frames.Add($v); $added++ }
        }
    }
    return $added
}
function Get-FrameStats($list) {
    $n = $list.Count
    if ($n -lt 30) { return $null }
    $a = $list.ToArray(); $sum = 0.0
    foreach ($x in $a) { $sum += $x }
    $avg = $sum / $n
    if ($avg -le 0) { return $null }
    $sorted = [double[]]$a.Clone(); [Array]::Sort($sorted)
    $k = [math]::Max(1, [int][math]::Ceiling($n * 0.01)); $w = 0.0
    for ($i = $n - $k; $i -lt $n; $i++) { $w += $sorted[$i] }
    $med = $sorted[[int]($n / 2)]; $st = 0; $var = 0.0
    foreach ($x in $a) { if ($x -gt (2 * $med)) { $st++ }; $var += ($x - $avg) * ($x - $avg) }
    return @{ Frames = $n; AvgFps = (1000 / $avg); Low1 = (1000 / ($w / $k)); MinFps = (1000 / $sorted[$n - 1]); WorstMs = $sorted[$n - 1]; AvgMs = $avg; Stutters = $st; Var = (100 * [math]::Sqrt($var / $n) / $avg) }
}
function Stop-Capture($cap) { try { if ($cap -and $cap.Ps -and -not $cap.Ps.HasExited) { $cap.Ps.Kill() } } catch {} }
function Check-CaptureStart($cap) {
    # returns 'ok', 'retry' (switched to the older command style) or 'failed'
    $el = ((Get-Date) - $cap.Started).TotalSeconds
    if ($cap.Ps.HasExited -and $cap.Frames.Count -eq 0 -and $el -lt 15) {
        if ($cap.Style -eq 2) { $cap.Style = 1; $cap.Pos = 0L; $cap.Idx = -1; Remove-Item $cap.Csv -ErrorAction SilentlyContinue; Launch-Capture $cap; $cap.Started = Get-Date; return 'retry' }
        return 'failed'
    }
    return 'ok'
}
$script:pmFail = 'PresentMon started but captured nothing. Check that bluFPS runs as administrator, the game is on screen, and this is the 64-bit PresentMon from Intel.'

function Start-FpsMonitor {
    if ($script:cap) { return }
    if ($script:bench) { $c.pmStatus.Text = 'A before/after test is running.'; return }
    $ag = Get-ActiveGame
    if (-not $ag) { $c.pmStatus.Text = 'No game from your library is running. Start a game first (add it on the Games page).'; return }
    if (-not (Find-PresentMon)) { Update-PmStatus; return }
    $script:cap = Start-Capture ($ag.Proc.ProcessName + '.exe') 0 'live'
    $ctx = [hashtable]::Synchronized(@{ Stop = $false; Seconds = 0; Delay = 0; WantHogs = $false; GamePid = $ag.Proc.Id; GameName = $ag.Game.Name; Samples = (New-Object System.Collections.ArrayList); Last = $null; Hogs = @(); Hw = $null; Done = $false })
    $script:liveCtx = $ctx
    $fns = foreach ($n in 'Invoke-PerfSampler') { "function $n {`n" + (Get-Command $n -CommandType Function).ScriptBlock.ToString() + "`n}" }
    $script:livePs = [powershell]::Create()
    [void]$script:livePs.AddScript("param(`$ctxArg)`n" + ($fns -join "`n") + "`ntry { Invoke-PerfSampler `$ctxArg } finally { `$ctxArg.Done = `$true }").AddArgument($ctx)
    $script:liveAsync = $script:livePs.BeginInvoke()
    $c.btnFpsStart.Visibility = 'Collapsed'; $c.btnFpsStop.Visibility = 'Visible'
    $c.pmStatus.Text = "Measuring $($ag.Game.Name) ($($ag.Proc.ProcessName).exe)..."
    if (-not $script:fpsTimer) {
        $script:fpsTimer = New-Object Windows.Threading.DispatcherTimer
        $script:fpsTimer.Interval = [TimeSpan]::FromSeconds(1)
        $script:fpsTimer.Add_Tick({ Guard 'FPS monitor' { Poll-Fps } })
    }
    $script:fpsTimer.Start()
}
function Stop-FpsMonitor {
    try { $script:fpsTimer.Stop() } catch {}
    Stop-Capture $script:cap; $script:cap = $null
    try { $script:liveCtx.Stop = $true } catch {}
    try { if ($script:livePs) { $script:livePs.BeginStop($null, $null) | Out-Null } } catch {}
    $script:livePs = $null
    $c.btnFpsStart.Visibility = 'Visible'; $c.btnFpsStop.Visibility = 'Collapsed'
}
function Poll-Fps {
    $cap = $script:cap; if (-not $cap) { return }
    $added = Read-Capture $cap
    $chk = Check-CaptureStart $cap
    if ($chk -eq 'retry') { return }
    if ($chk -eq 'failed') { Stop-FpsMonitor; $c.pmStatus.Text = $script:pmFail; return }
    $now = Get-Date; $dt = ($now - $cap.LastTick).TotalSeconds; $cap.LastTick = $now
    if ($dt -gt 0) { $c.fpsCur.Text = ('{0:N0}' -f ($added / $dt)) }
    if ($cap.Frames.Count -gt 150000) { $cap.Frames.RemoveRange(0, 50000) }
    $st = Get-FrameStats $cap.Frames
    if ($st) {
        $c.fpsAvg.Text = ('{0:N0}' -f $st.AvgFps); $c.fpsLow.Text = ('{0:N0}' -f $st.Low1); $c.fpsMin.Text = ('{0:N0}' -f $st.MinFps)
        $c.fpsFt.Text = ('{0:N1} ms' -f $st.AvgMs); $c.fpsStab.Text = ('{0:N0}% / {1} spikes' -f $st.Var, $st.Stutters)
    }
    $s = $null; try { $s = $script:liveCtx.Last } catch {}
    if ($s) {
        $g3 = $s.Gpu3d; if ($null -eq $g3) { $g3 = $s.GameGpu }
        $gt = ''; if ($null -ne $s.GpuTemp) { $gt = " ($([int]$s.GpuTemp) C)" }
        $fq = ''; if ($null -ne $s.Freq) { $fq = " at $(Pct-Text $s.Freq) of max speed" }
        $c.perfLive.Text = "CPU $(Pct-Text $s.Cpu)$fq   -   busiest game thread $(Pct-Text $s.Thread)   -   GPU 3D $(Pct-Text $g3)$gt   -   RAM $(Pct-Text $s.Ram)"
    }
}

# --- before / after test: two real captures of the same game, with and without boost ---
function Cancel-Bench($msg) {
    $b = $script:bench
    try { $script:benchTimer.Stop() } catch {}
    if ($b) { Stop-Capture $b.Cap; if ($b.Started -and $script:sess) { try { End-Boost } catch {} } }
    $script:bench = $null
    $c.btnBenchStart.Visibility = 'Visible'; $c.btnBenchCancel.Visibility = 'Collapsed'; $c.benchBar.Visibility = 'Collapsed'
    if ($msg) { $c.benchText.Text = $msg }
}
function Start-Bench {
    if ($script:bench -or $script:cap) { return }
    if ($script:sess) { $c.benchText.Text = 'A boost is already active. Press Restore on the Games page first, so the test can measure your PC without it.'; return }
    $ag = Get-ActiveGame
    if (-not $ag) { $c.benchText.Text = 'No game from your library is running. Start a game, get into a repeatable scene, then press Start test.'; return }
    if (-not (Find-PresentMon)) { Update-PmStatus; $c.benchText.Text = 'The test needs PresentMon (see above) so it can measure real frame times.'; return }
    $script:bench = @{ Stage = 'before'; Game = $ag.Game; Proc = ($ag.Proc.ProcessName + '.exe'); Secs = $script:benchSecs; T0 = (Get-Date); Base = $null; Boost = $null; Cap = $null; Started = $false }
    $script:bench.Cap = Start-Capture $script:bench.Proc $script:benchSecs 'before'
    $c.btnBenchStart.Visibility = 'Collapsed'; $c.btnBenchCancel.Visibility = 'Visible'; $c.benchBar.Visibility = 'Visible'; $c.benchBar.Value = 0
    if (-not $script:benchTimer) {
        $script:benchTimer = New-Object Windows.Threading.DispatcherTimer
        $script:benchTimer.Interval = [TimeSpan]::FromSeconds(1)
        $script:benchTimer.Add_Tick({ Guard 'Before/after test' { Poll-Bench } })
    }
    $script:benchTimer.Start()
}
function Format-BenchResult($b) {
    $ba = $b.Base; $bb = $b.Boost
    $dAvg = 100 * ($bb.AvgFps - $ba.AvgFps) / $ba.AvgFps; $dLow = 100 * ($bb.Low1 - $ba.Low1) / $ba.Low1
    $L = @("Game: $($b.Game.Name)   (each run $($b.Secs) s, $($ba.Frames) and $($bb.Frames) frames)", '')
    $L += ('Average FPS      {0,7:N1}  ->  {1,7:N1}    ({2:+0.0;-0.0}%)' -f $ba.AvgFps, $bb.AvgFps, $dAvg)
    $L += ('1% low FPS       {0,7:N1}  ->  {1,7:N1}    ({2:+0.0;-0.0}%)' -f $ba.Low1, $bb.Low1, $dLow)
    $L += ('Worst frame      {0,5:N1} ms  ->  {1,5:N1} ms' -f $ba.WorstMs, $bb.WorstMs)
    $L += ('Spikes (>2x typical frame)   {0}  ->  {1}' -f $ba.Stutters, $bb.Stutters)
    $L += ('Frame-time variation        {0:N1}%  ->  {1:N1}%   (lower = steadier)' -f $ba.Var, $bb.Var)
    $L += ''
    if (($dAvg -ge 3 -or $dLow -ge 3) -and $dAvg -gt -3 -and $dLow -gt -3) { $L += 'RESULT: measured improvement.' }
    elseif (($dAvg -le -3 -or $dLow -le -3) -and $dAvg -lt 3 -and $dLow -lt 3) { $L += 'RESULT: measured WORSE. This profile does not help in this game - try a lighter profile, or leave boost off.' }
    else { $L += 'RESULT: no meaningful change. Differences of a few percent are normal run-to-run variation.' }
    $L += 'These numbers are for this scene on this run. Repeat the test 2-3 times in the same spot before trusting a small difference. Boost is still active - press Restore on the Games page to undo it.'
    return ($L -join "`n")
}
function Poll-Bench {
    $b = $script:bench; if (-not $b -or $script:benchBusy) { return }
    $script:benchBusy = $true
    try {
        $el = ((Get-Date) - $b.T0).TotalSeconds
        if ($b.Stage -eq 'settle') {
            $c.benchText.Text = "Boost applied (profile: $($script:S.Level)). Letting your PC settle for 10 seconds..."
            if ($el -ge 10) { $b.Cap = Start-Capture $b.Proc $b.Secs 'after'; $b.Stage = 'boost'; $b.T0 = Get-Date }
            return
        }
        if (-not (Get-Process -Name ($b.Proc -replace '\.exe$', '') -ErrorAction SilentlyContinue)) { Cancel-Bench 'The game closed, so the test was stopped. Nothing was changed.'; return }
        [void](Read-Capture $b.Cap)
        $chk = Check-CaptureStart $b.Cap
        if ($chk -eq 'retry') { return }
        if ($chk -eq 'failed') { Cancel-Bench $script:pmFail; return }
        $n = if ($b.Stage -eq 'before') { 1 } else { 2 }
        $c.benchBar.Value = [math]::Min(100, 100 * $el / $b.Secs)
        $c.benchText.Text = "Test $n of 2: measuring $(if ($n -eq 1) { 'WITHOUT boost' } else { 'WITH boost' }) - keep playing the same scene ($([math]::Max(0, [int]($b.Secs - $el))) s left, $($b.Cap.Frames.Count) frames)"
        if (-not ($b.Cap.Ps.HasExited -or $el -gt ($b.Secs + 8))) { return }
        Start-Sleep -Milliseconds 400; [void](Read-Capture $b.Cap); Stop-Capture $b.Cap
        $st = Get-FrameStats $b.Cap.Frames
        if (-not $st) { Cancel-Bench 'Too few frames were captured to measure anything. Make sure the game is on screen and running, then try again.'; return }
        if ($b.Stage -eq 'before') {
            $b.Base = $st
            try { Boost-Safe $b.Game $false } catch { Cancel-Bench "The boost could not be applied: $($_.Exception.Message)"; return }
            if (-not $script:sess) { Cancel-Bench 'The boost did not start (see the log on the Dashboard). Nothing was measured with boost.'; return }
            $b.Started = $true; $b.Stage = 'settle'; $b.T0 = Get-Date
        } else {
            $b.Boost = $st
            $script:benchTimer.Stop()
            $c.benchText.Text = Format-BenchResult $b
            $script:bench = $null
            $c.btnBenchStart.Visibility = 'Visible'; $c.btnBenchCancel.Visibility = 'Collapsed'; $c.benchBar.Visibility = 'Collapsed'
            Log 'Before/after test finished.'
        }
    } finally { $script:benchBusy = $false }
}
$script:benchSecs = 60
$script:recProfile = $null
$c.navPerf.Add_Click({ Show-Page 'Perf' })
$c.btnAnalyze.Add_Click({ Guard 'Analyze' { Start-Analyze } })
$c.btnApplyRec.Add_Click({ Guard 'Apply profile' { if ($script:recProfile) { Set-Level $script:recProfile; $c.perfDiag.Text += "`n`nProfile set to $($script:recProfile). It applies the next time you boost a game." } } })
$c.btnPmGet.Add_Click({ Guard 'Get PresentMon' { Install-PresentMon } })
$c.btnPmSelect.Add_Click({ Guard 'Select PresentMon' {
    $d = New-Object Microsoft.Win32.OpenFileDialog -Property @{ Filter = 'PresentMon (*.exe)|*.exe'; Title = 'Select the PresentMon .exe' }
    if ($d.ShowDialog() -eq $true) { $script:S.PresentMon = $d.FileName; Save-Settings; Update-PmStatus }
} })
$c.btnFpsStart.Add_Click({ Guard 'FPS monitor' { Start-FpsMonitor } })
$c.btnFpsStop.Add_Click({ Guard 'FPS monitor' { Stop-FpsMonitor; $c.pmStatus.Text = 'Stopped.' } })
$c.btnBenchDur.Add_Click({ Guard 'Test length' { $script:benchSecs = $(if ($script:benchSecs -ge 90) { 30 } else { $script:benchSecs + 30 }); $c.btnBenchDur.Content = "Each run: $($script:benchSecs) s" } })
$c.btnBenchStart.Add_Click({ Guard 'Before/after test' { Start-Bench } })
$c.btnBenchCancel.Add_Click({ Guard 'Before/after test' { Cancel-Bench 'Test cancelled.' } })

# ---------- per-game profiles and safer defaults ----------
$script:levelKeys = 'CloseApps', 'Ram', 'Plan', 'GameMode', 'Dns', 'Prio', 'Svc', 'BgPrio', 'Sched', 'Notify', 'Gpu', 'Eco', 'ProBal', 'MemKeep', 'GpuPrio'
$script:levelOn = @{
    'Balanced'    = @('Plan', 'GameMode', 'Dns', 'Prio', 'Notify', 'Gpu')
    'Performance' = @('Plan', 'GameMode', 'Dns', 'Prio', 'Notify', 'Gpu', 'BgPrio', 'Sched', 'Eco', 'ProBal', 'MemKeep', 'GpuPrio')
    'Extreme'     = @('Plan', 'GameMode', 'Dns', 'Prio', 'Notify', 'Gpu', 'BgPrio', 'Sched', 'Eco', 'ProBal', 'MemKeep', 'GpuPrio', 'CloseApps', 'Svc', 'Ram')
}
$script:keyNames = @{ Gpu = 'High-performance GPU preference'; GpuPrio = 'GPU priority'; Ram = 'Free memory when RAM is nearly full'; MemKeep = 'Keep memory smooth'; Svc = 'Pause background services' }
$script:lastSkips = @(); $script:lastAutoPick = $null
function Get-AutoPlan($g) {
    $hw = $script:hw; $skips = @()
    $v = "$($g.LastVerdict)"
    $pick = 'Performance'
    if ($v -eq 'GPU' -or $v -eq 'Storage' -or $v -eq 'None') { $pick = 'Balanced' }
    elseif ($v -eq 'Memory') { $pick = 'Extreme' }
    elseif (-not $v -and $hw) { if (($hw.RamGb -gt 0 -and $hw.RamGb -le 8) -or ($hw.Threads -gt 0 -and $hw.Threads -le 4)) { $pick = 'Extreme' } }
    $on = @($script:levelOn[$pick])
    if ($v -eq 'GPU') { $on += 'GpuPrio' }
    $drop = @()
    if ($v -eq 'CPU') { $drop += , @('Gpu', 'the last analysis found this game CPU-limited, so GPU tweaks cannot help'); $drop += , @('GpuPrio', 'the last analysis found this game CPU-limited, so GPU tweaks cannot help') }
    if ($hw -and $null -ne $hw.GpuCount -and $hw.GpuCount -le 1) { $drop += , @('Gpu', 'you have one graphics adapter, so there is nothing to choose between') }
    if ($hw -and $null -ne $hw.RamGb -and $hw.RamGb -ge 24) { $drop += , @('Ram', "you have $($hw.RamGb) GB of RAM, so memory is not a limit"); $drop += , @('MemKeep', "you have $($hw.RamGb) GB of RAM, so memory is not a limit") }
    foreach ($d in $drop) {
        if ($on -contains $d[0]) { $on = @($on | Where-Object { $_ -ne $d[0] }); $skips += "$($script:keyNames[$d[0]]): $($d[1])" }
    }
    return @{ Profile = $pick; On = $on; Skipped = $skips }
}
function Apply-GameProfile($g) {
    $orig = @{}; $script:lastSkips = @(); $script:lastAutoPick = $null
    $pr = "$($g.Profile)"
    if (-not $pr -or $pr -eq 'Default') { if ("$($script:S.Level)" -eq 'Auto') { $pr = 'Auto' } else { $pr = '' } }
    $on = $null
    if ($pr -eq 'Auto') { $plan = Get-AutoPlan $g; $on = $plan.On; $script:lastSkips = @($plan.Skipped); $script:lastAutoPick = $plan.Profile }
    elseif ($pr -and $script:levelOn.ContainsKey($pr)) { $on = $script:levelOn[$pr] }
    if ($null -ne $on) { foreach ($k in $script:levelKeys) { $orig[$k] = $script:S[$k]; $script:S[$k] = ($on -contains $k) } }
    return $orig
}
# hardware facts are read once in the background and remembered, so Auto can use them instantly
$script:hwPath = Join-Path $script:dataDir 'hw.json'
$script:hw = $null; $script:hwPs = $null
function Load-HwCache { try { if (Test-Path $script:hwPath) { $script:hw = [IO.File]::ReadAllText($script:hwPath) | ConvertFrom-Json } } catch {} }
function Save-HwCache($h) {
    try {
        $o = @{ Threads = $h.Threads; RamGb = $h.RamGb; Modules = $h.Modules; HasHdd = $h.HasHdd; Laptop = $h.Laptop; GpuCount = $h.GpuCount; CpuName = $h.CpuName; When = (Get-Date).ToString('s') }
        New-Item $script:dataDir -ItemType Directory -Force | Out-Null
        [IO.File]::WriteAllText($script:hwPath, (ConvertTo-Json -InputObject $o), (New-Object Text.UTF8Encoding $false))
        $script:hw = [pscustomobject]$o
    } catch {}
}
function Start-HwCache {
    if ($script:hwPs) { return }
    $script:hwCtx = [hashtable]::Synchronized(@{ Hw = $null; Done = $false })
    $fns = foreach ($n in 'Format-Gb', 'Get-HwInfo') { "function $n {`n" + (Get-Command $n -CommandType Function).ScriptBlock.ToString() + "`n}" }
    $script:hwPs = [powershell]::Create()
    [void]$script:hwPs.AddScript("param(`$a)`n" + ($fns -join "`n") + "`ntry { `$a.Hw = Get-HwInfo } finally { `$a.Done = `$true }").AddArgument($script:hwCtx)
    [void]$script:hwPs.BeginInvoke()
    $script:hwTries = 0
    if (-not $script:hwTimer) {
        $script:hwTimer = New-Object Windows.Threading.DispatcherTimer
        $script:hwTimer.Interval = [TimeSpan]::FromSeconds(2)
        $script:hwTimer.Add_Tick({ Guard 'Hardware check' {
            $script:hwTries++
            if ($script:hwCtx.Done) { $script:hwTimer.Stop(); if ($script:hwCtx.Hw) { Save-HwCache $script:hwCtx.Hw }; try { $script:hwPs.Dispose() } catch {}; $script:hwPs = $null }
            elseif ($script:hwTries -gt 30) { $script:hwTimer.Stop(); try { [void]$script:hwPs.BeginStop($null, $null) } catch {}; $script:hwPs = $null }
        } })
    }
    $script:hwTimer.Start()
}
function Test-HddDrive($path) {
    try {
        $letter = ("$path").Substring(0, 1)
        if (-not $script:hddCache) { $script:hddCache = @{} }
        if ($script:hddCache.ContainsKey($letter)) { return $script:hddCache[$letter] }
        $pd = Get-Partition -DriveLetter $letter -ErrorAction Stop | Get-Disk -ErrorAction Stop | Get-PhysicalDisk -ErrorAction Stop | Select-Object -First 1
        $r = ("$($pd.MediaType)" -eq 'HDD'); $script:hddCache[$letter] = $r
        return $r
    } catch { return $false }
}
$c.btnGameProfile.Add_Click({ Guard 'Game profile' {
    $g = $script:selGame; if (-not $g) { return }
    $order = 'Default', 'Auto', 'Balanced', 'Performance', 'Extreme', 'Off'
    $cur = "$($g.Profile)"; if (-not $cur) { $cur = 'Default' }
    $idx = [array]::IndexOf($order, $cur); if ($idx -lt 0) { $idx = 0 }
    Set-Prop $g 'Profile' $order[($idx + 1) % $order.Count]
    Save-Library; Show-GameDetail
} })

function End-Boost {
    $bk = $null; try { $bk = $script:sess.CfgBackup } catch {}
    try { End-BoostCore } finally { if ($bk) { foreach ($k in @($bk.Keys)) { $script:S[$k] = $bk[$k] } } }
}

function Get-PresentMonStyle($pm) {
    if (-not $script:pmStyle) { $script:pmStyle = @{} }
    if ($script:pmStyle.ContainsKey($pm)) { return $script:pmStyle[$pm] }
    $style = 2
    try {
        $tmp = Join-Path $env:TEMP ('blufps-pm-' + [guid]::NewGuid().ToString('N') + '.txt')
        $p = Start-Process -FilePath $pm -ArgumentList '--help' -WindowStyle Hidden -PassThru -RedirectStandardOutput $tmp -RedirectStandardError ($tmp + '.err')
        [void]$p.WaitForExit(6000); if (-not $p.HasExited) { try { $p.Kill() } catch {} }
        $txt = ''
        foreach ($f in $tmp, ($tmp + '.err')) { if (Test-Path $f) { $txt += [string](Get-Content $f -Raw -ErrorAction SilentlyContinue); Remove-Item $f -ErrorAction SilentlyContinue } }
        if ($txt -match '--process_name') { $style = 2 } elseif ($txt -match '-process_name') { $style = 1 }
    } catch {}
    $script:pmStyle[$pm] = $style
    return $style
}
function Install-PresentMon {
    $ans = [Windows.MessageBox]::Show("bluFPS will download PresentMon (free and open source, by Intel) from its official GitHub page, github.com/GameTechDev/PresentMon, and keep it in bluFPS's own folder. bluFPS may pause for a moment while it downloads. Continue?", 'Download PresentMon', 'YesNo', 'Question')
    if ($ans -ne 'Yes') { return }
    $c.pmStatus.Text = 'Looking up the latest PresentMon...'; Pump
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/GameTechDev/PresentMon/releases/latest' -Headers @{ 'User-Agent' = 'bluFPS' } -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match '^PresentMon.*x64.*\.exe$' -and $_.name -notmatch 'Capture|Service|Control|Debug|Runtime' } | Select-Object -First 1
        if (-not $asset) { throw 'the latest release has no standalone 64-bit .exe' }
        if ("$($asset.browser_download_url)" -notmatch '^https://github\.com/GameTechDev/PresentMon/releases/download/') { throw 'unexpected download address' }
        $dir = Join-Path $script:dataDir 'tools'; New-Item $dir -ItemType Directory -Force | Out-Null
        $dest = Join-Path $dir $asset.name
        $c.pmStatus.Text = "Downloading $($asset.name)..."; Pump
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -UseBasicParsing -TimeoutSec 180
        if ((Get-Item $dest).Length -lt 100KB) { Remove-Item $dest -ErrorAction SilentlyContinue; throw 'the downloaded file is too small' }
        $script:S.PresentMon = $dest; Save-Settings; Update-PmStatus
        Log "PresentMon downloaded: $dest"
    } catch {
        $c.pmStatus.Text = "Automatic download did not work ($($_.Exception.Message)). The releases page is opening - download the 64-bit .exe there, then press Select PresentMon."
        Start-Process 'https://github.com/GameTechDev/PresentMon/releases'
    }
}

# ---------- self-check: tests the app's own logic on THIS PC and reports plainly ----------
function Run-SelfCheck {
    $c.btnSelfCheck.IsEnabled = $false
    $rows = New-Object System.Collections.ArrayList
    function Chk($name, [scriptblock]$test) {
        $res = 'PASS'; $info = ''
        try {
            $o = & $test
            if ($o -is [hashtable]) { $res = $o.R; $info = $o.I } elseif ($o -is [string]) { $info = $o } elseif ($o -eq $false) { $res = 'FAIL' }
        } catch { $res = 'FAIL'; $info = $_.Exception.Message }
        $line = '{0,-5} {1}' -f $res, $name; if ($info) { $line += " - $info" }
        [void]$rows.Add($line); $c.selfText.Text = ($rows -join "`n"); Pump
    }
    Chk 'Running as administrator' { if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { 'yes' } else { @{ R = 'FAIL'; I = 'power plans, services and priorities need administrator rights' } } }
    Chk 'Process helper (native)' { if (Test-Native) { 'ready' } else { @{ R = 'FAIL'; I = 'the native helper did not compile' } } }
    Chk 'Power helper (priorities, memory)' { if (Test-Power) { 'ready' } else { @{ R = 'FAIL'; I = 'the power helper did not compile' } } }
    Chk 'Program file has no script errors' { $pe = Get-ParseErrors ([IO.File]::ReadAllText((Join-Path $script:AppRoot 'bluFPS.ps1'))); if ($pe.Count) { @{ R = 'FAIL'; I = $pe[0] } } else { 'clean' } }
    Chk 'Data folder is writable' { $f = Join-Path $script:dataDir 'selfcheck.tmp'; Set-Content -LiteralPath $f -Value 'x'; $ok = Test-Path $f; Remove-Item $f -ErrorAction SilentlyContinue; if ($ok) { "$script:dataDir" } else { $false } }
    Chk 'Game library' { $n = @($script:library).Count; $bad = @($script:library | Where-Object { (Get-GameStatus $_) -notlike 'Ready*' }).Count; "$n games, $bad need attention; last scan found $(@($script:detected).Count), $(@($script:lastScanErrors).Count) unreadable place(s)" }
    Chk 'Duplicate detection logic' {
        $a = [pscustomobject]@{ Name = 'Test Game'; Key = 'steam-1'; Dir = 'D:\SteamLibrary\steamapps\common\Test Game'; Exe = $null }
        $b = [pscustomobject]@{ Name = 'Test Game'; Key = 'epic-x'; Dir = 'E:\Other\Test Game'; Exe = $null }
        $n = [pscustomobject]@{ Name = 'Different'; Key = 'folder-1'; Dir = 'D:\SteamLibrary\steamapps\common\Test Game\bin'; Exe = $null }
        $d = [pscustomobject]@{ Name = 'Another Title'; Key = 'folder-2'; Dir = 'D:\Games\Another Title'; Exe = $null }
        if ((Test-SameGame $a $b) -and (Test-SameGame $a $n) -and -not (Test-SameGame $a $d)) { 'same name, nested folder and different title all handled' } else { $false }
    }
    Chk 'Hardware detection' { $h = Get-HwInfo; if ($h.CpuName) { "$($h.CpuName), $($h.RamGb) GB RAM, $($h.GpuCount) GPU(s), drives: $(if ($h.HasHdd) { 'includes a hard drive' } else { 'no hard drive' })" } else { $false } }
    Chk 'Windows performance counters' { $r = (Get-Counter -Counter '\Processor(_Total)\% Processor Time', '\Memory\% Committed Bytes In Use' -ErrorAction Stop).CounterSamples; "CPU counter works ($([int]$r[0].CookedValue)% right now)" }
    Chk 'GPU load counter' { try { $null = Get-Counter -Counter '\GPU Engine(*)\Utilization Percentage' -MaxSamples 1 -ErrorAction Stop; 'available' } catch { @{ R = 'SKIP'; I = 'not available here - the WMI fallback is used, otherwise GPU load shows as ?' } } }
    Chk 'CPU speed counter (throttling)' { try { $null = Get-Counter -Counter '\Processor Information(_Total)\% of Maximum Frequency' -MaxSamples 1 -ErrorAction Stop; 'available' } catch { @{ R = 'SKIP'; I = 'not available - heat/power limiting cannot be detected' } } }
    Chk 'GPU temperature (NVIDIA)' {
        $nv = "$env:SystemRoot\System32\nvidia-smi.exe"; if (-not (Test-Path $nv)) { $nv = "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe" }
        if (-not (Test-Path $nv)) { return @{ R = 'SKIP'; I = 'no NVIDIA driver tools found (AMD/Intel GPUs have no standard temperature reading)' } }
        $o = & $nv '--query-gpu=temperature.gpu' '--format=csv,noheader,nounits' 2>$null
        "GPU is at $(@($o)[0]) C"
    }
    Chk 'Frame-time statistics' {
        $l = New-Object 'System.Collections.Generic.List[double]'
        1..990 | ForEach-Object { $l.Add(10.0) }; 1..10 | ForEach-Object { $l.Add(50.0) }
        $st = Get-FrameStats $l
        if ($st -and [math]::Abs($st.AvgFps - 96.15) -lt 1 -and [math]::Abs($st.Low1 - 20) -lt 0.5 -and [math]::Abs($st.MinFps - 20) -lt 0.5 -and $st.Stutters -eq 10) { "average $([math]::Round($st.AvgFps, 1)), 1% low $([math]::Round($st.Low1, 1)), spikes $($st.Stutters) - as expected for the test data" } else { $false }
    }
    Chk 'PresentMon file reader' {
        $f = Join-Path $env:TEMP 'blufps-selfcheck.csv'
        [IO.File]::WriteAllText($f, "Application,ProcessID,MsBetweenPresents,Dropped`r`ngame.exe,1,16.6,0`r`ngame.exe,1,16.7,0`r`ngame.exe,1,17.0")
        $cap = @{ Csv = $f; Pos = 0L; Idx = -1; Frames = (New-Object 'System.Collections.Generic.List[double]') }
        $a1 = Read-Capture $cap
        [IO.File]::AppendAllText($f, "`r`ngame.exe,1,16.9,0`r`n")
        $a2 = Read-Capture $cap
        Remove-Item $f -ErrorAction SilentlyContinue
        if ($a1 -eq 2 -and $a2 -eq 2 -and $cap.Frames.Count -eq 4) { 'handles a half-written last line correctly' } else { @{ R = 'FAIL'; I = "read $a1 then $a2 frames (expected 2 and 2)" } }
    }
    Chk 'Profiles apply and restore' {
        $before = ($script:levelKeys | ForEach-Object { "$_=$([bool]$script:S[$_])" }) -join ','
        $g = [pscustomobject]@{ Name = 'Self Check'; Key = 'x'; Dir = ''; Profile = ''; LastVerdict = '' }
        $cnt = @{}
        foreach ($pn in 'Balanced', 'Performance', 'Extreme', 'Auto') {
            $g.Profile = $pn; $o = Apply-GameProfile $g
            $cnt[$pn] = @($script:levelKeys | Where-Object { $script:S[$_] }).Count
            foreach ($k in @($o.Keys)) { $script:S[$k] = $o[$k] }
        }
        $after = ($script:levelKeys | ForEach-Object { "$_=$([bool]$script:S[$_])" }) -join ','
        if ($before -ne $after) { return @{ R = 'FAIL'; I = 'settings were not restored after applying a profile' } }
        if (-not ($cnt['Balanced'] -lt $cnt['Performance'] -and $cnt['Performance'] -lt $cnt['Extreme'])) { return @{ R = 'FAIL'; I = 'profiles do not differ as expected' } }
        "Balanced $($cnt['Balanced']) tweaks, Performance $($cnt['Performance']), Extreme $($cnt['Extreme']), Auto $($cnt['Auto']); settings restored"
    }
    Chk 'Anti-cheat detection' { if ((Test-KnownAntiCheat 'VALORANT') -and -not (Test-KnownAntiCheat 'Stardew Valley')) { 'recognizes protected games' } else { $false } }
    Chk 'Power plan tools' { $o = (& powercfg /list) 2>&1 | Out-String; if ($o -match '[0-9a-fA-F-]{36}') { 'powercfg works' } else { $false } }
    Chk 'PresentMon (real FPS)' { $pm = Find-PresentMon; if ($pm) { "found, command style $(Get-PresentMonStyle $pm): $pm" } else { @{ R = 'SKIP'; I = 'not installed - press Download PresentMon on this page' } } }
    Chk 'Left-over boost from a crash' { if (Test-Path (Join-Path $script:dataDir 'session.json')) { @{ R = 'WARN'; I = 'a session file exists - bluFPS restores it on the next start' } } else { 'none' } }
    Chk 'Security setting: Defender exclusion' { if ($script:S.Excl) { @{ R = 'WARN'; I = 'ON (your choice) - lowers protection for the game folder while playing' } } else { 'off (default, never part of a profile)' } }
    $np = @($rows | Where-Object { $_ -like 'PASS*' }).Count; $nf = @($rows | Where-Object { $_ -like 'FAIL*' }).Count; $ns = @($rows | Where-Object { $_ -like 'SKIP*' }).Count; $nw = @($rows | Where-Object { $_ -like 'WARN*' }).Count
    [void]$rows.Add(''); [void]$rows.Add("Result: $np passed, $nf failed, $nw warnings, $ns skipped.  Press Copy results and send it if anything failed.")
    $c.selfText.Text = ($rows -join "`n")
    $c.btnSelfCheck.IsEnabled = $true
}
$c.btnSelfCheck.Add_Click({ Guard 'Self-check' { try { Run-SelfCheck } finally { $c.btnSelfCheck.IsEnabled = $true } } })
$c.btnSelfCopy.Add_Click({ Guard 'Copy results' { if ($c.selfText.Text) { [Windows.Clipboard]::SetText($c.selfText.Text); Log 'Self-check results copied.' } } })

# ---------- version text and releasing updates from inside the app ----------
function Format-Ver($v) {
    $p = "$v".Split('.')
    if ($p.Count -lt 3) { return "v$v" }
    $s = "v$($p[0]).$($p[1]).$($p[2])"
    if ($p.Count -ge 4 -and [int]$p[3] -gt 0) { $s += " (build $($p[3]))" }
    return $s
}
$script:pubPath = Join-Path $script:dataDir 'publish.json'
$script:devFlag = Join-Path $script:dataDir 'developer.flag'
function Read-PubAll {
    $all = @{ Active = 'Testing'; Targets = @{} }
    try {
        if (Test-Path $script:pubPath) {
            $j = Get-Content $script:pubPath -Raw | ConvertFrom-Json
            if ($j.Targets) {
                foreach ($p in $j.Targets.PSObject.Properties) { if ($p.Value.User -and $p.Value.Repo -and $p.Value.Token) { $all.Targets[$p.Name] = $p.Value } }
                if ($j.Active) { $all.Active = "$($j.Active)" }
            } elseif ($j.User -and $j.Repo -and $j.Token) { $all.Targets['Testing'] = $j }
        }
    } catch {}
    if (-not $all.Targets.ContainsKey($all.Active) -and $all.Targets.Count) { $all.Active = @($all.Targets.Keys)[0] }
    return $all
}
function Save-PubAll($all) {
    New-Item $script:dataDir -ItemType Directory -Force | Out-Null
    $o = [pscustomobject]@{ Active = $all.Active; Targets = $all.Targets }
    [IO.File]::WriteAllText($script:pubPath, (ConvertTo-Json -InputObject $o -Depth 5), (New-Object Text.UTF8Encoding $false))
}
function Get-PubCfg { $all = Read-PubAll; if ($all.Targets.ContainsKey($all.Active)) { return $all.Targets[$all.Active] }; return $null }
function Update-PubStatus {
    $all = Read-PubAll
    $show = ((Test-Path $script:pubPath) -or (Test-Path $script:devFlag))
    $c.pubCard.Visibility = $(if ($show) { 'Visible' } else { 'Collapsed' })
    $lines = @()
    foreach ($n in 'Testing', 'Customers') {
        $tg = $all.Targets[$n]; $mark = ''; if ($n -eq $all.Active) { $mark = '   <-- publishing here' }
        if ($tg) { $lines += "${n}: github.com/$($tg.User)/$($tg.Repo)$mark" } else { $lines += "${n}: not set up" }
    }
    $lines += 'Installers built after the Customers destination exists check the Customers repository for updates.'
    $c.pubStatus.Text = ($lines -join "`n")
    if ($all.Targets.ContainsKey($all.Active)) { $c.btnPubTarget.Content = "Publish to: $($all.Active)" } else { $c.btnPubTarget.Content = 'Publish to: (not set up)' }
}
function Show-PubSetup {
    $all = Read-PubAll
    $w = New-Object Windows.Window
    $w.Title = 'Set up publishing'; $w.Width = 480; $w.SizeToContent = 'Height'; $w.ResizeMode = 'NoResize'; $w.WindowStartupLocation = 'CenterOwner'; $w.Owner = $win; $w.Background = '#0B1226'
    $sp = New-Object Windows.Controls.StackPanel -Property @{ Margin = '20' }
    function Add-Lbl($txt) { [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $txt; Foreground = '#8FA0C9'; FontSize = 12; Margin = '0,10,0,3'; TextWrapping = 'Wrap' })) }
    Add-Lbl 'Which destination are you setting up?'
    $rt = New-Object Windows.Controls.RadioButton -Property @{ Content = 'Testing - your own repo while you build and try versions'; Foreground = 'White'; Margin = '0,2,0,2'; GroupName = 'tgt' }
    $rc = New-Object Windows.Controls.RadioButton -Property @{ Content = 'Customers - the repo your customers download updates from'; Foreground = 'White'; Margin = '0,2,0,2'; GroupName = 'tgt' }
    [void]$sp.Children.Add($rt); [void]$sp.Children.Add($rc)
    if ($all.Active -eq 'Customers') { $rc.IsChecked = $true } else { $rt.IsChecked = $true }
    Add-Lbl 'GitHub username (use a different account for customers if you like)'
    $tu = New-Object Windows.Controls.TextBox -Property @{ Padding = '8,6'; Background = '#16224A'; Foreground = 'White'; BorderBrush = '#2A3A6B' }; [void]$sp.Children.Add($tu)
    Add-Lbl 'Repository name (created for you if it does not exist yet)'
    $tr = New-Object Windows.Controls.TextBox -Property @{ Padding = '8,6'; Background = '#16224A'; Foreground = 'White'; BorderBrush = '#2A3A6B'; Text = 'bluFPS' }; [void]$sp.Children.Add($tr)
    Add-Lbl 'GitHub token for that account: github.com/settings/tokens (classic, tick public_repo). Stored encrypted for your Windows account only.'
    $tp = New-Object Windows.Controls.PasswordBox -Property @{ Padding = '8,6'; Background = '#16224A'; Foreground = 'White'; BorderBrush = '#2A3A6B' }; [void]$sp.Children.Add($tp)
    $btn = New-Object Windows.Controls.Button -Property @{ Content = 'Save'; Padding = '16,7'; Margin = '0,16,0,0'; HorizontalAlignment = 'Right' }; [void]$sp.Children.Add($btn)
    $cm = New-Object Windows.Controls.CheckBox -Property @{ Content = 'Also keep the repository main branch up to date (program files, README, update.json)'; Foreground = 'White'; IsChecked = $true; Margin = '0,12,0,0' }; [void]$sp.Children.Add($cm)
    $script:pubDlg = @{ W = $w; U = $tu; R = $tr; P = $tp; RC = $rc; CM = $cm }
    $rc.Add_Checked({ if ($script:pubDlg.R.Text -eq 'bluFPS') { $script:pubDlg.R.Text = 'bluFPS-releases' } })
    $rt.Add_Checked({ if ($script:pubDlg.R.Text -eq 'bluFPS-releases') { $script:pubDlg.R.Text = 'bluFPS' } })
    $btn.Add_Click({
        $d = $script:pubDlg
        if (-not $d.U.Text.Trim() -or -not $d.R.Text.Trim() -or -not $d.P.Password) { [void][Windows.MessageBox]::Show('Please fill in all three boxes.', 'Set up publishing'); return }
        $d.W.DialogResult = $true
    })
    $w.Content = $sp
    if ($w.ShowDialog() -eq $true) {
        $d = $script:pubDlg
        $name = 'Testing'; if ($d.RC.IsChecked) { $name = 'Customers' }
        $sec = ConvertTo-SecureString $d.P.Password -AsPlainText -Force
        $all.Targets[$name] = @{ User = $d.U.Text.Trim(); Repo = ($d.R.Text.Trim() -replace '[^\w.-]', ''); Token = (ConvertFrom-SecureString $sec); PushMain = [bool]$d.CM.IsChecked }
        $all.Active = $name
        Save-PubAll $all
        Update-PubStatus
    }
}
function Push-Main($api, $user, $repo, $h, $files, $message) {
    $info = Invoke-RestMethod "$api/repos/$user/$repo" -Headers $h
    $branch = "$($info.default_branch)"; if (-not $branch) { $branch = 'main' }
    $ref = $null
    try { $ref = Invoke-RestMethod "$api/repos/$user/$repo/git/ref/heads/$branch" -Headers $h } catch {}
    if (-not $ref) {
        $first = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("# bluFPS`n"))
        $null = Invoke-RestMethod "$api/repos/$user/$repo/contents/README.md" -Method Put -Headers $h -ContentType 'application/json' -Body (@{ message = 'Initial commit'; content = $first } | ConvertTo-Json)
        Start-Sleep -Seconds 1
        $info = Invoke-RestMethod "$api/repos/$user/$repo" -Headers $h; $branch = "$($info.default_branch)"
        $ref = Invoke-RestMethod "$api/repos/$user/$repo/git/ref/heads/$branch" -Headers $h
    }
    $parent = "$($ref.object.sha)"
    $pc = Invoke-RestMethod "$api/repos/$user/$repo/git/commits/$parent" -Headers $h
    $tree = @()
    foreach ($k in @($files.Keys)) {
        $blob = Invoke-RestMethod "$api/repos/$user/$repo/git/blobs" -Method Post -Headers $h -ContentType 'application/json' -Body (@{ content = [Convert]::ToBase64String($files[$k]); encoding = 'base64' } | ConvertTo-Json)
        $tree += @{ path = $k; mode = '100644'; type = 'blob'; sha = "$($blob.sha)" }
    }
    $nt = Invoke-RestMethod "$api/repos/$user/$repo/git/trees" -Method Post -Headers $h -ContentType 'application/json' -Body (@{ base_tree = "$($pc.tree.sha)"; tree = $tree } | ConvertTo-Json -Depth 5)
    $nc = Invoke-RestMethod "$api/repos/$user/$repo/git/commits" -Method Post -Headers $h -ContentType 'application/json' -Body (@{ message = $message; tree = "$($nt.sha)"; parents = @($parent) } | ConvertTo-Json -Depth 5)
    $null = Invoke-RestMethod "$api/repos/$user/$repo/git/refs/heads/$branch" -Method Patch -Headers $h -ContentType 'application/json' -Body (@{ sha = "$($nc.sha)" } | ConvertTo-Json)
    return $branch
}
function Get-ParseErrors($text) {
    $tk = $null; $er = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tk, [ref]$er)
    return @($er | Select-Object -First 5 | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" })
}
function Publish-UpdateZip($zip) {
    $cfg = Get-PubCfg
    if (-not $cfg) { throw 'Publishing is not set up yet. Press Set up publishing first.' }
    $tname = (Read-PubAll).Active
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $za = [IO.Compression.ZipFile]::OpenRead($zip)
    $files = @{}; $txt = ''
    try {
        foreach ($en in $za.Entries) {
            if (-not $en.Name -or $en.Name -match '\.exe$') { continue }
            $ms = New-Object IO.MemoryStream; $st = $en.Open(); $st.CopyTo($ms); $st.Dispose()
            $key = ($en.FullName -replace '\\', '/')
            $files[$key] = $ms.ToArray(); $ms.Dispose()
            if ($en.Name -eq 'bluFPS.ps1') { $txt = [Text.Encoding]::UTF8.GetString($files[$key]) }
        }
    } finally { $za.Dispose() }
    if (-not $txt) { throw 'That zip is not a bluFPS update (there is no bluFPS.ps1 inside).' }
    $pe = Get-ParseErrors $txt
    if ($pe.Count) { throw "This update has a script error and was NOT published, so no customer gets a broken version. $($pe -join ' | ')" }
    $ver = [regex]::Match($txt, "AppVersion = '([\d.]+)'").Groups[1].Value
    if (-not $ver) { throw 'Could not read the version inside that zip.' }
    $api = 'https://api.github.com'; $user = $cfg.User; $repo = $cfg.Repo
    if ($tname -eq 'Customers') {
        $ans = [Windows.MessageBox]::Show("You are publishing $(Format-Ver $ver) to CUSTOMERS (github.com/$user/$repo). Every customer copy will offer this update. Continue?", 'Publish to customers', 'YesNo', 'Warning')
        if ($ans -ne 'Yes') { $c.pubStatus.Text = 'Cancelled - nothing was published.'; return }
    }
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $cfg.Token)))
    $h = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'bluFPS-publish' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $c.pubStatus.Text = "Publishing $(Format-Ver $ver) to $tname..."; Pump
    try { $null = Invoke-RestMethod "$api/repos/$user/$repo" -Headers $h }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            $body = @{ name = $repo; description = 'bluFPS releases (auto-update)'; private = $false; auto_init = $true } | ConvertTo-Json
            $null = Invoke-RestMethod "$api/user/repos" -Method Post -Headers $h -ContentType 'application/json' -Body $body
            Start-Sleep -Seconds 2
        } else { throw }
    }
    $tag = "v$ver"; $rel = $null
    try { $rel = Invoke-RestMethod "$api/repos/$user/$repo/releases/tags/$tag" -Headers $h } catch {}
    # release notes = the newest section of CHANGELOG.txt when the zip carries one
    $notes = "bluFPS $(Format-Ver $ver)"
    if ($files.ContainsKey('CHANGELOG.txt')) {
        $take = $false; $buf = @()
        foreach ($line in ([Text.Encoding]::UTF8.GetString($files['CHANGELOG.txt']) -split "`r?`n")) {
            if ($line -match '^v\d') { if ($take) { break } else { $take = $true; continue } }
            if ($take) { $buf += $line }
        }
        if ($buf.Count) { $notes = ($buf -join "`n").Trim() }
    }
    if (-not $rel) {
        $body = @{ tag_name = $tag; name = "bluFPS $tag"; body = $notes; draft = $false; prerelease = $false } | ConvertTo-Json
        $rel = Invoke-RestMethod "$api/repos/$user/$repo/releases" -Method Post -Headers $h -ContentType 'application/json' -Body $body
    } else {
        $null = Invoke-RestMethod "$api/repos/$user/$repo/releases/$($rel.id)" -Method Patch -Headers $h -ContentType 'application/json' -Body (@{ body = $notes } | ConvertTo-Json)
    }
    $name = "bluFPS-v$ver-update.zip"
    foreach ($a in @($rel.assets)) { if ($a.name -eq $name) { $null = Invoke-RestMethod "$api/repos/$user/$repo/releases/assets/$($a.id)" -Method Delete -Headers $h } }
    $c.pubStatus.Text = "Uploading $name..."; Pump
    $null = Invoke-RestMethod ("https://uploads.github.com/repos/$user/$repo/releases/$($rel.id)/assets?name=" + [uri]::EscapeDataString($name)) -Method Post -Headers $h -ContentType 'application/zip' -InFile $zip
    if (-not "$($script:S.Source)") { $script:S.Source = "$user/$repo"; Save-Settings; $c.updSrc.Text = $script:S.Source }
    # keep the repository's main branch up to date too (program files, README, update.json) - one commit
    $mainMsg = 'The main branch was left alone (switched off for this destination).'
    if ($cfg.PushMain -ne $false) {
        try {
            $c.pubStatus.Text = 'Updating the main branch...'; Pump
            $sha = (Get-FileHash $zip -Algorithm SHA256).Hash
            $dl = "https://github.com/$user/$repo/releases/download/$tag/$name"
            $files['update.json'] = [Text.Encoding]::UTF8.GetBytes((@{ version = $ver; url = $dl; sha256 = $sha; notes = $notes } | ConvertTo-Json))
            $files['README.md'] = [Text.Encoding]::UTF8.GetBytes("# bluFPS`n`nLatest version: **$(Format-Ver $ver)**`n`nbluFPS updates itself: open bluFPS > Updates. Release page: https://github.com/$user/$repo/releases/tag/$tag`n`n## What is new`n`n$notes`n")
            $br = Push-Main $api $user $repo $h $files "bluFPS $tag"
            $mainMsg = "The main branch ($br) was updated too."
        } catch { $mainMsg = "The release is published, but updating the main branch failed: $($_.Exception.Message)" }
    }
    Log "Published $(Format-Ver $ver) to $tname ($user/$repo)."
    Update-PubStatus
    $c.pubStatus.Text = "Published $(Format-Ver $ver) to $tname.`n$mainMsg`n" + $c.pubStatus.Text
}
function Publish-Installed {
    $files = @('bluFPS.ps1', 'bluFPS.vbs', 'bluFPS.ico', 'bluFPS.png', 'Uninstall.ps1', 'bluFPS.exe' | ForEach-Object { Join-Path $script:AppRoot $_ } | Where-Object { Test-Path $_ })
    if (-not ($files | Where-Object { $_ -like '*bluFPS.ps1' })) { throw 'Could not find the installed program files.' }
    $zip = Join-Path $env:TEMP "bluFPS-v$($script:AppVersion)-update.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path $files -DestinationPath $zip
    try { Publish-UpdateZip $zip } finally { Remove-Item $zip -ErrorAction SilentlyContinue }
}
$c.btnPubSetup.Add_Click({ Guard 'Set up publishing' { Show-PubSetup } })
$c.btnPubTarget.Add_Click({ Guard 'Publish destination' {
    $all = Read-PubAll
    $have = @('Testing', 'Customers' | Where-Object { $all.Targets.ContainsKey($_) })
    if ($have.Count -lt 2) { $c.pubStatus.Text = 'Only one destination is set up. Press Set up publishing and choose the other one (Testing or Customers) to add it.'; return }
    $all.Active = $(if ($all.Active -eq 'Testing') { 'Customers' } else { 'Testing' })
    Save-PubAll $all; Update-PubStatus
} })
$c.updCur.Add_MouseLeftButtonDown({ if (([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0) { New-Item $script:devFlag -ItemType File -Force | Out-Null; Update-PubStatus } })
$c.btnPubFile.Add_Click({ Guard 'Publish update' {
    $d = New-Object Microsoft.Win32.OpenFileDialog -Property @{ Filter = 'bluFPS update (*.zip)|*.zip'; Title = 'Select the update .zip' }
    if ($d.ShowDialog() -eq $true) { try { Publish-UpdateZip $d.FileName } catch { $c.pubStatus.Text = "Publishing failed: $($_.Exception.Message)" } }
} })
$c.btnPubThis.Add_Click({ Guard 'Publish update' { try { Publish-Installed } catch { $c.pubStatus.Text = "Publishing failed: $($_.Exception.Message)" } } })

# ---------- build Boost list ----------
foreach ($t in $tweaks) {
    $sp = New-Object Windows.Controls.StackPanel
    [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.Name; FontSize = 14 }))
    [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.Desc; FontSize = 12; Foreground = '#6C7CA3' }))
    $cb = New-Object Windows.Controls.CheckBox -Property @{ Content = $sp; IsChecked = $t.On; Tag = $t; Foreground = '#FFFFFF'; Margin = '0,0,0,14' }
    [void]$c.tweakPanel.Children.Add($cb)
}

# ---------- events ----------
$c.navDash.Add_Click({ Show-Page 'Dash' }); $c.navBoost.Add_Click({ Show-Page 'Boost' })
$c.navNet.Add_Click({ Show-Page 'Net' });   $c.navApps.Add_Click({ Show-Page 'Apps' })
$c.btnMin.Add_Click({ $win.WindowState = 'Minimized' }); $c.btnX.Add_Click({ $win.Close() })
$win.Add_MouseLeftButtonDown({ if ($args[1].GetPosition($win).Y -lt 40) { try { $win.DragMove() } catch {} } })

$c.btnBoost.Add_Click({ if ($backup.Count -gt 0) { Undo-All } else { Apply-Tweaks ($tweaks | Where-Object { $_.On }) } })
$c.btnApply.Add_Click({ Apply-Tweaks @($c.tweakPanel.Children | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag }) })
$c.btnRevert.Add_Click({ Undo-All })

$c.btnPing.Add_Click({
    $c.pingOut.Text = ''; Log 'Running ping test...'
    foreach ($s in @(@('Cloudflare', '1.1.1.1'), @('Google', '8.8.8.8'), @('Quad9', '9.9.9.9'))) {
        $t = @(Ping-Host $s[1])
        if ($t.Count) {
            $m = $t | Measure-Object -Average -Minimum -Maximum
            $c.pingOut.AppendText(('{0,-11} avg {1,4:N0} ms   min {2,3}   max {3,3}   lost {4}/5' -f $s[0], $m.Average, $m.Minimum, $m.Maximum, (5 - $t.Count)) + "`r`n")
        } else { $c.pingOut.AppendText(('{0,-11} no reply' -f $s[0]) + "`r`n") }
    }
    Log 'Ping test finished.'
})
$c.btnFlush.Add_Click({ [void](Invoke-Native 'ipconfig' '/flushdns'); Log 'DNS cache flushed.' })
$c.dnsCf.Add_Click({ try { Set-Dns @('1.1.1.1', '1.0.0.1'); Log 'DNS set to Cloudflare.' } catch { Log "DNS change failed: $($_.Exception.Message)" } })
$c.dnsGg.Add_Click({ try { Set-Dns @('8.8.8.8', '8.8.4.4'); Log 'DNS set to Google.' } catch { Log "DNS change failed: $($_.Exception.Message)" } })
$c.dnsAuto.Add_Click({ try { Set-Dns $null; Log 'DNS set back to automatic.' } catch { Log "DNS change failed: $($_.Exception.Message)" } })

$c.btnRefresh.Add_Click({ Load-Apps })
$c.btnKill.Add_Click({
    foreach ($cb in @($c.appPanel.Children | Where-Object { $_.IsChecked })) { [void]$cb.Tag.CloseMainWindow(); Log "Asked to close $($cb.Tag.ProcessName)" }
})
$c.btnPrio.Add_Click({
    foreach ($cb in @($c.appPanel.Children | Where-Object { $_.IsChecked })) {
        try { $cb.Tag.PriorityClass = 'High'; Log "High priority set for $($cb.Tag.ProcessName)" } catch { Log "Could not change $($cb.Tag.ProcessName)" }
    }
})


# ---------- game-server ping + regions ----------
$script:goBrush = $c.btnBoost.Background

function Get-GameName {
    if ($script:gameExe) { [IO.Path]::GetFileNameWithoutExtension($script:gameExe) } elseif ($script:watchName) { $script:watchName }
}

function Find-GameServer($name) {
    $ids = @(Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    if (-not $ids.Count) { return }
    $priv = '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|169\.254\.|0\.|::|fe80|fc|fd)'
    $ips = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Where-Object { $ids -contains $_.OwningProcess -and $_.RemoteAddress -notmatch $priv } |
        Select-Object -ExpandProperty RemoteAddress -Unique | Select-Object -First 6)
    foreach ($ip in $ips) {
        try { $r = $script:pinger.Send($ip, 600) } catch { continue }
        if ($r.Status -eq 'Success') { $script:srvIp = $ip; return }
    }
}

function Draw-Spark {
    $w = $c.spark.ActualWidth; if ($w -lt 10) { $w = 180 }
    $h = 34; $v = $script:hist
    if ($v.Count -lt 2) { return }
    $max = [math]::Max(100, ($v | Measure-Object -Maximum).Maximum)
    $pts = New-Object Windows.Media.PointCollection
    for ($i = 0; $i -lt $v.Count; $i++) {
        $x = $w * $i / 29; $y = $h - 2 - ($v[$i] / $max * ($h - 4))
        $pts.Add((New-Object Windows.Point -ArgumentList $x, $y))
    }
    $c.sparkLine.Points = $pts
}

function Update-Ping {
    $name = Get-GameName
    if ($script:srvName -ne $name) { $script:srvIp = $null; $script:srvName = $name; $script:srvFail = 0 }
    $script:pTick++
    if (-not $script:srvIp -and $name -and ($script:pTick % 3 -eq 1)) { Find-GameServer $name }
    $ms = $null; $isServer = $false; $src = ''
    if ($script:srvIp) {
        try { $r = $script:pinger.Send($script:srvIp, 500) } catch { $r = $null }
        if ($r -and $r.Status -eq 'Success') { $ms = [int]$r.RoundtripTime; $isServer = $true; $src = "$name server  -  $($script:srvIp)" }
        else { $script:srvFail++; if ($script:srvFail -ge 3) { $script:srvIp = $null; $script:srvFail = 0 } }
    }
    if ($null -eq $ms) {
        $src = if ($name) { "waiting for $name to connect - showing internet ping" } else { 'boost a game in the Games tab for server ping' }
        try { $r = $script:pinger.Send('1.1.1.1', 400); if ($r.Status -eq 'Success') { $ms = [int]$r.RoundtripTime } } catch {}
    }
    $c.pingSrc.Text = $src
    if ($null -eq $ms) { $c.valPing.Text = 'timeout'; $c.valPing.Foreground = '#FF6B6B'; $c.pingNote.Text = 'no reply'; return }
    $c.valPing.Text = "$ms ms"
    $col, $q = if ($ms -lt 50) { '#3DDC97', 'excellent' } elseif ($ms -lt 100) { '#F5C542', 'okay' } else { '#FF6B6B', 'high' }
    $c.valPing.Foreground = $col; $c.pingNote.Text = $q
    $c.gameNet.Text = if ($isServer) { "Live server ping: $ms ms  ($($script:srvIp))" } else { 'Live server ping: start the game and it appears here (some games hide their server)' }
    $script:hist.Add([double]$ms); if ($script:hist.Count -gt 30) { $script:hist.RemoveAt(0) }
    Draw-Spark
}

function Test-Tcp($ip, $port = 443, $timeout = 1200) {
    $cl = New-Object Net.Sockets.TcpClient
    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $ar = $cl.BeginConnect($ip, $port, $null, $null)
        if ($ar.AsyncWaitHandle.WaitOne($timeout, $false) -and $cl.Connected) { return [int]$sw.ElapsedMilliseconds }
    } catch {} finally { $cl.Close() }
    return $null
}

$regions = @(
    @('US East (N. Virginia)', 'ec2.us-east-1.amazonaws.com'), @('US West (Oregon)', 'ec2.us-west-2.amazonaws.com'),
    @('Europe (Frankfurt)', 'ec2.eu-central-1.amazonaws.com'), @('Europe (London)', 'ec2.eu-west-2.amazonaws.com'),
    @('Asia (Tokyo)', 'ec2.ap-northeast-1.amazonaws.com'), @('Asia (Singapore)', 'ec2.ap-southeast-1.amazonaws.com'),
    @('Asia (Mumbai)', 'ec2.ap-south-1.amazonaws.com'), @('Oceania (Sydney)', 'ec2.ap-southeast-2.amazonaws.com'),
    @('South America (Sao Paulo)', 'ec2.sa-east-1.amazonaws.com'))

$c.btnRegions.Add_Click({
    $c.pingOut.Text = ''; Log 'Testing game server regions...'
    $rows = foreach ($r in $regions) {
        $ip = try { [Net.Dns]::GetHostAddresses($r[1]) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1 } catch { $null }
        $t = @()
        if ($ip) { 1..3 | ForEach-Object { $x = Test-Tcp $ip 443 1200; if ($null -ne $x) { $t += $x }; Pump } }
        $ms = if ($t.Count) { @($t | Sort-Object)[[int][math]::Floor($t.Count / 2)] } else { 9999 }
        [pscustomobject]@{ Name = $r[0]; Ms = $ms }
    }
    $first = $true
    foreach ($row in ($rows | Sort-Object Ms)) {
        if ($row.Ms -ge 9999) { $line = '{0,-27} unreachable' -f $row.Name }
        else { $line = '{0,-27} {1,4} ms  {2}' -f $row.Name, $row.Ms, ('=' * [math]::Max(1, [int](36 - $row.Ms / 8))) }
        if ($first -and $row.Ms -lt 9999) { $line += '  <- closest'; $first = $false }
        $c.pingOut.AppendText($line + "`r`n")
    }
    Log 'Region test finished. Choose the closest region in your game settings.'
})

# ---------- auto-update ----------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$script:cfgPath = Join-Path $env:APPDATA 'bluFPS\update.json'
$script:updRel = $null; $script:chkAsync = $null; $script:chkPs = $null; $script:chkManual = $false

function Test-RepoSource($src) {
    foreach ($p in ("$src" -split ';')) {
        $t = $p.Trim() -replace '^https://github\.com/', ''
        if ($t -match '^[\w.-]+/[\w.-]+$') { return $true }
    }
    return $false
}
$script:bannerMode = 'update'
function Show-SetupHint {
    $script:bannerMode = 'setup'
    $c.updBannerText.Text = 'Online updates are not connected in this build yet. Once the new version is published (PUBLISH.bat), every install finds updates by itself.'
    $c.btnBannerUpd.Content = 'Set up'
    $c.updBanner.Visibility = 'Visible'
}
function Get-UpdateCfg {
    $cfg = @{ Source = ''; AutoCheck = $true; SkipVersion = '' }
    $def = Join-Path $script:AppRoot 'update-source.txt'
    if (Test-Path $def) {
        $l = Get-Content $def | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } | Select-Object -First 1
        if ($l) { $cfg.Source = $l.Trim() }
    }
    if (Test-Path $script:cfgPath) {
        try {
            $j = Get-Content $script:cfgPath -Raw | ConvertFrom-Json
            foreach ($k in 'Source', 'AutoCheck', 'SkipVersion') { if (($j.PSObject.Properties.Name -contains $k) -and -not ($k -eq 'Source' -and (-not "$($j.Source)" -or ($cfg.Source -and -not (Test-RepoSource (Normalize-Source $j.Source)))))) { $cfg[$k] = $j.$k } }
        } catch {}
    }
    # a saved address that is not a repo or https link (for example a file path) is dropped instead of warning forever
    if ($cfg.Source -and -not (Test-RepoSource (Normalize-Source $cfg.Source))) { $cfg.Source = '' }
    $cfg
}

function Save-UpdateCfg {
    New-Item (Split-Path $script:cfgPath) -ItemType Directory -Force | Out-Null
    @{ Source = (Normalize-Source $c.updSrc.Text); AutoCheck = [bool]$c.chkAutoCheck.IsChecked; SkipVersion = "$($script:skipVer)" } | ConvertTo-Json | Set-Content $script:cfgPath
}

function Get-ZipAppVersion {
    param($path)
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $z = [IO.Compression.ZipFile]::OpenRead($path)
        try {
            $en = $z.Entries | Where-Object { $_.FullName -match '(^|/)bluFPS\.ps1$' } | Select-Object -First 1
            if (-not $en) { return $null }
            $sr = New-Object IO.StreamReader($en.Open())
            $txt = $sr.ReadToEnd(); $sr.Close()
            $m = [regex]::Match($txt, "AppVersion = '([\d.]+)'")
            if ($m.Success) { return $m.Groups[1].Value }
        } finally { $z.Dispose() }
    } catch {}
    return $null
}

# runs in a background runspace so the window never freezes
function Get-LatestRelease {
    param($srcList)
    function One {
        param($src)
        $h = @{ 'User-Agent' = 'bluFPS-updater' }
        $src = "$src".Trim().Trim('"')
        if ($src -match '^https://github\.com/([\w.-]+)/([\w.-]+?)(\.git)?(/.*)?$') { $src = "$($Matches[1])/$($Matches[2])" }
        if ($src -match '^[\w.-]+/[\w.-]+$') {
            $r = Invoke-RestMethod "https://api.github.com/repos/$src/releases/latest" -Headers $h -TimeoutSec 10
            $asset = $r.assets | Where-Object { $_.name -like '*-update.zip' } | Select-Object -First 1
            if (-not $asset) { $asset = $r.assets | Where-Object { $_.name -like '*.zip' -and $_.name -notlike '*-Mac.zip' } | Select-Object -First 1 }
            if (-not $asset) { throw 'The latest release has no .zip file attached.' }
            $sha = $null; if ("$($asset.digest)" -like 'sha256:*') { $sha = "$($asset.digest)".Substring(7) }
            return [pscustomobject]@{ Version = ("$($r.tag_name)" -replace '^[vV]', ''); Url = $asset.browser_download_url; Sha256 = $sha; Notes = $r.body }
        }
        if ($src -notmatch '^https://') { throw 'The update source must be your GitHub repo (owner/name) or an https link to update.json.' }
        $m = Invoke-RestMethod $src -Headers $h -TimeoutSec 10
        if ($m -is [string]) { $m = $m | ConvertFrom-Json }
        return [pscustomobject]@{ Version = ("$($m.version)" -replace '^[vV]', ''); Url = $m.url; Sha256 = $m.sha256; Notes = $m.notes }
    }
    $best = $null; $err = $null
    foreach ($one in ("$srcList" -split ';')) {
        $one = $one.Trim()
        if (-not $one) { continue }
        try { $r = One $one } catch { if (-not $err) { $err = $_ }; continue }
        if (-not $r -or -not $r.Version) { continue }
        try { $v = [version]$r.Version } catch { continue }
        if (-not $best -or $v -gt [version]$best.Version) { $best = $r }
    }
    if ($best) { return $best }
    if ($err) { throw $err }
    throw 'No update source is set.'
}

function Set-UpdText($m, $kind = 'info') {
    $c.updMsg.Text = $m
    $c.updMsg.Foreground = switch ($kind) { 'ok' { '#3DDC97' } 'warn' { '#F5C542' } 'err' { '#FF6B6B' } default { '#9FB0D0' } }
}

function Normalize-Source($s) {
    $out = @()
    foreach ($one in ("$s" -split ';')) {
        $o = $one.Trim().Trim('"', "'")
        if (-not $o) { continue }
        if ($o -notmatch '\.json(\?|$)') {
            if ($o -match '^(?:https?://)?(?:www\.)?github\.com/([\w.-]+)/([\w.-]+?)(?:\.git)?(?:[/?#].*)?$') { $o = "$($Matches[1])/$($Matches[2])" }
            elseif ($o -match '^git@github\.com:([\w.-]+)/([\w.-]+?)(?:\.git)?$') { $o = "$($Matches[1])/$($Matches[2])" }
        }
        $out += $o
    }
    return ($out -join ';')
}
function Start-UpdateCheck($manual) {
    if ($script:chkAsync) { return }
    $src = Normalize-Source $c.updSrc.Text
    if ($src -ne $c.updSrc.Text.Trim()) { $c.updSrc.Text = $src }
    if (-not $src) {
        if ($manual) { Set-UpdText 'No update source set yet. Enter your GitHub repo (owner/name) below, then press Save and check.' 'warn' }
        return
    }
    if ($manual) { Set-UpdText 'Checking for updates...' }
    $fn = ${function:Get-LatestRelease}.ToString(); $fz = ${function:Get-ZipAppVersion}.ToString()
    $script:chkPs = [powershell]::Create()
    [void]$script:chkPs.AddScript("param(`$s)`n`$ErrorActionPreference = 'Stop'`nfunction Get-ZipAppVersion {`n$fz`n}`nfunction Get-LatestRelease {`n$fn`n}`nGet-LatestRelease `$s").AddArgument($src)
    $script:chkManual = $manual
    $script:chkAsync = $script:chkPs.BeginInvoke()
    $script:updTimer.Start()
}

function Poll-Update {
    if (-not $script:chkAsync -or -not $script:chkAsync.IsCompleted) { return }
    $script:updTimer.Stop()
    $ps = $script:chkPs; $ar = $script:chkAsync; $manual = $script:chkManual
    $script:chkAsync = $null; $script:chkPs = $null
    try {
        $rel = @($ps.EndInvoke($ar)) | Select-Object -First 1
        if (-not $rel -or -not $rel.Version) { throw 'The update source did not return a version.' }
        $new = [version]$rel.Version; $cur = [version]$script:AppVersion
        if ($new -gt $cur) {
            $script:updRel = $rel
            if ($manual -and "$($script:skipVer)" -eq "$new") { $script:skipVer = ''; Save-UpdateCfg }
            $skipped = ("$($script:skipVer)" -eq "$new")
            Set-UpdText "Update available: $(Format-Ver $new)  (you have $(Format-Ver $cur))" 'ok'
            $c.updNotes.Text = "$($rel.Notes)"; $c.updNotes.Visibility = if ($rel.Notes) { 'Visible' } else { 'Collapsed' }
            $c.btnUpdInstall.Visibility = 'Visible'
            if (-not $skipped) {
                $script:bannerMode = 'update'; $c.btnBannerUpd.Content = 'Update...'; $c.updBannerText.Text = "bluFPS $(Format-Ver $new) is available (you have $(Format-Ver $cur))"; $c.updBanner.Visibility = 'Visible'
                Log "Update available: $(Format-Ver $new)"
                if ($manual -or $script:promptedFor -ne "$new") {
                    $script:promptedFor = "$new"
                    Show-UpdateOverlay $rel $cur
                }
            }
        } else {
            $script:updRel = $null
            $c.btnUpdInstall.Visibility = 'Collapsed'; $c.updBanner.Visibility = 'Collapsed'; $c.updNotes.Visibility = 'Collapsed'
            Set-UpdText "You are up to date ($(Format-Ver $cur)). Checked at $((Get-Date).ToString('t'))." 'ok'
        }
    } catch {
        $m = "$($_.Exception.Message)"
        if ($_.Exception.InnerException) { $m = "$($_.Exception.InnerException.Message)" }
        if ($m -match '404') {
            $m = 'No published release was found. On GitHub, publish a release (not a draft) and attach the update zip. Private repositories are not supported.'
            try {
                $one = ("$(Normalize-Source $c.updSrc.Text)" -split ';')[0]
                if ($one -match '^[\w.-]+/[\w.-]+$') {
                    $rp = $null
                    try { $rp = Invoke-RestMethod "https://api.github.com/repos/$one" -Headers @{ 'User-Agent' = 'bluFPS' } -TimeoutSec 8 } catch {}
                    if ($rp) { $m = "The repository $one is public but has no published release yet. Publish one: Releasing updates below > Publish an update file... (or create a release on GitHub and attach the update zip)." }
                    else { $m = "GitHub cannot see $one without signing in, so it is private or the name is wrong. bluFPS checks for updates without a login, so the repository must be PUBLIC (GitHub > repository Settings > Change visibility)." }
                }
            } catch {}
        }
        elseif ($m -match '403') { $m = 'GitHub refused the request (rate limit). Try again in a few minutes.' }
        elseif ($m -match 'remote name|could not be resolved|unable to connect|timed out|timeout') { $m = 'Could not reach the update source. Check your internet connection.' }
        if ($m -match 'update source must be' -and $c.updSrc.Text -match '^[A-Za-z]:\\|^\\\\|\.zip\s*$') { Set-UpdText 'That is a file on your PC. Online updates only work with a GitHub repo (owner/name). To install a new zip, just run its bluFPS-Setup.exe - it updates in place. Clear this box or enter your repo.' 'warn' }
        elseif ($m -match 'update source must be') { Set-UpdText "That update source does not look right. Type your GitHub repo as owner/name (for example mycompany/bluFPS) or paste the repo link, then press Save and check." 'warn' }
        else { Set-UpdText "Could not check for updates: $m" 'err' }
    }
    finally { $ps.Dispose() }
}

function Install-Update($rel) {
    if (-not $rel) { return }
    try {
        $url = "$($rel.Url)"
        $isLocal = ($url -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://')
        if ($url -notmatch '^https://') { throw 'The update download must use https.' }
        $tmp = Join-Path $env:TEMP ('bluFPS-update-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item $tmp -ItemType Directory -Force | Out-Null
        $zip = Join-Path $tmp 'update.zip'
        Set-UpdText "Downloading $(Format-Ver $rel.Version)..."; Log "Downloading update $(Format-Ver $rel.Version)..."
        $ProgressPreference = 'SilentlyContinue'
        if ($isLocal) {
            if (-not (Test-Path -LiteralPath $url)) { throw "Update file not found: $url" }
            Copy-Item -LiteralPath $url $zip -Force
        } else {
            Invoke-WebRequest $url -OutFile $zip -UseBasicParsing -Headers @{ 'User-Agent' = 'bluFPS-updater' } -TimeoutSec 120
        }
        if ($rel.Sha256) {
            if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne "$($rel.Sha256)".Trim().ToUpper()) { throw 'The download failed its SHA-256 check, so the update was cancelled.' }
        }
        Expand-Archive $zip -DestinationPath (Join-Path $tmp 'x') -Force
        $pkg = Get-ChildItem (Join-Path $tmp 'x') -Recurse -Filter 'bluFPS.ps1' | Select-Object -First 1
        if (-not $pkg) { throw 'The update package does not contain bluFPS.ps1.' }
        $pv = [regex]::Match((Get-Content -LiteralPath $pkg.FullName -Raw), "AppVersion = '([\d.]+)'").Groups[1].Value
        if ($pv -and ([version]$pv) -le ([version]$script:AppVersion)) { throw "That package is $(Format-Ver $pv), which is not newer than the version you have ($(Format-Ver $script:AppVersion))." }
        $pe = Get-ParseErrors (Get-Content -LiteralPath $pkg.FullName -Raw)
        if ($pe.Count) { throw "The downloaded update has a script error and was NOT installed. Your current version is untouched. $($pe[0])" }
        $apply = @'
param($ProcId, $Src, $Dest, $Ver, $Tmp)
try {
    try { Wait-Process -Id $ProcId -Timeout 30 -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Milliseconds 500
    Get-ChildItem $Src -File | Where-Object { $_.Name -notmatch '^(Setup\..*|README\.txt|CHANGELOG\.txt|UPDATING\.txt|update-source\.txt)$' } | ForEach-Object { Copy-Item $_.FullName $Dest -Force }
    Get-ChildItem $Dest | Unblock-File -ErrorAction SilentlyContinue
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\bluFPS'
    if (Test-Path $k) { Set-ItemProperty $k -Name DisplayVersion -Value $Ver }
} catch { Set-Content (Join-Path $env:TEMP 'bluFPS-update-error.txt') ($_ | Out-String) }
$exe = Join-Path $Dest 'bluFPS.exe'
if (Test-Path $exe) { Start-Process $exe } else { Start-Process "$env:WINDIR\System32\wscript.exe" -ArgumentList "`"$Dest\bluFPS.vbs`"" }
Start-Process cmd.exe -WindowStyle Hidden -ArgumentList "/c ping 127.0.0.1 -n 5 >nul & rmdir /s /q `"$Tmp`""
'@
        Set-Content (Join-Path $tmp 'apply.ps1') $apply
        Set-UpdText 'Installing... bluFPS will restart in a moment.' 'ok'; Log 'Installing update and restarting...'
        Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp\apply.ps1`" -ProcId $PID -Src `"$($pkg.DirectoryName)`" -Dest `"$script:AppRoot`" -Ver $($rel.Version) -Tmp `"$tmp`""
        $win.Close()
    } catch { Set-UpdText "Update failed: $($_.Exception.Message)" 'err'; Log "Update failed: $($_.Exception.Message)" }
}

function Show-UpdateOverlay($rel, $cur) {
    if (-not $rel) { return }
    $script:ovRel = $rel
    $c.ovVer.Text = "bluFPS $(Format-Ver $rel.Version)  (you have $(Format-Ver $cur))"
    if ($rel.Notes) { $c.ovNotes.Text = "$($rel.Notes)"; $c.ovNotes.Visibility = 'Visible' } else { $c.ovNotes.Visibility = 'Collapsed' }
    $c.updOverlay.Visibility = 'Visible'
}
$c.ovNow.Add_Click({ $c.updOverlay.Visibility = 'Collapsed'; Install-Update $script:ovRel })
$c.ovLater.Add_Click({ $c.updOverlay.Visibility = 'Collapsed' })
$c.ovSkip.Add_Click({
    $script:skipVer = "$($script:ovRel.Version)"; Save-UpdateCfg
    $c.updOverlay.Visibility = 'Collapsed'; $c.updBanner.Visibility = 'Collapsed'
    Set-UpdText "v$($script:skipVer) skipped. You can still update from this page." 'warn'
})

$script:updTimer = New-Object Windows.Threading.DispatcherTimer
$script:updTimer.Interval = [TimeSpan]::FromMilliseconds(400)
$script:updTimer.Add_Tick({ Poll-Update })
$script:updEvery = New-Object Windows.Threading.DispatcherTimer
$script:updEvery.Interval = [TimeSpan]::FromHours(6)
$script:updEvery.Add_Tick({ if ($c.chkAutoCheck.IsChecked) { Start-UpdateCheck $false } })
$script:updEvery.Start()

$u = Get-UpdateCfg
$c.updSrc.Text = $u.Source; $c.chkAutoCheck.IsChecked = [bool]$u.AutoCheck; $script:skipVer = "$($u.SkipVersion)"; $script:promptedFor = ''
if (-not $u.Source) { Set-UpdText 'No update source yet. Enter your GitHub repo below to get online updates.' 'warn' }
$c.navUpd.Add_Click({ Show-Page 'Upd' })
$c.btnUpdCheck.Add_Click({ Start-UpdateCheck $true })
$c.btnUpdInstall.Add_Click({ Show-UpdateOverlay $script:updRel ([version]$script:AppVersion) })
$c.btnBannerUpd.Add_Click({ if ($script:bannerMode -eq 'setup') { Show-Page 'Upd'; [void]$c.updSrc.Focus() } else { Show-UpdateOverlay $script:updRel ([version]$script:AppVersion) } })
$c.btnUpdSave.Add_Click({ Save-UpdateCfg; Start-UpdateCheck $true })
$c.chkAutoCheck.Add_Click({ Save-UpdateCfg })

# ---------- live stats ----------
try { $script:cpuC = New-Object Diagnostics.PerformanceCounter -ArgumentList 'Processor', '% Processor Time', '_Total'; [void]$script:cpuC.NextValue() } catch {}
try {
    $cpuN = ("$((Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction Stop).ProcessorNameString)" -replace '\s+', ' ').Trim()
    $gpus = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11cd-b325-00805fc4d3f9}' -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^\d{4}$' } |
        ForEach-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DriverDesc } |
        Where-Object { $_ -and $_ -notmatch 'Basic|Remote|Virtual|Mirror' })
    $gpuN = $gpus | Where-Object { $_ -match 'NVIDIA|GeForce|Radeon|AMD|Arc' } | Select-Object -First 1
    if (-not $gpuN) { $gpuN = $gpus | Select-Object -First 1 }
    $ramG = 0
    try { $ramG = [math]::Round((New-Object Microsoft.VisualBasic.Devices.ComputerInfo).TotalPhysicalMemory / 1GB) } catch {}
    $c.sysInfo.Text = "$cpuN   |   $gpuN   |   $ramG GB RAM"
} catch { $c.sysInfo.Text = 'System info unavailable' }

$script:tick = 0; $script:pTick = 0; $script:srvIp = $null; $script:srvName = $null; $script:srvFail = 0
$script:hist = New-Object Collections.Generic.List[double]
$script:pinger = New-Object Net.NetworkInformation.Ping
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({
    try { $cpu = [int]$script:cpuC.NextValue() } catch { $cpu = [int](Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average }
    $c.valCpu.Text = "$cpu%"; $c.barCpu.Value = $cpu
    if ($script:ci) { $ram = [int](100 - 100 * $script:ci.AvailablePhysicalMemory / $script:ci.TotalPhysicalMemory) }
    else { $o = Get-CimInstance Win32_OperatingSystem; $ram = [int](100 - 100 * $o.FreePhysicalMemory / $o.TotalVisibleMemorySize) }
    $c.valRam.Text = "$ram%"; $c.barRam.Value = $ram
    $script:tick++
    if ($script:tick % 2 -eq 1) { try { Update-Ping } catch {} }
    try { Update-Session } catch {}
})

$script:AppVersion = '1.1.9.5'
$c.verText.Text = "$(Format-Ver $script:AppVersion)"
$win.Title = "bluFPS $(Format-Ver $script:AppVersion)"
$c.updCur.Text = "$(Format-Ver $script:AppVersion)"
$logoPath = Join-Path $script:AppRoot 'bluFPS.png'
if (Test-Path $logoPath) {
    try {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit(); $bmp.UriSource = New-Object Uri $logoPath; $bmp.CacheOption = 'OnLoad'; $bmp.EndInit()
        $c.logoImg.Source = $bmp; $c.ovLogo.Source = $bmp; $win.Icon = $bmp
    } catch {}
}
$c.verText.Add_MouseLeftButtonUp({
    [Windows.MessageBox]::Show("bluFPS $(Format-Ver $script:AppVersion)`n`nWhat is new in this update:`n- More powerful boost: efficiency mode + low disk/memory priority for other apps, ProBalance (stops CPU hogs mid-game), standby-memory cleaning`n- Boost levels: Light, Balanced, Maximum`n- GPU priority for the game, game-scheduler tweaks, optional Defender exclusion for the game folder; anti-cheat apps are never touched`n- Faster boost: the game launches almost immediately", 'bluFPS - what is new', 'OK', 'Information') | Out-Null
})

Set-Splash 'Scanning your games...'
Load-SettingsUi; Load-Library; Load-Games; Show-GameDetail
Recover-Session; Clean-OldPlans
Set-Splash 'Almost ready...'
Show-Page 'Dash'; Update-Boost
$timer.Start()
if ($c.chkAutoCheck.IsChecked) { Start-UpdateCheck $false }
if (-not (Test-RepoSource $c.updSrc.Text)) { Show-SetupHint }
Start-GameScan 'auto'
Load-HwCache; if (-not $script:hw) { Start-HwCache }
try { $bundled = Join-Path $script:AppRoot 'update-source.txt'; if ((Test-Path $bundled) -and (Get-Content $bundled | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') })) { $c.updSrcLbl.Visibility = 'Collapsed'; $c.updSrcRow.Visibility = 'Collapsed' } } catch {}
# safety net: an unexpected error is written to crash.log instead of closing the app
$win.Dispatcher.Add_UnhandledException({ param($s, $e)
    try { $e.Handled = $true; $dir = Join-Path $env:APPDATA 'bluFPS'; New-Item $dir -ItemType Directory -Force | Out-Null; Add-Content (Join-Path $dir 'crash.log') ("[{0}] {1}`n{2}`n" -f (Get-Date), $e.Exception.Message, $e.Exception.StackTrace); Log "Something went wrong: $($e.Exception.Message) (details in crash.log in the data folder)" } catch {}
})
$win.Add_Closing({ try { if ($script:cap) { Stop-FpsMonitor }; if ($script:bench) { Cancel-Bench $null } } catch {} })
Start-ArtRefresh $false; $script:artEvery.Start()
$win.Add_Closing({ try { End-Boost } catch {} })
if ($env:BLUFPS_ARGS -match '/minimized') { $win.WindowState = 'Minimized' }
Finish-Splash
$c.rootBorder.Opacity = 0
Start-Anim $c.rootBorder ([Windows.UIElement]::OpacityProperty) 0 1 600 150
[void]$win.ShowDialog()
