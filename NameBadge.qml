import QtQuick
import QtQuick.Layouts

// Sticker de cómic estilo "HELLO my name is": inspirado en el fondo de Peter Parker.
Item {
    id: root

    property string name: "JUAMPY"
    property bool alert: false

    implicitWidth: 230
    implicitHeight: 125

    // Sombra dura detrás del sticker
    Rectangle {
        anchors.fill: card
        anchors.leftMargin: 6
        anchors.topMargin: 6
        radius: card.radius
        color: Theme.shadow.a > 0 ? Theme.shadow : Theme.ink
        rotation: card.rotation
        opacity: 0.85
    }

    // El sticker
    Rectangle {
        id: card

        anchors.fill: parent
        radius: 8
        color: "#f6f4ee"
        border.width: 2
        border.color: Theme.ink
        rotation: -2.5
        clip: true

        Column {
            anchors.fill: parent

            // Encabezado rojo con "HELLO my name is"
            Rectangle {
                width: parent.width
                height: 46
                color: root.alert ? Theme.danger : Theme.accent
                border.width: 2
                border.color: Theme.ink

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: -2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "HELLO"
                        color: "#ffffff"
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.Black
                        font.letterSpacing: 3
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "my name is"
                        color: "#ffffff"
                        font.pixelSize: Theme.fontTiny
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }
                }
            }

            // Cuerpo del sticker: papel blanco con el nombre en tinta
            Item {
                width: parent.width
                height: parent.height - 46

                // Trama suave de fondo
                Halftone {
                    art: true
                    strength: 0.04
                    anchors.margins: 2
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.name
                        color: "#110c0e"
                        font.family: Theme.artFont || Qt.application.font.family
                        font.pixelSize: 32
                        font.letterSpacing: 2
                        font.weight: Font.Bold
                    }

                    // Signo de exclamación / sentido arácnido si falla la contraseña
                    Rectangle {
                        visible: root.alert
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        radius: 4
                        color: Theme.danger
                        border.width: 1.5
                        border.color: Theme.ink
                        rotation: 12

                        Text {
                            anchors.centerIn: parent
                            text: "!"
                            color: "#ffffff"
                            font.family: Theme.artFont || Qt.application.font.family
                            font.pixelSize: Theme.fontEmphasis
                            font.weight: Font.Bold
                        }
                    }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 5
                    text: "friendly neighborhood"
                    color: Qt.rgba(0, 0, 0, 0.3)
                    font.pixelSize: Theme.fontTiny
                    font.italic: true
                }
            }
        }
    }
}
