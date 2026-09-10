#!/usr/bin/env bash

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
CLAUDE_JSON="${HOME}/.claude.json"
CLAUDE_SETTINGS="${CLAUDE_DIR}/settings.json"

DEEPSEEK_CONFIG_DIR="${HOME}/.config/deepseek-claude"
DEEPSEEK_ENV_FILE="${DEEPSEEK_CONFIG_DIR}/env.sh"

SHELL_RCS=("${HOME}/.bashrc" "${HOME}/.zshrc")

BLOCK_START="# >>> DeepSeek V4 for Claude Code >>>"
BLOCK_END="# <<< DeepSeek V4 for Claude Code <<<"

TIMESTAMP="$(date +%Y%m%d%H%M%S)"
DEEPSEEK_MODEL="${1:-deepseek-v4-pro}"

case "${DEEPSEEK_MODEL}" in
    deepseek-v4-flash|deepseek-v4-pro)
        CLAUDE_MODEL="${DEEPSEEK_MODEL}[1m]"
        ;;
    deepseek-v4-flash-vision-exp)
        CLAUDE_MODEL="${DEEPSEEK_MODEL}"
        ;;
    *)
        echo "Unsupported DeepSeek model: ${DEEPSEEK_MODEL}"
        echo "Choose deepseek-v4-flash, deepseek-v4-pro, or deepseek-v4-flash-vision-exp."
        exit 1
        ;;
esac

if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    echo "DEEPSEEK_API_KEY is not set in the environment."
    exit 1
fi

mkdir -p "${CLAUDE_DIR}" "${DEEPSEEK_CONFIG_DIR}"

for file in \
    "${CLAUDE_JSON}" \
    "${CLAUDE_SETTINGS}" \
    "${DEEPSEEK_ENV_FILE}"
do
    if [[ -f "${file}" ]]; then
        cp "${file}" "${file}.backup.${TIMESTAMP}"
    fi
done

for rc in "${SHELL_RCS[@]}"; do
    touch "${rc}"
    cp "${rc}" "${rc}.backup.${TIMESTAMP}"
done

python3 - \
    "${CLAUDE_JSON}" \
    "${CLAUDE_SETTINGS}" \
    "${DEEPSEEK_ENV_FILE}" \
    "${CLAUDE_MODEL}" \
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
    model,
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
    "CLAUDE_CODE_EFFORT_LEVEL",
}


def remove_conflicting_env(config: dict) -> None:
    config_env = config.get("env")

    if not isinstance(config_env, dict):
        return

    for key in CONFLICTING_ENV_KEYS:
        config_env.pop(key, None)

    if not config_env:
        config.pop("env", None)


claude_json = read_json_object(claude_json_path)
claude_json["penguinModeOrgEnabled"] = True
claude_json["hasCompletedOnboarding"] = True
remove_conflicting_env(claude_json)
write_json(claude_json_path, claude_json)

settings = read_json_object(settings_path)
remove_conflicting_env(settings)
write_json(settings_path, settings)

env_file = pathlib.Path(env_path)
env_file.parent.mkdir(parents=True, exist_ok=True)
quoted_model = shlex.quote(model)

env_file.write_text(
    "\n".join(
        [
            "# DeepSeek V4 configuration for Claude Code.",
            "# DEEPSEEK_API_KEY must be supplied by the parent environment.",
            "",
            'export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"',
            'export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY:-}"',
            "",
            f"export ANTHROPIC_MODEL={quoted_model}",
            'export ANTHROPIC_DEFAULT_FABLE_MODEL="$ANTHROPIC_MODEL"',
            'export ANTHROPIC_DEFAULT_OPUS_MODEL="$ANTHROPIC_MODEL"',
            'export ANTHROPIC_DEFAULT_SONNET_MODEL="$ANTHROPIC_MODEL"',
            'export ANTHROPIC_DEFAULT_HAIKU_MODEL="$ANTHROPIC_MODEL"',
            'export CLAUDE_CODE_SUBAGENT_MODEL="$ANTHROPIC_MODEL"',
            "",
            'export CLAUDE_CODE_EFFORT_LEVEL="max"',
            'export CLAUDE_CODE_AUTO_COMPACT_WINDOW="786432"',
            'export CLAUDE_CODE_MAX_CONTEXT_TOKENS="1048576"',
            "",
        ]
    )
)

os.chmod(env_file, 0o600)

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
            'source "$HOME/.config/deepseek-claude/env.sh"',
            block_end,
        ]
    )

    if content:
        content += "\n\n"

    shell_rc.write_text(content + managed_block + "\n")
PY

chmod 600 "${CLAUDE_JSON}" "${CLAUDE_SETTINGS}" "${DEEPSEEK_ENV_FILE}"

echo
echo "Claude Code configured for ${DEEPSEEK_MODEL}."
echo "The API key remains in DEEPSEEK_API_KEY and was not copied to a file."
echo
echo "Reload your shell, then start Claude Code:"
echo "  source ~/.bashrc   # bash"
echo "  source ~/.zshrc    # zsh"
echo "  claude"
echo
echo "Verify that /status shows this Base URL:"
echo "  https://api.deepseek.com/anthropic"
