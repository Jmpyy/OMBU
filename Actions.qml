pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Catálogo de acciones de ombu: el launcher (LauncherMenu) las encuentra al escribir («apagar», «tema»,
// «captura»...) y el menú de la araña (MainMenu) usa las de la sesión y el sistema por su nombre.
// Cada fila: name, icon, y o bien children (sección) o run (acción). Opcionales:
//   hint: texto a la derecha (el atajo) · keywords: otras palabras para encontrarla
//   swatch: colores de un tema · checked: marca la opción actual
//   confirm: pide un segundo Enter o clic · keepOpen: no cierra el menú al ejecutar
Singleton {
    id: root

    // Abre un menú de la barra (calendario, mezcladora...) en el monitor con foco
    function openPopup(kind: string): void {
        Ui.popup = kind + "@" + (Hyprland.focusedMonitor?.name ?? "");
    }

    function sh(cmd: var): void {
        Quickshell.execDetached(cmd);
    }

    function side(tab: string): void {
        Ui.sideTab = tab;
        Ui.sideOpen = true;
    }

    // Corre una acción un rato después, cuando el menú que la pidió ya se cerró (si no, lo que abra se
    // encuentra con ese menú encima y le roba el foco). Vive en el singleton: sobrevive al menú.
    function runLater(f: var): void {
        pending = f;
        laterTimer.restart();
    }

    property var pending: null

    Timer {
        id: laterTimer

        interval: 260
        onTriggered: {
            const f = root.pending;
            root.pending = null;
            if (f)
                f();
        }
    }

    function find(name: string): var {
        const walk = list => {
            for (const n of list) {
                if (n.name === name)
                    return n;
                if (n.children) {
                    const r = walk(n.children);
                    if (r)
                        return r;
                }
            }
            return null;
        };
        return walk(tree);
    }

    readonly property var tree: [
        {
            name: "Apps",
            icon: "apps",
            hint: "Super+Espacio",
            keywords: "launcher aplicaciones programas",
            run: () => {
                Ui.launcherOpen = true;
            }
        },
        {
            name: "Estudio",
            icon: "school",
            children: [
                {
                    name: "Anotar",
                    icon: "edit_note",
                    hint: "Super+Alt+N",
                    keywords: "parcial entrega tp nota agenda facultad",
                    run: () => {
                        Ui.noteOpen = true;
                    }
                },
                {
                    name: "Chat con la IA",
                    icon: "forum",
                    hint: "Super+Shift+A",
                    keywords: "claude antigravity agente pregunta",
                    run: () => root.side("chat")
                },
                {
                    name: "Modo foco",
                    icon: "timer",
                    keywords: "pomodoro estudiar concentración",
                    run: () => root.openPopup("focus")
                },
                {
                    name: "Calendario",
                    icon: "calendar_month",
                    keywords: "agenda eventos fechas",
                    run: () => root.openPopup("calendar")
                }
            ].concat(Facu.subjects.map(s => ({
                        name: "Notas de " + s.name,
                        icon: "sticky_note_2",
                        hint: s.notes > 0 ? s.notes + (s.notes === 1 ? " nota" : " notas") : "",
                        keywords: "materia apuntes " + (s.aliases ?? []).join(" "),
                        run: () => Facu.openNotes(s)
                    })))
        },
        {
            name: "Estilo",
            icon: "palette",
            children: [
                {
                    name: "Tema",
                    icon: "format_color_fill",
                    keywords: "colores apariencia",
                    children: Themes.palettes.map(p => ({
                                name: p.name,
                                icon: "circle",
                                themeId: p.id,
                                swatch: [p.bg, p.surface, p.accent],
                                checked: Themes.current === p.id,
                                keywords: "tema",
                                keepOpen: true,
                                run: () => Themes.set(p.id)
                            }))
                },
                {
                    name: "Fondo de pantalla",
                    icon: "wallpaper",
                    hint: "Super+Ctrl+Espacio",
                    keywords: "wallpaper imagen",
                    run: () => {
                        Ui.wallMenuOpen = true;
                    }
                }
            ]
        },
        {
            name: "Ajustes",
            icon: "tune",
            children: [
                {
                    name: "Brillo y volumen",
                    icon: "brightness_6",
                    keywords: "centro de control pantalla sonido",
                    run: () => root.openPopup("control")
                },
                {
                    name: "Mezcladora de sonido",
                    icon: "volume_up",
                    keywords: "audio salida micrófono",
                    run: () => root.openPopup("mixer")
                },
                {
                    name: "Cambiar la distribución del teclado",
                    icon: "keyboard",
                    hint: Keyboard.code,
                    keywords: "idioma layout",
                    keepOpen: true,
                    run: () => Keyboard.toggle()
                },
                {
                    name: Notifs.dnd ? "Desactivar No molestar" : "Activar No molestar",
                    icon: Notifs.dnd ? "notifications_active" : "notifications_off",
                    hint: Notifs.dnd ? "Activado" : "",
                    keywords: "notificaciones silencio avisos",
                    keepOpen: true,
                    run: () => {
                        Notifs.dnd = !Notifs.dnd;
                    }
                },
                {
                    name: "Google Calendar y agenda",
                    icon: "event",
                    keywords: "cuenta conectar",
                    run: () => root.openPopup("calendar")
                }
            ]
        },
        {
            name: "Capturas",
            icon: "photo_camera",
            children: [
                {
                    name: "Región y editor",
                    icon: "crop",
                    hint: "Impr",
                    keywords: "captura screenshot pantallazo",
                    run: () => root.sh([Quickshell.shellPath("bin/shot.sh"), "edit"])
                },
                {
                    name: "Región directa",
                    icon: "screenshot_region",
                    hint: "Shift+Impr",
                    keywords: "captura screenshot",
                    run: () => root.sh([Quickshell.shellPath("bin/shot.sh"), "quick"])
                },
                {
                    name: "Todo el monitor",
                    icon: "desktop_windows",
                    hint: "Super+Impr",
                    keywords: "captura screenshot pantalla completa",
                    run: () => root.sh([Quickshell.shellPath("bin/shot.sh"), "full"])
                },
                {
                    name: "Copiar el texto de una región",
                    icon: "text_fields",
                    hint: "Ctrl+Impr",
                    keywords: "ocr leer texto captura",
                    run: () => root.sh([Quickshell.shellPath("bin/shot.sh"), "ocr"])
                },
                {
                    name: "Elegir un color de la pantalla",
                    icon: "colorize",
                    hint: "Super+P",
                    keywords: "cuentagotas color picker",
                    run: () => root.sh(["hyprpicker", "-a", "-n"])
                }
            ]
        },
        {
            name: "Herramientas",
            icon: "construction",
            children: [
                {
                    name: "Portapapeles",
                    icon: "content_paste",
                    hint: "Super+V",
                    keywords: "copiar pegar historial",
                    run: () => {
                        Ui.clipOpen = true;
                    }
                },
                {
                    name: "Atajos de teclado",
                    icon: "keyboard_command_key",
                    hint: "Super+K",
                    keywords: "keybinds teclas",
                    run: () => {
                        Ui.keysOpen = true;
                    }
                },
                {
                    name: "Panel lateral",
                    icon: "side_navigation",
                    hint: "Super+A",
                    keywords: "resumen agenda",
                    run: () => root.side("resumen")
                },
                {
                    name: "Pagos y suscripciones",
                    icon: "payments",
                    keywords: "vencimientos dinero",
                    run: () => root.side("resumen")
                },
                {
                    name: "Seguridad y procesos",
                    icon: "shield",
                    keywords: "puertos firewall servicios memoria procesador sistema",
                    run: () => root.side("sistema")
                },
                {
                    // Cada recarga de un .qml deja memoria sin liberar: reiniciar la devuelve (~310 MB)
                    name: "Reiniciar ombu",
                    icon: "refresh",
                    keywords: "recargar shell memoria quickshell",
                    confirm: true,
                    run: () => root.sh(["sh", "-c", "sleep 0.4; qs -c ombu kill >/dev/null 2>&1; sleep 1; setsid -f quickshell -c ombu -n -d >/dev/null 2>&1"])
                },
                {
                    name: "Actualizar el sistema",
                    icon: "system_update",
                    keywords: "paru pacman update paquetes",
                    run: () => Seguridad.upgradeInTerminal()
                }
            ]
        },
        {
            name: "Sistema",
            icon: "power_settings_new",
            children: [
                {
                    name: "Bloquear",
                    icon: "lock",
                    hint: "Super+Ctrl+L",
                    keywords: "lock pantalla",
                    run: () => {
                        Ui.lockPreview = false;
                        Ui.locked = true;
                    }
                },
                {
                    // No suspende de verdad (la placa NVIDIA no despierta bien): bloquea y deja el salvapantallas
                    name: "Reposo",
                    icon: "bedtime",
                    keywords: "suspender dormir",
                    run: () => {
                        Ui.lockPreview = false;
                        Idle.lockedByIdle = true;
                        Ui.locked = true;
                    }
                },
                {
                    name: "Cerrar sesión",
                    icon: "logout",
                    keywords: "salir logout",
                    confirm: true,
                    run: () => Goodbye.run("logout")
                },
                {
                    name: "Reiniciar",
                    icon: "restart_alt",
                    keywords: "reboot",
                    confirm: true,
                    run: () => Goodbye.run("reboot")
                },
                {
                    name: "Apagar",
                    icon: "power_settings_new",
                    keywords: "shutdown apagado",
                    confirm: true,
                    run: () => Goodbye.run("poweroff")
                }
            ]
        }
    ]

    // Todas las acciones del árbol, con la sección a la que pertenecen (para buscar)
    function flatten(list: var, crumbs: var): var {
        let out = [];
        for (const n of list) {
            if (n.children)
                out = out.concat(flatten(n.children, crumbs.concat([n.name])));
            else
                out.push(Object.assign({}, n, {
                    crumb: crumbs.join(" › ")
                }));
        }
        return out;
    }

    readonly property var flat: flatten(tree, [])

    // Puntaje de una acción contra lo escrito (0 = no coincide), para el launcher y el buscador del menú
    function score(n: var, q: string): int {
        const name = n.name.toLowerCase();
        if (name.startsWith(q))
            return 90;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 70;
        if (name.includes(q))
            return 50;
        if ((n.keywords ?? "").toLowerCase().split(/\s+/).some(w => w.startsWith(q)))
            return 40;
        if ((n.crumb ?? "").toLowerCase().includes(q))
            return 20;
        return 0;
    }

    function search(q: string): var {
        q = q.trim().toLowerCase();
        if (q === "")
            return [];
        return flat.map(n => ({
                    n: n,
                    s: score(n, q)
                })).filter(x => x.s > 0).sort((a, b) => b.s - a.s).map(x => x.n);
    }
}
