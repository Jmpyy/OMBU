#!/usr/bin/env python3
"""Chat del panel lateral de ombu con Claude Code o Antigravity.

Uso:
  agent-chat.py dirs                                        carpetas donde se puede charlar (JSON)
  agent-chat.py models                                      modelos de Antigravity (`agy models`, JSON)
  agent-chat.py run --agent claude|agy --model M --cwd DIR [--session ID] [--add-dir DIR]...
                                                            un turno; el mensaje llega en
                                                            OMBU_CHAT_PROMPT o por stdin

`run` corre el agente en modo no interactivo y traduce sus eventos a líneas JSON iguales para los dos:
  {"t": "session", "id": ...}          conversación (para retomarla en el próximo turno)
  {"t": "model", "id": ...}            modelo real del turno (Claude se elige por alias)
  {"t": "text", "d": ...}              pedazo de la respuesta
  {"t": "tool", "name": ..., "detail": ...}
  {"t": "denied", "name": ...}         herramienta que pedía permiso y se negó
  {"t": "limits", "five": 0.24, "week": 0.21, "resets": epoch}   cupo del plan (solo Claude)
  {"t": "done", "tokens": N, "cost": x}
  {"t": "error", "msg": ...}

Seguridad: Claude corre con --permission-prompts none (lo que pediría permiso se niega solo: lee pero
no escribe ni corre comandos fuera de lo que ya permite su configuración) y Antigravity con --mode plan
y --dangerously-skip-permissions (el hook agent-confirm.py valida comandos y pide confirmación por tarjeta
de notificación de ombu cuando hace falta). Para que el agente haga cambios libres, seguí la conversación
en la terminal. OMBU_CHAT=1 le avisa a los hooks (agent-notify.sh y agent-confirm.py) que es el chat.
"""
import argparse
import json
import os
import shutil
import signal
import subprocess
import sys

HOME = os.path.expanduser("~")
# La sesión de Hyprland no trae ~/.local/bin en el PATH
EXTRA_PATH = [os.path.join(HOME, ".local/bin"), "/usr/local/bin", "/usr/bin"]
OMBU = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

child = None


