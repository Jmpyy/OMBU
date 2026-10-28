import QtQuick
import QtQuick.Layouts
import Quickshell

// Notificaciones en la pantalla de bloqueo. Por privacidad solo se ven la app y el
// título, no el cuerpo del mensaje, y no se puede actuar sobre ellas.
ColumnLayout {
    id: root

    readonly property int maxItems: 5

    visible: Notifs.count > 0
    width: 340
    spacing: 8

    Text {
        text: "NOTIFICACIONES  " + Notifs.count
        color: Qt.rgba(1, 1, 1, 0.6)
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
    }

    Repeater {
        model: ScriptModel {
            values: Notifs.history.slice(0, root.maxItems)
        }

        Rectangle {
            id: card

            required property var modelData
            readonly property string iconSource: {
                if (modelData.appIcon)
                    return modelData.appIcon.startsWith("/") ? "file://" + modelData.appIcon : Quickshell.iconPath(modelData.appIcon, "");
                const e = DesktopEntries.heuristicLookup(modelData.desktopEntry || modelData.appName);
                return e ? Quickshell.iconPath(e.icon, "") : "";
            }

            required property int index

            Layout.fillWidth: true
            Layout.preferredHeight: 58
            radius: 16
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            // Entrada escalonada: cada tarjeta llega un poco después de la anterior
            opacity: 0
            transform: Translate {
                x: (1 - card.opacity) * 40
            }

            Component.onCompleted: enter.start()

            SequentialAnimation {
                id: enter

                PauseAnimation {
                    duration: 120 + card.index * 90
                }
                NumberAnimation {
                    target: card
                    property: "opacity"
                    to: 1
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Theme.surface

                    Image {
                        id: icon

                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        visible: source != "" && status !== Image.Error
                        source: card.iconSource
                        sourceSize: Qt.size(44, 44)
                        fillMode: Image.PreserveAspectFit
                    }

                    MIcon {
                        anchors.centerIn: parent
                        visible: !icon.visible
                        name: "notifications"
                        color: Theme.textDim
                        font.pixelSize: Theme.iconSm
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.appName
                        elide: Text.ElideRight
                        color: Theme.textDim
                        font.pixelSize: Theme.fontCaption
                    }

                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.summary
                        elide: Text.ElideRight
                        color: Theme.text
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    Text {
        visible: Notifs.count > root.maxItems
        text: "y " + (Notifs.count - root.maxItems) + " más"
        color: Qt.rgba(1, 1, 1, 0.6)
        font.pixelSize: Theme.fontSmall
    }
}
