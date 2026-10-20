param(
  [string]$Scenario = 'all',
  [string]$NewMsiUrl = '',
  [string]$NewMsiDir = '',
  [string]$OldMsiUrl = '',
  [string]$Work = 'C:\msitest'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'wingui.psm1')

$Evidence = Join-Path $Work 'evidence'
$Logs = Join-Path $Evidence 'logs'
Initialize-Evidence $Evidence
New-Item -ItemType Directory -Force $Logs | Out-Null

$Desktop = [Environment]::GetFolderPath('Desktop')
if (-not $Desktop -or -not $Desktop.EndsWith('\Desktop')) { throw "Unexpected Desktop path '$Desktop'" }
$ProgramFilesDir = Join-Path $env:ProgramFiles 'SimpleX'
$Setup = 'SimpleX Setup'
$UserFiles = @('My notes.txt', 'Tax return 2025.txt', 'Holiday photos\beach.txt')
$SeededNames = @('My notes.txt', 'Tax return 2025.txt', 'Holiday photos')
$InstalledNames = @('SimpleX.exe', 'app', 'runtime')

function Write-Check([string]$Name, $Value) {
  Write-Host "CHECK $Name = $Value"
  Add-Content (Join-Path $Evidence 'checks.txt') "$Name = $Value"
}

function Invoke-Com($Object, [string]$Method, [object[]]$Arguments) {
  $Object.GetType().InvokeMember($Method, [Reflection.BindingFlags]::InvokeMethod, $null, $Object, $Arguments)
}

function Read-MsiColumn([string]$Msi, [string]$Sql) {
  $installer = New-Object -ComObject WindowsInstaller.Installer
  $db = Invoke-Com $installer 'OpenDatabase' @($Msi, 0)
  $view = Invoke-Com $db 'OpenView' @($Sql)
  Invoke-Com $view 'Execute' @() | Out-Null
  $values = @()
  while ($record = Invoke-Com $view 'Fetch' @()) {
    $values += $record.GetType().InvokeMember('StringData', [Reflection.BindingFlags]::GetProperty, $null, $record, @(1))
  }
  Invoke-Com $view 'Close' @() | Out-Null
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($view) | Out-Null
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($db) | Out-Null
  $values
}

function Get-Msi([string]$Url, [string]$Dir, [string]$Name) {
  if ($Dir) {
    $file = Get-ChildItem $Dir -Recurse -Filter *.msi | Select-Object -First 1
    if (-not $file) { throw "No .msi in $Dir" }
    $path = Join-Path $Work "$Name.msi"
    Copy-Item $file.FullName $path
    return $path
  }
  $path = Join-Path $Work "$Name.msi"
  Invoke-WebRequest $Url -OutFile $path
  $path
}

function Describe-Msi([string]$Msi, [string]$Name) {
  $version = Read-MsiColumn $Msi 'SELECT `Value` FROM `Property` WHERE `Property`=''ProductVersion'''
  $code = Read-MsiColumn $Msi 'SELECT `Value` FROM `Property` WHERE `Property`=''ProductCode'''
  $rows = try { @(Read-MsiColumn $Msi 'SELECT `WixRemoveFolderEx` FROM `WixRemoveFolderEx`').Count } catch { 'table absent' }
  Write-Check "$Name MSI version" $version
  Write-Check "$Name MSI WixRemoveFolderEx rows" $rows
  Write-Check "$Name MSI sha256" (Get-FileHash $Msi -Algorithm SHA256).Hash
  $code
}

function Test-UserFiles([string]$Label) {
  foreach ($file in $UserFiles) {
    Write-Check "$Label - Desktop\$file exists" (Test-Path (Join-Path $Desktop $file))
  }
}

function Reset-State {
  foreach ($code in $script:ProductCodes) {
    Start-Process msiexec.exe -ArgumentList @('/x', $code, '/qn') -Wait
  }
  foreach ($name in $SeededNames + $InstalledNames) {
    $path = Join-Path $Desktop $name
    if (Test-Path $path) { Remove-Item -Recurse -Force $path }
  }
}

function Add-UserFiles {
  Set-Content (Join-Path $Desktop 'My notes.txt') 'Personal notes that must survive uninstalling SimpleX.'
  Set-Content (Join-Path $Desktop 'Tax return 2025.txt') 'A document unrelated to SimpleX.'
  New-Item -ItemType Directory -Force (Join-Path $Desktop 'Holiday photos') | Out-Null
  Set-Content (Join-Path $Desktop 'Holiday photos\beach.txt') 'A file in a user folder.'
}

