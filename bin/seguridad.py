#!/usr/bin/env python3
"""Seguridad y estado del sistema para la pestaña «Sistema» del panel lateral de ombu.

  seguridad.py watch [SEGUNDOS]     una línea JSON cada tanto: puertos, servicios caídos, firewall y
                                    procesos que más consumen ({"t": "live", ...})
  seguridad.py updates [--refresh]  actualizaciones pendientes (repos y AUR) y noticias de Arch
                                    ({"t": "updates", ...}); copia de 1 hora en ~/.cache/ombu
  seguridad.py kill NOMBRE          cierra (SIGTERM) los procesos propios con ese nombre

Solo lee: no necesita root (los procesos de otros usuarios aparecen sin nombre en los puertos).
`kill` nunca toca procesos de otro usuario ni los de la sesión (PROTECTED). Solo biblioteca estándar
más ss, systemctl, checkupdates y paru.
"""
import datetime as dt
import email.utils
import json
import os
import re
import signal
import subprocess
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET

HOME = os.path.expanduser("~")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "ombu", "seguridad.json")
UID = os.getuid()
TICK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
NCPU = os.cpu_count() or 1

# Lo que sostiene la sesión: cerrarlo desde un botón rompe todo
PROTECTED = {"Hyprland", "quickshell", "qs", "kitty", "systemd", "dbus-daemon", "dbus-broker", "pipewire",
             "pipewire-pulse", "wireplumber", "xdg-desktop-por", "greetd", "fish", "zsh", "bash", "sh",
             "claude", "agy", "Xwayland", "gnome-keyring-d", "polkit-agent-he", "hypridle", "python3"}

# Programas cuyos procesos hijos se cuentan con ellos
FAMILIES = {"zen-bin", "firefox", "chrome", "chromium", "electron", "vesktop", "Discord", "steam", "code",
            "obs", "spotify", "zeditor", "zed-editor"}

# Nombres más claros para mostrar
NAMES = {"zen-bin": "Zen", "zeditor": "Zed", "zed-editor": "Zed", "java": "Java", "steam": "Steam",
         "vesktop": "Discord", "obs": "OBS", "Hyprland": "Hyprland", "quickshell": "ombu (Quickshell)"}

# Puertos conocidos: qué son, para leer la lista sin buscar en internet
KNOWN = {
    22: "SSH: entrar a esta PC desde otra",
    53: "DNS local (systemd-resolved)",
    80: "Servidor web",
    443: "Servidor web seguro",
    546: "DHCPv6: pedir dirección IPv6 al router",
    631: "Impresoras (CUPS)",
    3000: "Servidor de desarrollo",
    5037: "adb: depuración de Android",
    5173: "Servidor de desarrollo (Vite)",
    5353: "mDNS: descubrir equipos en la red local",
    5355: "LLMNR: nombres en la red local (systemd-resolved)",
    8080: "Servidor de desarrollo",
}


def run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout
    except (OSError, subprocess.TimeoutExpired):
        return -1, ""


# ---------------- en vivo ----------------

def ephemeral():
    """Rango de puertos que el sistema asigna a las conexiones salientes (ej. 32768-60999)."""
    try:
        with open("/proc/sys/net/ipv4/ip_local_port_range") as f:
            lo, hi = f.read().split()
        return int(lo), int(hi)
    except (OSError, ValueError):
        return 32768, 60999


