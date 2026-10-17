import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Bandeja del sistema: los íconos de las apps que viven en ella (Discord, Steam...). Clic
// activa la app, clic derecho abre su menú (con el diseño de ombu), clic del medio la acción
// secundaria.
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

            readonly property string key: "tray-" + modelData.id + "@" + root.barWindow.screen.name
            readonly property bool isOpen: Ui.popup === key
            // Evita que el clic que cierra el menú lo vuelva a abrir
            property double dismissedAt: 0

            function toggleMenu(): void {
                if (!modelData.hasMenu)
                    return;
                if (Date.now() - dismissedAt > 300)
                    Ui.popup = isOpen ? "" : key;
            }

            width: 24
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: cellHover.hovered || cell.isOpen ? Theme.hover : "transparent"
            }

            Image {
                anchors.centerIn: parent
                width: 17
                height: 17
                // Algunas apps traen un ícono que no es el de su marca (ver Icons)
                source: Icons.override(cell.modelData.id) || cell.modelData.icon
                sourceSize: Qt.size(34, 34)
                smooth: true
            }

            HoverHandler {
                id: cellHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    if (cell.modelData.onlyMenu && cell.modelData.hasMenu)
                        cell.toggleMenu();
                    else
                        cell.modelData.activate();
                }
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: cell.toggleMenu()
            }

            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: cell.modelData.secondaryActivate()
            }

            TrayMenu {
                barWindow: root.barWindow
                anchorItem: cell
                trayItem: cell.modelData
                open: cell.isOpen

                onDismissed: {
                    cell.dismissedAt = Date.now();
                    if (cell.isOpen)
                        Ui.popup = "";
                }
            }
        }
    }
}
