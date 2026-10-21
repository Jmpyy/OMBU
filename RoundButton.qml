import QtQuick

// Botón redondo con ícono: lleno (violeta) para la acción principal, con fondo para las demás.
Rectangle {
    id: root

    property string icon
    property bool primary: false
    property bool enabled: true
    // Encendido (aleatorio, repetir...): el ícono va en el color de acento
    property bool active: false
    property int size: primary ? 44 : 34

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size * 0.28
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
        font.pixelSize: root.primary ? 26 : 20
        color: root.primary ? Theme.accentText : (root.active ? Theme.accent : Theme.text)
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
