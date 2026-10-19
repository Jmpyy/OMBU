"""Prueba de bin/gcal.py contra un servidor falso de Google (no toca tu cuenta ni tu HOME).
Uso: python3 tests/gcal_mock_test.py"""
import http.server, json, os, subprocess, sys, tempfile, threading, urllib.parse, time, stat, re, urllib.request

LOG = []
EVENTS = {"primary": {}, "clases": {}}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, obj=None):
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.end_headers()
        if obj is not None: self.wfile.write(json.dumps(obj).encode())
    def auth_ok(self):
        return self.headers.get("Authorization") == "Bearer AT-" + str(TOK["n"])
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); raw = self.rfile.read(n).decode()
        if self.path == "/token":
            f = urllib.parse.parse_qs(raw); LOG.append(("token", {k: v[0] for k, v in f.items()}))
            TOK["n"] += 1
            if f["grant_type"][0] == "authorization_code":
                if not f.get("code_verifier"): return self.send(400, {"error": "no pkce"})
                return self.send(200, {"access_token": "AT-%d" % TOK["n"], "refresh_token": "RT-secret", "expires_in": 3600})
            if f["refresh_token"][0] != "RT-secret": return self.send(400, {"error": "invalid_grant"})
            return self.send(200, {"access_token": "AT-%d" % TOK["n"], "expires_in": 3600})
        if not self.auth_ok(): return self.send(401, {"error": {"message": "bad token"}})
        if re.fullmatch(r"/calendars/primary/events", self.path):
            body = json.loads(raw); LOG.append(("insert", body)); body["id"] = "new1"; EVENTS["primary"]["new1"] = body
            return self.send(200, body)
        self.send(404, {})
    def do_GET(self):
        if not self.auth_ok(): return self.send(401, {"error": {"message": "bad token"}})
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query)
        if u.path == "/users/me/calendarList":
            return self.send(200, {"items": [{"id": "primary", "summary": "Juan", "selected": True, "defaultReminders": [{"method": "popup", "minutes": 30}]}, {"id": "clases", "summary": "UPE", "selected": True}, {"id": "oculto", "summary": "Oculto", "selected": False}, {"id": "es.ar#holiday@group.v.calendar.google.com", "summary": "Feriados", "selected": True}]})
        m = re.fullmatch(r"/calendars/([^/]+)/events", u.path)
        if m:
            LOG.append(("list", m.group(1), q))
            if m.group(1) == "primary":
                if "pageToken" not in q:
                    return self.send(200, {"items": [
                        {"id": "a", "summary": "Reunión", "start": {"dateTime": "2026-10-20T15:00:00-03:00"}, "end": {"dateTime": "2026-10-20T16:30:00-03:00"}},
                        {"id": "b", "summary": "Cancelado", "status": "cancelled", "start": {"dateTime": "2026-10-20T10:00:00-03:00"}, "end": {"dateTime": "2026-10-20T11:00:00-03:00"}},
                    ], "nextPageToken": "P2"})
                return self.send(200, {"items": [
                    {"id": "c", "summary": "Viaje", "start": {"date": "2026-10-23"}, "end": {"date": "2026-10-26"}},
                    {"id": "p", "summary": "Pago", "recurringEventId": "serie1", "start": {"dateTime": "2026-10-08T09:00:00-03:00"}, "end": {"dateTime": "2026-10-08T09:30:00-03:00"}, "reminders": {"useDefault": False, "overrides": [{"method": "popup", "minutes": 0}, {"method": "popup", "minutes": 1440}, {"method": "email", "minutes": 60}]}},
                    {"id": "d", "summary": "Mío", "start": {"dateTime": "2026-10-21T09:00:00-03:00"}, "end": {"dateTime": "2026-10-21T10:00:00-03:00"}, "extendedProperties": {"private": {"ombu": "1"}}},
                ]})
            return self.send(200, {"items": [{"id": "e", "summary": "Programación I", "hangoutLink": "https://meet.google.com/abc-defg-hij", "start": {"dateTime": "2026-10-19T22:00:00Z"}, "end": {"dateTime": "2026-10-20T00:00:00Z"}}]})
        m = re.fullmatch(r"/calendars/primary/events/(\w+)", u.path)
        if m:
            ev = {"a": {"id": "a"}, "d": {"id": "d", "extendedProperties": {"private": {"ombu": "1"}}}, "new1": EVENTS["primary"].get("new1", {})}.get(m.group(1))
            return self.send(200 if ev is not None else 404, ev or {})
        self.send(404, {})
    def do_DELETE(self):
        if not self.auth_ok(): return self.send(401, {"error": {"message": "bad token"}})
        LOG.append(("delete", self.path)); self.send_response(204); self.end_headers()

