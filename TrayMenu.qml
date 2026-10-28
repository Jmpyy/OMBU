import QtQuick
import QtQuick.Layouts
import Quickshell

// Menú del ícono de una app de la bandeja (el clic derecho): las mismas opciones que daría
// el ícono original ("Abrir", "Salir"...), con el diseño de ombu. Los submenús se abren
// dentro del mismo menú, con una fila para volver.
DropPopup {
    id: root

    required property var trayItem
    // Submenús abiertos, del más externo al más interno
    property var stack: []

    // Sin `?.` fallaba cuando la app se cerraba: el menú vive un instante más que su ícono de la bandeja
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : (trayItem?.menu ?? null)

    onOpenChanged: if (!open)
        stack = []

    centered: true
    bodyWidth: 250
    bodyHeight: column.implicitHeight + 20

    QsMenuOpener {
        id: opener

        menu: root.current
    }

    ColumnLayout {
        id: column

        x: 10
        y: 2
        width: root.bodyWidth - 20
        spacing: 2

        // Volver del submenú
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            visible: root.stack.length > 0
            radius: 10
            color: backHover.hovered ? Theme.hover : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                MIcon {
                    name: "arrow_back"
                    color: Theme.textDim
                    font.pixelSize: Theme.iconMd
                }

                Text {
                    Layout.fillWidth: true
                    text: "Atrás"
                    color: Theme.textDim
                    font.pixelSize: Theme.fontBody
                }
            }

            HoverHandler {
                id: backHover
            }
            TapHandler {
                onTapped: root.stack = root.stack.slice(0, -1)
            }
        }

        Repeater {
            model: opener.children

            Item {
                id: row

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: modelData.isSeparator ? 9 : 34

                // Separador
                Rectangle {
                    visible: row.modelData.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    width: parent.width - 12
                    height: 1
                    color: Theme.border
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !row.modelData.isSeparator
                    radius: 10
                    color: rowHover.hovered && row.modelData.enabled ? Theme.hover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        // Casilla marcada (opciones de tipo sí/no o una u otra)
                        MIcon {
                            Layout.preferredWidth: 18
                            visible: row.modelData.buttonType !== 0
                            name: row.modelData.checkState === Qt.Checked ? "check" : ""
                            color: Theme.accent
                            font.pixelSize: Theme.iconMd
                        }

                        Image {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            visible: row.modelData.icon !== ""
                            source: row.modelData.icon
                            sourceSize: Qt.size(36, 36)
                            smooth: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.text
                            color: row.modelData.enabled ? Theme.text : Theme.textDim
                            font.pixelSize: Theme.fontBody
                            elide: Text.ElideRight
                        }

                        MIcon {
                            visible: row.modelData.hasChildren
                            name: "chevron_right"
                            color: Theme.textDim
                            font.pixelSize: Theme.iconMd
                        }
                    }

                    HoverHandler {
                        id: rowHover

                        cursorShape: row.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    TapHandler {
                        enabled: row.modelData.enabled
                        onTapped: {
                            if (row.modelData.hasChildren) {
                                root.stack = root.stack.concat([row.modelData]);
                            } else {
                                row.modelData.triggered();
                                root.dismissed();
                            }
                        }
                    }
                }
            }
        }
    }
}
