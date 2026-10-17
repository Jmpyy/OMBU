import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Avisos emergentes: una pila de tarjetas arriba a la derecha, en el monitor con foco.
// Van en la capa "top": no tapan videos ni juegos a pantalla completa.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    visible: Notifs.toasts.length > 0 && Hyprland.focusedMonitor?.name === modelData.name
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins {
        top: 52
        right: 16
    }
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nuestro-notifs"

    // Los clics solo se capturan sobre las tarjetas
    mask: Region {
        item: stack
    }

    Column {
        id: stack

        width: parent.width

        Repeater {
            model: Notifs.toasts

            Item {
                id: slot

                required property var modelData

                // Entra y sale con la misma animación: se desvanece y se desliza un poco
                property bool appeared: false
                readonly property bool show: appeared && modelData.shown

                width: stack.width
                height: show ? card.implicitHeight + 10 : 0
                opacity: show ? 1 : 0
                clip: true

                Component.onCompleted: appeared = true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.popupDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.popupDuration
                        easing.type: Easing.OutCubic
                    }
                }

                NotifCard {
                    id: card

                    x: slot.show ? 0 : 36
                    width: parent.width
                    entry: slot.modelData
                    floating: true

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.popupDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
