import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Menú de la araña (el logo de la barra, o Super+Alt+Espacio), a la manera del menú de Apple: cuelga de
// la barra y tiene solo la sesión y el sistema. Cada cosa vive en un solo lugar: lo que se prende y
// apaga seguido (brillo, volumen, foco, No molestar, teclado) está en el centro de control, lo de la
// facultad en el panel lateral, y todo se encuentra escribiendo en el launcher (Super+Espacio).
// Apariencia abre una segunda página con los temas: pasar por encima los previsualiza.
// Lo que corta la sesión (cerrar sesión, reiniciar, apagar) pide un segundo clic o Enter.
DropPopup {
    id: root

    // "main" o "temas"
    property string page: "main"
    // Fila que pidió confirmación
    property string armed: ""
    // Fila resaltada (teclado o mouse), índice entre las que se pueden elegir
    property int sel: -1
    property int uptime: 0
    // Tema resaltado (mouse o teclado), para previsualizarlo
    readonly property string hoverTheme: page === "temas" ? (rows[sel]?.themeId ?? "") : ""

    readonly property var mainRows: [
        {
            kind: "row",
            name: "Apariencia",
            icon: "palette",
            hint: (Themes.palettes.find(p => p.id === Themes.current)?.name ?? ""),
            page: "temas"
        },
        {
            kind: "row",
            name: "Fondo de pantalla",
            icon: "wallpaper",
            hint: "Super+Ctrl+Espacio",
            action: "Fondo de pantalla"
        },
        {
            kind: "row",
            name: "Atajos de teclado",
            icon: "keyboard_command_key",
            hint: "Super+K",
            action: "Atajos de teclado"
        },
        {
            kind: "sep"
        },
        {
            kind: "row",
            name: "Actualizar el sistema",
            icon: "system_update",
            badge: Seguridad.pending > 0 ? String(Seguridad.pending) : "",
            action: "Actualizar el sistema"
        },
        {
            kind: "row",
            name: "Seguridad y procesos",
            icon: "shield",
            action: "Seguridad y procesos"
        },
        {
            kind: "row",
            name: "Reiniciar ombu",
            icon: "refresh",
            action: "Reiniciar ombu"
        },
        {
            kind: "sep"
        },
        {
            kind: "row",
            name: "Reposo",
            icon: "bedtime",
            action: "Reposo"
        },
        {
            kind: "row",
            name: "Bloquear",
            icon: "lock",
            hint: "Super+Ctrl+L",
            action: "Bloquear"
        },
        {
            kind: "sep"
        },
        {
            kind: "row",
            name: "Cerrar sesión",
            icon: "logout",
            action: "Cerrar sesión"
        },
        {
            kind: "row",
            name: "Reiniciar",
            icon: "restart_alt",
            action: "Reiniciar"
        },
        {
            kind: "row",
            name: "Apagar",
            icon: "power_settings_new",
            action: "Apagar"
        }
    ]

    readonly property var themeRows: [
        {
            kind: "back",
            name: "Apariencia",
            icon: "chevron_left"
        },
        {
            kind: "sep"
        }
    ].concat(Themes.palettes.map(p => ({
                kind: "row",
                name: p.name,
                themeId: p.id,
                swatch: [p.bg, p.surface, p.accent],
                checked: Themes.current === p.id
            })))

    readonly property var rows: page === "temas" ? themeRows : mainRows
    readonly property var selectable: rows.map((r, i) => r.kind === "sep" ? -1 : i).filter(i => i >= 0)

    function needsConfirm(r: var): bool {
        const a = r.action ? Actions.find(r.action) : null;
        return !!(a && a.confirm);
    }

    function activate(r: var): void {
        if (!r)
            return;
        if (r.kind === "back") {
            page = "main";
            sel = -1;
            return;
        }
        if (r.page) {
            page = r.page;
            sel = -1;
            return;
        }
        if (r.themeId) {
            Themes.set(r.themeId);
            return;
        }
        const a = Actions.find(r.action);
        if (!a)
            return;
        if (a.confirm && armed !== r.name) {
            armed = r.name;
            disarm.restart();
            return;
        }
        armed = "";
        root.dismissed();
        Actions.runLater(a.run);
    }

    function move(d: int): void {
        const list = selectable;
        if (list.length === 0)
            return;
        const at = list.indexOf(sel);
        sel = list[at < 0 ? (d > 0 ? 0 : list.length - 1) : Math.max(0, Math.min(list.length - 1, at + d))];
    }

    function uptimeText(sec: int): string {
        const h = Math.floor(sec / 3600);
        const m = Math.floor(sec % 3600 / 60);
        return h >= 24 ? Math.floor(h / 24) + " d " + (h % 24) + " h" : (h > 0 ? h + " h " + m + " min" : m + " min");
    }

    onOpenChanged: {
        if (open) {
            page = Ui.sysMenuStart.toLowerCase().includes("tema") ? "temas" : "main";
            Ui.sysMenuStart = "";
            armed = "";
            sel = -1;
            uptimeProc.running = true;
            Seguridad.load(false);
            Qt.callLater(() => keys.forceActiveFocus());
        }
    }

    alignLeft: true
    // Tiene su propia navegación con flechas (ver `keys`)
    keyboardNav: false
    bodyWidth: 300
    bodyHeight: col.implicitHeight + 16

    // Vista previa del tema resaltado mientras se elige
    Binding {
        target: Themes
        property: "preview"
        value: root.hoverTheme
        when: root.open && root.page === "temas"
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    Process {
        id: uptimeProc

        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: root.uptime = parseInt(text) || 0
        }
    }

    // Teclado: flechas, Enter, Esc (vuelve de la página de temas o cierra), ← vuelve
    Item {
        id: keys

        focus: true
        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onReturnPressed: root.activate(root.rows[root.sel])
        Keys.onEnterPressed: root.activate(root.rows[root.sel])
        Keys.onRightPressed: if (root.rows[root.sel]?.page)
            root.activate(root.rows[root.sel])
        Keys.onLeftPressed: if (root.page !== "main") {
            root.page = "main";
            root.sel = -1;
        }
        Keys.onEscapePressed: {
            if (root.page !== "main") {
                root.page = "main";
                root.sel = -1;
            } else {
                root.dismissed();
            }
        }
    }

    ColumnLayout {
        id: col

        x: 8
        y: 8
        width: parent.width - 16
        spacing: 2

        // Quién sos y hace cuánto está prendida
        RowLayout {
            visible: root.page === "main"
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.topMargin: 2
            Layout.bottomMargin: 6
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Theme.comic ? 7 : 17
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                border.width: Theme.comic ? 1.5 : 0
                border.color: Theme.ink

                Text {
                    anchors.centerIn: parent
                    text: Estacion.displayName.charAt(0).toUpperCase()
                    color: Theme.accent
                    font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: Estacion.displayName
                    color: Theme.text
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: "CachyOS · " + (root.uptime > 0 ? "encendida hace " + root.uptimeText(root.uptime) : "ombu")
                    elide: Text.ElideRight
                    color: Theme.textDim
                    font.pixelSize: Theme.fontCaption
                }
            }
        }

        Rectangle {
            visible: root.page === "main"
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        Repeater {
            model: root.rows

            Item {
                id: entry

                required property var modelData
                required property int index
                readonly property bool isSep: modelData.kind === "sep"
                readonly property bool isArmed: root.armed === modelData.name && !!modelData.action
                readonly property bool current: root.sel === index
                readonly property bool danger: root.needsConfirm(modelData)

                Layout.fillWidth: true
                Layout.preferredHeight: isSep ? 9 : 32

                Rectangle {
                    visible: entry.isSep
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    width: parent.width - 12
                    height: 1
                    color: Theme.border
                }

                Rectangle {
                    visible: !entry.isSep
                    anchors.fill: parent
                    radius: Theme.controlRadius - 3
                    color: entry.isArmed ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22) : (entry.current ? (Theme.comic ? Qt.rgba(1, 1, 1, 0.08) : Theme.surface) : "transparent")
                    border.width: Theme.comic && entry.current ? 1.5 : 0
                    border.color: Theme.ink

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        // Ícono, o los tres colores del tema
                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20

                            MIcon {
                                visible: !entry.modelData.swatch
                                anchors.centerIn: parent
                                name: entry.modelData.icon ?? ""
                                font.pixelSize: Theme.iconSm
                                color: entry.isArmed || (entry.danger && entry.current) ? Theme.danger : (entry.modelData.kind === "back" ? Theme.textDim : Theme.text)
                            }

                            Row {
                                visible: !!entry.modelData.swatch
                                anchors.centerIn: parent
                                spacing: -4

                                Repeater {
                                    model: entry.modelData.swatch ?? []

                                    Rectangle {
                                        required property string modelData

                                        width: 11
                                        height: 11
                                        radius: 6
                                        color: modelData
                                        border.width: 1
                                        border.color: Qt.rgba(0, 0, 0, 0.5)
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry.isArmed ? "Clic otra vez para " + entry.modelData.name.toLowerCase() : entry.modelData.name + (entry.danger ? "…" : "")
                            elide: Text.ElideRight
                            color: entry.isArmed ? Theme.danger : (entry.modelData.kind === "back" ? Theme.textDim : Theme.text)
                            font.pixelSize: Theme.fontBody
                            font.weight: entry.isArmed || entry.modelData.kind === "back" ? Font.DemiBold : Font.Normal
                        }

                        Rectangle {
                            visible: (entry.modelData.badge ?? "") !== ""
                            implicitWidth: badgeText.implicitWidth + 12
                            implicitHeight: 18
                            radius: 9
                            color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.2)

                            Text {
                                id: badgeText

                                anchors.centerIn: parent
                                text: entry.modelData.badge ?? ""
                                color: Theme.warn
                                font.pixelSize: Theme.fontTiny
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            visible: !entry.isArmed && (entry.modelData.hint ?? "") !== ""
                            text: entry.modelData.hint ?? ""
                            color: Theme.textDim
                            font.pixelSize: Theme.fontCaption
                        }

                        MIcon {
                            visible: entry.modelData.checked === true
                            name: "check"
                            font.pixelSize: Theme.iconSm
                            color: Theme.accent
                        }

                        MIcon {
                            visible: !!entry.modelData.page
                            name: "chevron_right"
                            font.pixelSize: Theme.iconSm
                            color: Theme.textDim
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered)
                                root.sel = entry.index;
                        }
                    }
                    TapHandler {
                        onTapped: root.activate(entry.modelData)
                    }
                }
            }
        }
    }
}
