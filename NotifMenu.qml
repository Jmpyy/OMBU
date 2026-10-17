import QtQuick
import Quickshell
import QtQuick.Layouts

// Historial de notificaciones, colgando de la campana de la barra.
DropPopup {
    id: root

    readonly property int maxHeight: 440

    bodyWidth: 420
    bodyHeight: column.implicitHeight + 24

    ColumnLayout {
        id: column

        x: 14
        y: 2
        width: root.bodyWidth - 28
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "NOTIFICACIONES"
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                text: Notifs.count
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
            }

            // No molestar
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: dndRow.implicitWidth + 20
                radius: 14
                color: Notifs.dnd ? Theme.accent : (dndHover.hovered ? Theme.hover : Theme.surface)

                Row {
                    id: dndRow

                    anchors.centerIn: parent
                    spacing: 5

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Notifs.dnd ? "notifications_off" : "notifications_active"
                        font.pixelSize: 15
                        color: Notifs.dnd ? "#14131a" : Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "No molestar"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Notifs.dnd ? "#14131a" : Theme.text
                    }
                }

                HoverHandler {
                    id: dndHover
                }
                TapHandler {
                    onTapped: Notifs.dnd = !Notifs.dnd
                }
            }

            // Limpiar todo
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: clearText.implicitWidth + 20
                radius: 14
                visible: Notifs.count > 0
                color: clearHover.hovered ? Theme.danger : Theme.surface

                Text {
                    id: clearText

                    anchors.centerIn: parent
                    text: "Limpiar"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: clearHover.hovered ? "#14131a" : Theme.text
                }

                HoverHandler {
                    id: clearHover
                }
                TapHandler {
                    onTapped: Notifs.dismissAll()
                }
            }
        }

        Text {
            visible: Notifs.count === 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 10
            horizontalAlignment: Text.AlignHCenter
            text: Notifs.dnd ? "Sin notificaciones. No molestar está activado." : "Sin notificaciones."
            color: Theme.textDim
            font.pixelSize: 13
        }

        Flickable {
            visible: Notifs.count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(list.implicitHeight, root.maxHeight)
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: parent.width
                spacing: 8

                Repeater {
                    model: ScriptModel {
                        values: Notifs.history
                    }

                    NotifCard {
                        required property var modelData

                        width: list.width
                        entry: modelData
                    }
                }
            }
        }
    }
}
