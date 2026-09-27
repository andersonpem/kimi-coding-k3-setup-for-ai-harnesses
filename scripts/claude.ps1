#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$ClaudeJson = Join-Path $env:USERPROFILE '.claude.json'
$ClaudeSettings = Join-Path $ClaudeDir 'settings.json'

$KimiConfigDir = Join-Path $env:USERPROFILE '.config\kimi-claude'

$UserEnvironmentKey = 'HKCU:\Environment'

$Timestamp = Get-Date -Format 'yyyyMMddHHmmss'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

$ConflictingEnvKeys = @(
    'ANTHROPIC_BASE_URL'
    'ANTHROPIC_API_KEY'
    'ANTHROPIC_AUTH_TOKEN'
    'ANTHROPIC_MODEL'
    'ANTHROPIC_SMALL_FAST_MODEL'
    'ANTHROPIC_DEFAULT_FABLE_MODEL'
    'ANTHROPIC_DEFAULT_FABLE_MODEL_NAME'
    'ANTHROPIC_DEFAULT_OPUS_MODEL'
    'ANTHROPIC_DEFAULT_OPUS_MODEL_NAME'
    'ANTHROPIC_DEFAULT_SONNET_MODEL'
    'ANTHROPIC_DEFAULT_SONNET_MODEL_NAME'
    'ANTHROPIC_DEFAULT_HAIKU_MODEL'
    'ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME'
    'CLAUDE_CODE_SUBAGENT_MODEL'
    'CLAUDE_CODE_AUTO_COMPACT_WINDOW'
    'CLAUDE_CODE_MAX_CONTEXT_TOKENS'
    'CLAUDE_CODE_EFFORT_LEVEL'
)


function Read-JsonObject([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{}
    }

    $text = [System.IO.File]::ReadAllText($Path)

    if (-not $text.Trim()) {
        return [pscustomobject]@{}
    }

    # PowerShell 7.5+ can keep ISO timestamps as strings instead of
    # converting them to dates and rewriting them in another format.
    $options = @{}
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
        $options.DateKind = 'String'
    }

    try {
        $value = ConvertFrom-Json -InputObject $text @options
    } catch {
        throw "Invalid JSON in ${Path}: $($_.Exception.Message)"
    }

    if ($value -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Expected a JSON object in $Path"
    }

    return $value
}


function Write-Json([string]$Path, $Value) {
    $json = ConvertTo-Json -InputObject $Value -Depth 100
    [System.IO.File]::WriteAllText($Path, $json + "`n", $Utf8NoBom)
}


function Remove-ConflictingEnv($Config) {
    $envProperty = $Config.PSObject.Properties['env']

    if (-not $envProperty -or $envProperty.Value -isnot [System.Management.Automation.PSCustomObject]) {
        return
    }

    foreach ($key in $ConflictingEnvKeys) {
        $envProperty.Value.PSObject.Properties.Remove($key)
    }

    if (@($envProperty.Value.PSObject.Properties).Count -eq 0) {
        $Config.PSObject.Properties.Remove('env')
    }
}


function Get-UserEnvironmentValue([string]$Name) {
    $key = Get-Item -LiteralPath $UserEnvironmentKey
    return $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
}


