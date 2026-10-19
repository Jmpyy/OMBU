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
    // El escritorio "gaming" (donde Hyprland manda los juegos y el Minecraft Launcher) solo aparece si
    // tiene ventanas o si estás en él; así no queda escondido.
    readonly property var spaces: Hyprland.workspaces.values.filter(w => w.monitor?.name === screenName && (w.id > 0 || (w.name === "gaming" && (w.id === activeId || windowsOf(w.id).length > 0)))).sort((a, b) => (a.id > 0 ? a.id : 1000) - (b.id > 0 ? b.id : 1000))
    // Escritorio que se está viendo en este monitor
    readonly property int activeId: Hyprland.monitors.values.find(m => m.name === screenName)?.activeWorkspace?.id ?? -1

    spacing: 4

    function windowsOf(id: int): var {
        return Hyprland.toplevels.values.filter(t => t.workspace?.id === id);
    }

    function iconOf(toplevel: var): string {
        const appId = toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || "";
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
            width: active ? content.implicitWidth + (Theme.comic ? 16 : 18) : (occupied ? (Theme.comic ? 28 : 26) : 16)
            radius: Theme.comic ? 5 : 11
            color: active ? Theme.accent : (area.containsMouse ? Theme.hover : (Theme.comic && occupied ? Qt.rgba(1, 1, 1, 0.05) : "transparent"))
            border.width: Theme.comic ? (active ? 1.5 : (occupied ? 1 : 0)) : 0
            border.color: Theme.comic ? (active ? "#0a0708" : (area.containsMouse ? Theme.accent : (occupied ? Qt.rgba(0, 0, 0, 0.5) : "transparent"))) : "transparent"

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

            // Escritorio vacío y sin foco: rombo/punto de semitono de imprenta
            Rectangle {
                anchors.centerIn: parent
                visible: !ws.active && !ws.occupied
                width: Theme.comic ? 5 : 6
                height: Theme.comic ? 5 : 6
                radius: Theme.comic ? 1 : 3
                rotation: Theme.comic ? 45 : 0
                color: area.containsMouse ? Theme.accent : Theme.textDim
                opacity: area.containsMouse ? 1 : 0.5

                Behavior on rotation {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            Row {
                id: content

                anchors.centerIn: parent
                spacing: Theme.comic ? 6 : 5
                visible: ws.active || ws.occupied

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ws.active && ws.wsId < 0
                    name: "sports_esports"
                    color: Theme.accentText
                    font.pixelSize: 15
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ws.active && ws.wsId > 0
                    text: ws.wsId
                    color: Theme.accentText
                    font.family: (Theme.comic && Theme.displayFont) ? Theme.displayFont : Qt.application.font.family
                    font.pixelSize: Theme.comic ? 15 : 12
                    font.letterSpacing: Theme.comic ? 1 : 0
                    font.weight: Font.Bold
                }

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ws.occupied && appIcon.source == ""
                    name: "apps"
                    color: ws.active ? Theme.accentText : Theme.textDim
                    font.pixelSize: 15
                }

                Image {
                    id: appIcon

                    anchors.verticalCenter: parent.verticalCenter
                    visible: ws.occupied && source != ""
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
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + (ws.wsId > 0 ? ws.wsId : "name:" + ws.modelData.name) + "\" })")
            }
        }
    }
}