def ports():
    """Sockets que escuchan: TCP en LISTEN y UDP atados a una dirección. Juntos los de IPv4 e IPv6.
    Un UDP en un puerto del rango efímero es el lado cliente de una conexión saliente (llamadas, QUIC,
    juegos): no espera que nadie entre, así que no cuenta como expuesto; va aparte en «outgoing»."""
    _, out = run(["ss", "-tulnpH"])
    lo, hi = ephemeral()
    seen = {}
    outgoing = {}
    for line in out.splitlines():
        f = line.split()
        if len(f) < 5:
            continue
        proto, state, local = f[0], f[1], f[4]
        if proto == "tcp" and state != "LISTEN":
            continue
        addr, _, port = local.rpartition(":")
        if not port.isdigit():
            continue
        port = int(port)
        addr = addr.strip("[]").split("%")[0]
        loopback = addr.startswith("127.") or addr in ("::1", "::ffff:127.0.0.1") or addr.startswith("::ffff:127.")
        link_local = addr.startswith("fe80")
        m = re.search(r'users:\(\("([^"]+)",pid=(\d+)', line)
        prog = m.group(1) if m else ""
        if proto == "udp" and lo <= port <= hi and prog:
            outgoing[prog] = outgoing.get(prog, 0) + 1
            continue
        key = (proto, port, prog)
        p = seen.setdefault(key, {"proto": proto, "port": port, "program": prog,
                                  "pid": int(m.group(2)) if m else 0, "exposed": False,
                                  "local": True, "what": KNOWN.get(port, "")})
        # «Expuesto»: atado a todas las interfaces o a una dirección de la red (no solo a esta PC)
        if not loopback and not link_local:
            p["local"] = False
            p["exposed"] = True
    # Primero lo expuesto, después por puerto
    listening = sorted(seen.values(), key=lambda p: (not p["exposed"], p["port"], p["proto"]))
    return listening, [{"program": k, "count": v} for k, v in sorted(outgoing.items())]


def failed():
    out = []
    for scope in (["--system"], ["--user"]):
        _, txt = run(["systemctl"] + scope + ["--failed", "--no-legend", "--plain"])
        for line in txt.splitlines():
            f = line.split(None, 4)
            if f:
                out.append({"unit": f[0], "scope": scope[0][2:], "desc": f[4] if len(f) > 4 else ""})
    return out


def firewall():
    for name in ("ufw", "firewalld", "nftables"):
        rc, out = run(["systemctl", "is-active", name])
        if out.strip() == "active":
            return {"name": name, "active": True}
    return {"name": "", "active": False}


def last_upgrade():
    """Fecha (epoch) de la última actualización completa del sistema, según el log de pacman."""
    try:
        with open("/var/log/pacman.log", "rb") as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 400000))
            tail = f.read().decode("utf-8", "replace")
    except OSError:
        return 0
    found = re.findall(r"\[([0-9T:+\-]+)\] \[PACMAN\] starting full system upgrade", tail)
    if not found:
        return 0
    try:
        return int(dt.datetime.strptime(found[-1], "%Y-%m-%dT%H:%M:%S%z").timestamp())
    except ValueError:
        return 0


def procs():
    """{pid: (nombre, uid, ticks de CPU, bytes de memoria)}. Los procesos hijos de un programa de
    FAMILIES (las pestañas de Zen se llaman «Isolated Web Co») llevan el nombre del padre."""
    out = {}
    parent = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open("/proc/%s/stat" % pid) as f:
                st = f.read()
            with open("/proc/%s/statm" % pid) as f:
                rss = int(f.read().split()[1]) * PAGE
            uid = os.stat("/proc/" + pid).st_uid
        except (OSError, ValueError, IndexError):
            continue
        name = st[st.index("(") + 1:st.rindex(")")]
        rest = st[st.rindex(")") + 2:].split()
        out[int(pid)] = (name, uid, int(rest[11]) + int(rest[12]), rss)
        parent[int(pid)] = int(rest[1])
    for pid, (name, uid, ticks, rss) in list(out.items()):
        pp = parent.get(pid)
        # Hasta tres niveles arriba (Zen -> pestaña -> proceso auxiliar)
        for _ in range(3):
            if pp not in out:
                break
            if out[pp][0] in FAMILIES:
                out[pid] = (out[pp][0], uid, ticks, rss)
                break
            pp = parent.get(pp)
    return out


def top(prev, now, seconds):
    """Por nombre de programa (Zen tiene muchos procesos): CPU % (del total de la PC) y memoria."""
    groups = {}
    for pid, (name, uid, ticks, rss) in now.items():
        g = groups.setdefault(name, {"name": name, "label": NAMES.get(name, name), "cpu": 0.0, "mem": 0,
                                     "count": 0, "mine": True})
        before = prev.get(pid)
        if before and before[0] == name and seconds > 0:
            g["cpu"] += max(0, ticks - before[2]) / TICK / seconds / NCPU * 100
        g["mem"] += rss
        g["count"] += 1
        if uid != UID:
            g["mine"] = False
    for g in groups.values():
        g["cpu"] = round(g["cpu"], 1)
        g["closable"] = g["mine"] and g["name"] not in PROTECTED
    lst = list(groups.values())
    return {
        "cpu": sorted(lst, key=lambda g: -g["cpu"])[:5],
        "mem": sorted(lst, key=lambda g: -g["mem"])[:5],
    }


