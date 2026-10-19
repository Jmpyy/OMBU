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

    // onAccent: texto sobre el acento (por defecto oscuro) · border2: segundo color del degradé del borde
    // de la ventana activa (si falta, el borde es liso) · shadow: color de la sombra dura de las tarjetas
    // (HardShadow; si falta, no hay sombra) · display: tipografía de los títulos · logo: dibujo de la barra
    // (spider o reactor, ver bin/qt-theme.py; si falta, el de CachyOS)
    readonly property var palettes: [
        {
            // El fondo de pantalla de Peter Parker: negro cálido, papel crema, rojo y el verde azulado
            // de las letras de «Amazing» y de los ojos de la máscara
            id: "spiderman",
            name: "Spider-Man",
            bg: "#161011",
            surface: "#211819",
            track: "#35282a",
            text: "#efe8dc",
            textDim: "#a89c90",
            accent: "#e23b32",
            danger: "#ff7a8a",
            warn: "#f2b84b",
            onAccent: "#fff4e8",
            border2: "#5fb0ae",
            shadow: "#8c231e",
            display: "Bangers",
            logo: "spider",
            folder: "red"
        },
        {
            // Gris acero, rojo y dorado
            id: "ironman",
            name: "Iron Man",
            bg: "#0f1216",
            surface: "#171b21",
            track: "#262c35",
            text: "#e9eef5",
            textDim: "#8d97a6",
            accent: "#e5383b",
            danger: "#ff8a80",
            warn: "#f5b82e",
            onAccent: "#fff6f0",
            border2: "#f2b632",
            shadow: "#8f6b12",
            display: "Bangers",
            logo: "reactor",
            folder: "carmine"
        },
        {
            id: "ombu",
            folder: "violet",
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
            folder: "indigo",
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
            folder: "blue",
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
            folder: "pink",
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
            folder: "yellow",
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
            folder: "cyan",
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
            folder: "green",
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
            folder: "orange",
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
        applyQt();
    }

    // Dolphin, las demás apps Qt, la terminal y el logo de la barra (bin/qt-theme.py). Las ventanas
    // que ya están abiertas no cambian; la siguiente sí. Al terminar sube `logoRev` para que la barra
    // vuelva a leer el logo.
    property int logoRev: 0
    readonly property string logoFile: active.logo ? "file://" + (Quickshell.env("HOME") ?? "") + "/.local/share/ombu/icons/bar-logo.svg?" + logoRev : ""

    function applyQt(): void {
        const p = active;
        qtProc.running = false;
        qtProc.command = [Quickshell.shellPath("bin/qt-theme.py"), "--bg", p.bg, "--surface", p.surface, "--track", p.track, "--text", p.text, "--dim", p.textDim, "--accent", p.accent, "--danger", p.danger, "--warn", p.warn, "--on-accent", p.onAccent ?? "#14131a", "--folder", p.folder, "--accent2", p.border2 ?? "", "--logo", p.logo ?? ""];
        qtProc.running = true;
    }

    Process {
        id: qtProc

        onRunningChanged: if (!running)
            root.logoRev += 1
    }

    // Borde de la ventana activa: el acento del tema. Es un cambio en vivo de Hyprland (no toca tu
    // configuración): una recarga de Hyprland vuelve al color de decorations.lua hasta que se
    // vuelva a aplicar, lo que ombu hace al iniciar.
    function applyBorder(): void {
        const c1 = "rgba(" + String(active.accent).replace("#", "") + "ff)";
        // Con un segundo color el borde es un degradé en diagonal (en Lua, una tabla con colors y angle); si no, liso
        const value = active.border2 ? "{ colors = { \"" + c1 + "\", \"rgba(" + String(active.border2).replace("#", "") + "ff)\" }, angle = 45 }" : "\"" + c1 + "\"";
        const isComic = Boolean(active.shadow);
        const inact = isComic ? "\"rgba(0a0708ff)\"" : "\"rgba(ffffff14)\"";
        const rnd = isComic ? 8 : 14;
        const shRange = isComic ? 8 : 24;
        const shPwr = isComic ? 4 : 3;
        const shOff = isComic ? "{ 5, 5 }" : "{ 0, 0 }";
        const shCol = isComic ? "\"rgba(0a0708f0)\"" : "\"rgba(00000070)\"";
        Quickshell.execDetached([
            "hyprctl", "eval",
            "hl.config({ general = { col = { active_border = " + value + ", inactive_border = " + inact + " } }, decoration = { rounding = " + rnd + ", shadow = { offset = " + shOff + ", range = " + shRange + ", render_power = " + shPwr + ", color = " + shCol + " } } })"
        ]);
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
