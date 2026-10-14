param(
    [string]$Configuration = "Release",
    [string]$PayloadPath,
    [string]$SigningPfx,
    [string]$SigningPassword
)

$ErrorActionPreference = "Stop"
$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($PayloadPath) {
    $payloadRoot = (Resolve-Path -LiteralPath $PayloadPath).Path
} else {
    $payloadRoot = (Resolve-Path (Join-Path $sourceRoot "..\Publish")).Path
}
$artifactsRoot = Join-Path $sourceRoot "artifacts\$Configuration"
$publishOutput = Join-Path $artifactsRoot "publish-win-x64"
$stagingRoot = Join-Path $artifactsRoot "xbox-stage"
$packagePath = Join-Path $artifactsRoot "CelesteUWP_x64.appx"
$makeAppx = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64\MakeAppx.exe"
$signTool = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64\SignTool.exe"

if (-not (Test-Path (Join-Path $payloadRoot "Content\Graphics"))) {
    throw "Payload de jogo não encontrado: $payloadRoot\Content"
}

dotnet publish (Join-Path $sourceRoot "Celeste.csproj") --configuration $Configuration `
    --runtime win-x64 --self-contained true -p:BuildProjectReferences=false `
    -p:UseAppHost=true -o $publishOutput
if ($LASTEXITCODE -ne 0) { throw "A compilação do Celeste falhou." }

if (-not (Test-Path $publishOutput)) { throw "Publish output missing: $publishOutput" }
if (-not (Test-Path $makeAppx)) { throw "MakeAppx.exe não encontrado no Windows SDK." }

if (Test-Path $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
Copy-Item (Join-Path $payloadRoot "*") $stagingRoot -Recurse -Force
if (Test-Path (Join-Path $stagingRoot "Saves")) {
    Remove-Item -LiteralPath (Join-Path $stagingRoot "Saves") -Recurse -Force
}
Copy-Item (Join-Path $publishOutput "*") $stagingRoot -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $stagingRoot "Assets") -Force | Out-Null
Copy-Item (Join-Path $PSScriptRoot "Assets\*") (Join-Path $stagingRoot "Assets") -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot "AppxManifest.xml") $stagingRoot -Force

if (Test-Path $packagePath) { Remove-Item -LiteralPath $packagePath -Force }
& $makeAppx pack /d $stagingRoot /p $packagePath /o 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "A criação do pacote APPX falhou." }

if ($SigningPfx) {
    if (-not (Test-Path $SigningPfx)) { throw "Certificado PFX não encontrado: $SigningPfx" }
    if (-not (Test-Path $signTool)) { throw "SignTool.exe não encontrado no Windows SDK." }
    & $signTool sign /fd SHA256 /f $SigningPfx /p $SigningPassword $packagePath
    if ($LASTEXITCODE -ne 0) { throw "Não foi possível assinar o pacote APPX." }
} else {
    Write-Host "Pacote não assinado: use -SigningPfx e -SigningPassword para assinar."
}

Write-Host "Pacote criado em $packagePath"
