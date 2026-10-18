pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Modo foco: temporizador de estudio y descanso, tres modos y un bloqueo de juegos.
//   libre    no hace nada
//   estudio  temporizador + cierra los juegos mientras dura el bloque de estudio
//   trabajo  temporizador, sin bloqueo (consultorio, Plaxia)
// El bloqueo avisa antes de cerrar (para no perder una partida) y se puede saltar con fricción:
// hay que esperar 60 segundos. Se guarda en ~/.local/share/ombu/focus.json y el estado actual,
// para que lo lean otros programas (el modo estudio de la IA), en ~/.local/state/ombu/modo.
// Por consola: qs -c ombu ipc call focus start|pause|stop|skip|mode estudio|idea "texto"|status
Singleton {
    id: root

    property string mode: "libre"
    property bool running: false
    // estudio | descanso | largo
    property string phase: "estudio"
    // Segundos que faltan en la fase actual (con el temporizador en marcha o en pausa)
    property int remaining: studySeconds_
    property double endsAt: 0

    // Duraciones, en segundos
    readonly property int studyLength: 25 * 60
    readonly property int breakLength: 5 * 60
    readonly property int longBreakLength: 15 * 60
    readonly property int cyclesBeforeLong: 4
    readonly property int studySeconds_: studyLength

    // Estadística de hoy y racha de días seguidos con al menos un bloque completo
    property string day: ""
    property int studyToday: 0
    property int cycles: 0
    property int streak: 0
    property string lastStudyDay: ""

    // Bloqueo: ventanas que no se dejan abrir mientras se estudia
    readonly property var blockedPattern: /steam_app|^steam$|gamescope|minecraft|mojang|league|riot|heroic|lutris/i
    readonly property int warnSeconds: 15
    readonly property int terminateAfter: 10
    readonly property int unlockSeconds: 60
    readonly property int overrideMinutes: 15
    property int unlockLeft: 0
    property double overrideUntil: 0
    property var warned: ({})

    // Cartel que aparece cuando se intenta abrir un juego: qué app, hasta cuándo y qué frase
    property string noticeTitle: ""
    property double noticeEndsAt: 0
    property string noticePhrase: ""
    readonly property bool noticeVisible: blocking && noticeTitle !== "" && nowMs < noticeEndsAt + 1500
    readonly property int noticeLeft: Math.max(0, Math.ceil((noticeEndsAt - nowMs) / 1000))
    readonly property var phrases: [
        "Tu yo del futuro te lo va a agradecer.",
        "Son 25 minutos. Después jugás tranquilo.",
        "Esto es lo que te acerca a la carrera que querés.",
        "Cada bloque cuenta: estás construyendo tu futuro.",
        "Lo difícil es empezar. Ya empezaste.",
        "Primero lo importante. El juego espera."
    ]

    readonly property bool blocking: mode === "estudio" && running && phase === "estudio" && overrideUntil < nowMs
    property double nowMs: Date.now()

    readonly property string dataDir: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu"
    readonly property string stateDir: (Quickshell.env("HOME") ?? "") + "/.local/state/ombu"

    readonly property string phaseName: phase === "estudio" ? "Estudio" : (phase === "largo" ? "Descanso largo" : "Descanso")

    function today(): string {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    function lengthOf(p: string): int {
        return p === "estudio" ? studyLength : (p === "largo" ? longBreakLength : breakLength);
    }

    function clock(seconds: int): string {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
    }

    function minutesText(seconds: int): string {
        const m = Math.floor(seconds / 60);
        return m >= 60 ? Math.floor(m / 60) + " h " + String(m % 60).padStart(2, "0") + " min" : m + " min";
    }

    // Nombre para el cartel: lo que dice la ventana o, si no, la clase sin prefijos técnicos
    function friendlyName(cls: string, title: string): string {
        if (/minecraft|mojang/i.test(cls))
            return "Minecraft";
        if (/league|riot/i.test(cls))
            return "League of Legends";
        if (/^steam_app/i.test(cls))
            return title && title !== "" ? title : "un juego de Steam";
        return title && title !== "" ? title : cls;
    }

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Modo foco", "-t", "7000", title, body]);
    }

    function chime(): void {
        Quickshell.execDetached(["paplay", "--volume=45000", "/usr/share/sounds/freedesktop/stereo/message.oga"]);
    }

    function setMode(m: string): void {
        if (m === mode)
            return;
        mode = m;
        if (m === "libre")
            stop();
        publish();
        save();
    }

    function start(): void {
        if (mode === "libre")
            mode = "estudio";
        if (remaining <= 0)
            remaining = lengthOf(phase);
        endsAt = Date.now() + remaining * 1000;
        running = true;
        warned = ({});
        publish();
        save();
    }

    function pause(): void {
        if (!running)
            return;
        remaining = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000));
        running = false;
        publish();
    }

    function stop(): void {
        running = false;
        phase = "estudio";
        remaining = studyLength;
        warned = ({});
        unlockLeft = 0;
        publish();
    }

    // Pasa a la fase siguiente (al terminar el tiempo, o saltando con el botón)
    function next(announce: bool): void {
        if (phase === "estudio") {
            cycles += 1;
            phase = cycles % cyclesBeforeLong === 0 ? "largo" : "descanso";
        } else {
            phase = "estudio";
        }
        remaining = lengthOf(phase);
        endsAt = Date.now() + remaining * 1000;
        warned = ({});
        if (announce) {
            chime();
            notify(phase === "estudio" ? "A estudiar" : phase === "largo" ? "Descanso largo" : "Descanso", phase === "estudio" ? "Empieza un bloque de " + Math.round(studyLength / 60) + " minutos." : "Pará un rato: " + Math.round(remaining / 60) + " minutos.");
        }
        publish();
        save();
    }

    // Anota una idea sin salir del estudio: queda en ~/.local/share/ombu/ideas.md
    function saveIdea(text: string): void {
        const t = text.trim();
        if (t === "")
            return;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; printf -- '- %s %s\\n' \"$(date '+%F %H:%M')\" \"$1\" >> \"$2\"", "ideas", t, dataDir + "/ideas.md"]);
    }

    // "Volver a estudiar": no espera los 15 s, cierra ahora lo que está bloqueado
    function closeBlocked(): void {
        if (!blocking)
            return;
        const past = Date.now() - warnSeconds * 1000 - 1;
        const w = {};
        for (const k of Object.keys(warned))
            w[k] = {
                since: past,
                closedAt: warned[k].closedAt,
                termAt: warned[k].termAt
            };
        warned = w;
        noticeEndsAt = Date.now();
        blockTimer.triggered();
    }

    // Saltar el bloqueo: no es inmediato, hay que esperar
    function requestUnlock(): void {
        if (unlockLeft > 0 || !blocking)
            return;
        unlockLeft = unlockSeconds;
    }

    function cancelUnlock(): void {
        unlockLeft = 0;
    }

    // Qué leen otros programas: "estudio activo", "trabajo inactivo", "libre inactivo"...
    function publish(): void {
        const active = mode !== "libre" && running && (mode === "trabajo" || phase === "estudio");
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; printf '%s\\n' \"$1\" > \"$2\"", "modo", mode + (active ? " activo" : " inactivo"), stateDir + "/modo"]);
    }

    function save(): void {
        saveTimer.restart();
    }

    // Cada segundo: cuenta, cambia de fase y cierra de día
    Timer {
        interval: 1000
        repeat: true
        running: root.running || root.unlockLeft > 0
        onTriggered: {
            root.nowMs = Date.now();

            if (root.unlockLeft > 0) {
                root.unlockLeft -= 1;
                if (root.unlockLeft === 0) {
                    root.overrideUntil = Date.now() + root.overrideMinutes * 60000;
                    root.notify("Bloqueo pausado", "Tenés " + root.overrideMinutes + " minutos. Después vuelve solo.");
                }
            }

            if (!root.running)
                return;

            if (root.day !== root.today()) {
                root.day = root.today();
                root.studyToday = 0;
                root.cycles = 0;
            }

            root.remaining = Math.max(0, Math.ceil((root.endsAt - Date.now()) / 1000));
            if (root.phase === "estudio") {
                root.studyToday += 1;
                // Cuenta para la racha el día en que se completan 25 minutos
                if (root.studyToday >= root.studyLength && root.lastStudyDay !== root.today()) {
                    const y = new Date();
                    y.setDate(y.getDate() - 1);
                    root.streak = root.lastStudyDay === Qt.formatDate(y, "yyyy-MM-dd") ? root.streak + 1 : 1;
                    root.lastStudyDay = root.today();
                    root.save();
                }
            }
            if (root.remaining <= 0)
                root.next(true);
        }
    }

    // Vigila las ventanas mientras el bloqueo está activo: avisa y, pasado el plazo, cierra la
    // ventana con un cierre normal (no mata el proceso, para no perder una partida sin guardar)
    Timer {
        id: blockTimer

        interval: 2500
        repeat: true
        running: root.blocking
        onTriggered: {
            const now = Date.now();
            // Se arma un registro nuevo en cada vuelta: avisos de las ventanas que siguen abiertas
            const next = {};
            for (const t of Apps.windows) {
                const cls = t.wayland?.appId ?? t.lastIpcObject?.class ?? "";
                if (!root.blockedPattern.test(cls))
                    continue;
                const address = t.address;
                const seen = root.warned[address];
                if (seen === undefined) {
                    next[address] = {
                        since: now,
                        closedAt: 0,
                        termAt: 0
                    };
                    root.noticeTitle = root.friendlyName(cls, t.title);
                    root.noticePhrase = root.phrases[Math.floor(Math.random() * root.phrases.length)];
                    root.noticeEndsAt = now + root.warnSeconds * 1000;
                    root.chime();
                    console.log("FOCO: detectado " + cls + " (" + address + ")");
                    continue;
                }
                const entry = {
                    since: seen.since,
                    closedAt: seen.closedAt,
                    termAt: seen.termAt
                };
                next[address] = entry;
                if (now - entry.since < root.warnSeconds * 1000)
                    continue;
                if (entry.termAt === 0) {
                    // Primero un cierre normal: se enfoca la ventana y se cierra la activa
                    // (close({ window = ... }) no cierra en esta versión de Hyprland)
                    if (entry.closedAt === 0)
                        console.log("FOCO: pidiendo cerrar " + cls);
                    entry.closedAt = entry.closedAt === 0 ? now : entry.closedAt;
                    Hyprland.dispatch("function() hl.dispatch(hl.dsp.focus({ window = \"address:0x" + address + "\" })); hl.dispatch(hl.dsp.window.close()) end");
                    // Si la app lo ignora (un juego puede hacerlo, o un launcher que solo se
                    // esconde), a los 10 s se le manda SIGTERM: cierre ordenado, no SIGKILL
                    const pid = t.lastIpcObject?.pid ?? 0;
                    if (now - entry.closedAt >= root.terminateAfter * 1000 && pid > 0) {
                        entry.termAt = now;
                        console.log("FOCO: " + cls + " no se cerró, SIGTERM a " + pid);
                        Quickshell.execDetached(["kill", "-TERM", String(pid)]);
                    }
                }
            }
            root.warned = next;
        }
    }

    Timer {
        id: saveTimer

        interval: 500
        onTriggered: file.setText(JSON.stringify({
            mode: root.mode,
            day: root.day,
            studyToday: root.studyToday,
            cycles: root.cycles,
            streak: root.streak,
            lastStudyDay: root.lastStudyDay
        }, null, 2) + "\n")
    }

    FileView {
        id: file

        path: root.dataDir + "/focus.json"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", dataDir, stateDir]);
        remaining = studyLength;
        try {
            const saved = JSON.parse(file.text());
            if (typeof saved.mode === "string")
                mode = saved.mode;
            if (saved.day === today()) {
                studyToday = saved.studyToday ?? 0;
                cycles = saved.cycles ?? 0;
            }
            day = today();
            streak = saved.streak ?? 0;
            lastStudyDay = saved.lastStudyDay ?? "";
            // Una racha de ayer sigue viva; más vieja se corta
            if (lastStudyDay !== "" && lastStudyDay !== today()) {
                const y = new Date();
                y.setDate(y.getDate() - 1);
                if (lastStudyDay !== Qt.formatDate(y, "yyyy-MM-dd"))
                    streak = 0;
            }
        } catch (e) {
            day = today();
        }
        publish();
    }
}
