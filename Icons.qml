pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Íconos de apps. Algunas traen uno que no es el de la marca (Vesktop usa el de Vencord):
// acá se les pone el original. La clave es un trozo del identificador de la app.
Singleton {
    readonly property var overrides: ({
            "vesktop": "file:///usr/share/icons/Papirus-Dark/64x64/apps/discord.svg",
            "discord": "file:///usr/share/icons/Papirus-Dark/64x64/apps/discord.svg",
            // La ventana del juego se llama com.mojang.minecraft y no coincide con el launcher
            "mojang": "file:///usr/share/icons/Papirus-Dark/64x64/apps/minecraft.svg",
            "minecraft": "file:///usr/share/icons/Papirus-Dark/64x64/apps/minecraft.svg",
            "dev.zed": "file:///usr/share/icons/Papirus-Dark/64x64/apps/zed.svg",
            "sung": "file://" + (Quickshell.env("HOME") ?? "/home/jmpyy") + "/.local/share/icons/hicolor/scalable/apps/sung.svg"
        })

    // Ícono propio para ese identificador, o "" si no hay
    function override(id: string): string {
        const key = (id ?? "").toLowerCase();
        for (const part in overrides)
            if (key.includes(part))
                return overrides[part];
        return "";
    }

    // Íconos que las apps instalan en ~/.local/share/icons/hicolor (Sung, por ejemplo): a veces Qt
    // no los encuentra por nombre y el launcher mostraba el ícono genérico. Se buscan a mano:
    // nombre -> archivo, con el escalable primero y si no el PNG más grande.
    property var userIcons: ({})

    function rescan(): void {
        scanner.running = true;
    }

    function userIcon(name: string): string {
        const path = userIcons[(name ?? "").toLowerCase()];
        return path ? "file://" + path : "";
    }

    // El ícono del tema por nombre; si el tema no lo tiene, el que instaló la propia app
    function themed(name: string): string {
        const p = Quickshell.iconPath(name, true);
        return p !== "" ? p : userIcon(name);
    }

    Process {
        id: scanner

        command: ["sh", "-c", "find \"$HOME/.local/share/icons/hicolor\" -path '*/apps/*' -type f \\( -iname '*.png' -o -iname '*.svg' \\) 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const best = {};
                const score = {};
                for (const path of text.split("\n")) {
                    if (path === "")
                        continue;
                    const file = path.slice(path.lastIndexOf("/") + 1);
                    const name = file.slice(0, file.lastIndexOf(".")).toLowerCase();
                    const dir = path.split("/").slice(-3, -2)[0] ?? "";
                    const s = dir === "scalable" ? 100000 : (parseInt(dir) || 1);
                    if (!(name in score) || s > score[name]) {
                        score[name] = s;
                        best[name] = path;
                    }
                }
                Icons.userIcons = best;
            }
        }
    }

    Component.onCompleted: rescan()

    // Ícono de una app: el propio si lo hay; si no, el del tema (nombre o ruta)
    function forApp(id: string, themeIcon: string): string {
        const own = override(id);
        if (own)
            return own;
        const icon = themeIcon || (id ?? "").toLowerCase();
        if (!icon)
            return "";
        // Con "true" devuelve vacío si el tema no tiene el ícono (en vez del cuadro magenta de error)
        return icon.startsWith("/") ? "file://" + icon : themed(icon);
    }
}
