<#
.SYNOPSIS
  Installs the ekode setup exe silently, then uninstalls it, and fails if the
  machine is not back where it started.

.DESCRIPTION
  Takes three snapshots -- before install, after install, after uninstall --
  of everything the installer is capable of touching:

    * the install directory tree (relative path + size + SHA256)
    * every value under HKCU\Environment, including its registry value KIND
      (a REG_SZ that comes back as REG_EXPAND_SZ is a leftover, not a no-op)
    * the Uninstall key names under HKCU and HKLM
    * Start Menu entries matching the app name
    * what where.exe resolves the CLI name to

  Snapshot 2 must show the additions. Snapshot 3 must equal snapshot 1.
  Any difference is printed as a diff and the script exits non-zero.

  Written for Windows PowerShell 5.1 so it runs unchanged on a dev box and on
  a GitHub windows runner.

.PARAMETER Setup
  Path to ekode-setup-*.exe.

.PARAMETER WorkDir
  Where to write the three snapshot JSON files and the installer logs.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Setup,
  [string]$WorkDir = (Join-Path $env:TEMP "ekode-uninstall-check"),
  [string]$AppName = "Ekode",
  [string]$ExeName = "ekode.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Setup)) { throw "Setup not found: $Setup" }
$Setup = (Resolve-Path -LiteralPath $Setup).Path
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# PrivilegesRequired=lowest + DefaultDirName={autopf} lands here.
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\$AppName"

function Get-DirSnapshot([string]$Root) {
  if (-not (Test-Path -LiteralPath $Root)) { return @() }
  Get-ChildItem -LiteralPath $Root -Recurse -File -Force | ForEach-Object {
    [pscustomobject]@{
      Path   = $_.FullName.Substring($Root.Length).TrimStart([char]0x5C)
      Length = $_.Length
      Sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
  } | Sort-Object Path
}

function Get-EnvSnapshot {
  # Registry, not [Environment]::GetEnvironmentVariable -- that expands
  # REG_EXPAND_SZ and hides the value kind, which is exactly what we check.
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment")
  if ($null -eq $key) { return @() }
  try {
    $key.GetValueNames() | Sort-Object | ForEach-Object {
      [pscustomobject]@{
        Name  = $_
        Kind  = $key.GetValueKind($_).ToString()
        Value = [string]$key.GetValue($_, "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
      }
    }
  } finally { $key.Close() }
}

function Get-UninstallKeys {
  $roots = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
  )
  $out = @()
  foreach ($r in $roots) {
    if (Test-Path -LiteralPath $r) {
      $out += Get-ChildItem -LiteralPath $r | ForEach-Object { "$r\$($_.PSChildName)" }
    }
  }
  $out | Sort-Object
}

function Get-StartMenu {
  $dirs = @(
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"),
    (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs")
  )
  $out = @()
  foreach ($d in $dirs) {
    if (Test-Path -LiteralPath $d) {
      $out += Get-ChildItem -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like "*$AppName*" } |
        ForEach-Object { $_.FullName }
    }
  }
  $out | Sort-Object
}

function Invoke-Native([scriptblock]$Command) {
  # Windows PowerShell 5.1 turns anything a native exe writes to stderr into a
  # NativeCommandError ErrorRecord, which is *terminating* while
  # $ErrorActionPreference is 'Stop'. where.exe writes "INFO: Could not find
  # files for the given pattern(s)." to stderr on a miss -- the normal baseline
  # state here, not a failure. Drop to Continue for the call and judge the
  # result by $LASTEXITCODE, which is what actually carries the outcome.
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & $Command } finally { $ErrorActionPreference = $prev }
}

function Get-WhereExe {
  $exe = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
  # redirect inside cmd so the stderr text never reaches PowerShell at all
  $r = Invoke-Native { & cmd.exe /c "where $exe 2>nul" }
  if ($LASTEXITCODE -ne 0) { return @() }
  @($r) | Sort-Object
}

function New-Snapshot([string]$Label) {
  $snap = [pscustomobject]@{
    Label     = $Label
    Files     = @(Get-DirSnapshot $InstallDir)
    Env       = @(Get-EnvSnapshot)
    Uninstall = @(Get-UninstallKeys)
    StartMenu = @(Get-StartMenu)
    Where     = @(Get-WhereExe)
  }
  $path = Join-Path $WorkDir "$Label.json"
  $snap | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding utf8
  Write-Host "[snapshot] $Label -> $path  (files=$($snap.Files.Count) env=$($snap.Env.Count) uninstall=$($snap.Uninstall.Count) startmenu=$($snap.StartMenu.Count) where=$($snap.Where.Count))"
  return $snap
}

function Compare-Lines($Before, $After, [string]$Name) {
  $diff = Compare-Object -ReferenceObject @($Before) -DifferenceObject @($After)
  if ($null -eq $diff) { return @() }
  $diff | ForEach-Object {
    if ($_.SideIndicator -eq "=>") { $sign = "+" } else { $sign = "-" }
    "$Name $sign $($_.InputObject)"
  }
}

