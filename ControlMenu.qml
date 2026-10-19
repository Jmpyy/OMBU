import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Centro de control: brillo y volumen, y los ajustes rápidos que no hace falta tener siempre
// a la vista en la barra (layout de teclado, No molestar, dispositivos).
DropPopup {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    signal openDevices

    // Botón grande: ícono y dos líneas de texto; resaltado cuando está activo
    component Tile: Rectangle {
        id: tile

        property string icon
        property string title
        property string subtitle
        property bool on: false

        signal clicked

        implicitHeight: 54
        radius: 12
        color: on ? Theme.accent : (area.containsMouse ? Theme.hover : Theme.surface)

        Behavior on color {
            ColorAnimation {
                duration: 90
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            MIcon {
                name: tile.icon
                font.pixelSize: 22
                color: tile.on ? "#14131a" : Theme.text
            }

            Column {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    width: parent.width
                    text: tile.title
                    elide: Text.ElideRight
                    color: tile.on ? "#14131a" : Theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: tile.subtitle
                    elide: Text.ElideRight
                    color: tile.on ? "#14131a" : Theme.textDim
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

    // Fila con ícono, slider y porcentaje
    component SliderRow: RowLayout {
        id: row

        property string icon
        property real value
        property bool muted: false
        property string text

        signal moved(real value)
        signal iconClicked

        spacing: 12

        MouseArea {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            cursorShape: Qt.PointingHandCursor
            onClicked: row.iconClicked()

            MIcon {
                anchors.centerIn: parent
                name: row.icon
                font.pixelSize: 22
                color: row.muted ? Theme.danger : Theme.text
            }
        }

        MixerSlider {
            Layout.fillWidth: true
            value: row.value
            muted: row.muted
            onMoved: v => row.moved(v)
        }

        Text {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            text: row.text
            color: row.muted ? Theme.textDim : Theme.text
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    bodyWidth: 340
    bodyHeight: column.implicitHeight + 26

    ColumnLayout {
        id: column

        x: 16
        y: 2
        width: root.bodyWidth - 32
        spacing: 14

        SliderRow {
            Layout.fillWidth: true
            visible: Brightness.available
            icon: "brightness_6"
            value: Brightness.level
            text: Math.round(Brightness.level * 100) + "%"
            onMoved: v => Brightness.setLevel(v)
        }

        SliderRow {
            Layout.fillWidth: true
            icon: (root.sink?.audio?.muted ?? false) || (root.sink?.audio?.volume ?? 0) <= 0 ? "volume_off" : ((root.sink?.audio?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up")
            value: root.sink?.audio?.volume ?? 0
            muted: root.sink?.audio?.muted ?? false
            text: muted ? "Mute" : Math.round(value * 100) + "%"
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
        }
    }
}
