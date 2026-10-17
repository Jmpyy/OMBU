import QtQuick
import Quickshell
import QtQuick.Layouts

// Bloque de un dispositivo principal (salida o entrada) con su volumen,
// mute y la lista para cambiar de dispositivo.
ColumnLayout {
    id: root

    property string title
    property string iconOn
    property string iconOff
    property var node
    property var devices: []
    property bool expanded: false

    signal selected(var device)

    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false

    spacing: 8

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: root.title
            color: Theme.textDim
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: Math.round(root.volume * 100) + "%"
            color: root.muted ? Theme.textDim : Theme.text
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 18
            color: muteHover.hovered ? Theme.hover : Theme.surface

            MIcon {
                anchors.centerIn: parent
                name: root.muted ? root.iconOff : root.iconOn
                color: root.muted ? Theme.danger : Theme.text
            }

            HoverHandler {
                id: muteHover
            }
            TapHandler {
                onTapped: {
                    if (root.node?.audio)
                        root.node.audio.muted = !root.node.audio.muted;
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.node ? root.node.description : "Sin dispositivo"
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: Theme.fontSize
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

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 8
            visible: root.devices.length > 1
            color: expandHover.hovered || root.expanded ? Theme.hover : "transparent"

            MIcon {
                anchors.centerIn: parent
                name: "expand_more"
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.popupDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            HoverHandler {
                id: expandHover
            }
            TapHandler {
                onTapped: root.expanded = !root.expanded
            }
        }
    }

    // Lista para elegir el dispositivo principal
    Column {
        Layout.fillWidth: true
        visible: root.expanded

        Repeater {
            model: ScriptModel {
                values: root.devices
            }

            Rectangle {
                id: item

                required property var modelData
                readonly property bool isDefault: modelData === root.node

                width: parent.width
                height: 34
                radius: 10
                color: itemHover.hovered ? Theme.hover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    MIcon {
                        name: item.isDefault ? "radio_button_checked" : "radio_button_unchecked"
                        color: item.isDefault ? Theme.accent : Theme.textDim
                        font.pixelSize: 17
                    }

                    Text {
                        Layout.fillWidth: true
                        text: item.modelData.description
                        elide: Text.ElideRight
                        color: item.isDefault ? Theme.text : Theme.textDim
                        font.pixelSize: 12
                    }
                }

                HoverHandler {
                    id: itemHover
                }
                TapHandler {
                    onTapped: root.selected(item.modelData)
                }
            }
        }
    }
}
