import QtQuick

// Botón de la barra: ícono y texto opcionales con el mismo tamaño, relleno y espaciado
// en todos, para que los de la derecha queden alineados y parejos.
Rectangle {
    id: root

    property string icon
    property string label
    property color iconColor: Theme.text
    property color labelColor: Theme.text
    property int labelSize: 12
    property int labelWeight: Font.DemiBold
    // Ancho mínimo del texto: evita que los vecinos se muevan cuando el número cambia
    property real labelMinWidth: 0
    // El menú de este botón está abierto
    property bool active: false
    property real iconRotation: 0
    property int iconOrigin: Item.Center

    // Lo que se declare adentro del botón va al final de la fila (ej. un "+1")
    default property alias extra: content.data
    property alias labelItem: labelText
    // Mouse encima. Marca propia y no containsMouse: al cerrarse un menú Wayland a veces no avisa que el
    // mouse se fue y el botón quedaba gris; esta se apaga a mano (forgetHover) y vuelve al mover el mouse
    property bool hovered: false

    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: content.implicitWidth + 20
    implicitHeight: 24
    radius: Theme.comic ? 6 : height / 2
    color: hovered || active ? Theme.hover : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 5

        Item {
            id: iconBox

            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            width: 18
            height: 18
            rotation: root.iconRotation
            transformOrigin: root.iconOrigin

            MIcon {
                anchors.centerIn: parent
                name: root.icon
                color: root.iconColor
                font.pixelSize: 17
            }
        }

        Text {
            id: labelText

            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            width: Math.max(implicitWidth, root.labelMinWidth)
            horizontalAlignment: Text.AlignHCenter
            text: root.label
            color: root.labelColor
            // Con los temas de cómic los números van en la tipografía del tema, como el reloj
            font.pixelSize: Theme.comic ? root.labelSize + 3 : root.labelSize
            font.weight: Theme.comic ? Font.Normal : root.labelWeight
            font.family: Theme.comic ? Theme.displayFont : ""
            font.letterSpacing: Theme.comic ? 0.5 : 0
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.scrolled(wheel)
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onPositionChanged: root.hovered = true
    }

    // Al abrirse o cerrarse un menú se olvida el «mouse encima» (ver `hovered`)
    Connections {
        target: Ui

        function onPopupChanged(): void {
            root.forgetHover();
        }
        function onSysMenuOpenChanged(): void {
            root.forgetHover();
        }
    }

    function forgetHover(): void {
        hovered = false;
    }
}
