#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${HOME}/.config/opencode/opencode.jsonc"
CONFIG_DIR="${HOME}/.config/opencode"

SHELL_RCS=("${HOME}/.bashrc" "${HOME}/.zshrc")

changed=0

for rc in "${SHELL_RCS[@]}"; do
    [[ -f "${rc}" ]] || continue

    if python3 - "${rc}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text().splitlines()
filtered = [line for line in lines if not line.startswith("export KIMI_CODE_API_KEY=")]

if len(filtered) == len(lines):
    raise SystemExit(1)

while filtered and not filtered[-1]:
    filtered.pop()

path.write_text("\n".join(filtered) + "\n" if filtered else "")
PY
    then
        echo "Removed KIMI_CODE_API_KEY from ${rc}"
        changed=1
    fi
done

if [[ -f "${CONFIG_FILE}" ]]; then
    rm "${CONFIG_FILE}"
    echo "Removed ${CONFIG_FILE}"
    changed=1
fi

if [[ -d "${CONFIG_DIR}" ]] \
    && [[ -z "$(ls -A "${CONFIG_DIR}" 2>/dev/null)" ]]; then
    rmdir "${CONFIG_DIR}"
    echo "Removed empty ${CONFIG_DIR}/"
fi

if [[ "${changed}" -eq 0 ]]; then
    echo "Nothing to remove. Kimi K3 for OpenCode does not appear to be installed."
    exit 0
fi

echo
echo "Kimi K3 integration for OpenCode has been removed."
echo
echo "Reload your shell:"
echo "  source ~/.bashrc   # bash"
echo "  source ~/.zshrc    # zsh"
echo
echo "To restore a previous OpenCode configuration, copy the desired backup:"
echo "  ls -t ~/.config/opencode/opencode.jsonc.backup.*"
