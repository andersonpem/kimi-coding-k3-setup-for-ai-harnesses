#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$KimiConfigDir = Join-Path $env:USERPROFILE '.config\kimi-claude'
$KimiBaseUrl = 'https://api.kimi.com/coding/'

$KimiEnvKeys = @(
    'ANTHROPIC_BASE_URL'
    'ANTHROPIC_API_KEY'
    'ANTHROPIC_MODEL'
    'ANTHROPIC_DEFAULT_FABLE_MODEL'
    'ANTHROPIC_DEFAULT_OPUS_MODEL'
    'ANTHROPIC_DEFAULT_SONNET_MODEL'
    'ANTHROPIC_DEFAULT_HAIKU_MODEL'
    'CLAUDE_CODE_SUBAGENT_MODEL'
    'CLAUDE_CODE_AUTO_COMPACT_WINDOW'
    'CLAUDE_CODE_MAX_CONTEXT_TOKENS'
)

$UserEnvironmentKey = 'HKCU:\Environment'


# Tell Explorer and other running apps to reload the user environment,
# so programs started afterwards see the change.
function Publish-EnvironmentChange {
    if (-not ('AgentSetup.NativeMethods' -as [type])) {
        Add-Type -Namespace AgentSetup -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint msg, UIntPtr wParam, string lParam,
    uint flags, uint timeout, out UIntPtr result);
'@
    }

    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x1a
    $SMTO_ABORTIFHUNG = 0x2
    $result = [UIntPtr]::Zero

    [AgentSetup.NativeMethods]::SendMessageTimeout(
        $HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'Environment',
        $SMTO_ABORTIFHUNG, 5000, [ref]$result) | Out-Null
}


$changed = $false
$userEnvironment = Get-Item -LiteralPath $UserEnvironmentKey

# Only remove the variables if they still point at Kimi, so another
# provider configured afterwards is left alone.
if ($userEnvironment.GetValue('ANTHROPIC_BASE_URL') -eq $KimiBaseUrl) {
    foreach ($name in $KimiEnvKeys) {
        if ($null -ne $userEnvironment.GetValue($name)) {
            Remove-ItemProperty -LiteralPath $UserEnvironmentKey -Name $name
            Write-Host "Removed user environment variable $name"
        }
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    Publish-EnvironmentChange
    $changed = $true
}

if ((Test-Path -LiteralPath $KimiConfigDir -PathType Container) `
    -and -not (Get-ChildItem -LiteralPath $KimiConfigDir -Force)) {
    Remove-Item -LiteralPath $KimiConfigDir
    Write-Host "Removed empty $KimiConfigDir\"
}

if (-not $changed) {
    Write-Host 'Nothing to remove. Kimi K3 for Claude Code does not appear to be installed.'
    exit 0
}

Write-Host ''
Write-Host 'Kimi K3 integration for Claude Code has been removed.'
Write-Host ''
Write-Host 'Open a new terminal so it picks up the change. Restart apps such as'
Write-Host 'Windows Terminal or VS Code if they were already running.'
Write-Host ''
Write-Host 'To restore previous Claude Code settings, copy the desired backup over'
Write-Host 'the original. Backups are listed newest-first by:'
Write-Host '  Get-ChildItem ~\.claude.json.backup.* | Sort-Object Name -Descending'
Write-Host '  Get-ChildItem ~\.claude\settings.json.backup.* | Sort-Object Name -Descending'
Write-Host ''
Write-Host 'Environment variables replaced during setup, if any, were saved to:'
Write-Host "  $KimiConfigDir\user-env.backup.*.json"
