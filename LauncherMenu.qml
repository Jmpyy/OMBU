import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Launcher estilo Spotlight: una barra de búsqueda. Vacía muestra tus apps de siempre (favoritas
// y las más usadas); al escribir aparecen los resultados. Aparece en el monitor con foco.
//   Enter abre o enfoca · Shift+Enter ventana nueva · flechas mueven · Ctrl+P fija o suelta · Esc cierra
PanelWindow {
    id: win

    required property var modelData

    readonly property int columns: 6
    readonly property int cell: 92
    readonly property int rowHeight: 50
    readonly property int maxRows: 6

    readonly property string query: input.text.trim().toLowerCase()
    readonly property bool searching: query !== ""

    readonly property var allApps: Array.from(DesktopEntries.applications.values).filter(e => !e.noDisplay)
    readonly property var tiles: Launch.tiles(allApps)

    // Puntaje de coincidencia de una app con lo escrito (0 = no coincide)
    function score(entry, q: string): int {
        const name = entry.name.toLowerCase();
        if (name.startsWith(q))
            return 100;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 80;
        if (name.includes(q))
            return 60;
        if ((entry.genericName ?? "").toLowerCase().includes(q))
            return 40;
        if (Array.from(entry.keywords ?? []).some(k => k.toLowerCase().includes(q)))
            return 35;
        if ((entry.comment ?? "").toLowerCase().includes(q))
            return 20;
        return 0;
    }

    // Resultados: primero las apps de siempre; las del sistema ocultas solo si escribís 3 letras o más
    readonly property var results: {
        const q = query;
        if (!q)
            return [];
        const out = [];
        for (const e of allApps) {
            const s = score(e, q);
            if (s <= 0)
                continue;
            const hidden = Launch.isHidden(e);
            if (hidden && q.length < 3)
                continue;
            // Lo que más abrís sube un poco; lo oculto va al final
            out.push({
                entry: e,
                rank: s + Math.min(Launch.usage[e.id] ?? 0, 20) * 0.5 + (Launch.isFavorite(e.id) ? 5 : 0) - (hidden ? 1000 : 0)
            });
        }
        return out.sort((a, b) => b.rank - a.rank || a.entry.name.localeCompare(b.entry.name)).map(x => x.entry);
    }

    readonly property var current: searching ? (results[list.currentIndex] ?? null) : (tiles[grid.currentIndex] ?? null)

    // Ícono de una app; "" si el tema no lo tiene (así no sale el cuadro magenta de error)
    function iconFor(entry): string {
        if (!entry)
            return "";
        const own = Icons.override(entry.id);
        if (own)
            return own;
        const icon = entry.icon ?? "";
        if (!icon)
            return "";
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true);
    }

    function launch(entry, forceNew: bool): void {
        Launch.open(entry, forceNew);
    }

    onQueryChanged: {
        list.currentIndex = 0;
        grid.currentIndex = 0;
    }
    onTilesChanged: grid.currentIndex = Math.min(grid.currentIndex, Math.max(0, tiles.length - 1))

    property real p: Ui.launcherOpen ? 1 : 0

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

        function onLauncherOpenChanged() {
            if (!Ui.launcherOpen)
                return;
            if (Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
            input.text = Ui.launcherPrefill;
            list.currentIndex = 0;
            grid.currentIndex = 0;
            Qt.callLater(() => input.forceActiveFocus());
        }

        // Precargar un texto con el launcher ya abierto
        function onLauncherPrefillChanged() {
            if (Ui.launcherOpen)
                input.text = Ui.launcherPrefill;
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    screen: modelData
    visible: (p > 0.001 && activeOnScreen) || (Ui.launcherOpen && Hyprland.focusedMonitor?.name === modelData.name)
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-launcher"
    WlrLayershell.keyboardFocus: Ui.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.launcherOpen = false
        }
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        width: win.columns * win.cell + 28
        height: column.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.p
        scale: 0.92 + 0.08 * win.p
        transformOrigin: Item.Top

        // Evita que un clic dentro de la tarjeta cierre el launcher
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: 14
            y: 12
            width: parent.width - 28
            spacing: 4

            // Barra de búsqueda
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 12

                MIcon {
                    name: "search"
                    color: Theme.textDim
                    font.pixelSize: 24
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: "#14131a"
                    font.pixelSize: 19
                    clip: true
                    focus: true


                    Keys.onEscapePressed: Ui.launcherOpen = false
                    // Enter abre o enfoca la app; Shift+Enter abre una ventana nueva
                    Keys.onReturnPressed: event => {
                        win.launch(win.current, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: event => {
                        win.launch(win.current, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    }
                    Keys.onUpPressed: {
                        if (win.searching)
                            list.currentIndex = Math.max(0, list.currentIndex - 1);
                        else
                            grid.moveCurrentIndexUp();
                    }
                    Keys.onDownPressed: {
                        if (win.searching)
                            list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
                        else
                            grid.moveCurrentIndexDown();
                    }
                    // Con la búsqueda vacía las flechas laterales se mueven por los íconos
                    Keys.onLeftPressed: event => {
                        if (win.searching)
                            event.accepted = false;
                        else
                            grid.moveCurrentIndexLeft();
                    }
                    Keys.onRightPressed: event => {
                        if (win.searching)
                            event.accepted = false;
                        else
                            grid.moveCurrentIndexRight();
                    }
                    Keys.onPressed: event => {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P && win.current) {
                            Launch.toggleFavorite(win.current.id);
                            event.accepted = true;
                        }
                    }

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar aplicaciones…"
                        color: Theme.textDim
                        font.pixelSize: 19
                    }
                }
            }

            Rectangle {
                visible: !win.searching ? win.tiles.length > 0 : win.results.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // Vista inicial: tus apps de siempre
            GridView {
                id: grid

                visible: !win.searching && win.tiles.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.ceil(win.tiles.length / win.columns) * win.cell
                Layout.topMargin: 4
                cellWidth: width / win.columns
                cellHeight: win.cell
                model: win.tiles
                interactive: false
                currentIndex: 0
                highlightMoveDuration: 0

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    readonly property string icon: win.iconFor(modelData)

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 16
                        color: tile.current ? Theme.surface : (tileHover.hovered ? Theme.hover : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: 90
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 7

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 46
                            height: 46

                            Image {
                                id: tileImage

                                anchors.fill: parent
                                visible: tile.icon !== "" && status !== Image.Error
                                source: tile.icon
                                sourceSize: Qt.size(92, 92)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MIcon {
                                anchors.centerIn: parent
                                visible: !tileImage.visible
                                name: "apps"
                                color: Theme.textDim
                                font.pixelSize: 34
                            }
                        }

                        Text {
                            width: grid.cellWidth - 14
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    // Marca de favorita
                    MIcon {
                        visible: Launch.isFavorite(tile.modelData.id) && (tile.current || tileHover.hovered)
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        name: "push_pin"
                        color: Theme.accent
                        font.pixelSize: 13
                    }

                    HoverHandler {
                        id: tileHover
                    }
                    TapHandler {
                        onTapped: win.launch(tile.modelData, false)
                    }
                }
            }

            Text {
                visible: !win.searching && win.tiles.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 10
                horizontalAlignment: Text.AlignHCenter
                text: "Escribí para buscar una aplicación"
                color: Theme.textDim
                font.pixelSize: 14
            }

            // Al escribir: resultados
            Text {
                visible: win.searching && win.results.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 14
                horizontalAlignment: Text.AlignHCenter
                text: "Sin resultados para “" + input.text + "”"
                color: Theme.textDim
                font.pixelSize: 14
            }

            ListView {
                id: list

                visible: win.searching && win.results.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(count, win.maxRows) * win.rowHeight
                model: win.results
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: item

                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    readonly property string icon: win.iconFor(modelData)

                    width: ListView.view.width
                    height: win.rowHeight
                    radius: 14
                    color: current ? Theme.surface : (itemHover.hovered ? Theme.hover : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: 90
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 14

                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32

                            Image {
                                id: rowImage

                                anchors.fill: parent
                                visible: item.icon !== "" && status !== Image.Error
                                source: item.icon
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MIcon {
                                anchors.centerIn: parent
                                visible: !rowImage.visible
                                name: "apps"
                                color: Theme.textDim
                                font.pixelSize: 24
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: item.modelData.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }

                        MIcon {
                            visible: Launch.isFavorite(item.modelData.id)
                            name: "push_pin"
                            color: Theme.accent
                            font.pixelSize: 15
                        }

                        MIcon {
                            visible: item.current
                            name: "keyboard_return"
                            color: Theme.textDim
                            font.pixelSize: 18
                        }
                    }

                    HoverHandler {
                        id: itemHover
                    }
                    TapHandler {
                        onTapped: win.launch(item.modelData, false)
                    }
                }
            }

            // Ayuda de teclas
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 2
                Layout.bottomMargin: 4
                text: win.searching ? "Enter abre o enfoca  ·  Shift+Enter ventana nueva  ·  Ctrl+P fija o suelta" : "Enter abre o enfoca  ·  Shift+Enter ventana nueva  ·  Ctrl+P fija o suelta"
                color: Theme.textDim
                font.pixelSize: 11
            }
        }
    }
}
