import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Avisos emergentes: una pila de tarjetas arriba a la derecha, en el monitor con foco.
// Van en la capa "top": no tapan videos ni juegos a pantalla completa.
//
// Animaciones: la tarjeta entra deslizándose desde la derecha con un pequeño rebote y
// crece en escala; los demás avisos se corren suavemente para hacerle lugar. Al irse
// hace el recorrido inverso. También se puede descartar arrastrándola hacia la derecha.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    visible: Notifs.toasts.length > 0 && Hyprland.focusedMonitor?.name === modelData.name
    color: "transparent"
    // La ventana ocupa SIEMPRE toda la franja derecha y nunca cambia de tamaño: si su
    // tamaño siguiera a la animación, el compositor la reconfiguraría en cada cuadro y las
    // tarjetas se verían deformadas y temblando. Solo se anima lo que hay adentro, y los
    // clics se capturan únicamente sobre las tarjetas (ver mask).
    anchors {
        top: true
        right: true
        bottom: true
    }
    // El relleno lateral de 10 px da lugar al rebote de la animación sin recortarla
    margins {
        top: 52
        right: 6
        bottom: 16
    }
    implicitWidth: 380
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ombu-notifs"

    // Los clics solo se capturan sobre las tarjetas
    mask: Region {
        item: stack
    }

    Column {
        id: stack

        width: parent.width

        Repeater {
            model: ScriptModel {
                values: Notifs.toasts
            }

            Item {
                id: slot

                required property var modelData
                readonly property var entry: modelData

                property bool appeared: false
                readonly property bool show: appeared && entry.shown
                // Cuánto se arrastró la tarjeta hacia la derecha
                property real dragX: 0

                width: stack.width
                height: show ? card.implicitHeight + 10 : 0
                opacity: show ? 1 : 0
                clip: true

                Component.onCompleted: appeared = true

                Behavior on height {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: slot.show ? 160 : 200
                        easing.type: Easing.OutCubic
                    }
                }

                HardShadow {
                    target: card
                    offset: 4
                }

                NotifCard {
                    id: card

                    x: 10 + (slot.show ? slot.dragX : (slot.entry.swiped ? slot.width : 70))
                    width: slot.width - 20
                    entry: slot.entry
                    floating: true
                    scale: slot.show ? 1 : 0.95
                    transformOrigin: Item.Right

                    // Entra con rebote; sale acelerando. Mientras se arrastra, sigue al mouse.
                    Behavior on x {
                        enabled: !drag.active

                        NumberAnimation {
                            duration: slot.show ? 300 : 200
                            easing.type: slot.show ? Easing.OutBack : Easing.InCubic
                            easing.overshoot: 0.8
                        }
                    }

                    // Sin rebote: un rebote en la escala al salir se veía como un temblor
                    Behavior on scale {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Deslizar hacia la derecha para descartar
                    DragHandler {
                        id: drag

                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false
                        acceptedButtons: Qt.LeftButton

                        onTranslationChanged: slot.dragX = Math.max(0, translation.x)
                        onActiveChanged: {
                            if (active)
                                return;
                            if (slot.dragX > 110) {
                                slot.entry.swiped = true;
                                Notifs.dismiss(slot.entry);
                            } else {
                                slot.dragX = 0;
                            }
                        }
                    }
                }
            }
        }
    }
}
