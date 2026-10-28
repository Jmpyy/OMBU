import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Lo que está «guardado»: las ventanas minimizadas (clic para traerlas) y, debajo, las apps que siguen
// corriendo sin ventana (Discord en la bandeja, Sung, Steam...). Las ventanas que estás usando no aparecen
// acá: antes las listaba todas y la persona solo quería ver lo que quedó en segundo plano.
DropPopup {
    id: root

    readonly property int rowHeight: 48
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

    bodyWidth: 380
    bodyHeight: column.implicitHeight + 24

    ColumnLayout {
        id: column

        x: 14
        y: 2
        width: root.bodyWidth - 28
        spacing: 10

        RowLayout {
            visible: root.windows.length > 0
            Layout.fillWidth: true

            Text {
                text: "MINIMIZADAS"
                color: Theme.comic ? Theme.accent : Theme.textDim
                font.pixelSize: Theme.comic ? 13 : 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                font.family: Theme.comic ? Theme.displayFont : ""
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.windows.length
                color: Theme.textDim
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
            }
        }

        Text {
            visible: Apps.tucked === 0
            Layout.fillWidth: true
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
                        radius: Theme.comic ? 6 : 12
                        color: rowHover.hovered ? (Theme.comic ? Qt.rgba(1, 1, 1, 0.08) : Theme.hover) : "transparent"
                        border.width: Theme.comic && rowHover.hovered ? 1.5 : 0
                        border.color: Theme.comic ? Theme.ink : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30

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
                                    color: row.minimized ? Theme.accent : Theme.textDim
                                    font.pixelSize: Theme.fontCaption
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
                                color: closeHover.hovered ? Theme.danger : Theme.surface

                                MIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    font.pixelSize: Theme.iconSm
                                    color: closeHover.hovered ? Theme.accentText : Theme.textDim
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
            spacing: 4

            // La línea separa de las minimizadas; sin minimizadas no hace falta
            Rectangle {
                visible: root.windows.length > 0
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
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Apps.trayItems.length + Apps.backgroundOnly.length
                    color: Theme.textDim
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                }
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
                    radius: 12
                    color: trayHover.hovered ? Theme.hover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30

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
                            color: trayMoreHover.hovered ? Theme.accent : Theme.surface

                            MIcon {
                                anchors.centerIn: parent
                                name: "more_horiz"
                                font.pixelSize: Theme.iconMd
                                color: trayMoreHover.hovered ? Theme.accentText : Theme.textDim
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
                    radius: 12
                    color: bgHover.hovered ? Theme.hover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30

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
                            color: bgRow.armed || bgCloseHover.hovered ? Theme.danger : Theme.surface

                            MIcon {
                                anchors.centerIn: parent
                                name: "close"
                                font.pixelSize: Theme.iconSm
                                color: bgRow.armed || bgCloseHover.hovered ? Theme.accentText : Theme.textDim
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
