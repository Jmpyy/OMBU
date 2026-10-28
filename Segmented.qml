import QtQuick

// Selector segmentado: una píldora con la opción elegida resaltada que se desliza.
// model: [{id, name}], current: id elegido; picked(id) al tocar otra.
Rectangle {
    id: root

    property var model: []
    property string current

    signal picked(string id)

    readonly property int index: Math.max(0, model.findIndex(m => m.id === current))
    readonly property real segment: (width - 6) / Math.max(1, model.length)

    implicitHeight: 28
    radius: Theme.controlRadius
    color: Theme.surface

    Rectangle {
        x: 3 + root.index * root.segment
        y: 3
        width: root.segment
        height: root.height - 6
        radius: Theme.controlRadius - 2
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)

        Behavior on x {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Theme.ease
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 3

        Repeater {
            model: root.model

            Item {
                id: seg

                required property var modelData
                required property int index

                width: root.segment
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: seg.modelData.name
                    color: root.index === seg.index ? Theme.accent : (area.containsMouse ? Theme.text : Theme.textDim)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(seg.modelData.id)
                }
            }
        }
    }
}
