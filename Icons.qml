pragma Singleton

import QtQuick
import Quickshell

// Íconos de apps. Algunas traen uno que no es el de la marca (Vesktop usa el de Vencord):
// acá se les pone el original. La clave es un trozo del identificador de la app.
Singleton {
    readonly property var overrides: ({
            "vesktop": "file:///usr/share/icons/Papirus-Dark/64x64/apps/discord.svg",
            "discord": "file:///usr/share/icons/Papirus-Dark/64x64/apps/discord.svg",
            // La ventana del juego se llama com.mojang.minecraft y no coincide con el launcher
            "mojang": "file:///usr/share/icons/Papirus-Dark/64x64/apps/minecraft.svg",
            "minecraft": "file:///usr/share/icons/Papirus-Dark/64x64/apps/minecraft.svg"
        })

    // Ícono propio para ese identificador, o "" si no hay
    function override(id: string): string {
        const key = (id ?? "").toLowerCase();
        for (const part in overrides)
            if (key.includes(part))
                return overrides[part];
        return "";
    }

    // Ícono de una app: el propio si lo hay; si no, el del tema (nombre o ruta)
    function forApp(id: string, themeIcon: string): string {
        const own = override(id);
        if (own)
            return own;
        const icon = themeIcon || (id ?? "").toLowerCase();
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "application-x-executable");
    }
}
