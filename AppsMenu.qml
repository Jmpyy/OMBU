import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Lo que está «guardado»: las ventanas minimizadas (clic para traerlas) y, debajo, las apps que siguen
// corriendo sin ventana (Discord en la bandeja, Sung, Steam...). Las ventanas que estás usando no aparecen
// acá: antes las listaba todas y la persona solo quería ver lo que quedó en segundo plano.
DropPopup {
    id: root

    readonly property int rowHeight: 40
    readonly property int maxRows: 7
    readonly property var windows: {
        const list = Array.from(Apps.minimized);
        // Los workspaces especiales (minimizadas, scratchpad) tienen id negativo: van al final
        const rank = t => {
            const id = t.workspace?.id ?? 0;
            return id < 0 ? 1000 - id : id;
        };
        list.sort((a, b) => rank(a) - rank(b));
        return list;
    }

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
        Apps.focusWindow(t);
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

    bodyWidth: 340
    bodyHeight: column.implicitHeight + 16

    ColumnLayout {
        id: column

        x: 8
        y: 4
        width: root.bodyWidth - 16
        spacing: 2

        MenuSection {
            visible: root.windows.length > 0
            text: "Minimizadas"
            detail: String(root.windows.length)
        }

        Text {
            visible: Apps.tucked === 0
            Layout.fillWidth: true
            Layout.margins: 8
            text: "No hay apps minimizadas ni en segundo plano."
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall
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
                        radius: Theme.controlRadius - 3
                        color: rowHover.hovered || activeFocus ? Theme.surface : "transparent"

                        activeFocusOnTab: true
                        Keys.onReturnPressed: root.focusWindow(row.modelData)
                        Keys.onEnterPressed: root.focusWindow(row.modelData)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24

                                Image {
                                    id: rowIcon

                                    anchors.fill: parent
                                    visible: source != ""
                                    source: Icons.forApp(row.appId, row.entry ? row.entry.icon : "")
                                    sourceSize: Qt.size(60, 60)
                                    smooth: true
                                }

                                MIcon {
                                    anchors.centerIn: parent
                                    visible: rowIcon.source == ""
                                    name: "apps"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.iconLg
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.title
                                    elide: Text.ElideRight
                                    color: row.minimized ? Theme.textDim : Theme.text
                                    font.pixelSize: Theme.fontBody
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (row.entry ? row.entry.name : row.appId) + "  ·  " + root.placeLabel(row.modelData)
                                    elide: Text.ElideRight
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontCaption
                                }
                            }

                            // Minimizar (solo ventanas de un workspace normal)
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                visible: rowHover.hovered && row.regular
                                color: minHover.hovered ? Theme.hover : "transparent"

                                MIcon {
                                    anchors.centerIn: parent
                                    name: "minimize"
                                    font.pixelSize: Theme.iconSm
                                    color: minHover.hovered ? Theme.text : Theme.textDim
                                }

                                HoverHandler {
                                    id: minHover
                                }
                                TapHandler {
                                    // Se queda con el clic: si no, también lo recibe la fila que lo contiene
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: root.minimizeWindow(row.modelData)
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                visible: rowHover.hovered
                                color: closeHover.hovered ? Theme.hover : "transparent"

                                MIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    font.pixelSize: Theme.iconSm
                                    color: closeHover.hovered ? Theme.danger : Theme.textDim
                                }

                                HoverHandler {
                                    id: closeHover
                                }
                                TapHandler {
                                    // Se queda con el clic: si no, también lo recibe la fila que lo contiene
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
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

        // En segundo plano: las apps de la bandeja (con su menú de opciones) y las que siguen corriendo sin
        // ventana ni ícono en la bandeja
        ColumnLayout {
            visible: Apps.trayItems.length + Apps.backgroundOnly.length > 0
            Layout.fillWidth: true
            spacing: 2

            // La línea separa de las minimizadas; sin minimizadas no hace falta
            MenuSeparator {
                visible: root.windows.length > 0
            }

            MenuSection {
                text: "En segundo plano"
                detail: String(Apps.trayItems.length + Apps.backgroundOnly.length)
            }

            // Apps de la bandeja: clic la abre, ⋯ muestra su menú de opciones (el del clic derecho de siempre),
            // que cuelga del botón de la barra; clic del medio, su acción secundaria
            Repeater {
                model: Apps.trayItems

                Rectangle {
                    id: trayRow

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowHeight
                    radius: Theme.controlRadius - 3
                    color: trayHover.hovered || activeFocus ? Theme.surface : "transparent"

                    activeFocusOnTab: true
                    Keys.onReturnPressed: {
                        trayRow.modelData.activate();
                        root.dismissed();
                    }
                    // → abre su menú de opciones, como el botón ⋯
                    Keys.onRightPressed: if (trayRow.modelData.hasMenu)
                        Ui.popup = "tray-" + trayRow.modelData.id + "@" + root.barWindow.screen.name

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            Image {
                                anchors.fill: parent
                                // Algunas apps traen un ícono que no es el de su marca (ver Icons)
                                source: Icons.override(trayRow.modelData.id) || trayRow.modelData.icon
                                sourceSize: Qt.size(60, 60)
                                smooth: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                // El nombre de la app instalada primero: el título de la bandeja a veces es el
                                // identificador en minúscula («sung»)
                                text: DesktopEntries.heuristicLookup(trayRow.modelData.id)?.name || trayRow.modelData.title || trayRow.modelData.tooltipTitle || trayRow.modelData.id
                                elide: Text.ElideRight
                                color: Theme.text
                                font.pixelSize: Theme.fontBody
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "En la bandeja"
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.pixelSize: Theme.fontCaption
                            }
                        }

                        // Menú de opciones de la app
                        Rectangle {
                            visible: trayRow.modelData.hasMenu
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: trayMoreHover.hovered ? Theme.hover : "transparent"

                            MIcon {
                                anchors.centerIn: parent
                                name: "more_horiz"
                                font.pixelSize: Theme.iconMd
                                color: trayMoreHover.hovered ? Theme.text : Theme.textDim
                            }

                            HoverHandler {
                                id: trayMoreHover

                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                // Se queda con el clic: si no, también lo recibe la fila que lo contiene
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Ui.popup = "tray-" + trayRow.modelData.id + "@" + root.barWindow.screen.name
                            }
                        }
                    }

                    HoverHandler {
                        id: trayHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            if (trayMoreHover.hovered)
                                return;
                            if (trayRow.modelData.onlyMenu && trayRow.modelData.hasMenu) {
                                Ui.popup = "tray-" + trayRow.modelData.id + "@" + root.barWindow.screen.name;
                                return;
                            }
                            trayRow.modelData.activate();
                            root.dismissed();
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            if (trayRow.modelData.hasMenu)
                                Ui.popup = "tray-" + trayRow.modelData.id + "@" + root.barWindow.screen.name;
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.MiddleButton
                        onTapped: trayRow.modelData.secondaryActivate()
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    // Los datos vienen de un script (objetos nuevos en cada lectura): se identifican por id
                    objectProp: "id"
                    values: Apps.backgroundOnly
                }

                Rectangle {
                    id: bgRow

                    required property var modelData
                    readonly property bool armed: root.armedPid === modelData.main

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowHeight
                    radius: Theme.controlRadius - 3
                    color: bgHover.hovered || activeFocus ? Theme.surface : "transparent"

                    activeFocusOnTab: true
                    Keys.onReturnPressed: {
                        Apps.open(bgRow.modelData);
                        root.dismissed();
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            Image {
                                id: bgIcon

                                anchors.fill: parent
                                visible: source != ""
                                source: Icons.forApp(bgRow.modelData.id, bgRow.modelData.icon)
                                sourceSize: Qt.size(60, 60)
                                smooth: true
                            }

                            MIcon {
                                anchors.centerIn: parent
                                visible: bgIcon.source == ""
                                name: "apps"
                                color: Theme.textDim
                                font.pixelSize: Theme.iconLg
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: bgRow.modelData.name
                                elide: Text.ElideRight
                                color: Theme.text
                                font.pixelSize: Theme.fontBody
                            }

                            Text {
                                Layout.fillWidth: true
                                text: bgRow.armed ? "Tocá la ✕ de nuevo para cerrarla" : "Sin ventana  ·  PID " + bgRow.modelData.main
                                elide: Text.ElideRight
                                color: bgRow.armed ? Theme.danger : Theme.textDim
                                font.pixelSize: Theme.fontCaption
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            visible: bgHover.hovered || bgRow.armed
                            color: bgRow.armed ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.2) : (bgCloseHover.hovered ? Theme.hover : "transparent")

                            MIcon {
                                anchors.centerIn: parent
                                name: "close"
                                font.pixelSize: Theme.iconSm
                                color: bgRow.armed || bgCloseHover.hovered ? Theme.danger : Theme.textDim
                            }

                            HoverHandler {
                                id: bgCloseHover
                            }
                            TapHandler {
                                // Se queda con el clic: si no, también lo recibe la fila que lo contiene
                                gesturePolicy: TapHandler.ReleaseWithinBounds
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
    }
}
