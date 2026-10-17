import QtQuick

// Una capa de color del salvapantallas: solo lleva los caracteres de un nivel de brillo.
// Todas las capas usan la misma fuente, el mismo origen y el mismo alto de línea, así que
// al superponerlas cada carácter cae exactamente en su celda.
Text {
    required property real cellWidth
    required property real cellHeight
    required property int gridCols
    required property int gridRows

    x: Math.round((parent.width - gridCols * cellWidth) / 2)
    y: Math.round((parent.height - gridRows * cellHeight) / 2)
    font.family: "monospace"
    font.pixelSize: Theme.saverFontSize
    lineHeightMode: Text.FixedHeight
    lineHeight: cellHeight
    textFormat: Text.PlainText
    renderType: Text.QtRendering
}
