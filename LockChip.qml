import QtQuick

// Etiqueta chica de la pantalla de bloqueo: ícono y texto.
Rectangle {
    id: root

    property string icon
    property string label
    // Resalta con el color de advertencia
    property bool warn: false

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 30
    radius: 15
    color: warn ? Qt.rgba(0.98, 0.75, 0.14, 0.16) : Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    border.color: warn ? Qt.rgba(0.98, 0.75, 0.14, 0.45) : Qt.rgba(1, 1, 1, 0.08)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 7

        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            color: root.warn ? Theme.warn : Qt.rgba(1, 1, 1, 0.75)
            font.pixelSize: 16
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.warn ? Theme.warn : Qt.rgba(1, 1, 1, 0.78)
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
