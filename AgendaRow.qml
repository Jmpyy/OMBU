import QtQuick
import QtQuick.Layouts

// Una fila de la tarjeta Agenda del Resumen: punto de color (el de su tipo de facultad, o feriado,
// Google o propio), el día (en «Próximos días») o la hora, y el título.
RowLayout {
    id: root

    required property var modelData
    property bool showDay: false

    readonly property string facuKind: Facu.kindOf(modelData)

    spacing: 8

    Rectangle {
        Layout.preferredWidth: 6
        Layout.preferredHeight: 6
        radius: 3
        color: root.facuKind !== "" ? Facu.kindColor(root.facuKind) : (root.modelData.kind === "holiday" ? Agenda.holidayColor : (root.modelData.kind === "google" ? Agenda.googleColor : Agenda.localColor))
    }

    Text {
        visible: root.showDay || (root.modelData.time ?? "") !== ""
        Layout.preferredWidth: root.showDay ? 112 : implicitWidth
        text: root.showDay ? Chrono.capitalize(Agenda.parseDay(root.modelData.day).toLocaleDateString(Chrono.locale, "ddd d MMM")) + (root.modelData.time ? " " + root.modelData.time : "") : root.modelData.time
        elide: Text.ElideRight
        color: Theme.textDim
        font.pixelSize: Theme.fontSmall
        font.family: root.showDay ? Qt.application.font.family : "monospace"
    }

    Text {
        Layout.fillWidth: true
        text: root.modelData.title
        elide: Text.ElideRight
        color: Theme.text
        font.pixelSize: Theme.fontBody
    }
}
