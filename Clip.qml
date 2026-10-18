pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Historial del portapapeles. Lo guarda cliphist (lo arranca bin/clipwatch.sh); acá se lee,
// se borra, se pausa y se manejan los textos fijados.
Singleton {
    id: root

    // Cada entrada: { line, id, preview, image }. La más nueva primero.
    property var entries: []
    // Textos fijados: [{ text }]
    property var pins: []
    // El historial no está guardando lo que se copia
    property bool paused: false
    // Cambia cuando hay miniaturas nuevas, para que las imágenes se vuelvan a leer
    property int thumbRev: 0

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp"
    readonly property string thumbDir: runtimeDir + "/ombu-clip"
    readonly property string pausedFlag: runtimeDir + "/ombu-clip-paused"
    readonly property string dataDir: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu"
    readonly property string pasteScript: Quickshell.shellPath("bin/clip-paste.sh")

    function refresh(): void {
        if (!lister.running)
            lister.running = true;
        if (!pauseCheck.running)
            pauseCheck.running = true;
    }

    function thumb(entry: var): string {
        return "file://" + thumbDir + "/" + entry.id + ".png?" + thumbRev;
    }

    // Copia (y si se pide, pega en la ventana de antes) una entrada o un texto fijado
    function use(item: var, paste: bool): void {
        const mode = paste ? "paste" : "copy";
        if (item.kind === "pin")
            Quickshell.execDetached([pasteScript, mode, "text", item.text]);
        else
            Quickshell.execDetached([pasteScript, mode, "entry", item.id]);
    }

    function remove(item: var): void {
        if (item.kind === "pin") {
            unpin(item.index);
            return;
        }
        // cliphist borra la entrada cuyo renglón (id, tab, vista previa) le llega por stdin
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", item.line]);
        entries = entries.filter(e => e.id !== item.id);
        reloadSoon.restart();
    }

    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }

    function togglePause(): void {
        paused = !paused;
        Quickshell.execDetached(["sh", "-c", paused ? 'touch "$1"' : 'rm -f "$1"', "sh", pausedFlag]);
    }

    function isPinned(text: string): bool {
        return pins.some(p => p.text === text);
    }

    function pin(text: string): void {
        if (!text || isPinned(text))
            return;
        pins = [{
                text: text
            }].concat(pins);
        savePins();
    }

    // Fija una entrada del historial: hay que traer el texto completo (la vista previa está cortada)
    function pinEntry(entry: var): void {
        if (pinner.running)
            return;
        pinner.command = ["cliphist", "decode", entry.id];
        pinner.running = true;
    }

    function unpin(index: int): void {
        pins = pins.filter((p, i) => i !== index);
        savePins();
    }

    function savePins(): void {
        pinsFile.setText(JSON.stringify(pins.map(p => ({
                    text: p.text
                })), null, 2) + "\n");
    }

    function parse(text: string): void {
        const out = [];
        for (const line of text.split("\n")) {
            if (!line)
                continue;
            const tab = line.indexOf("\t");
            if (tab < 0)
                continue;
            const preview = line.slice(tab + 1);
            out.push({
                line: line,
                id: line.slice(0, tab),
                preview: preview,
                image: /^\[\[ binary data .*(png|jpe?g|bmp|webp|gif)/i.test(preview)
            });
        }
        entries = out;
        // Miniaturas de las primeras imágenes
        const ids = out.filter(e => e.image).slice(0, 12).map(e => e.id);
        if (ids.length > 0 && !thumbs.running) {
            thumbs.command = [Quickshell.shellPath("bin/clip-thumbs.sh")].concat(ids);
            thumbs.running = true;
        }
    }

    Process {
        id: lister

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: pinner

        stdout: StdioCollector {
            onStreamFinished: root.pin(text)
        }
    }

    Process {
        id: thumbs

        onExited: root.thumbRev++
    }

    // ¿Está en pausa? (la pausa es un archivo en la carpeta de ejecución)
    Process {
        id: pauseCheck

        command: ["test", "-e", root.pausedFlag]
        onExited: code => root.paused = code === 0
    }

    Timer {
        id: reloadSoon

        interval: 300
        onTriggered: root.refresh()
    }

    FileView {
        id: pinsFile

        path: root.dataDir + "/clipboard-pins.json"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", dataDir]);
        try {
            const saved = JSON.parse(pinsFile.text());
            if (Array.isArray(saved))
                pins = saved.filter(p => p && typeof p.text === "string");
        } catch (e) {
            // Todavía no hay textos fijados
        }
        refresh();
    }
}
