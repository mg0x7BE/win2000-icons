param([switch]$Restore, [switch]$Machine, [switch]$UserOnly)

$ErrorActionPreference = 'Stop'
$sourceDir = Join-Path $PSScriptRoot 'icons'
$iconDir = Join-Path $env:ProgramData 'win2000-icons'
$explorerKey = 'Software\Microsoft\Windows\CurrentVersion\Explorer'
$themesKey = 'Software\Microsoft\Windows\CurrentVersion\Themes'
$computer = '{20D04FE0-3AEA-1069-A2D8-08002B30309D}'
$recycleBin = '{645FF040-5081-101B-9F08-00AA002F954E}'

# Global shell icons (HKLM, needs admin). Key = shell32 icon index used by Windows.
$shellIcons = [ordered]@{
    0  = 'unknown-file'
    1  = 'document'
    2  = 'application'
    3  = 'folder'
    4  = 'folder-open'
    5  = 'floppy-525'
    6  = 'floppy'
    7  = 'removable-drive'
    8  = 'hard-drive'
    9  = 'network-drive'
    10 = 'network-drive-offline'
    11 = 'cd-drive'
    12 = 'ram-disk'
    13 = 'entire-network'
    15 = 'network-computer'
    16 = 'printer'
    17 = 'network-places'
    18 = 'workgroup'
    29 = 'shortcut-overlay'
    51 = 'network-share'
    58 = 'unknown-drive'
}

# Per-user overrides for special shell items.
$clsidIcons = [ordered]@{
    $computer                                = 'my-computer'
    '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}' = 'network-places'  # Network
    '{679f85cb-0220-4080-b29b-5540cc05aab6}' = 'favorites'       # Quick access
    '{f874310e-b6b7-47dc-bc84-b9e6b38f5903}' = 'favorites'       # Home (Windows 11)
    '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' = 'my-pictures'     # Gallery (Windows 11)
    '{26EE0668-A00A-44D7-9371-BEB064C98683}' = 'control-panel'
    '{21EC2020-3AEA-1069-A2DD-08002B30309D}' = 'control-panel'   # All Control Panel items
    '{2227A280-3AEA-1069-A2DE-08002B30309D}' = 'printers-folder'
    '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}' = 'desktop'
    '{d3162b92-9365-467a-956b-92703aca08af}' = 'my-documents'
    '{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}' = 'music'
    '{24ad3ad4-a569-4530-98e1-ab02f9417aa8}' = 'my-pictures'
    '{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}' = 'camcorder'
    '{088e3905-0323-4b02-9826-5d99428e115f}' = 'downloads'
    '{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}' = 'entire-network'  # 3D Objects, the globe
    # Older IDs of the same folders, used by the default Quick access pins.
    '{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}' = 'my-documents'
    '{1CF1260C-4DD0-4ebb-811F-33C572699FDE}' = 'music'
    '{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}' = 'my-pictures'
    '{A0953C92-50DC-43bf-BE83-3742FED03C9C}' = 'camcorder'
    '{374DE290-123F-4565-9164-39C4925E467B}' = 'downloads'
}

# Per-user file type icons. Key = ProgID.
$fileTypeIcons = [ordered]@{
    'CompressedFolder' = 'zip'  # .zip, icon from Windows Me
}

# Folder icons from desktop.ini, used when browsing C:\Users\<name>.
# Value = icon name, Windows default for restore.
$knownFolders = [ordered]@{
    'Desktop'     = 'desktop', '%SystemRoot%\system32\imageres.dll,-183'
    'Personal'    = 'my-documents', '%SystemRoot%\system32\imageres.dll,-112'
    'My Music'    = 'music', '%SystemRoot%\system32\imageres.dll,-108'
    'My Pictures' = 'my-pictures', '%SystemRoot%\system32\imageres.dll,-113'
    'My Video'    = 'camcorder', '%SystemRoot%\system32\imageres.dll,-189'
    'Downloads'   = 'downloads', '%SystemRoot%\system32\imageres.dll,-184'
    '3D Objects'  = 'entire-network', '%SystemRoot%\system32\imageres.dll,-198'
}

function Set-FolderIcon($folder, $iconResource) {
    $ini = Join-Path $folder 'desktop.ini'
    if (-not (Test-Path -LiteralPath $ini)) { return }
    $file = Get-Item -LiteralPath $ini -Force
    $attributes = $file.Attributes
    $bytes = [IO.File]::ReadAllBytes($ini)
    $encoding = if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { [Text.Encoding]::Unicode } else { [Text.Encoding]::Default }
    $text = [IO.File]::ReadAllText($ini, $encoding)
    $line = 'IconResource=' + $iconResource.Replace('$', '$$')
    if ($text -match '(?m)^IconResource=') { $text = $text -replace '(?m)^IconResource=[^\r\n]*', $line }
    else { $text = $text -replace '(?m)^\[\.ShellClassInfo\]', "[.ShellClassInfo]`r`n$line" }
    $file.Attributes = 'Normal'
    [IO.File]::WriteAllText($ini, $text, $encoding)
    $file.Attributes = $attributes
}

function Get-IconPath($name) {
    $path = Join-Path $iconDir "$name.ico"
    if (-not (Test-Path $path)) { throw "Missing icon: $path (run without -UserOnly first)" }
    "$path,0"
}

function Invoke-MachineStep {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Machine"
    if ($Restore) { $arguments += ' -Restore' }
    $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ArgumentList $arguments
    if ($p.ExitCode -ne 0) { throw "admin step failed with exit code $($p.ExitCode)" }
}

