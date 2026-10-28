import QtQuick

// Slider grueso con el ícono adentro, como el centro de control de macOS. Con `label` muestra también
// el nombre a la izquierda y el valor en % a la derecha. Clic en el ícono dispara iconClicked (ej.
// silenciar) si iconClickable. Relleno neutro (claro), como macOS: el acento queda para lo activo.
// Con los temas de cómic lleva sombra dura, como las viñetas.
Item {
    id: slider

    property string icon
    property string label
    property real value: 0
    property bool muted: false
    property bool iconClickable: false
    // Texto del valor a la derecha; vacío = el porcentaje
    property string valueText: ""

    readonly property real fill: Math.max(0, Math.min(1, value))

    signal moved(real value)
    signal iconClicked

    implicitHeight: label !== "" ? 36 : 30

    activeFocusOnTab: true
    Keys.onLeftPressed: slider.moved(Math.max(0, slider.fill - 0.05))
    Keys.onRightPressed: slider.moved(Math.min(1, slider.fill + 0.05))
    Keys.onReturnPressed: if (slider.iconClickable)
        slider.iconClicked()

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
    }

    // Anillo de foco (afuera de la pista, que recorta lo que tiene adentro)
    Rectangle {
        anchors.fill: track
        anchors.margins: -2
        radius: track.radius + 2
        color: "transparent"
        border.width: 1.5
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.55)
        visible: slider.activeFocus
    }

    // El relleno, recortado al tamaño de la pista
    Item {
        anchors.fill: track
        clip: true

        Rectangle {
            id: filled

            width: Math.max(parent.height, parent.width * slider.fill)
            height: parent.height
            radius: track.radius
            color: slider.muted ? Theme.textDim : Theme.text
            border.width: Theme.comic ? 2 : 0
            border.color: Theme.comic ? Theme.ink : "transparent"
        }
    }

    // Ícono, nombre y valor. Se dibujan dos veces: claros sobre la parte vacía y en el color del fondo
    // encima del relleno (la segunda copia se recorta justo en su borde), así se leen en
    // cualquier tema.
    Repeater {
        model: 2

        Item {
            required property int index
            readonly property color tone: index === 0 || slider.muted ? Theme.text : Theme.bg

            width: index === 0 ? slider.width : filled.width
            height: slider.height
            clip: true

            MIcon {
                x: 9
                anchors.verticalCenter: parent.verticalCenter
                name: slider.icon
                font.pixelSize: Theme.iconMd
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
                text: slider.muted ? "Silencio" : (slider.valueText !== "" ? slider.valueText : Math.round(slider.fill * 100) + " %")
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
