#!/usr/bin/env python3
"""Datos del Resumen del panel lateral de ombu: clima, dólar y proyectos.

Uso:
  estacion.py net [--city CIUDAD] [--cached]   clima (wttr.in) y dólar (dolarapi.com), copia de 30 min
  estacion.py proyectos                        repos de ~/Proyectos y ombu, con su último cambio

Salida JSON. `net --cached` imprime la copia (~/.cache/ombu/estacion.json) sin importar su edad y sin
bajar nada. Si una de las dos fuentes falla se conserva lo último que se pudo bajar de esa fuente.
Sin ciudad, wttr.in la deduce de la dirección IP (solo ve eso, como cualquier sitio web). Solo
biblioteca estándar."""
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "ombu", "estacion.json")
FRESH = 30 * 60
HOME = os.path.expanduser("~")

# Código de wttr.in -> ícono de Material Symbols
ICONS = [
    ({113}, "wb_sunny"), ({116}, "partly_cloudy_day"), ({119, 122}, "cloud"),
    ({143, 248, 260}, "foggy"),
    ({200, 386, 389, 392, 395}, "thunderstorm"),
    ({179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377}, "ac_unit"),
    ({176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359}, "rainy"),
]


def get(url, timeout=8):
    req = urllib.request.Request(url, headers={"User-Agent": "ombu-estacion/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def weather(city):
    d = get("https://wttr.in/%s?format=j1&lang=es" % urllib.parse.quote(city))
    c = d["current_condition"][0]
    today = d["weather"][0]
    code = int(c.get("weatherCode", 113))
    icon = next((i for codes, i in ICONS if code in codes), "cloud")
    desc = (c.get("lang_es") or c.get("weatherDesc") or [{"value": ""}])[0]["value"]
    rain = max((int(h.get("chanceofrain", 0)) for h in today.get("hourly", [])), default=0)
    area = ""
    try:
        area = d["nearest_area"][0]["areaName"][0]["value"]
    except (KeyError, IndexError):
        pass
    return {"temp": int(c["temp_C"]), "feels": int(c["FeelsLikeC"]), "desc": desc, "icon": icon, "code": code,
            "max": int(today["maxtempC"]), "min": int(today["mintempC"]), "rain": rain, "area": area,
            "humidity": int(c.get("humidity", 0))}


def dolar():
    out = {}
    for d in get("https://dolarapi.com/v1/dolares"):
        if d.get("casa") in ("oficial", "blue", "cripto", "bolsa"):
            out[d["casa"]] = {"compra": d.get("compra"), "venta": d.get("venta"), "fecha": d.get("fechaActualizacion")}
    return out


def read_cache():
    try:
        with open(CACHE, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {"updated": 0, "weather": None, "dolar": None, "error": None}


def net(args):
    old = read_cache()
    if "--cached" in args:
        print(json.dumps(old, ensure_ascii=False))
        return
    city = args[args.index("--city") + 1] if "--city" in args else ""
    if time.time() - old.get("updated", 0) < FRESH and "--refresh" not in args:
        print(json.dumps(old, ensure_ascii=False))
        return
    errors = []
    with ThreadPoolExecutor(2) as pool:
        fw, fd = pool.submit(weather, city), pool.submit(dolar)
        res = {}
        for key, fut in (("weather", fw), ("dolar", fd)):
            try:
                res[key] = fut.result(timeout=12)
            except Exception:
                res[key] = old.get(key)
                errors.append(key)
    out = {"updated": time.time() if len(errors) < 2 else old.get("updated", 0), "weather": res["weather"],
           "dolar": res["dolar"], "error": ("Sin conexión con: " + ", ".join(errors)) if errors else None}
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    print(json.dumps(out, ensure_ascii=False))


def git(path, *a):
    try:
        return subprocess.run(["git", "-C", path, *a], capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        return ""


def proyectos():
    paths = [os.path.join(HOME, ".config/quickshell/ombu")]
    base = os.path.join(HOME, "Proyectos")
    if os.path.isdir(base):
        paths += [os.path.join(base, n) for n in sorted(os.listdir(base))]
    out = []
    for p in paths:
        if not os.path.isdir(os.path.join(p, ".git")):
            continue
        log = git(p, "log", "-1", "--format=%ct%x09%s")
        if not log or "\t" not in log:
            continue
        ts, subject = log.split("\t", 1)
        dirty = len([l for l in git(p, "status", "--porcelain").splitlines() if l.strip()])
        out.append({"name": os.path.basename(p), "when": int(ts), "subject": subject, "dirty": dirty})
    # La facultad no es un repo: lo último que tocaste
    uni = os.path.join(HOME, "Universidad")
    try:
        files = [os.path.join(uni, f) for f in os.listdir(uni) if not f.startswith(".")]
        newest = max(files, key=os.path.getmtime)
        out.append({"name": "Universidad", "when": int(os.path.getmtime(newest)), "subject": os.path.basename(newest), "dirty": 0})
    except (OSError, ValueError):
        pass
    out.sort(key=lambda x: -x["when"])
    print(json.dumps(out[:4], ensure_ascii=False))


def main():
    args = sys.argv[1:]
    if args[:1] == ["net"]:
        net(args[1:])
    elif args[:1] == ["proyectos"]:
        proyectos()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