function Install-WithUi([string]$Msi, [string]$Folder, [string]$Tag, [string]$What) {
  $log = Join-Path $Logs "$Tag-install.log"
  $process = Start-Process msiexec.exe -ArgumentList @('/i', "`"$Msi`"", '/l*v', "`"$log`"") -PassThru
  Invoke-Element (Wait-Button $Setup @('Next') 180)
  Wait-Button $Setup @('Change...') | Out-Null
  if ($Folder) {
    Set-EditText $Setup $Folder | Out-Null
    Start-Sleep -Milliseconds 500
    Save-Screenshot "$What - Desktop folder typed as the install folder"
  } else {
    Save-Screenshot "$What - default install folder"
  }
  $next = Wait-Button $Setup @('Next')
  $next.SetFocus()
  Start-Sleep -Milliseconds 300
  Invoke-Element $next
  $button = Wait-Button $Setup @('Yes', 'Install')
  if ($button.Current.Name -eq 'Yes') {
    Save-Screenshot "$What - installer warns the folder already exists"
    Invoke-Element $button
    $button = Wait-Button $Setup @('Install')
  }
  Invoke-Element $button
  $finish = Wait-Button $Setup @('Finish') 900
  Save-Screenshot "$What - installer finished"
  Invoke-Element $finish
  $process.WaitForExit()
  Write-Check "$Tag install exit code" $process.ExitCode
  $installDir = Select-String -Path $log -Pattern 'Property\(S\): INSTALLDIR = (.*)' | Select-Object -Last 1
  Write-Check "$Tag INSTALLDIR" $(if ($installDir) { $installDir.Matches[0].Groups[1].Value } else { '<not in log>' })
}

function Uninstall-WithUi([string]$Msi, [string]$Tag, [string]$What) {
  $log = Join-Path $Logs "$Tag-uninstall.log"
  $process = Start-Process msiexec.exe -ArgumentList @('/x', "`"$Msi`"", '/l*v', "`"$log`"") -PassThru
  $yes = Wait-Button 'Windows Installer' @('Yes') 180
  Save-Screenshot "$What - uninstall confirmation"
  Invoke-Element $yes
  $process.WaitForExit()
  Write-Check "$Tag uninstall exit code" $process.ExitCode
}

function Test-UninstallDesktop {
  Reset-State
  Add-UserFiles
  Show-Folder $Desktop 'Desktop with the user''s own files, before installing SimpleX'
  Install-WithUi $script:NewMsi "$Desktop\" 'uninstall-desktop' 'Install into Desktop'
  Show-Folder $Desktop 'Desktop after installing SimpleX into it'
  Write-Check 'uninstall-desktop - SimpleX.exe installed in Desktop' (Test-Path (Join-Path $Desktop 'SimpleX.exe'))
  Uninstall-WithUi $script:NewMsi 'uninstall-desktop' 'Uninstall from Desktop'
  Show-Folder $Desktop 'Desktop after uninstalling SimpleX'
  Test-UserFiles 'uninstall-desktop after uninstall'
  foreach ($name in $InstalledNames) {
    Write-Check "uninstall-desktop after uninstall - Desktop\$name exists" (Test-Path (Join-Path $Desktop $name))
  }
}

function Test-UpdateDesktop {
  Reset-State
  Add-UserFiles
  Show-Folder $Desktop 'Desktop with the user''s own files, before installing the older SimpleX'
  Install-WithUi $script:OldMsi "$Desktop\" 'update-desktop-old' 'Install older version into Desktop'
  Show-Folder $Desktop 'Desktop after installing the older SimpleX into it'
  Install-WithUi $script:NewMsi '' 'update-desktop-new' 'Update to the newer version'
  Show-Folder $Desktop 'Desktop after updating SimpleX to the newer version'
  Test-UserFiles 'update-desktop after update'
  Write-Check 'update-desktop - newer SimpleX.exe in Program Files' (Test-Path (Join-Path $ProgramFilesDir 'SimpleX.exe'))
}

function Test-DefaultFolder {
  Reset-State
  Add-UserFiles
  Install-WithUi $script:NewMsi '' 'default-folder' 'Install into the default folder'
  Show-Folder $ProgramFilesDir 'Program Files SimpleX folder after installing'
  $app = Start-Process (Join-Path $ProgramFilesDir 'SimpleX.exe') -PassThru
  Start-Sleep -Seconds 45
  Save-Screenshot 'SimpleX started from the default install folder'
  Write-Check 'default-folder - app process running after 45 s' (-not $app.HasExited)
  if (-not $app.HasExited) { Stop-Process -Id $app.Id -Force }
  Get-Process -Name SimpleX -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 3
  Uninstall-WithUi $script:NewMsi 'default-folder' 'Uninstall from the default folder'
  Show-Folder $env:ProgramFiles 'Program Files after uninstalling SimpleX'
  Write-Check 'default-folder after uninstall - Program Files SimpleX folder exists' (Test-Path $ProgramFilesDir)
  Test-UserFiles 'default-folder after uninstall'
}

Write-Check 'session id' ([System.Diagnostics.Process]::GetCurrentProcess().SessionId)
Write-Check 'explorer running' ([bool](Get-Process explorer -ErrorAction SilentlyContinue))
Write-Check 'screen' ([System.Windows.Forms.SystemInformation]::VirtualScreen)
Write-Check 'EnableLUA' (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').EnableLUA
Write-Check 'Desktop' $Desktop
Save-Screenshot 'Runner screen at start'

$script:NewMsi = Get-Msi $NewMsiUrl $NewMsiDir 'new'
$script:OldMsi = Get-Msi $OldMsiUrl '' 'old'
$script:ProductCodes = @((Describe-Msi $script:NewMsi 'new'), (Describe-Msi $script:OldMsi 'old'))

$scenarios = [ordered]@{
  'uninstall-desktop' = { Test-UninstallDesktop }
  'update-desktop' = { Test-UpdateDesktop }
  'default-folder' = { Test-DefaultFolder }
}
$selected = if ($Scenario -eq 'all') { $scenarios.Keys } else { @($Scenario) }
$failed = @()
foreach ($name in $selected) {
  Write-Host "=== SCENARIO $name"
  try {
    & $scenarios[$name]
  } catch {
    Write-Host "SCENARIO $name ERROR: $($_.Exception.Message)"
    Write-Check "$name error" $_.Exception.Message
    $failed += $name
    Get-Process -Name msiexec -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  }
}
Reset-State
if ($failed) { throw "Scenarios with unexpected state: $($failed -join ', ')" }
