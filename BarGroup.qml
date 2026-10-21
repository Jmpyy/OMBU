import QtQuick

// Grupo de botones de la derecha. Antes era una sola cápsula con todo adentro, con otro estilo que la
// izquierda; ahora cada grupo es una viñeta: borde de tinta y sombra dura con los temas de cómic.
Rectangle {
    default property alias content: groupRow.data

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: groupRow.implicitWidth + 8
    implicitHeight: 28
    radius: Theme.comic ? 6 : 14
    color: Theme.surface
    border.width: Theme.comic ? 2 : 0
    border.color: Theme.comic ? Theme.ink : "transparent"

    // Sombra dura: hija con z negativo para no ocupar lugar en la fila
    Rectangle {
        z: -1
        visible: Theme.comic
        x: 3
        y: 3
        width: parent.width
        height: parent.height
        radius: parent.radius
        color: Theme.shadow
    }

    Row {
        id: groupRow

        anchors.centerIn: parent
        spacing: 2
    }
}
