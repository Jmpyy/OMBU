import QtQuick

// Ícono de Material Symbols (se escribe el nombre del glifo).
Text {
    property string name

    text: name
    color: Theme.text
    font.family: Theme.iconFont
    font.pixelSize: 18
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
