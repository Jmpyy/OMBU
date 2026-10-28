import QtQuick
import Quickshell
import QtQuick.Layouts

// Un dispositivo principal (salida o entrada), como el menú de sonido de macOS: título con el volumen,
// el slider con su botón de silencio y, debajo, la lista de dispositivos con una tilde en el que suena.
ColumnLayout {
    id: root

    property string title
    property string iconOn
    property string iconOff
    property var node
    property var devices: []

    signal selected(var device)

    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false

    // Ícono según el tipo de aparato, por su nombre
    function deviceIcon(d): string {
        const name = (d?.description ?? "").toLowerCase();
        if (/headset|auricular|headphone|cascos/.test(name))
            return "headphones";
        if (/hdmi|displayport|tv|monitor/.test(name))
            return "tv";
        return root.iconOn;
    }

    spacing: 2

    MenuSection {
        text: root.title
        detail: root.muted ? "Silencio" : Math.round(root.volume * 100) + " %"
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 8
        Layout.bottomMargin: 2
        spacing: 6

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 14
            color: muteArea.containsMouse ? Theme.hover : "transparent"

            MIcon {
                anchors.centerIn: parent
                name: root.muted ? root.iconOff : root.iconOn
                font.pixelSize: Theme.iconMd
                color: root.muted ? Theme.danger : Theme.text
            }

            MouseArea {
                id: muteArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.node?.audio)
                        root.node.audio.muted = !root.node.audio.muted;
                }
            }
        }

        MixerSlider {
            Layout.fillWidth: true
            value: root.volume
            muted: root.muted
            onMoved: v => {
                if (root.node?.audio)
                    root.node.audio.volume = v;
            }
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.devices
        }

        MenuRow {
            required property var modelData

            icon: root.deviceIcon(modelData)
            text: modelData.description
            checked: modelData === root.node
            onClicked: root.selected(modelData)
        }
    }
}
