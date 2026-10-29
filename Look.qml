pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Vista rápida a pantalla completa, como la barra espaciadora de Finder (la muestra QuickLook.qml).
// Lo que hay que mostrar sale de bin/ql.sh en modo full. En Dolphin se abre con Espacio: el atajo existe
// solo mientras la ventana principal de Dolphin está activa y la vista está cerrada (abierta, el Espacio
// la cierra), así que en el resto del sistema el Espacio no se toca. Los diálogos de Dolphin (Renombrar,
// Propiedades...) no tienen el atajo: lo pregunta bin/look-dolphin.sh check, porque también se titulan
// «… — Dolphin». Por eso renombrar abre el diálogo (RenameInline=false en dolphinrc): renombrando en la
// lista, el Espacio abriría la vista en vez de escribir un espacio.
// ipc call look file <ruta> | close | status. Lo que decide sobre el atajo queda en el log con LOOK:
Singleton {
    id: root

    property bool open: false
    property string path: ""
    // image, pdf, video, audio, text, dir, other o none (ver bin/ql.sh)
    property string kind: ""
    property var lines: []
    property string image: ""
    property int page: 1
    property int pages: 1
    property bool loading: false
    readonly property string name: path.split("/").pop()
    // Para medir cuánto tarda en verse (va al log con LOOK:)
    property real openedAt: 0

    function show(p: string): void {
        openedAt = Date.now();
        path = p;
        kind = "";
        page = 1;
        pages = 1;
        load();
        open = true;
    }

    function close(): void {
        open = false;
    }

    function openInApp(): void {
        if (path !== "")
            Quickshell.execDetached(["xdg-open", path]);
        close();
    }

    // Página anterior o siguiente de un PDF
    function turn(delta: int): void {
        if (kind !== "pdf")
            return;
        const n = Math.max(1, Math.min(pages, page + delta));
        if (n === page)
            return;
        page = n;
        load();
    }

    function load(): void {
        loading = true;
        proc.running = false;
        proc.command = [Quickshell.shellPath("bin/ql.sh"), path, "full", String(page)];
        proc.running = true;
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                const k = l[0] ?? "";
                if (k === "image" || k === "pdf") {
                    root.image = "file://" + (l[1] ?? "");
                    // ql.sh cuenta las páginas solo al abrir el PDF
                    if (k === "pdf" && (l[2] ?? "") !== "")
                        root.pages = Math.max(1, parseInt(l[2]) || 1);
                } else {
                    root.lines = l.slice(1).filter((s, i, a) => i < a.length - 1 || s !== "");
                }
                root.kind = k;
                root.loading = false;
                if (k !== "image" && k !== "pdf")
                    console.log("LOOK:", k, "visible en", Date.now() - root.openedAt, "ms");
            }
        }
    }

    // Atajo de Dolphin -----------------------------------------------------------------------------

    property bool dolphinActive: false
    property string activeClass: ""
    property string activeAddr: ""
    // Si cada ventana de Dolphin es la principal (true) o un diálogo (false), por dirección: no cambia, así
    // que bin/look-dolphin.sh check corre una vez por ventana y no cada vez que gana el foco (con el foco
    // siguiendo al mouse, eso era a cada rato)
    property var mainCache: ({})
    property string pendingAddr: ""

    // La vista queda armada (shell.qml) mientras Dolphin está activo y 2 minutos más: si se armara y
    // destruyera con cada cambio de foco, pasar el mouse sobre Dolphin la reconstruiría (~430 ms) cada vez
    property bool warm: false

    onDolphinActiveChanged: {
        if (dolphinActive) {
            warm = true;
            cool.stop();
        } else {
            cool.restart();
        }
    }

    Timer {
        id: cool

        interval: 120000
        onTriggered: root.warm = false
    }
    // Lo que Hyprland tiene puesto ahora (para no mandar el mismo cambio dos veces)
    property bool bound: false
    readonly property bool wantBound: dolphinActive && !open

    onWantBoundChanged: sync()

    // Las órdenes a Hyprland salen de a una y en orden (sueltas, un «sacar» podía llegar después de un
    // «poner» y dejar el estado al revés)
    property var queue: []

    function send(lua: string): void {
        queue = queue.concat([lua]);
        if (!hypr.running)
            next();
    }

    function next(): void {
        if (queue.length === 0)
            return;
        hypr.command = ["hyprctl", "eval", queue[0]];
        queue = queue.slice(1);
        hypr.running = true;
    }

    Process {
        id: hypr

        onExited: root.next()
    }

    function sync(): void {
        if (wantBound === bound)
            return;
        bound = wantBound;
        console.log("LOOK: Espacio de Dolphin", bound ? "puesto" : "sacado", "(" + activeClass + ")");
        if (bound)
            send("hl.bind(\"Space\", hl.dsp.exec_cmd(\"" + Quickshell.shellPath("bin/look-dolphin.sh") + "\"))");
        else
            send("hl.unbind(\"Space\")");
    }

    // Hyprland avisa la clase (activewindow) y después la dirección (activewindowv2); acá ya están las dos
    function check(): void {
        if (activeClass !== "org.kde.dolphin" || activeAddr === "") {
            dolphinActive = false;
            return;
        }
        const known = mainCache[activeAddr];
        if (known !== undefined) {
            dolphinActive = known;
            return;
        }
        pendingAddr = activeAddr;
        console.log("LOOK: mirando si la ventana", activeAddr, "es la principal de Dolphin");
        mainCheck.running = false;
        mainCheck.running = true;
    }

    Process {
        id: mainCheck

        command: [Quickshell.shellPath("bin/look-dolphin.sh"), "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Si el foco ya se fue a otra ventana, la respuesta no sirve (el script mira la activa)
                if (root.pendingAddr !== root.activeAddr)
                    return;
                const main = text.trim() === "main";
                root.mainCache[root.pendingAddr] = main;
                root.dolphinActive = root.activeClass === "org.kde.dolphin" && main;
            }
        }
    }

    // Lo nombra shell.qml al arrancar. Una recarga del shell puede dejar puesto el atajo de la
    // ejecución anterior: se saca siempre y se vuelve a poner si hace falta.
    function start(): void {
        send("hl.unbind(\"Space\")");
        bound = false;
        current.running = true;
    }

    Process {
        id: current

        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text);
                    root.activeClass = w.class ?? "";
                    root.activeAddr = String(w.address ?? "").replace("0x", "");
                } catch (e) {
                    root.activeClass = "";
                    root.activeAddr = "";
                }
                root.check();
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "activewindow") {
                // «clase,título»: el título puede tener comas, la clase no. Una ventana que no es Dolphin
                // se resuelve acá; Dolphin espera a activewindowv2, que trae la dirección
                const d = event.data ?? "";
                const i = d.indexOf(",");
                root.activeClass = i < 0 ? d : d.slice(0, i);
                if (root.activeClass !== "org.kde.dolphin")
                    root.dolphinActive = false;
            } else if (event.name === "activewindowv2") {
                root.activeAddr = event.data ?? "";
                root.check();
            } else if (event.name === "windowtitle" && root.activeClass === "org.kde.dolphin" && !root.dolphinActive) {
                // Dolphin recién abierto puede activarse antes de poner su título (y quedar como «diálogo»):
                // se olvida lo que se sabía de esa ventana y se vuelve a mirar. Solo en ese caso: la terminal
                // cambia de título todo el tiempo
                delete root.mainCache[root.activeAddr];
                root.check();
            } else if (event.name === "closewindow") {
                delete root.mainCache[event.data ?? ""];
            } else if (event.name === "configreloaded") {
                // Recargar la configuración de Hyprland borra los atajos puestos a mano
                root.bound = false;
                root.sync();
            }
        }
    }
}
