import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Centro de control, versión mínima: brillo y volumen (con nombre y valor) y tres interruptores (modo
// foco, No molestar, teclado). Los pagos y la música están en el panel lateral, y el fondo se elige con
// Super+Ctrl+Espacio o desde el menú del sistema. Con los temas de cómic todo es
// viñeta: borde de tinta y sombra dura.
DropPopup {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    onOpenChanged: if (open)
        Brightness.refresh()

    signal openFocus
    signal openWalls

    // Interruptor cuadrado: ícono arriba (se pinta de acento cuando está activo), nombre y estado
    component Tile: Rectangle {
        id: tile

        property string icon
        property string title
        property string subtitle
        property bool on: false

        signal clicked

        implicitHeight: 82
        radius: Theme.controlRadius
        color: area.containsMouse ? Theme.hover : Theme.surface
        border.width: Theme.comic ? 2 : 0
        border.color: Theme.comic ? (tile.on ? Theme.accent : Theme.ink) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 90
            }
        }

        // Sombra dura (temas de cómic): hija con z negativo para no correr nada de lugar
        Rectangle {
            z: -1
            visible: Theme.comic
            x: 3
            y: 3
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.shadow
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 4

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 34
                height: 34
                radius: Theme.comic ? 6 : 10
                color: tile.on ? Theme.accent : Theme.track
                border.width: Theme.comic ? 1.5 : 0
                border.color: Theme.comic ? Theme.ink : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                MIcon {
                    anchors.centerIn: parent
                    name: tile.icon
                    font.pixelSize: 19
                    color: tile.on ? Theme.accentText : Theme.text
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Theme.comic ? tile.title.toUpperCase() : tile.title
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: Theme.comic ? 14 : 12
                font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                font.family: Theme.comic ? Theme.displayFont : ""
                font.letterSpacing: Theme.comic ? 0.5 : 0
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.subtitle
                elide: Text.ElideRight
                color: tile.on ? Theme.accent : Theme.textDim
                font.pixelSize: 11
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
    bodyHeight: column.implicitHeight + 28

    ColumnLayout {
        id: column

        x: 16
        y: 4
        width: root.bodyWidth - 32
        spacing: 10

        PillSlider {
            Layout.fillWidth: true
            visible: Brightness.available
            icon: "brightness_6"
            label: "Brillo"
            value: Brightness.level
            onMoved: v => Brightness.setLevel(v)
        }

        PillSlider {
            Layout.fillWidth: true
            iconClickable: true
            icon: (root.sink?.audio?.muted ?? false) || (root.sink?.audio?.volume ?? 0) <= 0 ? "volume_off" : ((root.sink?.audio?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up")
            label: "Volumen"
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

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            columns: 3
            columnSpacing: 9
            rowSpacing: 9

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Focus.running ? (Focus.phase === "estudio" ? "school" : "coffee") : "timer"
                title: "Foco"
                subtitle: Focus.running ? Focus.clock(Focus.remaining) : "Apagado"
                on: Focus.running
                onClicked: root.openFocus()
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Notifs.dnd ? "notifications_off" : "notifications_active"
                title: "No molestar"
                subtitle: Notifs.dnd ? "Activado" : "Apagado"
                on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "keyboard"
                title: "Teclado"
                subtitle: Keyboard.code
                onClicked: Keyboard.toggle()
            }
        }
    }
}
