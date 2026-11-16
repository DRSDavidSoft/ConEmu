param(
    [Parameter(Mandatory)][ValidateSet('x86','x64','arm64')][string]$Architecture,
    [ValidatePattern('^[0-9]{6}[a-z]?$')][string]$Version,
    [ValidateRange(0,2147483647)][int]$WaitForPid = 0,
    [switch]$Recover,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$feedUrl = 'https://raw.githubusercontent.com/Sim-md/ConEmu/update-feed/version.ini'
$bits = if ($Architecture -eq 'x86') { '' } else { '64' }
$pluginSuffix = @{x86='.dll'; x64='.x64.dll'; arm64='.arm64.dll'}[$Architecture]
$thumbBits = if ($bits) { '64' } else { '32' }
$machine = @{x86=0x014c; x64=0x8664; arm64=0xaa64}[$Architecture]
$gui = "ConEmu$bits.exe"
$otherGui = if ($bits) { 'ConEmu.exe' } else { 'ConEmu64.exe' }

# Keep both runtimes, including hooks for console processes of either bitness.
$machines = @{}
$runtimes = if ($Architecture -eq 'arm64') { @('64') } else { @('','64') }
$updateFiles = @(
    foreach ($runtime in $runtimes) {
        foreach ($name in "ConEmuC$runtime.exe","ConEmuCD$runtime.dll","ConEmuHk$runtime.dll") {
            $path = "ConEmu/$name"
            $machines[$path] = if ($Architecture -eq 'arm64') { 0xaa64 } elseif ($runtime) { 0x8664 } else { 0x014c }
            $path
        }
    }
    foreach ($name in "ConEmu$pluginSuffix","Background/ConEmuBg$pluginSuffix",
        "Lines/ConEmuLn$pluginSuffix","Thumbs/ConEmuTh$pluginSuffix","Thumbs/gdi+.t$thumbBits",
        "Thumbs/ico.t$thumbBits","Thumbs/pe.t$thumbBits") {
        $path = "Plugins/ConEmu/$name"
        $machines[$path] = $machine
        $path
    }
    'ConEmu/ConEmu.l10n'
    'ConEmu/Scripts/ForkUpdate.ps1'
    $gui
)
$machines[$gui] = $machine

function Assert-OrdinaryPath([string]$Path) {
    for ($item = $Path; $item; $item = [IO.Path]::GetDirectoryName($item)) {
        if (Test-Path -LiteralPath $item) {
            if (([IO.File]::GetAttributes($item) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "The updater does not follow reparse points: $item"
            }
        }
    }
}

function Assert-PeMachine([string]$Path, [int]$Machine) {
    $binary = [IO.File]::ReadAllBytes($Path)
    if ($binary.Length -lt 64 -or [BitConverter]::ToUInt16($binary, 0) -ne 0x5a4d) {
        throw "Invalid Windows executable: $Path"
    }
    $offset = [BitConverter]::ToInt32($binary, 60)
    if ($offset -lt 64 -or $offset -gt $binary.Length - 6 -or
        [BitConverter]::ToUInt32($binary, $offset) -ne 0x4550 -or
        [BitConverter]::ToUInt16($binary, $offset + 4) -ne $Machine) {
        throw "Unexpected executable architecture: $Path"
    }
}

function Get-PackageBuild([string]$Path) {
    $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
    if ($v.FilePrivatePart -lt 0 -or $v.FilePrivatePart -gt 26) {
        throw "Invalid build suffix: $Path"
    }
    $suffix = if ($v.FilePrivatePart) { [char]([int][char]'a' + $v.FilePrivatePart - 1) } else { '' }
    return ('{0:00}{1:00}{2:00}{3}' -f $v.FileMajorPart,$v.FileMinorPart,$v.FileBuildPart,$suffix)
}

function Wait-ForUpdateFile([string]$Target) {
    # Console helpers and scanners may still hold files briefly after the GUI exits.
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        try {
            $probe = [IO.File]::Open($Target, 'Open', 'ReadWrite', 'None')
            $probe.Dispose()
            return
        } catch [IO.IOException] {
            $code = $_.Exception.HResult -band 0xffff
            if ($code -notin 32,33 -or $timer.Elapsed.TotalSeconds -ge 15) { throw }
            Start-Sleep -Milliseconds 250
        }
    }
}

function Set-UpdateFile([string]$Source, [string]$Target, [string]$Backup) {
    [IO.File]::Replace($Source, $Target, $Backup)
}

function Undo-ForkUpdate([string]$Root, [string]$Work) {
    $active = Join-Path $Work 'active'
    if (![IO.File]::Exists($active)) { return }
    for ($i = $updateFiles.Count - 1; $i -ge 0; $i--) {
        $backup = Join-Path $Work "$i.bak"
        Assert-OrdinaryPath $backup
        if (![IO.File]::Exists($backup)) { continue }
        $target = Join-Path $Root $updateFiles[$i]
        Assert-OrdinaryPath $target
        $restore = Join-Path $Work "$i.restore"
        Assert-OrdinaryPath $restore
        [IO.File]::Copy($backup, $restore, $true)
        if ([IO.File]::Exists($target)) {
            [IO.File]::Replace($restore, $target, [NullString]::Value)
        } else {
            [IO.File]::Move($restore, $target)
        }
    }
    [IO.File]::Delete($active)
}

function Install-ForkUpdate(
    [string]$Root, [string]$Archive, [string]$Sha256, [string]$ExpectedVersion,
    [switch]$RecoveryOnly
) {
    $Root = [IO.Path]::GetFullPath($Root)
    $work = Join-Path $Root '.conemu-fork-update'
    $lockPath = Join-Path $work 'lock'
    Assert-OrdinaryPath $lockPath
    [void][IO.Directory]::CreateDirectory($work)
    $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    $active = Join-Path $work 'active'
    try {
        Assert-OrdinaryPath $active
        Undo-ForkUpdate $Root $work
        if ($RecoveryOnly) { return }

        $localGui = Join-Path $Root $gui
        Assert-OrdinaryPath $localGui
        Assert-PeMachine $localGui $machines[$gui]
        if (Test-Path -LiteralPath (Join-Path $Root $otherGui)) {
            throw 'Both x86 and x64 launchers are installed here. Update this directory manually.'
        }
        if ($ExpectedVersion -cnotmatch '\A[0-9]{6}[a-z]?\z' -or
            [string]::CompareOrdinal($ExpectedVersion, (Get-PackageBuild $localGui)) -le 0) {
            throw 'The archive is not a newer build.'
        }
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $stream = [IO.File]::Open($Archive, 'Open', 'Read', 'Read')
        try {
            if ($stream.Length -gt 128MB -or $Sha256 -notmatch '\A[0-9a-fA-F]{64}\z') {
                throw 'The update ZIP failed size or SHA-256 verification.'
            }
            $hash = [Security.Cryptography.SHA256]::Create()
            try { $digest = [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-', '') }
            finally { $hash.Dispose() }
            if ($digest -ine $Sha256) { throw 'The update ZIP failed SHA-256 verification.' }
            $stream.Position = 0
            $zip = [IO.Compression.ZipArchive]::new($stream, 'Read', $true)
            try {
                for ($i = 0; $i -lt $updateFiles.Count; $i++) {
                    $name = $updateFiles[$i]
                    $target = Join-Path $Root $name
                    Assert-OrdinaryPath $target
                    if (![IO.File]::Exists($target)) { throw "Missing installed file: $target" }
                    Wait-ForUpdateFile $target
                    $matchesInZip = @($zip.Entries | Where-Object FullName -ieq $name)
                    if ($matchesInZip.Count -ne 1 -or $matchesInZip[0].Length -le 0 -or
                        $matchesInZip[0].Length -gt 64MB) {
                        throw "Missing, duplicate or oversized package entry: $name"
                    }
                    $staged = Join-Path $work "$i.new"
                    Assert-OrdinaryPath $staged
                    Assert-OrdinaryPath (Join-Path $work "$i.bak")
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($matchesInZip[0], $staged, $true)
                    if ($machines.ContainsKey($name)) { Assert-PeMachine $staged $machines[$name] }
                    if ($name -eq $gui -and (Get-PackageBuild $staged) -cne $ExpectedVersion) {
                        throw 'The package executable version does not match the channel.'
                    }
                }
            } finally { $zip.Dispose() }
        } finally {
            $stream.Dispose()
        }

        for ($i = 0; $i -lt $updateFiles.Count; $i++) {
            [IO.File]::Delete((Join-Path $work "$i.bak"))
        }
        [IO.File]::WriteAllText($active, $ExpectedVersion)
        try {
            for ($i = 0; $i -lt $updateFiles.Count; $i++) {
                Set-UpdateFile (Join-Path $work "$i.new") (Join-Path $Root $updateFiles[$i]) `
                    (Join-Path $work "$i.bak")
            }
            [IO.File]::Delete($active)
        } catch {
            try { Undo-ForkUpdate $Root $work }
            catch { throw "Rollback needs another attempt after Far and ConEmu close. Backups: $work. $_" }
            throw
        }
    } finally {
        try {
            if (![IO.File]::Exists($active)) {
                for ($i = 0; $i -lt $updateFiles.Count; $i++) {
                    foreach ($extension in 'new','bak','restore') {
                        [IO.File]::Delete((Join-Path $work "$i.$extension"))
                    }
                }
            }
        } finally { $lock.Dispose() }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $archive = $null
    try {
        $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
        if ($WaitForPid) {
            $parent = Get-Process -Id $WaitForPid -ErrorAction SilentlyContinue
            if ($parent -and !$parent.HasExited) {
                Wait-Process -InputObject $parent -Timeout 90 -ErrorAction Stop
            }
        }
        if ($Recover) {
            Install-ForkUpdate -Root $root -RecoveryOnly
            $message = 'Any interrupted update has been rolled back. You can start ConEmu now.'
        } else {
            if (!$Version) { throw 'An update version is required.' }
            $feed = (Invoke-WebRequest -UseBasicParsing -Uri $feedUrl -MaximumRedirection 0 -TimeoutSec 30).Content
            $section = [regex]::Match($feed, "(?m)^\[ConEmu_${Architecture}\]\r?\n([^\[]*)").Groups[1].Value
            $versionMatches = [regex]::Matches($section, '(?m)^version=([0-9]{6}[a-z]?)\r?$')
            $shaMatches = [regex]::Matches($section, '(?m)^sha256=([a-f0-9]{64})\r?$')
            $urlMatches = [regex]::Matches($section,
                "(?m)^url=(https://github\.com/Sim-md/ConEmu/releases/download/ci-[0-9a-f]{7}-[0-9]+-[0-9]+/ConEmu-[0-9]{6}[a-z]?-[0-9a-f]{7}-${Architecture}\.zip)\r?$")
            if ($versionMatches.Count -ne 1 -or $versionMatches[0].Groups[1].Value -cne $Version -or
                $shaMatches.Count -ne 1 -or $urlMatches.Count -ne 1) {
                throw 'The update channel changed or returned invalid metadata. Check for updates again.'
            }
            $archive = [IO.Path]::GetTempFileName()
            Invoke-WebRequest -UseBasicParsing -Uri $urlMatches[0].Groups[1].Value -OutFile $archive -TimeoutSec 120
            Install-ForkUpdate -Root $root -Archive $archive -Sha256 $shaMatches[0].Groups[1].Value -ExpectedVersion $Version
            $message = "ConEmu $Version was installed. You can start ConEmu now."
        }
        if (!$Quiet) {
            Add-Type -AssemblyName System.Windows.Forms
            [void][Windows.Forms.MessageBox]::Show($message, 'ConEmu update')
        }
    } catch {
        if (!$Quiet) {
            Add-Type -AssemblyName System.Windows.Forms
            [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, 'ConEmu update failed')
        }
        Write-Error $_
        exit 1
    } finally {
        if ($archive) { [IO.File]::Delete($archive) }
    }
}
