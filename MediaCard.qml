import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Lo que suena ahora (música, un video del navegador...) en versión compacta para el centro de
// control: portada, título, artista y los tres controles. Solo aparece si hay algún reproductor.
Rectangle {
    id: root

    // El reproductor lo elige Media.qml (el último que sonó, aunque esté en pausa)
    readonly property var player: Media.player

    visible: player !== null
    implicitHeight: 60
    radius: Theme.controlRadius
    color: Theme.surface
    border.width: Theme.comic ? 1.5 : 0
    border.color: Theme.comic ? "#0a0708" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 10

        // Portada con esquinas suaves (clip solo recorta en rectángulo: hace falta una máscara)
        Item {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42

            Rectangle {
                id: artMask

                anchors.fill: parent
                radius: 8
                visible: false
                layer.enabled: true
            }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.track
            }

            Image {
                id: art

                anchors.fill: parent
                visible: status === Image.Ready
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: artMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }

            MIcon {
                anchors.centerIn: parent
                visible: !art.visible
                name: "music_note"
                color: Theme.textDim
                font.pixelSize: 22
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 1

            Text {
                width: parent.width
                text: root.player?.trackTitle || root.player?.identity || ""
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                // Con más de un reproductor se aclara de cuál es
                text: (root.player?.trackArtist || "") + (Media.count > 1 ? ((root.player?.trackArtist ? " · " : "") + (root.player?.identity ?? "")) : (root.player?.trackArtist ? "" : (root.player?.identity ?? "")))
                elide: Text.ElideRight
                color: Theme.textDim
                font.pixelSize: 11
            }
        }

        // Cambiar de reproductor (solo aparece si hay más de uno)
        Rectangle {
            visible: Media.count > 1
            Layout.preferredWidth: switchText.implicitWidth + 14
            Layout.preferredHeight: 22
            radius: 7
            color: switchHover.hovered ? Theme.hover : Theme.track

            Text {
                id: switchText

                anchors.centerIn: parent
                text: (Media.index + 1) + "/" + Media.count
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: switchHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Media.cycle()
            }
        }

        Repeater {
            model: [
                {
                    icon: "skip_previous",
                    can: root.player !== null,
                    run: () => Media.previous(),
                    main: false
                },
                {
                    icon: root.player?.isPlaying ? "pause" : "play_arrow",
                    can: root.player !== null,
                    run: () => Media.toggle(),
                    main: true
                },
                {
                    icon: "skip_next",
                    can: root.player !== null,
                    run: () => Media.next(),
                    main: false
                }
            ]

            Rectangle {
                id: btn

                required property var modelData

                Layout.preferredWidth: modelData.main ? 34 : 28
                Layout.preferredHeight: modelData.main ? 34 : 28
                radius: modelData.main ? 10 : 8
                opacity: modelData.can ? 1 : 0.35
                color: modelData.main ? Theme.accent : (btnHover.hovered && modelData.can ? Theme.hover : "transparent")

                MIcon {
                    anchors.centerIn: parent
                    name: btn.modelData.icon
                    font.pixelSize: btn.modelData.main ? 22 : 20
                    color: btn.modelData.main ? Theme.accentText : Theme.text
                }

                HoverHandler {
                    id: btnHover

                    cursorShape: btn.modelData.can ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                TapHandler {
                    enabled: btn.modelData.can
                    onTapped: btn.modelData.run()
                }
            }
        }
    }
}
