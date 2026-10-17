pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Qué muestra el launcher: tus apps favoritas y las que más usás (aprende solo), y qué se
// oculta (los ajustes y herramientas del sistema que casi nunca se abren a mano).
// Se guarda en ~/.local/share/ombu/launcher.json.
Singleton {
    id: root

    // Favoritas, en orden. Son los ids de los .desktop (sin la extensión).
    property var favorites: ["zen", "vesktop", "kitty", "org.kde.dolphin", "minecraft-launcher"]
    // Cuántas veces abriste cada app: { id: veces }
    property var usage: ({})
    // Apps que elegiste ocultar a mano (por id), además de las reglas de abajo
    property var hiddenIds: []

    // Hasta cuántas apps se muestran con la búsqueda vacía
    readonly property int maxTiles: 12

    // Cosas del sistema que no se muestran en la lista principal (sí al buscarlas por nombre)
    readonly property var hiddenCategories: ["Settings", "DesktopSettings", "HardwareSettings", "X-XFCE-SettingsDialog"]
    readonly property var hiddenPattern: /avahi|qv4l2|qvidcap|xgps|rofi|uuctl|schedext|limine|cachyos-hello|noctalia/i

    readonly property string dataDir: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu"

    function isHidden(entry: var): bool {
        if (hiddenIds.includes(entry.id))
            return true;
        if (Array.from(entry.categories ?? []).some(c => hiddenCategories.includes(c)))
            return true;
        return hiddenPattern.test(entry.id + " " + entry.name);
    }

    function isFavorite(id: string): bool {
        return favorites.includes(id);
    }

    // Las apps de la vista inicial: favoritas primero, después las más usadas
    function tiles(apps: var): var {
        const byId = {};
        for (const a of apps)
            byId[a.id] = a;
        const out = [];
        const seen = {};
        for (const id of favorites) {
            const a = byId[id];
            if (a && !isHidden(a)) {
                out.push(a);
                seen[id] = true;
            }
        }
        const used = apps.filter(a => !seen[a.id] && !isHidden(a) && (usage[a.id] ?? 0) > 0).sort((a, b) => usage[b.id] - usage[a.id]);
        for (const a of used) {
            if (out.length >= maxTiles)
                break;
            out.push(a);
        }
        return out;
    }

    // Las ventanas abiertas de una app (se compara por id, clase de ventana o nombre)
    function windowsOf(entry: var): var {
        const id = entry.id.toLowerCase();
        const cls = (entry.startupClass ?? "").toLowerCase();
        const name = entry.name.toLowerCase();
        return Apps.windows.filter(t => {
            const app = (t.wayland?.appId ?? "").toLowerCase();
            return app !== "" && (app === id || app === cls || app === name || DesktopEntries.heuristicLookup(app)?.id === entry.id);
        });
    }

    // Abre la app; si ya tiene una ventana abierta, la enfoca (forceNew abre una nueva)
    function open(entry: var, forceNew: bool): void {
        if (!entry)
            return;
        record(entry.id);
        Ui.launcherOpen = false;
        const wins = forceNew ? [] : windowsOf(entry);
        if (wins.length > 0) {
            const t = wins[0];
            const address = "address:0x" + t.address;
            if (t.workspace?.name === "special:minimized") {
                // Minimizada: se trae al escritorio actual
                let here = Hyprland.focusedWorkspace?.id ?? 1;
                if (here < 1)
                    here = 1;
                Hyprland.dispatch("function() hl.dispatch(hl.dsp.focus({ window = \"" + address + "\" })); hl.dispatch(hl.dsp.window.move({ workspace = \"" + here + "\" })) end");
            } else {
                Hyprland.dispatch("hl.dsp.focus({ window = \"" + address + "\" })");
            }
            return;
        }
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e"].concat(entry.command));
        else
            entry.execute();
    }

    function record(id: string): void {
        const copy = Object.assign({}, usage);
        copy[id] = (copy[id] ?? 0) + 1;
        usage = copy;
        save();
    }

    function toggleFavorite(id: string): void {
        favorites = isFavorite(id) ? favorites.filter(f => f !== id) : favorites.concat([id]);
        save();
    }

    function save(): void {
        saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 400
        onTriggered: file.setText(JSON.stringify({
            favorites: root.favorites,
            usage: root.usage,
            hiddenIds: root.hiddenIds
        }, null, 2) + "\n")
    }

    FileView {
        id: file

        path: root.dataDir + "/launcher.json"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", dataDir]);
        try {
            const saved = JSON.parse(file.text());
            if (Array.isArray(saved.favorites))
                favorites = saved.favorites;
            if (saved.usage && typeof saved.usage === "object")
                usage = saved.usage;
            if (Array.isArray(saved.hiddenIds))
                hiddenIds = saved.hiddenIds;
        } catch (e) {
            // Primera vez: se quedan las favoritas de fábrica
        }
    }
}
