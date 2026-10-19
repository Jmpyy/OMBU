#!/usr/bin/env python3
"""Google Calendar para ombu, por la API oficial (OAuth de aplicación de escritorio).

Uso: gcal.py status | auth | calendars | list DESDE HASTA | add DIA HORA TITULO [MINUTOS] [opciones] | delete CAL ID | disconnect
  status      ¿hay credenciales y sesión? -> {"client": bool, "connected": bool}
  auth        abre el navegador para dar permiso y guarda el token
  calendars   tus calendarios -> {"calendars": [{id, name, role, primary}], "error": null | "texto"}
  list        eventos entre dos fechas (YYYY-MM-DD) de todos tus calendarios, con las repeticiones
              ya expandidas por Google -> {"events": [...], "error": null | "texto"}
  add         crea un evento en el calendario principal (HORA vacía = todo el día). Opciones:
                --repeat monthly|monthly-last|yearly   se repite (monthly-last = el último día de cada mes)
                --remind 1440,0                        avisos en minutos antes (por defecto los del calendario)
                --note TEXTO                           descripción del evento
                --tag ETIQUETA                         marca privada para reconocerlo después
                --calendar ID                          calendario donde crearlo (por defecto el principal)
  delete      borra un evento que creó ombu (los ajenos no se tocan)
  disconnect  borra el token y lo revoca en Google

Archivos en ~/.local/share/ombu (solo legibles por el usuario, nunca van al repo):
  google-client.json   las credenciales que bajás de la consola de Google
  google-token.json    el token de acceso y el de renovación
Solo biblioteca estándar. Salida siempre en JSON; los errores salen como {"error": "..."}.
Variables para probar contra un servidor falso: OMBU_GCAL_API, OMBU_GCAL_TOKEN_URI."""
import base64
import hashlib
import http.server
import json
import os
import secrets
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta

SCOPES = "https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/calendar.calendarlist.readonly"
API = os.environ.get("OMBU_GCAL_API", "https://www.googleapis.com/calendar/v3")
DATA = os.path.join(os.environ.get("HOME", ""), ".local", "share", "ombu")
CLIENT = os.path.join(DATA, "google-client.json")
TOKEN = os.path.join(DATA, "google-token.json")
LOCAL_TZ = datetime.now().astimezone().tzinfo


def tz_name():
    """Nombre de la zona horaria del sistema (Google la pide para los eventos que se repiten)"""
    try:
        target = os.path.realpath("/etc/localtime")
        if "zoneinfo/" in target:
            return target.split("zoneinfo/", 1)[1]
    except OSError:
        pass
    return os.environ.get("TZ", "UTC")


class Fail(Exception):
    pass


def out(obj):
    print(json.dumps(obj, ensure_ascii=False))


def load_client():
    try:
        with open(CLIENT, encoding="utf-8") as f:
            raw = json.load(f)
    except OSError:
        raise Fail("Falta el archivo de credenciales: %s" % CLIENT)
    except ValueError:
        raise Fail("El archivo de credenciales no es un JSON válido")
    c = raw.get("installed") or raw.get("web")
    if not c or "client_id" not in c:
        raise Fail("El archivo de credenciales no parece de una app de escritorio")
    return c


