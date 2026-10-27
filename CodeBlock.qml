import QtQuick

// Bloque de código de una respuesta del chat: encabezado con el lenguaje y «Copiar», y el código en
// monoespaciada sobre un fondo más oscuro (seleccionable). `open` = todavía está llegando.
Rectangle {
    id: root

    property string lang
    property string code
    property bool open: false

    implicitHeight: header.height + body.implicitHeight + 16
    radius: Theme.controlRadius - 2
    color: Qt.darker(Theme.bg, 1.25)
    border.width: Theme.comic ? 1.5 : 1
    border.color: Theme.comic ? Theme.ink : Theme.border

    Item {
        id: header

        width: parent.width
        height: 28

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.lang !== "" ? root.lang : "código"
            color: Theme.textDim
            font.pixelSize: 11
            font.family: "monospace"
        }

        Rectangle {
            visible: !root.open
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: copyRow.implicitWidth + 12
            height: 22
            radius: 5
            color: copyHover.hovered ? Theme.hover : "transparent"

            Row {
                id: copyRow

                anchors.centerIn: parent
                spacing: 4

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: copied.running ? "check" : "content_copy"
                    font.pixelSize: 13
                    color: copied.running ? Theme.accent : Theme.textDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: copied.running ? "Copiado" : "Copiar"
                    color: copied.running ? Theme.accent : Theme.textDim
                    font.pixelSize: 11
                }
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
                    Chat.copy(root.code);
                    copied.restart();
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }
    }

    TextEdit {
        id: body

        x: 10
        y: header.height + 8
        width: parent.width - 20
        text: root.code
        readOnly: true
        selectByMouse: true
        wrapMode: TextEdit.WrapAnywhere
        textFormat: TextEdit.PlainText
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: "monospace"
        font.pixelSize: 12
    }
}
