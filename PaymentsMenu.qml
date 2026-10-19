import QtQuick
import QtQuick.Layouts

// Pagos: las suscripciones y pagos fijos ordenados por el próximo vencimiento, con cuánto es y
// quién paga, y el total por mes.
DropPopup {
    id: root

    bodyWidth: 380
    bodyHeight: column.implicitHeight + 26

    ColumnLayout {
        id: column

        x: 16
        y: 2
        width: root.bodyWidth - 32
        spacing: 6

        Text {
            text: "PAGOS"
            color: Theme.textDim
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Text {
            visible: Subs.list.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 10
            horizontalAlignment: Text.AlignHCenter
            text: "Todavía no cargaste ninguna suscripción"
            color: Theme.textDim
            font.pixelSize: 13
        }

        Repeater {
            model: Subs.upcoming

            Rectangle {
                id: row

                required property var modelData
                readonly property var sub: modelData.sub
                readonly property int days: modelData.days
                // Hoy y mañana en ámbar, esta semana en violeta
                readonly property color tone: days <= 1 ? Theme.warn : (days <= 7 ? Theme.accent : Theme.textDim)

                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.controlRadius
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: row.tone
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.sub.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: Subs.whenText(row.days) + " · " + Qt.formatDate(modelData.due, "d MMM") + (row.sub.payer === "mama" ? " · avisar a mamá" : (row.sub.method !== "" ? " · " + row.sub.method : ""))
                            color: row.tone
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        text: Subs.money(row.sub.amount, row.sub.currency)
                        color: Theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // Totales por mes
        ColumnLayout {
            visible: Subs.list.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            Repeater {
                model: [
                    {
                        label: "Pagás vos",
                        value: Subs.total("yo")
                    },
                    {
                        label: "Paga mamá",
                        value: Subs.total("mama")
                    },
                    {
                        label: "Total por mes",
                        value: Subs.total("")
                    }
                ].filter(r => r.value !== "")

                RowLayout {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: parent.modelData.label
                        color: parent.modelData.label === "Total por mes" ? Theme.text : Theme.textDim
                        font.pixelSize: 12
                        font.weight: parent.modelData.label === "Total por mes" ? Font.DemiBold : Font.Normal
                    }

                    Text {
                        text: parent.modelData.value
                        color: parent.modelData.label === "Total por mes" ? Theme.text : Theme.textDim
                        font.pixelSize: 12
                        font.weight: parent.modelData.label === "Total por mes" ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
