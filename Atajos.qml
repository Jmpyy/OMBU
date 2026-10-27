pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Atajos de teclado para el menú de atajos: se leen de Hyprland (`hyprctl binds -j`), solo los
// que tienen descripción (ver hypr/atajos.lua), agrupados por categoría.
Singleton {
    id: root

    // [{category, text, alternatives: [[tecla, tecla, ...], ...]}]
    property var entries: []

    readonly property var categoryOrder: ["Apps", "Estudio e IA", "Ventanas", "Escritorios", "Capturas", "Notificaciones", "Sistema"]
    readonly property var keyNames: ({
            "Return": "Enter",
            "Escape": "Esc",
            "Space": "Espacio",
            "Left": "←",
            "Right": "→",
            "Up": "↑",
            "Down": "↓",
            "Minus": "-",
            "Plus": "+",
            "mouse:272": "Clic izq.",
            "mouse:273": "Clic der.",
            "mouse_down": "Rueda",
            "mouse_up": "Rueda"
        })

    function refresh(): void {
        reader.running = true;
    }

    // Super + Shift + Q a partir de la máscara de modificadores de Hyprland
    function chips(bind: var): var {
        const out = [];
        if (bind.modmask & 64)
            out.push("Super");
        if (bind.modmask & 4)
            out.push("Ctrl");
        if (bind.modmask & 8)
            out.push("Alt");
        if (bind.modmask & 1)
            out.push("Shift");
        const key = bind.key !== "" ? bind.key : "code:" + bind.keycode;
        out.push(keyNames[key] ?? (key.length === 1 ? key.toUpperCase() : key));
        return out;
    }

    function parse(json: string): var {
        let binds = [];
        try {
            binds = JSON.parse(json);
        } catch (e) {}
        const list = [];
        for (const b of binds) {
            if (!b.description)
                continue;
            const parts = b.description.split("|");
            if (parts.length < 2)
                continue;
            const alternatives = parts.length > 2 ? parts[2].split("  /  ").map(a => a.split(" + ")) : [chips(b)];
            list.push({
                category: parts[0],
                text: parts[1],
                alternatives: alternatives
            });
        }
        // Por categoría en el orden fijo; dentro de cada una se respeta el orden de la configuración
        const rank = c => categoryOrder.indexOf(c) < 0 ? categoryOrder.length : categoryOrder.indexOf(c);
        return list.map((e, i) => ({
                    e: e,
                    i: i
                })).sort((a, b) => rank(a.e.category) - rank(b.e.category) || a.i - b.i).map(x => x.e);
    }

    Process {
        id: reader

        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = root.parse(text)
        }
    }

    Component.onCompleted: refresh()
}
