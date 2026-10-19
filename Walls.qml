pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fondos de pantalla: busca las imágenes en las carpetas de siempre, recuerda cuál elegiste
// y avisa a Wallpaper y al bloqueo con `current`.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? ""
    // La carpeta propia va primero: lo que pongas ahí aparece arriba en el selector
    readonly property string userDir: home + "/Imágenes/Fondos"
    readonly property var dirs: [userDir, home + "/Imágenes", home + "/Pictures/Wallpapers", "/usr/share/wallpapers/cachyos-wallpapers"]
    readonly property string stateFile: home + "/.local/share/ombu/fondo.json"

    property string current: Theme.wallpaper
    property var list: []

    function set(path: string): void {
        current = path;
        file.setText(JSON.stringify({
            path: path
        }));
    }

    function rescan(): void {
        finder.running = true;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", userDir, home + "/.local/share/ombu"]);
        try {
            const saved = JSON.parse(file.text());
            if (typeof saved.path === "string" && saved.path !== "")
                current = saved.path;
        } catch (e) {}
        rescan();
    }

    FileView {
        id: file

        path: root.stateFile
        blockLoading: true
        printErrors: false
    }

    Process {
        id: finder

        command: ["sh", "-c", "for d in \"$@\"; do find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort; done", "buscar"].concat(root.dirs)
        stdout: StdioCollector {
            onStreamFinished: root.list = text.split("\n").filter(l => l !== "")
        }
    }
}
