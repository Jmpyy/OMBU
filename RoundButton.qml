import QtQuick

// Botón redondo con ícono: lleno (violeta) para la acción principal, con fondo para las demás.
Rectangle {
    id: root

    property string icon
    property bool primary: false
    property bool enabled: true
    property int size: primary ? 56 : 42

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    opacity: enabled ? 1 : 0.4
    color: primary ? (area.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent) : (area.containsMouse && enabled ? Theme.hover : Theme.surface)

    Behavior on color {
        ColorAnimation {
            duration: 90
        }
    }

    MIcon {
        anchors.centerIn: parent
        name: root.icon
        font.pixelSize: root.primary ? 30 : 22
        color: root.primary ? "#14131a" : Theme.text
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled)
            root.clicked()
    }
}
