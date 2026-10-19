import QtQuick
import QtQuick.Layouts

// Selector de fondos: una cuadrícula de miniaturas; un clic cambia el fondo del escritorio y
// del bloqueo. Lo que pongas en ~/Imágenes/Fondos aparece primero.
DropPopup {
    id: root

    onOpenChanged: if (open)
        Walls.rescan()

    bodyWidth: 400
    bodyHeight: 372

    ColumnLayout {
        x: 16
        y: 2
        width: root.bodyWidth - 32
        height: root.bodyHeight - 26
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "FONDOS"
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                text: "Los tuyos: ~/Imágenes/Fondos"
                color: Theme.textDim
                font.pixelSize: 11
            }
        }

        GridView {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / 3
            cellHeight: 76
            model: Walls.list
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: cell

                required property string modelData

                readonly property bool selected: Walls.current === modelData

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 10
                    color: Theme.surface
                    border.width: cell.selected ? 2 : 0
                    border.color: Theme.accent

                    Image {
                        anchors.fill: parent
                        anchors.margins: cell.selected ? 2 : 0
                        source: "file://" + cell.modelData
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(260, 150)
                        opacity: status === Image.Ready ? (area.containsMouse ? 1 : 0.88) : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Walls.set(cell.modelData)
                    }
                }
            }
        }
    }
}
