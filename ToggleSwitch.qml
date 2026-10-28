import QtQuick

// Interruptor chico, como los de macOS: acento cuando está prendido
Rectangle {
    id: sw

    property bool on: false

    signal toggled

    implicitWidth: 34
    implicitHeight: 20
    radius: 10
    color: on ? Theme.accent : Theme.track

    activeFocusOnTab: true
    Keys.onReturnPressed: sw.toggled()
    Keys.onEnterPressed: sw.toggled()
    Keys.onSpacePressed: sw.toggled()

    KeyFocus {}

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    Rectangle {
        x: sw.on ? sw.width - width - 2 : 2
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: sw.on ? Theme.accentText : Theme.text

        Behavior on x {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Theme.ease
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
