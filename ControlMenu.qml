import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Centro de control: brillo y volumen, y los ajustes rápidos que no hace falta tener siempre
// a la vista en la barra (layout de teclado, No molestar, dispositivos).
DropPopup {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    signal openDevices
    signal openFocus
    signal openWalls
    signal openPayments

    // Botón: el ícono va en un círculo que se pinta de violeta cuando está activo
    component Tile: Rectangle {
        id: tile

        property string icon
        property string title
        property string subtitle
        property bool on: false

        signal clicked

        implicitHeight: 48
        radius: Theme.controlRadius
        color: area.containsMouse ? Theme.hover : Theme.surface
        border.width: Theme.comic ? 1.5 : 0
        border.color: Theme.comic ? (tile.on ? Theme.accent : "#0a0708") : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 90
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Theme.comic ? 6 : 8
                color: tile.on ? Theme.accent : Theme.track
                border.width: Theme.comic ? 1.5 : 0
                border.color: Theme.comic ? "#0a0708" : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                MIcon {
                    anchors.centerIn: parent
                    name: tile.icon
                    font.pixelSize: 18
                    color: tile.on ? Theme.accentText : Theme.text
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    width: parent.width
                    text: tile.title
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: Theme.comic ? 14 : 13
                    font.weight: Font.DemiBold
                    font.family: Theme.comic ? Theme.displayFont : ""
                }

                Text {
                    width: parent.width
                    text: tile.subtitle
                    elide: Text.ElideRight
                    color: tile.on ? Theme.accent : Theme.textDim
                    font.pixelSize: 11
                }
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    bodyWidth: 340
    bodyHeight: column.implicitHeight + 26

    ColumnLayout {
        id: column

        x: 16
        y: 2
        width: root.bodyWidth - 32
        spacing: 8

        PillSlider {
            Layout.fillWidth: true
            visible: Brightness.available
            icon: "brightness_6"
            value: Brightness.level
            onMoved: v => Brightness.setLevel(v)
        }

        PillSlider {
            Layout.fillWidth: true
            iconClickable: true
            icon: (root.sink?.audio?.muted ?? false) || (root.sink?.audio?.volume ?? 0) <= 0 ? "volume_off" : ((root.sink?.audio?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up")
            value: root.sink?.audio?.volume ?? 0
            muted: root.sink?.audio?.muted ?? false
            onMoved: v => {
                if (root.sink?.audio)
                    root.sink.audio.volume = v;
            }
            onIconClicked: {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            }
        }

        // Lo que suena (solo aparece si hay un reproductor)
        MediaCard {
            Layout.fillWidth: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "keyboard"
                title: "Teclado"
                subtitle: Keyboard.code
                onClicked: Keyboard.toggle()
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Focus.running ? (Focus.phase === "estudio" ? "school" : "coffee") : "timer"
                title: "Modo foco"
                subtitle: Focus.running ? Focus.clock(Focus.remaining) : "Apagado"
                on: Focus.running
                onClicked: root.openFocus()
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Notifs.dnd ? "notifications_off" : "notifications_active"
                title: "No molestar"
                subtitle: Notifs.dnd ? "Activado" : "Desactivado"
                on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Disks.removable.length > 0 ? "usb" : "hard_drive"
                title: "Dispositivos"
                subtitle: Disks.removable.length > 0 ? Disks.removable.length + (Disks.removable.length === 1 ? " conectado" : " conectados") : "Discos"
                onClicked: root.openDevices()
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "payments"
                title: "Pagos"
                subtitle: Subs.upcoming.length > 0 ? Subs.upcoming[0].sub.name + " · " + (Subs.upcoming[0].days <= 0 ? "hoy" : (Subs.upcoming[0].days === 1 ? "mañana" : Subs.upcoming[0].days + " d")) : "Sin suscripciones"
                on: Subs.upcoming.length > 0 && Subs.upcoming[0].days <= 1
                onClicked: root.openPayments()
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "wallpaper"
                title: "Fondo"
                subtitle: Walls.list.length + " imágenes"
                onClicked: root.openWalls()
            }
        }
    }
}
