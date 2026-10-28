pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// Apps que siguen corriendo aunque no tengan ventana abierta.
Singleton {
    id: root

    // Todas las apps gráficas corriendo, según bgapps.py
    property var running: []

    // Ventanas de verdad: hay apps (el Minecraft Launcher) que esconden su ventana y Hyprland la deja
    // en la lista sin escritorio; esas no se muestran ni se cuentan.
    readonly property var windows: Array.from(Hyprland.toplevels.values).filter(t => t.workspace !== null && t.workspace !== undefined)

    readonly property var windowPids: {
        const set = {};
        for (const t of windows) {
            const pid = t.lastIpcObject?.pid;
            if (pid)
                set[pid] = true;
        }
        return set;
    }

    // Algunas apps abren su ventana desde otro proceso: también se compara por entrada .desktop
    readonly property var windowEntryIds: {
        const set = {};
        for (const t of windows) {
            const appId = t.wayland?.appId;
            const entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
            if (entry)
                set[entry.id.toLowerCase()] = true;
        }
        return set;
    }

    readonly property var background: running.filter(a => !a.pids.some(p => windowPids[p]) && !windowEntryIds[a.id.toLowerCase()])
    // Ventanas minimizadas (Hyprland no minimiza: ombu las manda al escritorio especial «minimized»)
    readonly property var minimized: windows.filter(t => t.workspace?.name === "special:minimized")
    // Apps de la bandeja del sistema (Discord, Steam, Sung...): ya no van en la barra, sino en el menú de
    // segundo plano, cada una con su menú de opciones
    readonly property var trayItems: Array.from(SystemTray.items.values)
    // Una app sin ventana que también está en la bandeja se muestra una sola vez (como app de la bandeja)
    function inTray(a: var): bool {
        const aid = (a.id ?? "").toLowerCase(), an = (a.name ?? "").toLowerCase();
        return (trayItems ?? []).some(t => {
            const tid = (t.id ?? "").toLowerCase(), tt = (t.title ?? "").toLowerCase();
            return tid !== "" && (aid.includes(tid) || tid.includes(aid) || tid === an || (tt !== "" && tt === an));
        });
    }
    readonly property var backgroundOnly: (background ?? []).filter(a => !inTray(a))
    // Lo que está «guardado»: minimizado, en la bandeja o corriendo sin ventana. Es lo que muestran el
    // botón de la barra y su menú (AppsMenu); las ventanas en uso no.
    // Al arrancar, las listas se calculan en cualquier orden y alguna puede no existir todavía: se cuenta
    // lo que tenga largo (una lista de QML no pasa Array.isArray).
    readonly property int tucked: {
        let n = 0;
        for (const l of [minimized, trayItems, backgroundOnly])
            n += l && l.length > 0 ? l.length : 0;
        return n;
    }

    function refresh(): void {
        Hyprland.refreshToplevels();
        if (!scan.running)
            scan.running = true;
    }

    // Para refrescar la lista poco después de una acción (minimizar, cerrar...)
    function refreshSoon(): void {
        recheck.restart();
    }

    // Ir a una ventana; si estaba minimizada (Hyprland no minimiza: ombu la manda al escritorio especial
    // «minimized»), además la trae al escritorio actual. La usan el launcher, el menú de apps y los avisos.
    function focusWindow(t): void {
        const address = "address:0x" + t.address;
        if (t.workspace?.name === "special:minimized") {
            let here = Hyprland.focusedWorkspace?.id ?? 1;
            if (here < 1)
                here = 1;
            Hyprland.dispatch("function() hl.dispatch(hl.dsp.focus({ window = \"" + address + "\" })); hl.dispatch(hl.dsp.window.move({ workspace = \"" + here + "\" })) end");
        } else {
            Hyprland.dispatch("hl.dsp.focus({ window = \"" + address + "\" })");
        }
    }

    // Lanzar una app que ya está corriendo suele traer su ventana al frente
    function open(app): void {
        const entry = DesktopEntries.heuristicLookup(app.id) ?? DesktopEntries.heuristicLookup(app.name);
        if (entry)
            entry.execute();
    }

    // Cierre normal (SIGTERM) de todos los procesos de la app; si alguno no hace caso (el Minecraft
    // Launcher captura la señal), a los 3 segundos se lo fuerza. Se mata por PID: el juego, que es
    // un proceso aparte, sigue.
    function close(app): void {
        const pids = (app.pids ?? [app.main]).map(String);
        Quickshell.execDetached(["sh", "-c", 'kill "$@" 2>/dev/null; sleep 3; kill -9 "$@" 2>/dev/null', "sh"].concat(pids));
        recheck.restart();
    }

    Process {
        id: scan

        command: ["python3", "-I", Quickshell.shellPath("bgapps.py")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.running = JSON.parse(text);
                } catch (e) {
                    console.warn("bgapps.py devolvió algo ilegible:", e);
                }
            }
        }
    }

    // Abrir o cerrar una ventana cambia quién queda en segundo plano: se mira enseguida, y el sondeo
    // queda de respaldo (una app que arranca sin ventana, o un proceso que termina un rato después)
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "openwindow" || event.name === "closewindow")
                root.refreshSoon();
        }
    }

    Timer {
        interval: Ui.popup.startsWith("apps@") ? 1500 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: recheck

        interval: 900
        onTriggered: root.refresh()
    }
}
