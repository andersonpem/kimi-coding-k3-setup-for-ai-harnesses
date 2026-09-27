#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$DeepSeekConfigDir = Join-Path $env:USERPROFILE '.config\deepseek-claude'
$DeepSeekBaseUrl = 'https://api.deepseek.com/anthropic'

$DeepSeekEnvKeys = @(
    'ANTHROPIC_BASE_URL'
    'ANTHROPIC_AUTH_TOKEN'
    'ANTHROPIC_MODEL'
    'ANTHROPIC_DEFAULT_FABLE_MODEL'
    'ANTHROPIC_DEFAULT_OPUS_MODEL'
    'ANTHROPIC_DEFAULT_SONNET_MODEL'
    'ANTHROPIC_DEFAULT_HAIKU_MODEL'
    'CLAUDE_CODE_SUBAGENT_MODEL'
    'CLAUDE_CODE_EFFORT_LEVEL'
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

# Only remove the variables if they still point at DeepSeek, so another
# provider configured afterwards is left alone.
if ($userEnvironment.GetValue('ANTHROPIC_BASE_URL') -eq $DeepSeekBaseUrl) {
    foreach ($name in $DeepSeekEnvKeys) {
        if ($null -ne $userEnvironment.GetValue($name)) {
            Remove-ItemProperty -LiteralPath $UserEnvironmentKey -Name $name
            Write-Host "Removed user environment variable $name"
        }
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    Publish-EnvironmentChange
    $changed = $true
}

if ((Test-Path -LiteralPath $DeepSeekConfigDir -PathType Container) `
    -and -not (Get-ChildItem -LiteralPath $DeepSeekConfigDir -Force)) {
    Remove-Item -LiteralPath $DeepSeekConfigDir
}

if (-not $changed) {
    Write-Host 'Nothing to remove. DeepSeek V4 for Claude Code does not appear to be installed.'
    exit 0
}

Write-Host ''
Write-Host 'DeepSeek V4 integration for Claude Code has been removed.'
Write-Host 'DEEPSEEK_API_KEY was not changed.'
Write-Host ''
Write-Host 'Open a new terminal so it picks up the change.'
