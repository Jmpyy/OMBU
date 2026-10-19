#!/usr/bin/env python3
"""Lee un calendario iCal (la dirección secreta de Google Calendar o un archivo) y escribe en
la salida estándar, en JSON, los eventos entre dos fechas con las repeticiones ya expandidas.

Uso: ics.py FUENTE DESDE HASTA [CACHE]
  FUENTE   URL http(s), ruta de un archivo .ics o `env` (toma la URL de $OMBU_ICS_URL)
  DESDE    YYYY-MM-DD (inclusive)    HASTA  YYYY-MM-DD (inclusive)
  CACHE    archivo donde guardar la última descarga; si la red falla se usa ese

Salida: {"events": [{"date", "time", "end", "title", "allDay"}], "error": null | "texto"}
Las horas salen en la zona horaria del sistema. Solo se usa la biblioteca estándar."""
import json
import os
import re
import sys
import urllib.request
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

DAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
MAX_ITER = 20000


def unfold(text):
    lines = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw[:1] in (" ", "\t") and lines:
            lines[-1] += raw[1:]
        else:
            lines.append(raw)
    return lines


def unescape(v):
    return v.replace("\\n", " ").replace("\\N", " ").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")


def parse_events(text):
    events, cur = [], None
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            cur = []
        elif line == "END:VEVENT":
            if cur is not None:
                events.append(cur)
            cur = None
        elif cur is not None and ":" in line:
            head, value = line.split(":", 1)
            parts = head.split(";")
            params = {}
            for p in parts[1:]:
                if "=" in p:
                    k, v = p.split("=", 1)
                    params[k.upper()] = v.strip('"')
            cur.append((parts[0].upper(), params, value))
    return events


def get(ev, name):
    return [(p, v) for n, p, v in ev if n == name]


def to_dt(value, params, local_tz):
    """date (todo el día) o datetime con zona; las horas sin zona se toman de la local"""
    value = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        return date(int(value[:4]), int(value[4:6]), int(value[6:8]))
    d = datetime(int(value[:4]), int(value[4:6]), int(value[6:8]), int(value[9:11]), int(value[11:13]), int(value[13:15]) if len(value) >= 15 else 0)
    if value.endswith("Z"):
        return d.replace(tzinfo=timezone.utc)
    tzid = params.get("TZID")
    if tzid:
        try:
            return d.replace(tzinfo=ZoneInfo(tzid))
        except Exception:
            pass
    return d.replace(tzinfo=local_tz)


def parse_rrule(value):
    r = {}
    for part in value.split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            r[k.upper()] = v
    return r


def add_months(d, n):
    m = d.month - 1 + n
    return d.year + m // 12, m % 12 + 1


def occurrences(start, rule, limit_end):
    """Genera los comienzos de cada repetición (misma hora de pared que `start`) hasta limit_end"""
    freq = rule.get("FREQ")
    interval = int(rule.get("INTERVAL", "1"))
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until = None
    if "UNTIL" in rule:
        u = to_dt(rule["UNTIL"], {}, timezone.utc)
        until = u if isinstance(u, date) and not isinstance(u, datetime) else u.date() if isinstance(u, datetime) else u
    bydays = [b[-2:] for b in rule.get("BYDAY", "").split(",") if b]
    is_dt = isinstance(start, datetime)
    start_day = start.date() if is_dt else start
    out, n = [], 0

    def make(day):
        return datetime.combine(day, start.timetz().replace(tzinfo=None)).replace(tzinfo=start.tzinfo) if is_dt else day

    def emit(day):
        nonlocal n
        if day < start_day:
            return True
        if until and day > until:
            return False
        if count is not None and n >= count:
            return False
        n += 1
        out.append(make(day))
        return True

    for i in range(MAX_ITER):
        if freq == "DAILY":
            day = start_day + timedelta(days=i * interval)
            if day > limit_end or not emit(day):
                break
        elif freq == "WEEKLY":
            week0 = start_day - timedelta(days=start_day.weekday()) + timedelta(weeks=i * interval)
            if week0 > limit_end:
                break
            wanted = sorted(DAYS.index(b) for b in bydays) if bydays else [start_day.weekday()]
            stop = False
            for w in wanted:
                if not emit(week0 + timedelta(days=w)):
                    stop = True
                    break
            if stop:
                break
        elif freq == "MONTHLY":
            y, m = add_months(start_day, i * interval)
            if date(y, m, 1) > limit_end:
                break
            try:
                day = date(y, m, int(rule.get("BYMONTHDAY", start_day.day)))
            except ValueError:
                continue
            if not emit(day):
                break
        elif freq == "YEARLY":
            try:
                day = start_day.replace(year=start_day.year + i * interval)
            except ValueError:
                continue
            if day > limit_end or not emit(day):
                break
        else:
            emit(start_day)
            break
    return out


