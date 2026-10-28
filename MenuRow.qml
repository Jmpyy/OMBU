import QtQuick
import QtQuick.Layouts

// Fila de menú, a la manera de macOS (la del menú de la araña): ícono gris en una columna fija, texto,
// atajo o dato atenuado a la derecha, tilde o flecha opcionales, y resaltado al pasar el mouse. Lo que
// se declare adentro va al final de la fila (ej. un botón «⋯»); al ir arriba del clic de la fila, se
// queda con su propio clic.
Rectangle {
    id: row

    property string icon
    // Imagen en vez de ícono (el de una app)
    property string image
    property string text
    property string hint
    property bool checked: false
    property bool chevron: false
    property bool danger: false
    // Resaltado forzado (navegación con teclado)
    property bool current: false
    readonly property bool hovered: hover.hovered

    default property alias trailing: extra.data

    signal clicked

    Layout.fillWidth: true
    implicitHeight: 32
    radius: Theme.controlRadius - 3
    color: hover.hovered || current ? Theme.surface : "transparent"

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: row.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10

        Item {
            visible: row.icon !== "" || row.image !== ""
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20

            MIcon {
                visible: row.image === ""
                anchors.centerIn: parent
                name: row.icon
                font.pixelSize: Theme.iconSm
                color: row.danger ? Theme.danger : Theme.text
            }

            Image {
                visible: row.image !== ""
                anchors.fill: parent
                source: row.image
                sourceSize: Qt.size(40, 40)
                smooth: true
            }
        }

        Text {
            Layout.fillWidth: true
            text: row.text
            elide: Text.ElideRight
            color: row.danger ? Theme.danger : Theme.text
            font.pixelSize: Theme.fontBody
        }

        Text {
            visible: row.hint !== ""
            text: row.hint
            color: Theme.textDim
            font.pixelSize: Theme.fontCaption
        }

        MIcon {
            visible: row.checked
            name: "check"
            font.pixelSize: Theme.iconSm
            color: Theme.accent
        }

        MIcon {
            visible: row.chevron
            name: "chevron_right"
            font.pixelSize: Theme.iconSm
            color: Theme.textDim
        }

        RowLayout {
            id: extra

            visible: children.length > 0
            spacing: 2
        }
    }
}
