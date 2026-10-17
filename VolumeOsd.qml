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

    Rectangle {
        anchors.centerIn: parent
        width: 280
        height: 52
        radius: height / 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.p
        scale: 0.92 + 0.08 * win.p

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 20
            spacing: 14

            MIcon {
                name: Osd.icon
                font.pixelSize: 22
                color: Osd.muted ? Theme.danger : Theme.text
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 6

                Rectangle {
                    id: track

                    anchors.fill: parent
                    radius: 3
                    color: Theme.track

                    Rectangle {
                        width: track.width * Math.min(1, Osd.volume)
                        height: parent.height
                        radius: parent.radius
                        color: Osd.muted ? Theme.textDim : Theme.accent

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
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Osd.muted ? "Mute" : Math.round(Osd.volume * 100) + "%"
                color: Osd.muted ? Theme.textDim : Theme.text
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }
    }
}