TOK = {"n": 0}
srv = http.server.HTTPServer(("127.0.0.1", 0), H); port = srv.server_port
threading.Thread(target=srv.serve_forever, daemon=True).start()

home = tempfile.mkdtemp(prefix="gcal-test-"); data = os.path.join(home, ".local/share/ombu"); os.makedirs(data)
json.dump({"installed": {"client_id": "cid", "client_secret": "csec", "auth_uri": "http://127.0.0.1:%d/auth" % port, "token_uri": "http://127.0.0.1:%d/token" % port}}, open(os.path.join(data, "google-client.json"), "w"))
env = dict(os.environ, HOME=home, OMBU_GCAL_API="http://127.0.0.1:%d" % port, OMBU_GCAL_NO_BROWSER="1", TZ="America/Argentina/Buenos_Aires")
gcal = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "gcal.py")
def run(*a): 
    r = subprocess.run([sys.executable, "-W", "error", gcal, *a], env=env, capture_output=True, text=True, timeout=60)
    return json.loads(r.stdout), r.stderr
ok = True
def check(name, cond, extra=""):
    global ok; ok &= bool(cond); print(("PASS " if cond else "FAIL ") + name, extra if not cond else "")

print(run("status")[0]); 
# 1) permiso: el navegador falso entra a la URL de redirección
p = subprocess.Popen([sys.executable, gcal, "auth"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
url = p.stderr.readline().strip(); q = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
check("la URL de permiso trae PKCE, offline y los dos permisos", q["code_challenge_method"] == ["S256"] and q["access_type"] == ["offline"] and "calendar.events" in q["scope"][0] and q["client_id"] == ["cid"])
time.sleep(0.5)
urllib.request.urlopen(q["redirect_uri"][0] + "/?code=XYZ&state=" + q["state"][0]).read()
o, _ = p.communicate(timeout=20); check("auth termina bien", json.loads(o).get("ok") is True, o)
tokpath = os.path.join(data, "google-token.json")
check("token guardado con permisos 600", stat.S_IMODE(os.stat(tokpath).st_mode) == 0o600)
check("el estado queda conectado", run("status")[0] == {"client": True, "connected": True})
# 2) estado falso: state incorrecto rechazado
p = subprocess.Popen([sys.executable, gcal, "auth"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
url = p.stderr.readline().strip(); q = urllib.parse.parse_qs(urllib.parse.urlparse(url).query); time.sleep(0.5)
urllib.request.urlopen(q["redirect_uri"][0] + "/?code=XYZ&state=ATAQUE").read()
o, _ = p.communicate(timeout=20); check("un state incorrecto se rechaza", "error" in json.loads(o), o)
# 3) listado
o, err = run("list", "2026-10-01", "2026-10-31"); ev = o["events"]
check("sin error ni advertencias", o["error"] is None and err == "", (o, err))
titles = [(e["date"], e["time"], e["title"]) for e in ev]
print(titles)
check("pagina y junta calendarios (sin el oculto ni el cancelado)", sorted(set(e["title"] for e in ev)) == ["Mío", "Pago", "Programación I", "Reunión", "Viaje"])
check("evento de todo el día de varios días se reparte (23, 24 y 25)", [e["date"] for e in ev if e["title"] == "Viaje"] == ["2026-10-23", "2026-10-24", "2026-10-25"])
check("no repite los calendarios de feriados de Google", len([e for e in ev if e["title"] == "Programación I"]) == 1, titles)
check("UTC pasa a hora local (22:00Z -> 19:00)", ("2026-10-19", "19:00", "Programación I") in titles)
rem = {e["title"]: e["reminders"] for e in ev}
check("avisos: propios del evento, los del calendario por defecto y 10 si no hay datos", rem.get("Pago") == [1440, 0] and rem.get("Reunión") == [30] and rem.get("Programación I") == [10], rem)
check("marca los eventos de una serie", [e["series"] for e in ev if e["title"] == "Pago"] == ["serie1"])
check("trae el link de Meet y la marca 'mío'", any(e["meet"].startswith("https://meet.google.com") for e in ev) and [e["mine"] for e in ev if e["title"] == "Mío"] == [True])
# 4) renovación: el access token vence y se renueva solo
t = json.load(open(tokpath)); t["expires_at"] = 0; json.dump(t, open(tokpath, "w"))
n0 = len([l for l in LOG if l[0] == "token"]); o, _ = run("list", "2026-10-01", "2026-10-31")
check("renueva el token vencido y sigue andando", o["error"] is None and len([l for l in LOG if l[0] == "token"]) == n0 + 1, o["error"])
# 5) crear
o, _ = run("add", "2026-10-22", "18:30", "Estudiar C", "90"); ins = [l[1] for l in LOG if l[0] == "insert"][-1]
check("crea con hora, duración y marca de ombu", o.get("ok") and ins["start"]["dateTime"].startswith("2026-10-22T18:30") and ins["end"]["dateTime"].startswith("2026-10-22T20:00") and ins["extendedProperties"]["private"]["ombu"] == "1", ins)
o, _ = run("add", "2026-10-22", "", "Todo el día"); ins = [l[1] for l in LOG if l[0] == "insert"][-1]
check("crea de todo el día", ins["start"] == {"date": "2026-10-22"} and ins["end"] == {"date": "2026-10-23"}, ins)
# 5b) repetición mensual con avisos, nota y etiqueta
o, _ = run("add", "2026-10-31", "09:00", "Pagar Gemini", "30", "--repeat", "monthly-last", "--remind", "1440,0", "--note", "5 USD", "--tag", "sub:gemini")
ins = [l[1] for l in LOG if l[0] == "insert"][-1]
check("repite el último día de cada mes con zona horaria", ins["recurrence"] == ["RRULE:FREQ=MONTHLY;BYMONTHDAY=-1"] and ins["start"]["timeZone"] and ins["start"]["dateTime"].startswith("2026-10-31T09:00"), ins)
check("avisos, nota y etiqueta viajan", ins["reminders"] == {"useDefault": False, "overrides": [{"method": "popup", "minutes": 1440}, {"method": "popup", "minutes": 0}]} and ins["description"] == "5 USD" and ins["extendedProperties"]["private"] == {"ombu": "1", "tag": "sub:gemini"}, ins)
o, _ = run("add", "2026-11-06", "09:00", "Avisar Netflix", "30", "--repeat", "monthly")
ins = [l[1] for l in LOG if l[0] == "insert"][-1]
check("mensual el mismo día", ins["recurrence"] == ["RRULE:FREQ=MONTHLY"] and ins["start"]["dateTime"].startswith("2026-11-06T09:00"), ins)
o, _ = run("add", "2026-11-30", "", "Fin de mes", "--repeat", "monthly-last")
ins = [l[1] for l in LOG if l[0] == "insert"][-1]
check("último día en un evento de todo el día", ins["start"] == {"date": "2026-11-30"} and ins["recurrence"] == ["RRULE:FREQ=MONTHLY;BYMONTHDAY=-1"], ins)
o, _ = run("add", "2026-11-30", "", "x", "--repeat", "semanal"); check("rechaza una repetición desconocida", "error" in o, o)
# 6) borrar
o, _ = run("delete", "primary", "d"); check("borra uno creado por ombu", o.get("ok") is True and any(l[0] == "delete" for l in LOG), o)
o, _ = run("delete", "primary", "a"); check("se niega a borrar uno ajeno", "error" in o and not any(l[0] == "delete" and l[1].endswith("/a") for l in LOG), o)
# 6b) permiso vencido o revocado: se borra el token y el mensaje pide volver a conectar
t = json.load(open(tokpath)); t["refresh_token"] = "RT-vencido"; t["expires_at"] = 0; json.dump(t, open(tokpath, "w"))
o, _ = run("list", "2026-10-01", "2026-10-31")
check("permiso vencido: avisa 'venció' y borra el token", "venció" in o.get("error", "") and not os.path.exists(tokpath) and run("status")[0]["connected"] is False, o)
json.dump({"refresh_token": "RT-secret", "access_token": "", "expires_at": 0}, open(tokpath, "w"))
# 7) desconectar
o, _ = run("disconnect"); check("desconecta y borra el token", not os.path.exists(tokpath) and run("status")[0]["connected"] is False)
o, _ = run("list", "2026-10-01", "2026-10-31"); check("sin sesión avisa y no revienta", "error" in o and o["error"], o)
print("\nTODO BIEN" if ok else "\nHAY FALLOS")
