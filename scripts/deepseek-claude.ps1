#Requires -Version 5.1

param(
    [ValidateSet('deepseek-v4-flash', 'deepseek-v4-pro', 'deepseek-v4-flash-vision-exp')]
    [string]$Model = 'deepseek-v4-flash'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$ClaudeJson = Join-Path $env:USERPROFILE '.claude.json'
$ClaudeSettings = Join-Path $ClaudeDir 'settings.json'

$DeepSeekConfigDir = Join-Path $env:USERPROFILE '.config\deepseek-claude'

$UserEnvironmentKey = 'HKCU:\Environment'

$Timestamp = Get-Date -Format 'yyyyMMddHHmmss'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

if ($Model -eq 'deepseek-v4-flash-vision-exp') {
    $ClaudeModel = $Model
} else {
    $ClaudeModel = "$Model[1m]"
}

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


function Set-UserEnvironmentValue([string]$Name, [string]$Value, [string]$Kind = 'String') {
    New-ItemProperty -LiteralPath $UserEnvironmentKey -Name $Name -Value $Value `
        -PropertyType $Kind -Force | Out-Null
    Set-Item -LiteralPath "Env:$Name" -Value ([Environment]::ExpandEnvironmentVariables($Value))
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


if (-not $env:DEEPSEEK_API_KEY) {
    Write-Host 'DEEPSEEK_API_KEY is not set in the environment.'
    exit 1
}

$DeepSeekEnv = [ordered]@{
    ANTHROPIC_BASE_URL              = 'https://api.deepseek.com/anthropic'

    ANTHROPIC_MODEL                 = $ClaudeModel
    ANTHROPIC_DEFAULT_FABLE_MODEL   = 'deepseek-v4-flash-vision-exp'
    ANTHROPIC_DEFAULT_OPUS_MODEL    = 'deepseek-v4-pro[1m]'
    ANTHROPIC_DEFAULT_SONNET_MODEL  = 'deepseek-v4-flash[1m]'
    ANTHROPIC_DEFAULT_HAIKU_MODEL   = 'deepseek-v4-flash'
    CLAUDE_CODE_SUBAGENT_MODEL      = 'deepseek-v4-flash'

    CLAUDE_CODE_EFFORT_LEVEL        = 'max'
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = '786432'
    CLAUDE_CODE_MAX_CONTEXT_TOKENS  = '1048576'
}

New-Item -ItemType Directory -Force -Path $ClaudeDir, $DeepSeekConfigDir | Out-Null

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
    $envBackup = Join-Path $DeepSeekConfigDir "user-env.backup.$Timestamp.json"
    Write-Json $envBackup $previousEnv
}

$claudeConfig = Read-JsonObject $ClaudeJson
$claudeConfig | Add-Member -NotePropertyName 'penguinModeOrgEnabled' -NotePropertyValue $true -Force
$claudeConfig | Add-Member -NotePropertyName 'hasCompletedOnboarding' -NotePropertyValue $true -Force
Remove-ConflictingEnv $claudeConfig
Write-Json $ClaudeJson $claudeConfig

$settings = Read-JsonObject $ClaudeSettings
Remove-ConflictingEnv $settings
Write-Json $ClaudeSettings $settings

foreach ($name in $ConflictingEnvKeys) {
    if ($name -ne 'ANTHROPIC_AUTH_TOKEN' -and -not $DeepSeekEnv.Contains($name)) {
        Remove-UserEnvironmentValue $name
    }
}

foreach ($entry in $DeepSeekEnv.GetEnumerator()) {
    Set-UserEnvironmentValue $entry.Key $entry.Value
}

# Store a reference instead of the key itself. Windows expands it from
# DEEPSEEK_API_KEY whenever it builds the environment for a new process.
Set-UserEnvironmentValue 'ANTHROPIC_AUTH_TOKEN' '%DEEPSEEK_API_KEY%' 'ExpandString'

Publish-EnvironmentChange

Write-Host ''
Write-Host "Claude Code configured for $Model."
Write-Host 'The API key remains in DEEPSEEK_API_KEY and was not copied anywhere.'
Write-Host 'ANTHROPIC_AUTH_TOKEN is stored as a reference to %DEEPSEEK_API_KEY%.'
if ($envBackup) {
    Write-Host "Previous values were saved to: $envBackup"
}

if (-not [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'User') `
    -and -not [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Machine')) {
    Write-Host ''
    Write-Warning ('DEEPSEEK_API_KEY is only set in this session, so new terminals ' +
        'will not see it. Save it as a user environment variable:')
    Write-Host "  [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', 'your-key', 'User')"
}

Write-Host ''
Write-Host 'Open a new terminal, then start Claude Code. Restart apps such as'
Write-Host 'Windows Terminal or VS Code if they were already running.'
Write-Host '  claude'
Write-Host ''
Write-Host 'Verify that /status shows this Base URL:'
Write-Host '  https://api.deepseek.com/anthropic'
