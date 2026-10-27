import QtQuick

// Slider grueso con el ícono adentro, como el centro de control de macOS. Con `label` muestra también
// el nombre a la izquierda y el valor en % a la derecha. Clic en el ícono dispara iconClicked (ej.
// silenciar) si iconClickable. Con los temas de cómic lleva sombra dura, como las viñetas.
Item {
    id: slider

    property string icon
    property string label
    property real value: 0
    property bool muted: false
    property bool iconClickable: false

    readonly property real fill: Math.max(0, Math.min(1, value))

    signal moved(real value)
    signal iconClicked

    implicitHeight: label !== "" ? 36 : 30

    // Sombra dura (temas de cómic)
    Rectangle {
        visible: Theme.comic
        x: 3
        y: 3
        width: track.width
        height: track.height
        radius: track.radius
        color: Theme.shadow
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: Theme.controlRadius
        color: Theme.surface
        border.width: Theme.comic ? 2 : 0
        border.color: Theme.comic ? Theme.ink : "transparent"
        clip: true

        Rectangle {
            id: filled

            width: Math.max(parent.height, parent.width * slider.fill)
            height: parent.height
            radius: parent.radius
            color: slider.muted ? Theme.textDim : Theme.accent
            border.width: Theme.comic ? 2 : 0
            border.color: Theme.comic ? Theme.ink : "transparent"
        }
    }

    // Ícono, nombre y valor. Se dibujan dos veces: claros sobre la parte vacía y en el color de texto
    // sobre acento encima del relleno (la segunda copia se recorta justo en su borde), así se leen en
    // cualquier tema.
    Repeater {
        model: 2

        Item {
            required property int index
            readonly property color tone: index === 0 || slider.muted ? Theme.text : Theme.accentText

            width: index === 0 ? slider.width : filled.width
            height: slider.height
            clip: true

            MIcon {
                x: 9
                anchors.verticalCenter: parent.verticalCenter
                name: slider.icon
                font.pixelSize: 18
                color: slider.muted ? Theme.danger : parent.tone
            }

            Text {
                x: 34
                anchors.verticalCenter: parent.verticalCenter
                visible: slider.label !== ""
                text: Theme.comic ? slider.label.toUpperCase() : slider.label
                color: parent.tone
                font.family: Theme.comic ? Theme.displayFont : ""
                font.pixelSize: Theme.comic ? 15 : 13
                font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                font.letterSpacing: Theme.comic ? 0.6 : 0
            }

            // Pegado al borde derecho del slider (no al de esta copia, que puede ser más angosta)
            Text {
                x: slider.width - width - 12
                anchors.verticalCenter: parent.verticalCenter
                visible: slider.label !== ""
                text: slider.muted ? "Silencio" : Math.round(slider.fill * 100) + " %"
                color: parent.tone
                font.family: Theme.comic ? Theme.displayFont : ""
                font.pixelSize: Theme.comic ? 15 : 12
                font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                font.features: {
                    "tnum": 1
                }
            }
        }
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