if ($Machine) {
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64')
    $key = $hklm.CreateSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons')
    if (-not $Restore) {
        New-Item -ItemType Directory -Path $iconDir -Force | Out-Null
        $source = Get-ChildItem $sourceDir -Filter *.ico
        Get-ChildItem $iconDir -Filter *.ico | Where-Object { $source.Name -notcontains $_.Name } | Remove-Item -Force
        $source | Copy-Item -Destination $iconDir -Force
    }
    # GetEnumerator, because an int index on an ordered dictionary means position, not key.
    foreach ($entry in $shellIcons.GetEnumerator()) {
        if ($Restore) { $key.DeleteValue([string]$entry.Key, $false) }
        else { $key.SetValue([string]$entry.Key, (Get-IconPath $entry.Value), 'String') }
    }
    if ($Restore -and (Test-Path $iconDir)) { Remove-Item $iconDir -Recurse -Force }
    exit 0
}

# Icons have to be installed before per-user settings can point at them.
if (-not $Restore -and -not $UserOnly) {
    try { Invoke-MachineStep }
    catch { Write-Error "Icons were not installed: $_" }
}

$hkcu = [Microsoft.Win32.Registry]::CurrentUser
if ($Restore) {
    foreach ($clsid in @($clsidIcons.Keys) + $recycleBin) {
        $hkcu.DeleteSubKeyTree("$explorerKey\CLSID\$clsid\DefaultIcon", $false)
    }
    foreach ($progId in $fileTypeIcons.Keys) {
        $hkcu.DeleteSubKeyTree("Software\Classes\$progId\DefaultIcon", $false)
        $key = $hkcu.OpenSubKey("Software\Classes\$progId")
        if ($key -and $key.SubKeyCount -eq 0 -and $key.ValueCount -eq 0) {
            $key.Close()
            $hkcu.DeleteSubKey("Software\Classes\$progId")
        }
    }
    $hkcu.CreateSubKey($themesKey).SetValue('ThemeChangesDesktopIcons', 1, 'DWord')
    $hkcu.CreateSubKey("$explorerKey\Advanced").SetValue('IconsOnly', 0, 'DWord')
} else {
    foreach ($clsid in $clsidIcons.Keys) {
        $hkcu.CreateSubKey("$explorerKey\CLSID\$clsid\DefaultIcon").SetValue('', (Get-IconPath $clsidIcons[$clsid]), 'String')
    }
    foreach ($entry in $fileTypeIcons.GetEnumerator()) {
        $hkcu.CreateSubKey("Software\Classes\$($entry.Key)\DefaultIcon").SetValue('', (Get-IconPath $entry.Value), 'String')
    }
    $empty = Get-IconPath 'recycle-bin-empty'
    $full = Get-IconPath 'recycle-bin-full'
    $binHasItems = (New-Object -ComObject Shell.Application).Namespace(10).Items().Count -gt 0
    $key = $hkcu.CreateSubKey("$explorerKey\CLSID\$recycleBin\DefaultIcon")
    $key.SetValue('empty', $empty, 'ExpandString')
    $key.SetValue('full', $full, 'ExpandString')
    $key.SetValue('', $(if ($binHasItems) { $full } else { $empty }), 'ExpandString')

    # Show This PC on the desktop and stop themes from resetting the icons.
    foreach ($panel in 'NewStartPanel', 'ClassicStartMenu') {
        $hkcu.CreateSubKey("$explorerKey\HideDesktopIcons\$panel").SetValue($computer, 0, 'DWord')
    }
    $hkcu.CreateSubKey($themesKey).SetValue('ThemeChangesDesktopIcons', 0, 'DWord')

    # No thumbnails, like Win2000. Windows can't turn off folder content previews alone.
    $hkcu.CreateSubKey("$explorerKey\Advanced").SetValue('IconsOnly', 1, 'DWord')
}

$shell = New-Object -ComObject Shell.Application
foreach ($entry in $knownFolders.GetEnumerator()) {
    $folder = $shell.Namespace("shell:$($entry.Key)")
    if (-not $folder) { continue }
    $icon = if ($Restore) { $entry.Value[1] } else { Get-IconPath $entry.Value[0] }
    Set-FolderIcon $folder.Self.Path $icon
}

# File Explorer on the taskbar and in Start menu. Edited via Shell.Application,
# because WScript.Shell would drop the shell item target of this shortcut.
$programs = [Environment]::GetFolderPath('Programs')
foreach ($linkDir in (Join-Path $programs 'System Tools'), $programs) {
    if (-not (Test-Path -LiteralPath (Join-Path $linkDir 'File Explorer.lnk'))) { continue }
    $link = $shell.Namespace($linkDir).ParseName('File Explorer.lnk').GetLink
    if ($Restore) { $link.SetIconLocation('%windir%\explorer.exe', 0) }
    else {
        $iconFile = (Get-IconPath 'file-explorer') -replace ',0$'
        $link.SetIconLocation($iconFile, 0)
    }
    $link.Save()
}

$failed = $false
if ($Restore -and -not $UserOnly) {
    try { Invoke-MachineStep }
    catch {
        Write-Warning "Folder, drive and file icons were not restored: $_"
        $failed = $true
    }
}

& "$env:SystemRoot\System32\ie4uinit.exe" -show
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }

if ($failed) { exit 1 }
