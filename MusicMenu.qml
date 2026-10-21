import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Mpris

// Lo que suena en tu app de música (Sung; ver Media.musicApps), en grande: cuelga del indicador de
// música de la barra. Un video del navegador no aparece acá. Portada sobre un fondo hecho con
// la misma portada desenfocada, título, artista y álbum, línea de tiempo, controles (aleatorio y repetir
// solo si el reproductor los tiene) y el volumen propio del reproductor. Con los temas de cómic, la
// portada es una viñeta (borde de tinta y sombra dura) con el sticker «Ahora suena».
DropPopup {
    id: root

    readonly property var player: Media.music
    readonly property int pad: 14

    bodyWidth: 340
    bodyHeight: column.implicitHeight + 22
    centered: true

    // Portada: YouTube no siempre tiene la de máxima resolución, se cae a hqdefault (ver Media.artUrl)
    Image {
        id: cover

        readonly property string url: root.player?.trackArtUrl ?? ""
        property bool failed: false

        onUrlChanged: failed = false
        onStatusChanged: if (status === Image.Error)
            failed = true
        visible: false
        source: Media.artUrl(url, failed)
        sourceSize: Qt.size(400, 400)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    ColumnLayout {
        id: column

        x: root.pad
        y: 4
        width: root.bodyWidth - 2 * root.pad
        spacing: 12

        // De qué app es y traerla al frente
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: (root.player?.identity ?? "").toUpperCase()
                elide: Text.ElideRight
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            RoundButton {
                visible: root.player?.canRaise ?? false
                icon: "open_in_new"
                size: 26
                onClicked: root.player.raise()
            }
        }

        // La portada sobre su propio fondo desenfocado
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 200

            Rectangle {
                id: heroMask

                anchors.fill: parent
                radius: Theme.cardRadius
                visible: false
                layer.enabled: true
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.cardRadius
                color: Theme.surface
            }

            MultiEffect {
                anchors.fill: parent
                visible: cover.status === Image.Ready
                source: cover
                blurEnabled: true
                blur: 1
                blurMax: 48
                brightness: -0.3
                saturation: 0.15
                maskEnabled: true
                maskSource: heroMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Halftone {
                strength: 0.08
            }

            // Sombra dura de la viñeta (temas de cómic)
            Rectangle {
                visible: Theme.comic
                x: art.x + 5
                y: art.y + 5
                width: art.width
                height: art.height
                radius: art.radius
                color: Theme.shadow
            }

            Rectangle {
                id: art

                anchors.centerIn: parent
                width: 160
                height: 160
                radius: Theme.comic ? 8 : 14
                color: Theme.track

                Rectangle {
                    id: artMask

                    anchors.fill: parent
                    radius: parent.radius
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    visible: cover.status === Image.Ready
                    source: cover
                    maskEnabled: true
                    maskSource: artMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                MIcon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    name: "music_note"
                    color: Theme.textDim
                    font.pixelSize: 56
                }

                // El borde va encima de la imagen para que la tinta no quede tapada
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: Theme.comic ? 2 : 1
                    border.color: Theme.comic ? Theme.ink : Theme.border
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.player?.canRaise ?? false
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.player.raise()
                }
            }

            Sticker {
                visible: Theme.comic
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 10
                text: root.player?.isPlaying ? "Ahora suena" : "En pausa"
            }
        }

        // Título, artista y álbum
        Column {
            Layout.fillWidth: true
            spacing: 2

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.player?.trackTitle || root.player?.identity || ""
                color: Theme.text
                font.family: Theme.comic ? Theme.displayFont : Theme.font
                font.pixelSize: Theme.comic ? 24 : 16
                font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                font.letterSpacing: Theme.comic ? 0.6 : 0
            }

            Text {
                width: parent.width
                visible: text !== ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.player?.trackArtist ?? ""
                color: Theme.comic ? Theme.accent : Theme.text
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                visible: text !== ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.player?.trackAlbum ?? ""
                color: Theme.textDim
                font.pixelSize: 11
            }
        }

        MediaTimeline {
            Layout.fillWidth: true
            player: root.player
            barHeight: 5
            fontSize: 11
        }

        // Controles: aleatorio · anterior · reproducir · siguiente · repetir
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            RoundButton {
                visible: root.player?.shuffleSupported ?? false
                icon: "shuffle"
                size: 32
                active: root.player?.shuffle ?? false
                onClicked: root.player.shuffle = !root.player.shuffle
            }

            RoundButton {
                icon: "skip_previous"
                enabled: root.player !== null
                onClicked: Media.previous(root.player)
            }

            RoundButton {
                primary: true
                size: 52
                icon: root.player?.isPlaying ? "pause" : "play_arrow"
                enabled: root.player !== null
                onClicked: Media.toggle(root.player)
            }

            RoundButton {
                icon: "skip_next"
                enabled: root.player !== null
                onClicked: Media.next(root.player)
            }

            // Sin repetir → repetir la lista → repetir el tema
            RoundButton {
                visible: root.player?.loopSupported ?? false
                icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                size: 32
                active: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: {
                    const s = root.player.loopState;
                    root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : (s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
                }
            }
        }

        // Volumen propio del reproductor (no el general del sistema)
        PillSlider {
            Layout.fillWidth: true
            visible: (root.player?.volumeSupported ?? false) && (root.player?.canControl ?? false)
            icon: "music_note"
            value: root.player?.volume ?? 0
            onMoved: v => root.player.volume = v
        }
    }
}
