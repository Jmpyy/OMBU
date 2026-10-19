import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Selector de fondos de pantalla (Super+Ctrl+Espacio): un menú grande al centro con una vista previa
// y una cuadrícula de miniaturas. Moverse por la cuadrícula previsualiza el fondo en el propio
// escritorio; Enter lo aplica y Esc lo deja como estaba. Escribir filtra por nombre.
PanelWindow {
    id: win

    required property var modelData

    readonly property int columns: 6
    readonly property string query: input.text.trim().toLowerCase()
    readonly property var items: Walls.list.filter(p => query === "" || baseName(p).toLowerCase().includes(query))
    readonly property string currentPath: items[grid.currentIndex] ?? ""

    function baseName(path: string): string {
        const file = path.slice(path.lastIndexOf("/") + 1);
        const dot = file.lastIndexOf(".");
        return dot > 0 ? file.slice(0, dot) : file;
    }

    function apply(path: string): void {
        if (path === "")
            return;
        Walls.set(path);
        Ui.wallMenuOpen = false;
    }

    function random(): void {
        if (items.length > 0)
            apply(items[Math.floor(Math.random() * items.length)]);
    }

    function openFolder(): void {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && exec xdg-open \"$1\"", "carpeta", Walls.userDir]);
    }

    // Vista previa en el escritorio mientras el selector está abierto (en el monitor que lo muestra)
    Binding {
        target: Walls
        property: "preview"
        value: win.currentPath
        when: Ui.wallMenuOpen && win.activeOnScreen
    }

    property real p: Ui.wallMenuOpen ? 1 : 0

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

        function onWallMenuOpenChanged() {
            if (!Ui.wallMenuOpen)
                return;
            if (Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
            Walls.rescan();
            input.text = "";
            // Arranca parado en el fondo actual
            Qt.callLater(() => {
                const i = win.items.indexOf(Walls.current);
                grid.currentIndex = i >= 0 ? i : 0;
                input.forceActiveFocus();
            });
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    screen: modelData
    visible: (p > 0.001 && activeOnScreen) || (Ui.wallMenuOpen && Hyprland.focusedMonitor?.name === modelData.name)
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-wallpicker"
    WlrLayershell.keyboardFocus: Ui.wallMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Velo suave: se tiene que ver el escritorio para juzgar el fondo
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.28)
        opacity: win.p

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.wallMenuOpen = false
        }
    }

    HardShadow {
        target: card
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(40, (parent.height - height) / 2 - 20)
        width: 880
        height: column.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.outline
        opacity: win.p
        scale: 0.94 + 0.06 * win.p
        transformOrigin: Item.Center

        // Evita que un clic dentro de la tarjeta cierre el selector
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 10

            // Título, búsqueda y acciones
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 10

                MIcon {
                    name: "wallpaper"
                    color: Theme.accent
                    font.pixelSize: 22
                }

                Text {
                    text: "Fondos de pantalla"
                    color: Theme.text
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Text {
                    text: win.items.length + (win.items.length === 1 ? " imagen" : " imágenes")
                    color: Theme.textDim
                    font.pixelSize: 12
                }

                Item {
                    Layout.fillWidth: true
                }

                // Búsqueda por nombre
                Rectangle {
                    Layout.preferredWidth: 190
                    Layout.preferredHeight: 32
                    radius: Theme.controlRadius
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        MIcon {
                            name: "search"
                            font.pixelSize: 17
                            color: Theme.textDim
                        }

                        TextInput {
                            id: input

                            Layout.fillWidth: true
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.onAccent
                            font.pixelSize: 13
                            clip: true
                            focus: true

                            Keys.onEscapePressed: {
                                if (input.text !== "")
                                    input.text = "";
                                else
                                    Ui.wallMenuOpen = false;
                            }
                            Keys.onReturnPressed: win.apply(win.currentPath)
                            Keys.onEnterPressed: win.apply(win.currentPath)
                            Keys.onLeftPressed: event => {
                                // Con texto escrito las flechas laterales mueven el cursor
                                if (input.text === "")
                                    grid.moveCurrentIndexLeft();
                                else
                                    event.accepted = false;
                            }
                            Keys.onRightPressed: event => {
                                if (input.text === "")
                                    grid.moveCurrentIndexRight();
                                else
                                    event.accepted = false;
                            }
                            Keys.onUpPressed: grid.moveCurrentIndexUp()
                            Keys.onDownPressed: grid.moveCurrentIndexDown()
                            onTextChanged: grid.currentIndex = 0

                            Text {
                                visible: input.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Buscar…"
                                color: Theme.textDim
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                Repeater {
                    model: [
                        {
                            icon: "shuffle",
                            label: "Aleatorio",
                            run: () => win.random()
                        },
                        {
                            icon: "folder_open",
                            label: "Mi carpeta",
                            run: () => win.openFolder()
                        }
                    ]

                    Rectangle {
                        id: action

                        required property var modelData

                        Layout.preferredHeight: 32
                        Layout.preferredWidth: actionRow.implicitWidth + 20
                        radius: Theme.controlRadius
                        color: actionHover.hovered ? Theme.hover : Theme.surface

                        Row {
                            id: actionRow

                            anchors.centerIn: parent
                            spacing: 6

                            MIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: action.modelData.icon
                                font.pixelSize: 16
                                color: Theme.text
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: action.modelData.label
                                color: Theme.text
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }

                        HoverHandler {
                            id: actionHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: action.modelData.run()
                        }
                    }
                }
            }

            // Vista previa grande
            Rectangle {
                visible: win.items.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                radius: 14
                color: Theme.surface
                clip: true

                Image {
                    anchors.fill: parent
                    source: win.currentPath !== "" ? "file://" + win.currentPath : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    sourceSize: Qt.size(1760, 600)
                }

                // Nombre y marca de «en uso» sobre la imagen
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    width: nameRow.implicitWidth + 24
                    height: 30
                    radius: 9
                    color: Qt.rgba(0, 0, 0, 0.62)

                    Row {
                        id: nameRow

                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.baseName(win.currentPath)
                            color: "#f4f4fa"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: win.currentPath === Walls.current
                            text: "· en uso"
                            color: Theme.accent
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // Cuadrícula de miniaturas
            GridView {
                id: grid

                visible: win.items.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.ceil(win.items.length / win.columns), 3) * cellHeight
                cellWidth: width / win.columns
                cellHeight: Math.round(cellWidth * 0.5625) + 10
                model: win.items
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                delegate: Item {
                    id: cell

                    required property string modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    readonly property bool inUse: modelData === Walls.current

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 10
                        color: Theme.surface
                        border.width: cell.current ? 2 : 0
                        border.color: Theme.accent

                        Image {
                            anchors.fill: parent
                            anchors.margins: cell.current ? 2 : 0
                            source: "file://" + cell.modelData
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(280, 160)
                            opacity: status === Image.Ready ? (cell.current || cellHover.hovered ? 1 : 0.85) : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }

                        // Marca del que está en uso
                        Rectangle {
                            visible: cell.inUse
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.accent

                            MIcon {
                                anchors.centerIn: parent
                                name: "check"
                                font.pixelSize: 14
                                color: Theme.onAccent
                            }
                        }
                    }

                    HoverHandler {
                        id: cellHover

                        onHoveredChanged: if (hovered)
                            grid.currentIndex = cell.index
                    }
                    TapHandler {
                        onTapped: win.apply(cell.modelData)
                    }
                }
            }

            // Sin imágenes: cómo agregar las propias
            ColumnLayout {
                visible: win.items.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 14
                Layout.bottomMargin: 14
                spacing: 8

                MIcon {
                    Layout.alignment: Qt.AlignHCenter
                    name: "add_photo_alternate"
                    color: Theme.textDim
                    font.pixelSize: 44
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: win.query !== "" ? "Ningún fondo se llama «" + input.text + "»" : "Todavía no hay fondos"
                    color: Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: win.query === ""
                    text: "Poné tus imágenes (jpg, png o webp) en ~/Imágenes/Fondos y aparecen acá"
                    color: Theme.textDim
                    font.pixelSize: 13
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "Flechas para moverte (se ve en el escritorio)  ·  Enter aplica  ·  Esc cierra  ·  Escribí para filtrar"
                color: Theme.textDim
                font.pixelSize: 11
            }
        }
    }
}
