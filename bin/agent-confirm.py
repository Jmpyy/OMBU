#!/usr/bin/env python3
"""Confirmación de comandos de un agente de IA por una tarjeta de ombu.

Lo llama bin/agent-confirm.sh como hook de permisos:
  - Claude Code:  evento PermissionRequest (se dispara solo cuando iba a pedirte permiso)
  - Antigravity:  evento PreToolUse con run_command

Reglas de seguridad (el valor por defecto SIEMPRE es "no decidir", nunca "permitir"):
  - Si estás mirando la terminal, no hace nada: confirmás ahí como siempre.
  - Si no se entiende el pedido, no hace nada.
  - Lo conocido y seguro se aprueba solo (lectura, `git add/commit`, compilar con gcc/make/cmake, valgrind
    sobre un programa del proyecto). Es una LISTA PERMITIDA: lo que no está en ella nunca se aprueba solo.
    Cualquier redirección, sustitución, fondo (&) o varias líneas la descarta entera.
  - Los comandos destructivos o larguísimos no se pueden aprobar desde la tarjeta: solo mandan a
    la consola o se deniegan. Así no se aprueba algo que no se alcanzó a leer.
  - Cerrar la tarjeta o dejarla vencer deja el pedido en la consola.
"""
import json
import os
import re
import shlex
import subprocess
import sys

AGENT = sys.argv[1] if len(sys.argv) > 1 else "agy"
NAMES = {"claude": "Claude Code", "agy": "Antigravity"}
NAME = NAMES.get(AGENT, "Agente IA")
WAIT_MS = 45000
MAX_CHARS = 280  # más largo que esto no se aprueba desde la tarjeta
MAX_LINES = 8

