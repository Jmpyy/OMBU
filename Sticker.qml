import QtQuick

// Etiqueta de color para títulos y categorías: en los temas de cómic es un sticker inclinado con borde
// de tinta y letra de historieta; en los demás, una píldora simple. El texto elige tinta o crema según
// el color de fondo.
Rectangle {
    id: root

    property string text
    property color tint: Theme.accent
    // true = es de un «momento» (los stickers del escritorio vacío): con cualquier tema de cómic
    property bool art: false
    readonly property bool comic: art ? Theme.comicArt : Theme.comic
    readonly property color fg: !comic ? tint : ((0.299 * tint.r + 0.587 * tint.g + 0.114 * tint.b) > 0.5 ? Theme.ink : Theme.accentText)

    // Sin cómic es solo un rótulo: mayúsculas chicas del color de la tarjeta, sin pastilla
    implicitWidth: label.implicitWidth + (comic ? 12 : 0)
    implicitHeight: label.implicitHeight + (comic ? 4 : 0)
    radius: comic ? 3 : 0
    color: comic ? tint : "transparent"
    border.width: comic ? 1.5 : 0
    border.color: Theme.ink
    rotation: comic ? -2 : 0

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text.toUpperCase()
        color: root.fg
        font.family: root.comic && Theme.artFont ? Theme.artFont : Qt.application.font.family
        font.pixelSize: root.comic ? 13 : 10
        font.letterSpacing: root.comic ? 1 : 1
        font.weight: root.comic ? Font.Normal : Font.Bold
    }
}
