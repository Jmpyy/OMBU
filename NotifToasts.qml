import QtQuick
import QtQuick.Effects
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
                // Vibración de Sentido Arácnido al entrar (temblor de cómic)
                property real tingleAngle: 0

                width: stack.width
                height: show ? card.implicitHeight + 14 : 0
                opacity: show ? 1 : 0
                clip: !show

                Component.onCompleted: appeared = true

                onShowChanged: {
                    if (show && Theme.comic)
                        tingleAnim.restart();
                }

                SequentialAnimation {
                    id: tingleAnim

                    NumberAnimation {
                        target: slot
                        property: "tingleAngle"
                        to: -2.2
                        duration: 35
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: slot
                        property: "tingleAngle"
                        to: 2.2
                        duration: 35
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: slot
                        property: "tingleAngle"
                        to: -1.0
                        duration: 35
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: slot
                        property: "tingleAngle"
                        to: 1.0
                        duration: 35
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: slot
                        property: "tingleAngle"
                        to: 0
                        duration: 40
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Theme.ease
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: slot.show ? Theme.animFast : Theme.animNormal
                        easing.type: Theme.ease
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

                    // Sombra suave y difusa, como los avisos de macOS (en los temas de cómic va la dura)
                    layer.enabled: !Theme.comic
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#000000"
                        shadowOpacity: 0.5
                        shadowBlur: 0.9
                        shadowVerticalOffset: 6
                        autoPaddingEnabled: true
                    }
                    rotation: slot.tingleAngle
                    transformOrigin: Item.Right

                    // Entra con rebote; sale acelerando. Mientras se arrastra, sigue al mouse.
                    Behavior on x {
                        enabled: !drag.active

                        NumberAnimation {
                            duration: slot.show ? Theme.animSlow : Theme.animNormal
                            easing.type: slot.show ? Easing.OutBack : Easing.InCubic
                            easing.overshoot: 0.8
                        }
                    }

                    // Sin rebote: un rebote en la escala al salir se veía como un temblor
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animNormal
                            easing.type: Theme.ease
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
