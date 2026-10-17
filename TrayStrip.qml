import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Bandeja del sistema: los íconos de las apps que viven en ella (Discord, Steam...). Clic
// activa la app, clic derecho abre su menú, clic del medio la acción secundaria.
Row {
    id: root

    required property var barWindow
    readonly property int count: SystemTray.items.values.length

    visible: count > 0
    spacing: 2

    Repeater {
        model: SystemTray.items

        Item {
            id: cell

            required property SystemTrayItem modelData

            function openMenu(): void {
                const pos = cell.mapToItem(root.barWindow.contentItem, 0, cell.height);
                menuAnchor.anchor.rect = Qt.rect(pos.x, pos.y, cell.width, 1);
                menuAnchor.open();
            }

            width: 24
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: cellHover.hovered ? Theme.hover : "transparent"
            }

            Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: cell.modelData.icon
                sourceSize: Qt.size(32, 32)
                smooth: true
            }

            QsMenuAnchor {
                id: menuAnchor

                menu: cell.modelData.menu
                anchor.window: root.barWindow
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }

            HoverHandler {
                id: cellHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    if (cell.modelData.onlyMenu && cell.modelData.hasMenu)
                        cell.openMenu();
                    else
                        cell.modelData.activate();
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
        }
    }
}
