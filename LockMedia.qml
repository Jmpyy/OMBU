import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// "Reproduciendo ahora": lo que suena (música, un video del navegador...) con controles.
// Solo aparece si hay algún reproductor.
Rectangle {
    id: root

    readonly property var all: Array.from(Mpris.players.values)
    readonly property var player: all.find(p => p.isPlaying) ?? all[0] ?? null

    width: 340
    implicitHeight: content.implicitHeight + 36
    visible: player !== null
    radius: 24
    color: Theme.bg
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 18
        spacing: 14

        Text {
            text: "REPRODUCIENDO AHORA"
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Portada con esquinas redondeadas (clip solo recorta en rectángulo, hace falta una máscara)
            Item {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 68

                Rectangle {
                    id: artMask

                    anchors.fill: parent
                    radius: 16
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Theme.surface
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
                    font.pixelSize: 30
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle || root.player?.identity || ""
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    color: Theme.textDim
                    font.pixelSize: 13
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player?.identity ?? ""
                    elide: Text.ElideRight
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 11
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                opacity: root.player?.canGoPrevious ? 1 : 0.35
                color: prevHover.hovered ? Theme.hover : "transparent"

                MIcon {
                    anchors.centerIn: parent
                    name: "skip_previous"
                    font.pixelSize: 24
                }

                HoverHandler {
                    id: prevHover
                }
                TapHandler {
                    enabled: root.player?.canGoPrevious ?? false
                    onTapped: root.player.previous()
                }
            }

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 24
                opacity: root.player?.canTogglePlaying ? 1 : 0.35
                color: Theme.accent

                MIcon {
                    anchors.centerIn: parent
                    name: root.player?.isPlaying ? "pause" : "play_arrow"
                    color: Theme.accentText
                    font.pixelSize: 28
                }

                TapHandler {
                    enabled: root.player?.canTogglePlaying ?? false
                    onTapped: root.player.togglePlaying()
                }
            }

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                opacity: root.player?.canGoNext ? 1 : 0.35
                color: nextHover.hovered ? Theme.hover : "transparent"

                MIcon {
                    anchors.centerIn: parent
                    name: "skip_next"
                    font.pixelSize: 24
                }

                HoverHandler {
                    id: nextHover
                }
                TapHandler {
                    enabled: root.player?.canGoNext ?? false
                    onTapped: root.player.next()
                }
            }
        }
    }
}
