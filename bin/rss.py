#!/usr/bin/env python3
"""Noticias para el panel lateral de ombu: baja varios feeds RSS/Atom y los junta por categoría.

Uso: rss.py [--refresh | --cached] [--max N]
  --cached imprime la copia guardada sin importar su edad (o una lista vacía) y no baja nada: es lo que
  muestra el panel mientras se actualiza.
  Sin --refresh usa la copia guardada (~/.cache/ombu/noticias.json) si tiene menos de 15 minutos.
Salida (JSON): {"updated": segundos, "categories": [{"id", "name", "items": [{"title", "link",
  "source", "time"}]}], "error": null | "texto"}

Los feeds salen de ~/.local/share/ombu/noticias.json si existe (mismo formato que FEEDS abajo) y,
si no, de la lista de este archivo. Se descartan los titulares de farándula y obituarios. Solo
biblioteca estándar."""
import html
import json
import os
import re
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "ombu", "noticias.json")
USER_FEEDS = os.path.expanduser("~/.local/share/ombu/noticias.json")
FRESH = 15 * 60

# categoría -> (nombre, [(fuente, dirección)])
FEEDS = [
    {"id": "argentina", "name": "Argentina", "feeds": [
        ["Infobae", "https://www.infobae.com/arc/outboundfeeds/rss/category/politica/"],
        ["La Nación", "https://www.lanacion.com.ar/arc/outboundfeeds/rss/category/politica/?outputType=xml"]]},
    {"id": "economia", "name": "Economía", "feeds": [
        ["Infobae", "https://www.infobae.com/arc/outboundfeeds/rss/category/economia/"],
        ["Ámbito", "https://www.ambito.com/rss/pages/economia.xml"],
        ["La Nación", "https://www.lanacion.com.ar/arc/outboundfeeds/rss/category/economia/?outputType=xml"]]},
    {"id": "tecnologia", "name": "Tecnología", "feeds": [
        ["Hacker News", "https://hnrss.org/frontpage?points=150"],
        ["Genbeta", "https://www.genbeta.com/feedburner.xml"],
        ["Xataka", "https://www.xataka.com/feedburner.xml"],
        ["Phoronix", "https://www.phoronix.com/rss.php"]]},
    {"id": "seguridad", "name": "Seguridad", "feeds": [
        ["The Hacker News", "https://feeds.feedburner.com/TheHackersNews"],
        ["Krebs", "https://krebsonsecurity.com/feed/"],
        ["BleepingComputer", "https://www.bleepingcomputer.com/feed/"]]},
    {"id": "programacion", "name": "Programación", "feeds": [
        ["Lobsters · C", "https://lobste.rs/t/c.rss"],
        ["Lobsters", "https://lobste.rs/t/programming.rss"]]},
]

# Farándula, obituarios y relleno: no interesan
BLOCK = re.compile(
    r"\b(muri[óo]|muere|murieron|falleci[óo]|fallece|velatorio|funeral|luto|despedida a|farándula|farandula|"
    r"famos[oa]s?|actriz|cantante|conductor[a]? de|influencer|reality|gran hermano|romance|se separ[óo]|"
    r"separaci[óo]n de|infidelidad|horóscopo|horoscopo|signo[s]? del|looks?|alfombra roja|celebrity|"
    r"obituary|dies at|passed away|"
    # Ofertas y relleno
    r"ofertas?|descuentos?|chollos?|cup[óo]n|rebajas?|prime day|black friday|euros al mes|"
    r"what are you doing this week|who.?s hiring|weekly thread)\b", re.I)

UA = "Mozilla/5.0 (X11; Linux x86_64) ombu-news"


def local(tag):
    return tag.rsplit("}", 1)[-1]


def clean(text):
    text = re.sub(r"<[^>]+>", "", html.unescape(text or ""))
    return re.sub(r"\s+", " ", text).strip()


def when(text):
    text = (text or "").strip()
    if not text:
        return 0
    try:
        return parsedate_to_datetime(text).timestamp()
    except (TypeError, ValueError):
        pass
    try:
        d = datetime.fromisoformat(text.replace("Z", "+00:00"))
        return (d if d.tzinfo else d.replace(tzinfo=timezone.utc)).timestamp()
    except ValueError:
        return 0


def parse(data, source):
    items = []
    try:
        root = ET.fromstring(data)
    except ET.ParseError:
        return items
    for el in root.iter():
        if local(el.tag) not in ("item", "entry"):
            continue
        row = {"title": "", "link": "", "time": 0, "source": source}
        for ch in el:
            t = local(ch.tag)
            if t == "title":
                row["title"] = clean(ch.text)
            elif t == "link":
                row["link"] = (ch.get("href") or ch.text or "").strip() or row["link"]
            elif t in ("pubDate", "published", "updated", "date") and not row["time"]:
                row["time"] = when(ch.text)
        if row["title"] and row["link"].startswith("http"):
            items.append(row)
    return items


def fetch(source, url):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/rss+xml, application/xml, text/xml, */*"})
        with urllib.request.urlopen(req, timeout=10) as r:
            return parse(r.read(), source)
    except Exception:
        return None


def build(feeds, limit):
    jobs = [(c["id"], s, u) for c in feeds for s, u in c["feeds"]]
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda j: fetch(j[1], j[2]), jobs))
    failed = sum(1 for r in results if r is None)
    by_cat = {}
    for (cat, _s, _u), res in zip(jobs, results):
        by_cat.setdefault(cat, []).extend(res or [])
    cats = []
    for c in feeds:
        seen, out = set(), []
        for it in sorted(by_cat.get(c["id"], []), key=lambda x: x["time"], reverse=True):
            key = re.sub(r"\W+", "", it["title"].lower())[:60]
            if key in seen or BLOCK.search(it["title"]):
                continue
            seen.add(key)
            out.append(it)
            if len(out) >= limit:
                break
        cats.append({"id": c["id"], "name": c["name"], "items": out})
    err = "No se pudieron leer %d de %d fuentes" % (failed, len(jobs)) if failed else None
    return {"updated": int(time.time()), "categories": cats, "error": err}


def main():
    args = sys.argv[1:]
    refresh = "--refresh" in args
    if "--cached" in args:
        try:
            with open(CACHE, encoding="utf-8") as f:
                print(f.read())
        except (OSError, ValueError):
            print(json.dumps({"updated": 0, "categories": [], "error": None}))
        return
    limit = int(args[args.index("--max") + 1]) if "--max" in args else 25
    if not refresh:
        try:
            if time.time() - os.path.getmtime(CACHE) < FRESH:
                with open(CACHE, encoding="utf-8") as f:
                    print(f.read())
                return
        except (OSError, ValueError):
            pass
    feeds = FEEDS
    try:
        with open(USER_FEEDS, encoding="utf-8") as f:
            feeds = json.load(f)
    except (OSError, ValueError):
        pass
    result = build(feeds, limit)
    # Si no se pudo bajar nada, se prefiere la copia vieja a una lista vacía
    if not any(c["items"] for c in result["categories"]):
        try:
            with open(CACHE, encoding="utf-8") as f:
                old = json.load(f)
            old["error"] = "Sin conexión: se muestra lo último que se pudo bajar"
            print(json.dumps(old, ensure_ascii=False))
            return
        except (OSError, ValueError):
            pass
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
