#Requires -Version 5.1

param(
    [ValidateSet('deepseek-v4-flash', 'deepseek-v4-pro', 'deepseek-v4-flash-vision-exp')]
    [string]$Model = 'deepseek-v4-flash'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
$ConfigFile = Join-Path $ConfigDir 'opencode.jsonc'

if (-not $env:DEEPSEEK_API_KEY) {
    Write-Host 'DEEPSEEK_API_KEY is not set in the environment.'
    exit 1
}

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

if (Test-Path -LiteralPath $ConfigFile -PathType Leaf) {
    Copy-Item -LiteralPath $ConfigFile -Destination "$ConfigFile.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
}


function New-ModelConfig([string]$Name, [switch]$Vision) {
    if ($Vision) {
        $inputModalities = @('text', 'image')
    } else {
        $inputModalities = @('text')
    }

    return [ordered]@{
        name       = $Name
        reasoning  = $true
        tool_call  = $true
        modalities = [ordered]@{ input = $inputModalities; output = @('text') }
        limit      = [ordered]@{ context = 1048576; output = 393216 }
        options    = [ordered]@{
            reasoningEffort = 'high'
            thinking        = @{ type = 'enabled' }
        }
        variants   = [ordered]@{
            none = @{ thinking = @{ type = 'disabled' } }
            low  = [ordered]@{ reasoningEffort = 'low'; thinking = @{ type = 'enabled' } }
            high = [ordered]@{ reasoningEffort = 'high'; thinking = @{ type = 'enabled' } }
            max  = [ordered]@{ reasoningEffort = 'max'; thinking = @{ type = 'enabled' } }
        }
    }
}


$config = [ordered]@{
    '$schema' = 'https://opencode.ai/config.json'
    model     = "deepseek/$Model"
    provider  = [ordered]@{
        deepseek = [ordered]@{
            npm     = '@ai-sdk/openai-compatible'
            name    = 'DeepSeek'
            options = [ordered]@{
                baseURL = 'https://api.deepseek.com'
                apiKey  = '{env:DEEPSEEK_API_KEY}'
            }
            models  = [ordered]@{
                'deepseek-v4-flash'            = New-ModelConfig 'DeepSeek V4 Flash'
                'deepseek-v4-pro'              = New-ModelConfig 'DeepSeek V4 Pro'
                'deepseek-v4-flash-vision-exp' = New-ModelConfig 'DeepSeek V4 Flash Vision Experimental' -Vision
            }
        }
    }
}

$json = ConvertTo-Json -InputObject $config -Depth 100
[System.IO.File]::WriteAllText($ConfigFile, $json + "`n", (New-Object System.Text.UTF8Encoding $false))

Write-Host ''
Write-Host 'OpenCode configured for the DeepSeek V4 family.'
Write-Host "Default model: deepseek/$Model"
Write-Host 'The API key is read from DEEPSEEK_API_KEY and was not copied to a file.'

if (-not [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'User') `
    -and -not [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Machine')) {
    Write-Host ''
    Write-Warning ('DEEPSEEK_API_KEY is only set in this session, so new terminals ' +
        'will not see it. Save it as a user environment variable:')
    Write-Host "  [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', 'your-key', 'User')"
}

Write-Host ''
Write-Host 'Validate:'
Write-Host '  opencode models'
Write-Host ''
Write-Host 'Select a model:'
Write-Host '  opencode --model deepseek/deepseek-v4-flash'
Write-Host '  opencode --model deepseek/deepseek-v4-pro'
Write-Host '  opencode --model deepseek/deepseek-v4-flash-vision-exp'
