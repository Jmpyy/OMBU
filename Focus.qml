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

    // Entorno de estudio: qué se abre al empezar según lo que toque estudiar
    //   programacion  NotebookLM en Zen + el editor en la carpeta de la facultad + la IA en una terminal
    //   matematica    NotebookLM + la IA (sin editor)
    //   otro          solo NotebookLM
    property string kit: "programacion"
    property bool autoOpen: true
    readonly property var kits: [
        {
            id: "programacion",
            name: "Programación",
            tools: ["notebook", "ide", "ai"]
        },
        {
            id: "matematica",
            name: "Matemática",
            tools: ["notebook", "ai"]
        },
        {
            id: "otro",
            name: "Otro",
            tools: ["notebook"]
        }
    ]
    readonly property string notebookUrl: "https://notebooklm.google.com"
    readonly property string studyDir: (Quickshell.env("HOME") ?? "") + "/universidad"
    // El PATH de la sesión de Hyprland no trae ~/.local/bin: la IA se llama con su ruta completa
    readonly property string aiCommand: (Quickshell.env("HOME") ?? "") + "/.local/bin/agy"
    property var pendingTools: []

    // Estadística de hoy y racha de días seguidos con al menos un bloque completo
    property string day: ""
    property int studyToday: 0
    property int cycles: 0
    property int streak: 0
    property string lastStudyDay: ""
    // Minutos estudiados por día ("yyyy-MM-dd" -> minutos), para marcar el calendario
    property var history: ({})

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

    readonly property string phaseName: phase === "estudio" ? (mode === "trabajo" ? "Trabajo" : "Estudio") : (phase === "largo" ? "Descanso largo" : "Descanso")

    // Sitios que se bloquean en el navegador. Se reconocen por el título de la pestaña activa (el
    // de la ventana de Zen); al vencer el plazo se cierra esa pestaña. YouTube no está: sirve para
    // estudiar. Los patrones piden que el título empiece con el nombre o lo traiga como sello del
    // sitio, para no cerrar una pestaña de estudio que solo nombra a Instagram.
    readonly property var browserClasses: ["zen", "firefox"]
    readonly property var blockedSites: [
        {
            name: "Instagram",
            re: /^(\(\d+\)\s*)?Instagram|• Instagram|Instagram •/i
        },
        {
            name: "TikTok",
            re: /TikTok/i
        },
        {
            name: "Facebook",
            re: /^(\(\d+\)\s*)?Facebook|\| Facebook/i
        },
        {
            name: "X",
            re: /(\/ X|on X:)( — |$)/
        },
        {
            name: "Reddit",
            re: /^(\(\d+\)\s*)?(Reddit|r\/)|: r\/|\| Reddit/i
        },
        {
            name: "Twitch",
            re: /^(\(\d+\)\s*)?Twitch|- Twitch( — |$)/i
        },
        {
            name: "Netflix",
            re: /^(\(\d+\)\s*)?Netflix|- Netflix( — |$)/i
        }
    ]
    // "game" o "web": lo que se bloqueó, para los textos del cartel
    property string noticeKind: "game"

    // Procesos (nombre de 15 caracteres como máximo) que cuentan aunque todavía no tengan ventana:
    // el launcher de Minecraft tarda en mostrarla y el cartel tiene que salir antes
    readonly property var blockedProcesses: [
        {
            comm: "minecraft-launc",
            family: "minecraft"
        }
    ]
    property var procPids: ({})

    // Familia de una app: el launcher y el juego de Minecraft comparten un solo aviso
    function familyOf(cls: string): string {
        if (/minecraft|mojang/i.test(cls))
            return "minecraft";
        if (/league|riot/i.test(cls))
            return "league";
        if (/steam|gamescope/i.test(cls))
            return "steam";
        return cls.toLowerCase();
    }

    // Revisa ventanas y procesos bloqueados: avisa al verlos, y pasado el plazo los cierra con un
    // cierre normal; si la app lo ignora, a los 10 s le manda SIGTERM (nunca SIGKILL).
    function scanBlocked(): void {
        const now = Date.now();
        const present = {};
        for (const t of Apps.windows) {
            // Con "||" y no "??": un appId vacío ("") tiene que caer al nombre de clase de Hyprland
            const cls = t.wayland?.appId || t.lastIpcObject?.class || "";
            // Navegador mostrando un sitio bloqueado: se cierra la pestaña, no la ventana
            if (browserClasses.includes(cls.toLowerCase())) {
                const site = blockedSites.find(b => b.re.test(t.title ?? ""));
                if (site) {
                    const wf = "web:" + site.name;
                    if (!present[wf])
                        present[wf] = {
                            kind: "tab",
                            cls: "web",
                            title: site.name,
                            windows: [],
                            pids: []
                        };
                    present[wf].windows.push(t.address);
                }
                continue;
            }
            if (!blockedPattern.test(cls))
                continue;
            const f = familyOf(cls);
            if (!present[f])
                present[f] = {
                    kind: "game",
                    cls: cls,
                    title: t.title,
                    windows: [],
                    pids: []
                };
            present[f].windows.push(t.address);
            const pid = t.lastIpcObject?.pid ?? 0;
            if (pid > 0)
                present[f].pids.push(pid);
        }
        for (const f of Object.keys(procPids)) {
            if (procPids[f].length === 0)
                continue;
            if (!present[f])
                present[f] = {
                    kind: "game",
                    cls: f,
                    title: "",
                    windows: [],
                    pids: []
                };
            for (const pid of procPids[f])
                present[f].pids.push(pid);
        }

        const next = {};
        for (const f of Object.keys(present)) {
            const p = present[f];
            const seen = warned[f];
            const entry = seen === undefined ? {
                since: now,
                closedAt: 0,
                termAt: 0,
                lastSend: 0
            } : {
                since: seen.since,
                closedAt: seen.closedAt,
                termAt: seen.termAt,
                lastSend: seen.lastSend ?? 0
            };
            next[f] = entry;
            if (seen === undefined) {
                noticeKind = p.kind === "tab" ? "web" : "game";
                noticeTitle = friendlyName(p.cls, p.title);
                noticePhrase = phrases[Math.floor(Math.random() * phrases.length)];
                noticeEndsAt = now + warnSeconds * 1000;
                chime();
                console.log("FOCO: detectado " + f + " (" + p.windows.length + " ventanas, " + p.pids.length + " procesos)");
                continue;
            }
            if (now - entry.since < warnSeconds * 1000 || entry.termAt !== 0)
                continue;
            if (p.kind === "tab") {
                // Ctrl+W a la ventana del navegador, que muestra el sitio bloqueado. Se espera 3 s
                // entre envíos: si el título tarda en actualizarse, un segundo Ctrl+W cerraría
                // la pestaña que no era.
                if (now - entry.lastSend >= 3000) {
                    entry.lastSend = now;
                    if (entry.closedAt === 0) {
                        entry.closedAt = now;
                        console.log("FOCO: cerrando la pestaña de " + p.title);
                    }
                    for (const a of p.windows)
                        Hyprland.dispatch("hl.dsp.send_shortcut({ mods = \"CTRL\", key = \"w\", window = \"address:0x" + a + "\" })");
                }
                continue;
            }
            if (p.windows.length > 0) {
                // Primero un cierre normal: se enfoca cada ventana y se cierra la activa
                // (close({ window = ... }) no cierra en esta versión de Hyprland)
                if (entry.closedAt === 0) {
                    entry.closedAt = now;
                    console.log("FOCO: pidiendo cerrar " + f);
                }
                let code = "function() ";
                for (const a of p.windows)
                    code += "hl.dispatch(hl.dsp.focus({ window = \"address:0x" + a + "\" })); hl.dispatch(hl.dsp.window.close()); ";
                Hyprland.dispatch(code + "end");
            } else if (entry.closedAt === 0) {
                // Sin ventana todavía (cargando): no hay a quién pedirle que cierre
                entry.closedAt = now - terminateAfter * 1000;
            }
            if (now - entry.closedAt >= terminateAfter * 1000 && p.pids.length > 0) {
                entry.termAt = now;
                console.log("FOCO: " + f + " no se cerró, SIGTERM a " + p.pids.join(" "));
                Quickshell.execDetached(["kill", "-TERM"].concat(p.pids.map(String)));
            }
        }
        warned = next;
    }

    // Pasa los minutos de hoy al historial (solo reasigna si cambió, para no despertar al calendario de balde)
    function recordHistory(): void {
        const m = Math.floor(studyToday / 60);
        if (day !== "" && (history[day] ?? 0) !== m)
            history = Object.assign({}, history, {
                [day]: m
            });
    }

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

    // Abre una herramienta de estudio; la carpeta de la facultad se crea si todavía no existe
    function openTool(tool: string): void {
        if (tool === "notebook") {
            Quickshell.execDetached(["zen-browser", notebookUrl]);
        } else if (tool === "ide") {
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && exec zeditor \"$1\"", "ide", studyDir]);
        } else if (tool === "ai") {
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && exec kitty --directory \"$1\" \"$2\"", "ia", studyDir, aiCommand]);
        }
    }

    // Abre todo lo del tipo de estudio elegido, de a una cada 0,7 s para que las ventanas no
    // se pisen el foco; la última (la terminal con la IA) queda enfocada
    function openKit(): void {
        const k = kits.find(x => x.id === kit);
        if (!k)
            return;
        pendingTools = k.tools.slice();
        launchTimer.restart();
    }

    function setKit(id: string): void {
        kit = id;
        save();
    }

    function toggleAutoOpen(): void {
        autoOpen = !autoOpen;
        save();
    }

    function start(): void {
        // Arranque desde cero (no al volver de una pausa ni de un descanso)
        const fresh = !running && phase === "estudio" && remaining === studyLength;
        if (mode === "libre")
            mode = "estudio";
        if (fresh && autoOpen && mode === "estudio")
            openKit();
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

    // "Cerrar y estudiar": no espera los 15 s, cierra ahora lo que está bloqueado
    function closeBlocked(): void {
        if (!blocking)
            return;
        const past = Date.now() - warnSeconds * 1000 - 1;
        const w = {};
        for (const k of Object.keys(warned))
            w[k] = {
                since: past,
                closedAt: warned[k].closedAt,
                termAt: warned[k].termAt,
                lastSend: 0
            };
        warned = w;
        noticeEndsAt = Date.now();
        scanBlocked();
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

    // Vigila cada segundo mientras el bloqueo está activo (el aviso sale casi al abrir la app)
    Timer {
        interval: 1000
        repeat: true
        running: root.blocking
        onTriggered: {
            root.scanBlocked();
            if (!procProbe.running)
                procProbe.running = true;
        }
    }

    // Procesos bloqueados que están corriendo, con o sin ventana
    Process {
        id: procProbe

        command: ["pgrep", "-x", "-l", root.blockedProcesses.map(b => b.comm).join("|")]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.split("\n")) {
                    const m = /^(\d+)\s+(\S+)/.exec(line);
                    if (!m)
                        continue;
                    const b = root.blockedProcesses.find(x => x.comm === m[2]);
                    if (!b)
                        continue;
                    found[b.family] = (found[b.family] ?? []).concat([Number(m[1])]);
                }
                root.procPids = found;
            }
        }
    }

    Timer {
        id: launchTimer

        interval: 700
        repeat: true
        onTriggered: {
            if (root.pendingTools.length === 0) {
                launchTimer.stop();
                return;
            }
            const rest = root.pendingTools.slice();
            root.openTool(rest.shift());
            root.pendingTools = rest;
        }
    }

    Timer {
        id: saveTimer

        interval: 500
        onTriggered: {
            root.recordHistory();
            file.setText(JSON.stringify({
                mode: root.mode,
                kit: root.kit,
                autoOpen: root.autoOpen,
                day: root.day,
                studyToday: root.studyToday,
                cycles: root.cycles,
                streak: root.streak,
                lastStudyDay: root.lastStudyDay,
                history: root.history
            }, null, 2) + "\n");
        }
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
            if (typeof saved.kit === "string" && kits.some(k => k.id === saved.kit))
                kit = saved.kit;
            if (typeof saved.autoOpen === "boolean")
                autoOpen = saved.autoOpen;
            if (saved.day === today()) {
                studyToday = saved.studyToday ?? 0;
                cycles = saved.cycles ?? 0;
            }
            day = today();
            streak = saved.streak ?? 0;
            lastStudyDay = saved.lastStudyDay ?? "";
            history = saved.history ?? {};
            recordHistory();
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
