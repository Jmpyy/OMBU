import QtQuick

// Anillo de foco de teclado: se ve alrededor del control que tiene el foco (Tab o flechas en un menú).
// Se pone como hijo del control; toma su forma.
Rectangle {
    anchors.fill: parent
    anchors.margins: -2
    radius: (parent.radius ?? 0) + 2
    color: "transparent"
    border.width: 1.5
    border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.55)
    visible: parent.activeFocus
}
