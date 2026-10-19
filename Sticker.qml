import QtQuick

// Etiqueta de color para títulos y categorías: en los temas de cómic es un sticker inclinado con borde
// de tinta y letra de historieta; en los demás, una píldora simple. El texto elige tinta o crema según
// el color de fondo.
Rectangle {
    id: root

    property string text
    property color tint: Theme.accent
    readonly property color fg: (0.299 * tint.r + 0.587 * tint.g + 0.114 * tint.b) > 0.5 ? Theme.ink : Theme.accentText

    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 4
    radius: Theme.comic ? 3 : height / 2
    color: tint
    border.width: Theme.comic ? 1.5 : 0
    border.color: Theme.ink
    rotation: Theme.comic ? -2 : 0

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text.toUpperCase()
        color: root.fg
        font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
        font.pixelSize: Theme.comic ? 13 : 10
        font.letterSpacing: Theme.comic ? 1 : 0.6
        font.weight: Theme.comic ? Font.Normal : Font.Bold
    }
}
