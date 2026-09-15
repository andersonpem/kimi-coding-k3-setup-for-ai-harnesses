#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
CONFIG_FILE="${CONFIG_DIR}/opencode.jsonc"
SHELL_RCS=("${HOME}/.bashrc" "${HOME}/.zshrc")

printf "Kimi Code API key: "
IFS= read -rs KIMI_CODE_API_KEY
printf "\n"

if [[ -z "${KIMI_CODE_API_KEY}" ]]; then
    echo "API key cannot be empty."
    exit 1
fi

mkdir -p "${CONFIG_DIR}"

if [[ -f "${CONFIG_FILE}" ]]; then
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
fi

cat > "${CONFIG_FILE}" <<'JSON'
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
JSON

for rc in "${SHELL_RCS[@]}"; do
    touch "${rc}"

    if grep -q '^export KIMI_CODE_API_KEY=' "${rc}"; then
        python3 - "${rc}" "${KIMI_CODE_API_KEY}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
api_key = sys.argv[2]

lines = path.read_text().splitlines()
replacement = f"export KIMI_CODE_API_KEY={api_key!r}"

updated = []
replaced = False

for line in lines:
    if line.startswith("export KIMI_CODE_API_KEY="):
        if not replaced:
            updated.append(replacement)
            replaced = True
    else:
        updated.append(line)

path.write_text("\n".join(updated) + "\n")
PY
    else
        printf '\nexport KIMI_CODE_API_KEY=%q\n' "${KIMI_CODE_API_KEY}" >> "${rc}"
    fi
done

export KIMI_CODE_API_KEY

echo
echo "OpenCode configured for Kimi Code. Default model: kimi-code/k3-256k."
echo "Config: ${CONFIG_FILE}"
echo
echo "Reload your shell:"
echo "  source ~/.bashrc   # bash"
echo "  source ~/.zshrc    # zsh"
echo
echo "Validate:"
echo "  opencode models"
echo
echo "Start Kimi Code:"
echo "  opencode --model kimi-code/k3-256k"