import QtQuick

// Tarjeta de una respuesta del chat: encabezado con el agente, el modelo y la hora (y copiar),
// y debajo los pasos y el texto (MessageBody). `live` = la respuesta que todavía está llegando.
Item {
    id: root

    property string agent
    property string model
    property real at: 0
    property string text
    property string tools
    property bool live: false

    implicitHeight: card.height + (Theme.comic ? 3 : 0)

    // Sombra dura de viñeta (solo temas de cómic)
    Rectangle {
        visible: Theme.comic
        x: 3
        y: 3
        width: card.width
        height: card.height
        radius: card.radius
        color: Theme.shadow
    }

    Rectangle {
        id: card

        width: parent.width - (Theme.comic ? 3 : 0)
        height: col.implicitHeight + 22
        radius: Theme.controlRadius
        color: Theme.surface
        border.width: Theme.comic ? 1.5 : 1
        border.color: Theme.comic ? Theme.ink : Theme.border

        Column {
            id: col

            x: 12
            y: 10
            width: parent.width - 24
            spacing: 8

            Item {
                width: parent.width
                height: 20

                Rectangle {
                    id: avatar

                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 6
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)

                    MIcon {
                        anchors.centerIn: parent
                        name: root.agent === "agy" ? "rocket_launch" : "auto_awesome"
                        font.pixelSize: 13
                        color: Theme.accent
                    }
                }

                Row {
                    anchors.left: avatar.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        anchors.baseline: parent.children[1].baseline
                        text: Chat.agentLabel(root.agent)
                        color: Theme.text
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.model !== ""
                        text: root.model
                        color: Theme.textDim
                        font.pixelSize: 11
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.at > 0
                        text: Qt.formatTime(new Date(root.at), "HH:mm")
                        color: Theme.textDim
                        font.pixelSize: 11
                    }

                    // Copiar la respuesta
                    Rectangle {
                        visible: !root.live && root.text !== ""
                        width: 22
                        height: 22
                        radius: 6
                        color: copyHover.hovered ? Theme.hover : "transparent"

                        MIcon {
                            id: copyIcon

                            anchors.centerIn: parent
                            name: copied.running ? "check" : "content_copy"
                            font.pixelSize: 14
                            color: copied.running ? Theme.accent : Theme.textDim
                        }

                        Timer {
                            id: copied

                            interval: 1500
                        }

                        HoverHandler {
                            id: copyHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: {
                                Chat.copy(root.text);
                                copied.restart();
                            }
                        }
                    }
                }
            }

            MessageBody {
                width: parent.width
                text: root.text
                tools: root.tools
                thinking: root.live
            }
        }
    }
}
