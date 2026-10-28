pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// Servidor de notificaciones (org.freedesktop.Notifications). Reemplaza a swaync.
// Mantiene el historial y decide qué avisos emergentes se muestran.
Singleton {
    id: root

    // No molestar: no hay avisos emergentes. Pasan igual los críticos (las confirmaciones de los agentes
    // lo son) y los marcados x-ombu-urgent (parciales, entregas, pagos de hoy, el propio modo foco).
    property bool dnd: false

    // El bloque de estudio del modo foco lo activa y, al pausar, parar o pasar al descanso, lo apaga; pero
    // solo si lo había activado él: si ya estaba prendido a mano, o lo apagás en medio del bloque, se respeta
    readonly property bool studyBlock: Focus.mode === "estudio" && Focus.running && Focus.phase === "estudio"
    property bool dndByFocus: false

    function syncFocus(): void {
        if (studyBlock && !dnd && !dndByFocus) {
            dnd = true;
            dndByFocus = true;
        } else if (!studyBlock && dndByFocus) {
            dnd = false;
        }
    }

    onStudyBlockChanged: syncFocus()
    onDndChanged: {
        if (!dnd)
            dndByFocus = false;
        saveDnd();
    }
    onDndByFocusChanged: saveDnd()

    // No molestar sobrevive a las recargas (antes volvía a apagado cada vez): ~/.local/share/ombu/avisos.json
    property bool dndLoaded: false

    function saveDnd(): void {
        if (dndLoaded)
            dndFile.setText(JSON.stringify({
                dnd: dnd,
                byFocus: dndByFocus
            }));
    }

    FileView {
        id: dndFile

        path: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu/avisos.json"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            const s = JSON.parse(dndFile.text());
            dndByFocus = s.byFocus === true;
            dnd = s.dnd === true;
        } catch (e) {}
        dndLoaded = true;
        syncFocus();
    }

    function breaksDnd(entry): bool {
        return !dnd || entry.critical || entry.urgent;
    }

    // Historial, de la más nueva a la más vieja. Cada elemento es un Entry.
    property var history: []
    // Avisos emergentes en pantalla (incluye los que se están yendo)
    property var toasts: []

    readonly property int count: history.length
    readonly property var latest: history.length > 0 ? history[0] : null

    // Llegó una notificación nueva (la campana de la barra reacciona)
    signal received(var entry)

    // Un aviso: la notificación más su estado de aviso emergente.
    // La Notification se destruye apenas se cierra, pero la tarjeta sigue en pantalla
    // mientras se desvanece: por eso se guarda una copia de lo que se muestra.
    component Entry: QtObject {
        id: entry

        required property var n
        property date time: new Date()
        // La app (o Quickshell, al tocar una acción) ya la cerró: el objeto original no se puede volver a cerrar
        property bool gone: false
        property bool shown: false
        property bool hovered: false
        // Se cerró deslizándola hacia la derecha: sale con ese movimiento
        property bool swiped: false
        // Tiempo que le queda al aviso, de 1 (recién llegó) a 0 (se va)
        property real remaining: 1

        // Copia de los datos que dibuja la tarjeta
        property string appName: ""
        property string summary: ""
        property string body: ""
        property string image: ""
        property string appIcon: ""
        property string desktopEntry: ""
        property bool critical: false
        // Pasa aunque esté No molestar (x-ombu-urgent)
        property bool urgent: false
        // Confirmación de un comando de un agente (ver bin/agent-confirm.py)
        property string kind: ""
        property bool risky: false
        property bool compound: false
        property string cwd: ""
        property real expireSeconds: 0
        property var actionList: []

        Component.onCompleted: root.copyInto(entry)

        // Una app que reemplaza su aviso (replaces_id: volumen, progreso, el tema que suena) no manda
        // una notificación nueva: Quickshell actualiza la misma. Se vuelve a copiar y se muestra de nuevo.
        readonly property Connections updates: Connections {
            target: entry.gone ? null : entry.n

            function onSummaryChanged(): void {
                Qt.callLater(root.replaced, entry);
            }
            function onBodyChanged(): void {
                Qt.callLater(root.replaced, entry);
            }
            function onImageChanged(): void {
                Qt.callLater(root.replaced, entry);
            }
        }

        function hide(): void {
            shown = false;
            leave.restart();
        }

        // Todo aviso se va solo, menos la confirmación de un comando de un agente (esa espera a que
        // decidas). Segundos: los que indica la app; sin indicación, 6 y, si es crítico, 30 (muchas
        // apps marcan todo como crítico y se quedaban para siempre).
        readonly property bool hasTimer: kind !== "confirm"
        readonly property real seconds: expireSeconds > 0 ? expireSeconds : (kind === "summary" ? 25 : (critical ? 30 : 6))

        // La cuenta regresiva es una animación: se pausa con el mouse encima y la barra
        // de progreso de la tarjeta la sigue sin desfasarse.
        readonly property NumberAnimation countdown: NumberAnimation {
            target: entry
            property: "remaining"
            from: 1
            to: 0
            duration: entry.seconds * 1000
            running: entry.shown && entry.hasTimer
            // Solo se puede pausar una animación en marcha (si no, Qt avisa en el log)
            paused: running && entry.hovered
            onFinished: entry.hide()
        }

        // Tope: con el mouse quieto encima el contador se pausaba. Pasado este tiempo
        // el aviso se va aunque lo tengas debajo (tope razonable de 8 a 15s).
        readonly property Timer hardLimit: Timer {
            interval: Math.min(15, Math.max(entry.seconds * 1.5, 8)) * 1000
            running: entry.shown && entry.hasTimer
            onTriggered: entry.hide()
        }

        // Deja terminar la animación de salida antes de sacarlo de la lista
        readonly property Timer leave: Timer {
            interval: 380
            onTriggered: root.dropToast(entry)
        }
    }

    function dropToast(entry): void {
        toasts = toasts.filter(e => e !== entry);
        if (!history.includes(entry))
            entry.destroy();
    }

    // Copia en la entrada lo que dibuja la tarjeta, ya traducido o reescrito por NotifRules
    function copyInto(entry): void {
        const n = entry.n;
        const h = n.hints ?? {};
        const rule = NotifRules.ruleFor(n);
        entry.desktopEntry = n.desktopEntry;
        entry.image = n.image || (rule && rule.cover ? NotifRules.coverFor(n) : "");
        entry.critical = n.urgency === NotificationUrgency.Critical;
        entry.kind = String(h["x-ombu-kind"] ?? "");
        entry.urgent = Number(h["x-ombu-urgent"] ?? 0) === 1;
        entry.risky = Number(h["x-ombu-risky"] ?? 0) === 1;
        entry.compound = Number(h["x-ombu-compound"] ?? 0) === 1;
        entry.cwd = String(h["x-ombu-cwd"] ?? "");
        // expireTimeout de freedesktop viene en milisegundos (ej: 5000 = 5s)
        entry.expireSeconds = n.expireTimeout > 0 ? (n.expireTimeout >= 100 ? Math.round(n.expireTimeout / 1000) : n.expireTimeout) : 0;
        entry.actionList = Array.from(n.actions).map(a => ({
                    identifier: a.identifier,
                    text: NotifRules.translateAction(a.text)
                }));
        // Pasa el texto a español si hay una regla para esta app (o lo reescribe, ver NotifRules.speak)
        const spoken = NotifRules.speak(n);
        entry.summary = spoken ? spoken[0] : plain(NotifRules.translate(n, n.summary));
        entry.body = spoken ? spoken[1] : plain(NotifRules.translate(n, n.body));
        entry.appName = rule && rule.asApp ? rule.asApp : n.appName;
        entry.appIcon = rule && rule.icon ? rule.icon : n.appIcon;
    }

    // El servidor no interpreta HTML (bodyMarkupSupported: false), pero muchas apps escapan el texto igual
    // (Sung manda el artista con toHtmlEscaped): «Simon &amp; Garfunkel» se veía tal cual
    function plain(text: string): string {
        return text.replace(/&(amp|lt|gt|quot|apos|#39);/g, (m, e) => ({
                    amp: "&",
                    lt: "<",
                    gt: ">",
                    quot: "\"",
                    apos: "'",
                    "#39": "'"
                })[e]);
    }

    // La app reemplazó el contenido del aviso: se actualiza, sube al principio y vuelve a mostrarse
    function replaced(entry): void {
        if (entry.gone || !history.includes(entry))
            return;
        copyInto(entry);
        entry.time = new Date();
        history = [entry, ...history.filter(e => e !== entry)];
        // Lo que ya estás mirando (Sung a la vista al cambiar de tema) se actualiza sin aparecer
        if (!breaksDnd(entry) || NotifRules.shouldDrop(entry.n))
            return;
        if (!toasts.includes(entry))
            toasts = [entry, ...toasts];
        entry.leave.stop();
        entry.swiped = false;
        entry.shown = true;
        entry.remaining = 1;
        if (entry.hasTimer) {
            entry.countdown.restart();
            entry.hardLimit.restart();
        }
    }

    function add(n): void {
        // Hay que marcarla como "tracked" para que el servidor no la descarte
        n.tracked = true;
        // Avisos de algo que ya tenés a la vista (ver NotifRules): se descartan sin mostrar
        if (NotifRules.shouldDrop(n)) {
            n.dismiss();
            return;
        }
        for (const old of history.filter(e => e.n && e.n.id === n.id))
            remove(old);

        const entry = entryComponent.createObject(root, {
            n: n
        });
        history = [entry, ...history];
        n.closed.connect(() => {
            entry.gone = true;
            root.remove(entry);
        });
        received(entry);

        // Las que sobreviven a una recarga del shell (lastGeneration) ya se vieron: solo van al
        // historial. Antes reaparecían como nuevas cada vez que se recargaba.
        if (breaksDnd(entry) && !n.lastGeneration) {
            toasts = [entry, ...toasts];
            entry.shown = true;
            // Máximo 5 avisos a la vez; los más viejos se van (siguen en el historial)
            for (const old of toasts.slice(5))
                old.hide();
        }
    }

    function remove(entry): void {
        // Puede llegar dos veces (la app la cierra mientras se cerraba a mano): la segunda no hace nada
        const inHistory = history.includes(entry);
        if (!inHistory && !toasts.includes(entry))
            return;
        history = history.filter(e => e !== entry);
        if (toasts.includes(entry))
            entry.hide();
        else
            entry.destroy(500);
    }

    function dismiss(entry): void {
        // Si la app ya la cerró, la notificación original ya no existe
        if (entry.n && !entry.gone)
            entry.n.dismiss();
        else
            remove(entry);
    }

    function dismissLatest(): void {
        if (latest)
            dismiss(latest);
    }

    function dismissAll(): void {
        for (const e of history.slice())
            dismiss(e);
    }

    // La ventana de la app que mandó el aviso (null si no tiene). Los agentes de IA de la terminal
    // (bin/agent-notify.sh) no tienen ventana propia: su aviso lleva a la consola.
    function windowFor(entry): var {
        if (/^(claude code|antigravity)$/i.test(entry.appName))
            return Apps.windows.find(t => (t.wayland?.appId ?? "") === "kitty") ?? null;
        const name = entry.appName.toLowerCase();
        const key = (entry.desktopEntry || entry.appName).toLowerCase();
        const de = DesktopEntries.heuristicLookup(entry.desktopEntry || entry.appName);
        return Apps.windows.find(t => {
            const app = (t.wayland?.appId ?? "").toLowerCase();
            if (app === "")
                return false;
            return app === key || app === name || (de && (app === de.id.toLowerCase() || app === (de.startupClass ?? "").toLowerCase() || DesktopEntries.heuristicLookup(app)?.id === de.id));
        }) ?? null;
    }

    // Lleva al frente la ventana de esa app. Muchas apps (Discord, por ejemplo) reciben «Ver» o
    // «Responder» y no hacen nada: así el botón siempre te lleva a la app.
    function focusApp(entry): void {
        const t = windowFor(entry);
        if (t)
            Apps.focusWindow(t);
    }

    // Acciones que significan «ir a la app»; las demás (silenciar, posponer...) no enfocan nada
    function opensApp(action: var): bool {
        return action.identifier === "default" || /\b(ver|abrir|responder|mostrar|ir|open|view|reply|show)\b/i.test(action.text ?? "");
    }

    // Ejecuta una acción por su identificador y cierra la notificación
    function invokeAction(entry, identifier: string): void {
        const n = entry.n;
        if (!n)
            return;
        const action = Array.from(n.actions).find(a => a.identifier === identifier);
        if (action)
            action.invoke();
        const info = entry.actionList.find(a => a.identifier === identifier);
        if (entry.kind !== "confirm" && (identifier === "default" || (info && opensApp(info))))
            focusApp(entry);
        // Si no es residente, invoke() ya la cerró (closed marca `gone`): cerrarla otra vez daba
        // «Cannot close destroyed notification» en el log
        if (!n.resident && !entry.gone)
            dismiss(entry);
    }

    // Acción principal ("default" o la primera) y cerrar
    function invoke(entry): void {
        // Una confirmación de comando solo se aprueba con su propio botón: un clic suelto en la
        // tarjeta o el atajo "ejecutar la acción de la última" no pueden tocar "Permitir".
        if (entry.kind === "confirm")
            return;
        const actions = entry.actionList;
        const action = actions.find(a => a.identifier === "default") ?? actions[0];
        if (action)
            invokeAction(entry, action.identifier);
        else
            dismiss(entry);
        // Un clic en la tarjeta siempre lleva a la app, aunque no traiga acciones
        if (entry.kind !== "confirm")
            focusApp(entry);
    }

    function invokeLatest(): void {
        if (latest)
            invoke(latest);
    }

    Component {
        id: entryComponent

        Entry {}
    }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => root.add(n)
    }
}