function Compare-Snapshot($Before, $After) {
  $lines = @()
  # files carry their hash so a same-path different-content file still shows
  $bFiles = @($Before.Files | ForEach-Object { "$($_.Path)|$($_.Length)|$($_.Sha256)" })
  $aFiles = @($After.Files  | ForEach-Object { "$($_.Path)|$($_.Length)|$($_.Sha256)" })
  $lines += Compare-Lines $bFiles $aFiles "files"

  # env compared name|kind|value so a KIND flip with an identical string shows
  $bEnv = @($Before.Env | ForEach-Object { "$($_.Name)|$($_.Kind)|$($_.Value)" })
  $aEnv = @($After.Env  | ForEach-Object { "$($_.Name)|$($_.Kind)|$($_.Value)" })
  $lines += Compare-Lines $bEnv $aEnv "env"

  $lines += Compare-Lines $Before.Uninstall $After.Uninstall "uninstall"
  $lines += Compare-Lines $Before.StartMenu $After.StartMenu "startmenu"
  $lines += Compare-Lines $Before.Where     $After.Where     "where"

  @($lines | Where-Object { $_ } | Sort-Object -Unique)
}

function Wait-For([scriptblock]$Condition, [string]$What, [int]$TimeoutSec = 120) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if (& $Condition) { return }
    Start-Sleep -Milliseconds 500
  }
  throw "Timed out after $TimeoutSec s waiting for: $What"
}

# ---------------------------------------------------------------- 1. baseline
Write-Host "=== 1/3 baseline ==="
if (Test-Path -LiteralPath $InstallDir) {
  throw "$InstallDir already exists. Uninstall ekode first; this check needs a clean start."
}
$before = New-Snapshot "1-before"

# ----------------------------------------------------------------- 2. install
Write-Host "=== 2/3 silent install ==="
$installLog = Join-Path $WorkDir "install.log"
$p = Start-Process -FilePath $Setup -Wait -PassThru -ArgumentList @(
  "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", "/LOG=$installLog"
)
if ($p.ExitCode -ne 0) { throw "Installer exited $($p.ExitCode). Log: $installLog" }

$exePath = Join-Path $InstallDir "bin\$ExeName"
Wait-For { Test-Path -LiteralPath $exePath } "installed $ExeName" 60
$after = New-Snapshot "2-after-install"

$added = Compare-Snapshot $before $after
if ($added.Count -eq 0) { throw "Install changed nothing. The installer did not run." }
Write-Host "--- what the install added ---"
$added | ForEach-Object { Write-Host "  $_" }

# the install has to actually deliver the two things it exists for
$exeRow = $after.Files | Where-Object { $_.Path -eq "bin\$ExeName" }
if (-not $exeRow) { throw "Expected bin\$ExeName in the install dir, not found." }
$pathRow = $after.Env | Where-Object { $_.Name -eq "Path" }
if (-not $pathRow) { throw "HKCU\Environment\Path missing after install." }
if ($pathRow.Value -notlike "*$InstallDir\bin*") {
  throw "PATH does not contain $InstallDir\bin after install. Got: $($pathRow.Value)"
}
Write-Host "PATH entry present, $ExeName present."

Invoke-Native { & $exePath --version }
if ($LASTEXITCODE -ne 0) { throw "$exePath --version exited $LASTEXITCODE" }

# The registry entry is only half the claim. Prove a *new* shell resolves the
# bare command, the way a user's next terminal will. This process inherited its
# PATH before the install, so rebuild it from the registry the way Windows does
# for a freshly spawned process: machine PATH, then user PATH.
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$freshPath = ($machinePath, $userPath | Where-Object { $_ }) -join ";"
$bare = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
$probe = Start-Process -FilePath "cmd.exe" -Wait -PassThru -NoNewWindow `
  -ArgumentList "/c", "set `"PATH=$freshPath`" && $bare --version"
if ($probe.ExitCode -ne 0) {
  throw "A fresh shell could not run '$bare' off PATH (cmd exited $($probe.ExitCode)). The PATH registration did not take."
}
Write-Host "A fresh shell resolves '$bare' off PATH."

# --------------------------------------------------------------- 3. uninstall
Write-Host "=== 3/3 silent uninstall ==="
$uninst = Get-ChildItem -LiteralPath $InstallDir -Filter "unins*.exe" -File |
  Sort-Object Name | Select-Object -First 1
if (-not $uninst) { throw "No uninstaller found in $InstallDir" }

$uninstallLog = Join-Path $WorkDir "uninstall.log"
Start-Process -FilePath $uninst.FullName -Wait -ArgumentList @(
  "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/LOG=$uninstallLog"
) | Out-Null
# Inno's uninstaller re-launches itself from %TEMP% and the first process exits
# immediately, so -Wait alone is not enough. Wait for the directory to go.
Wait-For { -not (Test-Path -LiteralPath $InstallDir) } "install dir removed" 180

$post = New-Snapshot "3-after-uninstall"

$leftovers = Compare-Snapshot $before $post
if ($leftovers.Count -gt 0) {
  Write-Host ""
  Write-Host "UNCLEAN UNINSTALL -- $($leftovers.Count) difference(s) vs baseline:" -ForegroundColor Red
  $leftovers | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  Write-Host ""
  Write-Host "Snapshots in $WorkDir"
  exit 1
}

Write-Host ""
Write-Host "Clean uninstall: snapshot 3 is identical to snapshot 1." -ForegroundColor Green
Write-Host "Snapshots in $WorkDir"
exit 0
