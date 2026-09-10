#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
CONFIG_FILE="${CONFIG_DIR}/opencode.jsonc"
DEEPSEEK_MODEL="${1:-deepseek-v4-pro}"

case "${DEEPSEEK_MODEL}" in
    deepseek-v4-flash|deepseek-v4-pro|deepseek-v4-flash-vision-exp) ;;
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

mkdir -p "${CONFIG_DIR}"

if [[ -f "${CONFIG_FILE}" ]]; then
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
fi

python3 - "${CONFIG_FILE}" "${DEEPSEEK_MODEL}" <<'PY'
import json
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
default_model = sys.argv[2]


def model(name: str, *, vision: bool = False) -> dict:
    input_modalities = ["text", "image"] if vision else ["text"]

    return {
        "name": name,
        "reasoning": True,
        "tool_call": True,
        "modalities": {"input": input_modalities, "output": ["text"]},
        "limit": {"context": 1048576, "output": 393216},
        "options": {
            "reasoningEffort": "high",
            "thinking": {"type": "enabled"},
        },
        "variants": {
            "none": {"thinking": {"type": "disabled"}},
            "low": {
                "reasoningEffort": "low",
                "thinking": {"type": "enabled"},
            },
            "high": {
                "reasoningEffort": "high",
                "thinking": {"type": "enabled"},
            },
            "max": {
                "reasoningEffort": "max",
                "thinking": {"type": "enabled"},
            },
        },
    }


config = {
    "$schema": "https://opencode.ai/config.json",
    "model": f"deepseek/{default_model}",
    "provider": {
        "deepseek": {
            "npm": "@ai-sdk/openai-compatible",
            "name": "DeepSeek",
            "options": {
                "baseURL": "https://api.deepseek.com",
                "apiKey": "{env:DEEPSEEK_API_KEY}",
            },
            "models": {
                "deepseek-v4-flash": model("DeepSeek V4 Flash"),
                "deepseek-v4-pro": model("DeepSeek V4 Pro"),
                "deepseek-v4-flash-vision-exp": model(
                    "DeepSeek V4 Flash Vision Experimental",
                    vision=True,
                ),
            },
        }
    },
}

config_path.write_text(json.dumps(config, indent=2) + "\n")
PY

echo
echo "OpenCode configured for the DeepSeek V4 family."
echo "Default model: deepseek/${DEEPSEEK_MODEL}"
echo "The API key is read from DEEPSEEK_API_KEY and was not copied to a file."
echo
echo "Validate:"
echo "  opencode models"
echo
echo "Select a model:"
echo "  opencode --model deepseek/deepseek-v4-flash"
echo "  opencode --model deepseek/deepseek-v4-pro"
echo "  opencode --model deepseek/deepseek-v4-flash-vision-exp"
