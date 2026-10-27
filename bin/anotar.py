#!/usr/bin/env python3
"""Anotador rápido de ombu: entiende frases como las del papel.

  anotar.py parse "parcial eda jueves 18hs" [--now 2026-10-23T10:00]
  anotar.py note "texto" [--subject eda1]          guarda una nota (sin fecha)
  anotar.py subjects                               materias que reconoce, con sus notas (JSON)

`parse` devuelve JSON con lo que entendió:
  {kind, kindName, subject: {id, name, dir} | null, title, detail, date "AAAA-MM-DD" | "",
   time "HH:MM" | "", reminders: [minutos antes], tag, isNote, when (texto para mostrar)}

Tipos: parcial, recuperatorio, final, entrega (TP, trabajo práctico, informe), clase, consulta;
sin tipo y con fecha es un evento; sin fecha es una nota. Las entregas sin hora vencen a las 23:59.
Las materias salen de ~/.local/share/ombu/materias.json (si no existe, las de la carrera).
Solo biblioteca estándar: se prueba con tests/anotar_test.py.
"""
import datetime as dt
import json
import os
import re
import sys
import unicodedata

HOME = os.path.expanduser("~")
DATA = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share")), "ombu")
UNI = os.path.join(HOME, "Universidad")

DEFAULT_SUBJECTS = [
    {"id": "eda1", "name": "EDA1", "full": "Estructura de Datos y Algoritmos 1", "dir": "EDA1",
     "aliases": ["eda1", "eda 1", "eda", "estructuras", "estructura de datos", "algoritmos"]},
    {"id": "so", "name": "Sistemas Operativos", "dir": "Sistemas-Operativos",
     "aliases": ["sistemas operativos", "operativos", "sistemas", "so"]},
    {"id": "testing", "name": "Testing", "dir": "Testing", "aliases": ["testing", "test"]},
    {"id": "mate1", "name": "Matemática 1", "dir": "Matematica1",
     "aliases": ["matematica 1", "matematica1", "mate 1", "mate1", "matematica", "mate"]},
]

# palabra (sin tildes) -> tipo
KINDS = {
    "parcial": "parcial", "parciales": "parcial", "examen": "parcial", "evaluacion": "parcial",
    "recuperatorio": "recuperatorio", "recu": "recuperatorio",
    "final": "final",
    "entrega": "entrega", "entregar": "entrega", "informe": "entrega", "trabajo practico": "entrega",
    "clase": "clase", "cursada": "clase",
    "consulta": "consulta",
}
KIND_NAMES = {"parcial": "Parcial", "recuperatorio": "Recuperatorio", "final": "Final", "entrega": "Entrega",
              "clase": "Clase", "consulta": "Consulta", "evento": "Evento", "nota": "Nota"}
# Avisos (minutos antes): con hora / todo el día
REMINDERS = {
    "parcial": ([4320, 1440, 120], [4320, 1440]),
    "recuperatorio": ([4320, 1440, 120], [4320, 1440]),
    "final": ([10080, 4320, 1440, 120], [10080, 4320, 1440]),
    "entrega": ([1440, 180], [1440]),
    "clase": ([30], [0]),
    "consulta": ([30], [0]),
    "evento": ([60], [0]),
}

WEEKDAYS = {"lunes": 0, "martes": 1, "miercoles": 2, "jueves": 3, "viernes": 4, "sabado": 5, "domingo": 6}
MONTHS = {"enero": 1, "ene": 1, "febrero": 2, "feb": 2, "marzo": 3, "mar": 3, "abril": 4, "abr": 4,
          "mayo": 5, "may": 5, "junio": 6, "jun": 6, "julio": 7, "jul": 7, "agosto": 8, "ago": 8,
          "septiembre": 9, "setiembre": 9, "sep": 9, "sept": 9, "set": 9, "octubre": 10, "oct": 10,
          "noviembre": 11, "nov": 11, "diciembre": 12, "dic": 12}
NUMBERS = {"un": 1, "una": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5, "seis": 6, "siete": 7}
FILLER = {"el", "la", "los", "las", "de", "del", "a", "al", "para", "hasta", "en", "y", "que", "es", "hay",
          "tengo", "tenemos", "con", "por"}
DAY_NAMES = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]


