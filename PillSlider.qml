import QtQuick

// Slider grueso con el ícono adentro, como el centro de control de macOS. Con el ícono
// a la izquierda del relleno: clic en el ícono dispara iconClicked (ej. silenciar).
Item {
    id: slider

    property string icon
    property real value: 0
    property bool muted: false
    property bool iconClickable: false

    signal moved(real value)
    signal iconClicked

    implicitHeight: 40

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Theme.surface
        clip: true

        Rectangle {
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, slider.value)))
            height: parent.height
            radius: parent.radius
            color: slider.muted ? Theme.textDim : Theme.accent
        }
    }

    MIcon {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        name: slider.icon
        font.pixelSize: 20
        color: slider.muted ? Theme.danger : (slider.value > 0.04 ? "#14131a" : Theme.text)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            if (mouse.x < 40 && slider.iconClickable)
                slider.iconClicked();
            else
                slider.moved(Math.max(0, Math.min(1, mouse.x / width)));
        }
        onPositionChanged: mouse => {
            if (pressed && mouse.x >= 0)
                slider.moved(Math.max(0, Math.min(1, mouse.x / width)));
        }
        onWheel: wheel => slider.moved(Math.max(0, Math.min(1, slider.value + (wheel.angleDelta.y > 0 ? 0.04 : -0.04))))
    }

}
