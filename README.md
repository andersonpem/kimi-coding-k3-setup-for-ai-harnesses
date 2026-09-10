# Kimi K3 and DeepSeek V4 setup for AI coding agents

Small, auditable setup scripts for using [Kimi K3](https://www.kimi.com/code/docs/en/) or [DeepSeek V4](https://api-docs.deepseek.com/) with [Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started) or [OpenCode](https://opencode.ai/en/docs).

The Kimi scripts prompt for the API key without echoing it. The DeepSeek scripts consume `DEEPSEEK_API_KEY` from the environment and never copy its value into generated configuration files.

> [!IMPORTANT]
> These scripts modify files in your home directory and back up configuration files as described below. Review the script you intend to run before executing it.

## Supported agents

| Provider | Agent | Setup | Uninstall | Protocol | Models |
|----------|-------|-------|-----------|----------|--------|
| Kimi | Claude Code | `scripts/claude.sh` | `scripts/claude-uninstall.sh` | Anthropic-compatible | `k3[1m]` |
| Kimi | OpenCode | `scripts/opencode.sh` | `scripts/opencode-uninstall.sh` | OpenAI-compatible | `kimi-code/k3` |
| DeepSeek | Claude Code | `scripts/deepseek-claude.sh` | `scripts/deepseek-claude-uninstall.sh` | Anthropic-compatible | DeepSeek V4 family |
| DeepSeek | OpenCode | `scripts/deepseek-opencode.sh` | `scripts/deepseek-opencode-uninstall.sh` | OpenAI-compatible | DeepSeek V4 family |

## Prerequisites

- macOS or Linux with Bash and/or Zsh
- Python 3
- The coding agent you want to configure: [Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started) or [OpenCode](https://opencode.ai/en/docs)
- An active Kimi Code membership with access to K3 and the 1M context window
- A Kimi Code API key from the [Kimi Code Console](https://www.kimi.com/code/console)
- For DeepSeek, an API key from the [DeepSeek Platform](https://platform.deepseek.com/api_keys) exported as `DEEPSEEK_API_KEY`

Kimi Code keys and Kimi Open Platform keys are not interchangeable. These scripts expect a key for `api.kimi.com`, not a key for `api.moonshot.cn`.

## Quick start

Clone the repository:

```sh
git clone https://github.com/andersonpem/kimi-coding-k3-setup-for-ai-harnesses.git
cd kimi-coding-k3-setup-for-ai-harnesses
```

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

# Claude Code; defaults to deepseek-v4-pro
./scripts/deepseek-claude.sh

# OpenCode; installs the complete family and defaults to deepseek-v4-pro
./scripts/deepseek-opencode.sh
```

Pass a model ID to choose another default:

```sh
./scripts/deepseek-claude.sh deepseek-v4-flash
./scripts/deepseek-opencode.sh deepseek-v4-flash-vision-exp
```

## Claude Code

Run:

```sh
./scripts/claude.sh
source ~/.bashrc   # or: source ~/.zshrc
claude
```

Inside Claude Code, run `/status` and confirm that the base URL is:

```text
https://api.kimi.com/coding/
```

Use `/effort` to change K3's reasoning effort.

### What the Claude Code script changes

- Updates `~/.claude.json` to enable third-party models and mark onboarding complete.
- Removes provider-related environment values (such as `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_BASE_URL`) from `~/.claude.json` and `~/.claude/settings.json` when they would override the Kimi configuration. Leaving a stale `ANTHROPIC_AUTH_TOKEN` in either file triggers Claude Code's "both auth methods set" warning. Other settings are preserved.
- Creates `~/.config/kimi-claude/env.sh`, sets its permissions to `600`, and stores the API endpoint, key, K3 model aliases, and context settings there.
- Adds a marked block to `~/.bashrc` and `~/.zshrc` that loads `env.sh`.
- Creates timestamped backups beside every existing file before changing it.

Re-running the script updates the existing managed block instead of adding a duplicate.

## OpenCode

Run:

```sh
./scripts/opencode.sh
source ~/.bashrc   # or: source ~/.zshrc
opencode models
opencode --model kimi-code/k3
```

The generated OpenCode configuration includes `low`, `high`, and `max` reasoning variants and uses `low` by default.

### What the OpenCode script changes

- Writes `~/.config/opencode/opencode.jsonc` with Kimi Code as the provider and K3 as the default model.
- Adds or updates `KIMI_CODE_API_KEY` in `~/.bashrc` and `~/.zshrc`.
- Creates a timestamped backup of an existing `opencode.jsonc` before replacing it.

> [!WARNING]
> The OpenCode script replaces the complete `opencode.jsonc` file. If you already use other providers or custom OpenCode settings, merge the generated Kimi provider into your configuration manually or restore the backup afterward.

## DeepSeek V4

The DeepSeek scripts configure these API model IDs:

| Model | Input | Context | Maximum output |
|-------|-------|---------|----------------|
| `deepseek-v4-flash` | Text | 1M tokens | 384K tokens |
| `deepseek-v4-pro` | Text | 1M tokens | 384K tokens |
| `deepseek-v4-flash-vision-exp` | Text and images | 1M tokens | 384K tokens |

DeepSeek thinking mode is enabled by default. The OpenCode configuration provides `none`, `low`, `high`, and `max` variants. The vision model is experimental and supports JPEG, PNG, GIF, and WebP input.

Claude Code exposes the family through its model aliases: Opus maps to V4 Pro, Sonnet and Haiku map to V4 Flash, and Fable maps to V4 Flash Vision Experimental. The model argument selects the default. The script uses DeepSeek's Anthropic-compatible endpoint, sets the 1M context limits, and loads the key from `DEEPSEEK_API_KEY` whenever the shell starts.

OpenCode receives all three models in its model picker. The setup script uses the requested model as the default and references `{env:DEEPSEEK_API_KEY}` in `opencode.jsonc`.

> [!WARNING]
> Like the Kimi OpenCode setup, the DeepSeek OpenCode script replaces the complete `opencode.jsonc` file after making a timestamped backup.

## Backups and removal

Backups use the suffix `.backup.YYYYMMDDHHMMSS` and sit next to the original file. For example:

```text
~/.claude.json.backup.20260719123045
~/.config/opencode/opencode.jsonc.backup.20260719123045
```

To uninstall, review and run the matching uninstall script:

```sh
# Claude Code
less scripts/claude-uninstall.sh
./scripts/claude-uninstall.sh

# Or OpenCode
less scripts/opencode-uninstall.sh
./scripts/opencode-uninstall.sh

# DeepSeek for Claude Code
less scripts/deepseek-claude-uninstall.sh
./scripts/deepseek-claude-uninstall.sh

# DeepSeek for OpenCode
less scripts/deepseek-opencode-uninstall.sh
./scripts/deepseek-opencode-uninstall.sh
```

Each uninstall script removes the configuration added by the corresponding setup script. Timestamped backups are preserved so you can restore previous settings manually if needed.

Open a new terminal after removal, or run `exec bash` / `exec zsh`.

## Security notes

- Never commit or share your API key.
- Claude Code's key is stored in `~/.config/kimi-claude/env.sh` with `600` permissions.
- OpenCode's key is stored directly in `~/.bashrc` and `~/.zshrc`. Make sure those files are private and excluded from dotfile repositories, shell-history captures, and support bundles.
- The DeepSeek scripts do not store the key. `DEEPSEEK_API_KEY` must be present in the environment that starts Claude Code or OpenCode.
- The scripts create plaintext backups that may contain credentials already present in the affected files. Protect or remove those backups when they are no longer needed.
- Revoke and replace the key in the Kimi Code Console if it is exposed.

## Troubleshooting

### `command not found`

Install Claude Code or OpenCode first, then open a new terminal. The setup scripts configure an existing agent; they do not install it.

### Authentication errors

For Kimi, confirm that the key came from the Kimi Code Console and belongs to an active membership. A Kimi Open Platform key for `api.moonshot.cn` will not work with these endpoints.

For DeepSeek, confirm that `DEEPSEEK_API_KEY` is exported in the same environment that starts the coding agent:

```sh
test -n "${DEEPSEEK_API_KEY:-}" && echo "DeepSeek key is available"
```

### Existing Claude Code settings are invalid

The Claude script stops rather than overwrite malformed JSON. Fix `~/.claude.json` or `~/.claude/settings.json`, then run it again.

### The new configuration is not active

Reload your shell:

```sh
source ~/.bashrc   # bash
source ~/.zshrc    # zsh
```

If an agent was already running, restart it so it inherits the updated environment.

## License

[MIT](LICENSE)