def fold(s):
    """Minúsculas y sin tildes, para comparar."""
    s = unicodedata.normalize("NFD", s.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def subjects():
    try:
        with open(os.path.join(DATA, "materias.json")) as f:
            data = json.load(f)
        if isinstance(data, list) and data:
            return data
    except (OSError, ValueError):
        pass
    return DEFAULT_SUBJECTS


class Text:
    """El texto en minúsculas y sin tildes, con las partes que ya se entendieron tachadas."""

    def __init__(self, raw):
        self.raw = raw
        self.low = fold(raw)
        self.used = [False] * len(self.low)

    def take(self, pattern, flags=0):
        """Busca el patrón (palabras completas) donde no se tachó nada; lo tacha y devuelve el match."""
        for m in re.finditer(r"(?<![\w/:.])(?:" + pattern + r")(?![\w/:])", self.low, flags):
            if not any(self.used[m.start():m.end()]):
                for i in range(m.start(), m.end()):
                    self.used[i] = True
                return m
        return None

    def rest(self):
        """Lo que quedó sin entender, con las mayúsculas originales."""
        out = "".join(c if not u else " " for c, u in zip(self.raw, self.used))
        words = [w for w in out.split() if fold(w) not in FILLER]
        return " ".join(words).strip(" ,.;-:·")


def find_date(t, now):
    today = now.date()
    if t.take(r"pasado\s+manana"):
        return today + dt.timedelta(days=2)
    if t.take(r"manana"):
        return today + dt.timedelta(days=1)
    if t.take(r"hoy"):
        return today
    m = t.take(r"en\s+(\d+|un|una|dos|tres|cuatro|cinco|seis|siete)\s+(dias?|semanas?)")
    if m:
        n = int(m.group(1)) if m.group(1).isdigit() else NUMBERS[m.group(1)]
        return today + dt.timedelta(days=n * (7 if m.group(2).startswith("semana") else 1))
    if t.take(r"(la\s+)?semana\s+que\s+viene|(la\s+)?proxima\s+semana"):
        return today + dt.timedelta(days=7 - today.weekday())
    # 15/11, 15/11/26, 15/11/2026, 15-11
    m = t.take(r"(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?")
    if m:
        d, mo = int(m.group(1)), int(m.group(2))
        y = int(m.group(3)) if m.group(3) else today.year
        if y < 100:
            y += 2000
        try:
            date = dt.date(y, mo, d)
        except ValueError:
            return None
        if not m.group(3) and date < today:
            date = date.replace(year=y + 1)
        return date
    # 15 de noviembre, 15 nov
    m = t.take(r"(\d{1,2})\s+(?:de\s+)?(" + "|".join(sorted(MONTHS, key=len, reverse=True)) + r")")
    if m:
        try:
            date = dt.date(today.year, MONTHS[m.group(2)], int(m.group(1)))
        except ValueError:
            return None
        return date if date >= today else date.replace(year=today.year + 1)
    # jueves, el jueves, este jueves, el próximo jueves, el jueves que viene
    m = t.take(r"(?:(?:el|este)\s+)?(?:proximo\s+)?(" + "|".join(WEEKDAYS) + r")(?:\s+que\s+viene)?")
    if m:
        ahead = (WEEKDAYS[m.group(1)] - today.weekday()) % 7 or 7
        return today + dt.timedelta(days=ahead)
    return None


def find_time(t):
    # 18:30, 18.30, 18:30hs
    m = t.take(r"(?:a\s+las\s+)?(\d{1,2})[:.](\d{2})\s*(?:hs?|horas)?")
    if m:
        h, mi = int(m.group(1)), int(m.group(2))
        return (h, mi) if h < 24 and mi < 60 else None
    # 18hs, 18 hs, 18h, 8am, 8 pm
    m = t.take(r"(?:a\s+las\s+)?(\d{1,2})\s*(hs|h|horas|am|pm)")
    if m:
        h = int(m.group(1))
        if m.group(2) == "pm" and h < 12:
            h += 12
        if m.group(2) == "am" and h == 12:
            h = 0
        return (h, 0) if h < 24 else None
    # a las 6 de la tarde, a las 9 de la noche, a las 18
    m = t.take(r"a\s+las\s+(\d{1,2})(?:\s+de\s+la\s+(manana|tarde|noche))?")
    if m:
        h = int(m.group(1))
        if m.group(2) in ("tarde", "noche") and h < 12:
            h += 12
        return (h, 0) if h < 24 else None
    return None


def find_subject(t):
    best = None
    for s in subjects():
        names = [fold(a) for a in s.get("aliases", [])] + [fold(s["name"])]
        for a in sorted(set(names), key=len, reverse=True):
            m = re.search(r"(?<![\w])" + re.escape(a) + r"(?![\w])", t.low)
            if m and not any(t.used[m.start():m.end()]) and (best is None or len(a) > best[1]):
                best = (s, len(a), m.start(), m.end())
                break
    if not best:
        return None
    for i in range(best[2], best[3]):
        t.used[i] = True
    return best[0]


def find_kind(t):
    # «nota:» al principio fuerza una nota aunque haya una fecha
    if t.take(r"^nota:?|^anotar:?"):
        return "nota"
    # TP, TP2, TP 2, trabajo práctico 3: es una entrega y el número queda en el título
    m = re.search(r"(?<![\w])(tp\s*\d*|trabajo\s+practico\s*\d*)(?![\w])", t.low)
    if m:
        t.take(r"entrega|entregar")
        return "entrega"
    # La primera palabra de tipo que aparece manda («clase de consulta» es una clase)
    found = []
    for word in KINDS:
        m = re.search(r"(?<![\w])" + re.escape(word) + r"(?![\w])", t.low)
        if m and not any(t.used[m.start():m.end()]):
            found.append((m.start(), -len(word), word))
    if not found:
        return None
    word = min(found)[2]
    t.take(re.escape(word))
    return KINDS[word]


def parse(raw, now=None):
    now = now or dt.datetime.now()
    t = Text(raw.strip())
    kind = find_kind(t)
    subject = find_subject(t)
    date = None if kind == "nota" else find_date(t, now)
    tm = None if kind == "nota" else find_time(t)
    if kind is None:
        kind = "evento" if date or tm else "nota"
    if kind != "nota" and date is None:
        # Algo con tipo pero sin fecha: si dijo una hora, es hoy (o mañana si ya pasó); si no, falta el día
        if tm:
            date = now.date() if (tm[0], tm[1]) > (now.hour, now.minute) else now.date() + dt.timedelta(days=1)
    if kind == "entrega" and date and not tm:
        tm = (23, 59)

    detail = t.rest()
    # «TP2» o «tp 2» con mayúsculas prolijas
    detail = re.sub(r"(?i)\btp\s*(\d*)", lambda m: "TP" + m.group(1), detail)
    detail = re.sub(r"(?i)\btrabajo pr[aá]ctico\b", "Trabajo práctico", detail)
    name = KIND_NAMES[kind]
    if kind == "nota":
        title = detail
    elif kind == "evento":
        title = detail or "Evento"
    else:
        title = name + (" " + detail if detail else "")
    if subject and kind != "nota":
        title += " · " + subject["name"]
    if title:
        title = title[0].upper() + title[1:]

    time = "%02d:%02d" % tm if tm else ""
    reminders = []
    if kind in REMINDERS:
        reminders = REMINDERS[kind][0 if time else 1]
    tag = ""
    if kind not in ("evento", "nota"):
        tag = "facu:" + kind + ":" + (subject["id"] if subject else "")
    elif kind == "evento" and subject:
        tag = "facu:evento:" + subject["id"]

    when = ""
    if date:
        days = (date - now.date()).days
        rel = {0: "hoy", 1: "mañana", 2: "pasado mañana"}.get(days)
        when = (rel + " " if rel else "") + DAY_NAMES[date.weekday()] + " " + date.strftime("%d/%m")
        if date.year != now.year:
            when += "/" + str(date.year)
        when += " · " + (time if time else "todo el día")

    return {
        "kind": kind,
        "kindName": name,
        "subject": {"id": subject["id"], "name": subject["name"], "dir": subject.get("dir", "")} if subject else None,
        "title": title,
        "detail": detail,
        "date": date.isoformat() if date else "",
        "time": time,
        "reminders": reminders,
        "tag": tag,
        "isNote": kind == "nota",
        "needsDate": kind != "nota" and date is None,
        "when": when,
    }


def note_path(subject_id):
    for s in subjects():
        if s["id"] == subject_id and s.get("dir"):
            return os.path.join(UNI, s["dir"], "notas.md")
    return os.path.join(DATA, "notas.md")


def save_note(text, subject_id, now=None):
    now = now or dt.datetime.now()
    text = " ".join(text.split())
    if not text:
        return {"error": "nota vacía"}
    path = note_path(subject_id)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    new = not os.path.exists(path)
    with open(path, "a") as f:
        if new:
            name = next((s["name"] for s in subjects() if s["id"] == subject_id), "Notas")
            f.write("# " + name + "\n\n")
        f.write("- " + now.strftime("%d/%m %H:%M") + " · " + text + "\n")
    return {"path": path}


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip())
        return 1
    now = None
    if "--now" in argv:
        i = argv.index("--now")
        now = dt.datetime.fromisoformat(argv[i + 1])
        del argv[i:i + 2]
    cmd = argv[1]
    if cmd == "subjects":
        # Con sus notas: cuántas hay y dónde están (para el Resumen)
        out = []
        for sub in subjects():
            path = note_path(sub["id"])
            try:
                with open(path) as f:
                    count = sum(1 for line in f if line.startswith("- "))
            except OSError:
                count = 0
            out.append(dict(sub, notes=count, notesPath=path))
        print(json.dumps(out, ensure_ascii=False))
    elif cmd == "parse" and len(argv) >= 3:
        print(json.dumps(parse(argv[2], now), ensure_ascii=False))
    elif cmd == "note" and len(argv) >= 3:
        sid = ""
        if "--subject" in argv:
            i = argv.index("--subject")
            sid = argv[i + 1]
            del argv[i:i + 2]
        print(json.dumps(save_note(argv[2], sid, now), ensure_ascii=False))
    else:
        print(__doc__.strip())
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
