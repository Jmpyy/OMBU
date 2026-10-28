import QtQuick
import QtQuick.Layouts

// Línea fina entre grupos de un menú (macOS agrupa con líneas, no con cajas)
Item {
    Layout.fillWidth: true
    implicitHeight: 9

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 6
        width: parent.width - 12
        height: 1
        color: Theme.border
    }
}
