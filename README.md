# Kimi K3 setup for AI coding agents

Small, auditable setup scripts for using [Kimi K3](https://www.kimi.com/code/docs/en/) with [Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started) or [OpenCode](https://opencode.ai/en/docs).

The scripts configure the Kimi Code API, select the `k3` model, enable its 1M-token context window, and prompt for the API key without echoing it to the terminal.

> [!IMPORTANT]
> These scripts modify files in your home directory and back up configuration files as described below. Review the script you intend to run before executing it.

## Supported agents

| Agent       | Script                | Protocol             | Model          |
|-------------|-----------------------|----------------------|----------------|
| Claude Code | `scripts/claude.sh`   | Anthropic-compatible | `k3[1m]`       |
| OpenCode    | `scripts/opencode.sh` | OpenAI-compatible    | `kimi-code/k3` |

## Prerequisites

- macOS or Linux with Bash and Zsh
- Python 3
- The coding agent you want to configure: [Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started) or [OpenCode](https://opencode.ai/en/docs)
- An active Kimi Code membership with access to K3 and the 1M context window
- A Kimi Code API key from the [Kimi Code Console](https://www.kimi.com/code/console)

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
source ~/.zshrc
```

## Claude Code

Run:

```sh
./scripts/claude.sh
source ~/.zshrc
claude
```

Inside Claude Code, run `/status` and confirm that the base URL is:

```text
https://api.kimi.com/coding/
```

Use `/effort` to change K3's reasoning effort.

### What the Claude Code script changes

- Updates `~/.claude.json` to enable third-party models and mark onboarding complete.
- Removes provider-related environment values from `~/.claude/settings.json` when they would override the Kimi configuration. Other settings are preserved.
- Creates `~/.config/kimi-claude/env.zsh`, sets its permissions to `600`, and stores the API endpoint, key, K3 model aliases, and context settings there.
- Adds a marked block to `~/.zshrc` that loads `env.zsh`.
- Creates timestamped backups beside every existing file before changing it.

Re-running the script updates the existing managed block instead of adding a duplicate.

## OpenCode

Run:

```sh
./scripts/opencode.sh
source ~/.zshrc
opencode models
opencode --model kimi-code/k3
```

The generated OpenCode configuration includes `low`, `high`, and `max` reasoning variants and uses `max` by default.

### What the OpenCode script changes

- Writes `~/.config/opencode/opencode.jsonc` with Kimi Code as the provider and K3 as the default model.
- Adds or updates `KIMI_CODE_API_KEY` in `~/.zshrc`.
- Creates a timestamped backup of an existing `opencode.jsonc` before replacing it.

> [!WARNING]
> The OpenCode script replaces the complete `opencode.jsonc` file. If you already use other providers or custom OpenCode settings, merge the generated Kimi provider into your configuration manually or restore the backup afterward.

## Backups and removal

Backups use the suffix `.backup.YYYYMMDDHHMMSS` and sit next to the original file. For example:

```text
~/.claude.json.backup.20260719123045
~/.config/opencode/opencode.jsonc.backup.20260719123045
```

To remove the Claude Code integration:

1. Delete the block between `# >>> Kimi K3 for Claude Code >>>` and `# <<< Kimi K3 for Claude Code <<<` in `~/.zshrc`.
2. Delete `~/.config/kimi-claude/env.zsh`.
3. Restore the desired timestamped backups of `~/.claude.json` and `~/.claude/settings.json`, if needed.

To remove the OpenCode integration:

1. Delete the `export KIMI_CODE_API_KEY=...` line from `~/.zshrc`.
2. Restore a timestamped `opencode.jsonc` backup, or remove the Kimi provider from the current file.

Open a new terminal after removal, or run `exec zsh`.

## Security notes

- Never commit or share your API key.
- Claude Code's key is stored in `~/.config/kimi-claude/env.zsh` with `600` permissions.
- OpenCode's key is stored directly in `~/.zshrc`. Make sure that file is private and excluded from dotfile repositories, shell-history captures, and support bundles.
- The scripts create plaintext backups that may contain credentials already present in the affected files. Protect or remove those backups when they are no longer needed.
- Revoke and replace the key in the Kimi Code Console if it is exposed.

## Troubleshooting

### `command not found`

Install Claude Code or OpenCode first, then open a new terminal. The setup scripts configure an existing agent; they do not install it.

### Authentication errors

Confirm that the key came from the Kimi Code Console and belongs to an active membership. A Kimi Open Platform key for `api.moonshot.cn` will not work with these endpoints.

### Existing Claude Code settings are invalid

The Claude script stops rather than overwrite malformed JSON. Fix `~/.claude.json` or `~/.claude/settings.json`, then run it again.

### The new configuration is not active

Reload Zsh:

```sh
source ~/.zshrc
```

If an agent was already running, restart it so it inherits the updated environment.

## License

[MIT](LICENSE)