def watch(interval):
    prev, prev_t = procs(), time.monotonic()
    time.sleep(0.6)
    while True:
        now, now_t = procs(), time.monotonic()
        listening, outgoing = ports()
        print(json.dumps({
            "t": "live",
            "ports": listening,
            "outgoing": outgoing,
            "failed": failed(),
            "firewall": firewall(),
            "upgradedAt": last_upgrade(),
            "top": top(prev, now, now_t - prev_t),
        }, ensure_ascii=False), flush=True)
        prev, prev_t = now, now_t
        time.sleep(interval)


# ---------------- actualizaciones ----------------

def pending(cmd, timeout):
    rc, out = run(cmd, timeout)
    lst = []
    for line in out.splitlines():
        f = line.split()
        # «nombre viejo -> nuevo»
        if len(f) >= 4 and f[2] == "->":
            lst.append({"name": f[0], "old": f[1], "new": f[3]})
    # checkupdates sale con 2 si no hay nada; con 1 si falló
    ok = rc in (0, 2) or (rc == 1 and lst)
    return lst, ok


def news(since):
    """Las últimas noticias de archlinux.org: algunas piden hacer algo a mano antes de actualizar."""
    try:
        req = urllib.request.Request("https://archlinux.org/feeds/news/", headers={"User-Agent": "ombu"})
        with urllib.request.urlopen(req, timeout=10) as r:
            root = ET.fromstring(r.read())
    except Exception:
        return None
    out = []
    for item in root.iter("item"):
        try:
            when = int(email.utils.parsedate_to_datetime(item.findtext("pubDate", "")).timestamp())
        except (TypeError, ValueError):
            when = 0
        out.append({"title": item.findtext("title", ""), "link": item.findtext("link", ""), "at": when,
                    "unread": since > 0 and when > since})
        if len(out) >= 4:
            break
    return out


def updates(refresh):
    if not refresh:
        try:
            cache_mtime = os.path.getmtime(CACHE)
            pacman_mtime = 0
            try:
                pacman_mtime = max(
                    os.path.getmtime("/var/log/pacman.log"),
                    os.path.getmtime("/var/lib/pacman/local")
                )
            except OSError:
                pass
            if (time.time() - cache_mtime < 3600) and (pacman_mtime <= cache_mtime):
                with open(CACHE) as f:
                    print(f.read().strip())
                return
        except OSError:
            pass
    repo, ok_repo = pending(["checkupdates"], 90)
    aur, ok_aur = pending(["paru", "-Qua"], 60)
    since = last_upgrade()
    data = {"t": "updates", "repo": repo, "aur": aur, "news": news(since) or [],
            "at": int(time.time()), "upgradedAt": since,
            "error": "" if ok_repo else "No se pudieron consultar los repos (¿sin conexión?)"}
    if ok_repo:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE, "w") as f:
            json.dump(data, f, ensure_ascii=False)
    print(json.dumps(data, ensure_ascii=False))


# ---------------- cerrar ----------------

def kill(name):
    if name in PROTECTED:
        print(json.dumps({"error": "«%s» sostiene la sesión: no se cierra desde acá" % name}, ensure_ascii=False))
        return 1
    done = 0
    for pid, (n, uid, _, _) in procs().items():
        if n == name and uid == UID and pid != os.getpid():
            try:
                os.kill(pid, signal.SIGTERM)
                done += 1
            except OSError:
                pass
    print(json.dumps({"closed": done}))
    return 0


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "watch":
        watch(float(argv[2]) if len(argv) > 2 else 3)
    elif cmd == "updates":
        updates("--refresh" in argv)
    elif cmd == "kill" and len(argv) > 2:
        return kill(argv[2])
    else:
        print(__doc__.strip())
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except (KeyboardInterrupt, BrokenPipeError):
        pass
