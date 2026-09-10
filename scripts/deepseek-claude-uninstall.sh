#!/usr/bin/env bash

set -euo pipefail

DEEPSEEK_ENV_FILE="${HOME}/.config/deepseek-claude/env.sh"
DEEPSEEK_CONFIG_DIR="${HOME}/.config/deepseek-claude"
SHELL_RCS=("${HOME}/.bashrc" "${HOME}/.zshrc")

BLOCK_START="# >>> DeepSeek V4 for Claude Code >>>"
BLOCK_END="# <<< DeepSeek V4 for Claude Code <<<"

changed=0

for rc in "${SHELL_RCS[@]}"; do
    [[ -f "${rc}" ]] || continue

    if python3 - "${rc}" "${BLOCK_START}" "${BLOCK_END}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
block_start = sys.argv[2]
block_end = sys.argv[3]
text = path.read_text()
start = text.find(block_start)

if start == -1:
    raise SystemExit(1)

end = text.find(block_end, start)

if end == -1:
    print(f"Warning: opening marker in {path} but closing marker missing.", file=sys.stderr)
    raise SystemExit(2)

end += len(block_end)
before = text[:start].rstrip("\n")
after = text[end:].lstrip("\n")

if before and after:
    result = before + "\n\n" + after
elif before:
    result = before + "\n"
elif after:
    result = after
else:
    result = ""

path.write_text(result)
PY
    then
        echo "Removed managed block from ${rc}"
        changed=1
    fi
done

if [[ -f "${DEEPSEEK_ENV_FILE}" ]]; then
    rm "${DEEPSEEK_ENV_FILE}"
    echo "Removed ${DEEPSEEK_ENV_FILE}"
    changed=1
fi

if [[ -d "${DEEPSEEK_CONFIG_DIR}" ]] \
    && [[ -z "$(ls -A "${DEEPSEEK_CONFIG_DIR}" 2>/dev/null)" ]]; then
    rmdir "${DEEPSEEK_CONFIG_DIR}"
fi

if [[ "${changed}" -eq 0 ]]; then
    echo "Nothing to remove. DeepSeek V4 for Claude Code does not appear to be installed."
    exit 0
fi

echo
echo "DeepSeek V4 integration for Claude Code has been removed."
echo "DEEPSEEK_API_KEY was not changed."
