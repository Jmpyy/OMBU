import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Launcher estilo Spotlight: busca entre las apps instaladas y las abre.
// Aparece en el monitor con foco.
PanelWindow {
    id: win

    required property var modelData

    readonly property int rowHeight: 54
    readonly property int maxRows: 7

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
        if ((entry.keywords ?? []).some(k => k.toLowerCase().includes(q)))
            return 35;
        if ((entry.comment ?? "").toLowerCase().includes(q))
            return 20;
        return 0;
    }

    readonly property var results: {
        const q = input.text.trim().toLowerCase();
        const apps = Array.from(DesktopEntries.applications.values).filter(e => !e.noDisplay);
        if (!q)
            return apps.sort((a, b) => a.name.localeCompare(b.name));
        return apps.map(e => ({
                    entry: e,
                    score: score(e, q)
                })).filter(x => x.score > 0).sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name)).map(x => x.entry);
    }

    function launch(entry): void {
        if (!entry)
            return;
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e"].concat(entry.command));
        else
            entry.execute();
        Ui.launcherOpen = false;
    }

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
        y: parent.height * 0.18
        width: 640
        height: column.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.p
        scale: 0.90 + 0.10 * win.p
        transformOrigin: Item.Top

        // Evita que un clic dentro de la tarjeta cierre el launcher
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 6

            // Barra de búsqueda
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 10
                Layout.rightMargin: 10
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
                    font.pixelSize: 18
                    clip: true
                    focus: true

                    onTextChanged: list.currentIndex = 0
                    onAccepted: win.launch(win.results[list.currentIndex])

                    Keys.onEscapePressed: Ui.launcherOpen = false
                    Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                    Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar aplicaciones…"
                        color: Theme.textDim
                        font.pixelSize: 18
                    }
                }
            }

            Rectangle {
                visible: win.results.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            Text {
                visible: win.results.length === 0
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

                visible: win.results.length > 0
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

                    width: ListView.view.width
                    height: win.rowHeight
                    radius: 14
                    color: current ? Theme.surface : (itemHover.hovered ? Theme.hover : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 14
                        spacing: 14

                        Image {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            source: item.modelData.icon.startsWith("/") ? "file://" + item.modelData.icon : Quickshell.iconPath(item.modelData.icon, "application-x-executable")
                            sourceSize: Qt.size(72, 72)
                            smooth: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: item.modelData.name
                                elide: Text.ElideRight
                                color: Theme.text
                                font.pixelSize: 15
                                font.weight: Font.Medium
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: item.modelData.comment || item.modelData.genericName || ""
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.pixelSize: 12
                            }
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
                        onTapped: win.launch(item.modelData)
                    }
                }
            }
        }
    }
}
