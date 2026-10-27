import QtQuick
import Quickshell
import QtQuick.Layouts

// Historial de notificaciones, colgando de la campana de la barra. Agrupado por app como en macOS: de cada
// app se ve la más nueva con las demás apiladas detrás; un clic en «N más» despliega el grupo.
DropPopup {
    id: root

    readonly property int maxHeight: 460

    // [{app, items}] en el orden del historial (la app con el aviso más nuevo, primero)
    readonly property var groups: {
        const byApp = {};
        const out = [];
        for (const n of Notifs.history) {
            const k = n.appName || "Notificación";
            if (!byApp[k]) {
                byApp[k] = {
                    app: k,
                    items: []
                };
                out.push(byApp[k]);
            }
            byApp[k].items.push(n);
        }
        return out;
    }
    // Apps desplegadas
    property var expanded: ({})

    function toggle(app: string): void {
        const e = Object.assign({}, expanded);
        e[app] = !e[app];
        expanded = e;
    }

    onOpenChanged: if (!open)
        expanded = ({})

    bodyWidth: 420
    bodyHeight: column.implicitHeight + 24

    ColumnLayout {
        id: column

        x: 14
        y: 2
        width: root.bodyWidth - 28
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "NOTIFICACIONES"
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                text: Notifs.count
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
            }

            // No molestar
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: dndRow.implicitWidth + 20
                radius: 14
                color: Notifs.dnd ? Theme.accent : (dndHover.hovered ? Theme.hover : Theme.surface)

                Row {
                    id: dndRow

                    anchors.centerIn: parent
                    spacing: 5

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Notifs.dnd ? "notifications_off" : "notifications_active"
                        font.pixelSize: 15
                        color: Notifs.dnd ? Theme.accentText : Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "No molestar"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Notifs.dnd ? Theme.accentText : Theme.text
                    }
                }

                HoverHandler {
                    id: dndHover
                }
                TapHandler {
                    onTapped: Notifs.dnd = !Notifs.dnd
                }
            }

            // Limpiar todo
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: clearText.implicitWidth + 20
                radius: 14
                visible: Notifs.count > 0
                color: clearHover.hovered ? Theme.danger : Theme.surface

                Text {
                    id: clearText

                    anchors.centerIn: parent
                    text: "Limpiar"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: clearHover.hovered ? Theme.accentText : Theme.text
                }

                HoverHandler {
                    id: clearHover
                }
                TapHandler {
                    onTapped: Notifs.dismissAll()
                }
            }
        }

        Text {
            visible: Notifs.count === 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 10
            horizontalAlignment: Text.AlignHCenter
            text: Notifs.dnd ? "Sin notificaciones. No molestar está activado." : "Sin notificaciones."
            color: Theme.textDim
            font.pixelSize: 13
        }

        Flickable {
            visible: Notifs.count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(list.implicitHeight, root.maxHeight)
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: parent.width
                spacing: 14

                Repeater {
                    model: root.groups

                    Column {
                        id: group

                        required property var modelData
                        readonly property bool open: root.expanded[modelData.app] === true
                        readonly property int more: modelData.items.length - 1

                        width: list.width
                        spacing: 6

                        // Encabezado de la app: nombre, cantidad y borrar el grupo
                        RowLayout {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: group.modelData.app.toUpperCase()
                                color: Theme.textDim
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                visible: group.more > 0
                                text: group.modelData.items.length
                                color: Theme.textDim
                                font.pixelSize: 10
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: group.more > 0
                                text: group.open ? "Mostrar menos" : ""
                                color: Theme.textDim
                                font.pixelSize: 11
                                font.underline: lessHover.hovered

                                HoverHandler {
                                    id: lessHover

                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: root.toggle(group.modelData.app)
                                }
                            }

                            Text {
                                text: "Borrar"
                                color: groupClear.hovered ? Theme.danger : Theme.textDim
                                font.pixelSize: 11

                                HoverHandler {
                                    id: groupClear

                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: {
                                        for (const n of group.modelData.items.slice())
                                            Notifs.dismiss(n);
                                    }
                                }
                            }
                        }

                        // La más nueva, con las demás apiladas detrás (cerrado) o todas (abierto)
                        Repeater {
                            model: group.open ? group.modelData.items : group.modelData.items.slice(0, 1)

                            Item {
                                id: cell

                                required property var modelData
                                required property int index
                                readonly property bool stacked: !group.open && group.more > 0

                                width: group.width
                                height: card.height + (stacked ? Math.min(group.more, 2) * 6 : 0)

                                // Las tarjetas de atrás: se asoman abajo, cada vez más angostas
                                Repeater {
                                    model: cell.stacked ? Math.min(group.more, 2) : 0

                                    Rectangle {
                                        required property int index

                                        x: 10 * (index + 1)
                                        y: card.height - 10 + 6 * (index + 1)
                                        width: cell.width - 20 * (index + 1)
                                        height: 12
                                        radius: 8
                                        color: Theme.surface
                                        opacity: 0.75 - 0.25 * index
                                        z: -1 - index
                                    }
                                }

                                NotifCard {
                                    id: card

                                    width: cell.width
                                    entry: cell.modelData
                                }
                            }
                        }

                        // «N más»: despliega el grupo
                        Text {
                            visible: group.more > 0 && !group.open
                            text: group.more === 1 ? "1 más de " + group.modelData.app : group.more + " más de " + group.modelData.app
                            color: Theme.accent
                            font.pixelSize: 11
                            font.weight: Font.DemiBold

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: root.toggle(group.modelData.app)
                            }
                        }
                    }
                }
            }
        }
    }
}
