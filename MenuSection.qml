import QtQuick
import QtQuick.Layouts

// Título de una sección de menú, como en macOS: chico, gris y en minúsculas normales (no en
// MAYÚSCULAS espaciadas). `detail` va a la derecha (un valor, un contador) y lo que se declare
// adentro también (ej. un botón «Borrar»).
RowLayout {
    id: section

    property string text
    property string detail

    default property alias trailing: extra.data

    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    Layout.topMargin: 4
    implicitHeight: 22
    spacing: 8

    Text {
        Layout.fillWidth: true
        text: section.text
        elide: Text.ElideRight
        color: Theme.textDim
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
    }

    Text {
        visible: section.detail !== ""
        text: section.detail
        color: Theme.textDim
        font.pixelSize: Theme.fontSmall
        font.features: {
            "tnum": 1
        }
    }

    RowLayout {
        id: extra

        visible: children.length > 0
        spacing: 4
    }
}
