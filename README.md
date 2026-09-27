# Kimi K3 and DeepSeek V4 setup for AI coding agents

Small, auditable setup scripts for using [Kimi K3](https://www.kimi.com/code/docs/en/) or [DeepSeek V4](https://api-docs.deepseek.com/) with [Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started) or [OpenCode](https://opencode.ai/en/docs), on macOS, Linux, and Windows.

The Kimi scripts prompt for the API key without echoing it. The DeepSeek scripts consume `DEEPSEEK_API_KEY` from the environment and never copy its value into generated configuration.

> [!IMPORTANT]
> These scripts modify files in your home directory (and, on Windows, your user environment variables) and back up what they change as described below. Review the script you intend to run before executing it.

## Supported agents

Each script comes in two variants: `.sh` for macOS and Linux, and `.ps1` for Windows.

| Provider | Agent | Setup | Uninstall | Protocol | Default model |
|----------|-------|-------|-----------|----------|---------------|
| Kimi | Claude Code | `scripts/claude` | `scripts/claude-uninstall` | Anthropic-compatible | `k3-256k` |
| Kimi | OpenCode | `scripts/opencode` | `scripts/opencode-uninstall` | OpenAI-compatible | `kimi-code/k3-256k` |
| DeepSeek | Claude Code | `scripts/deepseek-claude` | `scripts/deepseek-claude-uninstall` | Anthropic-compatible | `deepseek-v4-flash` |
| DeepSeek | OpenCode | `scripts/deepseek-opencode` | `scripts/deepseek-opencode-uninstall` | OpenAI-compatible | `deepseek/deepseek-v4-flash` |

## Prerequisites

- One of:
  - macOS or Linux with Bash and/or Zsh, and Python 3
  - Windows 10 or 11 with Windows PowerShell 5.1 or PowerShell 7 (Python is not needed)
- The coding agent you want to configure: [Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started) or [OpenCode](https://opencode.ai/en/docs)
- For Kimi, an active Kimi Code membership with access to K3, and an API key from the [Kimi Code Console](https://www.kimi.com/code/console)
- For DeepSeek, an API key from the [DeepSeek Platform](https://platform.deepseek.com/api_keys) exported as `DEEPSEEK_API_KEY`

Kimi Code keys and Kimi Open Platform keys are not interchangeable. These scripts expect a key for `api.kimi.com`, not a key for `api.moonshot.cn`.

## Quick start

Clone the repository:

```sh
git clone https://github.com/andersonpem/kimi-coding-k3-setup-for-ai-harnesses.git
cd kimi-coding-k3-setup-for-ai-harnesses
```

### macOS and Linux

Review and run the script for your agent:

```sh
# Claude Code
less scripts/claude.sh
./scripts/claude.sh

# Or OpenCode
less scripts/opencode.sh
./scripts/opencode.sh
```

The script asks for your Kimi Code API key. Input is hidden. Once setup finishes, reload your shell:

```sh
source ~/.bashrc   # bash
source ~/.zshrc    # zsh
```

For DeepSeek, export the key through your operating system or shell environment, then run the matching script:

```sh
export DEEPSEEK_API_KEY="your-key"

# Claude Code; defaults to deepseek-v4-flash
./scripts/deepseek-claude.sh

# OpenCode; installs the complete family and defaults to deepseek-v4-flash
./scripts/deepseek-opencode.sh
```

Pass a model ID to choose another default. Valid IDs are `deepseek-v4-flash`, `deepseek-v4-pro`, and `deepseek-v4-flash-vision-exp`:

```sh
./scripts/deepseek-claude.sh deepseek-v4-pro
./scripts/deepseek-opencode.sh deepseek-v4-flash-vision-exp
```

### Windows

Review and run the script for your agent from PowerShell. `-ExecutionPolicy Bypass` applies only to that one invocation and does not change your system policy:

```powershell
# Claude Code
notepad .\scripts\claude.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\claude.ps1

# Or OpenCode
notepad .\scripts\opencode.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\opencode.ps1
```

The script asks for your Kimi Code API key. Input is masked. Once setup finishes, open a new terminal. Restart Windows Terminal, VS Code, or any other app that was already running so it picks up the new environment.

For DeepSeek, save the key as a persistent user environment variable, open a new terminal, then run the matching script:

```powershell
[Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', 'your-key', 'User')

# In a new terminal:
powershell -ExecutionPolicy Bypass -File .\scripts\deepseek-claude.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\deepseek-opencode.ps1
```

Pass a model ID to choose another default:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deepseek-claude.ps1 deepseek-v4-pro
powershell -ExecutionPolicy Bypass -File .\scripts\deepseek-opencode.ps1 deepseek-v4-flash-vision-exp
```

## Claude Code

Run the setup script for your platform, reload your shell or open a new terminal, then start Claude Code:

```sh
claude
```

Inside Claude Code, run `/status` and confirm that the base URL is `https://api.kimi.com/coding/` for Kimi or `https://api.deepseek.com/anthropic` for DeepSeek.

The Kimi configuration defaults to `k3-256k` with a 256K context window. The Opus and Sonnet aliases map to `k3[1m]`, the 1M-context K3, so you can switch to it with `/model`. Use `/effort` to change K3's reasoning effort.

### What the Claude Code scripts change

On every platform:

- Updates `~/.claude.json` to enable third-party models and mark onboarding complete.
- Removes provider-related environment values (such as `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_BASE_URL`) from `~/.claude.json` and `~/.claude/settings.json` when they would override the new configuration. Leaving a stale `ANTHROPIC_AUTH_TOKEN` in either file triggers Claude Code's "both auth methods set" warning. Other settings are preserved.
- Creates timestamped backups of both files before changing them.

On macOS and Linux:

- Kimi: creates `~/.config/kimi-claude/env.sh`, sets its permissions to `600`, and stores the API endpoint, key, model aliases, and context settings there.
- DeepSeek: creates `~/.config/deepseek-claude/env.sh`, which maps `ANTHROPIC_AUTH_TOKEN` to `DEEPSEEK_API_KEY` at load time without storing the key.
- Adds a marked block to `~/.bashrc` and `~/.zshrc` that loads `env.sh`, backing up both files first. Re-running the script updates the existing block instead of adding a duplicate.

On Windows:

- Stores the same settings as persistent user environment variables (`HKCU\Environment`), so every new terminal and app sees them: PowerShell, cmd, Git Bash, and editors such as VS Code. There is no `env.sh` file and no profile is edited.
- Kimi: the API key is stored in the `ANTHROPIC_API_KEY` user variable.
- DeepSeek: `ANTHROPIC_AUTH_TOKEN` is stored as a reference to `%DEEPSEEK_API_KEY%`, not the key itself. Windows expands it when it starts a process, so `DEEPSEEK_API_KEY` must be a persistent user or system variable. The script warns if it is only set in the current session.
- Clears the other provider's variables, so switching between Kimi and DeepSeek does not leave conflicting credentials behind. Any existing user-level values it replaces are saved first to `~\.config\kimi-claude\user-env.backup.*.json` or `~\.config\deepseek-claude\user-env.backup.*.json`.

## OpenCode

Run the setup script for your platform, reload your shell or open a new terminal, then validate and start OpenCode:

```sh
opencode models
opencode --model kimi-code/k3-256k
```

The Kimi configuration includes `kimi-code/k3` (1M context), `kimi-code/k3-256k` (256K context, the default), `kimi-code/kimi-for-coding`, and `kimi-code/kimi-for-coding-highspeed`. The K3 models have `low`, `high`, and `max` reasoning variants and use `low` by default.

The DeepSeek configuration installs the complete V4 family:

```sh
opencode --model deepseek/deepseek-v4-flash
opencode --model deepseek/deepseek-v4-pro
opencode --model deepseek/deepseek-v4-flash-vision-exp
```

### What the OpenCode scripts change

- Writes `~/.config/opencode/opencode.jsonc` (`%USERPROFILE%\.config\opencode\opencode.jsonc` on Windows), creating a timestamped backup of an existing file first.
- Kimi on macOS and Linux: adds or updates `KIMI_CODE_API_KEY` in `~/.bashrc` and `~/.zshrc`.
- Kimi on Windows: stores the key in the `KIMI_CODE_API_KEY` user environment variable.
- DeepSeek: reads the key from `DEEPSEEK_API_KEY` at runtime and stores nothing else.

> [!WARNING]
> The OpenCode scripts replace the complete `opencode.jsonc` file. If you already use other providers or custom OpenCode settings, merge the generated provider into your configuration manually or restore the backup afterward.

## Backups and removal

Backups use the suffix `.backup.YYYYMMDDHHMMSS` and sit next to the original file. For example:

```text
~/.claude.json.backup.20260719123045
~/.config/opencode/opencode.jsonc.backup.20260719123045
```

To uninstall, review and run the uninstall script that matches your setup script:

```sh
# macOS and Linux
./scripts/claude-uninstall.sh
./scripts/opencode-uninstall.sh
./scripts/deepseek-claude-uninstall.sh
./scripts/deepseek-opencode-uninstall.sh
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\scripts\claude-uninstall.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\opencode-uninstall.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\deepseek-claude-uninstall.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\deepseek-opencode-uninstall.ps1
```

Each uninstall script removes what its setup script added: the shell RC entries and `env.sh` on macOS and Linux, or the user environment variables on Windows, plus any generated configuration file. On Windows, the Claude Code uninstall scripts only remove variables while `ANTHROPIC_BASE_URL` still points at their own provider, so they leave another provider's configuration alone. The DeepSeek OpenCode uninstall script refuses to delete an `opencode.jsonc` that does not contain a DeepSeek provider. `DEEPSEEK_API_KEY` itself is never removed.

Timestamped backups are preserved so you can restore previous settings manually. Open a new terminal after removal, or run `exec bash` / `exec zsh`.

## Security notes

- Never commit or share your API key.
- On macOS and Linux, Claude Code's Kimi key is stored in `~/.config/kimi-claude/env.sh` with `600` permissions, and OpenCode's key is stored directly in `~/.bashrc` and `~/.zshrc`. Make sure those files are private and excluded from dotfile repositories, shell-history captures, and support bundles.
- On Windows, Kimi keys are stored as user environment variables. Only your account and administrators can read them, but every process you start inherits them.
- The scripts create plaintext backups that may contain credentials already present in the affected files or variables. Protect or remove those backups when they are no longer needed.
- Revoke and replace the key in the Kimi Code Console or DeepSeek Platform if it is exposed.

## Troubleshooting

### `command not found`

Install Claude Code or OpenCode first, then open a new terminal. The setup scripts configure an existing agent; they do not install it.

### Windows: "running scripts is disabled on this system"

Run the script with `powershell -ExecutionPolicy Bypass -File ...` as shown above. This bypasses the policy for that single invocation only.

### Authentication errors

For Kimi, confirm that the key came from the Kimi Code Console and belongs to an active membership. A Kimi Open Platform key for `api.moonshot.cn` will not work with these endpoints.

For DeepSeek, confirm that `DEEPSEEK_API_KEY` is set in the same environment that starts the coding agent:

```sh
test -n "${DEEPSEEK_API_KEY:-}" && echo "DeepSeek key is available"
```

On Windows, also confirm that Claude Code's token resolved to the key rather than the literal text `%DEEPSEEK_API_KEY%`. If it did not, save `DEEPSEEK_API_KEY` as a user variable as shown in the quick start, then sign out and back in:

```powershell
if ($env:DEEPSEEK_API_KEY) { 'DeepSeek key is available' }
if ($env:ANTHROPIC_AUTH_TOKEN -eq $env:DEEPSEEK_API_KEY) { 'Claude Code token resolves to the key' }
```

### Existing Claude Code settings are invalid

The Claude Code scripts stop rather than overwrite malformed JSON. Fix `~/.claude.json` or `~/.claude/settings.json`, then run the script again.

### The new configuration is not active

On macOS and Linux, reload your shell:

```sh
source ~/.bashrc   # bash
source ~/.zshrc    # zsh
```

On Windows, open a new terminal. Apps such as Windows Terminal and VS Code keep the environment they started with, so close and reopen them.

If an agent was already running, restart it so it inherits the updated environment.

## License

[MIT](LICENSE)
