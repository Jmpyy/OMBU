pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Temas de color de todo ombu (barra, menús, avisos, bloqueo): una paleta elegida cambia los
// colores de Theme.qml en vivo. Se recuerda en ~/.local/share/ombu/tema.json y, al elegirla, también
// pinta el borde de la ventana activa de Hyprland. Todos son oscuros: el texto sobre el color de
// acento es siempre oscuro (#14131a), así que el acento tiene que ser claro.
Singleton {
    id: root

    readonly property var palettes: [
        {
            id: "ombu",
            name: "Ombú",
            bg: "#14131a",
            surface: "#1d1c26",
            track: "#2b2a38",
            text: "#e8e8f0",
            textDim: "#8a8a9c",
            accent: "#a78bfa",
            danger: "#f87171",
            warn: "#fbbf24"
        },
        {
            id: "tokyo",
            name: "Tokyo Night",
            bg: "#1a1b26",
            surface: "#24283b",
            track: "#2f334d",
            text: "#c0caf5",
            textDim: "#7f87ad",
            accent: "#7aa2f7",
            danger: "#f7768e",
            warn: "#e0af68"
        },
        {
            id: "catppuccin",
            name: "Catppuccin",
            bg: "#1e1e2e",
            surface: "#2a2b3c",
            track: "#363849",
            text: "#cdd6f4",
            textDim: "#9399b2",
            accent: "#89b4fa",
            danger: "#f38ba8",
            warn: "#f9e2af"
        },
        {
            id: "rosepine",
            name: "Rosé Pine",
            bg: "#191724",
            surface: "#1f1d2e",
            track: "#2a2740",
            text: "#e0def4",
            textDim: "#908caa",
            accent: "#ebbcba",
            danger: "#eb6f92",
            warn: "#f6c177"
        },
        {
            id: "gruvbox",
            name: "Gruvbox",
            bg: "#1d2021",
            surface: "#282828",
            track: "#3c3836",
            text: "#ebdbb2",
            textDim: "#a89984",
            accent: "#fabd2f",
            danger: "#fb4934",
            warn: "#fe8019"
        },
        {
            id: "nord",
            name: "Nord",
            bg: "#2e3440",
            surface: "#3b4252",
            track: "#434c5e",
            text: "#eceff4",
            textDim: "#9aa5b8",
            accent: "#88c0d0",
            danger: "#bf616a",
            warn: "#ebcb8b"
        },
        {
            id: "everforest",
            name: "Everforest",
            bg: "#2d353b",
            surface: "#343f44",
            track: "#3d484d",
            text: "#d3c6aa",
            textDim: "#859289",
            accent: "#a7c080",
            danger: "#e67e80",
            warn: "#dbbc7f"
        },
        {
            id: "carbon",
            name: "Carbón",
            bg: "#121212",
            surface: "#1c1c1c",
            track: "#2a2a2a",
            text: "#e6e6e6",
            textDim: "#8c8c8c",
            accent: "#fb923c",
            danger: "#f87171",
            warn: "#fbbf24"
        }
    ]

    // Tema elegido, y el que se está mirando sin confirmar (vacío = ninguno)
    property string current: "ombu"
    property string preview: ""

    readonly property var active: palettes.find(p => p.id === (preview !== "" ? preview : current)) ?? palettes[0]

    readonly property string stateFile: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu/tema.json"

    function find(id: string): var {
        return palettes.find(p => p.id === id) ?? null;
    }

    // Confirma un tema: se recuerda y se pinta el borde de la ventana activa de Hyprland
    function set(id: string): void {
        const p = find(id);
        if (!p)
            return;
        current = p.id;
        preview = "";
        file.setText(JSON.stringify({
            id: p.id
        }));
        applyBorder();
    }

    // Borde de la ventana activa: el acento del tema. Es un cambio en vivo de Hyprland (no toca tu
    // configuración): una recarga de Hyprland vuelve al color de decorations.lua hasta que se
    // vuelva a aplicar, lo que ombu hace al iniciar.
    function applyBorder(): void {
        const hex = String(active.accent).replace("#", "");
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ general = { col = { active_border = \"rgba(" + hex + "ff)\" } } })"]);
    }

    FileView {
        id: file

        path: root.stateFile
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            const saved = JSON.parse(file.text());
            if (typeof saved.id === "string" && find(saved.id))
                current = saved.id;
        } catch (e) {}
        // Con el tema de siempre no hay nada que cambiar; con otro, el borde acompaña al arrancar
        if (current !== "ombu")
            applyBorder();
    }
}
