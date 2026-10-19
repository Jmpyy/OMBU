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
    property bool sessionNotified: false
    // Al anotar un evento, ¿va a Google (y al celular) o queda solo en ombu?
    property bool createInGoogle: true
    // Calendarios de la cuenta [{id, name, role, primary}] y los que se ocultan (ids)
    property var calendars: []
    property var hidden: []
    // Calendarios «en silencio»: se ven en el calendario pero no salen en el Resumen, en «Próximos» ni
    // mandan avisos (salvo los recordatorios de pagos, que llevan la etiqueta «sub:»). null = nunca se
    // configuró: por defecto el de la familia.
    property var quiet: null
    readonly property var quietIds: quiet !== null ? quiet : (familyCalendarId !== "" ? [familyCalendarId] : [])
    // El calendario compartido de la familia, si existe y se puede escribir en él
    readonly property string familyCalendarId: {
        const c = calendars.find(x => /famili/i.test(x.name) && (x.role === "owner" || x.role === "writer"));
        return c ? c.id : "";
    }
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
        for (const e of local) {
            if (!e.repeat) {
                mark(e.date, "local");
                continue;
            }
            // Repetidos: se marcan los próximos 14 meses
            const start = parseDay(e.date);
            for (let i = 0; i < 430; i++) {
                const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i, 12);
                const day = ymd(d);
                if (localMatches(e, day))
                    mark(day, "local");
            }
        }
        for (const e of google) {
            if (!hidden.includes(e.calendarId))
                mark(e.date, "google");
        }
        for (const d in Focus.history) {
            if (Focus.history[d] >= 5)
                mark(d, "study");
        }
        return map;
    }

    // ¿Un evento propio cae en este día? Los que se repiten: cada mes el mismo día, el último día de
    // cada mes o cada año
    function localMatches(e: var, day: string): bool {
        if (!e.repeat)
            return e.date === day;
        if (day < e.date)
            return false;
        const d = parseDay(day);
        const b = parseDay(e.date);
        if (e.repeat === "monthly")
            return d.getDate() === b.getDate();
        if (e.repeat === "monthly-last")
            return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate() === d.getDate();
        if (e.repeat === "yearly")
            return d.getDate() === b.getDate() && d.getMonth() === b.getMonth();
        return false;
    }

    function ymd(d: date): string {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function parseDay(s: string): date {
        return new Date(s + "T12:00:00");
    }

    function isQuiet(e: var): bool {
        return quietIds.includes(e.calendarId ?? "") && !(e.tag ?? "").startsWith("sub:");
    }

    // Todo lo de un día, en orden: feriado, eventos de todo el día y los que tienen hora. Con
    // summary = true se saltean los calendarios en silencio (Resumen, «Próximos» y avisos).
    function itemsFor(day: string, summary): var {
        const out = [];
        if (holidays[day])
            out.push({
                kind: "holiday",
                time: "",
                title: holidays[day]
            });
        const timed = [];
        for (const e of google) {
            if (e.date === day && !hidden.includes(e.calendarId) && !(summary === true && isQuiet(e)))
                (e.time ? timed : out).push({
                    kind: "google",
                    id: e.id ?? "",
                    calendarId: e.calendarId ?? "",
                    tag: e.tag ?? "",
                    mine: e.mine ?? false,
                    meet: e.meet ?? "",
                    series: e.series ?? "",
                    reminders: e.reminders ?? [10],
                    time: e.time,
                    end: e.end,
                    title: e.title
                });
        }
        for (const e of local) {
            if (localMatches(e, day))
                (e.time ? timed : out).push({
                    kind: "local",
                    id: e.id,
                    time: e.time,
                    title: e.title,
                    done: e.repeat ? false : e.done,
                    repeat: e.repeat ?? "",
                    reminders: e.reminders ?? [0]
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
            for (const it of itemsFor(day, true)) {
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

    // extra (opcional): {note, tag, done(respuesta)}; tag marca el evento para reconocerlo después
    function add(day: string, time: string, title: string, repeat: string, reminders: var, extra: var): void {
        const t = title.trim();
        if (t === "")
            return;
        let hhmm = "";
        const m = time.trim().match(/^(\d{1,2})(?::|\.|h)?(\d{2})$/);
        if (m && parseInt(m[1]) < 24 && parseInt(m[2]) < 60)
            hhmm = m[1].padStart(2, "0") + ":" + m[2];
        if (apiConnected && createInGoogle) {
            const args = ["add", day, hhmm, t, "30"];
            if (repeat)
                args.push("--repeat", repeat);
            if (reminders && !(reminders.length === 1 && reminders[0] === 0))
                args.push("--remind", reminders.join(","));
            if (extra?.note)
                args.push("--note", extra.note);
            if (extra?.tag)
                args.push("--tag", extra.tag);
            if (extra?.calendar)
                args.push("--calendar", extra.calendar);
            gcal(args, r => {
                if (r.error)
                    googleError = r.error;
                if (extra?.done)
                    extra.done(r);
                refreshGoogle(true);
            });
            return;
        }
        const localId = Date.now() + "-" + Math.floor(Math.random() * 1000);
        local = local.concat([
            {
                id: localId,
                tag: extra?.tag ?? "",
                date: day,
                time: hhmm,
                title: t,
                done: false,
                repeat: repeat ?? "",
                reminders: reminders ?? [0]
            }
        ]);
        saveLocal();
        if (extra?.done)
            extra.done({
                id: localId,
                local: true
            });
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

    // Mostrar u ocultar un calendario de Google (se recuerda)
    function toggleCalendar(id: string): void {
        hidden = hidden.includes(id) ? hidden.filter(x => x !== id) : hidden.concat([id]);
        saveConfig();
    }

    // Poner o sacar un calendario del Resumen y de los avisos (se recuerda)
    function toggleQuiet(id: string): void {
        quiet = quietIds.includes(id) ? quietIds.filter(x => x !== id) : quietIds.concat([id]);
        saveConfig();
    }

    function setCreateInGoogle(on: bool): void {
        createInGoogle = on;
        saveConfig();
    }

    function saveConfig(): void {
        configFile.setText(JSON.stringify({
            url: googleUrl,
            createInGoogle: createInGoogle,
            hidden: hidden,
            quiet: quiet
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
            if (apiConnected) {
                sessionNotified = false;
                refreshGoogle(true);
                gcal(["calendars"], c => {
                    if (!c.error)
                        calendars = c.calendars ?? [];
                });
            }
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

    // Si Google dice que la sesión venció, vuelve al estado "sin conectar" y avisa una sola vez
    function handleApiError(message: string): void {
        if (!message.includes("venció"))
            return;
        refreshApiStatus();
        if (!sessionNotified) {
            sessionNotified = true;
            Quickshell.execDetached(["notify-send", "-a", "Agenda", "-i", "dialog-warning", "Google Calendar se desconectó", "El permiso venció. Abrí el calendario y tocá «Conectar con Google»."]);
        }
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
                handleApiError(googleError);
            });
            return;
        }
        fetcher.command = ["python3", ombuDir + "/bin/ics.py", "env", ymd(from), ymd(to), cacheDir + "/google.ics"];
        fetcher.running = true;
    }

    // Recordatorios: cada evento con hora trae sus avisos (minutos antes). Los propios suenan a la hora,
    // los de Google usan los suyos (10 minutos por defecto). Se miran hoy y los dos días que siguen,
    // porque un aviso puede ser "el día antes".
    function check(): void {
        now = new Date();
        const stamp = now.getTime();
        for (let off = 0; off < 3; off++) {
            const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + off, 12);
            const day = ymd(date);
            for (const it of itemsFor(day, true)) {
                if (!it.time || it.done || it.kind === "holiday")
                    continue;
                const at = new Date(date.getFullYear(), date.getMonth(), date.getDate(), parseInt(it.time.slice(0, 2)), parseInt(it.time.slice(3)));
                for (const m of (it.reminders ?? (it.kind === "google" ? [10] : [0]))) {
                    const fireAt = at.getTime() - m * 60000;
                    const key = day + "|" + it.kind + "|" + it.time + "|" + it.title + "|" + m;
                    if (fired[key] || stamp < fireAt || stamp > fireAt + 5 * 60000)
                        continue;
                    fired[key] = true;
                    let body = "Es ahora (" + it.time + ")";
                    if (m >= 1440)
                        body = (m < 2880 ? "Mañana" : "En " + Math.round(m / 1440) + " días") + " a las " + it.time;
                    else if (m > 0)
                        body = "Empieza en " + m + " min (" + it.time + ")";
                    Quickshell.execDetached(["notify-send", "-a", "Agenda", "-i", "appointment-soon", it.title, body]);
                }
            }
        }
    }

    // ---- Resumen del día: una notificación al prender la compu, una vez por día ----
    property string summaryDay: ""

    function greeting(): string {
        const h = new Date().getHours();
        return h < 12 ? "Buen día" : (h < 20 ? "Buenas tardes" : "Buenas noches");
    }

    // Líneas del resumen: lo de hoy, los pagos de los próximos días y el estudio
    function summaryLines(): var {
        const lines = [];
        const day = ymd(now);
        const items = itemsFor(day, true);
        // Los pagos van en su propia línea (ver más abajo): acá no se repiten
        const mine = items.filter(it => !/^(Pagar|Avisar a mamá)/.test(it.title));
        const holiday = mine.find(it => it.kind === "holiday");
        if (holiday)
            lines.push("Feriado: " + holiday.title);
        const rest = mine.filter(it => it.kind !== "holiday");
        for (const it of rest.slice(0, 5))
            lines.push(it.time ? it.time + "  " + it.title : "Todo el día: " + it.title);
        if (rest.length > 5)
            lines.push("+" + (rest.length - 5) + " más");
        if (rest.length === 0 && !holiday)
            lines.push("Nada agendado para hoy");

        const due = Subs.upcoming.filter(u => u.days <= 3);
        if (due.length > 0)
            lines.push("Pagos: " + due.map(u => u.sub.name + " " + Subs.money(u.sub.amount, u.sub.currency) + " (" + Subs.whenText(u.days).toLowerCase() + ")").join(", "));

        if (Focus.streak > 0)
            lines.push("Racha de estudio: " + Focus.streak + (Focus.streak === 1 ? " día" : " días"));
        return lines;
    }

    function showSummary(): void {
        summaryDay = ymd(new Date());
        summaryFile.setText(JSON.stringify({
            day: summaryDay
        }));
        Quickshell.execDetached(["notify-send", "-a", "Resumen del día", "-h", "string:x-ombu-kind:summary", greeting(), summaryLines().join("\n")]);
    }

    // Al arrancar espera a que carguen Google y los pagos (hasta ~45 s) y avisa si hoy no lo hizo
    function maybeSummary(): void {
        if (summaryDay === ymd(new Date()))
            return;
        const ready = !googleOn || googleAt > 0;
        if (!ready && summaryWait < 9) {
            summaryWait += 1;
            summaryTimer.restart();
            return;
        }
        showSummary();
    }

    property int summaryWait: 0

    FileView {
        id: summaryFile

        path: root.dataDir + "/resumen.json"
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: summaryTimer

        interval: 5000
        running: true
        onTriggered: root.maybeSummary()
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
            if (Array.isArray(cfg.hidden))
                hidden = cfg.hidden;
            if (Array.isArray(cfg.quiet))
                quiet = cfg.quiet;
        } catch (e) {}
        try {
            const sd = JSON.parse(summaryFile.text());
            if (typeof sd.day === "string")
                summaryDay = sd.day;
        } catch (e) {}
        loadHolidays(now.getFullYear());
        loadHolidays(now.getFullYear() + 1);
        refreshApiStatus();
        refreshGoogle(true);
    }
}
