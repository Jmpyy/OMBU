import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Indicador de volumen: una píldora chica abajo al centro, sin clics ni foco.
// Aparece en el monitor con foco.
PanelWindow {
    id: win

    required property var modelData

    readonly property bool onFocusedMonitor: Hyprland.focusedMonitor?.name === modelData.name

    property real p: Osd.shown ? 1 : 0

    Behavior on p {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    // Guarda el monitor en el que se mostró para completar la animación de salida
    property bool activeOnScreen: false

    Connections {
        target: Osd

        function onShownChanged() {
            if (Osd.shown && win.onFocusedMonitor)
                win.activeOnScreen = true;
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    screen: modelData
    visible: (p > 0.001 && activeOnScreen) || (Osd.shown && onFocusedMonitor)
    color: "transparent"
    anchors.bottom: true
    margins.bottom: 56
    implicitWidth: 300
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-osd"

    // Región vacía: los clics lo atraviesan
    mask: Region {}

    HardShadow {
        target: box
        offset: 4
    }

    Rectangle {
        id: box

        anchors.centerIn: parent
        width: 290
        height: 52
        radius: Theme.comic ? 8 : (height / 2)
        color: Theme.bg
        border.width: Theme.comic ? 2 : 1
        border.color: Theme.comic ? Theme.ink : Theme.border
        opacity: win.p
        scale: 0.92 + 0.08 * win.p

        Halftone {
            strength: 0.05
            anchors.margins: 4
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            MIcon {
                name: Osd.icon
                font.pixelSize: 22
                color: Osd.showMuted ? Theme.danger : (Theme.comic ? Theme.accent : Theme.text)
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 8

                Rectangle {
                    id: track

                    anchors.fill: parent
                    radius: Theme.comic ? 4 : 3
                    color: Theme.track
                    border.width: Theme.comic ? 1 : 0
                    border.color: Theme.comic ? Theme.ink : "transparent"

                    Rectangle {
                        width: track.width * Math.min(1, Osd.level)
                        height: parent.height
                        radius: parent.radius
                        color: Osd.showMuted ? Theme.danger : Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            Text {
                Layout.preferredWidth: Theme.comic ? 56 : 40
                horizontalAlignment: Text.AlignRight
                text: Osd.showMuted ? (Theme.comic ? "¡MUTE!" : "Mute") : Math.round(Osd.level * 100) + "%"
                color: Osd.showMuted ? Theme.danger : Theme.text
                font.family: Theme.comic ? Theme.displayFont : Theme.font
                font.pixelSize: Theme.comic ? 16 : 13
                font.weight: Theme.comic ? Font.Normal : Font.Medium
            }
        }
    }
}
