param(
    [string]$SteamPath,
    [string]$Configuration = "Release",
    [string]$SigningPfx,
    [string]$SigningPassword
)

$ErrorActionPreference = "Stop"

if ($Configuration -notmatch '^[A-Za-z0-9_.-]+$') {
    throw "Configuration may contain only letters, numbers, dot, underscore, and hyphen."
}

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$artifactsRoot = Join-Path $sourceRoot "artifacts\$Configuration"
$steamAppId = "504230"

function Add-SteamLibrary([string]$Path, [System.Collections.Generic.List[string]]$Libraries) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $candidate = $Path.Trim().Replace('/', '\')
    if ((Test-Path (Join-Path $candidate "Celeste.exe")) -and (Test-Path (Join-Path $candidate "Content\Graphics"))) {
        $script:gameRoot = (Resolve-Path -LiteralPath $candidate).Path
        return
    }
    if (Test-Path (Join-Path $candidate "steamapps\common\Celeste\Celeste.exe")) {
        $Libraries.Add($candidate)
    }
}

$libraries = [System.Collections.Generic.List[string]]::new()
if ($SteamPath) {
    Add-SteamLibrary $SteamPath $libraries
} else {
    $steamRoots = [System.Collections.Generic.List[string]]::new()
    try {
        $registeredSteam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction Stop).SteamPath
        if ($registeredSteam) { $steamRoots.Add($registeredSteam) }
    } catch { }
    foreach ($defaultRoot in @("${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam", "C:\Steam")) {
        if (Test-Path $defaultRoot) { $steamRoots.Add($defaultRoot) }
    }

    foreach ($steamRoot in $steamRoots) {
        Add-SteamLibrary $steamRoot $libraries
        $libraryFile = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $libraryFile) {
            $libraryText = Get-Content -LiteralPath $libraryFile -Raw
            foreach ($match in [regex]::Matches($libraryText, '"path"\s+"([^"]+)"')) {
                Add-SteamLibrary $match.Groups[1].Value.Replace('\\', '\') $libraries
            }
        }
    }
}

if (-not $script:gameRoot) {
    foreach ($library in $libraries) {
        $candidate = Join-Path $library "steamapps\common\Celeste"
        if ((Test-Path (Join-Path $candidate "Celeste.exe")) -and (Test-Path (Join-Path $candidate "Content\Graphics"))) {
            $script:gameRoot = (Resolve-Path -LiteralPath $candidate).Path
            break
        }
    }
}

if (-not $script:gameRoot) {
    throw "Could not find Steam Celeste (AppID $steamAppId). Pass -SteamPath with the game folder or Steam library folder."
}

$assemblyPath = Join-Path $script:gameRoot "Celeste.exe"
$contentPath = Join-Path $script:gameRoot "Content"
$ilspy = Get-Command ilspycmd.exe -ErrorAction SilentlyContinue
if (-not $ilspy) {
    $toolPath = Join-Path $artifactsRoot "tools"
    New-Item -ItemType Directory -Path $toolPath -Force | Out-Null
    dotnet tool install ilspycmd --tool-path $toolPath
    if ($LASTEXITCODE -ne 0) { throw "Could not install ILSpy command-line tool." }
    $ilspyExe = Join-Path $toolPath "ilspycmd.exe"
} else {
    $ilspyExe = $ilspy.Source
}

$decompiledPath = Join-Path $artifactsRoot "decompiled-steam"
if (Test-Path $decompiledPath) { Remove-Item -LiteralPath $decompiledPath -Recurse -Force }
New-Item -ItemType Directory -Path $decompiledPath -Force | Out-Null
& $ilspyExe -p -o $decompiledPath $assemblyPath
if ($LASTEXITCODE -ne 0) { throw "ILSpy could not decompile $assemblyPath" }

$buildArgs = @{
    Configuration = $Configuration
    PayloadPath = $script:gameRoot
}
if ($SigningPfx) {
    $buildArgs.SigningPfx = $SigningPfx
    $buildArgs.SigningPassword = $SigningPassword
}
& (Join-Path $PSScriptRoot "Build-Xbox.ps1") @buildArgs
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "UWP package build failed." }

Write-Host "Steam game: $script:gameRoot"
Write-Host "Decompiled source (reference only): $decompiledPath"
Write-Host "The APPX was built from the checked-in UWP-adapted source project."
Write-Host "APPX: $(Join-Path $artifactsRoot 'CelesteUWP_x64.appx')"
