import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// Lista de ventanas abiertas (clic para ir a ellas, ✕ para cerrarlas)
// y, debajo, los íconos de la bandeja si hay alguno.
DropPopup {
    id: root

    readonly property int rowHeight: 48
    readonly property int maxRows: 7
    readonly property var windows: {
        const list = Array.from(Hyprland.toplevels.values);
        // Los workspaces especiales (minimizadas, scratchpad) tienen id negativo: van al final
        const rank = t => {
            const id = t.workspace?.id ?? 0;
            return id < 0 ? 1000 - id : id;
        };
        list.sort((a, b) => rank(a) - rank(b));
        return list;
    }
    readonly property int trayCount: SystemTray.items.values.length

    function entryFor(appId: string): var {
        return appId ? DesktopEntries.heuristicLookup(appId) : null;
    }

    function isMinimized(t): bool {
        return t.workspace?.name === "special:minimized";
    }

    function placeLabel(t): string {
        const ws = t.workspace;
        if (!ws)
            return "?";
        if (ws.name === "special:minimized")
            return "Minimizada";
        return ws.id < 0 ? "Scratchpad" : "Workspace " + ws.id;
    }

    // Ir a una ventana; si estaba minimizada, además la trae al workspace actual
    function focusWindow(t): void {
        const address = "address:0x" + t.address;
        if (isMinimized(t)) {
            let here = Hyprland.focusedWorkspace?.id ?? 1;
            if (here < 1)
                here = 1;
            Hyprland.dispatch("function() hl.dispatch(hl.dsp.focus({ window = \"" + address + "\" })); hl.dispatch(hl.dsp.window.move({ workspace = \"" + here + "\" })) end");
        } else {
            Hyprland.dispatch("hl.dsp.focus({ window = \"" + address + "\" })");
        }
        dismissed();
    }

    // Hyprland no minimiza: la ventana se manda sin enfocarla a un workspace especial oculto
    function minimizeWindow(t): void {
        Hyprland.dispatch("hl.dsp.window.move({ workspace = \"special:minimized\", follow = false, window = \"address:0x" + t.address + "\" })");
        Apps.refreshSoon();
    }

    // PID de la app en segundo plano esperando confirmación para cerrarse (-1 = ninguna)
    property int armedPid: -1

    onOpenChanged: {
        armedPid = -1;
        if (open)
            Apps.refresh();
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armedPid = -1
    }

    bodyWidth: 380
    bodyHeight: column.implicitHeight + 24

    ColumnLayout {
        id: column

        x: 14
        y: 2
        width: root.bodyWidth - 28
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "APPS ABIERTAS"
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.windows.length
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Text {
            visible: root.windows.length === 0
            Layout.fillWidth: true
            text: "No hay ventanas abiertas."
            color: Theme.textDim
            font.pixelSize: 12
        }

        Flickable {
            visible: root.windows.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(windowList.implicitHeight, root.maxRows * root.rowHeight)
            contentHeight: windowList.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: windowList

                width: parent.width

                Repeater {
                    model: ScriptModel {
                        values: root.windows
                    }

                    Rectangle {
                        id: row

                        required property var modelData
                        readonly property string appId: modelData.wayland?.appId ?? ""
                        readonly property var entry: root.entryFor(appId)
                        readonly property bool minimized: root.isMinimized(modelData)
                        readonly property bool regular: (modelData.workspace?.id ?? 0) > 0

                        width: windowList.width
                        height: root.rowHeight
                        radius: 12
                        color: rowHover.hovered ? Theme.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 12

                            Image {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                source: Quickshell.iconPath(row.entry ? row.entry.icon : row.appId.toLowerCase(), "application-x-executable")
                                sourceSize: Qt.size(60, 60)
                                smooth: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.title
                                    elide: Text.ElideRight
                                    color: row.minimized ? Theme.textDim : Theme.text
                                    font.pixelSize: Theme.fontSize
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (row.entry ? row.entry.name : row.appId) + "  ·  " + root.placeLabel(row.modelData)
                                    elide: Text.ElideRight
                                    color: row.minimized ? Theme.accent : Theme.textDim
                                    font.pixelSize: 11
                                }
                            }

                            // Minimizar (solo ventanas de un workspace normal)
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                visible: rowHover.hovered && row.regular
                                color: minHover.hovered ? Theme.hover : Theme.surface

                                MIcon {
                                    anchors.centerIn: parent
                                    name: "minimize"
                                    font.pixelSize: 16
                                    color: minHover.hovered ? Theme.text : Theme.textDim
                                }

                                HoverHandler {
                                    id: minHover
                                }
                                TapHandler {
                                    onTapped: root.minimizeWindow(row.modelData)
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                visible: rowHover.hovered
                                color: closeHover.hovered ? Theme.danger : Theme.surface

                                MIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    font.pixelSize: 16
                                    color: closeHover.hovered ? "#14131a" : Theme.textDim
                                }

                                HoverHandler {
                                    id: closeHover
                                }
                                TapHandler {
                                    onTapped: row.modelData.wayland?.close()
                                }
                            }
                        }

                        HoverHandler {
                            id: rowHover
                        }
                        TapHandler {
                            onTapped: {
                                if (!closeHover.hovered && !minHover.hovered)
                                    root.focusWindow(row.modelData);
                            }
                        }
                    }
                }
            }
        }

        // Apps que siguen corriendo sin ventana (ej. Vesktop cerrado a la bandeja)
        ColumnLayout {
            visible: Apps.background.length > 0
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.bottomMargin: 6
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "EN SEGUNDO PLANO"
                    color: Theme.textDim
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Apps.background.length
                    color: Theme.textDim
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Repeater {
                model: ScriptModel {
                    // Los datos vienen de un script (objetos nuevos en cada lectura): se identifican por id
                    objectProp: "id"
                    values: Apps.background
                }

                Rectangle {
                    id: bgRow

                    required property var modelData
                    readonly property bool armed: root.armedPid === modelData.main

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowHeight
                    radius: 12
                    color: bgHover.hovered ? Theme.hover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12

                        Image {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            source: {
                                const icon = bgRow.modelData.icon || bgRow.modelData.id;
                                return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "application-x-executable");
                            }
                            sourceSize: Qt.size(60, 60)
                            smooth: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: bgRow.modelData.name
                                elide: Text.ElideRight
                                color: Theme.text
                                font.pixelSize: Theme.fontSize
                            }

                            Text {
                                Layout.fillWidth: true
                                text: bgRow.armed ? "Tocá la ✕ de nuevo para cerrarla" : "Sin ventana  ·  PID " + bgRow.modelData.main
                                elide: Text.ElideRight
                                color: bgRow.armed ? Theme.danger : Theme.textDim
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            visible: bgHover.hovered || bgRow.armed
                            color: bgRow.armed || bgCloseHover.hovered ? Theme.danger : Theme.surface

                            MIcon {
                                anchors.centerIn: parent
                                name: "close"
                                font.pixelSize: 16
                                color: bgRow.armed || bgCloseHover.hovered ? "#14131a" : Theme.textDim
                            }

                            HoverHandler {
                                id: bgCloseHover
                            }
                            TapHandler {
                                onTapped: {
                                    if (bgRow.armed) {
                                        root.armedPid = -1;
                                        Apps.close(bgRow.modelData);
                                    } else {
                                        root.armedPid = bgRow.modelData.main;
                                        disarm.restart();
                                    }
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: bgHover
                    }
                    TapHandler {
                        onTapped: {
                            if (!bgCloseHover.hovered) {
                                Apps.open(bgRow.modelData);
                                root.dismissed();
                            }
                        }
                    }
                }
            }
        }

        // Bandeja del sistema: solo aparece si hay íconos
        ColumnLayout {
            visible: root.trayCount > 0
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            Text {
                text: "BANDEJA"
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Flow {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: SystemTray.items

                    Item {
                        id: cell

                        required property SystemTrayItem modelData

                        width: 38
                        height: 38

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                            color: cellHover.hovered ? Theme.hover : "transparent"
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: cell.modelData.icon
                            sourceSize: Qt.size(44, 44)
                            smooth: true
                        }

                        QsMenuAnchor {
                            id: menuAnchor

                            menu: cell.modelData.menu
                            anchor.window: root
                            anchor.edges: Edges.Bottom
                            anchor.gravity: Edges.Bottom
                        }

                        HoverHandler {
                            id: cellHover
                        }
                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                if (cell.modelData.onlyMenu && cell.modelData.hasMenu) {
                                    cell.openMenu();
                                } else {
                                    cell.modelData.activate();
                                    root.dismissed();
                                }
                            }
                        }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: if (cell.modelData.hasMenu)
                                cell.openMenu()
                        }
                        TapHandler {
                            acceptedButtons: Qt.MiddleButton
                            onTapped: cell.modelData.secondaryActivate()
                        }

                        function openMenu(): void {
                            const pos = cell.mapToItem(root.contentItem, 0, cell.height);
                            menuAnchor.anchor.rect = Qt.rect(pos.x, pos.y, cell.width, 1);
                            menuAnchor.open();
                        }
                    }
                }
            }
        }
    }
}
