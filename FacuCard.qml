import QtQuick
import QtQuick.Layouts

// Tarjeta «Facultad» del Resumen: entregas, parciales, recuperatorios y finales de los próximos 60 días
// con la cuenta regresiva (rojo si es mañana o antes, amarillo si es esta semana) y las materias con
// sus notas (un clic las abre en Zed). Se anota con Super+Alt+N (AnotarMenu).
ComicCard {
    id: root

    readonly property var list: Facu.deadlines.slice(0, 5)

    function urgency(n: int): color {
        return n <= 1 ? Theme.danger : (n <= 7 ? Theme.warn : Theme.textDim);
    }

    title: "Facultad"
    tint: Theme.danger

    Text {
        visible: root.list.length === 0
        Layout.fillWidth: true
        text: "Sin entregas ni parciales a la vista."
        wrapMode: Text.Wrap
        color: Theme.textDim
        font.pixelSize: 12
    }

    Repeater {
        model: root.list

        RowLayout {
            id: row

            required property var modelData
            readonly property color uc: root.urgency(modelData.daysLeft)

            Layout.fillWidth: true
            spacing: 10

            MIcon {
                name: Facu.kindIcon(row.modelData.kind)
                color: Facu.kindColor(row.modelData.kind)
                font.pixelSize: 18
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: row.modelData.title
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    text: Chrono.capitalize(Agenda.parseDay(row.modelData.day).toLocaleDateString(Chrono.locale, "ddd d/M")) + (row.modelData.time ? " · " + row.modelData.time : "")
                    color: Theme.textDim
                    font.pixelSize: 11
                }
            }

            // Cuenta regresiva
            Rectangle {
                implicitWidth: left.implicitWidth + 14
                implicitHeight: 22
                radius: 6
                color: Qt.rgba(row.uc.r, row.uc.g, row.uc.b, row.modelData.daysLeft <= 1 ? 0.28 : 0.14)
                border.width: Theme.comic && row.modelData.daysLeft <= 1 ? 1.5 : 0
                border.color: Theme.ink

                Text {
                    id: left

                    anchors.centerIn: parent
                    text: Facu.leftText(row.modelData.daysLeft)
                    color: row.modelData.daysLeft <= 7 ? row.uc : Theme.text
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Text {
        visible: Facu.deadlines.length > root.list.length
        text: "y " + (Facu.deadlines.length - root.list.length) + " más en los próximos 60 días"
        color: Theme.textDim
        font.pixelSize: 11
    }

    // Materias: notas de cada una
    Flow {
        visible: Facu.subjects.length > 0
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 6

        Repeater {
            model: Facu.subjects

            Rectangle {
                id: chip

                required property var modelData

                width: chipRow.implicitWidth + 16
                height: 26
                radius: Theme.controlRadius - 3
                color: chipHover.hovered ? Theme.hover : Theme.track

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: 5

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "sticky_note_2"
                        font.pixelSize: 14
                        color: chip.modelData.notes > 0 ? (Themes.active.border2 ?? Theme.accent) : Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.name + (chip.modelData.notes > 0 ? " · " + chip.modelData.notes : "")
                        color: Theme.text
                        font.pixelSize: 11
                    }
                }

                HoverHandler {
                    id: chipHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: Facu.openNotes(chip.modelData)
                }
            }
        }
    }
}
