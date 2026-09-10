#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${HOME}/.config/opencode/opencode.jsonc"
CONFIG_DIR="${HOME}/.config/opencode"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Nothing to remove. DeepSeek V4 for OpenCode does not appear to be installed."
    exit 0
fi

if ! python3 - "${CONFIG_FILE}" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])

try:
    config = json.loads(path.read_text())
except json.JSONDecodeError:
    raise SystemExit(1)

provider = config.get("provider")

if not isinstance(provider, dict) or "deepseek" not in provider:
    raise SystemExit(1)
PY
then
    echo "Refusing to remove ${CONFIG_FILE}: it is not a DeepSeek configuration."
    exit 1
fi

rm "${CONFIG_FILE}"
echo "Removed ${CONFIG_FILE}"

if [[ -d "${CONFIG_DIR}" ]] && [[ -z "$(ls -A "${CONFIG_DIR}" 2>/dev/null)" ]]; then
    rmdir "${CONFIG_DIR}"
fi

echo
echo "DeepSeek V4 integration for OpenCode has been removed."
echo "DEEPSEEK_API_KEY was not changed."
