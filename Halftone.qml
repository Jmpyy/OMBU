import QtQuick

// Puntos de impresión de cómic: una trama sutil que solo se ve en los temas con `shadow`. Se coloca
// dentro de una tarjeta, con márgenes que la mantienen lejos de las esquinas redondeadas.
Image {
    property real strength: 0.07

    visible: Theme.comic
    anchors.fill: parent
    anchors.margins: 10
    source: "assets/halftone.png"
    fillMode: Image.Tile
    opacity: strength
    smooth: false
}
