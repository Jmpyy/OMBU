#!/usr/bin/env python3
"""Lista las aplicaciones gráficas del usuario que están corriendo.

Cruza los procesos del usuario con las entradas .desktop visibles y escribe
un JSON: [{"id", "name", "icon", "pids": [...]}]. Quién tiene o no ventana
se decide del lado de Quickshell.
"""
import json
import os
import shlex
import sys
from pathlib import Path

DIRS = [
    Path.home() / ".local/share/applications",
    Path("/usr/local/share/applications"),
    Path("/usr/share/applications"),
]
# Lanzadores genéricos: no identifican a una app concreta
SKIP_EXEC = {"sh", "bash", "env", "xdg-open", "flatpak", "snap", "uwsm", "systemd-run"}


def parse_desktop(path: Path):
    entry = {}
    in_main = False
    try:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if line.startswith("["):
                in_main = line == "[Desktop Entry]"
                continue
            if in_main and "=" in line and not line.startswith("#"):
                key, _, value = line.partition("=")
                entry.setdefault(key.strip(), value.strip())
    except OSError:
        return None
    return entry


def exec_key(command: str):
    """Nombre del ejecutable que lanza la entrada (sin códigos %U, env, etc.)."""
    try:
        parts = shlex.split(command)
    except ValueError:
        return None
    parts = [p for p in parts if not (p.startswith("%") and len(p) == 2)]
    while parts and (parts[0] == "env" or ("=" in parts[0] and not parts[0].startswith("/"))):
        parts = parts[1:]
    if not parts:
        return None
    key = os.path.basename(parts[0]).lower()
    if key in SKIP_EXEC:
        return None
    # Los accesos directos de juegos de Steam (steam steam://rungameid/...) no son el cliente Steam
    if key == "steam" and any("rungameid" in p for p in parts[1:]):
        return None
    return key


def load_entries():
    """{ejecutable: {id, name, icon}} con el primer .desktop visible de cada uno."""
    by_exec = {}
    seen = set()
    for base in DIRS:
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.desktop")):
            desktop_id = str(path.relative_to(base)).removesuffix(".desktop").replace("/", "-")
            if desktop_id in seen:
                continue
            seen.add(desktop_id)
            data = parse_desktop(path)
            if not data or data.get("Type") != "Application":
                continue
            if data.get("NoDisplay", "").lower() == "true" or data.get("Hidden", "").lower() == "true":
                continue
            if data.get("Terminal", "").lower() == "true":
                continue
            key = exec_key(data.get("Exec", ""))
            if key and key not in by_exec:
                by_exec[key] = {
                    "id": desktop_id,
                    "name": data.get("Name", desktop_id),
                    "icon": data.get("Icon", ""),
                }
    return by_exec


def running_processes():
    """(pid, nombres posibles del ejecutable) de los procesos principales del usuario."""
    uid = os.getuid()
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        proc = Path("/proc") / name
        try:
            if proc.stat().st_uid != uid:
                continue
            argv = proc.joinpath("cmdline").read_bytes().split(b"\0")
            argv = [a.decode(errors="replace") for a in argv if a]
            if not argv:
                continue
            # Los procesos hijos de Electron/Chromium/Firefox no son la app en sí
            # (Electron reescribe su argv, por eso se busca dentro del texto)
            if any("--type=" in a or "-contentproc" in a for a in argv):
                continue
            names = {os.path.basename(argv[0]).lower()}
            try:
                names.add(os.path.basename(os.readlink(proc / "exe")).lower())
            except OSError:
                pass
            # Scripts lanzados con intérprete: python3 /ruta/app.py
            if names & {"python3", "python", "node", "java"} and len(argv) > 1:
                names.add(os.path.basename(argv[1]).lower().removesuffix(".py"))
            yield int(name), names
        except OSError:
            continue


def parent_of(pid: int):
    try:
        stat = Path(f"/proc/{pid}/stat").read_text()
        # El nombre va entre paréntesis y puede tener espacios: se corta después del último ")"
        return int(stat.rsplit(")", 1)[1].split()[1])
    except (OSError, ValueError, IndexError):
        return None


def main():
    entries = load_entries()
    found = {}
    for pid, names in running_processes():
        for n in names:
            entry = entries.get(n)
            if entry:
                found.setdefault(entry["id"], {**entry, "pids": []})["pids"].append(pid)
                break
    apps = sorted(found.values(), key=lambda a: a["name"].lower())
    for app in apps:
        app["pids"].sort()
        # Proceso principal: el que no es hijo de otro de la misma app
        roots = [p for p in app["pids"] if parent_of(p) not in app["pids"]]
        app["main"] = (roots or app["pids"])[0]
    json.dump(apps, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
