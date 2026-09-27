#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
$ConfigFile = Join-Path $ConfigDir 'opencode.jsonc'

$changed = $false

if ($null -ne [Environment]::GetEnvironmentVariable('KIMI_CODE_API_KEY', 'User')) {
    # PowerShell passes $null to .NET as an empty string, which PowerShell 7
    # stores instead of deleting the variable.
    [Environment]::SetEnvironmentVariable('KIMI_CODE_API_KEY', [NullString]::Value, 'User')
    Write-Host 'Removed user environment variable KIMI_CODE_API_KEY'
    $changed = $true
}
Remove-Item -LiteralPath 'Env:KIMI_CODE_API_KEY' -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath $ConfigFile -PathType Leaf) {
    Remove-Item -LiteralPath $ConfigFile
    Write-Host "Removed $ConfigFile"
    $changed = $true
}

if ((Test-Path -LiteralPath $ConfigDir -PathType Container) `
    -and -not (Get-ChildItem -LiteralPath $ConfigDir -Force)) {
    Remove-Item -LiteralPath $ConfigDir
    Write-Host "Removed empty $ConfigDir\"
}

if (-not $changed) {
    Write-Host 'Nothing to remove. Kimi K3 for OpenCode does not appear to be installed.'
    exit 0
}

Write-Host ''
Write-Host 'Kimi K3 integration for OpenCode has been removed.'
Write-Host ''
Write-Host 'Open a new terminal so it picks up the change.'
Write-Host ''
Write-Host 'To restore a previous OpenCode configuration, copy the desired backup:'
Write-Host '  Get-ChildItem ~\.config\opencode\opencode.jsonc.backup.* | Sort-Object Name -Descending'
