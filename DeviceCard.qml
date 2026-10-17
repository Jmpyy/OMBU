import QtQuick
import QtQuick.Layouts

// Una unidad: ícono, nombre, qué sistema de archivos y dónde está montada, y una barra con
// cuánto espacio se usó. Clic abre la unidad; el botón de la derecha monta o expulsa.
Rectangle {
    id: root

    required property var volume

    readonly property bool busy: Disks.busyPath === volume.path
    readonly property real total: volume.used >= 0 && volume.avail >= 0 ? volume.used + volume.avail : volume.size
    readonly property real fraction: volume.used >= 0 && total > 0 ? Math.min(1, volume.used / total) : 0
    readonly property color barColor: fraction > 0.9 ? Theme.danger : (fraction > 0.75 ? Theme.warn : Theme.accent)

    implicitHeight: content.implicitHeight + 24
    radius: 16
    color: cardHover.hovered ? Qt.lighter(Theme.surface, 1.18) : Theme.surface

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    HoverHandler {
        id: cardHover
    }

    TapHandler {
        onTapped: Disks.open(root.volume)
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Ícono de la unidad
        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            Layout.alignment: Qt.AlignTop
            radius: 13
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)

            MIcon {
                anchors.centerIn: parent
                name: root.volume.removable ? "usb" : "hard_drive"
                color: Theme.accent
                font.pixelSize: 24
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.volume.name
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.volume.fs + " · " + (root.volume.mounted ? root.volume.mount : "sin montar")
                color: Theme.textDim
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }

            // Espacio usado
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.track
                visible: root.volume.mounted && root.volume.used >= 0

                Rectangle {
                    width: Math.max(parent.height, parent.width * root.fraction)
                    height: parent.height
                    radius: 3
                    color: root.barColor

                    Behavior on width {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.volume.mounted && root.volume.avail >= 0 ? Disks.format(root.volume.avail) + " libres de " + Disks.format(root.total) : Disks.format(root.volume.size)
                color: Theme.textDim
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // Montar (unidad sin montar) o expulsar (unidad extraíble o montada a mano)
        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignTop
            visible: root.volume.removable || !root.volume.mounted
            radius: 17
            color: actionHover.hovered ? Theme.hover : "transparent"

            MIcon {
                anchors.centerIn: parent
                name: root.busy ? "hourglass_top" : (root.volume.mounted ? "eject" : "play_arrow")
                color: Theme.textDim
                font.pixelSize: 20
            }

            HoverHandler {
                id: actionHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.volume.mounted ? Disks.eject(root.volume) : Disks.open(root.volume)
            }
        }
    }
}
