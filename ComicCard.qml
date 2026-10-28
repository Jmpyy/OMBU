import QtQuick
import QtQuick.Layouts

// Tarjeta del panel lateral, como los widgets del Centro de notificaciones de macOS: título chico, gris
// y en minúsculas (como MenuSection) y el contenido apilado en una columna. Con los temas de cómic es una
// viñeta con borde de tinta, sombra dura, franja del color `tint` y el título en un sticker.
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
        radius: Theme.comic ? 6 : Theme.controlRadius + 4
        color: Theme.surface
        border.width: Theme.comic ? 2 : 1
        border.color: Theme.comic ? Theme.ink : Theme.border

        // Franja del color de la tarjeta (solo en cómic; sobrio, el color va en el título)
        Rectangle {
            visible: Theme.comic
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
            anchors.leftMargin: Theme.comic ? 16 : 14
            anchors.rightMargin: 10
            anchors.topMargin: 9
            spacing: 8

            Sticker {
                visible: Theme.comic && root.title !== ""
                text: root.title
                tint: root.tint
            }

            Text {
                visible: !Theme.comic && root.title !== ""
                text: root.title
                color: Theme.textDim
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                spacing: 6
            }
        }
    }
}
