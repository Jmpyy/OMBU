import QtQuick

// Un sticker del escritorio vacío (ver DesktopStickers): etiqueta chica arriba y el dato grande abajo,
// inclinado como pegado a mano sobre el collage. En los temas de cómic, borde de tinta, sombra dura y
// letra de historieta; en los demás, una tarjeta simple. El texto elige tinta o crema según el color.
Item {
    id: root

    property string label
    property string value
    property string icon
    property color tint: Theme.accent
    property real tilt: 0
    property int valueSize: 38
    property real maxValueWidth: 320

    readonly property color fg: (0.299 * tint.r + 0.587 * tint.g + 0.114 * tint.b) > 0.5 ? Theme.ink : Theme.text

    implicitWidth: card.width
    implicitHeight: card.height
    rotation: tilt

    // Sombra dura
    Rectangle {
        visible: Theme.comicArt
        x: 6
        y: 6
        width: card.width
        height: card.height
        radius: card.radius
        color: Theme.shadow
    }

    Rectangle {
        id: card

        width: Math.max(labelText.implicitWidth, valueRow.implicitWidth) + 30
        height: labelText.implicitHeight + valueRow.implicitHeight + 18
        radius: Theme.comicArt ? 6 : 16
        color: root.tint
        border.width: Theme.comicArt ? 2.5 : 1
        border.color: Theme.comicArt ? Theme.ink : Theme.border

        Halftone {
            art: true
            anchors.margins: 4
            strength: 0.08
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                id: labelText

                text: (root.label ?? "").toUpperCase()
                color: root.fg
                opacity: 0.8
                font.family: Theme.comicArt ? Theme.artFont : ""
                font.pixelSize: Theme.comicArt ? 15 : 11
                font.weight: Theme.comicArt ? Font.Normal : Font.DemiBold
                font.letterSpacing: Theme.comicArt ? 1 : 0.8
            }

            Row {
                id: valueRow

                spacing: 6

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.icon !== ""
                    name: root.icon
                    color: root.fg
                    font.pixelSize: root.valueSize * 0.8
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.maxValueWidth)
                    elide: Text.ElideRight
                    text: root.value
                    color: root.fg
                    font.family: Theme.comicArt ? Theme.artFont : ""
                    font.pixelSize: Theme.comicArt ? root.valueSize : root.valueSize * 0.75
                    font.weight: Theme.comicArt ? Font.Normal : Font.DemiBold
                    font.letterSpacing: Theme.comicArt ? 1 : 0
                }
            }
        }
    }
}
