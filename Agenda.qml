pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Agenda del calendario: eventos propios, los de Google Calendar (por la dirección secreta en
// formato iCal, solo lectura), los feriados de Argentina y los recordatorios con hora.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string dataDir: home + "/.local/share/ombu"
    readonly property string cacheDir: home + "/.cache/ombu"
    readonly property string ombuDir: home + "/.config/quickshell/ombu"

    readonly property color holidayColor: Theme.danger
    readonly property color localColor: Theme.warn
    readonly property color googleColor: "#60a5fa"
    readonly property color studyColor: "#4ade80"

    // Eventos propios: [{id, date, time, title, done}]
    property var local: []
    // Eventos de Google: [{date, time, end, title, allDay}]
    property var google: []
    // Feriados: "yyyy-MM-dd" -> nombre
    property var holidays: ({})

    property string googleUrl: ""
    // API de Google (bin/gcal.py): hay credenciales / hay sesión / esperando el permiso en el navegador
    property bool apiClient: false
    property bool apiConnected: false
    property bool apiAuthing: false
    property string apiError: ""
    // Al anotar un evento, ¿va a Google (y al celular) o queda solo en ombu?
    property bool createInGoogle: true
    readonly property bool googleOn: apiConnected || googleUrl !== ""
    property string googleError: ""
    property bool googleLoading: false
    property double googleAt: 0

    // "Ahora" al minuto: lo usan las listas que dependen de la hora, sin recalcular cada segundo
    property date now: new Date()
    property var fired: ({})

    // Días con algo para marcar: "yyyy-MM-dd" -> {holiday, local, google, study}
    readonly property var byDay: {
        const map = {};
        const mark = (day, kind) => {
            if (!map[day])
                map[day] = {};
            map[day][kind] = true;
        };
        for (const d in holidays)
            mark(d, "holiday");
        for (const e of local)
            mark(e.date, "local");
        for (const e of google)
            mark(e.date, "google");
        for (const d in Focus.history) {
            if (Focus.history[d] >= 5)
                mark(d, "study");
        }
        return map;
    }

    function ymd(d: date): string {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function parseDay(s: string): date {
        return new Date(s + "T12:00:00");
    }

    // Todo lo de un día, en orden: feriado, eventos de todo el día y los que tienen hora
    function itemsFor(day: string): var {
        const out = [];
        if (holidays[day])
            out.push({
                kind: "holiday",
                time: "",
                title: holidays[day]
            });
        const timed = [];
        for (const e of google) {
            if (e.date === day)
                (e.time ? timed : out).push({
                    kind: "google",
                    id: e.id ?? "",
                    calendarId: e.calendarId ?? "",
                    mine: e.mine ?? false,
                    meet: e.meet ?? "",
                    time: e.time,
                    end: e.end,
                    title: e.title
                });
        }
        for (const e of local) {
            if (e.date === day)
                (e.time ? timed : out).push({
                    kind: "local",
                    id: e.id,
                    time: e.time,
                    title: e.title,
                    done: e.done
                });
        }
        timed.sort((a, b) => a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
        return out.concat(timed);
    }

    // Lo que viene: los próximos eventos (sin feriados ni terminados), empezando por lo de hoy que no pasó
    function upcoming(count: int): var {
        const out = [];
        const hhmm = Qt.formatTime(now, "HH:mm");
        const todayStr = ymd(now);
        for (let i = 0; i < 60 && out.length < count; i++) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, 12);
            const day = ymd(d);
            for (const it of itemsFor(day)) {
                if (it.kind === "holiday" || it.done)
                    continue;
                if (day === todayStr && it.time && it.time < hhmm)
                    continue;
                out.push({
                    day: day,
                    kind: it.kind,
                    time: it.time,
                    title: it.title
                });
                if (out.length >= count)
                    break;
            }
        }
        return out;
    }

    function studyMinutes(day: string): int {
        return Focus.history[day] ?? 0;
    }

    function add(day: string, time: string, title: string): void {
        const t = title.trim();
        if (t === "")
            return;
        let hhmm = "";
        const m = time.trim().match(/^(\d{1,2})(?::|\.|h)?(\d{2})$/);
        if (m && parseInt(m[1]) < 24 && parseInt(m[2]) < 60)
            hhmm = m[1].padStart(2, "0") + ":" + m[2];
        if (apiConnected && createInGoogle) {
            gcal(["add", day, hhmm, t], r => {
                if (r.error)
                    googleError = r.error;
                refreshGoogle(true);
            });
            return;
        }
        local = local.concat([
            {
                id: Date.now() + "-" + Math.floor(Math.random() * 1000),
                date: day,
                time: hhmm,
                title: t,
                done: false
            }
        ]);
        saveLocal();
    }

    function toggle(id: string): void {
        local = local.map(e => e.id === id ? Object.assign({}, e, {
                done: !e.done
            }) : e);
        saveLocal();
    }

    function remove(id: string): void {
        local = local.filter(e => e.id !== id);
        saveLocal();
    }

    // Borra un evento de Google que creó ombu (los ajenos no se tocan)
    function removeGoogle(calendarId: string, id: string): void {
        gcal(["delete", calendarId, id], r => {
            if (r.error)
                googleError = r.error;
            refreshGoogle(true);
        });
    }

    function saveLocal(): void {
        localFile.setText(JSON.stringify(local, null, 2) + "\n");
    }

    function setUrl(url: string): void {
        googleUrl = url.trim();
        googleError = "";
        if (googleUrl === "")
            google = [];
        saveConfig();
        refreshGoogle(true);
    }

    function setCreateInGoogle(on: bool): void {
        createInGoogle = on;
        saveConfig();
    }

    function saveConfig(): void {
        configFile.setText(JSON.stringify({
            url: googleUrl,
            createInGoogle: createInGoogle
        }));
        // La dirección es un secreto: el archivo solo lo lee el usuario
        Quickshell.execDetached(["sh", "-c", "sleep 1; chmod 600 \"$1\"", "permisos", configFile.path]);
    }

    // Corre bin/gcal.py y entrega su respuesta JSON a `done`
    function gcal(args: var, done: var): void {
        const p = gcalComponent.createObject(root, {
            command: [ombuDir + "/bin/gcal.py"].concat(args),
            done: done
        });
        p.running = true;
    }

    function refreshApiStatus(): void {
        gcal(["status"], r => {
            apiClient = r.client === true;
            apiConnected = r.connected === true;
            if (apiConnected)
                refreshGoogle(true);
        });
    }

    // Abre el navegador para dar el permiso; al volver queda conectado
    function connectApi(): void {
        if (apiAuthing)
            return;
        apiAuthing = true;
        apiError = "";
        gcal(["auth"], r => {
            apiAuthing = false;
            if (r.error)
                apiError = r.error;
            refreshApiStatus();
        });
    }

    function disconnectApi(): void {
        gcal(["disconnect"], r => {
            apiConnected = false;
            google = [];
            googleError = "";
            refreshApiStatus();
        });
    }

    function refreshGoogle(force: bool): void {
        if (!googleOn || googleLoading)
            return;
        if (!force && Date.now() - googleAt < 5 * 60000)
            return;
        const from = new Date(now.getFullYear(), now.getMonth() - 2, 1, 12);
        const to = new Date(now.getFullYear(), now.getMonth() + 14, 0, 12);
        googleLoading = true;
        if (apiConnected) {
            gcal(["list", ymd(from), ymd(to)], r => {
                googleLoading = false;
                googleAt = Date.now();
                google = r.events ?? [];
                googleError = r.error ?? "";
            });
            return;
        }
        fetcher.command = ["python3", ombuDir + "/bin/ics.py", "env", ymd(from), ymd(to), cacheDir + "/google.ics"];
        fetcher.running = true;
    }

    // Recordatorios: los propios suenan a la hora; los de Google, 10 minutos antes
    function check(): void {
        now = new Date();
        const day = ymd(now);
        const minutes = now.getHours() * 60 + now.getMinutes();
        for (const it of itemsFor(day)) {
            if (!it.time || it.done || it.kind === "holiday")
                continue;
            const key = day + "|" + it.kind + "|" + it.time + "|" + it.title;
            if (fired[key])
                continue;
            const at = parseInt(it.time.slice(0, 2)) * 60 + parseInt(it.time.slice(3));
            const lead = it.kind === "google" ? 10 : 0;
            if (minutes >= at - lead && minutes <= at + 5) {
                fired[key] = true;
                const left = at - minutes;
                Quickshell.execDetached(["notify-send", "-a", "Agenda", "-i", "appointment-soon", it.title, left > 0 ? "Empieza en " + left + " min (" + it.time + ")" : "Es ahora (" + it.time + ")"]);
            }
        }
    }

    function loadHolidays(year: int): void {
        const proc = holidayComponent.createObject(root, {
            command: [ombuDir + "/bin/feriados.sh", String(year)]
        });
        proc.running = true;
    }

    Component {
        id: holidayComponent

        Process {
            id: proc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const list = JSON.parse(text);
                        const merged = Object.assign({}, root.holidays);
                        for (const h of list)
                            merged[h.date] = h.localName;
                        root.holidays = merged;
                    } catch (e) {}
                    proc.destroy();
                }
            }
        }
    }

    Component {
        id: gcalComponent

        Process {
            id: gproc

            property var done

            stdout: StdioCollector {
                onStreamFinished: {
                    let r = {};
                    try {
                        r = JSON.parse(text);
                    } catch (e) {
                        r = {
                            error: "respuesta inválida de gcal.py"
                        };
                    }
                    if (gproc.done)
                        gproc.done(r);
                    gproc.destroy();
                }
            }
        }
    }

    Process {
        id: fetcher

        environment: ({
                OMBU_ICS_URL: root.googleUrl
            })
        stdout: StdioCollector {
            onStreamFinished: {
                root.googleLoading = false;
                root.googleAt = Date.now();
                try {
                    const r = JSON.parse(text);
                    root.google = r.events ?? [];
                    root.googleError = r.error ?? "";
                } catch (e) {
                    root.googleError = "respuesta inválida";
                }
            }
        }
    }

    FileView {
        id: localFile

        path: root.dataDir + "/agenda.json"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: configFile

        path: root.dataDir + "/calendario.json"
        blockLoading: true
        printErrors: false
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.check()
    }

    // Refresca Google: cada 5 minutos con la API (es barata) y cada 30 con la dirección iCal
    Timer {
        running: root.googleOn
        repeat: true
        interval: root.apiConnected ? 5 * 60000 : 30 * 60000
        onTriggered: root.refreshGoogle(true)
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", dataDir, cacheDir]);
        try {
            const saved = JSON.parse(localFile.text());
            if (Array.isArray(saved))
                local = saved;
        } catch (e) {}
        try {
            const cfg = JSON.parse(configFile.text());
            if (typeof cfg.url === "string")
                googleUrl = cfg.url;
            if (typeof cfg.createInGoogle === "boolean")
                createInGoogle = cfg.createInGoogle;
        } catch (e) {}
        loadHolidays(now.getFullYear());
        loadHolidays(now.getFullYear() + 1);
        refreshApiStatus();
        refreshGoogle(true);
    }
}
