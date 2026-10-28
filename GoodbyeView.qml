import QtQuick

// Lo que se ve al despedirse (ver Goodbye): fundido a negro, el logo del tema que late despacio, un
// saludo y «Apagando…». Lo usan GoodbyeWindow (sobre el escritorio) y LockScreen (con la sesión
// bloqueada nada se dibuja por encima del bloqueo, así que va adentro).
Item {
    id: root

    // Falso hasta que la ventana dibujó su primer cuadro (GoodbyeWindow), para que el fundido no salte
    property bool armed: true
    readonly property bool active: armed && Goodbye.action !== ""

    visible: opacity > 0.001
    opacity: active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 600
            easing.type: Easing.InOutQuad
        }
    }

    // Se come los clics: con la despedida en curso no se toca nada de abajo
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.ink
    }

    Halftone {
        art: true
        anchors.margins: 0
        strength: 0.06
    }

    Column {
        anchors.centerIn: parent
        spacing: 16

        Item {
            id: logo

            anchors.horizontalCenter: parent.horizontalCenter
            width: 110
            height: 110
            scale: 0.9 + 0.1 * root.opacity

            // El logo del tema (la araña, el reactor) o, si no hay, el de CachyOS
            Image {
                anchors.fill: parent
                visible: themeLogo.status !== Image.Ready
                source: "file:///usr/share/icons/cachyos.svg"
                sourceSize: Qt.size(220, 220)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Image {
                id: themeLogo

                anchors.fill: parent
                source: Themes.logoFile
                sourceSize: Qt.size(220, 220)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            SequentialAnimation on opacity {
                running: root.active
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.55
                    duration: 700
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutSine
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.comicArt ? "¡HASTA LUEGO, VECINO!" : "Hasta luego"
            color: Theme.comicArt ? Theme.accent : Theme.text
            font.family: Theme.comicArt ? Theme.artFont : Qt.application.font.family
            font.pixelSize: Theme.comicArt ? 46 : 28
            font.weight: Theme.comicArt ? Font.Normal : Font.DemiBold
            font.letterSpacing: Theme.comicArt ? 1.5 : 0
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Goodbye.label
            color: Theme.textDim
            font.pixelSize: Theme.fontEmphasis
        }
    }
}
