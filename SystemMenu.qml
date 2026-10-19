import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Menú del sistema (Super+Alt+Espacio), a la manera del de Omarchy: una tarjeta al centro con
// secciones (Apps, Estilo, Ajustes, Capturas, Herramientas, Sistema). Se navega con las flechas,
// Enter entra o ejecuta, Esc o Retroceso vuelven, y escribiendo se busca en todo el menú.
// En Estilo › Tema, moverse por la lista previsualiza cada tema y Esc lo deja como estaba.
PanelWindow {
    id: win

    required property var modelData

    readonly property int maxListHeight: 460

    // Camino de secciones por el que se entró, como nombres ("Estilo", "Tema"). Se guardan los
    // nombres y no los objetos: el árbol se recalcula al cambiar el tema o el teclado, y una
    // sección guardada quedaba con las marcas viejas (la tilde no se movía).
    property var path: []
    // Fila que pidió confirmación (apagar, reiniciar, cerrar sesión): se ejecuta con un segundo Enter
    property string armed: ""
    // Acción que espera a que el menú termine de cerrarse
    property var pending: null

    readonly property var section: {
        let list = tree;
        let node = null;
        for (const name of path) {
            node = list.find(x => x.children && x.name === name) ?? null;
            if (!node)
                return null;
            list = node.children;
        }
        return node;
    }
    readonly property string query: input.text.trim().toLowerCase()

    // Abre un menú de la barra (calendario, mezcladora...) en el monitor con foco
    function openPopup(kind: string): void {
        Ui.popup = kind + "@" + (Hyprland.focusedMonitor?.name ?? "");
    }

    function sh(cmd: var): void {
        Quickshell.execDetached(cmd);
    }

    // El árbol del menú. Cada fila: name, icon, y o bien children (sección) o run (acción).
    //   hint: texto a la derecha · swatch: colores de un tema · checked: marca la opción actual
    //   confirm: pide un segundo Enter · keepOpen: no cierra el menú al ejecutar
    readonly property var tree: [
        {
            name: "Apps",
            icon: "apps",
            hint: "Super+Espacio",
            run: () => {
                Ui.launcherOpen = true;
            }
        },
        {
            name: "Estilo",
            icon: "palette",
            children: [
                {
                    name: "Tema",
                    icon: "format_color_fill",
                    children: Themes.palettes.map(p => ({
                                name: p.name,
                                icon: "circle",
                                themeId: p.id,
                                swatch: [p.bg, p.surface, p.accent],
                                checked: Themes.current === p.id,
                                keepOpen: true,
                                run: () => Themes.set(p.id)
                            }))
                },
                {
                    name: "Fondo de pantalla",
                    icon: "wallpaper",
                    hint: "Super+Ctrl+Espacio",
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
                    run: () => win.openPopup("control")
                },
                {
                    name: "Mezcladora de sonido",
                    icon: "volume_up",
                    run: () => win.openPopup("mixer")
                },
                {
                    name: "Cambiar la distribución del teclado",
                    icon: "keyboard",
                    hint: Keyboard.code,
                    keepOpen: true,
                    run: () => Keyboard.toggle()
                },
                {
                    name: Notifs.dnd ? "Desactivar No molestar" : "Activar No molestar",
                    icon: Notifs.dnd ? "notifications_active" : "notifications_off",
                    hint: Notifs.dnd ? "Activado" : "",
                    keepOpen: true,
                    run: () => {
                        Notifs.dnd = !Notifs.dnd;
                    }
                },
                {
                    name: "Google Calendar y agenda",
                    icon: "event",
                    run: () => win.openPopup("calendar")
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
                    run: () => win.sh([Quickshell.shellPath("bin/shot.sh"), "edit"])
                },
                {
                    name: "Región directa",
                    icon: "screenshot_region",
                    hint: "Shift+Impr",
                    run: () => win.sh([Quickshell.shellPath("bin/shot.sh"), "quick"])
                },
                {
                    name: "Todo el monitor",
                    icon: "desktop_windows",
                    hint: "Super+Impr",
                    run: () => win.sh([Quickshell.shellPath("bin/shot.sh"), "full"])
                },
                {
                    name: "Copiar el texto de una región",
                    icon: "text_fields",
                    hint: "Ctrl+Impr",
                    run: () => win.sh([Quickshell.shellPath("bin/shot.sh"), "ocr"])
                },
                {
                    name: "Elegir un color de la pantalla",
                    icon: "colorize",
                    hint: "Super+P",
                    run: () => win.sh(["hyprpicker", "-a", "-n"])
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
                    run: () => {
                        Ui.clipOpen = true;
                    }
                },
                {
                    name: "Atajos de teclado",
                    icon: "keyboard_command_key",
                    hint: "Super+K",
                    run: () => {
                        Ui.keysOpen = true;
                    }
                },
                {
                    name: "Calendario",
                    icon: "calendar_month",
                    run: () => win.openPopup("calendar")
                },
                {
                    name: "Modo foco",
                    icon: "timer",
                    run: () => win.openPopup("focus")
                },
                {
                    name: "Pagos y suscripciones",
                    icon: "payments",
                    run: () => win.openPopup("payments")
                },
                {
                    name: "Discos y unidades",
                    icon: "hard_drive",
                    run: () => win.openPopup("devices")
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
                    run: () => {
                        Ui.lockPreview = false;
                        Ui.locked = true;
                    }
                },
                {
                    // No suspende de verdad (la placa NVIDIA no despierta bien): bloquea y deja el salvapantallas
                    name: "Reposo",
                    icon: "bedtime",
                    run: () => {
                        Ui.lockPreview = false;
                        Idle.lockedByIdle = true;
                        Ui.locked = true;
                    }
                },
                {
                    name: "Cerrar sesión",
                    icon: "logout",
                    confirm: true,
                    run: () => win.sh(["hyprctl", "dispatch", "hl.dsp.exit()"])
                },
                {
                    name: "Reiniciar",
                    icon: "restart_alt",
                    confirm: true,
                    run: () => win.sh(["systemctl", "reboot"])
                },
                {
                    name: "Apagar",
                    icon: "power_settings_new",
                    confirm: true,
                    run: () => win.sh(["systemctl", "poweroff"])
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

    // Lo que muestra la lista: la sección actual, o los resultados si se está buscando
    readonly property var rows: {
        if (query !== "")
            return flatten(tree, []).filter(n => (n.name + " " + (n.crumb ?? "")).toLowerCase().includes(query));
        return section ? section.children : tree;
    }

    readonly property var currentRow: list.currentIndex >= 0 && list.currentIndex < rows.length ? rows[list.currentIndex] : null

    // De un camino como "Estilo>Tema" a los nombres de las secciones por las que entrar
    function resolve(start: string): var {
        const out = [];
        let list = tree;
        for (const name of start.split(">").map(s => s.trim()).filter(s => s !== "")) {
            const n = list.find(x => x.children && x.name.toLowerCase() === name.toLowerCase());
            if (!n)
                break;
            out.push(n.name);
            list = n.children;
        }
        return out;
    }

    function open_(item: var): void {
        // Esc o Retroceso vuelven; al salir de Tema la vista previa se deshace sola (ver Binding)
        path = path.concat([item.name]);
        input.text = "";
        armed = "";
        list.currentIndex = 0;
    }

    function back(): void {
        armed = "";
        if (input.text !== "") {
            input.text = "";
            return;
        }
        if (path.length > 0) {
            path = path.slice(0, -1);
            list.currentIndex = 0;
            return;
        }
        Ui.sysMenuOpen = false;
    }

    function activate(item: var): void {
        if (!item)
            return;
        if (item.children) {
            open_(item);
            return;
        }
        if (item.confirm && armed !== item.name) {
            armed = item.name;
            disarm.restart();
            return;
        }
        armed = "";
        if (item.keepOpen) {
            item.run();
            return;
        }
        // Se cierra primero y recién después se ejecuta: así lo que abra (un menú, una captura) no
        // se encuentra con este menú encima ni le roba el foco
        Ui.sysMenuOpen = false;
        pending = item.run;
        runTimer.restart();
    }

    Timer {
        id: runTimer

        interval: 260
        onTriggered: {
            if (win.pending) {
                const f = win.pending;
                win.pending = null;
                f();
            }
        }
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: win.armed = ""
    }

    // Vista previa del tema que está resaltado (solo en el monitor que muestra el menú)
    Binding {
        target: Themes
        property: "preview"
        value: win.currentRow?.themeId ?? ""
        when: Ui.sysMenuOpen && win.activeOnScreen
    }

    property real p: Ui.sysMenuOpen ? 1 : 0

    Behavior on p {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    // Guarda el monitor en el que se abrió para completar la animación de cierre
    property bool activeOnScreen: false

    Connections {
        target: Ui

        function onSysMenuOpenChanged() {
            if (!Ui.sysMenuOpen) {
                // Hay una copia del menú por monitor: el camino de arranque se borra recién al cerrar
                Ui.sysMenuStart = "";
                return;
            }
            if (Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
            win.path = win.resolve(Ui.sysMenuStart);
            win.armed = "";
            input.text = "";
            list.currentIndex = 0;
            Qt.callLater(() => input.forceActiveFocus());
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    screen: modelData
    visible: (p > 0.001 && activeOnScreen) || (Ui.sysMenuOpen && Hyprland.focusedMonitor?.name === modelData.name)
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-sysmenu"
    WlrLayershell.keyboardFocus: Ui.sysMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.sysMenuOpen = false
        }
    }

    HardShadow {
        target: card
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14
        width: 620
        height: column.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.outline
        opacity: win.p
        scale: 0.90 + 0.10 * win.p
        transformOrigin: Item.Top

        // Evita que un clic dentro de la tarjeta cierre el menú
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 6

            // Búsqueda y migas de pan
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 12

                MIcon {
                    name: win.section ? "arrow_back" : "search"
                    color: Theme.textDim
                    font.pixelSize: 22

                    TapHandler {
                        enabled: win.section !== null
                        onTapped: win.back()
                    }
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.pixelSize: 18
                    clip: true
                    focus: true

                    Keys.onEscapePressed: win.back()
                    Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                    Keys.onDownPressed: list.currentIndex = Math.min(win.rows.length - 1, list.currentIndex + 1)
                    Keys.onReturnPressed: win.activate(win.currentRow)
                    Keys.onEnterPressed: win.activate(win.currentRow)
                    Keys.onPressed: event => {
                        // Retroceso con el buscador vacío vuelve a la sección anterior
                        if (event.key === Qt.Key_Backspace && input.text === "" && win.path.length > 0) {
                            win.back();
                            event.accepted = true;
                        }
                    }
                    onTextChanged: list.currentIndex = 0

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.section ? win.section.name : "Buscar en el menú…"
                        color: win.section ? Theme.text : Theme.textDim
                        font.pixelSize: 18
                        font.weight: win.section ? Font.DemiBold : Font.Normal
                    }
                }

                Text {
                    text: win.section ? "Esc para volver" : "Esc para cerrar"
                    color: Theme.textDim
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            Text {
                visible: win.rows.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.bottomMargin: 14
                horizontalAlignment: Text.AlignHCenter
                text: "Sin resultados para “" + input.text + "”"
                color: Theme.textDim
                font.pixelSize: 14
            }

            ListView {
                id: list

                visible: win.rows.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, win.maxListHeight)
                model: win.rows
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool isArmed: win.armed === modelData.name
                    readonly property bool current: ListView.isCurrentItem

                    width: ListView.view.width
                    height: 44
                    radius: 10
                    color: current ? Theme.surface : "transparent"

                    HoverHandler {
                        onHoveredChanged: if (hovered)
                            list.currentIndex = row.index
                    }
                    TapHandler {
                        onTapped: win.activate(row.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Ícono en un cuadradito; los temas muestran sus tres colores
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 8
                            color: row.modelData.swatch ? row.modelData.swatch[0] : (row.current ? Theme.track : Theme.surface)
                            border.width: row.modelData.swatch ? 1 : 0
                            border.color: Theme.border

                            MIcon {
                                visible: !row.modelData.swatch
                                anchors.centerIn: parent
                                name: row.modelData.icon
                                font.pixelSize: 18
                                color: row.isArmed ? Theme.warn : Theme.text
                            }

                            Row {
                                visible: row.modelData.swatch !== undefined
                                anchors.centerIn: parent
                                spacing: 2

                                Repeater {
                                    model: row.modelData.swatch ? row.modelData.swatch.slice(1) : []

                                    Rectangle {
                                        required property string modelData

                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.isArmed ? row.modelData.name + ": Enter otra vez para confirmar" : row.modelData.name
                            elide: Text.ElideRight
                            color: row.isArmed ? Theme.warn : Theme.text
                            font.pixelSize: 14
                            font.weight: row.isArmed ? Font.DemiBold : Font.Normal
                        }

                        Text {
                            visible: win.query !== "" && (row.modelData.crumb ?? "") !== ""
                            text: row.modelData.crumb ?? ""
                            color: Theme.textDim
                            font.pixelSize: 12
                        }

                        Text {
                            visible: (row.modelData.hint ?? "") !== ""
                            text: row.modelData.hint ?? ""
                            color: Theme.textDim
                            font.pixelSize: 12
                        }

                        MIcon {
                            visible: row.modelData.checked === true
                            name: "check"
                            font.pixelSize: 18
                            color: Theme.accent
                        }

                        MIcon {
                            visible: row.modelData.children !== undefined
                            name: "chevron_right"
                            font.pixelSize: 20
                            color: Theme.textDim
                        }
                    }
                }
            }
        }
    }
}