def emit(**kw):
    sys.stdout.write(json.dumps(kw, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def find(name):
    path = os.pathsep.join(EXTRA_PATH + [os.environ.get("PATH", "")])
    return shutil.which(name, path=path)


def dirs():
    out = []
    p = os.path.join(HOME, "Universidad")
    if os.path.isdir(p):
        out.append({"name": "Universidad", "path": p})
    out.append({"name": "ombu", "path": OMBU})
    base = os.path.join(HOME, "Proyectos")
    try:
        for d in sorted(os.listdir(base), key=str.lower):
            p = os.path.join(base, d)
            if os.path.isdir(p) and not d.startswith(".") and os.path.realpath(p) != os.path.realpath(OMBU):
                out.append({"name": d, "path": p})
    except OSError:
        pass
    out.append({"name": "Inicio", "path": HOME})
    print(json.dumps(out, ensure_ascii=False))


def models():
    """Modelos de Antigravity: «id<TAB>nombre» por línea en la salida de `agy models`."""
    out = []
    exe = find("agy")
    if exe:
        try:
            r = subprocess.run([exe, "models"], capture_output=True, text=True, timeout=30)
            for line in r.stdout.splitlines():
                if "\t" in line:
                    mid, name = line.split("\t", 1)
                    if mid.strip() and not mid.startswith(" "):
                        out.append({"id": mid.strip(), "name": name.strip()})
        except (OSError, subprocess.TimeoutExpired):
            pass
    print(json.dumps({"agy": out}, ensure_ascii=False))


def short(inp):
    """Lo más útil de los parámetros de una herramienta, en una línea."""
    if not isinstance(inp, dict):
        return ""
    for k in ("file_path", "path", "Path", "command", "CommandLine", "pattern", "Pattern", "query",
              "Query", "url", "Url", "AbsolutePath", "TargetFile", "description"):
        v = inp.get(k)
        if isinstance(v, str) and v:
            v = v.replace(HOME, "~").replace("\n", " ")
            return v if len(v) <= 90 else v[:87] + "…"
    return ""


def run_claude(a, prompt):
    exe = find("claude")
    if not exe:
        emit(t="error", msg="No encontré «claude»")
        return 1
    cmd = [exe, "-p", "--output-format", "stream-json", "--include-partial-messages", "--verbose",
           "--model", a.model, "--permission-prompts", "none"]
    if a.session:
        cmd += ["--resume", a.session]
    # Carpetas extra que puede leer (las de los adjuntos)
    if a.add_dir:
        cmd += ["--add-dir"] + a.add_dir
    texted = False
    in_text = False
    ok = False
    err = ""
    for e in stream(cmd, a.cwd, prompt):
        t = e.get("type")
        if t == "system" and e.get("subtype") == "init":
            emit(t="session", id=e.get("session_id", ""))
            if e.get("model"):
                emit(t="model", id=e["model"])
        elif t == "system" and e.get("subtype") == "permission_denied":
            emit(t="denied", name=e.get("tool_name", ""))
        elif t == "stream_event":
            ev = e.get("event") or {}
            # Los mensajes de los subagentes (Task) no van al chat
            if e.get("parent_tool_use_id"):
                continue
            if ev.get("type") == "content_block_start":
                in_text = (ev.get("content_block") or {}).get("type") == "text"
                if in_text and texted:
                    emit(t="text", d="\n\n")
            elif ev.get("type") == "content_block_delta":
                d = ev.get("delta") or {}
                if d.get("type") == "text_delta" and d.get("text"):
                    texted = True
                    emit(t="text", d=d["text"])
        elif t == "assistant" and not e.get("parent_tool_use_id"):
            for c in (e.get("message") or {}).get("content") or []:
                if c.get("type") == "tool_use":
                    emit(t="tool", name=c.get("name", ""), detail=short(c.get("input")))
        elif t == "rate_limit_event":
            w = (e.get("rate_limit_info") or {}).get("unifiedWindows") or {}
            five = w.get("five_hour") or {}
            week = w.get("seven_day") or {}
            emit(t="limits", five=five.get("utilization"), week=week.get("utilization"),
                 resets=five.get("resetsAt"))
        elif t == "result":
            u = e.get("usage") or {}
            tokens = sum(u.get(k) or 0 for k in ("input_tokens", "output_tokens",
                                                   "cache_creation_input_tokens", "cache_read_input_tokens"))
            if e.get("is_error") or e.get("subtype") not in (None, "success"):
                err = e.get("result") or "; ".join(e.get("errors") or []) or e.get("subtype") or "error"
            else:
                ok = True
                emit(t="done", tokens=tokens, cost=e.get("total_cost_usd") or 0)
        elif t == "raw":
            err = e.get("line", "")[:300] or err
    if not ok:
        emit(t="error", msg=err or "Claude terminó sin responder")
    return 0 if ok else 1


def run_agy(a, prompt):
    exe = find("agy")
    if not exe:
        emit(t="error", msg="No encontré «agy»")
        return 1
    # Con «=» el mensaje no se confunde con una opción aunque empiece con «-»
    cmd = [exe, "--print=" + prompt, "--output-format=stream-json", "--model=" + a.model, "--mode=plan",
           "--dangerously-skip-permissions"]
    if a.session:
        cmd.append("--conversation=" + a.session)
    cmd += ["--add-dir=" + d for d in a.add_dir]
    texted = False
    last_step = None
    ok = False
    err = ""
    for e in stream(cmd, a.cwd, None):
        ev = e.get("event")
        if ev == "init":
            emit(t="session", id=e.get("conversation_id", ""))
            if (e.get("init") or {}).get("model"):
                emit(t="model", id=e["init"]["model"])
        elif ev == "step_update":
            s = e.get("step_update") or {}
            kind = s.get("step_type")
            if kind == "agent_response" and s.get("text_delta"):
                if texted and s.get("step_index") != last_step:
                    emit(t="text", d="\n\n")
                texted = True
                last_step = s.get("step_index")
                emit(t="text", d=s["text_delta"])
            elif kind == "tool" and s.get("state") == "ACTIVE":
                info = s.get("tool_info") or {}
                emit(t="tool", name=s.get("tool_name", ""), detail=short(info.get("parameters")))
        elif ev == "result":
            r = e.get("result") or {}
            if r.get("status") == "SUCCESS":
                ok = True
                emit(t="done", tokens=(r.get("usage") or {}).get("total_tokens") or 0, cost=0)
            else:
                err = r.get("error") or r.get("status") or "error"
        elif e.get("type") == "raw":
            err = e.get("line", "")[:300] or err
    if not ok:
        emit(t="error", msg=err or "Antigravity terminó sin responder")
    return 0 if ok else 1


def stream(cmd, cwd, stdin_text):
    global child
    env = dict(os.environ, OMBU_CHAT="1")
    env["PATH"] = os.pathsep.join(EXTRA_PATH + [env.get("PATH", "")])
    child = subprocess.Popen(cmd, cwd=cwd, env=env, text=True, bufsize=1,
                             stdin=subprocess.PIPE if stdin_text is not None else subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
    if stdin_text is not None:
        child.stdin.write(stdin_text)
        child.stdin.close()
    for line in child.stdout:
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except ValueError:
            yield {"type": "raw", "line": line}
    child.wait()


def stop(*_):
    # Parar = cortar el turno del agente (y lo que haya lanzado), nunca dejarlo corriendo
    if child and child.poll() is None:
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except OSError:
            pass
    sys.exit(0)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=["dirs", "models", "run"])
    p.add_argument("--agent", choices=["claude", "agy"], default="claude")
    p.add_argument("--model", default="sonnet")
    p.add_argument("--cwd", default=HOME)
    p.add_argument("--session", default="")
    p.add_argument("--add-dir", action="append", default=[])
    a = p.parse_args()
    if a.cmd == "dirs":
        dirs()
        return 0
    if a.cmd == "models":
        models()
        return 0
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    # El mensaje llega en OMBU_CHAT_PROMPT (así lo manda ombu) o por stdin; no pasa al agente
    prompt = os.environ.pop("OMBU_CHAT_PROMPT", None)
    if prompt is None:
        prompt = sys.stdin.read()
    prompt = prompt.strip()
    if not prompt:
        emit(t="error", msg="Mensaje vacío")
        return 1
    if not os.path.isdir(a.cwd):
        emit(t="error", msg="No existe la carpeta " + a.cwd)
        return 1
    return run_claude(a, prompt) if a.agent == "claude" else run_agy(a, prompt)


if __name__ == "__main__":
    sys.exit(main())
