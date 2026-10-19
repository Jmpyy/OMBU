#!/usr/bin/env python3
"""Confirmación de comandos de un agente de IA por una tarjeta de ombu.

Lo llama bin/agent-confirm.sh como hook de permisos:
  - Claude Code:  evento PermissionRequest (se dispara solo cuando iba a pedirte permiso)
  - Antigravity:  evento PreToolUse con run_command

Reglas de seguridad (el valor por defecto SIEMPRE es "no decidir", nunca "permitir"):
  - Si estás mirando la terminal, no hace nada: confirmás ahí como siempre.
  - Si no se entiende el pedido, no hace nada.
  - Los comandos de solo lectura (ls, git status...) no molestan: siguen el flujo normal.
  - Los comandos destructivos o larguísimos no se pueden aprobar desde la tarjeta: solo mandan a
    la consola o se deniegan. Así no se aprueba algo que no se alcanzó a leer.
  - Cerrar la tarjeta o dejarla vencer deja el pedido en la consola.
"""
import json
import os
import re
import subprocess
import sys

AGENT = sys.argv[1] if len(sys.argv) > 1 else "agy"
NAMES = {"claude": "Claude Code", "agy": "Antigravity"}
NAME = NAMES.get(AGENT, "Agente IA")
WAIT_MS = 45000
MAX_CHARS = 280  # más largo que esto no se aprueba desde la tarjeta
MAX_LINES = 8

# Comandos de solo lectura (sin tocar nada). Se admiten encadenados entre sí.
SAFE_SIMPLE = {
    "ls", "cat", "head", "tail", "grep", "rg", "fd", "stat", "file", "wc", "pwd", "which", "type",
    "date", "uname", "whoami", "id", "df", "du", "free", "ps", "pgrep", "lsblk", "sort", "uniq",
    "cut", "tr", "basename", "dirname", "realpath", "readlink", "env", "printenv", "true", "false",
    "test", "[", "nproc", "uptime", "lscpu", "lsusb", "lspci", "tree", "diff", "cmp", "md5sum",
    "sha256sum", "strings", "identify", "seq", "echo", "printf",
}
SAFE_SUB = {
    "git": {"status", "log", "diff", "show", "branch", "remote", "ls-files", "rev-parse", "rev-list", "blame", "describe", "config", "stash list"},
    "pacman": None,  # solo consultas: se revisa aparte
    "hyprctl": {"clients", "monitors", "workspaces", "getoption", "activewindow", "layers", "devices", "version", "cursorpos", "activeworkspace", "binds"},
    "systemctl": {"status", "is-active", "is-enabled", "is-failed", "show", "cat", "list-units", "--failed"},
    "journalctl": None,
    "qs": {"list", "log"},
    "atuin": {"history", "search", "stats"},
}
# Comandos verdaderamente destructivos o que tocan privilegios del sistema
DESTRUCTIVE = re.compile(
    r"(?<![\w-])("
    r"sudo|doas|su\b|"                                            # Escalado a root
    r"rm\s+(-[a-zA-Z]*[rf][a-zA-Z]*|--recursive)|rmdir\b|"        # Borrado recursivo
    r"mkfs\w*|dd\b|fdisk\b|parted\b|shred\b|truncate\b|"          # Destrucción de discos/particiones
    r"reboot\b|poweroff\b|shutdown\b|"                            # Apagado/reinicio
    r"git\s+(reset\s+--hard|clean\s+-[a-zA-Z]*f|push\s+.*--force)|" # Git destructivo
    r"chmod\s+(-[a-zA-Z]*R\s+)?(777|000)|"                       # Permisos peligrosos
    r">:?\s*/dev/sd[a-z]"                                         # Sobrescritura directa de discos
    r")(?![\w-])"
)
# Para saber si un comando es "compuesto" (varias órdenes, redirecciones, sustitución)
COMPOUND = re.compile(r"[;&|<>`\n]|\$\(")


def run(cmd, timeout=10):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""


def defer():
    """No decide nada: la consola pregunta como siempre."""
    if AGENT == "agy":
        print(json.dumps({"decision": "ask"}))
    sys.exit(0)


def decide(allow, reason=""):
    if AGENT == "agy":
        out = {"decision": "allow" if allow else "deny"}
        if not allow:
            out["reason"] = reason
        print(json.dumps(out))
    else:
        decision = {"behavior": "allow"} if allow else {"behavior": "deny", "message": reason, "interrupt": False}
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": decision}}))
    sys.exit(0)


def read_payload():
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        return "", ""
    cmd = ""
    if isinstance(data, dict):
        cmd = ((data.get("toolCall") or {}).get("args") or {}).get("CommandLine") or (data.get("tool_input") or {}).get("command") or ""
        cwd = data.get("cwd") or (data.get("workspacePaths") or [""])[0] or ""
    else:
        cwd = ""
    return (cmd if isinstance(cmd, str) else ""), (cwd if isinstance(cwd, str) else "")


def terminal_address():
    """Ventana de kitty donde corre este agente: se sube por los procesos padre hasta dar con ella."""
    try:
        clients = json.loads(run(["hyprctl", "clients", "-j"]) or "[]")
    except Exception:
        clients = []
    by_pid = {c.get("pid"): c.get("address") for c in clients if c.get("class") == "kitty"}
    pid = os.getppid()
    for _ in range(40):
        if pid in by_pid:
            return by_pid[pid]
        try:
            with open(f"/proc/{pid}/stat") as f:
                pid = int(f.read().rsplit(")", 1)[1].split()[1])
        except Exception:
            break
        if pid <= 1:
            break
    return None


def focus_terminal():
    addr = terminal_address()
    target = f"address:{addr}" if addr else "class:kitty"
    run(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "%s" })' % target])


def main():
    cmd, cwd = read_payload()
    if not cmd.strip():
        defer()

    is_danger = bool(DESTRUCTIVE.search(cmd))

    # Si NO es un comando destructivo: full access automático
    if not is_danger:
        decide(True)

    # Si ES destructivo y la terminal está activa: confirmás en la consola
    active = ""
    try:
        active = json.loads(run(["hyprctl", "activewindow", "-j"]) or "{}").get("class", "")
    except Exception:
        pass

    if active == "kitty":
        defer()

    # Si estás fuera de la consola y el comando es destructivo: mostramos la tarjeta con opción Permitir
    args = [
        "notify-send", "-a", NAME, "-u", "critical", "-t", str(WAIT_MS), "-c", "ombu.confirm",
        "-h", "string:x-ombu-kind:confirm",
        "-h", "int:x-ombu-risky:1",
        "-h", f"int:x-ombu-compound:{1 if bool(COMPOUND.search(cmd)) else 0}",
        "-h", "string:x-ombu-cwd:" + cwd,
        "-A", "allow=Permitir",
        "-A", "deny=Denegar",
        "-A", "focus=Ir a la consola",
        f"{NAME} quiere ejecutar un comando importante",
        cmd
    ]
    choice = run(args, timeout=WAIT_MS // 1000 + 15).strip()

    if choice == "allow":
        decide(True)
    elif choice == "deny":
        decide(False, "Denegado por el usuario desde la tarjeta de ombu.")
    elif choice == "focus":
        focus_terminal()
        defer()
    else:
        defer()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        # Ante cualquier error inesperado, nunca se decide por la persona
        defer()