function Set-UserEnvironmentValue([string]$Name, [string]$Value) {
    New-ItemProperty -LiteralPath $UserEnvironmentKey -Name $Name -Value $Value `
        -PropertyType String -Force | Out-Null
    Set-Item -LiteralPath "Env:$Name" -Value $Value
}


function Remove-UserEnvironmentValue([string]$Name) {
    if ($null -ne (Get-UserEnvironmentValue $Name)) {
        Remove-ItemProperty -LiteralPath $UserEnvironmentKey -Name $Name
    }
    Remove-Item -LiteralPath "Env:$Name" -ErrorAction SilentlyContinue
}


# Tell Explorer and other running apps to reload the user environment,
# so programs started afterwards see the new values.
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


$secureKey = Read-Host -Prompt 'Kimi Code API key' -AsSecureString
$apiKey = (New-Object System.Net.NetworkCredential('', $secureKey)).Password

if (-not $apiKey) {
    Write-Host 'API key cannot be empty.'
    exit 1
}

$KimiEnv = [ordered]@{
    ANTHROPIC_BASE_URL              = 'https://api.kimi.com/coding/'
    ANTHROPIC_API_KEY               = $apiKey

    ANTHROPIC_MODEL                 = 'k3-256k'
    ANTHROPIC_DEFAULT_FABLE_MODEL   = 'kimi-for-coding'
    ANTHROPIC_DEFAULT_OPUS_MODEL    = 'k3[1m]'
    ANTHROPIC_DEFAULT_SONNET_MODEL  = 'k3[1m]'
    ANTHROPIC_DEFAULT_HAIKU_MODEL   = 'kimi-for-coding-highspeed'
    CLAUDE_CODE_SUBAGENT_MODEL      = 'k3-256k'

    CLAUDE_CODE_AUTO_COMPACT_WINDOW = '262144'
    CLAUDE_CODE_MAX_CONTEXT_TOKENS  = '262144'
}

New-Item -ItemType Directory -Force -Path $ClaudeDir, $KimiConfigDir | Out-Null

foreach ($file in $ClaudeJson, $ClaudeSettings) {
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        Copy-Item -LiteralPath $file -Destination "$file.backup.$Timestamp"
    }
}

# Existing user-level values are replaced below, so keep a copy of them.
$previousEnv = [ordered]@{}
foreach ($name in $ConflictingEnvKeys) {
    $value = Get-UserEnvironmentValue $name
    if ($null -ne $value) {
        $previousEnv[$name] = $value
    }
}

$envBackup = $null
if ($previousEnv.Count -gt 0) {
    $envBackup = Join-Path $KimiConfigDir "user-env.backup.$Timestamp.json"
    Write-Json $envBackup $previousEnv
}

# Skip the normal Anthropic onboarding flow and enable third-party models.
$claudeConfig = Read-JsonObject $ClaudeJson
$claudeConfig | Add-Member -NotePropertyName 'penguinModeOrgEnabled' -NotePropertyValue $true -Force
$claudeConfig | Add-Member -NotePropertyName 'hasCompletedOnboarding' -NotePropertyValue $true -Force

# Claude Code also applies the env block from ~/.claude.json. Stale
# provider values there (e.g. ANTHROPIC_AUTH_TOKEN) override the user
# environment and trigger a both-auth-methods-set warning.
Remove-ConflictingEnv $claudeConfig
Write-Json $ClaudeJson $claudeConfig

# Remove stale settings that could override the Kimi environment.
$settings = Read-JsonObject $ClaudeSettings
Remove-ConflictingEnv $settings
Write-Json $ClaudeSettings $settings

foreach ($name in $ConflictingEnvKeys) {
    if (-not $KimiEnv.Contains($name)) {
        Remove-UserEnvironmentValue $name
    }
}

foreach ($entry in $KimiEnv.GetEnumerator()) {
    Set-UserEnvironmentValue $entry.Key $entry.Value
}

Publish-EnvironmentChange

Remove-Variable apiKey, secureKey

Write-Host ''
Write-Host 'Claude Code configured for Kimi Code. Default model: k3-256k (256K context).'
Write-Host 'Settings are stored as user environment variables.'
if ($envBackup) {
    Write-Host "Previous values were saved to: $envBackup"
}
Write-Host ''
Write-Host 'Open a new terminal so it picks up the new environment. Restart apps'
Write-Host 'such as Windows Terminal or VS Code if they were already running.'
Write-Host ''
Write-Host 'Start Claude Code:'
Write-Host '  claude'
Write-Host ''
Write-Host 'Verify inside Claude Code:'
Write-Host '  /status'
Write-Host ''
Write-Host 'The Base URL should be:'
Write-Host '  https://api.kimi.com/coding/'
Write-Host ''
Write-Host 'Change K3 reasoning effort with:'
Write-Host '  /effort'
