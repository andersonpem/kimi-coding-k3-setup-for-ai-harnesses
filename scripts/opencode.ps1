#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
$ConfigFile = Join-Path $ConfigDir 'opencode.jsonc'

$secureKey = Read-Host -Prompt 'Kimi Code API key' -AsSecureString
$apiKey = (New-Object System.Net.NetworkCredential('', $secureKey)).Password

if (-not $apiKey) {
    Write-Host 'API key cannot be empty.'
    exit 1
}

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

if (Test-Path -LiteralPath $ConfigFile -PathType Leaf) {
    Copy-Item -LiteralPath $ConfigFile -Destination "$ConfigFile.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
}

$config = @'
{
  "$schema": "https://opencode.ai/config.json",

  "model": "kimi-code/k3-256k",

  "provider": {
    "kimi-code": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Kimi Code",

      "options": {
        "baseURL": "https://api.kimi.com/coding/v1",
        "apiKey": "{env:KIMI_CODE_API_KEY}"
      },

      "models": {
        "k3": {
          "name": "Kimi K3",

          "limit": {
            "context": 1048576,
            "output": 131072
          },

          "options": {
            "reasoningEffort": "low"
          },

          "variants": {
            "low": {
              "reasoningEffort": "low"
            },

            "high": {
              "reasoningEffort": "high"
            },

            "max": {
              "reasoningEffort": "max"
            }
          }
        },

        "k3-256k": {
          "name": "Kimi K3-256K",

          "limit": {
            "context": 262144,
            "output": 131072
          },

          "options": {
            "reasoningEffort": "low"
          },

          "variants": {
            "low": {
              "reasoningEffort": "low"
            },

            "high": {
              "reasoningEffort": "high"
            },

            "max": {
              "reasoningEffort": "max"
            }
          }
        },

        "kimi-for-coding": {
          "name": "Kimi K2.7 Code",

          "limit": {
            "context": 262144,
            "output": 131072
          }
        },

        "kimi-for-coding-highspeed": {
          "name": "Kimi For Coding HighSpeed",

          "limit": {
            "context": 262144,
            "output": 131072
          }
        }
      }
    }
  }
}
'@

[System.IO.File]::WriteAllText($ConfigFile, ($config -replace "`r`n", "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))

[Environment]::SetEnvironmentVariable('KIMI_CODE_API_KEY', $apiKey, 'User')
[Environment]::SetEnvironmentVariable('KIMI_CODE_API_KEY', $apiKey, 'Process')

Remove-Variable apiKey, secureKey

Write-Host ''
Write-Host 'OpenCode configured for Kimi Code. Default model: kimi-code/k3-256k.'
Write-Host "Config: $ConfigFile"
Write-Host 'The API key is stored in the KIMI_CODE_API_KEY user environment variable.'
Write-Host ''
Write-Host 'Open a new terminal so it picks up the new environment. Restart apps'
Write-Host 'such as Windows Terminal or VS Code if they were already running.'
Write-Host ''
Write-Host 'Validate:'
Write-Host '  opencode models'
Write-Host ''
Write-Host 'Start Kimi Code:'
Write-Host '  opencode --model kimi-code/k3-256k'