def load_token():
    try:
        with open(TOKEN, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def save_token(tok):
    os.makedirs(DATA, exist_ok=True)
    fd = os.open(TOKEN, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(tok, f)


def post_form(url, fields):
    data = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode())
        except ValueError:
            body = {}
        raise Fail(body.get("error_description") or body.get("error") or "Google respondió %s" % e.code)


def token_uri(client):
    return os.environ.get("OMBU_GCAL_TOKEN_URI") or client.get("token_uri", "https://oauth2.googleapis.com/token")


def access_token():
    tok = load_token()
    if not tok or "refresh_token" not in tok:
        raise Fail("Todavía no conectaste Google Calendar")
    if tok.get("access_token") and tok.get("expires_at", 0) - 60 > time.time():
        return tok["access_token"]
    client = load_client()
    try:
        fresh = post_form(token_uri(client), {
            "client_id": client["client_id"],
            "client_secret": client.get("client_secret", ""),
            "refresh_token": tok["refresh_token"],
            "grant_type": "refresh_token",
        })
    except Fail as e:
        # Con la app en modo Prueba Google vence el permiso a los 7 días: se borra el token para
        # que ombu ofrezca conectar de nuevo en lugar de seguir fallando
        if "invalid_grant" in str(e) or "expired" in str(e).lower() or "revoked" in str(e).lower():
            try:
                os.remove(TOKEN)
            except OSError:
                pass
            raise Fail("La sesión de Google venció: volvé a conectar")
        raise Fail("No se pudo renovar el permiso de Google (%s)" % e)
    tok["access_token"] = fresh["access_token"]
    tok["expires_at"] = time.time() + int(fresh.get("expires_in", 3600))
    save_token(tok)
    return tok["access_token"]


def api(method, path, params=None, body=None):
    url = API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": "Bearer " + access_token()}
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            raw = r.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        try:
            msg = json.loads(e.read().decode()).get("error", {}).get("message", "")
        except ValueError:
            msg = ""
        raise Fail("Google respondió %s%s" % (e.code, ": " + msg if msg else ""))
    except urllib.error.URLError as e:
        raise Fail("Sin conexión (%s)" % e.reason)


def cmd_status():
    try:
        load_client()
        client = True
    except Fail:
        client = False
    tok = load_token()
    out({"client": client, "connected": bool(tok and tok.get("refresh_token"))})


def cmd_auth():
    client = load_client()
    verifier = base64.urlsafe_b64encode(secrets.token_bytes(48)).rstrip(b"=").decode()
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "code" in q or "error" in q:
                result.update({k: v[0] for k, v in q.items()})
                ok = "code" in q and q.get("state", [""])[0] == state
                body = ("<meta charset=utf-8><body style='font-family:sans-serif;background:#14131a;color:#e8e8f0;text-align:center;padding-top:20vh'>"
                        + ("<h2>Listo, ya podés cerrar esta pestaña</h2><p>ombu quedó conectado a tu Google Calendar.</p>" if ok else "<h2>No se pudo conectar</h2><p>Volvé a intentarlo desde ombu.</p>")).encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_response(404)
                self.end_headers()

        def log_message(self, *a):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    redirect = "http://127.0.0.1:%d" % server.server_port
    url = client.get("auth_uri", "https://accounts.google.com/o/oauth2/v2/auth") + "?" + urllib.parse.urlencode({
        "client_id": client["client_id"], "redirect_uri": redirect, "response_type": "code", "scope": SCOPES,
        "code_challenge": challenge, "code_challenge_method": "S256", "access_type": "offline",
        "prompt": "consent", "state": state,
    })
    if os.environ.get("OMBU_GCAL_NO_BROWSER"):
        print(url, file=sys.stderr)
    else:
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    server.timeout = 1
    deadline = time.time() + 240
    while not result and time.time() < deadline:
        server.handle_request()
    server.server_close()
    if "code" not in result or result.get("state") != state:
        raise Fail("No se completó el permiso en el navegador" if not result.get("error") else "Google rechazó el permiso (%s)" % result["error"])
    tok = post_form(token_uri(client), {
        "code": result["code"], "client_id": client["client_id"], "client_secret": client.get("client_secret", ""),
        "redirect_uri": redirect, "grant_type": "authorization_code", "code_verifier": verifier,
    })
    if "refresh_token" not in tok:
        raise Fail("Google no entregó el token de renovación; revocá el acceso de ombu en tu cuenta y reintentá")
    save_token({"refresh_token": tok["refresh_token"], "access_token": tok.get("access_token", ""),
                "expires_at": time.time() + int(tok.get("expires_in", 3600))})
    out({"ok": True})


def rfc3339(d, end_of_day=False):
    dt = datetime(d.year, d.month, d.day, tzinfo=LOCAL_TZ)
    if end_of_day:
        dt += timedelta(days=1)
    return dt.isoformat()


def normalize(ev, cal, since, until_day):
    if ev.get("status") == "cancelled":
        return []
    title = ev.get("summary") or "(sin título)"
    meet = ev.get("hangoutLink") or ""
    if not meet:
        for ep in (ev.get("conferenceData") or {}).get("entryPoints", []):
            if ep.get("entryPointType") == "video":
                meet = ep.get("uri", "")
                break
    rem = ev.get("reminders") or {}
    if rem.get("useDefault", True):
        pool = cal.get("defaultReminders") or []
    else:
        pool = rem.get("overrides") or []
    reminders = sorted({int(r["minutes"]) for r in pool if r.get("method", "popup") == "popup" and "minutes" in r}, reverse=True)
    base = {"title": title, "calendar": cal.get("summary", ""), "calendarId": cal["id"], "id": ev.get("id", ""),
            "reminders": reminders if (reminders or not rem.get("useDefault", True)) else [10],
            "series": ev.get("recurringEventId", ""),
            "mine": ((ev.get("extendedProperties") or {}).get("private") or {}).get("ombu") == "1", "meet": meet}
    s, e = ev.get("start", {}), ev.get("end", {})
    res = []
    if "date" in s:
        d = date.fromisoformat(s["date"])
        last = date.fromisoformat(e["date"]) - timedelta(days=1) if "date" in e else d
        for _ in range(14):
            if d > last:
                break
            if since <= d <= until_day:
                res.append(dict(base, date=d.isoformat(), time="", end="", allDay=True))
            d += timedelta(days=1)
    elif "dateTime" in s:
        st = datetime.fromisoformat(s["dateTime"]).astimezone(LOCAL_TZ)
        en = datetime.fromisoformat(e["dateTime"]).astimezone(LOCAL_TZ) if "dateTime" in e else None
        if since <= st.date() <= until_day:
            res.append(dict(base, date=st.date().isoformat(), time=st.strftime("%H:%M"),
                            end=en.strftime("%H:%M") if en else "", allDay=False))
    return res


def visible_calendars():
    """Calendarios que se muestran, sin los de feriados de Google (ombu trae los suyos)"""
    try:
        cals = [c for c in api("GET", "/users/me/calendarList").get("items", []) if c.get("selected", True) and not c.get("deleted")]
    except Fail as e:
        # Sin la lista de calendarios (permiso de más) se sigue con el principal; pero si la sesión
        # venció o no hay red, ese es el error que hay que mostrar
        if "venció" in str(e) or "Sin conexión" in str(e):
            raise
        cals = []
    cals = [c for c in cals if not c.get("id", "").endswith("#holiday@group.v.calendar.google.com")]
    return cals or [{"id": "primary", "summary": "Principal"}]


def cmd_calendars():
    out({"calendars": [{"id": c["id"], "name": c.get("summaryOverride") or c.get("summary", ""), "role": c.get("accessRole", ""),
                        "primary": bool(c.get("primary"))} for c in visible_calendars()], "error": None})


def cmd_list(since, until_day):
    events = []
    for cal in visible_calendars():
        page = None
        while True:
            params = {"timeMin": rfc3339(since), "timeMax": rfc3339(until_day, True), "singleEvents": "true",
                      "orderBy": "startTime", "maxResults": "2500"}
            if page:
                params["pageToken"] = page
            data = api("GET", "/calendars/%s/events" % urllib.parse.quote(cal["id"], safe=""), params)
            for ev in data.get("items", []):
                events.extend(normalize(ev, cal, since, until_day))
            page = data.get("nextPageToken")
            if not page:
                break
    events.sort(key=lambda e: (e["date"], e["time"] or "00:00"))
    out({"events": events, "error": None})


def last_day(d):
    nxt = date(d.year + (d.month == 12), d.month % 12 + 1, 1)
    return nxt - timedelta(days=1)


def cmd_add(day, hhmm, title, *rest):
    minutes, opts, i = 60, {}, 0
    rest = list(rest)
    if rest and not rest[0].startswith("--"):
        minutes = int(rest.pop(0))
    while i < len(rest):
        if rest[i].startswith("--") and i + 1 < len(rest):
            opts[rest[i][2:]] = rest[i + 1]
            i += 2
        else:
            raise Fail("opción inválida: %s" % rest[i])
    d = date.fromisoformat(day)
    repeat = opts.get("repeat")
    rules = {"monthly": "RRULE:FREQ=MONTHLY", "monthly-last": "RRULE:FREQ=MONTHLY;BYMONTHDAY=-1", "yearly": "RRULE:FREQ=YEARLY"}
    if repeat and repeat not in rules:
        raise Fail("repetición inválida: %s" % repeat)
    if repeat == "monthly-last":
        d = last_day(d)
    private = {"ombu": "1"}
    if opts.get("tag"):
        private["tag"] = opts["tag"]
    body = {"summary": title, "extendedProperties": {"private": private}}
    if opts.get("note"):
        body["description"] = opts["note"]
    if opts.get("remind"):
        body["reminders"] = {"useDefault": False, "overrides": [{"method": "popup", "minutes": int(m)} for m in opts["remind"].split(",") if m != ""]}
    else:
        body["reminders"] = {"useDefault": True}
    if hhmm:
        h, m = hhmm.split(":")
        start = datetime(d.year, d.month, d.day, int(h), int(m), tzinfo=LOCAL_TZ)
        body["start"] = {"dateTime": start.isoformat()}
        body["end"] = {"dateTime": (start + timedelta(minutes=int(minutes))).isoformat()}
        if repeat:
            body["start"]["timeZone"] = body["end"]["timeZone"] = tz_name()
    else:
        body["start"] = {"date": d.isoformat()}
        body["end"] = {"date": (d + timedelta(days=1)).isoformat()}
    if repeat:
        body["recurrence"] = [rules[repeat]]
    cal = opts.get("calendar") or "primary"
    created = api("POST", "/calendars/%s/events" % urllib.parse.quote(cal, safe=""), body=body)
    out({"ok": True, "id": created.get("id", ""), "calendarId": cal})


def cmd_delete(cal, event_id):
    got = api("GET", "/calendars/%s/events/%s" % (urllib.parse.quote(cal, safe=""), urllib.parse.quote(event_id, safe="")))
    if ((got.get("extendedProperties") or {}).get("private") or {}).get("ombu") != "1":
        raise Fail("Ese evento no lo creó ombu: borralo desde Google Calendar")
    api("DELETE", "/calendars/%s/events/%s" % (urllib.parse.quote(cal, safe=""), urllib.parse.quote(event_id, safe="")))
    out({"ok": True})


def cmd_disconnect():
    tok = load_token()
    if tok and tok.get("refresh_token"):
        try:
            post_form("https://oauth2.googleapis.com/revoke", {"token": tok["refresh_token"]})
        except Exception:
            pass
    try:
        os.remove(TOKEN)
    except OSError:
        pass
    out({"ok": True})


def main():
    a = sys.argv[1:]
    try:
        if not a:
            raise Fail("uso: gcal.py status|auth|list|add|delete|disconnect")
        if a[0] == "status":
            cmd_status()
        elif a[0] == "auth":
            cmd_auth()
        elif a[0] == "calendars":
            cmd_calendars()
        elif a[0] == "list" and len(a) >= 3:
            cmd_list(date.fromisoformat(a[1]), date.fromisoformat(a[2]))
        elif a[0] == "add" and len(a) >= 4:
            cmd_add(*a[1:])
        elif a[0] == "delete" and len(a) >= 3:
            cmd_delete(a[1], a[2])
        elif a[0] == "disconnect":
            cmd_disconnect()
        else:
            raise Fail("comando o argumentos inválidos")
    except Fail as e:
        out({"error": str(e), "events": []})
    except Exception as e:
        out({"error": "error inesperado: %s" % e, "events": []})


if __name__ == "__main__":
    main()
