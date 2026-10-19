import QtQuick
import QtQuick.Layouts

// Una medida del panel de sistema: nombre, valor y una barra de uso. La barra se pone ámbar y roja
// cuando el uso es alto.
ColumnLayout {
    id: root

    property string label
    property string value
    property string detail
    // 0 a 1; negativo = sin barra
    property real fraction: -1

    spacing: 4

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: root.label
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            visible: root.detail !== ""
            text: root.detail
            color: Theme.textDim
            font.pixelSize: 12
        }

        Text {
            text: root.value
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        visible: root.fraction >= 0
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        radius: 3
        color: Theme.track

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.fraction))
            height: parent.height
            radius: 3
            color: root.fraction > 0.9 ? Theme.danger : (root.fraction > 0.75 ? Theme.warn : Theme.accent)

            Behavior on width {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
