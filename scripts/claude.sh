#!/usr/bin/env bash

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
CLAUDE_JSON="${HOME}/.claude.json"
CLAUDE_SETTINGS="${CLAUDE_DIR}/settings.json"

KIMI_CONFIG_DIR="${HOME}/.config/kimi-claude"
KIMI_ENV_FILE="${KIMI_CONFIG_DIR}/env.sh"

SHELL_RCS=("${HOME}/.bashrc" "${HOME}/.zshrc")

BLOCK_START="# >>> Kimi K3 for Claude Code >>>"
BLOCK_END="# <<< Kimi K3 for Claude Code <<<"

TIMESTAMP="$(date +%Y%m%d%H%M%S)"

printf "Kimi Code API key: "
IFS= read -rs KIMI_CODE_API_KEY
printf "\n"

if [[ -z "${KIMI_CODE_API_KEY}" ]]; then
    echo "API key cannot be empty."
    exit 1
fi

mkdir -p "${CLAUDE_DIR}" "${KIMI_CONFIG_DIR}"

for file in \
    "${CLAUDE_JSON}" \
    "${CLAUDE_SETTINGS}" \
    "${KIMI_ENV_FILE}"
do
    if [[ -f "${file}" ]]; then
        cp "${file}" "${file}.backup.${TIMESTAMP}"
    fi
done

for rc in "${SHELL_RCS[@]}"; do
    touch "${rc}"
    if [[ -f "${rc}" ]]; then
        cp "${rc}" "${rc}.backup.${TIMESTAMP}"
    fi
done

python3 - \
    "${CLAUDE_JSON}" \
    "${CLAUDE_SETTINGS}" \
    "${KIMI_ENV_FILE}" \
    "${KIMI_CODE_API_KEY}" \
    "${BLOCK_START}" \
    "${BLOCK_END}" \
    "${SHELL_RCS[@]}" <<'PY'
import json
import os
import pathlib
import shlex
import sys

(
    claude_json_path,
    settings_path,
    env_path,
    api_key,
    block_start,
    block_end,
) = sys.argv[1:7]

shell_rc_paths = sys.argv[7:]


def read_json_object(path_string: str) -> dict:
    path = pathlib.Path(path_string)

    if not path.exists() or not path.read_text().strip():
        return {}

    try:
        value = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        raise SystemExit(
            f"Invalid JSON in {path}: "
            f"line {error.lineno}, column {error.colno}: {error.msg}"
        )

    if not isinstance(value, dict):
        raise SystemExit(f"Expected a JSON object in {path}")

    return value


def write_json(path_string: str, value: dict) -> None:
    path = pathlib.Path(path_string)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


CONFLICTING_ENV_KEYS = {
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_SMALL_FAST_MODEL",
    "ANTHROPIC_DEFAULT_FABLE_MODEL",
    "ANTHROPIC_DEFAULT_FABLE_MODEL_NAME",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME",
    "CLAUDE_CODE_SUBAGENT_MODEL",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS",
}


def remove_conflicting_env(config: dict) -> None:
    config_env = config.get("env")

    if not isinstance(config_env, dict):
        return

    for key in CONFLICTING_ENV_KEYS:
        config_env.pop(key, None)

    if not config_env:
        config.pop("env", None)


# Skip the normal Anthropic onboarding flow and enable third-party models.
claude_json = read_json_object(claude_json_path)
claude_json["penguinModeOrgEnabled"] = True
claude_json["hasCompletedOnboarding"] = True

# Claude Code also applies the env block from ~/.claude.json. Stale
# provider values there (e.g. ANTHROPIC_AUTH_TOKEN) override the shell
# configuration and trigger a both-auth-methods-set warning.
remove_conflicting_env(claude_json)

write_json(claude_json_path, claude_json)


# Remove stale settings that could override the Kimi shell configuration.
settings = read_json_object(settings_path)
remove_conflicting_env(settings)
write_json(settings_path, settings)


# Store the secret separately from .zshrc.
env_file = pathlib.Path(env_path)
env_file.parent.mkdir(parents=True, exist_ok=True)

quoted_key = shlex.quote(api_key)

env_file.write_text(
    "\n".join(
        [
            "# Kimi K3 configuration for Claude Code.",
            "",
            'export ANTHROPIC_BASE_URL="https://api.kimi.com/coding/"',
            f"export ANTHROPIC_API_KEY={quoted_key}",
            "",
            'export ANTHROPIC_MODEL="k3[1m]"',
            'export ANTHROPIC_DEFAULT_FABLE_MODEL="$ANTHROPIC_MODEL"',
            'export ANTHROPIC_DEFAULT_OPUS_MODEL="$ANTHROPIC_MODEL"',
            'export ANTHROPIC_DEFAULT_SONNET_MODEL="$ANTHROPIC_MODEL"',
            'export ANTHROPIC_DEFAULT_HAIKU_MODEL="$ANTHROPIC_MODEL"',
            'export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"',
            "",
            'export CLAUDE_CODE_AUTO_COMPACT_WINDOW="1048576"',
            'export CLAUDE_CODE_MAX_CONTEXT_TOKENS="1048576"',
            "",
        ]
    )
)

os.chmod(env_file, 0o600)


# Replace the previous managed block in each shell RC.
for shell_rc_path in shell_rc_paths:
    shell_rc = pathlib.Path(shell_rc_path)
    content = shell_rc.read_text() if shell_rc.exists() else ""

    start = content.find(block_start)

    if start != -1:
        end = content.find(block_end, start)

        if end == -1:
            raise SystemExit(
                f"Found {block_start!r} in {shell_rc}, "
                f"but the closing marker is missing."
            )

        end += len(block_end)
        content = content[:start] + content[end:]

    content = content.rstrip()

    managed_block = "\n".join(
        [
            block_start,
            'source "$HOME/.config/kimi-claude/env.sh"',
            block_end,
        ]
    )

    if content:
        content += "\n\n"

    content += managed_block + "\n"
    shell_rc.write_text(content)
PY

chmod 600 "${CLAUDE_JSON}" "${CLAUDE_SETTINGS}" "${KIMI_ENV_FILE}"

unset KIMI_CODE_API_KEY

echo
echo "Claude Code configured for Kimi K3 with 1M context."
echo
echo "Reload your shell:"
echo "  source ~/.bashrc   # bash"
echo "  source ~/.zshrc    # zsh"
echo
echo "Start Claude Code:"
echo "  claude"
echo
echo "Verify inside Claude Code:"
echo "  /status"
echo
echo "The Base URL should be:"
echo "  https://api.kimi.com/coding/"
echo
echo "Change K3 reasoning effort with:"
echo "  /effort"