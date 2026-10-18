#!/usr/bin/env bash
# Hook de permisos de Claude Code (PermissionRequest) y Antigravity (PreToolUse): ver agent-confirm.py.
# Uso: agent-confirm.sh claude|agy
exec python3 -I "$(dirname "$(readlink -f "$0")")/agent-confirm.py" "${1:-agy}"
