#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
$ConfigFile = Join-Path $ConfigDir 'opencode.jsonc'

if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    Write-Host 'Nothing to remove. DeepSeek V4 for OpenCode does not appear to be installed.'
    exit 0
}

$isDeepSeek = $false

try {
    $config = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($ConfigFile))
    $provider = $config.PSObject.Properties['provider']
    $isDeepSeek = $provider -and $provider.Value.PSObject.Properties['deepseek']
} catch {
    $isDeepSeek = $false
}

if (-not $isDeepSeek) {
    Write-Host "Refusing to remove ${ConfigFile}: it is not a DeepSeek configuration."
    exit 1
}

Remove-Item -LiteralPath $ConfigFile
Write-Host "Removed $ConfigFile"

if ((Test-Path -LiteralPath $ConfigDir -PathType Container) `
    -and -not (Get-ChildItem -LiteralPath $ConfigDir -Force)) {
    Remove-Item -LiteralPath $ConfigDir
}

Write-Host ''
Write-Host 'DeepSeek V4 integration for OpenCode has been removed.'
Write-Host 'DEEPSEEK_API_KEY was not changed.'