def run(text, since, until_day):
    local_tz = datetime.now().astimezone().tzinfo
    raw = parse_events(text)
    overrides = {}
    for ev in raw:
        rid = get(ev, "RECURRENCE-ID")
        uid = get(ev, "UID")
        if rid and uid:
            overrides[(uid[0][1], to_dt(rid[0][1], rid[0][0], local_tz))] = ev

    result = []

    def add(start, end, title):
        all_day = not isinstance(start, datetime)
        if all_day:
            last = (end - timedelta(days=1)) if isinstance(end, date) and end > start else start
            d = start
            for _ in range(14):
                if d > last:
                    break
                if since <= d <= until_day:
                    result.append({"date": d.isoformat(), "time": "", "end": "", "title": title, "allDay": True})
                d += timedelta(days=1)
            return
        s = start.astimezone(local_tz)
        if since <= s.date() <= until_day:
            e = end.astimezone(local_tz).strftime("%H:%M") if isinstance(end, datetime) else ""
            result.append({"date": s.date().isoformat(), "time": s.strftime("%H:%M"), "end": e, "title": title, "allDay": False})

    for ev in raw:
        if get(ev, "RECURRENCE-ID") or any(v.strip().upper() == "CANCELLED" for _, v in get(ev, "STATUS")):
            continue
        ds = get(ev, "DTSTART")
        if not ds:
            continue
        start = to_dt(ds[0][1], ds[0][0], local_tz)
        de = get(ev, "DTEND")
        dur = get(ev, "DURATION")
        if de:
            end = to_dt(de[0][1], de[0][0], local_tz)
        elif dur:
            m = re.fullmatch(r"P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?", dur[0][1])
            g = [int(x or 0) for x in m.groups()] if m else [0, 0, 0, 0]
            delta = timedelta(weeks=g[0], days=g[1], hours=g[2], minutes=g[3])
            end = start + delta
        else:
            end = start
        title = unescape(get(ev, "SUMMARY")[0][1]) if get(ev, "SUMMARY") else "(sin título)"
        uid = get(ev, "UID")[0][1] if get(ev, "UID") else ""
        rr = get(ev, "RRULE")
        if not rr:
            add(start, end, title)
            continue
        skip = set()
        for p, v in get(ev, "EXDATE"):
            for one in v.split(","):
                skip.add(to_dt(one, p, local_tz))
        length = end - start
        for occ in occurrences(start, parse_rrule(rr[0][1]), until_day + timedelta(days=1)):
            if occ in skip:
                continue
            ov = overrides.get((uid, occ))
            if ov is not None:
                ods = get(ov, "DTSTART")
                ode = get(ov, "DTEND")
                if any(v.strip().upper() == "CANCELLED" for _, v in get(ov, "STATUS")) or not ods:
                    continue
                ostart = to_dt(ods[0][1], ods[0][0], local_tz)
                oend = to_dt(ode[0][1], ode[0][0], local_tz) if ode else ostart
                otitle = unescape(get(ov, "SUMMARY")[0][1]) if get(ov, "SUMMARY") else title
                add(ostart, oend, otitle)
            else:
                add(occ, occ + length, title)

    result.sort(key=lambda e: (e["date"], e["time"] or "00:00"))
    return result


def main():
    if len(sys.argv) < 4:
        print(json.dumps({"events": [], "error": "uso: ics.py FUENTE DESDE HASTA [CACHE]"}))
        return
    source, since, until_day = sys.argv[1], date.fromisoformat(sys.argv[2]), date.fromisoformat(sys.argv[3])
    if source == "env":
        # La dirección secreta viaja por el entorno y no por los argumentos, que se ven con `ps`
        source = os.environ.get("OMBU_ICS_URL", "")
    cache = sys.argv[4] if len(sys.argv) > 4 else ""
    text, error = "", None
    try:
        if re.match(r"https?://", source):
            req = urllib.request.Request(source, headers={"User-Agent": "ombu"})
            with urllib.request.urlopen(req, timeout=20) as r:
                text = r.read().decode("utf-8", "replace")
            if "BEGIN:VCALENDAR" not in text:
                raise ValueError("la dirección no devolvió un calendario")
            if cache:
                with open(cache, "w", encoding="utf-8") as f:
                    f.write(text)
        else:
            with open(source, encoding="utf-8") as f:
                text = f.read()
    except Exception as e:
        error = str(e)
        if cache:
            try:
                with open(cache, encoding="utf-8") as f:
                    text = f.read()
            except OSError:
                pass
    events = []
    if text:
        try:
            events = run(text, since, until_day)
        except Exception as e:
            error = "no se pudo leer el calendario: %s" % e
    print(json.dumps({"events": events, "error": error}, ensure_ascii=False))


if __name__ == "__main__":
    main()