# Comandos de solo lectura (sin tocar nada). Se admiten encadenados entre sí. Ojo con lo que NO está:
# `env` y `xargs` ejecutan otros comandos; `tee`, `sed -i`, `cp`, `mv` escriben.
SAFE_SIMPLE = {
    "ls", "cat", "head", "tail", "grep", "rg", "fd", "stat", "file", "wc", "pwd", "which", "type",
    "date", "uname", "whoami", "id", "df", "du", "free", "ps", "pgrep", "lsblk", "sort",
    "cut", "tr", "basename", "dirname", "realpath", "readlink", "printenv", "true", "false",
    "test", "[", "nproc", "uptime", "lscpu", "lsusb", "lspci", "tree", "diff", "cmp", "md5sum",
    "sha256sum", "strings", "seq", "echo", "printf", "cd",
}
# Banderas que ejecutan otro programa o escriben un archivo aunque el comando sea «de lectura»
RISKY_FLAGS = {
    "fd": {"short": "xX", "long": ("--exec", "--exec-batch")},
    "rg": {"short": "", "long": ("--pre", "--pre-glob")},
    "sort": {"short": "o", "long": ("--output", "--compress-program")},
    "tree": {"short": "o", "long": ("--output",)},
    "file": {"short": "C", "long": ("--compile",)},
}
# Comandos a los que un comodín no les puede hacer daño aunque un archivo se llame «-x» o «--pre=sh»
# (bash lo expandiría a una bandera). Al resto, un comodín sin comillas los descarta.
GLOB_OK = {"ls", "cat", "head", "tail", "wc", "stat", "du", "grep", "md5sum", "sha256sum", "strings", "echo", "printf"}
# El subcomando tiene que ir primero: una opción con valor delante cambia cuál es el verbo de verdad
# (`systemctl -p status poweroff` apaga la PC). Solo se saltean estas banderas sin valor.
SAFE_SUB = {
    "hyprctl": {"clients", "monitors", "workspaces", "getoption", "activewindow", "layers", "devices", "version", "cursorpos", "activeworkspace", "binds"},
    "systemctl": {"status", "is-active", "is-enabled", "is-failed", "show", "cat", "list-units", "--failed"},
    "atuin": {"history", "search", "stats"},
}
SUB_NOVALUE = {
    "hyprctl": {"-j", "--json"},
    "systemctl": {"--user", "--system", "--no-pager"},
    "atuin": set(),
}
# Variables que se pueden nombrar (no traen espacios ni guiones al principio)
SAFE_VARS = re.compile(r"\$(HOME|USER|PWD)\b|\$\{(HOME|USER|PWD)\}")
GIT_READ = {"status", "log", "diff", "show", "ls-files", "rev-parse", "rev-list", "blame", "describe"}
GIT_WRITE = {"add", "commit"}  # al índice y al historial local; nada que salga de la máquina
BRANCH_OK = {"-a", "-r", "-v", "-vv", "--list", "--show-current", "--merged", "--no-merged", "--all", "--remotes"}
CONFIG_OK = {"--get", "--get-all", "--get-regexp", "--list", "-l"}
COMPILERS = {"gcc", "cc", "g++", "c++", "clang", "clang++"}
MAKE_TARGETS = {"all", "clean", "test", "tests", "check", "leaks", "debug", "release", "run"}
PROJECT_PREFIXES = ("./", "build/", "bin/")  # programas del proyecto (valgrind)
# Palabras que vuelven un comando "destructivo": no se aprueban desde la tarjeta
RISKY = re.compile(
    r"(?<![\w-])(sudo|doas|su|rm|rmdir|dd|mkfs\w*|shred|truncate|chmod|chown|mv|kill|pkill|killall|"
    r"eval|exec|reboot|poweroff|shutdown|pacman|paru|yay|systemctl|crontab|mount|umount|"
    r"git\s+(push|reset|clean|rebase|checkout\s+--)|gio\s+trash|find\b.*(-delete|-exec|-ok))(?![\w-])"
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


def has_risky_flag(first, words):
    spec = RISKY_FLAGS.get(first)
    if not spec:
        return False
    for w in words[1:]:
        if w.startswith("--"):
            if any(w == f or w.startswith(f + "=") for f in spec["long"]):
                return True
        elif w.startswith("-") and any(ch in w[1:] for ch in spec["short"]):
            return True
    return False


def git_safe(words):
    i = 1
    while i < len(words) and words[i].startswith("-"):
        if words[i] == "-C":
            i += 2
        elif words[i] in ("--no-pager", "-P", "--no-optional-locks"):
            i += 1
        else:
            return False  # -c k=v puede ejecutar programas (pager, ssh...)
    if i >= len(words):
        return False
    sub, rest = words[i], words[i + 1:]
    if sub in GIT_READ:
        return not any(w.startswith(("--output", "--ext-diff")) for w in rest)
    if sub in GIT_WRITE:
        return True
    if sub == "branch":
        return all(w in BRANCH_OK for w in rest)
    if sub == "remote":
        return rest in ([], ["-v"])
    if sub == "config":
        return bool(rest) and rest[0] in CONFIG_OK
    if sub == "stash":
        return rest[:1] == ["list"]
    return False


def out_path_ok(p):
    return not (p.startswith(("/", "~")) or "$" in p or ".." in p.split("/"))


# Opciones del compilador cuyo valor es un archivo que se escribe (separado o pegado: -o x / -ox)
COMPILER_OUT = ("-o", "-MF", "-MJ", "-dumpdir")


def compiler_safe(words):
    for k, w in enumerate(words[1:], 1):
        # Plugins, otros programas, archivos de opciones (@args) y opciones para el enlazador o el
        # ensamblador (-Wl,-o,/ruta escribe donde quiera; -Wl,--plugin carga código)
        if w.startswith(("-fplugin", "-specs", "--specs", "-wrapper", "-B", "-fuse-ld", "-X", "@")) or re.match(r"-W[alp],", w):
            return False
        if w in COMPILER_OUT or w == "--output":
            if k + 1 >= len(words) or not out_path_ok(words[k + 1]):
                return False
        elif w.startswith("--output="):
            if not out_path_ok(w.split("=", 1)[1]):
                return False
        else:
            for opt in COMPILER_OUT:
                if w.startswith(opt) and len(w) > len(opt) and not out_path_ok(w[len(opt):]):
                    return False
    return True


def make_safe(words):
    for w in words[1:]:
        if w.startswith("-"):
            if not re.fullmatch(r"-(j\d*|s|k|n|B)", w):
                return False  # -f, -C, --eval... cambian qué se ejecuta
        elif "=" in w or w not in MAKE_TARGETS:
            return False
    return True


def options_safe(words, with_value, plain, positional_ok=True):
    """Solo opciones conocidas: `with_value` llevan un valor (separado o pegado, -j4), `plain` no.
    Cualquier otra (o `--`, que le pasa el resto a otro programa) descarta el comando."""
    k = 1
    while k < len(words):
        w = words[k]
        if w in plain:
            k += 1
        elif w in with_value:
            k += 2
        elif any(w.startswith(o) and len(w) > len(o) and (len(o) == 2 or w[len(o)] == "=") for o in with_value):
            k += 1
        elif w.startswith("-") or not positional_ok:
            return False
        else:
            k += 1
    return True


CMAKE_VARS_OK = {"CMAKE_BUILD_TYPE", "CMAKE_EXPORT_COMPILE_COMMANDS"}


def cmake_safe(words):
    # -E (rm, copy...), -P (scripts), --install, --graphviz=archivo, `--build x -- --eval=...` y las
    # variables CMAKE_* (CMAKE_C_COMPILER_LAUNCHER=poweroff) quedan afuera
    for k, w in enumerate(words):
        define = w[2:] if w.startswith("-D") else (words[k + 1] if w == "-D" and k + 1 < len(words) else None)
        if define is not None:
            key = define.split("=", 1)[0].split(":", 1)[0]
            if "=" not in define or (key.startswith("CMAKE_") and key not in CMAKE_VARS_OK):
                return False
        if w in ("-B",) and (k + 1 >= len(words) or not out_path_ok(words[k + 1])):
            return False
        if w.startswith("-B") and len(w) > 2 and not out_path_ok(w[2:]):
            return False
    return options_safe(words, ("-S", "-B", "-G", "-D", "--build", "--target", "-t", "--config", "-j", "--parallel"),
                        ("--clean-first", "-v", "--verbose", "--fresh", "-Wdev", "-Wno-dev"))


def ctest_safe(words):
    # Sin -S (scripts) ni --build-and-test ... --test-command (ejecuta lo que sea)
    return options_safe(words, ("--test-dir", "-R", "-E", "-L", "-LE", "-j", "--parallel", "-C", "--timeout", "-I"),
                        ("--output-on-failure", "-V", "-VV", "-N", "--rerun-failed", "--stop-on-failure", "-Q", "--progress"),
                        positional_ok=False)


def valgrind_safe(words):
    # --log-file=/ruta, --xml-file, --vgdb-prefix... escriben donde quieran; --db-command ejecuta
    if any(re.match(r"--[\w-]*(file|prefix|command|socket)", w) for w in words[1:]):
        return False
    prog = [w for w in words[1:] if not w.startswith("-")]
    return bool(prog) and prog[0].startswith(PROJECT_PREFIXES) and ".." not in prog[0].split("/")


def sub_safe(first, words):
    allowed = SAFE_SUB[first]
    i = 1
    while i < len(words) and words[i] in SUB_NOVALUE[first]:
        i += 1
    if i >= len(words) or words[i] not in allowed:
        return False
    verb, rest = words[i], words[i + 1:]
    # hyprctl también lee banderas después del verbo (`hyprctl clients --batch "dispatch ..."`)
    if first == "hyprctl":
        return all(not w.startswith("-") or w in SUB_NOVALUE["hyprctl"] for w in rest)
    if first == "atuin":
        if any(w.startswith("--delete") for w in rest):
            return False
        return verb != "history" or rest[:1] == ["list"]
    return True


def shell_tricks(token):
    """Lo que bash transforma antes de ejecutar y podría fabricar una bandera escondida: barras
    (\\-x), $'\\x2dx', ${A:--x}, llaves {-x,rm}. Devuelve (hay_truco, hay_comodín_sin_comillas)."""
    if "\\" in token:
        return True, False
    quote, globs = "", False
    for ch in SAFE_VARS.sub("", token):
        if quote == "'":
            if ch == "'":
                quote = ""
            continue
        if ch == '"':
            quote = "" if quote else '"'
        elif ch == "$":
            return True, globs
        elif not quote:
            if ch == "'":
                quote = "'"
            elif ch in "{}":
                return True, globs
            elif ch in "*?[":
                globs = True
    return quote != "", globs


def is_safe_segment(tokens):
    if not tokens:
        return True
    words = []
    globs = False
    for tok in tokens:
        trick, glob = shell_tricks(tok)
        if trick:
            return False
        globs = globs or glob
        try:
            parts = shlex.split(tok)
        except ValueError:
            return False
        if len(parts) != 1:
            return False
        words.append(parts[0])
    first = words[0]
    if globs and first not in GLOB_OK:
        return False
    if first == "uniq":
        # uniq ENTRADA SALIDA escribe en el segundo archivo
        return sum(1 for w in words[1:] if not w.startswith("-")) <= 1
    if first == "identify":
        # Los «coders» de ImageMagick: ephemeral:archivo lo borra al leerlo, msl: escribe archivos
        return not any(":" in w or w.startswith("@") for w in words[1:])
    if first in SAFE_SIMPLE:
        return not has_risky_flag(first, words)
    if first == "git":
        return git_safe(words)
    if first in COMPILERS:
        return compiler_safe(words)
    if first == "make":
        return make_safe(words)
    if first == "cmake":
        return cmake_safe(words)
    if first == "ctest":
        return ctest_safe(words)
    if first == "valgrind":
        return valgrind_safe(words)
    if first == "pacman":
        return len(words) > 1 and (words[1].startswith("-Q") or words[1] in ("-Si", "-Ss", "-F", "-Fl"))
    if first == "journalctl":
        return not any(w.startswith(("--vacuum", "--rotate", "--flush", "--sync")) for w in words)
    if first in ("qs", "quickshell"):
        rest, k = [], 1
        while k < len(words):
            if words[k] in ("-c", "-p", "--config", "--path"):
                k += 2
                continue
            rest.append(words[k])
            k += 1
        return rest[:1] in (["list"], ["log"]) and all(w.startswith("-") for w in rest[1:]) and "-n" not in rest
    if first in SAFE_SUB:
        return sub_safe(first, words)
    return False


def split_segments(cmd):
    """Parte el comando en órdenes como lo haría bash: un `|` o `;` entre comillas es texto, no una
    tubería. Cada palabra conserva sus comillas (se quitan después). None si no se entiende."""
    try:
        lex = shlex.shlex(cmd, posix=False, punctuation_chars=True)
        lex.whitespace_split = True
        tokens = list(lex)
    except ValueError:
        return None
    segments, current = [], []
    for tok in tokens:
        if all(c in "();<>|&" for c in tok):
            if tok not in ("|", "||", "&&", ";"):
                return None
            segments.append(current)
            current = []
        else:
            current.append(tok)
    segments.append(current)
    return segments


def is_safe(cmd):
    """Verdadero solo si TODO el comando está en la lista permitida, encadenado con ; && || o tuberías."""
    if re.search(r"[<>`\n\r]|\$\(|(?<!&)&(?!&)", cmd):
        return False
    segments = split_segments(cmd)
    return segments is not None and all(is_safe_segment(s) for s in segments)


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
    if is_safe(cmd):
        decide(True)
    active = ""
    try:
        active = json.loads(run(["hyprctl", "activewindow", "-j"]) or "{}").get("class", "")
    except Exception:
        pass
    # Si ya estás en la terminal: confirmás ahí, como siempre
    if active == "kitty":
        defer()

    lines = cmd.count("\n") + 1
    too_long = len(cmd) > MAX_CHARS or lines > MAX_LINES
    risky = bool(RISKY.search(cmd)) or too_long
    compound = bool(COMPOUND.search(cmd))

    args = ["notify-send", "-a", NAME, "-u", "critical", "-t", str(WAIT_MS), "-c", "ombu.confirm",
            "-h", "string:x-ombu-kind:confirm",
            "-h", f"int:x-ombu-risky:{1 if risky else 0}",
            "-h", f"int:x-ombu-compound:{1 if compound else 0}",
            "-h", "string:x-ombu-cwd:" + cwd]
    if not risky:
        args += ["-A", "allow=Permitir"]
    args += ["-A", "deny=Denegar", "-A", "focus=Ir a la consola",
             f"{NAME} quiere ejecutar un comando", cmd]
    choice = run(args, timeout=WAIT_MS // 1000 + 15).strip()

    if choice == "allow" and not risky:
        decide(True)
    if choice == "deny":
        decide(False, "Denegado por el usuario desde la tarjeta de ombu.")
    if choice == "focus":
        focus_terminal()
    defer()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        # Ante cualquier error inesperado, nunca se decide por la persona
        defer()
