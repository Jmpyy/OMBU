import QtQuick
import Quickshell
import Quickshell.Hyprland

// Los escritorios del monitor de esta barra (cada monitor tiene los suyos: ver workspaces.lua).
// El activo se ensancha y muestra su número y el ícono de la app que tiene; los que tienen
// ventanas muestran el ícono de su app; los vacíos son un punto.
Row {
    id: root

    // Nombre del monitor de esta barra (ej. "HDMI-A-1")
    required property string screenName

    // Escritorios que pertenecen a este monitor, en orden. Mostrar los de otro monitor haría que un
    // clic mande el foco y el puntero a una pantalla que quizá está apagada.
    readonly property var spaces: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === screenName).sort((a, b) => a.id - b.id)
    // Escritorio que se está viendo en este monitor
    readonly property int activeId: Hyprland.monitors.values.find(m => m.name === screenName)?.activeWorkspace?.id ?? -1

    spacing: 4

    function windowsOf(id: int): var {
        return Hyprland.toplevels.values.filter(t => t.workspace?.id === id);
    }

    function iconOf(toplevel: var): string {
        const appId = toplevel?.wayland?.appId ?? "";
        const entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
        return Icons.forApp(appId, entry ? entry.icon : "");
    }

    Repeater {
        model: root.spaces

        Rectangle {
            id: ws

            required property var modelData
            readonly property int wsId: modelData.id
            readonly property bool active: root.activeId === wsId
            readonly property var windows: root.windowsOf(wsId)
            readonly property bool occupied: windows.length > 0

            anchors.verticalCenter: parent.verticalCenter
            height: 22
            width: active ? content.implicitWidth + 18 : (occupied ? 26 : 16)
            radius: 11
            color: active ? Theme.accent : (area.containsMouse ? Theme.hover : "transparent")

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            // Escritorio vacío y sin foco: solo un punto
            Rectangle {
                anchors.centerIn: parent
                visible: !ws.active && !ws.occupied
                width: 6
                height: 6
                radius: 3
                color: Theme.textDim
                opacity: area.containsMouse ? 1 : 0.5
            }

            Row {
                id: content

                anchors.centerIn: parent
                spacing: 5
                visible: ws.active || ws.occupied

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ws.active
                    text: ws.wsId
                    color: "#14131a"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ws.occupied
                    width: 15
                    height: 15
                    source: ws.occupied ? root.iconOf(ws.windows[0]) : ""
                    sourceSize: Qt.size(30, 30)
                    smooth: true
                    opacity: ws.active ? 1 : 0.85
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                anchors.margins: -2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hyprland 0.56 con config Lua: el dispatch es código Lua
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + ws.wsId + "\" })")
            }
        }
    }
}
