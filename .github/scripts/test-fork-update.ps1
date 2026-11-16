param(
    [Parameter(Mandatory)][string]$Archive,
    [Parameter(Mandatory)][ValidateSet('x86','x64','arm64')][string]$Architecture,
    [string]$WorkDir = $env:TEMP,
    [string]$HookProbe
)

$ErrorActionPreference = 'Stop'
$Archive = (Resolve-Path -LiteralPath $Archive).Path
. (Join-Path $PSScriptRoot '../../Release/ConEmu/Scripts/ForkUpdate.ps1') -Architecture $Architecture
$lab = Join-Path $WorkDir ('conemu-fork-update-test-' + [guid]::NewGuid().ToString('N'))
$root = Join-Path $lab 'installed'
$candidate = Join-Path $lab 'candidate'
# Unpack fixtures in a separate PowerShell so the installer must load ZIP support itself.
$setup = 'Expand-Archive -LiteralPath ''{0}'' -DestinationPath ''{1}'' -ErrorAction Stop; Copy-Item -LiteralPath ''{1}'' -Destination ''{2}'' -Recurse -ErrorAction Stop' -f
    $Archive.Replace("'", "''"), $root.Replace("'", "''"), $candidate.Replace("'", "''")
& (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -NoProfile -NonInteractive -Command $setup
if ($LASTEXITCODE) { throw 'Could not unpack the update fixtures' }
$guiPath = Join-Path $root $gui
$version = Get-PackageBuild $guiPath
$validHash = (Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $Archive).Hash

function Get-FileHash {
    throw 'Get-FileHash is intentionally unavailable to the installer in this test.'
}

# Give the fixture an older Windows file version by editing its VS_FIXEDFILEINFO.
$bytes = [IO.File]::ReadAllBytes($guiPath)
$fixedVersion = -1
$signature = [Convert]::ToUInt32('feef04bd', 16)
for ($i = 0; $i -lt $bytes.Length - 24; $i += 4) {
    if ([BitConverter]::ToUInt32($bytes, $i) -eq $signature -and
        [BitConverter]::ToUInt32($bytes, $i + 4) -eq 0x10000) {
        $fixedVersion = $i
        break
    }
}
if ($fixedVersion -lt 0) { throw 'Cannot find executable version resource' }
[BitConverter]::GetBytes([uint32]0x00160001).CopyTo($bytes, $fixedVersion + 8)
[BitConverter]::GetBytes([uint32]0x00010000).CopyTo($bytes, $fixedVersion + 12)
[IO.File]::WriteAllBytes($guiPath, $bytes)
if ((Get-PackageBuild $guiPath) -ne '220101') { throw 'Cannot construct old executable fixture' }
$sentinels = @('Far.exe', 'ConEmu/ConEmu.xml', 'Plugins/ConEmu/Background/Background.xml')
foreach ($file in $sentinels) {
    [IO.File]::WriteAllText((Join-Path $root $file), "User fixture for $file")
}

function Get-State([string]$Directory, [string[]]$Files) {
    ($Files | ForEach-Object { (Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath (Join-Path $Directory $_)).Hash }) -join ','
}

function Test-ExpectedFailure([scriptblock]$Operation, [string]$Pattern) {
    try { & $Operation }
    catch {
        if ($_ -notmatch $Pattern) { throw }
        return
    }
    throw "Expected failure: $Pattern"
}

foreach ($name in $updateFiles[0..1]) {
    Add-Content -LiteralPath (Join-Path $root $name) -Value 'Older fixture'
}
$initial = Get-State $root ($updateFiles + $sentinels)
$settings = Get-State $root $sentinels
Test-ExpectedFailure { Install-ForkUpdate $root $Archive ('0' * 64) $version } 'SHA-256'
if ((Get-State $root ($updateFiles + $sentinels)) -ne $initial) { throw 'Bad checksum changed files' }
'PASS invalid SHA-256 rejected before replacing files'

$lockedFile = [IO.File]::Open((Join-Path $root $updateFiles[2]), 'Open', 'Read', 'None')
try {
    Test-ExpectedFailure { Install-ForkUpdate $root $Archive $validHash $version } 'cannot access|being used|sharing'
} finally { $lockedFile.Dispose() }
if ((Get-State $root ($updateFiles + $sentinels)) -ne $initial) { throw 'Locked installation changed files' }
'PASS locked installation rejected before replacing files'

$replace = (Get-Item Function:Set-UpdateFile).ScriptBlock
$script:completedReplacements = 0
function Set-UpdateFile([string]$Source, [string]$Target, [string]$Backup) {
    if ($script:completedReplacements -eq 2) {
        $lock = [IO.File]::Open($Target, 'Open', 'Read', 'None')
        try { & $replace $Source $Target $Backup }
        finally { $lock.Dispose() }
    } else {
        & $replace $Source $Target $Backup
        $script:completedReplacements++
    }
}
Test-ExpectedFailure { Install-ForkUpdate $root $Archive $validHash $version } 'cannot access|being used|sharing'
Set-Item Function:Set-UpdateFile -Value $replace
if ($script:completedReplacements -ne 2 -or (Get-State $root ($updateFiles + $sentinels)) -ne $initial) {
    throw 'Rollback did not restore the installation'
}
'PASS two replacements rolled back after a mid-install sharing violation'

$work = Join-Path $root '.conemu-fork-update'
$previousGui = Join-Path $work "$($updateFiles.Count - 1).bak"
$copiedGui = Join-Path $work 'test-staged.exe'
[IO.File]::Copy((Join-Path $candidate $gui), $copiedGui)
[IO.File]::WriteAllText((Join-Path $work 'active'), $version)
[IO.File]::Replace($copiedGui, $guiPath, $previousGui)
Install-ForkUpdate -Root $root -RecoveryOnly
if ((Get-State $root ($updateFiles + $sentinels)) -ne $initial) { throw 'Interrupted update was not restored' }
'PASS interrupted transaction recovered on the next run'

Install-ForkUpdate $root $Archive $validHash $version
if ((Get-State $root $updateFiles) -ne (Get-State $candidate $updateFiles)) { throw 'Incomplete update' }
if ((Get-State $root $sentinels) -ne $settings) { throw 'Far or settings changed' }
"PASS installed $version and preserved Far and both profiles"

Test-ExpectedFailure { Install-ForkUpdate $root $Archive $validHash $version } 'not a newer'
'PASS same-version package rejected'
if ($HookProbe) {
    $config = Join-Path $lab 'hook.xml'
    $report = Join-Path $lab 'hook.report'
    '<key name="Software"><key name="ConEmu"><key name=".Vanilla"><value name="UseInjects" type="hex" data="01"/></key></key></key>' |
        Set-Content -LiteralPath $config -Encoding utf8
    $probe = (Resolve-Path -LiteralPath $HookProbe).Path
    $hookName = "ConEmuHk$bits.dll"
    $hookPath = Join-Path $root "ConEmu\$hookName"
    $arguments = "-ResetDefault -NoSingle -NoDefTerm -NoUpdate -NoCloseConfirm -LoadCfgFile `"$config`" -log -run `"$probe`" `"$report`""
    $console = Start-Process -FilePath $guiPath -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru
    try {
        for ($attempt = 0; $attempt -lt 80 -and !(Test-Path -LiteralPath $report); $attempt++) {
            Start-Sleep -Milliseconds 250
        }
        if (!(Test-Path -LiteralPath $report) -or [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($report)) -ine $hookPath) {
            throw "Expected classic hook did not load in the $Architecture process. Logs: $root"
        }
        "PASS $Architecture process loaded $hookName in a classic console after update"
    } finally {
        if (!$console.HasExited) {
            [void]$console.CloseMainWindow()
            if (!$console.WaitForExit(3000)) { Stop-Process -InputObject $console }
        }
    }
}
"Test fixture: $lab"
