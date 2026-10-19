import QtQuick
import QtQuick.Layouts

// Tarjeta del panel lateral: una viñeta con borde de tinta y sombra dura en los temas de cómic, una
// tarjeta simple en los demás. Lleva una franja del color `tint` y, si hay `title`, un sticker arriba.
// Lo que se ponga adentro se apila en una columna.
Item {
    id: root

    property string title: ""
    property color tint: Theme.accent
    default property alias content: body.data

    implicitHeight: card.height + 8

    // Sombra dura de viñeta (solo temas de cómic)
    Rectangle {
        visible: Theme.comic
        x: card.x + 3
        y: card.y + 3
        width: card.width
        height: card.height
        radius: card.radius
        color: Theme.shadow
    }

    Rectangle {
        id: card

        width: parent.width - 4
        height: col.implicitHeight + 20
        radius: Theme.comic ? 6 : 10
        color: Theme.surface
        border.width: Theme.comic ? 2 : 1
        border.color: Theme.comic ? Theme.ink : Theme.border

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.comic ? 2 : 1
            width: 4
            radius: 2
            color: root.tint
        }

        ColumnLayout {
            id: col

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 10
            anchors.topMargin: 9
            spacing: 8

            Sticker {
                visible: root.title !== ""
                text: root.title
                tint: root.tint
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                spacing: 6
            }
        }
    }
}
